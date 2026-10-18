import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import 'library_store.dart';
import 'settings_store.dart';

/// Sleeptimer-opties: vaste duur of tot het einde van het artikel.
sealed class SleepTimer {
  const SleepTimer();
}

class SleepAfter extends SleepTimer {
  const SleepAfter(this.duration);
  final Duration duration;
}

class SleepAtEnd extends SleepTimer {
  const SleepAtEnd();
}

/// Keuze "uitzetten" in het menu; wordt direct omgezet naar geen timer.
class SleepOff extends SleepTimer {
  const SleepOff();
}

/// Eén speler voor de hele app. Afspelen op de achtergrond en op het vergrendelscherm via just_audio_background.
class PlayerController extends ChangeNotifier {
  PlayerController(
      {required this.api,
      required this.library,
      required this.settings,
      AudioPlayer? audioPlayer})
      : player = audioPlayer ?? AudioPlayer() {
    _subs.add(player.playerStateStream.listen(_onState));
    _subs.add(player.positionStream.listen(_onPosition));
  }

  final ApiClient api;
  final LibraryStore library;
  final SettingsStore settings;
  final AudioPlayer player;
  Future<void> _pending = Future.value();
  bool _disposed = false;

  // Wisselen, stoppen en wissen mogen elkaar niet overlappen.
  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) async {
      if (!_disposed) await action();
    });
    _pending = next.catchError((Object _) {});
    return next;
  }

  final List<StreamSubscription<dynamic>> _subs = [];

  ArticleSummary? _current;
  String? _error;
  bool _loading = false;
  Duration _lastSaved = Duration.zero;
  bool _completed = false;
  Timer? _sleepTimer;
  SleepTimer? _sleep;
  DateTime? _sleepEndsAt;

  ArticleSummary? get current => _current;
  String? get error => _error;
  bool get loading => _loading;
  bool get hasMedia => _current != null;
  SleepTimer? get sleep => _sleep;
  DateTime? get sleepEndsAt => _sleepEndsAt;

  bool isCurrent(int articleId) => _current?.id == articleId;

  /// Afspeelpositie, voor meelezen.
  Stream<Duration> get positionStream => player.positionStream;
  Duration get position => player.position;

  /// Start (of hervat) een artikel. Gaat verder waar je gebleven was, tenzij het al beluisterd is.
  Future<void> playArticle(ArticleDetail article) =>
      _enqueue(() => _playArticle(article));

  Future<void> _playArticle(ArticleDetail article) async {
    final url = article.audio.url;
    if (!article.audio.ready || url == null) {
      _error = 'Voor dit artikel is nog geen audio beschikbaar.';
      notifyListeners();
      return;
    }
    if (isCurrent(article.id) && player.audioSource != null) {
      _completed = false;
      _startPlayback();
      return;
    }
    await _saveProgress();
    _completed = false;
    _current = null;
    _error = null;
    _loading = true;
    notifyListeners();

    final saved = library.progressFor(article.id);
    final start =
        (saved != null && !saved.finished) ? saved.position : Duration.zero;
    final art = article.imageWide ?? article.image;
    try {
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(api.resolveMediaUrl(url)),
          tag: MediaItem(
            id: '${article.id}',
            title: article.title,
            artist: article.authorLine.isEmpty
                ? 'Het Rechte Pad'
                : article.authorLine,
            album: article.category?.name ?? 'Het Rechte Pad',
            artUri: art == null ? null : Uri.parse(api.resolveMediaUrl(art)),
            duration: article.audio.durationSeconds == null
                ? null
                : Duration(seconds: article.audio.durationSeconds!),
          ),
        ),
        initialPosition: start,
      );
      _lastSaved = start;
      await player.setSpeed(settings.speed);
      if (_disposed) return;
      _current = article.toSummary();
      _loading = false;
      notifyListeners();
      _startPlayback();
    } catch (e) {
      if (_disposed) return;
      _loading = false;
      _error = 'De audio kon niet worden geladen. Probeer het later opnieuw.';
      notifyListeners();
    }
  }

  void _startPlayback() {
    final article = _current;
    unawaited(player.play().catchError((Object error) {
      if (_disposed || _current != article) return;
      _error = 'De audio kon niet worden afgespeeld. Probeer het opnieuw.';
      notifyListeners();
    }));
  }

  Future<void> togglePlay() async {
    if (_loading || _current == null) return;
    if (player.playing) {
      await player.pause();
    } else {
      _completed = false;
      _startPlayback();
    }
  }

  Future<void> seekRelative(Duration offset) async {
    final dur = player.duration ?? Duration.zero;
    var target = player.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (dur > Duration.zero && target > dur) target = dur;
    await player.seek(target);
  }

  Future<void> seek(Duration position) => player.seek(position);

  Future<void> setSpeed(double speed) async {
    await player.setSpeed(speed);
    await settings.setSpeed(speed);
    notifyListeners();
  }

  void setSleepTimer(SleepTimer? timer) {
    if (timer is SleepOff) timer = null;
    _sleepTimer?.cancel();
    _sleep = timer;
    _sleepEndsAt = null;
    if (timer is SleepAfter) {
      _sleepEndsAt = DateTime.now().add(timer.duration);
      _sleepTimer = Timer(timer.duration, () {
        player.pause();
        _sleep = null;
        _sleepEndsAt = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> stop() => _enqueue(_stop);

  Future<void> clearLibrary() => _enqueue(() async {
        await _stop();
        await library.clearAll();
      });

  Future<void> _stop() async {
    await _saveProgress();
    _current = null;
    await player.stop();
    setSleepTimer(null);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _onState(PlayerState state) {
    if (_loading || _current == null || _disposed) return;
    if (state.processingState == ProcessingState.completed) {
      if (_completed) return;
      _completed = true;
      _saveProgress(atEnd: true);
      if (_sleep is SleepAtEnd) setSleepTimer(null);
      player.pause();
      player.seek(Duration.zero);
    } else if (!state.playing) {
      _saveProgress();
    }
    notifyListeners();
  }

  void _onPosition(Duration pos) {
    if (_loading || _current == null || _disposed) return;
    // Elke 10 seconden luisteren lokaal vastleggen (zonder de hele UI opnieuw te tekenen).
    if ((pos - _lastSaved).abs() >= const Duration(seconds: 10)) {
      _saveProgress(notify: false);
    }
  }

  Future<void> _saveProgress({bool atEnd = false, bool notify = true}) async {
    final article = _current;
    final dur = player.duration;
    if (article == null || dur == null || dur == Duration.zero) return;
    // Na het einde niet terugzetten naar 0 (anders verdwijnt het uit "Beluisterd").
    if (_completed && !atEnd) return;
    final pos = atEnd ? dur : player.position;
    _lastSaved = pos;
    await library.updateProgress(article, pos, dur, notify: notify);
  }

  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
    super.dispose();
  }
}
