import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'net.dart';

/// Relais local pour les chaînes en direct (MPEG-TS) : le lecteur lit 127.0.0.1, le relais lit le
/// fournisseur. Quand la connexion au fournisseur saute, le relais se reconnecte lui-même ; or la
/// plupart des serveurs Xtream repartent alors de leur mémoire tampon, quelques secondes en arrière.
/// Le relais retrouve dans le nouveau flux les derniers octets déjà envoyés et saute tout ce qui
/// précède : le lecteur reçoit un flux continu, sans coupure ni retour en arrière.
class LiveRelay {
  LiveRelay._(this._server) {
    _server.listen(_handle);
  }

  final HttpServer _server;

  static LiveRelay? instance;

  /// À appeler au démarrage. En cas d'échec, les chaînes sont lues directement (sans relais).
  static Future<void> start() async {
    try {
      instance ??= LiveRelay._(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      );
    } catch (e) {
      debugPrint('ElioTV relais : indisponible ($e)');
    }
  }

  /// Adresse locale qui relaie [url].
  String wrap(String url) =>
      'http://127.0.0.1:${_server.port}/live.ts?u=${Uri.encodeQueryComponent(url)}';

  Future<void> _handle(HttpRequest request) async {
    final url = Uri.tryParse(request.uri.queryParameters['u'] ?? '');
    if (url == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    await _Session(url, request.response).run();
  }
}

class _Session {
  _Session(this.url, this.out);

  final Uri url;
  final HttpResponse out;

  /// Empreinte de la fin du flux déjà envoyé : 8 paquets MPEG-TS.
  static const _signatureLength = 8 * 188;

  /// Au-delà, on renonce à chercher le raccord (le serveur n'a peut-être rien rejoué).
  static const _maxSearchBytes = 6 * 1024 * 1024;
  static const _maxSearchTime = Duration(seconds: 3);

  final _client = HttpClient()
    ..userAgent = userAgent
    ..connectionTimeout = const Duration(seconds: 10);
  var _closed = false;
  var _sent = 0;
  var _tail = Uint8List(0);

  Future<void> run() async {
    // Le lecteur a fermé la connexion (zapping, arrêt) : on arrête de lire le fournisseur.
    out.done.then((_) => _closed = true, onError: (_) => _closed = true);
    var failures = 0;
    while (!_closed) {
      var received = 0;
      try {
        final request = await _client.getUrl(url);
        final response = await request.close();
        if (response.statusCode >= 400) {
          unawaited(response.drain<void>().catchError((_) {}));
          throw HttpException('HTTP ${response.statusCode}', uri: url);
        }
        if (_sent == 0 && failures == 0) {
          out.statusCode = HttpStatus.ok;
          out.headers.contentType = ContentType('video', 'mp2t');
          out.bufferOutput = false;
        }
        received = await _pipe(response, rejoin: _sent > 0);
      } catch (e) {
        debugPrint('ElioTV relais : $e');
        // Premier essai raté : le lecteur reçoit l'erreur et passe à l'adresse suivante (.m3u8).
        if (_sent == 0) {
          if (failures == 0) {
            try {
              out.statusCode = HttpStatus.badGateway;
            } catch (_) {}
          }
          break;
        }
      }
      if (_closed) break;
      // Une connexion qui a bien fonctionné remet le compteur à zéro ; sinon on espace les essais.
      failures = received > 256 * 1024 ? 1 : failures + 1;
      if (failures > 6) break;
      debugPrint('ElioTV relais : reconnexion (essai $failures)');
      await Future<void>.delayed(Duration(milliseconds: 300 * (failures - 1)));
    }
    _client.close(force: true);
    try {
      await out.close();
    } catch (_) {}
  }

  /// Transmet le flux du fournisseur. Après une reconnexion ([rejoin]), retient les données le
  /// temps de retrouver le raccord avec ce qui a déjà été envoyé.
  Future<int> _pipe(Stream<List<int>> upstream, {required bool rejoin}) async {
    var received = 0;
    var searching = rejoin && _tail.length == _signatureLength;
    var pending = Uint8List(0);
    var searchedUpTo = 0;
    final searchStart = DateTime.now();
    await for (final chunk in upstream.timeout(const Duration(seconds: 15))) {
      if (_closed) break;
      received += chunk.length;
      if (!searching) {
        _send(chunk);
        continue;
      }
      pending = _concat(pending, chunk);
      final at = _indexOf(
        pending,
        _tail,
        max(0, searchedUpTo - _signatureLength + 1),
      );
      searchedUpTo = pending.length;
      if (at >= 0) {
        debugPrint(
          'ElioTV relais : ${formatBytes(at + _signatureLength)} déjà vus, sautés',
        );
        searching = false;
        _send(Uint8List.sublistView(pending, at + _signatureLength));
      } else if (pending.length > _maxSearchBytes ||
          DateTime.now().difference(searchStart) > _maxSearchTime) {
        searching = false;
        _send(pending);
      }
    }
    if (searching) _send(pending);
    return received;
  }

  void _send(List<int> data) {
    if (data.isEmpty || _closed) return;
    try {
      out.add(data);
    } catch (_) {
      _closed = true;
      return;
    }
    _sent += data.length;
    final recent = data.length >= _signatureLength ? data : _concat(_tail, data);
    _tail = Uint8List.fromList(
      recent.sublist(max(0, recent.length - _signatureLength)),
    );
  }

  static Uint8List _concat(Uint8List a, List<int> b) {
    final r = Uint8List(a.length + b.length);
    r.setAll(0, a);
    r.setAll(a.length, b);
    return r;
  }

  static int _indexOf(Uint8List hay, Uint8List needle, int from) {
    final first = needle[0];
    outer:
    for (var i = from; i <= hay.length - needle.length; i++) {
      if (hay[i] != first) continue;
      for (var j = 1; j < needle.length; j++) {
        if (hay[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }
}
