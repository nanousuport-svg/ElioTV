import 'package:eliotv/app_state.dart';
import 'package:eliotv/main.dart';
import 'package:eliotv/player.dart';
import 'package:eliotv/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

/// Direct irrégulier (serveur de test lancé avec `python3 tool/mock_xtream.py --live-ts flux.ts`) :
/// le flux arrive au rythme du direct avec un retard de 1,5 s toutes les 3 s. Le lecteur doit
/// absorber ces à-coups au lieu d'afficher « Mise en mémoire… » toutes les quelques secondes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pas de mise en mémoire à répétition en direct', (tester) async {
    MediaKit.ensureInitialized();
    await Storage.init();
    final state = AppState();
    final player = state.player;
    // L'app complète est affichée : le lecteur a besoin de sa surface vidéo pour sortir des images.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider.value(value: player),
        ],
        child: const ElioApp(),
      ),
    );
    var stalls = 0;
    var wasBuffering = false;
    player.addListener(() {
      if (player.status == PlayerStatus.playing && player.isBuffering && !wasBuffering)
        stalls++;
      wasBuffering = player.isBuffering;
    });

    final start = DateTime.now();
    player.play('http://127.0.0.1:8765/live/demo/demo+1/77.ts', 'Direct', live: true);
    while (player.status != PlayerStatus.playing &&
        DateTime.now().difference(start).inSeconds < 30) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    }
    final startup = DateTime.now().difference(start).inMilliseconds / 1000;
    stalls = 0;
    final p0 = player.player.state.position;
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 40)));
    final p1 = player.player.state.position;

    debugPrint(
      'RÉSULTAT démarrage ${startup}s, mises en mémoire en 40 s : $stalls, '
      'position $p0 → $p1',
    );
    expect(player.status, PlayerStatus.playing);
    expect(stalls, lessThanOrEqualTo(1));
    player.stop();
  });
}
