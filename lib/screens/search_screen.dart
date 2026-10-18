import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import 'article_screen.dart';

/// Zoeken in gepubliceerde artikelen (Zam-zoekindex van de site). Toont alleen gelinkte resultaten.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.active});

  /// True als dit tabblad zichtbaar is (dan krijgt het zoekveld focus).
  final bool active;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  String? _error;
  List<SearchResult> _results = const [];
  int _total = 0;
  int _requestId = 0;
  int _page = 0;
  bool _hasMore = false;

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _focus.requestFocus();
    if (!widget.active && old.active) _focus.unfocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Maak ook reeds lopende verzoeken ongeldig zodra de invoer verandert.
    ++_requestId;
    setState(() {
      _query = value.trim();
      _results = const [];
      _total = 0;
      _page = 0;
      _hasMore = false;
      _error = null;
      _loading = _query.length >= 2;
    });
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _search(value.trim()));
  }

  Future<void> _search(String q, {bool more = false}) async {
    _debounce?.cancel();
    if (more && (_loading || !_hasMore)) return;
    final id = ++_requestId;
    final page = more ? _page + 1 : 1;
    setState(() {
      _query = q;
      _loading = q.length >= 2;
      _error = null;
      if (!more) {
        _results = const [];
        _total = 0;
        _page = 0;
        _hasMore = false;
      }
    });
    if (q.length < 2) return;
    try {
      final res = await context.read<ApiClient>().search(q, page: page);
      if (!mounted || id != _requestId) return;
      setState(() {
        final items = res.items.where((r) => r.articleSlug != null);
        _results = [..._results, ...items];
        _total = res.total;
        _page = res.page;
        _hasMore = res.hasMore;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = '$e');
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget body;
    if (_query.length < 2) {
      body = const StatusView(
          icon: Icons.search_rounded,
          title: 'Zoek in alle artikelen',
          message:
              'Typ minstens twee letters, bijvoorbeeld een onderwerp of een naam.');
    } else if (_loading && _results.isEmpty) {
      body = const LoadingView();
    } else if (_error != null && _results.isEmpty && _page == 0) {
      body =
          StatusView.error(message: _error!, onAction: () => _search(_query));
    } else if (_results.isEmpty && !_hasMore) {
      body = StatusView(
          icon: Icons.search_off_rounded,
          title: 'Niets gevonden',
          message:
              'Geen artikelen gevonden voor "$_query". Probeer een ander woord.');
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(bottom: 180),
        itemCount: _results.length + 2,
        separatorBuilder: (_, i) => i == 0
            ? const SizedBox.shrink()
            : const Divider(indent: Space.l, endIndent: Space.l),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding:
                  const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.s),
              child: Text(_total == 1 ? '1 resultaat' : '$_total resultaten',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.onSurfaceVariant)),
            );
          }
          if (i == _results.length + 1) {
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_hasMore) {
              return Column(children: [
                if (_error != null) Text(_error!),
                TextButton(
                  onPressed: () => _search(_query, more: true),
                  child: Text(
                      _error == null ? 'Meer resultaten' : 'Opnieuw proberen'),
                ),
              ]);
            }
            return const SizedBox.shrink();
          }
          final r = _results[i - 1];
          return _ResultTile(result: r);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Zoeken')),
      body: Column(children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Space.l, Space.xs, Space.l, Space.s),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: _onChanged,
            onSubmitted: (v) => _search(v.trim()),
            textInputAction: TextInputAction.search,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Zoek op onderwerp, titel of naam',
              counterText: '',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Wissen',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                    ),
              filled: true,
              fillColor: c.surfaceContainerLow,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide(color: c.outlineVariant)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide(color: c.outlineVariant)),
            ),
          ),
        ),
        if (_loading && _results.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2, color: HrpColors.red),
        Expanded(child: body),
      ]),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});
  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final img = result.imageUrl;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ArticleScreen(slug: result.articleSlug!))),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 64,
            height: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.s),
              child: img == null
                  ? GeneratedCover(seed: result.category ?? result.title)
                  : CachedNetworkImage(
                      imageUrl: Provider.of<ApiClient>(context, listen: false)
                          .resolveMediaUrl(img),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          GeneratedCover(seed: result.category ?? result.title),
                    ),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(result.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (result.summary != null)
                Text(result.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              Text(
                [
                  if (result.category != null) result.category!,
                  if ((result.readingMinutes ?? 0) > 0)
                    '${result.readingMinutes} min lezen'
                ].join(' · '),
                style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
