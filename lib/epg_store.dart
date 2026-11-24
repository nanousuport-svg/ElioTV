import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'xtream.dart';

/// Guide TV (Xtream) : programmes chargés à la demande pour les chaînes affichées à l'écran,
/// puis gardés en mémoire. Quelques requêtes à la fois, les dernières chaînes demandées d'abord
/// (celles qu'on vient de faire défiler), pour ne pas surcharger le fournisseur.
class EpgStore extends ChangeNotifier {
  XtreamClient? _client;
  final _cache = <int, _Programmes>{};
  final _queue = <int>[];
  final _inFlight = <int>{};
  Timer? _notify;

  static const _parallel = 4;
  static const _maxQueue = 60;
  static const _maxAge = Duration(minutes: 30);

  /// Nouveau fournisseur (ou aucun, pour une liste M3U) : on repart de zéro.
  void reset(XtreamClient? client) {
    _client = client;
    _cache.clear();
    _queue.clear();
    _inFlight.clear();
    notifyListeners();
  }

  bool get available => _client != null;

  /// Programmes en cours et à venir ; vide tant qu'ils ne sont pas arrivés (ils sont alors demandés).
  List<EpgEntry> upcoming(int streamId) {
    final now = DateTime.now();
    final cached = _cache[streamId];
    if (cached == null || cached.isStale(now)) _request(streamId);
    return cached?.entries.where((e) => e.end.isAfter(now)).toList() ??
        const [];
  }

  /// Ce qui passe en ce moment sur la chaîne, s'il est connu.
  EpgEntry? onAir(int streamId) {
    final now = DateTime.now();
    final list = upcoming(streamId);
    return list.isNotEmpty && list.first.isOnAir(now) ? list.first : null;
  }

  /// Programme détaillé (une vingtaine d'émissions), pour la fiche « Programme ».
  Future<List<EpgEntry>> programme(int streamId) async {
    final client = _client;
    if (client == null) return const [];
    final entries = await client.shortEpg(streamId, limit: 24);
    _cache[streamId] = _Programmes(entries, DateTime.now());
    _scheduleNotify();
    return entries;
  }

  void _request(int streamId) {
    if (_client == null || _inFlight.contains(streamId)) return;
    _queue
      ..remove(streamId)
      ..insert(0, streamId);
    if (_queue.length > _maxQueue) _queue.removeRange(_maxQueue, _queue.length);
    // Hors du build en cours : la liste demande ses programmes pendant qu'elle se dessine.
    scheduleMicrotask(_pump);
  }

  void _pump() {
    final client = _client;
    while (client != null &&
        _inFlight.length < _parallel &&
        _queue.isNotEmpty) {
      final id = _queue.removeAt(0);
      _inFlight.add(id);
      client
          .shortEpg(id)
          .then(
            (entries) => _cache[id] = _Programmes(entries, DateTime.now()),
            // Pas de guide pour cette chaîne : on ne redemande pas avant un moment.
            onError: (Object e) {
              debugPrint(
                'ElioTV guide : chaîne $id → erreur ${e is ElioError ? e.message : e.runtimeType}',
              );
              return _cache[id] = _Programmes(const [], DateTime.now());
            },
          )
          .whenComplete(() {
            if (_client != client) return;
            _inFlight.remove(id);
            _scheduleNotify();
            _pump();
          });
    }
  }

  /// Les réponses arrivent par paquets : un seul rafraîchissement de l'écran pour plusieurs.
  void _scheduleNotify() {
    _notify ??= Timer(const Duration(milliseconds: 250), () {
      _notify = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _notify?.cancel();
    super.dispose();
  }
}

class _Programmes {
  _Programmes(this.entries, this.fetched);
  final List<EpgEntry> entries;
  final DateTime fetched;

  /// À recharger après 30 min, ou dès que l'émission en cours se termine sans suite connue.
  bool isStale(DateTime now) {
    final age = now.difference(fetched);
    if (age > EpgStore._maxAge) return true;
    final left = entries.where((e) => e.end.isAfter(now)).length;
    return entries.isNotEmpty && left < 2 && age > const Duration(minutes: 2);
  }
}
