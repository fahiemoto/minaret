import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/tokens.dart';
import '../widgets/category_tile.dart';
import '../widgets/common.dart';
import 'article_list_screen.dart';

/// Ontdek: alle onderwerpen als tegels, plus snelkoppelingen.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late Future<List<Category>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().categories();
  }

  void _retry() => setState(() => _future = context.read<ApiClient>().categories());

  void _openCategory(Category c) {
    if (c.children.where((x) => x.articleTotal > 0).isEmpty) {
      ArticleListScreen.open(context, title: c.name, category: c.slug);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _SubcategoryScreen(category: c)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ontdek')),
      body: FutureBuilder<List<Category>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return StatusView.error(message: '${snap.error}', onAction: _retry);
          if (!snap.hasData) return const LoadingView();
          final cats = snap.data!.where((c) => c.articleTotal > 0).toList();
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.l),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.headphones_rounded,
                      label: 'Om te luisteren',
                      onTap: () => ArticleListScreen.open(context, title: 'Om te luisteren', hasAudio: true),
                    ),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.auto_stories_rounded,
                      label: 'Alle artikelen',
                      onTap: () => ArticleListScreen.open(context, title: 'Alle artikelen'),
                    ),
                  ),
                ]),
              ),
            ),
            if (cats.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: StatusView(icon: Icons.grid_view_rounded, title: 'Nog geen onderwerpen'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.l),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: Space.m,
                    crossAxisSpacing: Space.m,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: cats.length,
                  itemBuilder: (_, i) => CategoryTile(category: cats[i], onTap: () => _openCategory(cats[i])),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 180)),
          ]);
        },
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surfaceContainerLow,
      borderRadius: BorderRadius.circular(Radii.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.m),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.l),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: c.outlineVariant)),
          child: Row(children: [
            Icon(icon, color: HrpColors.red),
            const SizedBox(width: Space.s),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

class _SubcategoryScreen extends StatelessWidget {
  const _SubcategoryScreen({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    final subs = category.children.where((c) => c.articleTotal > 0).toList();
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: GridView.builder(
        padding: const EdgeInsets.all(Space.l),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: Space.m,
          crossAxisSpacing: Space.m,
          childAspectRatio: 1.45,
        ),
        itemCount: subs.length + 1,
        itemBuilder: (context, i) {
          final c = i == 0
              ? Category(slug: category.slug, name: 'Alles in ${category.name}', articleTotal: category.articleTotal)
              : subs[i - 1];
          return CategoryTile(category: c, onTap: () => ArticleListScreen.open(context, title: i == 0 ? category.name : c.name, category: c.slug));
        },
      ),
    );
  }
}
