import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../screens/article_screen.dart';
import '../state/library_store.dart';
import '../theme/tokens.dart';
import '../util/format.dart';
import 'cover_art.dart';

void openArticle(BuildContext context, ArticleSummary a) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleScreen(summary: a)));
}

/// Kaart in een horizontale rij: vierkante cover, titel, auteur en meta.
class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article, this.width = 150});

  final ArticleSummary article;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final progress = context.select<LibraryStore, double?>((l) => l.progressFor(article.id)?.fraction);
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: '${article.title}. ${articleMeta(article)}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.m),
          onTap: () => openArticle(context, article),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(fit: StackFit.expand, children: [
                CoverArt(article: article),
                if (article.hasAudio) const Positioned(right: 6, bottom: 6, child: _AudioBadge()),
              ]),
            ),
            if (progress != null && progress > 0) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: progress, minHeight: 3, color: HrpColors.red, backgroundColor: c.outlineVariant),
              ),
            ],
            const SizedBox(height: Space.s),
            Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
            if (article.authorLine.isNotEmpty)
              Text(article.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            Text(articleMeta(article), style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _AudioBadge extends StatelessWidget {
  const _AudioBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: const Icon(Icons.headphones_rounded, size: 14, color: Colors.white),
      );
}

/// Horizontale rij kaarten.
class ArticleRow extends StatelessWidget {
  const ArticleRow({super.key, required this.items});
  final List<ArticleSummary> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 262,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: Space.m),
        itemBuilder: (_, i) => ArticleCard(article: items[i]),
      ),
    );
  }
}

/// Lijstregel voor overzichten, zoeken en "Mijn lijst".
class ArticleTile extends StatelessWidget {
  const ArticleTile({super.key, required this.article, this.progress, this.trailing});

  final ArticleSummary article;
  final ListeningProgress? progress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final p = progress;
    return InkWell(
      onTap: () => openArticle(context, article),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 76, height: 76, child: CoverArt(article: article, radius: Radii.s, showTitle: false)),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (article.authorLine.isNotEmpty)
                Text(article.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                [if (article.category != null) article.category!.name, articleMeta(article)].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
              ),
              if (p != null && p.positionMs > 0) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(value: p.fraction, minHeight: 3, color: HrpColors.red, backgroundColor: c.outlineVariant),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Text(p.finished ? 'Beluisterd' : 'Nog ${formatDurationShort(p.remaining.inSeconds)}', style: t.labelSmall),
                ]),
              ],
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

/// Grote uitgelichte carrousel bovenaan Home; handmatig te bedienen, geen autoplay.
class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({super.key, required this.items});
  final List<ArticleSummary> items;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  final _controller = PageController(viewportFraction: 0.86);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.86 * 1.2).clamp(320.0, 520.0);
    return Column(children: [
      SizedBox(
        height: height,
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.items.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            final a = widget.items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Semantics(
                button: true,
                label: 'Uitgelicht: ${a.title}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => openArticle(context, a),
                  child: Stack(fit: StackFit.expand, children: [
                    CoverArt(article: a, wide: true, radius: Radii.l, showTitle: false),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.l),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.35, 1],
                          colors: [Colors.transparent, Color(0xDD000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: Space.xl,
                      right: Space.xl,
                      bottom: Space.xl,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (a.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: HrpColors.red, borderRadius: BorderRadius.circular(Radii.pill)),
                            child: Text(a.category!.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        const SizedBox(height: Space.s),
                        Text(
                          a.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontFamily: 'serif', fontSize: 26, fontWeight: FontWeight.w700, height: 1.15),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          [if (a.authorLine.isNotEmpty) a.authorLine, articleMeta(a)].join(' · '),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: Space.m),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.items.length, (i) {
          final active = i == _index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? HrpColors.red : Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    ]);
  }
}
