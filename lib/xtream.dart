import 'genre.dart';
import 'models.dart';
import 'net.dart';

/// Client de l'API « Xtream Codes » (player_api.php) utilisée par la plupart des fournisseurs IPTV.
class XtreamClient {
  XtreamClient({
    required this.server,
    required this.username,
    required this.password,
  });

  final Uri server;
  final String username;
  final String password;

  /// Accepte « monserveur.com:8080 », « http://monserveur.com:8080/ » ou même un lien complet.
  static Uri? normalize(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (!s.toLowerCase().startsWith('http://') &&
        !s.toLowerCase().startsWith('https://'))
      s = 'http://$s';
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return null;
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );
  }

  /// Reconnaît un lien M3U Xtream (…/get.php?username=…&password=…) pour en extraire les codes.
  static XtreamClient? fromPlaylistLink(Uri url) {
    if (!url.path.toLowerCase().endsWith('get.php')) return null;
    final user = url.queryParameters['username'];
    final pass = url.queryParameters['password'];
    final server = normalize(url.toString());
    if (user == null ||
        user.isEmpty ||
        pass == null ||
        pass.isEmpty ||
        server == null)
      return null;
    return XtreamClient(server: server, username: user, password: pass);
  }

  Uri _api(String? action, [Map<String, String> extra = const {}]) =>
      server.replace(
        path: '/player_api.php',
        queryParameters: {
          'username': username,
          'password': password,
          if (action != null) 'action': action,
          ...extra,
        },
      );

  String _stream(String type, String file) =>
      server.replace(pathSegments: [type, username, password, file]).toString();

  Future<AccountInfo> authenticate() async {
    final root = await fetchJson(_api(null));
    final info = root is Map ? root['user_info'] : null;
    if (info is! Map || J.integer(info['auth']) != 1)
      throw ElioError.badCredentials;
    final status = J.str(info['status']) ?? 'Active';
    if (status.toLowerCase() != 'active')
      throw ElioError("Ton abonnement n'est pas actif (statut : $status).");
    final exp = J.integer(info['exp_date']);
    return AccountInfo(
      status: status,
      expires: exp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(exp * 1000),
    );
  }

  Future<Catalog> loadCatalog() async {
    final results = await Future.wait([
      _categories(ContentKind.live),
      _items(ContentKind.live),
      _optional(_categories(ContentKind.movie)),
      _optional(_items(ContentKind.movie)),
      _optional(_categories(ContentKind.series)),
      _optional(_items(ContentKind.series)),
    ]);
    // La TV est indispensable ; films et séries sont facultatifs (certains abonnements n'en ont pas).
    final catalog = Catalog(
      categories: [
        ...results[0] as List<MediaCategory>,
        ...results[2] as List<MediaCategory>,
        ...results[4] as List<MediaCategory>,
      ],
      items: [
        ...results[1] as List<MediaItem>,
        ...results[3] as List<MediaItem>,
        ...results[5] as List<MediaItem>,
      ],
      updated: DateTime.now(),
    );
    enrichGenres(catalog);
    return catalog;
  }

  Future<List<T>> _optional<T>(Future<List<T>> f) async {
    try {
      return await f;
    } catch (_) {
      return <T>[];
    }
  }

  static const _categoryActions = {
    ContentKind.live: 'get_live_categories',
    ContentKind.movie: 'get_vod_categories',
    ContentKind.series: 'get_series_categories',
  };
  static const _itemActions = {
    ContentKind.live: 'get_live_streams',
    ContentKind.movie: 'get_vod_streams',
    ContentKind.series: 'get_series',
  };

  Future<List<MediaCategory>> _categories(ContentKind kind) async {
    final list = await fetchJson(_api(_categoryActions[kind]));
    if (list is! List) return [];
    return [
      for (final c in list.whereType<Map>())
        if (J.str(c['category_id']) != null)
          MediaCategory(
            id: '${kind.name}:${J.str(c['category_id'])}',
            name: J.str(c['category_name']) ?? 'Sans nom',
            kind: kind,
          ),
    ];
  }

  Future<List<MediaItem>> _items(ContentKind kind) async {
    final list = await fetchJson(_api(_itemActions[kind]));
    if (list is! List) return [];
    final items = <MediaItem>[];
    for (final s in list.whereType<Map>()) {
      final category = '${kind.name}:${J.str(s['category_id']) ?? '0'}';
      final name = J.str(s['name'])?.trim() ?? 'Sans nom';
      switch (kind) {
        case ContentKind.live:
          final id = J.integer(s['stream_id']);
          if (id == null) continue;
          items.add(
            MediaItem(
              id: 'live:$id',
              name: name,
              kind: kind,
              categoryId: category,
              logo: J.url(s['stream_icon']),
              streamUrl: _stream('live', '$id.ts'),
              streamId: id,
              number: J.integer(s['num']),
            ),
          );
        case ContentKind.movie:
          final id = J.integer(s['stream_id']);
          if (id == null) continue;
          items.add(
            MediaItem(
              id: 'movie:$id',
              name: name,
              kind: kind,
              categoryId: category,
              logo: J.url(s['stream_icon']),
              streamUrl: _stream(
                'movie',
                '$id.${J.str(s['container_extension']) ?? 'mp4'}',
              ),
              streamId: id,
              year: _year(s['year']),
              rating: _rating(s['rating']),
              added: J.dbl(s['added']),
              genres: parseGenres(J.str(s['genre'])),
            ),
          );
        case ContentKind.series:
          final id = J.integer(s['series_id']);
          if (id == null) continue;
          final release = J.str(s['release_date']);
          items.add(
            MediaItem(
              id: 'series:$id',
              name: name,
              kind: kind,
              categoryId: category,
              logo: J.url(s['cover']),
              seriesId: id,
              year:
                  _year(s['year']) ??
                  _year(
                    release != null && release.length >= 4
                        ? release.substring(0, 4)
                        : null,
                  ),
              rating: _rating(s['rating']),
              added: J.dbl(s['last_modified']),
              genres: parseGenres(J.str(s['genre'])),
            ),
          );
      }
    }
    return items;
  }

  static int? _year(dynamic v) {
    final y = J.integer(v);
    return (y != null && y >= 1900 && y <= 2100) ? y : null;
  }

  static double? _rating(dynamic v) {
    final r = J.dbl(v);
    return (r != null && r > 0) ? r : null;
  }

  Future<SeriesDetails> series(int seriesId) async {
    final root = await fetchJson(
      _api('get_series_info', {'series_id': '$seriesId'}),
    );
    final episodesRaw = root is Map ? root['episodes'] : null;
    List<dynamic> groups = [];
    if (episodesRaw is Map) {
      final keys = episodesRaw.keys.map((k) => k.toString()).toList()
        ..sort(
          (a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0),
        );
      groups = [for (final k in keys) episodesRaw[k]];
    } else if (episodesRaw is List) {
      groups = episodesRaw;
    }
    final episodes = <Episode>[];
    for (final group in groups) {
      if (group is! List) continue;
      for (final e in group.whereType<Map>()) {
        final id = J.str(e['id']);
        if (id == null) continue;
        final info = e['info'] is Map ? e['info'] as Map : const {};
        final number = J.integer(e['episode_num']) ?? episodes.length + 1;
        episodes.add(
          Episode(
            id: id,
            season: J.integer(e['season']) ?? 1,
            number: number,
            title: J.str(e['title']) ?? 'Épisode $number',
            url: _stream(
              'series',
              '$id.${J.str(e['container_extension']) ?? 'mp4'}',
            ),
            plot: J.str(info['plot']),
            duration: J.str(info['duration']),
          ),
        );
      }
    }
    final info = root is Map && root['info'] is Map
        ? root['info'] as Map
        : const {};
    return SeriesDetails(
      plot: J.str(info['plot']),
      cover: J.url(info['cover']),
      episodes: episodes,
    );
  }

  Future<List<EpgEntry>> shortEpg(int streamId) async {
    final root = await fetchJson(
      _api('get_short_epg', {'stream_id': '$streamId', 'limit': '4'}),
    );
    final list = root is Map && root['epg_listings'] is List
        ? root['epg_listings'] as List
        : const [];
    final now = DateTime.now();
    final entries =
        <EpgEntry>[
            for (final e in list.whereType<Map>())
              if (J.integer(e['start_timestamp']) != null &&
                  J.integer(e['stop_timestamp']) != null)
                EpgEntry(
                  title: J.base64Text(e['title']) ?? '',
                  start: DateTime.fromMillisecondsSinceEpoch(
                    J.integer(e['start_timestamp'])! * 1000,
                  ),
                  end: DateTime.fromMillisecondsSinceEpoch(
                    J.integer(e['stop_timestamp'])! * 1000,
                  ),
                ),
          ].where((e) => e.end.isAfter(now)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return entries;
  }
}
