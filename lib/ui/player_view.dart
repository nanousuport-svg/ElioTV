import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../device.dart';
import '../player.dart';
import 'theme.dart';

/// Image vidéo + états (chargement, erreur) + commandes qui apparaissent au mouvement de la souris ou au toucher.
class PlayerSurface extends StatefulWidget {
  const PlayerSurface({super.key, required this.fullscreen});
  final bool fullscreen;

  @override
  State<PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<PlayerSurface> {
  bool controlsVisible = true;
  Timer? _hide;

  void _show() {
    setState(() => controlsVisible = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => controlsVisible = false);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final showControls = controlsVisible || p.status == PlayerStatus.paused;
    return MouseRegion(
      onHover: (_) => _show(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _show,
        onDoubleTap: () => widget.fullscreen
            ? Navigator.maybePop(context)
            : openFullscreen(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            Video(
              controller: p.video,
              controls: NoVideoControls,
              fill: Colors.black,
            ),
            if (p.status == PlayerStatus.loading)
              _Bubble(text: p.title ?? 'Chargement…'),
            if (p.status != PlayerStatus.loading &&
                p.isBuffering &&
                p.status != PlayerStatus.failed)
              const _Bubble(text: 'Mise en mémoire…'),
            if (p.status == PlayerStatus.failed)
              _Failure(message: p.failure ?? ''),
            if (p.status == PlayerStatus.playing ||
                p.status == PlayerStatus.paused)
              AnimatedOpacity(
                opacity: showControls ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: PlayerControls(fullscreen: widget.fullscreen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber,
            size: 36,
          ),
          const SizedBox(height: 10),
          const Text(
            'Lecture impossible',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          FilledButton(
            autofocus: true,
            onPressed: () => context.read<PlayerController>().retry(),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key, required this.fullscreen});
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final player = p.player;
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      constraints: const BoxConstraints(maxWidth: 860),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Lecture / Pause',
            icon: Icon(
              p.status == PlayerStatus.paused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
            ),
            onPressed: p.togglePause,
          ),
          if (p.isLive) ...[
            const Icon(Icons.circle, color: Colors.red, size: 10),
            const SizedBox(width: 6),
            const Text(
              'EN DIRECT',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const Spacer(),
          ] else
            Expanded(child: _SeekBar(player: player)),
          if (Device.isDesktop) _VolumeControl(player: player),
          if (p.audioTracks.length > 1)
            PopupMenuButton<AudioTrack>(
              tooltip: 'Piste audio',
              icon: const Icon(Icons.graphic_eq_rounded),
              onSelected: player.setAudioTrack,
              itemBuilder: (_) => [
                for (final t in p.audioTracks)
                  CheckedPopupMenuItem(
                    value: t,
                    checked: player.state.track.audio.id == t.id,
                    child: Text(trackLabel(t)),
                  ),
              ],
            ),
          if (p.subtitleTracks.isNotEmpty)
            PopupMenuButton<SubtitleTrack>(
              tooltip: 'Sous-titres',
              icon: const Icon(Icons.closed_caption_outlined),
              onSelected: player.setSubtitleTrack,
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: SubtitleTrack.no(),
                  checked: player.state.track.subtitle.id == 'no',
                  child: const Text('Désactivés'),
                ),
                for (final t in p.subtitleTracks)
                  CheckedPopupMenuItem(
                    value: t,
                    checked: player.state.track.subtitle.id == t.id,
                    child: Text(trackLabel(t)),
                  ),
              ],
            ),
          IconButton(
            tooltip: fullscreen ? 'Quitter le plein écran' : 'Plein écran',
            icon: Icon(
              fullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
            onPressed: () => fullscreen
                ? Navigator.maybePop(context)
                : openFullscreen(context),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player});
  final Player player;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? dragging;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (context, _) {
        final position = widget.player.state.position.inMilliseconds / 1000;
        final duration = widget.player.state.duration.inMilliseconds / 1000;
        final value = (dragging ?? position)
            .clamp(0, duration > 0 ? duration : 1)
            .toDouble();
        return Row(
          children: [
            Text(
              _time(value),
              style: const TextStyle(
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Expanded(
              child: Slider(
                value: value,
                max: duration > 0 ? duration : 1,
                onChanged: (v) => setState(() => dragging = v),
                onChangeEnd: (v) {
                  widget.player.seek(
                    Duration(milliseconds: (v * 1000).round()),
                  );
                  setState(() => dragging = null);
                },
              ),
            ),
            Text(
              _time(duration),
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        );
      },
    );
  }

  static String _time(double seconds) {
    final s = seconds.round();
    String two(int n) => n.toString().padLeft(2, '0');
    return s >= 3600
        ? '${s ~/ 3600}:${two(s ~/ 60 % 60)}:${two(s % 60)}'
        : '${s ~/ 60}:${two(s % 60)}';
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.stream.volume,
      builder: (context, _) {
        final volume = player.state.volume;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Muet',
              icon: Icon(
                volume == 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
              ),
              onPressed: () => player.setVolume(volume == 0 ? 100 : 0),
            ),
            SizedBox(
              width: 90,
              child: Slider(
                value: volume.clamp(0, 100),
                max: 100,
                onChanged: player.setVolume,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ouvre la vidéo en plein écran. Télécommande et clavier : ↑ ↓ changent de chaîne,
/// ← → reculent ou avancent de 10 s, OK / Espace met en pause, Retour / Échap ferme.
Future<void> openFullscreen(BuildContext context) async {
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const FullscreenPlayerPage(),
      transitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class FullscreenPlayerPage extends StatefulWidget {
  const FullscreenPlayerPage({super.key});

  @override
  State<FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<FullscreenPlayerPage> {
  String? _banner;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    defaultEnterNativeFullscreen();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    defaultExitNativeFullscreen();
    super.dispose();
  }

  void _zap(int delta) {
    final state = context.read<AppState>();
    if (!context.read<PlayerController>().isLive) return;
    state.zap(delta);
    setState(() => _banner = state.selectedItem?.name);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _zap(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _zap(1),
        const SingleActivator(LogicalKeyboardKey.channelUp): () => _zap(-1),
        const SingleActivator(LogicalKeyboardKey.channelDown): () => _zap(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            p.seekBy(const Duration(seconds: -10)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            p.seekBy(const Duration(seconds: 10)),
        const SingleActivator(LogicalKeyboardKey.space): p.togglePause,
        const SingleActivator(LogicalKeyboardKey.select): p.togglePause,
        const SingleActivator(LogicalKeyboardKey.enter): p.togglePause,
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): p.togglePause,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              const Positioned.fill(child: PlayerSurface(fullscreen: true)),
              if (_banner != null)
                Positioned(
                  top: 24,
                  left: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: Brand.gradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _banner!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
