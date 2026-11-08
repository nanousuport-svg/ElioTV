import 'dart:async';
import 'dart:io';

enum ContentKind {
  live('TV en direct', 'TV'),
  movie('Films', 'Films'),
  series('Séries', 'Séries');

  const ContentKind(this.title, this.shortTitle);
  final String title;
  final String shortTitle;
}

/// Clé de recherche sans accents ni majuscules (« Télé » trouve « tele »).
String foldText(String s) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝŒÆ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoaAAAAAACEEEEIIIINOOOOOUUUUYOA';
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final c = String.fromCharCode(rune);
    final i = from.indexOf(c);
    buffer.write(i >= 0 ? to[i] : c);
  }
  return buffer.toString().toLowerCase();
}

class MediaCategory {
  MediaCategory({required this.id, required this.name, required this.kind});
  final String id;
  final String name;
  final ContentKind kind;

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'k': kind.index};
  factory MediaCategory.fromJson(Map<String, dynamic> j) => MediaCategory(
    id: j['id'],
    name: j['n'],
    kind: ContentKind.values[j['k']],
  );
}

class MediaItem {
  MediaItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.categoryId,
    this.logo,
    this.streamUrl,
    this.streamId,
    this.seriesId,
    this.number,
    this.year,
    this.rating,
    this.added,
    List<String>? genres,
  }) : genres = genres ?? [],
       searchKey = foldText(name);

  final String id;
  final String name;
  final ContentKind kind;
  final String categoryId;
  final String? logo;

  /// null pour une série Xtream : les épisodes sont chargés à la demande.
  final String? streamUrl;
  final int? streamId;
  final int? seriesId;
  final int? number;
  int? year;
  final double? rating;

  /// Date d'ajout chez le fournisseur (secondes depuis 1970).
  final double? added;
  List<String> genres;
  final String searchKey;

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': name,
    'k': kind.index,
    'c': categoryId,
    if (logo != null) 'l': logo,
    if (streamUrl != null) 'u': streamUrl,
    if (streamId != null) 's': streamId,
    if (seriesId != null) 'se': seriesId,
    if (number != null) 'nu': number,
    if (year != null) 'y': year,
    if (rating != null) 'r': rating,
    if (added != null) 'a': added,
    if (genres.isNotEmpty) 'g': genres,
  };

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
    id: j['id'],
    name: j['n'],
    kind: ContentKind.values[j['k']],
    categoryId: j['c'],
    logo: j['l'],
    streamUrl: j['u'],
    streamId: j['s'],
    seriesId: j['se'],
    number: j['nu'],
    year: j['y'],
    rating: (j['r'] as num?)?.toDouble(),
    added: (j['a'] as num?)?.toDouble(),
    genres: (j['g'] as List?)?.cast<String>(),
  );
}

class Catalog {
  Catalog({
    List<MediaCategory>? categories,
    List<MediaItem>? items,
    DateTime? updated,
  }) : categories = categories ?? [],
       items = items ?? [],
       updated = updated ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// À augmenter quand le format change : les anciennes listes en cache sont alors rechargées.
  static const version = 1;

  final List<MediaCategory> categories;
  final List<MediaItem> items;
  final DateTime updated;

  Map<String, dynamic> toJson() => {
    'v': version,
    'updated': updated.millisecondsSinceEpoch,
    'categories': categories.map((c) => c.toJson()).toList(),
    'items': items.map((i) => i.toJson()).toList(),
  };

  static Catalog? fromJson(Map<String, dynamic> j) {
    if (j['v'] != version) return null;
    return Catalog(
      updated: DateTime.fromMillisecondsSinceEpoch(j['updated']),
      categories: (j['categories'] as List)
          .map((c) => MediaCategory.fromJson(c))
          .toList(),
      items: (j['items'] as List).map((i) => MediaItem.fromJson(i)).toList(),
    );
  }
}

enum SourceType { xtream, m3uUrl, m3uFile }

class Profile {
  Profile({
    String? id,
    required this.name,
    required this.type,
    required this.value,
    this.username,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final String name;
  final SourceType type;

  /// Adresse du serveur Xtream, lien M3U ou chemin du fichier.
  final String value;
  final String? username;

  String get subtitle => switch (type) {
    SourceType.xtream => '$username · ${Uri.tryParse(value)?.host ?? value}',
    SourceType.m3uUrl => Uri.tryParse(value)?.host ?? 'Lien M3U',
    SourceType.m3uFile => value.split(Platform.pathSeparator).last,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.index,
    'value': value,
    'user': username,
  };
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'],
    name: j['name'],
    type: SourceType.values[j['type']],
    value: j['value'],
    username: j['user'],
  );
}

class Episode {
  Episode({
    required this.id,
    required this.season,
    required this.number,
    required this.title,
    required this.url,
    this.plot,
    this.duration,
  });
  final String id;
  final int season;
  final int number;
  final String title;
  final String url;
  final String? plot;
  final String? duration;
}

class SeriesDetails {
  SeriesDetails({this.plot, this.cover, required this.episodes});
  final String? plot;
  final String? cover;
  final List<Episode> episodes;

  List<int> get seasons =>
      (episodes.map((e) => e.season).toSet().toList()..sort());
}

class EpgEntry {
  EpgEntry({required this.title, required this.start, required this.end});
  final String title;
  final DateTime start;
  final DateTime end;

  double progress(DateTime now) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (now.difference(start).inSeconds / total).clamp(0, 1).toDouble();
  }
}

class AccountInfo {
  AccountInfo({required this.status, this.expires});
  final String status;
  final DateTime? expires;
}

class ElioError implements Exception {
  ElioError(this.message);
  final String message;

  static final invalidServer = ElioError(
    "L'adresse du serveur n'est pas valide. Exemple : http://monserveur.com:8080",
  );
  static final invalidUrl = ElioError(
    "Ce lien n'est pas valide. Il doit commencer par http:// ou https://",
  );
  static final badCredentials = ElioError(
    "Nom d'utilisateur ou mot de passe refusé par le fournisseur.",
  );
  static final badResponse = ElioError(
    "Réponse inattendue du serveur. Vérifie l'adresse donnée par ton fournisseur.",
  );
  static final emptyPlaylist = ElioError('La liste ne contient aucune chaîne.');
  static final missingPassword = ElioError(
    'Mot de passe introuvable. Supprime ce fournisseur puis ajoute-le à nouveau.',
  );

  static String describe(Object error) {
    if (error is ElioError) return error.message;
    if (error is TimeoutException)
      return 'Le serveur met trop de temps à répondre. Réessaie dans un instant.';
    if (error is SocketException) {
      final m = error.message.toLowerCase();
      if (m.contains('lookup') || m.contains('host'))
        return 'Serveur introuvable. Vérifie l\'adresse.';
      return 'Impossible de joindre le serveur (adresse, port ou connexion internet ?).';
    }
    if (error is FormatException) return badResponse.message;
    return error.toString();
  }

  @override
  String toString() => message;
}
