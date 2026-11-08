import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'live_relay.dart';
import 'net.dart';
import 'storage.dart';

enum PlayerStatus { idle, loading, playing, paused, failed }

/// Lecteur basé sur media_kit, c'est-à-dire libmpv (moteur d'IINA/mpv) sur toutes les plateformes :
/// MPEG-TS, HLS, MKV, HEVC, AC3, DTS… avec le décodage matériel de l'appareil.
class PlayerController extends ChangeNotifier {
  PlayerController() {
    player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 64 * 1024 * 1024,
        title: 'ElioTV',
      ),
    );
    video = VideoController(player);
    _configure();
    player.setVolume(Storage.prefs.getDouble('volume') ?? 100);
    // « playing » passe à vrai dès l'ordre de lecture, avant toute image : il ne sert qu'à la pause.
    // Le passage loading → playing se fait sur la première image ou le premier son (plus bas).
    player.stream.playing.listen((playing) {
      if (status == PlayerStatus.playing || status == PlayerStatus.paused) {
        _setStatus(playing ? PlayerStatus.playing : PlayerStatus.paused);
      }
    });
    player.stream.buffering.listen((b) {
      isBuffering = b;
      notifyListeners();
    });
    player.stream.width.listen((w) {
      debugPrint(
        'ElioTV lecteur : image ${w}x${player.state.height}, position ${player.state.position.inSeconds} s',
      );
      // La première image est arrivée : la lecture a vraiment démarré.
      if (w != null && w > 0 && status == PlayerStatus.loading) {
        _watchdog?.cancel();
        _setStatus(PlayerStatus.playing);
      }
    });
    player.stream.audioParams.listen((p) {
      if (p.sampleRate != null && status == PlayerStatus.loading) {
        _watchdog?.cancel();
        _setStatus(PlayerStatus.playing);
      }
    });
    player.stream.error.listen((message) {
      debugPrint('mpv: $message');
      if (status == PlayerStatus.loading) _next();
    });
    player.stream.tracks.listen((_) => notifyListeners());
    player.stream.track.listen((_) => notifyListeners());
    player.stream.volume.listen((v) => Storage.prefs.setDouble('volume', v));
  }

  late final Player player;
  late final VideoController video;

  PlayerStatus status = PlayerStatus.idle;
  String? title;
  String? sourceUrl;
  String? failure;
  bool isBuffering = false;
  bool isLive = false;

  List<String> _candidates = [];
  int _attempt = 0;
  Timer? _watchdog;

  Future<void> _configure() async {
    final native = player.platform;
    if (native is! NativePlayer) return;
    const options = {
      'user-agent': userAgent,
      'network-timeout': '10',
      'cache': 'yes',
      'cache-pause-initial': 'no', // démarre dès la première image
      // En direct, les données arrivent au rythme de la lecture : sans réserve, chaque à-coup
      // du serveur relance « Mise en mémoire… ». Après un arrêt, on repart avec 4 s d'avance.
      'cache-pause-wait': '4',
      'demuxer-lavf-analyzeduration':
          '1', // analyse du flux raccourcie : zapping rapide
      'demuxer-lavf-probesize': '1000000',
      'stream-lavf-o': 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5',
      'hls-bitrate': 'max',
      'slang': 'fr,fre,fra',
      'alang': 'fr,fre,fra',
    };
    for (final e in options.entries) {
      await native.setProperty(e.key, e.value);
    }
  }

  void play(String url, String title, {required bool live}) {
    this.title = title;
    sourceUrl = url;
    isLive = live;
    _candidates = streamCandidates(url);
    // Direct en MPEG-TS : d'abord via le relais local (reconnexions sans retour en arrière),
    // puis les adresses habituelles si le relais échoue.
    final relay = LiveRelay.instance;
    if (live && relay != null && url.toLowerCase().endsWith('.ts'))
      _candidates = [relay.wrap(url), ..._candidates.skip(1), url];
    _attempt = 0;
    _start();
  }

  void retry() {
    if (sourceUrl != null && title != null)
      play(sourceUrl!, title!, live: isLive);
  }

  void stop() {
    _watchdog?.cancel();
    player.stop();
    title = null;
    sourceUrl = null;
    _setStatus(PlayerStatus.idle);
  }

  void togglePause() {
    if (status == PlayerStatus.idle || status == PlayerStatus.failed) return;
    player.playOrPause();
  }

  void seekBy(Duration delta) {
    if (isLive) return;
    final target = player.state.position + delta;
    player.seek(target < Duration.zero ? Duration.zero : target);
  }

  void _start() {
    _watchdog?.cancel();
    if (_attempt >= _candidates.length) {
      failure = 'Ce flux ne répond pas. La chaîne est peut-être hors ligne chez ton fournisseur.';
      _setStatus(PlayerStatus.failed);
      return;
    }
    _setStatus(PlayerStatus.loading);
    player.open(Media(_candidates[_attempt], httpHeaders: httpHeaders));
    // libmpv signale lui-même les liens morts ; ce délai ne sert qu'aux serveurs qui ne répondent jamais.
    final current = _attempt;
    _watchdog = Timer(const Duration(seconds: 30), () {
      if (_attempt == current && status == PlayerStatus.loading) _next();
    });
  }

  void _next() {
    _attempt++;
    _start();
  }

  void _setStatus(PlayerStatus s) {
    if (s != status)
      debugPrint(
        'ElioTV lecteur : ${s.name} (${_candidates.elementAtOrNull(_attempt) ?? '-'})',
      );
    status = s;
    notifyListeners();
  }

  /// « 1080p · H264 · AAC »
  String? get mediaInfo {
    final parts = <String>[];
    final h = player.state.height;
    if (h != null && h > 0) parts.add(h >= 2000 ? '4K' : '${h}p');
    final v =
        player.state.track.video.codec ??
        _firstCodec(player.state.tracks.video);
    if (v != null) parts.add(v.toUpperCase());
    final a =
        player.state.track.audio.codec ??
        _firstCodec(player.state.tracks.audio);
    if (a != null) parts.add(a.toUpperCase());
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? _firstCodec(List<dynamic> tracks) {
    for (final t in tracks) {
      final c = (t as dynamic).codec as String?;
      if (c != null) return c;
    }
    return null;
  }

  /// Pistes réelles (sans les entrées « auto » / « no » ajoutées par media_kit).
  List<AudioTrack> get audioTracks => player.state.tracks.audio
      .where((t) => t.id != 'auto' && t.id != 'no')
      .toList();
  List<SubtitleTrack> get subtitleTracks => player.state.tracks.subtitle
      .where((t) => t.id != 'auto' && t.id != 'no')
      .toList();

  @override
  void dispose() {
    _watchdog?.cancel();
    player.dispose();
    super.dispose();
  }
}

String trackLabel(dynamic track) {
  final parts = <String>[
    if ((track.title as String?)?.isNotEmpty ?? false) track.title as String,
    if ((track.language as String?)?.isNotEmpty ?? false)
      (track.language as String).toUpperCase(),
    if ((track.codec as String?)?.isNotEmpty ?? false)
      (track.codec as String).toUpperCase(),
  ];
  return parts.isEmpty ? 'Piste ${track.id}' : parts.join(' · ');
}
