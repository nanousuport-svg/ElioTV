import 'package:eliotv/app_state.dart';
import 'package:eliotv/live_relay.dart';
import 'package:eliotv/main.dart';
import 'package:eliotv/models.dart';
import 'package:eliotv/player.dart';
import 'package:eliotv/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

/// Test de bout en bout sur le vrai lecteur : connexion au serveur de test local, puis lecture
/// d'une chaîne et d'un film. Vérifie que des images arrivent et que la lecture avance.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, bool Function() done, {int seconds = 40}) async {
    for (var i = 0; i < seconds * 4 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();
    }
  }

  testWidgets('connexion, chaîne et film', (tester) async {
    MediaKit.ensureInitialized();
    await Storage.init();
    await LiveRelay.start();
    final state = AppState();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider.value(value: state.player),
    ], child: const ElioApp()));

    await tester.runAsync(() => state.connectXtream('127.0.0.1:8765', 'demo', 'demo+1', 'Test'));
    await tester.pump();
    expect(state.error, isNull);
    expect(state.catalog.items.length, 5);

    for (final id in ['live:1', 'movie:100']) {
      final item = state.catalog.items.firstWhere((i) => i.id == id);
      final start = DateTime.now();
      state.select(item);
      await waitFor(tester, () => state.player.status == PlayerStatus.playing && (state.player.player.state.width ?? 0) > 0);
      final startup = DateTime.now().difference(start).inMilliseconds / 1000;
      final p0 = state.player.player.state.position;
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      await tester.pump();
      final p1 = state.player.player.state.position;
      debugPrint('RÉSULTAT ${item.name} : ${state.player.status.name}, image ${state.player.player.state.width}x'
          '${state.player.player.state.height}, démarrage ${startup}s, position $p0 → $p1, ${state.player.mediaInfo}');
      expect(state.player.status, PlayerStatus.playing);
      expect(state.player.player.state.width, greaterThan(0));
      expect(p1, greaterThan(p0));
      expect(find.byType(Scaffold), findsWidgets);
    }

    // Lien mort : message d'erreur propre au lieu d'un chargement infini.
    state.select(state.catalog.items.firstWhere((i) => i.id == 'live:3'));
    await waitFor(tester, () => state.player.status == PlayerStatus.failed);
    debugPrint('RÉSULTAT chaîne en panne : ${state.player.status.name}');
    expect(state.player.status, PlayerStatus.failed);
    final profile = state.active!;
    state.deleteProfile(profile);
    expect(state.profiles.where((p) => p.id == profile.id), isEmpty);
    expect(state.active, isNull);
    // Nettoie les profils « Test » laissés par d'éventuels essais interrompus.
    for (final p in [...state.profiles.where((p) => p.type == SourceType.xtream && p.name == 'Test')]) {
      state.deleteProfile(p);
    }
  });
}
