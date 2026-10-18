import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Eén zin uit het meeleesbestand van de site: tijden in ms en codepoint-posities binnen een projectiesegment.
class SentenceTiming {
  const SentenceTiming(
      this.startMs, this.endMs, this.segment, this.start, this.end);

  final int startMs;
  final int endMs;

  /// Projectie-index: 0 is de titel, daarna de `data-seg`-elementen van de tekst.
  final int segment;
  final int start;
  final int end;
}

/// Zinstijden voor meelezen (zelfde formaat en regels als `readAlong.js` op de website).
class ReadAlongTimings {
  const ReadAlongTimings({required this.segments, required this.sentences});

  static const version = 1;

  final int segments;
  final List<SentenceTiming> sentences;

  /// Geeft null bij een onbekend of kapot bestand; dan speelt de audio gewoon zonder meelezen.
  static ReadAlongTimings? fromJson(Object? json) {
    if (json is! Map || json['v'] != version) return null;
    final segments = json['segments'];
    final raw = json['sentences'];
    if (segments is! int || raw is! List) return null;
    final out = <SentenceTiming>[];
    for (final s in raw) {
      if (s is! List || s.length < 5 || s.any((v) => v is! int)) return null;
      out.add(SentenceTiming(s[0], s[1], s[2], s[3], s[4]));
    }
    return ReadAlongTimings(segments: segments, sentences: out);
  }

  /// Zin die op [ms] klinkt; in een pauze tussen twee zinnen blijft de vorige staan. -1 vóór de eerste zin.
  int indexAt(int ms) {
    var lo = 0;
    var hi = sentences.length - 1;
    var found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (sentences[mid].startMs <= ms) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }

  /// Past bij deze tekst als het aantal segmenten (titel + `data-seg`-elementen) overeenkomt.
  bool matches(ReadAlongDocument doc) =>
      sentences.isNotEmpty && segments == doc.segmentCount + 1;
}

const _structural = {
  'ol', 'ul', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'figure', 'section', //
  'div', 'article', 'body', 'blockquote', 'aside', 'nav', 'header', 'footer',
  'main', 'html', 'dl', 'colgroup',
};
const _skip = {'img', 'script', 'style', 'template'};

/// Naam van het element dat de actieve zin omsluit, en van het nulbrede ankerpunt om naartoe te scrollen.
const readAlongMarkTag = 'hrp-mark';
const readAlongAnchorTag = 'hrp-anchor';

class _TextPiece {
  _TextPiece(this.node, this.start, this.length);
  final dom.Text node;
  final int start;
  final int length;
}

/// Artikel-HTML met de projectiesegmenten erin teruggevonden. Markeren voegt alleen omhullende
/// elementen toe; de tekst zelf blijft teken voor teken gelijk.
class ReadAlongDocument {
  ReadAlongDocument(this.html)
      : segmentCount = _segments(html_parser.parseFragment(html)).length;

  final String html;
  final int segmentCount;

  static List<dom.Element> _segments(dom.DocumentFragment root) => root
      .querySelectorAll('[data-seg]')
      .where((el) => !_insideUi(el))
      .toList();

  static bool _insideUi(dom.Element el) {
    for (dom.Element? e = el; e != null; e = e.parent) {
      if (e.attributes.containsKey('data-hrp-ui')) return true;
    }
    return false;
  }

  static List<_TextPiece> _textMap(dom.Element el) {
    final out = <_TextPiece>[];
    var pos = 0;
    void walk(dom.Node node) {
      for (final child in node.nodes.toList()) {
        if (child is dom.Text) {
          final data = child.data;
          final parent = child.parentNode;
          if (!RegExp(r'[^ \t\n\r\f]').hasMatch(data) &&
              parent is dom.Element &&
              _structural.contains(parent.localName)) {
            continue;
          }
          final len = data.runes.length;
          out.add(_TextPiece(child, pos, len));
          pos += len;
        } else if (child is dom.Element) {
          if (child.attributes.containsKey('data-hrp-ui') ||
              child.attributes.containsKey('data-seg') ||
              _skip.contains(child.localName)) {
            continue;
          }
          if (child.localName == 'br') {
            pos += 1;
            continue;
          }
          walk(child);
        }
      }
    }

    walk(el);
    return out;
  }

  /// HTML waarin de zin [sentence] in [readAlongMarkTag] staat, met een [readAlongAnchorTag] ervoor.
  /// Geeft de originele HTML terug als de zin niet in de tekst ligt (bijvoorbeeld de titel).
  String mark(SentenceTiming sentence) {
    final bodyIndex = sentence.segment - 1;
    final root = html_parser.parseFragment(html);
    final segments = _segments(root);
    if (bodyIndex < 0 || bodyIndex >= segments.length) return html;
    final cs = sentence.start;
    final ce = sentence.end;
    var anchored = false;
    for (final piece in _textMap(segments[bodyIndex])) {
      final from =
          cs.clamp(piece.start, piece.start + piece.length) - piece.start;
      final to =
          ce.clamp(piece.start, piece.start + piece.length) - piece.start;
      if (from >= to) continue;
      final runes = piece.node.data.runes.toList();
      final parent = piece.node.parentNode!;
      final before = String.fromCharCodes(runes.sublist(0, from));
      final inside = String.fromCharCodes(runes.sublist(from, to));
      final after = String.fromCharCodes(runes.sublist(to));
      final mark = dom.Element.tag(readAlongMarkTag)..append(dom.Text(inside));
      final replacement = <dom.Node>[
        if (before.isNotEmpty) dom.Text(before),
        if (!anchored) dom.Element.tag(readAlongAnchorTag),
        mark,
        if (after.isNotEmpty) dom.Text(after),
      ];
      anchored = true;
      for (final n in replacement) {
        parent.insertBefore(n, piece.node);
      }
      piece.node.remove();
    }
    return anchored ? root.outerHtml : html;
  }
}
