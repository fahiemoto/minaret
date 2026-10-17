import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/library_store.dart';
import '../theme/tokens.dart';
import '../widgets/article_widgets.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';

/// Doorlopende lijst (paginering via de API) voor een onderwerp, "nieuw" of "om te luisteren".
class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key, required this.title, this.category, this.author, this.hasAudio});

  final String title;
  final String? category;
  final String? author;
  final bool? hasAudio;

  static void open(BuildContext context, {required String title, String? category, String? author, bool? hasAudio}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArticleListScreen(title: title, category: category, author: author, hasAudio: hasAudio),
    ));
  }

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  final _items = <ArticleSummary>[];
  final _scroll = ScrollController();
  int _page = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<ApiClient>().articles(
            page: _page + 1,
            category: widget.category,
            author: widget.author,
            hasAudio: widget.hasAudio,
          );
      if (!mounted) return;
      setState(() {
        _page = res.page;
        _total = res.total;
        _hasMore = res.hasMore;
        _items.addAll(res.items);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryStore>();
    Widget body;
    if (_items.isEmpty && _loading) {
      body = const LoadingView();
    } else if (_items.isEmpty && _error != null) {
      body = StatusView.error(message: _error!, onAction: _reload);
    } else if (_items.isEmpty) {
      body = StatusView(
        icon: widget.hasAudio == true ? Icons.headphones_rounded : Icons.menu_book_rounded,
        title: widget.hasAudio == true ? 'Nog geen audio' : 'Nog geen artikelen',
        message: widget.hasAudio == true
            ? 'Er zijn nog geen ingesproken artikelen. Kom binnenkort terug.'
            : 'In dit onderwerp staan nog geen gepubliceerde artikelen.',
      );
    } else {
      body = RefreshIndicator(
        color: HrpColors.red,
        onRefresh: _reload,
        child: ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: _items.length + 2,
          separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(indent: Space.l, endIndent: Space.l),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.s),
                child: Text(_total == 1 ? '1 artikel' : '$_total artikelen',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              );
            }
            if (i == _items.length + 1) {
              if (_error != null) {
                return TextButton(onPressed: _loadMore, child: const Text('Opnieuw laden'));
              }
              return _hasMore ? const LoadingView() : const SizedBox(height: Space.l);
            }
            final a = _items[i - 1];
            return ArticleTile(
              article: a,
              progress: library.progressFor(a.id),
              trailing: IconButton(
                tooltip: library.isSaved(a.id) ? 'Uit mijn lijst halen' : 'Bewaren in mijn lijst',
                icon: Icon(library.isSaved(a.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: library.isSaved(a.id) ? HrpColors.red : null),
                onPressed: () => library.toggleSaved(a),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: body,
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }
}
