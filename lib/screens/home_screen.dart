import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/library_store.dart';
import '../theme/tokens.dart';
import '../widgets/article_widgets.dart';
import '../widgets/common.dart';
import 'article_list_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Wisselt van tabblad in de shell (1 = Ontdek).
  final ValueChanged<int> onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(List<HomeSection>, List<Category>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<HomeSection>, List<Category>)> _load() async {
    final api = context.read<ApiClient>();
    final results = await Future.wait([api.home(), api.categories()]);
    return (results[0] as List<HomeSection>, results[1] as List<Category>);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {
      // Fout wordt in de FutureBuilder getoond.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<(List<HomeSection>, List<Category>)>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError && !snap.hasData) return StatusView.error(message: '${snap.error}', onAction: _refresh);
            if (!snap.hasData) return const LoadingView();
            final (sections, categories) = snap.data!;
            return RefreshIndicator(
              color: HrpColors.red,
              onRefresh: _refresh,
              child: CustomScrollView(slivers: [
                SliverAppBar(
                  floating: true,
                  centerTitle: false,
                  titleSpacing: Space.l,
                  title: const HrpLogo(height: 24),
                  actions: [
                    IconButton(
                      tooltip: 'Profiel en instellingen',
                      icon: const Icon(Icons.account_circle_outlined),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    ),
                    const SizedBox(width: Space.xs),
                  ],
                ),
                SliverToBoxAdapter(child: _ChipsRow(categories: categories, onDiscover: () => widget.onOpenTab(1))),
                const SliverToBoxAdapter(child: _ContinueListening()),
                if (sections.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: StatusView(icon: Icons.menu_book_rounded, title: 'Nog geen artikelen', message: 'Zodra er artikelen gepubliceerd zijn, verschijnen ze hier.'),
                  ),
                for (final s in sections) ..._section(context, s),
                const SliverToBoxAdapter(child: SizedBox(height: 180)),
              ]),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _section(BuildContext context, HomeSection s) {
    if (s.isCarousel) {
      return [
        const SliverToBoxAdapter(child: SizedBox(height: Space.m)),
        SliverToBoxAdapter(child: FeaturedCarousel(items: s.items)),
      ];
    }
    final more = switch (s.key) {
      'listen' => () => ArticleListScreen.open(context, title: s.title, hasAudio: true),
      'latest' => () => ArticleListScreen.open(context, title: s.title),
      _ when s.category != null => () => ArticleListScreen.open(context, title: s.category!.name, category: s.category!.slug),
      _ => null,
    };
    return [
      SliverToBoxAdapter(child: SectionHeader(title: s.title, onMore: more)),
      SliverToBoxAdapter(child: ArticleRow(items: s.items)),
    ];
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.categories, required this.onDiscover});
  final List<Category> categories;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      ChoiceChip(label: const Text('Alles'), selected: true, onSelected: (_) {}),
      ActionChip(
        avatar: const Icon(Icons.headphones_rounded, size: 18),
        label: const Text('Om te luisteren'),
        onPressed: () => ArticleListScreen.open(context, title: 'Om te luisteren', hasAudio: true),
      ),
      for (final c in categories.where((c) => c.articleTotal > 0))
        ActionChip(label: Text(c.name), onPressed: () => ArticleListScreen.open(context, title: c.name, category: c.slug)),
      ActionChip(label: const Text('Alle onderwerpen'), onPressed: onDiscover),
    ];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.s),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: Space.s),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

/// "Verder luisteren": alleen zichtbaar als er iets half beluisterd is (lokaal).
class _ContinueListening extends StatelessWidget {
  const _ContinueListening();

  @override
  Widget build(BuildContext context) {
    final items = context.watch<LibraryStore>().continueListening.take(10).map((p) => p.article).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Verder luisteren'),
      ArticleRow(items: items),
    ]);
  }
}
