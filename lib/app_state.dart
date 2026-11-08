import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'country.dart';
import 'm3u.dart';
import 'models.dart';
import 'net.dart';
import 'player.dart';
import 'storage.dart';
import 'xtream.dart';

enum SortOrder {
  provider('Ordre du fournisseur'),
  yearDesc("Année (plus récents d'abord)"),
  added('Ajouts récents'),
  rating('Mieux notés'),
  name('Nom (A → Z)');

  const SortOrder(this.title);
  final String title;
}

/// Filtre d'année : une année précise, une décennie ou « avant 1980 ».
class YearFilter {
  const YearFilter(this.id, this.label, this.from, this.to);
  final String id;
  final String label;
  final int from;
  final int to;

  factory YearFilter.year(int y) => YearFilter('y$y', '$y', y, y);
  factory YearFilter.decade(int d) => YearFilter('d$d', 'Années $d', d, d + 9);
  static const old = YearFilter('old', 'Avant 1980', 1900, 1979);

  bool contains(int? year) => year != null && year >= from && year <= to;

  @override
  bool operator ==(Object other) => other is YearFilter && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class AppState extends ChangeNotifier {
  static const allId = '__all', favoritesId = '__fav', recentsId = '__recent';

  final player = PlayerController();

  List<Profile> profiles = Storage.loadProfiles();
  Profile? active;
  AccountInfo? account;
  Catalog catalog = Catalog();
  bool isLoading = false;
  bool isRefreshing = false;
  String loadingMessage = '';
  String? error;

  ContentKind _kind = ContentKind.live;
  String? _country;
  String _category = allId;
  String _search = '';
  String? _genre;
  YearFilter? _yearFilter;
  SortOrder _sortOrder = SortOrder.provider;

  List<MediaItem> visible = [];
  MediaItem? selectedItem;
  Set<String> favorites = {};
  List<String> recents = [];
  List<EpgEntry> epg = [];
  SeriesDetails? series;
  bool isLoadingSeries = false;
  String? playingEpisodeId;

  List<(String, int)> genreOptions = [];
  List<YearFilter> yearOptions = [];
  String _facetsKey = '';

  final Map<String, MediaItem> _itemsById = {};
  final Map<ContentKind, List<MediaItem>> _itemsByKind = {};
  final Map<ContentKind, List<MediaCategory>> _categoriesByKind = {};
  final Map<String, int> counts = {};
  List<ContentKind> availableKinds = [];
  final Map<String, String> _categoryCountry = {};
  final Map<String, String> _categoryNames = {};
  final Map<String, String> _itemCountry = {};
  final Map<ContentKind, List<(String, int)>> _countriesByKind = {};
  int _detailToken = 0;

  // MARK: Accès en lecture

  ContentKind get kind => _kind;
  String? get country => _country;
  String get category => _category;
  String get search => _search;
  String? get genre => _genre;
  YearFilter? get yearFilter => _yearFilter;
  SortOrder get sortOrder => _sortOrder;

  List<(String, int)> get countries => _countriesByKind[_kind] ?? [];

  List<MediaCategory> get categories {
    final all = _categoriesByKind[_kind] ?? [];
    if (_country == null) return all;
    return all
        .where((c) => (_categoryCountry[c.id] ?? Country.other) == _country)
        .toList();
  }

  int get totalCount => _itemsForCountry.length;

  List<MediaItem> get _itemsForCountry {
    final list = _itemsByKind[_kind] ?? [];
    if (_country == null) return list;
    return list
        .where((i) => (_itemCountry[i.id] ?? Country.other) == _country)
        .toList();
  }

  /// Nom de catégorie sans le préfixe pays (« FR | Sport » → « Sport »).
  String displayName(MediaCategory c) => _categoryNames[c.id] ?? c.name;

  String? categoryName(String id) {
    for (final c in catalog.categories) {
      if (c.id == id) return displayName(c);
    }
    return null;
  }

  bool isFavorite(MediaItem item) => favorites.contains(item.id);

  // MARK: Navigation

  set kind(ContentKind value) {
    if (value == _kind) return;
    _kind = value;
    _genre = null;
    _yearFilter = null;
    _sortOrder = value == ContentKind.live
        ? SortOrder.provider
        : SortOrder.values.asNameMap()[Storage.prefs.getString(
                'sort.${value.name}',
              )] ??
              SortOrder.yearDesc;
    _category = allId;
    _search = '';
    _update();
  }

  set country(String? value) {
    if (value == _country) return;
    _country = value;
    final id = active?.id;
    if (id != null) {
      value == null
          ? Storage.prefs.remove('country.$id')
          : Storage.prefs.setString('country.$id', value);
    }
    if (!_category.startsWith('__') &&
        !categories.any((c) => c.id == _category))
      _category = allId;
    _update();
  }

  set category(String value) {
    _category = value;
    _update();
  }

  set search(String value) {
    _search = value;
    _update();
  }

  set genre(String? value) {
    _genre = value;
    _update();
  }

  set yearFilter(YearFilter? value) {
    _yearFilter = value;
    _update();
  }

  set sortOrder(SortOrder value) {
    _sortOrder = value;
    if (_kind != ContentKind.live)
      Storage.prefs.setString('sort.${_kind.name}', value.name);
    _update();
  }

  void clearFilters() {
    _genre = null;
    _yearFilter = null;
    _update();
  }

  // MARK: Connexion

  Future<void> connectXtream(
    String server,
    String username,
    String password,
    String name,
  ) async {
    final url = XtreamClient.normalize(server);
    if (url == null) return _fail(ElioError.invalidServer);
    final client = XtreamClient(
      server: url,
      username: username.trim(),
      password: password.trim(),
    );
    _setLoading('Connexion au serveur…');
    try {
      final info = await client.authenticate();
      final profile = Profile(
        name: name.isEmpty ? url.host : name,
        type: SourceType.xtream,
        value: url.toString(),
        username: client.username,
      );
      Storage.setPassword(profile.id, client.password);
      _add(profile);
      await open(profile, forceRefresh: true);
      account = info;
    } catch (e) {
      _fail(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connectM3U(String link, String name) async {
    final url = Uri.tryParse(link.trim());
    if (url == null || !(url.scheme == 'http' || url.scheme == 'https'))
      return _fail(ElioError.invalidUrl);
    // Un lien get.php contient des codes Xtream : on les utilise (catégories, films, séries, guide TV).
    final xtream = XtreamClient.fromPlaylistLink(url);
    if (xtream != null)
      return connectXtream(
        xtream.server.toString(),
        xtream.username,
        xtream.password,
        name,
      );
    await _addAndOpen(
      Profile(
        name: name.isEmpty ? url.host : name,
        type: SourceType.m3uUrl,
        value: link.trim(),
      ),
    );
  }

  Future<void> connectM3UFile(String path) async {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    await _addAndOpen(
      Profile(
        name: fileName.replaceAll(RegExp(r'\.m3u8?$'), ''),
        type: SourceType.m3uFile,
        value: path,
      ),
    );
  }

  Future<void> _addAndOpen(Profile profile) async {
    _setLoading('Lecture de la playlist…');
    try {
      final c = await _fetchCatalog(profile);
      if (c.items.isEmpty) throw ElioError.emptyPlaylist;
      _add(profile);
      await open(profile, preloaded: c);
    } catch (e) {
      _fail(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _add(Profile profile) {
    profiles = [...profiles, profile];
    Storage.saveProfiles(profiles);
  }

  void deleteProfile(Profile profile) {
    if (active?.id == profile.id) signOut();
    profiles = profiles.where((p) => p.id != profile.id).toList();
    Storage.saveProfiles(profiles);
    Storage.deleteCatalog(profile.id);
    Storage.setPassword(profile.id, null);
    for (final k in ['fav', 'recent', 'country']) {
      Storage.prefs.remove('$k.${profile.id}');
    }
    notifyListeners();
  }

  Future<void> open(
    Profile profile, {
    bool forceRefresh = false,
    Catalog? preloaded,
  }) async {
    player.stop();
    active = profile;
    account = null;
    _clearDetail();
    favorites = (Storage.prefs.getStringList('fav.${profile.id}') ?? [])
        .toSet();
    recents = Storage.prefs.getStringList('recent.${profile.id}') ?? [];
    _country = Storage.prefs.getString('country.${profile.id}');
    _kind = ContentKind.live;
    _sortOrder = SortOrder.provider;
    _category = allId;
    _search = '';
    _genre = null;
    _yearFilter = null;

    if (preloaded != null) {
      _apply(preloaded);
      unawaited(Storage.saveCatalog(profile.id, preloaded));
      return;
    }
    _apply(Catalog());
    if (!forceRefresh) {
      final cached = await Storage.loadCatalog(profile.id);
      if (cached != null && active?.id == profile.id) {
        _apply(cached);
        _refreshAccount();
        if (DateTime.now().difference(cached.updated) <
            const Duration(hours: 12))
          return;
      }
    }
    await refresh();
  }

  void signOut() {
    player.stop();
    active = null;
    account = null;
    _clearDetail();
    _apply(Catalog());
  }

  Future<void> refresh() async {
    final profile = active;
    if (profile == null || isRefreshing) return;
    isRefreshing = true;
    // Premier chargement : la TV s'affiche dès qu'elle est prête, films et séries suivent.
    // Sinon la liste en cache reste affichée jusqu'à ce que la nouvelle soit complète.
    final firstLoad = catalog.items.isEmpty;
    if (firstLoad) _setLoading('Chargement des chaînes…');
    notifyListeners();
    try {
      final fresh = await _fetchCatalog(
        profile,
        onLive: firstLoad
            ? (live) {
                if (active?.id != profile.id) return;
                _apply(live);
                isLoading = false;
                notifyListeners();
              }
            : null,
      );
      if (active?.id != profile.id) return;
      if (fresh.items.isEmpty) throw ElioError.emptyPlaylist;
      _apply(fresh);
      unawaited(Storage.saveCatalog(profile.id, fresh));
    } catch (e) {
      _fail(e);
    } finally {
      isRefreshing = false;
      isLoading = false;
      notifyListeners();
    }
  }

  void _refreshAccount() {
    final client = _client(active);
    if (client == null) return;
    client
        .authenticate()
        .then((info) {
          account = info;
          notifyListeners();
        })
        .catchError((_) {});
  }

  /// Téléchargement et analyse dans un isolate : l'interface reste fluide.
  /// Pour Xtream, [onLive] reçoit la TV dès qu'elle est chargée, avant les films et séries.
  Future<Catalog> _fetchCatalog(
    Profile profile, {
    void Function(Catalog live)? onLive,
  }) async {
    switch (profile.type) {
      case SourceType.xtream:
        final client = _client(profile);
        if (client == null) throw ElioError.missingPassword;
        final live = await _xtreamLive(
          client,
          _progress('Chargement des chaînes'),
        );
        if (live.items.isEmpty) throw ElioError.emptyPlaylist;
        onLive?.call(live);
        var library = Catalog();
        try {
          library = await _xtreamLibrary(
            client,
            _progress('Chargement des films et séries'),
          );
        } catch (_) {
          // Films et séries indisponibles : la TV reste utilisable.
        }
        return Catalog(
          categories: [...live.categories, ...library.categories],
          items: [...live.items, ...library.items],
          updated: DateTime.now(),
        );
      case SourceType.m3uUrl:
        return _m3uUrl(
          Uri.parse(profile.value),
          _progress('Chargement de la playlist'),
        );
      case SourceType.m3uFile:
        final path = profile.value;
        return Isolate.run(() async => parseM3U(await _readFile(path)));
    }
  }

  /// Affiche la quantité reçue sur l'écran de chargement, pour qu'on voie que ça avance.
  void Function(int) _progress(String label) => (bytes) {
    if (!isLoading) return;
    loadingMessage = '$label… ${formatBytes(bytes)} reçus';
    notifyListeners();
  };

  XtreamClient? _client(Profile? profile) {
    if (profile == null || profile.type != SourceType.xtream) return null;
    final password = Storage.password(profile.id);
    final server = Uri.tryParse(profile.value);
    if (password == null || server == null) return null;
    return XtreamClient(
      server: server,
      username: profile.username ?? '',
      password: password,
    );
  }

  void _setLoading(String message) {
    isLoading = true;
    loadingMessage = message;
    notifyListeners();
  }

  void _fail(Object e) {
    error = ElioError.describe(e);
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  // MARK: Liste

  void _apply(Catalog c) {
    catalog = c;
    _itemsById
      ..clear()
      ..addEntries(c.items.map((i) => MapEntry(i.id, i)));
    _itemsByKind.clear();
    counts.clear();
    for (final item in c.items) {
      _itemsByKind.putIfAbsent(item.kind, () => []).add(item);
      counts[item.categoryId] = (counts[item.categoryId] ?? 0) + 1;
    }
    _categoriesByKind.clear();
    for (final cat in c.categories) {
      if ((counts[cat.id] ?? 0) > 0)
        _categoriesByKind.putIfAbsent(cat.kind, () => []).add(cat);
    }
    availableKinds = ContentKind.values
        .where((k) => (_itemsByKind[k]?.isNotEmpty ?? false))
        .toList();
    if (availableKinds.isNotEmpty && !availableKinds.contains(_kind))
      _kind = availableKinds.first;
    _detectCountries(c);
    _facetsKey = '';
    _update();
  }

  void _detectCountries(Catalog c) {
    _categoryCountry.clear();
    _categoryNames.clear();
    for (final cat in c.categories) {
      final found = Country.detect(cat.name);
      if (found != null) {
        _categoryCountry[cat.id] = found.$1;
        if (found.$2.isNotEmpty) _categoryNames[cat.id] = found.$2;
      } else {
        final code = Country.detectAnywhere(cat.name);
        if (code != null) _categoryCountry[cat.id] = code;
      }
    }
    // Une chaîne prend le pays de sa catégorie, sinon celui de son nom (« FR: TF1 »).
    // Jamais pour les films et séries : leur titre trompe (« Madagascar 3 », « IT »).
    _itemCountry.clear();
    for (final item in c.items) {
      final code =
          _categoryCountry[item.categoryId] ??
          (item.kind == ContentKind.live
              ? Country.detect(item.name)?.$1
              : null);
      if (code != null) _itemCountry[item.id] = code;
    }
    _countriesByKind.clear();
    for (final k in ContentKind.values) {
      final tally = <String, int>{};
      for (final item in _itemsByKind[k] ?? const <MediaItem>[]) {
        final code = _itemCountry[item.id] ?? Country.other;
        tally[code] = (tally[code] ?? 0) + 1;
      }
      // Sans aucun pays reconnu, le filtre n'a pas de sens : on le masque.
      if (!tally.keys.any((code) => code != Country.other)) continue;
      _countriesByKind[k] = tally.entries.map((e) => (e.key, e.value)).toList()
        ..sort(
          (a, b) => (b.$1 == Country.other ? 0 : b.$2).compareTo(
            a.$1 == Country.other ? 0 : a.$2,
          ),
        );
    }
    if (c.items.isNotEmpty &&
        _country != null &&
        !_countriesByKind.values.any((l) => l.any((e) => e.$1 == _country))) {
      _country = null;
    }
  }

  void _update() {
    final list = _itemsForCountry;
    _refreshFacets(list);
    var base = switch (_category) {
      allId => list,
      // Favoris et récents restent visibles quel que soit le pays choisi.
      favoritesId =>
        (_itemsByKind[_kind] ?? [])
            .where((i) => favorites.contains(i.id))
            .toList(),
      recentsId =>
        recents
            .map((id) => _itemsById[id])
            .whereType<MediaItem>()
            .where((i) => i.kind == _kind)
            .toList(),
      _ => list.where((i) => i.categoryId == _category).toList(),
    };
    // Genre et année s'ajoutent au pays (la langue) et à la catégorie.
    if (_genre != null)
      base = base.where((i) => i.genres.contains(_genre)).toList();
    if (_yearFilter != null)
      base = base.where((i) => _yearFilter!.contains(i.year)).toList();
    final query = foldText(_search.trim());
    if (query.isNotEmpty)
      base = base.where((i) => i.searchKey.contains(query)).toList();
    if (_category != recentsId) base = _sorted(base);
    visible = base;
    notifyListeners();
  }

  List<MediaItem> _sorted(List<MediaItem> items) {
    if (_sortOrder == SortOrder.provider) return items;
    final copy = [...items];
    int byNum(num? a, num? b) => (b ?? 0).compareTo(a ?? 0);
    switch (_sortOrder) {
      case SortOrder.yearDesc:
        copy.sort(
          (a, b) => byNum(a.year, b.year) != 0
              ? byNum(a.year, b.year)
              : byNum(a.added, b.added),
        );
      case SortOrder.added:
        copy.sort((a, b) => byNum(a.added, b.added));
      case SortOrder.rating:
        copy.sort(
          (a, b) => byNum(a.rating, b.rating) != 0
              ? byNum(a.rating, b.rating)
              : byNum(a.year, b.year),
        );
      case SortOrder.name:
        copy.sort((a, b) => a.searchKey.compareTo(b.searchKey));
      case SortOrder.provider:
        break;
    }
    return copy;
  }

  /// Genres et années proposés : ceux qui existent pour l'onglet et le pays choisis.
  void _refreshFacets(List<MediaItem> list) {
    final key =
        '${_kind.name}|$_country|${catalog.updated.millisecondsSinceEpoch}';
    if (key == _facetsKey) return;
    _facetsKey = key;
    if (_kind == ContentKind.live) {
      genreOptions = [];
      yearOptions = [];
      return;
    }
    final genreCount = <String, int>{};
    final years = <int>{};
    for (final item in list) {
      for (final g in item.genres) {
        genreCount[g] = (genreCount[g] ?? 0) + 1;
      }
      if (item.year != null) years.add(item.year!);
    }
    genreOptions = genreCount.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => foldText(a.$1).compareTo(foldText(b.$1)));
    // Les 6 dernières années une par une, puis par décennie.
    final recent = (years.toList()..sort((a, b) => b.compareTo(a)))
        .take(6)
        .toList();
    final options = recent.map(YearFilter.year).toList();
    final oldestRecent = recent.isEmpty ? 3000 : recent.last;
    for (var decade = 2020; decade >= 1980; decade -= 10) {
      if (years.any((y) => y >= decade && y <= decade + 9 && y < oldestRecent))
        options.add(YearFilter.decade(decade));
    }
    if (years.any((y) => y < 1980)) options.add(YearFilter.old);
    yearOptions = options;
    if (_genre != null && !genreCount.containsKey(_genre)) _genre = null;
    if (_yearFilter != null && !options.contains(_yearFilter))
      _yearFilter = null;
  }

  void toggleFavorite(MediaItem item) {
    favorites.contains(item.id)
        ? favorites.remove(item.id)
        : favorites.add(item.id);
    final id = active?.id;
    if (id != null) Storage.prefs.setStringList('fav.$id', favorites.toList());
    _update();
  }

  void _addRecent(MediaItem item) {
    recents = [
      item.id,
      ...recents.where((r) => r != item.id),
    ].take(60).toList();
    final id = active?.id;
    if (id != null) Storage.prefs.setStringList('recent.$id', recents);
  }

  // MARK: Lecture

  void _clearDetail() {
    _detailToken++;
    selectedItem = null;
    epg = [];
    series = null;
    isLoadingSeries = false;
    playingEpisodeId = null;
  }

  /// Sélectionne un élément : une chaîne ou un film démarre aussitôt, une série charge ses épisodes.
  void select(MediaItem item) {
    _clearDetail();
    selectedItem = item;
    final token = _detailToken;
    final client = _client(active);
    final url = item.streamUrl;
    if (url != null) {
      player.play(url, item.name, live: item.kind == ContentKind.live);
      _addRecent(item);
      if (item.kind == ContentKind.live &&
          item.streamId != null &&
          client != null) {
        client
            .shortEpg(item.streamId!)
            .then((entries) {
              if (token != _detailToken) return;
              epg = entries;
              notifyListeners();
            })
            .catchError((_) {});
      }
    } else if (item.seriesId != null && client != null) {
      player.stop();
      isLoadingSeries = true;
      _addRecent(item);
      client
          .series(item.seriesId!)
          .then((details) {
            if (token != _detailToken) return;
            series = details;
          })
          .catchError((Object e) {
            if (token == _detailToken) error = ElioError.describe(e);
          })
          .whenComplete(() {
            if (token != _detailToken) return;
            isLoadingSeries = false;
            notifyListeners();
          });
    }
    notifyListeners();
  }

  /// Chaîne précédente / suivante dans la liste affichée (zapping au clavier ou à la télécommande).
  void zap(int delta) {
    final current = selectedItem;
    if (current == null || visible.isEmpty) return;
    final index = visible.indexWhere((i) => i.id == current.id);
    final next = visible[((index < 0 ? 0 : index) + delta) % visible.length];
    if (next.streamUrl != null) select(next);
  }

  void playEpisode(Episode episode) {
    playingEpisodeId = episode.id;
    player.play(
      episode.url,
      '${selectedItem?.name ?? ''} · S${episode.season} É${episode.number}',
      live: false,
    );
    notifyListeners();
  }
}

Future<List<int>> _readFile(String path) async {
  return await File(path).readAsBytes();
}

// Fonctions de premier niveau : une fermeture créée dans AppState emporterait l'état entier
// (lecteur vidéo compris) vers l'isolate, ce qui est impossible.

Future<Catalog> _xtreamLive(XtreamClient client, void Function(int) progress) =>
    _inIsolate((send) => client.loadLive(onProgress: send), progress);

Future<Catalog> _xtreamLibrary(
  XtreamClient client,
  void Function(int) progress,
) => _inIsolate((send) => client.loadLibrary(onProgress: send), progress);

Future<Catalog> _m3uUrl(Uri url, void Function(int) progress) => _inIsolate(
  (send) async => parseM3U(await fetchBytes(url, onProgress: send)),
  progress,
);

/// Lance [task] dans un isolate et relaie sa progression (octets reçus) vers [progress].
Future<T> _inIsolate<T>(
  Future<T> Function(void Function(Object?) send) task,
  void Function(int) progress,
) async {
  final port = ReceivePort();
  port.cast<int>().listen(progress);
  final send = port.sendPort;
  try {
    return await Isolate.run(() => task(send.send));
  } finally {
    port.close();
  }
}
