import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/api/models.dart';

// Voorbeeld volgens docs/api/openapi.yaml (v1.1) van de website.
final _summaryJson = <String, dynamic>{
  'id': 12,
  'slug': 'fictief-testartikel',
  'title': 'Fictief testartikel: ʿIlm & “kennis”',
  'excerpt': null,
  'url': 'https://www.hetrechtepad.nl/fictief-testartikel',
  'category': {'slug': 'gebed', 'name': 'Gebed'},
  'authors': [
    {'name': 'Auteur Een', 'slug': 'auteur-een'},
    {'name': 'Auteur Twee', 'slug': 'auteur-twee'},
  ],
  'tags': [],
  'reading_minutes': 6,
  'image': null,
  'image_wide': null,
  'audio': {'status': 'ready', 'duration_seconds': 754},
  'published_at': '2026-10-16T10:00:00+00:00',
  'updated_at': '2026-10-16T10:00:00+00:00',
};

void main() {
  test('samenvatting: titel blijft exact gelijk en audio wordt gelezen', () {
    final a = ArticleSummary.fromJson(_summaryJson);
    expect(a.title, 'Fictief testartikel: ʿIlm & “kennis”');
    expect(a.hasAudio, isTrue);
    expect(a.audio.durationSeconds, 754);
    expect(a.authorLine, 'Auteur Een, Auteur Twee');
    expect(a.category?.slug, 'gebed');
    expect(a.image, isNull);
  });

  test('samenvatting: round-trip via toJson voor lokale opslag', () {
    final a = ArticleSummary.fromJson(_summaryJson);
    final b = ArticleSummary.fromJson(a.toJson());
    expect(b.id, a.id);
    expect(b.title, a.title);
    expect(b.audio.ready, isTrue);
    expect(b.authors.length, 2);
    expect(b.publishedAt, a.publishedAt);
  });

  test('detail: audio-url alleen bij status ready', () {
    final ready = ArticleDetail.fromJson({
      ..._summaryJson,
      'html': '<p data-seg="b1">Tekst</p>',
      'audio': {'status': 'ready', 'url': 'http://localhost/audio/artikel/12/3.mp3', 'duration_seconds': 754, 'timings_url': 'http://localhost/audio/artikel/12/3.json'},
      'pdf': {'url': 'http://localhost/pdf/artikel/12.pdf'},
      'revision': {'id': 1, 'number': 1, 'projection_sha256': 'abc', 'schema': 'hrp-doc/1'},
    });
    expect(ready.audio.url, endsWith('.mp3'));
    expect(ready.revisionHash, 'abc');
    expect(ready.toSummary().audio.url, isNull, reason: 'Opslag bewaart geen tijdelijke media-URL');

    final none = ArticleDetail.fromJson({..._summaryJson, 'html': '', 'audio': {'status': 'unavailable', 'url': null}});
    expect(none.hasAudio, isFalse);
    expect(none.audio.url, isNull);
  });

  test('onbekende of ontbrekende velden laten de app niet crashen', () {
    final a = ArticleSummary.fromJson({'id': '7', 'title': 'X'});
    expect(a.id, 7);
    expect(a.hasAudio, isFalse);
    expect(a.authors, isEmpty);
  });

  test('zoekresultaat: slug uit artikel-URL', () {
    const r = SearchResult(type: 'article', title: 'T', url: 'https://www.hetrechtepad.nl/de-slug');
    expect(r.articleSlug, 'de-slug');
    const p = SearchResult(type: 'page', title: 'P', url: 'https://www.hetrechtepad.nl/wie-we-zijn');
    expect(p.articleSlug, isNull);
  });

  test('startscherm-sectie', () {
    final s = HomeSection.fromJson({
      'key': 'category:gebed',
      'type': 'row',
      'title': 'Gebed',
      'category': {'slug': 'gebed', 'name': 'Gebed'},
      'items': [_summaryJson],
    });
    expect(s.isCarousel, isFalse);
    expect(s.items.single.id, 12);
  });
}
