import 'package:eliotv/app_state.dart';
import 'package:eliotv/main.dart';
import 'package:eliotv/models.dart';
import 'package:eliotv/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

/// Choix des langues : proposé au premier chargement, puis seules les chaînes, films et séries
/// des langues cochées restent visibles, dans toutes les rubriques.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Catalog sample() {
    final categories = <MediaCategory>[];
    final items = <MediaItem>[];
    void add(ContentKind kind, String category, List<String> names) {
      final id = '${kind.name}:${categories.length}';
      categories.add(MediaCategory(id: id, name: category, kind: kind));
      for (final n in names) {
        items.add(
          MediaItem(
            id: '${kind.name}:${items.length}',
            name: n,
            kind: kind,
            categoryId: id,
            streamUrl: kind == ContentKind.series ? null : 'http://x/$n',
            seriesId: kind == ContentKind.series ? items.length : null,
          ),
        );
      }
    }

    add(ContentKind.live, 'FR| Généraliste', ['TF1', 'France 2', 'M6']);
    add(ContentKind.live, 'BE| Belgique', ['RTL TVI', 'La Une']);
    add(ContentKind.live, 'UK| News', ['BBC One', 'Sky News']);
    add(ContentKind.live, 'DE| Sport', ['Sky Sport DE']);
    add(ContentKind.live, 'AR| Arabic', ['Al Jazeera', 'MBC 1', 'Rotana']);
    add(ContentKind.movie, 'FR - Action', ['Le Chant du loup', 'Balle perdue']);
    add(ContentKind.movie, 'EN - Comedy', ['The Mask', 'Superbad', 'Hangover']);
    add(ContentKind.movie, 'TR - Dram', ['Kış Uykusu']);
    add(ContentKind.series, 'FR Séries', ['Lupin', 'Dix pour cent']);
    add(ContentKind.series, 'TR Diziler', ['Diriliş Ertuğrul']);
    return Catalog(categories: categories, items: items, updated: DateTime.now());
  }

  testWidgets('seules les langues choisies restent visibles', (tester) async {
    MediaKit.ensureInitialized();
    await Storage.init(forTests: true);
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
    final profile = Profile(
      name: 'Langues',
      type: SourceType.m3uUrl,
      value: 'http://x/list.m3u',
    );
    await state.open(profile, preloaded: sample());
    await tester.pumpAndSettle();

    // Premier chargement : la fenêtre « Mes langues » s'ouvre d'elle-même.
    expect(find.text('Mes langues'), findsOneWidget);
    debugPrint(
      'RÉSULTAT langues proposées : '
      '${state.languageOptions.map((e) => '${e.$1}=${e.$2}').join(', ')}',
    );
    await tester.tap(find.text('🇫🇷 France'));
    await tester.tap(find.text('🇧🇪 Belgique'));
    await tester.pump();
    await tester.tap(find.text('Valider (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Mes langues'), findsNothing);

    List<String> names(ContentKind k) {
      state.kind = k;
      return state.visible.map((i) => i.name).toList()..sort();
    }

    final live = names(ContentKind.live);
    final movies = names(ContentKind.movie);
    final series = names(ContentKind.series);
    debugPrint('RÉSULTAT TV : $live | films : $movies | séries : $series');
    expect(live, ['France 2', 'La Une', 'M6', 'RTL TVI', 'TF1']);
    expect(movies, ['Balle perdue', 'Le Chant du loup']);
    expect(series, ['Dix pour cent', 'Lupin']);
    state.kind = ContentKind.live;
    expect(state.categories.map((c) => c.name), ['FR| Généraliste', 'BE| Belgique']);

    // Le choix est mémorisé pour ce fournisseur, et n'est plus redemandé.
    expect(Storage.prefs.getStringList('languages.${profile.id}')?.toSet(), {'FR', 'BE'});
    expect(state.shouldAskLanguages, isFalse);

    // « Tout afficher » remet toutes les langues.
    state.languages = {};
    expect(names(ContentKind.live).length, 11);
    state.deleteProfile(profile);
  });
}
