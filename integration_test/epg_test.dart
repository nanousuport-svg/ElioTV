import 'package:eliotv/app_state.dart';
import 'package:eliotv/live_relay.dart';
import 'package:eliotv/main.dart';
import 'package:eliotv/storage.dart';
import 'package:eliotv/ui/epg_view.dart';
import 'package:eliotv/ui/player_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

/// Guide TV (serveur de test `python3 tool/mock_xtream.py`) : l'émission en cours s'affiche sous
/// chaque chaîne, la fiche « Programme » liste la suite, et le plein écran montre en cours / ensuite.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int steps = 6]) async {
    for (var i = 0; i < steps; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
    }
  }

  testWidgets('guide TV dans la liste, la fiche et le plein écran', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    await Storage.init(forTests: true);
    await LiveRelay.start();
    final state = AppState();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider.value(value: state.player),
        ],
        child: const ElioApp(),
      ),
    );
    await tester.runAsync(
      () => state.connectXtream('127.0.0.1:8765', 'demo', 'demo+1', 'Guide'),
    );
    await settle(tester, 10);
    expect(state.error, isNull);

    // Sous chaque chaîne visible : l'émission en cours.
    final lines = find.byType(EpgLine).evaluate().length;
    final onAir = find.textContaining('Journal de 20h').evaluate().length;
    debugPrint(
      'RÉSULTAT liste : $onAir chaînes sur $lines avec leur émission en cours',
    );
    expect(lines, greaterThan(0));
    expect(onAir, lines);

    // Fiche « Programme » de la chaîne.
    final item = state.catalog.items.firstWhere((i) => i.id == 'live:1');
    showProgramme(tester.element(find.byType(Scaffold).first), item);
    await settle(tester);
    expect(find.text('Programme · ${item.name}'), findsOneWidget);
    expect(find.text('EN COURS'), findsOneWidget);
    expect(find.text('Film du soir'), findsOneWidget);
    debugPrint('RÉSULTAT fiche : en cours + suivant affichés');
    Navigator.of(tester.element(find.text('EN COURS'))).pop();
    await settle(tester, 3);

    // Plein écran : bandeau « en cours / ensuite ».
    state.select(item);
    openFullscreen(tester.element(find.byType(Scaffold).first));
    await settle(tester, 8);
    expect(find.byType(NowNextBanner), findsOneWidget);
    expect(find.textContaining('Ensuite ·'), findsOneWidget);
    debugPrint('RÉSULTAT plein écran : bandeau affiché');
    state.player.stop();
    state.deleteProfile(state.active!);
  });
}
