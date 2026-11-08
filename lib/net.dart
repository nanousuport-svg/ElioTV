import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Beaucoup de fournisseurs IPTV refusent les clients inconnus : on se présente comme VLC.
const userAgent = 'VLC/3.0.20 LibVLC/3.0.20';
const httpHeaders = {'User-Agent': userAgent};

final _client = http.Client();

Future<List<int>> fetchBytes(
  Uri url, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final response = await _client
      .get(url, headers: httpHeaders)
      .timeout(timeout);
  if (response.statusCode == 401 || response.statusCode == 403)
    throw ElioError.badCredentials;
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ElioError(
      'Le serveur a répondu avec une erreur (${response.statusCode}).',
    );
  }
  return response.bodyBytes;
}

Future<dynamic> fetchJson(Uri url) async =>
    jsonDecode(utf8.decode(await fetchBytes(url), allowMalformed: true));

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
