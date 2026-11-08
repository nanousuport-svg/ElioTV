import 'dart:convert';

import 'package:eliotv/country.dart';
import 'package:eliotv/genre.dart';
import 'package:eliotv/m3u.dart';
import 'package:eliotv/models.dart';
import 'package:eliotv/net.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pays en tête de catégorie (TV)', () {
    final cases = {
      'FR | Sport': ('FR', 'Sport'),
      '|FR| CINEMA': ('FR', 'CINEMA'),
      '[DE] Kino': ('DE', 'Kino'),
      'UK: News': ('GB', 'News'),
      'FRANCE - Cinéma': ('FR', 'Cinéma'),
      '🇮🇹 Calcio': ('IT', 'Calcio'),
      'AR | MBC': ('ARABE', 'MBC'),
      'EXYU | Film': ('EXYU', 'Film'),
      'BE| RTBF': ('BE', 'RTBF'),
      'USA NBA': ('US', 'NBA'),
      'ALLEMAGNE | Doc': ('DE', 'Doc'),
      'Portugal ▶ Desporto': ('PT', 'Desporto'),
      'FR: TF1 HD': ('FR', 'TF1 HD'),
      'IRE: Ireland General': ('IE', 'Ireland General'),
    };
    cases.forEach((name, expected) => expect(Country.detect(name), expected, reason: name));
    for (final name in ['4K | Sport', 'VIP Sport', 'Sport', "It's Comedy", 'TV Shows', 'Movie-Action']) {
      expect(Country.detect(name), isNull, reason: name);
    }
  });

  test('pays n\'importe où (films et séries)', () {
    final cases = {
      'Movies French': 'FR',
      'Movies Germany': 'DE',
      'Movies Turkey': 'TR',
      'Spanish Series': 'ES',
      'Series Greece': 'GR',
      'Saudi Arabia Series': 'SA',
      'Turkish Series Translated to Arabic': 'ARABE',
      'Movies-Bollywood': 'IN',
    };
    cases.forEach((name, code) => expect(Country.detectAnywhere(name), code, reason: name));
    for (final name in ['Movie-Action', 'Movies-New Releases', 'Server 2', 'NetFlix Series (Multi-Lang)']) {
      expect(Country.detectAnywhere(name), isNull, reason: name);
    }
    expect(Country.label('FR'), '🇫🇷 France');
  });

  test('genres', () {
    expect(genresFromCategory('Movie-Action'), ['Action']);
    expect(genresFromCategory('Series-Sci-Fi & Fantasy'), ['Science-fiction', 'Fantastique']);
    expect(genresFromCategory('Movie-TV Movie'), ['Téléfilm']);
    expect(genresFromCategory('Movies French'), isEmpty);
    expect(genresFromCategory('Movies-New Releases'), isEmpty);
    expect(parseGenres('Animation, Sci-Fi & Fantasy, Action & Adventure'),
        ['Animation', 'Science-fiction', 'Fantastique', 'Action', 'Aventure']);
    expect(yearInTitle('Troll 2 (2025)'), 2025);
  });

  test('un film en catégorie langue récupère le genre de son double', () {
    final catalog = Catalog(categories: [
      MediaCategory(id: 'movie:1', name: 'Movie-Action', kind: ContentKind.movie),
      MediaCategory(id: 'movie:2', name: 'Movies French', kind: ContentKind.movie),
    ], items: [
      MediaItem(id: 'a', name: 'John Wick: Chapter 4 (2023)', kind: ContentKind.movie, categoryId: 'movie:1'),
      MediaItem(id: 'b', name: 'John Wick: Chapter 4 (2023)', kind: ContentKind.movie, categoryId: 'movie:2'),
    ]);
    enrichGenres(catalog);
    expect(catalog.items[1].genres, ['Action']);
    expect(catalog.items[1].year, 2023);
  });

  test('lecture M3U', () {
    const text = '''#EXTM3U
#EXTINF:-1 tvg-id="demo" tvg-logo="http://logo/x.png" group-title="Démo, test",Mux Test HD
https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8
#EXTINF:-1 group-title="Films",Big Buck Bunny (2008)
https://example.com/movie/u/p/1.mp4
''';
    final c = parseM3U(utf8.encode(text));
    expect(c.items.map((i) => i.name), ['Mux Test HD', 'Big Buck Bunny (2008)']);
    expect(c.categories.map((x) => x.name), ['Démo, test', 'Films']);
    expect(c.items[0].logo, 'http://logo/x.png');
    expect(c.items[1].kind, ContentKind.movie);
    expect(c.items[1].year, 2008);
  });

  test('autres adresses de flux', () {
    expect(streamCandidates('http://h/live/a/b/5.ts'), ['http://h/live/a/b/5.ts', 'http://h/live/a/b/5.m3u8']);
    expect(streamCandidates('http://h/movie/a/b/5.mkv'), ['http://h/movie/a/b/5.mkv']);
  });

  test('recherche sans accents', () => expect(foldText('Télé Française'), 'tele francaise'));
}
