import 'dart:math' as math;

import '../api/models.dart';

/// "12 min", "1 u 5 min" — voor lijsten en kaarten.
String formatDurationShort(int seconds) {
  if (seconds <= 0) return '0 min';
  final totalMinutes = math.max(1, (seconds / 60).round());
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h u' : '$h u $m min';
}

/// "3:07" of "1:02:09" — voor de speler.
String formatClock(Duration d) {
  final neg = d.isNegative;
  final t = d.abs();
  final h = t.inHours;
  final m = t.inMinutes.remainder(60);
  final s = t.inSeconds.remainder(60);
  final ss = s.toString().padLeft(2, '0');
  final body = h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  return neg ? '-$body' : body;
}

/// "Audio · 12 min" of "Lezen · 6 min".
String articleMeta(ArticleSummary a) {
  if (a.hasAudio && (a.audio.durationSeconds ?? 0) > 0) {
    return 'Audio · ${formatDurationShort(a.audio.durationSeconds!)}';
  }
  if (a.hasAudio) return 'Audio';
  if ((a.readingMinutes ?? 0) > 0) return 'Lezen · ${a.readingMinutes} min';
  return 'Artikel';
}

const _months = ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];

String formatDate(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}
