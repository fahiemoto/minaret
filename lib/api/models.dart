// Datamodellen voor de publieke API van hetrechtepad.nl (/api/v1, OpenAPI v1.1).
// Teksten (titels, omschrijvingen) worden letterlijk overgenomen en nooit aangepast.

int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

class CategoryRef {
  const CategoryRef({required this.slug, required this.name});
  final String slug;
  final String name;

  static CategoryRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final slug = _str(json['slug']);
    if (slug == null) return null;
    return CategoryRef(slug: slug, name: _str(json['name']) ?? slug);
  }

  Map<String, dynamic> toJson() => {'slug': slug, 'name': name};
}

class AuthorRef {
  const AuthorRef({required this.name, required this.slug});
  final String name;
  final String slug;

  factory AuthorRef.fromJson(Map<String, dynamic> json) =>
      AuthorRef(name: _str(json['name']) ?? '', slug: _str(json['slug']) ?? '');

  Map<String, dynamic> toJson() => {'name': name, 'slug': slug};
}

class AudioInfo {
  const AudioInfo({required this.ready, this.durationSeconds, this.url, this.timingsUrl});
  const AudioInfo.unavailable() : this(ready: false);

  final bool ready;
  final int? durationSeconds;
  final String? url;
  final String? timingsUrl;

  factory AudioInfo.fromJson(Object? json) {
    if (json is! Map) return const AudioInfo.unavailable();
    final ready = json['status'] == 'ready';
    return AudioInfo(
      ready: ready,
      durationSeconds: _int(json['duration_seconds']),
      url: ready ? _str(json['url']) : null,
      timingsUrl: ready ? _str(json['timings_url']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': ready ? 'ready' : 'unavailable',
        'duration_seconds': durationSeconds,
        if (url != null) 'url': url,
        if (timingsUrl != null) 'timings_url': timingsUrl,
      };
}

class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.url,
    this.excerpt,
    this.category,
    this.authors = const [],
    this.readingMinutes,
    this.image,
    this.imageWide,
    this.audio = const AudioInfo.unavailable(),
    this.publishedAt,
  });

  final int id;
  final String slug;
  final String title;
  final String url;
  final String? excerpt;
  final CategoryRef? category;
  final List<AuthorRef> authors;
  final int? readingMinutes;
  final String? image;
  final String? imageWide;
  final AudioInfo audio;
  final DateTime? publishedAt;

  bool get hasAudio => audio.ready;
  String get authorLine => authors.map((a) => a.name).where((n) => n.isNotEmpty).join(', ');

  factory ArticleSummary.fromJson(Map<String, dynamic> json) => ArticleSummary(
        id: _int(json['id']) ?? 0,
        slug: _str(json['slug']) ?? '',
        title: (json['title'] as String?) ?? '',
        url: _str(json['url']) ?? '',
        excerpt: _str(json['excerpt']),
        category: CategoryRef.fromJson(json['category']),
        authors: _list(json['authors']).map(AuthorRef.fromJson).toList(),
        readingMinutes: _int(json['reading_minutes']),
        image: _str(json['image']),
        imageWide: _str(json['image_wide']) ?? _str(json['image']),
        audio: AudioInfo.fromJson(json['audio']),
        publishedAt: _date(json['published_at']),
      );

  /// Zelfde sleutels als de API, zodat lokaal bewaarde items met [fromJson] terug te lezen zijn.
  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'title': title,
        'url': url,
        'excerpt': excerpt,
        'category': category?.toJson(),
        'authors': authors.map((a) => a.toJson()).toList(),
        'reading_minutes': readingMinutes,
        'image': image,
        'image_wide': imageWide,
        'audio': audio.toJson(),
        'published_at': publishedAt?.toIso8601String(),
      };
}

class ArticleDetail extends ArticleSummary {
  const ArticleDetail({
    required super.id,
    required super.slug,
    required super.title,
    required super.url,
    super.excerpt,
    super.category,
    super.authors,
    super.readingMinutes,
    super.image,
    super.imageWide,
    super.audio,
    super.publishedAt,
    required this.html,
    this.pdfUrl,
    this.revisionHash,
  });

  final String html;
  final String? pdfUrl;
  final String? revisionHash;

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    final s = ArticleSummary.fromJson(json);
    final pdf = json['pdf'];
    final rev = json['revision'];
    return ArticleDetail(
      id: s.id,
      slug: s.slug,
      title: s.title,
      url: s.url,
      excerpt: s.excerpt,
      category: s.category,
      authors: s.authors,
      readingMinutes: s.readingMinutes,
      image: s.image,
      imageWide: s.imageWide,
      audio: s.audio,
      publishedAt: s.publishedAt,
      html: (json['html'] as String?) ?? '',
      pdfUrl: pdf is Map ? _str(pdf['url']) : null,
      revisionHash: rev is Map ? _str(rev['projection_sha256']) : null,
    );
  }

  /// Samenvatting zonder de (grote) HTML, voor lokale opslag.
  ArticleSummary toSummary() => ArticleSummary(
        id: id,
        slug: slug,
        title: title,
        url: url,
        excerpt: excerpt,
        category: category,
        authors: authors,
        readingMinutes: readingMinutes,
        image: image,
        imageWide: imageWide,
        audio: AudioInfo(ready: audio.ready, durationSeconds: audio.durationSeconds),
        publishedAt: publishedAt,
      );
}

class HomeSection {
  const HomeSection({required this.key, required this.type, required this.title, this.category, required this.items});

  final String key;
  final String type; // carousel | row
  final String title;
  final CategoryRef? category;
  final List<ArticleSummary> items;

  bool get isCarousel => type == 'carousel';

  factory HomeSection.fromJson(Map<String, dynamic> json) => HomeSection(
        key: _str(json['key']) ?? '',
        type: _str(json['type']) ?? 'row',
        title: (json['title'] as String?) ?? '',
        category: CategoryRef.fromJson(json['category']),
        items: _list(json['items']).map(ArticleSummary.fromJson).toList(),
      );
}

class Category {
  const Category({required this.slug, required this.name, this.description, this.articleTotal = 0, this.children = const []});

  final String slug;
  final String name;
  final String? description;
  final int articleTotal;
  final List<Category> children;

  CategoryRef get ref => CategoryRef(slug: slug, name: name);

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        slug: _str(json['slug']) ?? '',
        name: (json['name'] as String?) ?? '',
        description: _str(json['description']),
        articleTotal: _int(json['article_total']) ?? 0,
        children: _list(json['children']).map(Category.fromJson).toList(),
      );
}

class PageResult<T> {
  const PageResult({required this.items, required this.page, required this.lastPage, required this.total});

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

class SearchResult {
  const SearchResult({required this.type, required this.title, required this.url, this.category, this.summary, this.readingMinutes, this.imageUrl});

  final String type; // article | news | page
  final String title;
  final String url;
  final String? category;
  final String? summary;
  final int? readingMinutes;
  final String? imageUrl;

  /// Artikel-URL's zijn /{slug}; de slug is het laatste padsegment.
  String? get articleSlug {
    if (type != 'article') return null;
    final segments = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const [];
    return segments.isEmpty ? null : segments.last;
  }

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        type: _str(json['type']) ?? 'article',
        title: (json['title'] as String?) ?? '',
        url: _str(json['url']) ?? '',
        category: _str(json['category']),
        summary: _str(json['summary']),
        readingMinutes: _int(json['reading_minutes']),
        imageUrl: _str(json['image_url']),
      );
}
