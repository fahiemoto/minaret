import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:minaret/api/api_client.dart';
import 'package:minaret/api/models.dart';
import 'package:minaret/state/library_store.dart';
import 'package:minaret/state/player_controller.dart';
import 'package:minaret/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ArticleDetail article(int id) => ArticleDetail(
      id: id,
      slug: 'artikel-$id',
      title: 'Artikel $id',
      url: '',
      html: '',
      audio: AudioInfo(
          ready: true,
          url: 'https://example.com/$id.mp3',
          durationSeconds: 600),
    );

class FakePlayer extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  Completer<void>? loading;
  Completer<void>? playback;
  bool failLoading = false;
  final loaded = <AudioSource>[];
  @override
  AudioSource? audioSource;
  @override
  Duration? duration = const Duration(minutes: 10);
  @override
  Duration position = Duration.zero;
  @override
  bool playing = false;
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Future<Duration?> setAudioSource(AudioSource source,
      {bool preload = true,
      int? initialIndex,
      Duration? initialPosition}) async {
    loaded.add(source);
    // Tijdens wisselen kan de speler nog de positie van de vorige bron melden.
    states.add(PlayerState(false, ProcessingState.loading));
    positions.add(position);
    if (loading != null) await loading!.future;
    if (failLoading) throw StateError('Audio niet bereikbaar');
    audioSource = source;
    position = initialPosition ?? Duration.zero;
    return duration;
  }

  @override
  Future<void> play() async {
    playing = true;
    if (playback != null) await playback!.future;
  }

  @override
  Future<void> pause() async {
    playing = false;
    states.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> stop() async {
    playing = false;
    states.add(PlayerState(false, ProcessingState.idle));
  }

  @override
  Future<void> seek(Duration? value, {int? index}) async {
    position = value ?? Duration.zero;
  }

  @override
  Future<void> setSpeed(double value) async {}
  @override
  Future<void> dispose() async {
    await states.close();
    await positions.close();
  }
}

void main() {
  late LibraryStore library;
  late FakePlayer player;
  late PlayerController controller;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    library = LibraryStore(prefs);
    player = FakePlayer();
    final api = ApiClient(baseUrl: 'https://example.com/api/v1');
    controller = PlayerController(
        api: api,
        library: library,
        settings: SettingsStore(prefs),
        audioPlayer: player);
    addTearDown(controller.dispose);
    addTearDown(api.dispose);
  });

  test('bronwissel bewaart oude positie alleen bij het oude artikel', () async {
    await controller.playArticle(article(1));
    player.position = const Duration(minutes: 4);
    await controller.playArticle(article(2));
    expect(library.progressFor(1)!.position, const Duration(minutes: 4));
    expect(library.progressFor(2), isNull);
    expect(controller.current!.id, 2);
  });

  test(
      'wissen stopt audio, wist de timer en blijft leeg na late gebeurtenissen',
      () async {
    await controller.playArticle(article(1));
    player.position = const Duration(minutes: 4);
    await library.toggleSaved(article(1));
    controller.setSleepTimer(const SleepAfter(Duration(minutes: 5)));
    player.positions.add(player.position);
    await controller.clearLibrary();
    player.positions.add(const Duration(minutes: 5));
    player.states.add(PlayerState(false, ProcessingState.completed));
    expect(player.playing, isFalse);
    expect(controller.current, isNull);
    expect(controller.sleep, isNull);
    expect(library.saved, isEmpty);
    expect(library.progressFor(1), isNull);
    final reopened = LibraryStore(prefs);
    expect(reopened.saved, isEmpty);
    expect(reopened.continueListening, isEmpty);
    expect(reopened.finished, isEmpty);
  });

  test('overlappende bronwissels worden op volgorde geladen', () async {
    player.loading = Completer<void>();
    final first = controller.playArticle(article(1));
    final second = controller.playArticle(article(2));
    await Future<void>.delayed(Duration.zero);
    expect(player.loaded, hasLength(1));
    player.loading!.complete();
    await Future.wait([first, second]);
    expect(player.loaded, hasLength(2));
    expect(controller.current!.id, 2);
  });

  test('een mislukte laadpoging kan opnieuw worden geprobeerd', () async {
    player.failLoading = true;
    await controller.playArticle(article(1));
    expect(controller.error, isNotNull);
    expect(controller.current, isNull);
    player.failLoading = false;
    await controller.playArticle(article(1));
    expect(controller.error, isNull);
    expect(controller.current!.id, 1);
  });

  test('hervatten wacht niet op het einde van afspelen', () async {
    await controller.playArticle(article(1));
    await player.pause();
    player.playback = Completer<void>();
    await controller
        .playArticle(article(1))
        .timeout(const Duration(seconds: 1));
    expect(player.playing, isTrue);
    player.playback!.complete();
  });
}
