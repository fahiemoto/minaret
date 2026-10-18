import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:minaret/api/api_client.dart';
import 'package:minaret/api/models.dart';
import 'package:minaret/screens/article_screen.dart';
import 'package:minaret/state/library_store.dart';
import 'package:minaret/state/player_controller.dart';
import 'package:minaret/util/read_along.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const html = '<p data-seg="text">Eerste zin. Tweede zin.</p>'
    '<p data-seg="text">Derde zin.</p>';

class ReadAlongApi extends ApiClient {
  ReadAlongApi({this.segments = 3})
      : super(baseUrl: 'https://www.hetrechtepad.nl/api/v1');
  final int segments;

  @override
  Future<ArticleDetail> article(String idOrSlug) async => const ArticleDetail(
        id: 1,
        slug: 'test',
        title: 'Test',
        url: 'https://www.hetrechtepad.nl/test',
        html: html,
        audio: AudioInfo(
            ready: true,
            url: 'https://www.hetrechtepad.nl/audio/1.mp3',
            timingsUrl: 'https://www.hetrechtepad.nl/audio/1.json'),
      );

  @override
  Future<ReadAlongTimings?> readAlongTimings(String url) async =>
      ReadAlongTimings(segments: segments, sentences: const [
        SentenceTiming(0, 900, 0, 0, 4),
        SentenceTiming(1000, 1900, 1, 0, 11),
        SentenceTiming(2000, 2900, 1, 12, 23),
        SentenceTiming(3000, 3900, 2, 0, 10),
      ]);
}

class PlayingPlayer extends Fake
    with ChangeNotifier
    implements PlayerController {
  final positions = StreamController<Duration>.broadcast();
  @override
  Duration position = Duration.zero;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  ArticleSummary? get current => null;
  @override
  bool isCurrent(int articleId) => articleId == 1;
  @override
  void dispose() {
    positions.close();
    super.dispose();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<PlayingPlayer> open(WidgetTester tester, ApiClient api) async {
    final library = LibraryStore(await SharedPreferences.getInstance());
    final player = PlayingPlayer();
    addTearDown(api.dispose);
    addTearDown(library.dispose);
    addTearDown(player.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<LibraryStore>.value(value: library),
        ChangeNotifierProvider<PlayerController>.value(value: player),
      ],
      child: const MaterialApp(home: ArticleScreen(slug: 'test')),
    ));
    await tester.pumpAndSettle();
    // De tekst staat onder de cover; scrol erheen zodat hij wordt opgebouwd.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    return player;
  }

  String body(WidgetTester tester) =>
      tester.widget<HtmlWidget>(find.byType(HtmlWidget)).html;

  Future<void> at(WidgetTester tester, PlayingPlayer p, int ms) async {
    p.position = Duration(milliseconds: ms);
    p.positions.add(p.position);
    await tester.pumpAndSettle();
  }

  testWidgets('markeert de zin die op dit moment klinkt', (tester) async {
    final player = await open(tester, ReadAlongApi());
    await at(tester, player, 2500);
    expect(body(tester), contains('<hrp-mark>Tweede zin.</hrp-mark>'));
    await at(tester, player, 3200);
    expect(body(tester), contains('<hrp-mark>Derde zin.</hrp-mark>'));
    expect(body(tester), isNot(contains('<hrp-mark>Tweede')));
  });

  testWidgets('meelezen is uit te zetten', (tester) async {
    final player = await open(tester, ReadAlongApi());
    await at(tester, player, 1200);
    expect(body(tester), contains('<hrp-mark>Eerste zin.</hrp-mark>'));
    await tester.tap(find.byTooltip('Meelezen uitzetten'));
    await tester.pumpAndSettle();
    expect(body(tester), html);
    await at(tester, player, 2500);
    expect(body(tester), html);
  });

  testWidgets('geen markering als de zinstijden niet bij de tekst passen',
      (tester) async {
    final player = await open(tester, ReadAlongApi(segments: 5));
    await at(tester, player, 2500);
    expect(body(tester), html);
    expect(find.byTooltip('Meelezen uitzetten'), findsNothing);
  });
}
