import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';

class ListeningProgress {
  const ListeningProgress(
      {required this.article,
      required this.positionMs,
      required this.durationMs,
      required this.updatedAt});

  final ArticleSummary article;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;

  /// Als beluisterd beschouwen vanaf de laatste 15 seconden.
  bool get finished => durationMs > 0 && positionMs >= durationMs - 15000;
  double get fraction =>
      durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);
  Duration get position => Duration(milliseconds: positionMs);
  Duration get remaining =>
      Duration(milliseconds: (durationMs - positionMs).clamp(0, durationMs));

  factory ListeningProgress.fromJson(Map<String, dynamic> j) =>
      ListeningProgress(
        article: ArticleSummary.fromJson(
            Map<String, dynamic>.from(j['article'] as Map)),
        positionMs: (j['position_ms'] as num?)?.toInt() ?? 0,
        durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse('${j['updated_at']}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'article': article.toJson(),
        'position_ms': positionMs,
        'duration_ms': durationMs,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// "Mijn lijst": bewaarde artikelen en luistervoortgang, alleen lokaal op dit toestel (v1 heeft geen accounts).
class LibraryStore extends ChangeNotifier {
  LibraryStore(this._prefs) {
    _saved = _readMap(_savedKey, (j) => ArticleSummary.fromJson(j));
    _progress = _readMap(_progressKey, ListeningProgress.fromJson);
  }

  static const _savedKey = 'library.saved.v1';
  static const _progressKey = 'library.progress.v1';

  final SharedPreferences _prefs;
  late Map<int, ArticleSummary> _saved;
  late Map<int, ListeningProgress> _progress;
  Future<void> _pendingWrites = Future.value();

  Future<void> _persist(Future<void> Function() action) {
    final next = _pendingWrites.then((_) => action());
    _pendingWrites = next.catchError((Object _) {});
    return next;
  }

  Map<int, T> _readMap<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <int, T>{};
      decoded.forEach((k, v) {
        final id = int.tryParse('$k');
        if (id != null && v is Map) {
          out[id] = parse(Map<String, dynamic>.from(v));
        }
      });
      return out;
    } catch (_) {
      return {}; // beschadigde opslag: opnieuw beginnen in plaats van crashen
    }
  }

  Future<void> _write(String key, Map<int, Object> map) {
    final encoded =
        jsonEncode(map.map((k, v) => MapEntry('$k', (v as dynamic).toJson())));
    return _persist(() async {
      await _prefs.setString(key, encoded);
    });
  }

  // ---- Bewaard
  bool isSaved(int id) => _saved.containsKey(id);

  List<ArticleSummary> get saved => _saved.values.toList().reversed.toList();

  Future<void> toggleSaved(ArticleSummary article) async {
    if (_saved.remove(article.id) == null) {
      _saved[article.id] = article;
    }
    notifyListeners();
    await _write(_savedKey, _saved);
  }

  // ---- Voortgang
  ListeningProgress? progressFor(int id) => _progress[id];

  List<ListeningProgress> get continueListening =>
      (_progress.values.where((p) => !p.finished && p.positionMs > 0).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  List<ListeningProgress> get finished =>
      (_progress.values.where((p) => p.finished).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  Future<void> updateProgress(
      ArticleSummary article, Duration position, Duration duration,
      {bool notify = true}) async {
    _progress[article.id] = ListeningProgress(
      article: article,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      updatedAt: DateTime.now(),
    );
    if (notify) notifyListeners();
    await _write(_progressKey, _progress);
  }

  Future<void> removeProgress(int id) async {
    _progress.remove(id);
    notifyListeners();
    await _write(_progressKey, _progress);
  }

  Future<void> clearAll() async {
    _saved.clear();
    _progress.clear();
    notifyListeners();
    await _persist(() async {
      await _prefs.remove(_savedKey);
      await _prefs.remove(_progressKey);
    });
  }
}
