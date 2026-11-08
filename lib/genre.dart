import 'models.dart';

/// Genres en français, reconnus dans les noms de catégories (« Movie-Action », « Series-Sci-Fi & Fantasy »)
/// et dans le champ « genre » des séries Xtream (« Drama, Mystery »).
const _table = {
  'ACTION': 'Action',
  'ADVENTURE': 'Aventure',
  'AVENTURE': 'Aventure',
  'ANIMATION': 'Animation',
  'ANIME': 'Animé',
  'CARTOON': 'Animation',
  'DESSIN ANIME': 'Animation',
  'COMEDY': 'Comédie',
  'COMEDIE': 'Comédie',
  'CRIME': 'Policier',
  'POLICIER': 'Policier',
  'DOCUMENTARY': 'Documentaire',
  'DOCUMENTAIRE': 'Documentaire',
  'DOCUMENTARIES': 'Documentaire',
  'DRAMA': 'Drame',
  'DRAME': 'Drame',
  'FAMILY': 'Famille',
  'FAMILLE': 'Famille',
  'KIDS': 'Enfants',
  'ENFANTS': 'Enfants',
  'JEUNESSE': 'Enfants',
  'FANTASY': 'Fantastique',
  'FANTASTIQUE': 'Fantastique',
  'HISTORY': 'Histoire',
  'HISTOIRE': 'Histoire',
  'HORROR': 'Horreur',
  'HORREUR': 'Horreur',
  'MUSIC': 'Musique',
  'MUSIQUE': 'Musique',
  'MYSTERY': 'Mystère',
  'MYSTERE': 'Mystère',
  'ROMANCE': 'Romance',
  'ROMANTIQUE': 'Romance',
  'SCI FI': 'Science-fiction',
  'SCIFI': 'Science-fiction',
  'SCIENCE FICTION': 'Science-fiction',
  'THRILLER': 'Thriller',
  'SUSPENSE': 'Thriller',
  'WAR': 'Guerre',
  'GUERRE': 'Guerre',
  'WESTERN': 'Western',
  'TV MOVIE': 'Téléfilm',
  'TELEFILM': 'Téléfilm',
  'REALITY': 'Téléréalité',
  'NEWS': 'Actualités',
  'TALK': 'Talk-show',
  'SOAP': 'Feuilleton',
  'POLITICS': 'Politique',
  'SPORT': 'Sport',
  'SPORTS': 'Sport',
  'CHRISTMAS': 'Noël',
  'NOEL': 'Noël',
  'KUNG FU': 'Arts martiaux',
  'MARTIAL ARTS': 'Arts martiaux',
  'CLASSIC': 'Classiques',
  'CLASSIQUE': 'Classiques',
  'BIOGRAPHY': 'Biographie',
  'BIOPIC': 'Biographie',
};

/// Mots qui précèdent souvent le genre dans un nom de catégorie.
const _fillers = {'MOVIE', 'MOVIES', 'FILM', 'FILMS', 'VOD', 'SERIES', 'SERIE'};

List<String> words(String s) =>
    foldText(s)
        .toUpperCase()
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((w) => w.isNotEmpty && RegExp(r'[A-Z]').hasMatch(w))
        .toList();

/// « Drama, Mystery » ou « Action & Adventure » → ["Drame", "Mystère"] / ["Action", "Aventure"].
List<String> parseGenres(String? raw) {
  if (raw == null) return [];
  final result = <String>[];
  for (final part in raw.split(RegExp(r'[,&/|]'))) {
    final g = _table[words(part).join(' ')];
    if (g != null && !result.contains(g)) result.add(g);
  }
  return result;
}

/// Genres d'une catégorie qui n'est QUE du genre (« Movie-Action » oui, « Movies French » non).
List<String> genresFromCategory(String name) {
  final tokens = words(name);
  while (tokens.isNotEmpty && _fillers.contains(tokens.first)) {
    tokens.removeAt(0);
  }
  final genres = <String>[];
  var i = 0;
  while (i < tokens.length) {
    if (tokens[i] == 'AND' || tokens[i] == 'ET') {
      i++;
      continue;
    }
    final length = [3, 2, 1]
        .where(
          (l) =>
              i + l <= tokens.length &&
              _table.containsKey(tokens.sublist(i, i + l).join(' ')),
        )
        .firstOrNull;
    if (length == null) return [];
    final g = _table[tokens.sublist(i, i + length).join(' ')]!;
    if (!genres.contains(g)) genres.add(g);
    i += length;
  }
  return genres;
}

/// Année entre parenthèses dans un titre : « Troll 2 (2025) » → 2025.
int? yearInTitle(String title) {
  final m = RegExp(r'[\(\[]((?:19|20)\d{2})[\)\]]').firstMatch(title);
  return m == null ? null : int.parse(m.group(1)!);
}

/// Complète genres et années : un film rangé dans « Movies French » récupère le genre de son double
/// rangé dans « Movie-Action » (même titre, même année).
void enrichGenres(Catalog catalog) {
  final categoryGenres = <String, List<String>>{};
  for (final c in catalog.categories) {
    if (c.kind == ContentKind.live) continue;
    final g = genresFromCategory(c.name);
    if (g.isNotEmpty) categoryGenres[c.id] = g;
  }
  String key(MediaItem i) => '${words(i.name).join(' ')}|${i.year ?? 0}';
  final byTitle = <String, Set<String>>{};
  for (final item in catalog.items) {
    if (item.kind == ContentKind.live) continue;
    item.year ??= yearInTitle(item.name);
    if (item.genres.isEmpty)
      item.genres = [...?categoryGenres[item.categoryId]];
    if (item.genres.isNotEmpty)
      byTitle.putIfAbsent(key(item), () => {}).addAll(item.genres);
  }
  for (final item in catalog.items) {
    if (item.kind == ContentKind.live || item.genres.isNotEmpty) continue;
    final g = byTitle[key(item)];
    if (g != null) item.genres = (g.toList()..sort());
  }
}
