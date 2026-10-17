import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/api/models.dart';
import 'package:minaret/state/library_store.dart';
import 'package:minaret/util/format.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _article = ArticleSummary(id: 1, slug: 'a', title: 'Artikel', url: 'https://x/a', audio: AudioInfo(ready: true, durationSeconds: 600));

void main() {
  group('format', () {
    test('korte duur', () {
      expect(formatDurationShort(0), '0 min');
      expect(formatDurationShort(20), '1 min');
      expect(formatDurationShort(754), '13 min');
      expect(formatDurationShort(3600), '1 u');
      expect(formatDurationShort(3900), '1 u 5 min');
    });

    test('klok', () {
      expect(formatClock(const Duration(seconds: 7)), '0:07');
      expect(formatClock(const Duration(minutes: 3, seconds: 7)), '3:07');
      expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 9)), '1:02:09');
    });

    test('meta-regel', () {
      expect(articleMeta(_article), 'Audio · 10 min');
      expect(articleMeta(const ArticleSummary(id: 2, slug: 'b', title: 'B', url: '', readingMinutes: 6)), 'Lezen · 6 min');
    });
  });

  group('LibraryStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('bewaren en weer verwijderen blijft bewaard na herstart', () async {
      final prefs = await SharedPreferences.getInstance();
      final lib = LibraryStore(prefs);
      await lib.toggleSaved(_article);
      expect(lib.isSaved(1), isTrue);
      expect(LibraryStore(prefs).isSaved(1), isTrue, reason: 'na herstart nog aanwezig');
      await lib.toggleSaved(_article);
      expect(LibraryStore(prefs).isSaved(1), isFalse);
    });

    test('voortgang: verder luisteren en beluisterd', () async {
      final prefs = await SharedPreferences.getInstance();
      final lib = LibraryStore(prefs);
      await lib.updateProgress(_article, const Duration(minutes: 2), const Duration(minutes: 10));
      expect(lib.continueListening.single.article.id, 1);
      expect(lib.progressFor(1)!.fraction, closeTo(0.2, 0.001));

      await lib.updateProgress(_article, const Duration(minutes: 9, seconds: 50), const Duration(minutes: 10));
      expect(lib.continueListening, isEmpty);
      expect(lib.finished.single.finished, isTrue);
    });

    test('beschadigde opslag geeft een lege lijst in plaats van een crash', () async {
      SharedPreferences.setMockInitialValues({'library.saved.v1': '{kapot', 'library.progress.v1': '[]'});
      final lib = LibraryStore(await SharedPreferences.getInstance());
      expect(lib.saved, isEmpty);
      expect(lib.continueListening, isEmpty);
    });
  });
}
