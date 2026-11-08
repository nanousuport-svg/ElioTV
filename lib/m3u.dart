import 'dart:convert';

import 'genre.dart';
import 'models.dart';

/// Lit les playlists M3U / M3U Plus (#EXTINF avec tvg-logo, group-title…).
Catalog parseM3U(List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final items = <MediaItem>[];
  final categories = <MediaCategory>[];
  final knownCategories = <String>{};
  final usedIds = <String>{};

  String? pendingName;
  var pendingAttrs = <String, String>{};
  String? pendingGroup;

  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTINF')) {
      final (attrs, title) = _splitInfo(line);
      pendingAttrs = attrs;
      pendingName = title;
      continue;
    }
    if (line.startsWith('#EXTGRP:')) {
      pendingGroup = line.substring(8).trim();
      continue;
    }
    if (line.startsWith('#')) continue;

    final url = Uri.tryParse(line);
    if (url == null || !url.hasScheme) {
      pendingName = null;
      continue;
    }

    final kind = _kindOf(url);
    final groupAttr = pendingAttrs['group-title'];
    final group = (groupAttr != null && groupAttr.isNotEmpty)
        ? groupAttr
        : (pendingGroup ?? 'Sans catégorie');
    final categoryId = '${kind.name}:$group';
    if (knownCategories.add(categoryId))
      categories.add(MediaCategory(id: categoryId, name: group, kind: kind));

    final name = (pendingName != null && pendingName.isNotEmpty)
        ? pendingName
        : (pendingAttrs['tvg-name'] ?? url.pathSegments.lastOrNull ?? line);
    var id = line;
    for (var n = 2; !usedIds.add(id); n++) {
      id = '$line#$n';
    }
    final logo = pendingAttrs['tvg-logo'];
    items.add(
      MediaItem(
        id: id,
        name: name,
        kind: kind,
        categoryId: categoryId,
        logo: (logo != null && logo.startsWith('http')) ? logo : null,
        streamUrl: line,
        number: int.tryParse(pendingAttrs['tvg-chno'] ?? ''),
      ),
    );
    pendingName = null;
    pendingAttrs = {};
    pendingGroup = null;
  }
  final catalog = Catalog(
    categories: categories,
    items: items,
    updated: DateTime.now(),
  );
  enrichGenres(catalog);
  return catalog;
}

ContentKind _kindOf(Uri url) {
  final path = url.path.toLowerCase();
  if (path.contains('/movie/')) return ContentKind.movie;
  if (path.contains('/series/')) return ContentKind.series;
  if (RegExp(r'\.(mp4|mkv|avi|mov|m4v)$').hasMatch(path))
    return ContentKind.movie;
  return ContentKind.live;
}

/// Sépare `#EXTINF:-1 tvg-logo="…" group-title="…",Nom de la chaîne` en attributs + titre.
(Map<String, String>, String) _splitInfo(String line) {
  var inQuotes = false;
  var comma = -1;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (c == ',' && !inQuotes) {
      comma = i;
      break;
    }
  }
  final head = comma >= 0 ? line.substring(0, comma) : line;
  final title = comma >= 0 ? line.substring(comma + 1).trim() : '';
  final attrs = <String, String>{};
  for (final m in RegExp(r'([\w-]+)="([^"]*)"').allMatches(head)) {
    attrs[m.group(1)!.toLowerCase()] = m.group(2)!.trim();
  }
  return (attrs, title);
}
