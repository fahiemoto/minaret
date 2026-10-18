import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/theme/app_theme.dart';
import 'package:minaret/util/article_links.dart';

void main() {
  test('licht en donker thema kunnen worden opgebouwd', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  test('alleen exacte websitehosts openen een interne artikelroute', () {
    expect(internalArticleSlug(Uri.parse('https://www.hetrechtepad.nl/gebed')),
        'gebed');
    expect(internalArticleSlug(Uri.parse('https://hetrechtepad.nl/gebed')),
        'gebed');
    expect(
        internalArticleSlug(Uri.parse('https://hetrechtepad.evil.test/gebed')),
        isNull);
    expect(
        internalArticleSlug(
            Uri.parse('https://www.hetrechtepad.nl.evil.test/gebed')),
        isNull);
    expect(internalArticleSlug(Uri.parse('https://example.com/gebed')), isNull);
    expect(internalArticleSlug(Uri.parse('https://www.hetrechtepad.nl/a/b')),
        isNull);
    expect(
        internalArticleSlug(Uri.parse('mailto:info@hetrechtepad.nl')), isNull);
  });
}
