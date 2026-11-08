import 'package:eliotv/app_state.dart';
import 'package:eliotv/live_relay.dart';
import 'package:eliotv/main.dart';
import 'package:eliotv/player.dart';
import 'package:eliotv/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

/// Direct dont la connexion saute toutes les 10 s (serveur de test lancé avec
/// `python3 tool/mock_xtream.py --live-ts flux.ts`) : à chaque reconnexion le serveur renvoie
/// ses 3 dernières secondes. L'image ne doit ni couper ni revenir en arrière.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pas de retour en arrière après une reconnexion', (tester) async {
    MediaKit.ensureInitialized();
    await Storage.init();
    await LiveRelay.start();
    final state = AppState();
    final player = state.player;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider.value(value: player),
        ],
        child: const ElioApp(),
      ),
    );

    player.play('http://127.0.0.1:8765/live/demo/demo+1/78.ts', 'Direct', live: true);
    final start = DateTime.now();
    while (player.status != PlayerStatus.playing &&
        DateTime.now().difference(start).inSeconds < 30) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    }

    // Une reconnexion qui rejoue les mêmes images fait reculer la position de lecture.
    var rewinds = 0;
    var last = player.player.state.position;
    final p0 = last;
    for (var i = 0; i < 350; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      final pos = player.player.state.position;
      if (pos < last - const Duration(milliseconds: 500)) rewinds++;
      last = pos;
    }

    debugPrint(
      'RÉSULTAT retours en arrière en 35 s : $rewinds, position $p0 → $last, '
      'état ${player.status.name}',
    );
    expect(player.status, PlayerStatus.playing);
    expect(rewinds, 0);
    expect(last - p0, greaterThan(const Duration(seconds: 25)));
    player.stop();
  });
}
