import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Beaucoup de fournisseurs IPTV refusent les clients inconnus : on se présente comme VLC.
const userAgent = 'VLC/3.0.20 LibVLC/3.0.20';
const httpHeaders = {'User-Agent': userAgent};

final _client = http.Client();

/// Une grosse liste peut mettre plusieurs minutes à arriver : pas de limite de durée totale,
/// mais on abandonne si le serveur ne répond pas, ou cesse d'envoyer des données.
const _connectTimeout = Duration(seconds: 25);
const _idleTimeout = Duration(seconds: 45);

/// [onProgress] reçoit le nombre d'octets reçus jusqu'ici.
Future<Uint8List> fetchBytes(
  Uri url, {
  void Function(int received)? onProgress,
}) async {
  final request = http.Request('GET', url)..headers.addAll(httpHeaders);
  final response = await _client
      .send(request)
      .timeout(
        _connectTimeout,
        onTimeout: () => throw ElioError.timeout,
      );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    unawaited(response.stream.listen(null).cancel());
    if (response.statusCode == 401 || response.statusCode == 403)
      throw ElioError.badCredentials;
    throw ElioError(
      'Le serveur a répondu avec une erreur (${response.statusCode}).',
    );
  }
  final body = BytesBuilder(copy: false);
  await for (final chunk in response.stream.timeout(
    _idleTimeout,
    onTimeout: (sink) => sink.addError(ElioError.timeout),
  )) {
    body.add(chunk);
    onProgress?.call(body.length);
  }
  return body.takeBytes();
}

Future<dynamic> fetchJson(
  Uri url, {
  void Function(int received)? onProgress,
}) async => jsonDecode(
  utf8.decode(
    await fetchBytes(url, onProgress: onProgress),
    allowMalformed: true,
  ),
);

/// Additionne les octets reçus par plusieurs téléchargements simultanés
/// et les signale au plus une fois par 256 Ko.
class DownloadProgress {
  DownloadProgress(this.report);

  final void Function(int total)? report;
  final _received = <int, int>{};
  int _lastReported = 0;

  void Function(int) slot(int id) => (bytes) {
    _received[id] = bytes;
    final total = _received.values.fold(0, (a, b) => a + b);
    if (total - _lastReported >= 256 * 1024) {
      _lastReported = total;
      report?.call(total);
    }
  };
}

/// « 12,4 Mo » pour les messages de chargement.
String formatBytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  return mb < 1
      ? '${(bytes / 1024).round()} Ko'
      : '${mb.toStringAsFixed(1).replaceAll('.', ',')} Mo';
}

/// Lecture tolérante du JSON Xtream (identifiants tantôt nombres, tantôt texte).
class J {
  static String? str(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static int? integer(dynamic v) => v is int
      ? v
      : (v is num ? v.toInt() : int.tryParse(v?.toString().trim() ?? ''));

  static double? dbl(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString().trim() ?? '');

  static String? url(dynamic v) {
    final s = str(v)?.trim();
    return (s != null && s.toLowerCase().startsWith('http')) ? s : null;
  }

  static String? base64Text(dynamic v) {
    final s = str(v);
    if (s == null) return null;
    try {
      return utf8.decode(base64.decode(s));
    } catch (_) {
      return s;
    }
  }
}

/// Adresses à essayer dans l'ordre : le lien tel quel, puis l'autre format Xtream (.ts ↔ .m3u8).
List<String> streamCandidates(String url) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.ts'))
    return [url, '${url.substring(0, url.length - 3)}.m3u8'];
  if (lower.endsWith('.m3u8') && lower.contains('/live/'))
    return [url, '${url.substring(0, url.length - 5)}.ts'];
  return [url];
}
