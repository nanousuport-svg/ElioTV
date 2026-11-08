import 'package:eliotv/app_state.dart';
import 'package:eliotv/main.dart';
import 'package:eliotv/models.dart';
import 'package:eliotv/storage.dart';
import 'package:eliotv/ui/home_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

/// Gros fournisseur (serveur de test lancé avec `python3 tool/mock_xtream.py --big`) :
/// la TV doit s'afficher sans attendre les 18 Mo de films, et la progression doit être visible.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la TV s\'affiche avant les films', (tester) async {
    MediaKit.ensureInitialized();
    await Storage.init();
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

    final messages = <String>{};
    final start = DateTime.now();
    double elapsed() => DateTime.now().difference(start).inMilliseconds / 1000;
    int count(ContentKind k) =>
        state.catalog.items.where((i) => i.kind == k).length;

    final done = state.connectXtream('127.0.0.1:8765', 'demo', 'demo+1', 'Gros');
    var finished = false;
    done.whenComplete(() => finished = true);

    double? liveShown;
    var moviesWhenLiveShown = -1;
    for (var i = 0; i < 400 && !finished; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
      if (state.isLoading) messages.add(state.loadingMessage);
      if (liveShown == null && count(ContentKind.live) > 0) {
        liveShown = elapsed();
        moviesWhenLiveShown = count(ContentKind.movie);
        expect(state.isLoading, isFalse);
        expect(find.byType(HomePage), findsOneWidget);
      }
    }
    await tester.runAsync(() => done);
    await tester.pump();

    debugPrint('RÉSULTAT messages : ${messages.join(' | ')}');
    debugPrint(
      'RÉSULTAT TV affichée après ${liveShown}s (films à ce moment : $moviesWhenLiveShown), '
      'tout chargé après ${elapsed()}s : ${count(ContentKind.live)} chaînes, '
      '${count(ContentKind.movie)} films, ${count(ContentKind.series)} séries',
    );
    expect(state.error, isNull);
    expect(liveShown, lessThan(10));
    expect(moviesWhenLiveShown, 0);
    expect(messages.any((m) => m.contains('Mo reçus')), isTrue);
    expect(count(ContentKind.live), 20000);
    expect(count(ContentKind.movie), 80000);
    expect(state.availableKinds, contains(ContentKind.movie));
  });
}
