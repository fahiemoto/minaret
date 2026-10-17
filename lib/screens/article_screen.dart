import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/library_store.dart';
import '../state/player_controller.dart';
import '../theme/tokens.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/mini_player.dart';
import 'article_list_screen.dart';
import 'player_screen.dart';

/// Artikeldetail: cover, kerngegevens, luisterknop en de volledige tekst (letterlijk uit de API).
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, this.summary, this.slug}) : assert(summary != null || slug != null);

  final ArticleSummary? summary;
  final String? slug;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late Future<ArticleDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ArticleDetail> _load() => context.read<ApiClient>().article(widget.summary?.slug ?? widget.slug!);

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ArticleDetail>(
        future: _future,
        builder: (context, snap) {
          final detail = snap.data;
          final summary = detail ?? widget.summary;
          if (snap.hasError) {
            return Scaffold(appBar: AppBar(), body: StatusView.error(message: '${snap.error}', onAction: _retry));
          }
          if (summary == null) return Scaffold(appBar: AppBar(), body: const LoadingView());
          return CustomScrollView(slivers: [
            _Header(article: summary),
            SliverToBoxAdapter(child: _Intro(article: summary, detail: detail)),
            if (detail == null)
              const SliverToBoxAdapter(child: LoadingView())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, 160),
                sliver: SliverToBoxAdapter(child: _Body(html: detail.html)),
              ),
          ]);
        },
      ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.article});
  final ArticleSummary article;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final color = HrpColors.forKey(article.category?.slug ?? '${article.id}');
    return SliverAppBar(
      pinned: true,
      expandedHeight: width * 0.78,
      backgroundColor: Color.lerp(color, Colors.black, 0.45),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, Color.lerp(color, Colors.black, 0.55)!],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, 48, Space.xl, Space.xl),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.m),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 10))],
                    ),
                    child: CoverArt(article: article),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.article, required this.detail});
  final ArticleSummary article;
  final ArticleDetail? detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final lib = context.watch<LibraryStore>();
    final player = context.watch<PlayerController>();
    final progress = lib.progressFor(article.id);
    final saved = lib.isSaved(article.id);
    final isCurrent = player.isCurrent(article.id);

    final metaParts = <String>[
      if (article.hasAudio && (article.audio.durationSeconds ?? 0) > 0) 'Luisteren ${formatDurationShort(article.audio.durationSeconds!)}',
      if ((article.readingMinutes ?? 0) > 0) 'Lezen ${article.readingMinutes} min',
      if (article.publishedAt != null) formatDate(article.publishedAt),
    ];

    String playLabel;
    if (!article.hasAudio) {
      playLabel = 'Audio volgt nog';
    } else if (isCurrent) {
      playLabel = 'Open speler';
    } else if (progress != null && !progress.finished && progress.positionMs > 0) {
      playLabel = 'Verder luisteren';
    } else {
      playLabel = 'Luister';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (article.category != null)
          GestureDetector(
            onTap: () => ArticleListScreen.open(context, title: article.category!.name, category: article.category!.slug),
            child: Text(article.category!.name.toUpperCase(),
                style: t.labelMedium?.copyWith(color: HrpColors.red, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: Space.xs),
        SelectableText(article.title, style: t.headlineSmall),
        if (article.authorLine.isNotEmpty) ...[
          const SizedBox(height: Space.xs),
          Wrap(spacing: Space.s, children: [
            for (final a in article.authors)
              GestureDetector(
                onTap: a.slug.isEmpty ? null : () => ArticleListScreen.open(context, title: a.name, author: a.slug),
                child: Text(a.name, style: t.bodyMedium?.copyWith(decoration: TextDecoration.underline, decorationColor: c.outlineVariant)),
              ),
          ]),
        ],
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: Space.xs),
          Text(metaParts.join(' · '), style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
        const SizedBox(height: Space.l),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: HrpColors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              onPressed: !article.hasAudio || detail == null
                  ? null
                  : () async {
                      final d = detail;
                      if (d == null) return;
                      if (isCurrent) {
                        PlayerScreen.open(context);
                        return;
                      }
                      await context.read<PlayerController>().playArticle(d);
                      if (context.mounted) PlayerScreen.open(context);
                    },
              icon: Icon(article.hasAudio ? Icons.play_arrow_rounded : Icons.schedule_rounded),
              label: Text(playLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: Space.s),
          IconButton.outlined(
            tooltip: saved ? 'Uit mijn lijst halen' : 'Bewaren in mijn lijst',
            onPressed: () => lib.toggleSaved(detail?.toSummary() ?? article),
            icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: saved ? HrpColors.red : null),
          ),
        ]),
        if (progress != null && progress.positionMs > 0 && article.hasAudio) ...[
          const SizedBox(height: Space.m),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: progress.fraction, minHeight: 3, color: HrpColors.red, backgroundColor: c.outlineVariant),
              ),
            ),
            const SizedBox(width: Space.s),
            Text(progress.finished ? 'Beluisterd' : 'Nog ${formatDurationShort(progress.remaining.inSeconds)}', style: t.labelSmall),
          ]),
        ],
        if (article.excerpt != null) ...[
          const SizedBox(height: Space.l),
          Text(article.excerpt!, style: t.bodyLarge?.copyWith(fontStyle: FontStyle.italic, color: c.onSurfaceVariant)),
        ],
        const SizedBox(height: Space.m),
        const Divider(),
      ]),
    );
  }
}

/// Tekst letterlijk zoals de site hem publiceert (veilige HTML uit de API); alleen opmaak, nooit inhoud aanpassen.
class _Body extends StatelessWidget {
  const _Body({required this.html});
  final String html;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return SelectionArea(
      child: HtmlWidget(
        html,
        textStyle: t.bodyLarge?.copyWith(height: 1.6, fontSize: 17, color: c.onSurface),
        customStylesBuilder: (element) {
          switch (element.localName) {
            case 'h2':
            case 'h3':
              return {'font-family': 'serif', 'margin-top': '1.2em'};
            case 'blockquote':
              return {'border-left': '3px solid #dc143c', 'padding-left': '12px', 'margin-left': '0', 'font-style': 'italic'};
            case 'a':
              return {'color': '#dc143c'};
          }
          // Interface-elementen van de website (knoppen, deel-links) horen niet in de app.
          if (element.attributes.containsKey('data-hrp-ui')) return {'display': 'none'};
          return null;
        },
        onTapUrl: (url) async {
          final uri = Uri.tryParse(url);
          final segs = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const [];
          // Interne artikellink (/{slug}) in de app openen.
          if (uri != null && segs.length == 1 && (uri.host.isEmpty || uri.host.contains('hetrechtepad'))) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleScreen(slug: segs.first)));
            return true;
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Externe link: $url')));
          return true;
        },
      ),
    );
  }
}
