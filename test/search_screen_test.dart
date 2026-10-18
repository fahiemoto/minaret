import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/api/api_client.dart';
import 'package:minaret/api/models.dart';
import 'package:minaret/screens/search_screen.dart';
import 'package:provider/provider.dart';

class SearchApi extends ApiClient {
  SearchApi() : super(baseUrl: 'https://example.com/api/v1');
  final requests = <({String query, int page})>[];
  Future<PageResult<SearchResult>> Function(String, int)? respond;
  @override
  Future<PageResult<SearchResult>> search(String query, {int page = 1}) async {
    requests.add((query: query, page: page));
    return respond!(query, page);
  }
}

PageResult<SearchResult> results(String title,
        {int page = 1, int lastPage = 1}) =>
    PageResult(
      items: [
        SearchResult(
            type: 'article', title: title, url: 'https://example.com/$title')
      ],
      page: page,
      lastPage: lastPage,
      total: lastPage,
    );

void main() {
  late SearchApi api;
  setUp(() {
    api = SearchApi();
  });
  tearDown(() => api.dispose());

  Future<void> open(WidgetTester tester) => tester.pumpWidget(
        Provider<ApiClient>.value(
            value: api,
            child: const MaterialApp(home: SearchScreen(active: true))),
      );

  testWidgets('wissen annuleert de geplande zoekopdracht', (tester) async {
    api.respond = (_, __) async => results('Oud');
    await open(tester);
    await tester.enterText(find.byType(TextField), 'gebed');
    await tester.pump();
    await tester.tap(find.byTooltip('Wissen'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.requests, isEmpty);
    expect(find.text('Zoek in alle artikelen'), findsOneWidget);
  });

  testWidgets('oud antwoord wordt genegeerd zodra de invoer verandert',
      (tester) async {
    final old = Completer<PageResult<SearchResult>>();
    api.respond = (q, _) =>
        q == 'oud' ? old.future : Future.value(results('Nieuw resultaat'));
    await open(tester);
    await tester.enterText(find.byType(TextField), 'oud');
    await tester.pump(const Duration(milliseconds: 401));
    await tester.enterText(find.byType(TextField), 'nieuw');
    old.complete(results('Oud resultaat'));
    await tester.pump();
    expect(find.text('Oud resultaat'), findsNothing);
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pumpAndSettle();
    expect(find.text('Nieuw resultaat'), findsOneWidget);
  });

  testWidgets('meer resultaten voegt de volgende pagina toe', (tester) async {
    api.respond =
        (_, page) async => results('Resultaat $page', page: page, lastPage: 2);
    await open(tester);
    await tester.enterText(find.byType(TextField), 'gebed');
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meer resultaten'));
    await tester.pumpAndSettle();
    expect(api.requests.map((r) => r.page), [1, 2]);
    expect(find.text('Resultaat 1'), findsOneWidget);
    expect(find.text('Resultaat 2'), findsOneWidget);
    expect(find.text('Meer resultaten'), findsNothing);
  });

  testWidgets('fout op vervolgpagina behoudt resultaten en kan worden herhaald',
      (tester) async {
    var fail = true;
    api.respond = (_, page) async {
      if (page == 2 && fail) throw const ApiException('Geen verbinding');
      return results('Resultaat $page', page: page, lastPage: 2);
    };
    await open(tester);
    await tester.enterText(find.byType(TextField), 'gebed');
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meer resultaten'));
    await tester.pumpAndSettle();
    expect(find.text('Resultaat 1'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Opnieuw proberen'));
    await tester.pumpAndSettle();
    expect(api.requests.map((r) => r.page), [1, 2, 2]);
    expect(find.text('Resultaat 2'), findsOneWidget);
  });
}
