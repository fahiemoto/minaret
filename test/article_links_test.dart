import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:minaret/api/api_client.dart';
import 'package:minaret/api/models.dart';
import 'package:minaret/screens/article_screen.dart';
import 'package:minaret/state/library_store.dart';
import 'package:minaret/state/player_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ArticleApi extends ApiClient {
  ArticleApi() : super(baseUrl: 'https://www.hetrechtepad.nl/api/v1');
  @override
  Future<ArticleDetail> article(String idOrSlug) async => const ArticleDetail(
        id: 1,
        slug: 'test',
        title: 'Test',
        url: 'https://www.hetrechtepad.nl/test',
        html: '<p><a href="https://example.org/bron">Bron</a></p>',
      );
}

class IdlePlayer extends Fake with ChangeNotifier implements PlayerController {
  @override
  ArticleSummary? get current => null;
  @override
  bool isCurrent(int articleId) => false;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Duration get position => Duration.zero;
}

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final launches = <MethodCall>[];
  var canOpen = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    launches.clear();
    canOpen = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      launches.add(call);
      return canOpen;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<HtmlWidget> openArticle(WidgetTester tester) async {
    final api = ArticleApi();
    final library = LibraryStore(await SharedPreferences.getInstance());
    final player = IdlePlayer();
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
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    return tester.widget<HtmlWidget>(find.byType(HtmlWidget));
  }

  testWidgets('externe bronlink opent buiten de app', (tester) async {
    final html = await openArticle(tester);
    await html.onTapUrl!('https://example.org/bron');
    expect(launches.single.method, 'launch');
    expect(launches.single.arguments['url'], 'https://example.org/bron');
    expect(launches.single.arguments['useSafariVC'], isFalse);
    expect(launches.single.arguments['useWebView'], isFalse);
  });

  testWidgets('mislukt openen geeft een leesbare melding', (tester) async {
    canOpen = false;
    final html = await openArticle(tester);
    await html.onTapUrl!('https://example.org/bron');
    await tester.pumpAndSettle();
    expect(find.text('Deze link kon niet worden geopend.'), findsOneWidget);
  });

  testWidgets('onbekende linkschema’s worden niet gestart', (tester) async {
    final html = await openArticle(tester);
    await html.onTapUrl!('javascript:alert(1)');
    expect(launches, isEmpty);
  });
}
