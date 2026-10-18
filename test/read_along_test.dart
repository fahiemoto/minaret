import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:minaret/util/read_along.dart';

const html = '<p data-seg="paragraph">Eerste zin. <em>Tweede</em> zin!</p>'
    '<div data-hrp-ui><p data-seg="paragraph">Knop</p></div>'
    '<ul>\n  <li data-seg="item">Punt 😀 één.<br>Daarna ﷺ verder.</li>\n</ul>';

String text(String h) => html_parser.parseFragment(h).text ?? '';
List<String> marked(String h) => html_parser
    .parseFragment(h)
    .querySelectorAll(readAlongMarkTag)
    .map((e) => e.text)
    .toList();

void main() {
  group('ReadAlongTimings.fromJson', () {
    test('leest het formaat van de site', () {
      final t = ReadAlongTimings.fromJson({
        'v': 1,
        'segments': 3,
        'duration_ms': 9000,
        'sentences': [
          [0, 1200, 0, 0, 10],
          [1500, 3000, 1, 0, 11],
        ],
      })!;
      expect(t.segments, 3);
      expect(t.sentences, hasLength(2));
      expect(t.sentences[1].startMs, 1500);
      expect(t.sentences[1].segment, 1);
    });

    test('onbekende versie of kapotte data geeft null', () {
      expect(
          ReadAlongTimings.fromJson({'v': 2, 'segments': 1, 'sentences': []}),
          isNull);
      expect(
          ReadAlongTimings.fromJson({
            'v': 1,
            'segments': 1,
            'sentences': [
              [0, 1, 0]
            ]
          }),
          isNull);
      expect(ReadAlongTimings.fromJson('geen json'), isNull);
    });
  });

  test('indexAt houdt in een pauze de vorige zin vast', () {
    const t = ReadAlongTimings(segments: 2, sentences: [
      SentenceTiming(500, 1000, 1, 0, 5),
      SentenceTiming(1500, 2000, 1, 6, 10),
    ]);
    expect(t.indexAt(0), -1);
    expect(t.indexAt(500), 0);
    expect(t.indexAt(1200), 0);
    expect(t.indexAt(1500), 1);
    expect(t.indexAt(99999), 1);
  });

  group('ReadAlongDocument', () {
    final doc = ReadAlongDocument(html);

    test('telt segmenten zonder interface-elementen', () {
      expect(doc.segmentCount, 2);
      const fits = ReadAlongTimings(
          segments: 3, sentences: [SentenceTiming(0, 1, 0, 0, 1)]);
      const off = ReadAlongTimings(
          segments: 4, sentences: [SentenceTiming(0, 1, 0, 0, 1)]);
      expect(fits.matches(doc), isTrue);
      expect(off.matches(doc), isFalse);
    });

    test('markeert een zin over opmaak heen zonder de tekst te veranderen', () {
      final out = doc.mark(const SentenceTiming(0, 0, 1, 12, 23));
      expect(marked(out).join(), 'Tweede zin!');
      expect(text(out), text(html));
      expect(out, contains('<$readAlongAnchorTag>'));
    });

    test('rekent in codepoints en telt <br> als één teken', () {
      // "Punt 😀 één." = 0..11, <br> = 11, "Daarna ﷺ verder." = 12..28
      expect(marked(doc.mark(const SentenceTiming(0, 0, 2, 0, 11))).join(),
          'Punt 😀 één.');
      expect(marked(doc.mark(const SentenceTiming(0, 0, 2, 12, 28))).join(),
          'Daarna ﷺ verder.');
    });

    test('titel of onbekend segment laat de tekst ongemoeid', () {
      expect(doc.mark(const SentenceTiming(0, 0, 0, 0, 5)), html);
      expect(doc.mark(const SentenceTiming(0, 0, 9, 0, 5)), html);
    });
  });

  // Gemaakt met de DocumentRenderer en ReadAlongTimings::sentenceSpans van de site,
  // zodat app en server dezelfde zin aanwijzen.
  test('markeert elke zin precies zoals de site hem telt', () {
    final fixture = jsonDecode(
            File('test/fixtures/read_along_site.json').readAsStringSync())
        as Map<String, dynamic>;
    final siteHtml = fixture['html'] as String;
    final doc = ReadAlongDocument(siteHtml);
    expect(doc.segmentCount + 1, fixture['segments']);
    var checked = 0;
    for (final s in (fixture['sentences'] as List).cast<List>()) {
      final [seg as int, cs as int, ce as int, expected as String] = s;
      if (seg == 0) continue; // titel staat niet in de HTML
      final out = doc.mark(SentenceTiming(0, 0, seg, cs, ce));
      expect(marked(out).join(), expected, reason: 'segment $seg [$cs, $ce)');
      expect(text(out), text(siteHtml));
      checked++;
    }
    expect(checked, greaterThan(8));
  });
}
