import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// Client voor de read-only publieke API. Ondersteunt ETag-caching (304) en nette foutmeldingen.
class ApiClient {
  ApiClient({required String baseUrl, http.Client? client, this.timeout = const Duration(seconds: 15)})
      : baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _http = client ?? http.Client();

  final Uri baseUri;
  final Duration timeout;
  final http.Client _http;
  final Map<String, ({String etag, Map<String, dynamic> body})> _etagCache = {};

  Future<Map<String, dynamic>> _get(String path, [Map<String, String?> query = const {}]) async {
    final params = {for (final e in query.entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value!};
    final uri = baseUri.resolve(path).replace(queryParameters: params.isEmpty ? null : params);
    final key = uri.toString();
    final cached = _etagCache[key];
    http.Response res;
    try {
      res = await _http.get(uri, headers: {
        'Accept': 'application/json',
        if (cached != null) 'If-None-Match': cached.etag,
      }).timeout(timeout);
    } on TimeoutException {
      throw const ApiException('De verbinding duurt te lang. Probeer het opnieuw.');
    } catch (_) {
      throw const ApiException('Geen verbinding. Controleer je internet en probeer het opnieuw.');
    }

    if (res.statusCode == 304 && cached != null) return cached.body;
    if (res.statusCode == 404) throw const ApiException('Niet gevonden.', status: 404);
    if (res.statusCode == 429) throw const ApiException('Even rustig aan: te veel verzoeken. Probeer het zo opnieuw.', status: 429);
    if (res.statusCode >= 400) {
      throw ApiException(_errorMessage(res) ?? 'Er ging iets mis (${res.statusCode}).', status: res.statusCode);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) throw const ApiException('Onverwacht antwoord van de server.');
    final etag = res.headers['etag'];
    if (etag != null) _etagCache[key] = (etag: etag, body: body);
    return body;
  }

  String? _errorMessage(http.Response res) {
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      return j is Map && j['error'] is Map ? j['error']['message'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  /// Media-URL's uit de API zijn absoluut. Lokaal (localhost) herschrijven we de host naar die van de API,
  /// zodat bijvoorbeeld de Android-emulator (10.0.2.2) audio en beelden kan laden.
  String resolveMediaUrl(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !u.hasScheme) return baseUri.resolve(url).toString();
    const local = {'localhost', '127.0.0.1'};
    if (local.contains(u.host) && u.host != baseUri.host) {
      return u.replace(host: baseUri.host, port: baseUri.hasPort ? baseUri.port : null).toString();
    }
    return url;
  }

  PageResult<T> _page<T>(Map<String, dynamic> body, T Function(Map<String, dynamic>) parse) {
    final data = body['data'];
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    final items = data is List ? data.whereType<Map>().map((e) => parse(Map<String, dynamic>.from(e))).toList() : <T>[];
    final page = (meta['page'] as num?)?.toInt() ?? 1;
    final perPage = (meta['per_page'] as num?)?.toInt() ?? items.length;
    final total = (meta['total'] as num?)?.toInt() ?? items.length;
    final last = (meta['last_page'] as num?)?.toInt() ?? (perPage > 0 ? (total / perPage).ceil() : 1);
    return PageResult(items: items, page: page, lastPage: last < 1 ? 1 : last, total: total);
  }

  Future<List<HomeSection>> home() async {
    final body = await _get('home');
    final sections = (body['data'] is Map ? body['data']['sections'] : null);
    return sections is List
        ? sections.whereType<Map>().map((e) => HomeSection.fromJson(Map<String, dynamic>.from(e))).toList()
        : const [];
  }

  Future<List<Category>> categories() async {
    final body = await _get('categories');
    final data = body['data'];
    return data is List ? data.whereType<Map>().map((e) => Category.fromJson(Map<String, dynamic>.from(e))).toList() : const [];
  }

  Future<PageResult<ArticleSummary>> articles({int page = 1, int perPage = 20, String? category, String? author, bool? hasAudio}) async {
    final body = await _get('articles', {
      'page': '$page',
      'per_page': '$perPage',
      'category': category,
      'author': author,
      'has_audio': hasAudio?.toString(),
    });
    return _page(body, ArticleSummary.fromJson);
  }

  Future<ArticleDetail> article(String idOrSlug) async {
    final body = await _get('articles/${Uri.encodeComponent(idOrSlug)}');
    final data = body['data'];
    if (data is! Map) throw const ApiException('Artikel niet gevonden.', status: 404);
    return ArticleDetail.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PageResult<SearchResult>> search(String query, {int page = 1}) async {
    final body = await _get('search', {'q': query, 'type': 'article', 'page': '$page'});
    return _page(body, SearchResult.fromJson);
  }

  void dispose() => _http.close();
}
