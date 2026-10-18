import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/library_store.dart';
import '../state/player_controller.dart';
import '../theme/tokens.dart';
import '../util/format.dart';
import '../util/article_links.dart';
import '../util/read_along.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/mini_player.dart';
import 'article_list_screen.dart';
import 'player_screen.dart';

/// Artikeldetail: cover, kerngegevens, luisterknop en de volledige tekst (letterlijk uit de API).
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, this.summary, this.slug})
      : assert(summary != null || slug != null);

  final ArticleSummary? summary;
  final String? slug;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late Future<ArticleDetail> _future;

  // Meelezen: zinstijden van de site, de huidige zin en de tekst met die zin gemarkeerd.
  late final PlayerController _player;
  StreamSubscription<Duration>? _positionSub;
  ArticleDetail? _detail;
  ReadAlongDocument? _readDoc;
  ReadAlongTimings? _timings;
  bool _readAlongOn = true;
  int _sentence = -1;
  String? _markedHtml;
  final _anchorKey = GlobalKey();
  DateTime _userScrolledAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerController>();
    _positionSub = _player.positionStream.listen(_onPosition);
    _future = _load();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<ArticleDetail> _load() async {
    final api = context.read<ApiClient>();
    final detail = await api.article(widget.summary?.slug ?? widget.slug!);
    _detail = detail;
    unawaited(_loadTimings(api, detail));
    return detail;
  }

  Future<void> _loadTimings(ApiClient api, ArticleDetail detail) async {
    final url = detail.audio.timingsUrl;
    if (url == null) return;
    final timings = await api.readAlongTimings(url);
    if (timings == null || !mounted || _detail != detail) return;
    final doc = ReadAlongDocument(detail.html);
    // Klopt de indeling niet met deze tekst, dan liever geen markering dan een verkeerde.
    if (!timings.matches(doc)) return;
    setState(() {
      _readDoc = doc;
      _timings = timings;
    });
    _onPosition(_player.position);
  }

  void _retry() => setState(() => _future = _load());

  void _onPosition(Duration position) {
    final timings = _timings;
    final detail = _detail;
    final index = timings == null ||
            detail == null ||
            !_readAlongOn ||
            !_player.isCurrent(detail.id)
        ? -1
        : timings.indexAt(position.inMilliseconds);
    if (index == _sentence || !mounted) return;
    setState(() {
      _sentence = index;
      _markedHtml =
          index < 0 ? null : _readDoc!.mark(timings!.sentences[index]);
    });
    if (index >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    }
  }

  void _toggleReadAlong() {
    setState(() => _readAlongOn = !_readAlongOn);
    _sentence = -2; // forceer opnieuw tekenen
    _onPosition(_player.position);
  }

  /// Houd de zin in beeld, behalve kort nadat de lezer zelf heeft gescrold.
  void _follow() {
    final ctx = _anchorKey.currentContext;
    if (ctx == null || !mounted) return;
    if (DateTime.now().difference(_userScrolledAt) <
        const Duration(seconds: 5)) {
      return;
    }
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final y = box.localToGlobal(Offset.zero).dy;
    final h = MediaQuery.sizeOf(context).height;
    if (y >= h * 0.2 && y <= h * 0.7) return;
    final reduce = MediaQuery.of(context).disableAnimations;
    Scrollable.ensureVisible(ctx,
        alignment: 0.35,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
        curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ArticleDetail>(
        future: _future,
        builder: (context, snap) {
          final detail = snap.data;
          final summary = detail ?? widget.summary;
          if (snap.hasError) {
            return Scaffold(
                appBar: AppBar(),
                body: StatusView.error(
                    message: '${snap.error}', onAction: _retry));
          }
          if (summary == null) {
            return Scaffold(appBar: AppBar(), body: const LoadingView());
          }
          final sentence =
              _sentence >= 0 ? _timings!.sentences[_sentence] : null;
          return NotificationListener<UserScrollNotification>(
            onNotification: (_) {
              _userScrolledAt = DateTime.now();
              return false;
            },
            child: CustomScrollView(slivers: [
              _Header(
                article: summary,
                actions: [
                  if (_timings != null && _player.isCurrent(summary.id))
                    IconButton(
                      tooltip: _readAlongOn
                          ? 'Meelezen uitzetten'
                          : 'Meelezen aanzetten',
                      onPressed: _toggleReadAlong,
                      icon: Icon(_readAlongOn
                          ? Icons.subtitles_rounded
                          : Icons.subtitles_off_outlined),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                  child: _Intro(
                      article: summary,
                      detail: detail,
                      titleActive: sentence?.segment == 0)),
              if (detail == null)
                const SliverToBoxAdapter(child: LoadingView())
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, 160),
                  sliver: SliverToBoxAdapter(
                      child: _Body(
                          html: _markedHtml ?? detail.html,
                          articleUrl: detail.url,
                          anchorKey: _anchorKey)),
                ),
            ]),
          );
        },
      ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.article, this.actions = const []});
  final ArticleSummary article;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final color = HrpColors.forKey(article.category?.slug ?? '${article.id}');
    return SliverAppBar(
      pinned: true,
      expandedHeight: width * 0.78,
      backgroundColor: Color.lerp(color, Colors.black, 0.45),
      foregroundColor: Colors.white,
      actions: actions,
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
                padding:
                    const EdgeInsets.fromLTRB(Space.xl, 48, Space.xl, Space.xl),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.m),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black38,
                            blurRadius: 24,
                            offset: Offset(0, 10))
                      ],
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
  const _Intro(
      {required this.article, required this.detail, this.titleActive = false});
  final ArticleSummary article;
  final ArticleDetail? detail;

  /// De titel wordt op dit moment voorgelezen.
  final bool titleActive;

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
      if (article.hasAudio && (article.audio.durationSeconds ?? 0) > 0)
        'Luisteren ${formatDurationShort(article.audio.durationSeconds!)}',
      if ((article.readingMinutes ?? 0) > 0)
        'Lezen ${article.readingMinutes} min',
      if (article.publishedAt != null) formatDate(article.publishedAt),
    ];

    String playLabel;
    if (!article.hasAudio) {
      playLabel = 'Audio volgt nog';
    } else if (isCurrent) {
      playLabel = 'Open speler';
    } else if (progress != null &&
        !progress.finished &&
        progress.positionMs > 0) {
      playLabel = 'Verder luisteren';
    } else {
      playLabel = 'Luister';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (article.category != null)
          GestureDetector(
            onTap: () => ArticleListScreen.open(context,
                title: article.category!.name,
                category: article.category!.slug),
            child: Text(article.category!.name.toUpperCase(),
                style: t.labelMedium?.copyWith(
                    color: HrpColors.red,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: Space.xs),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: titleActive ? readAlongHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(article.title, style: t.headlineSmall),
        ),
        if (article.authorLine.isNotEmpty) ...[
          const SizedBox(height: Space.xs),
          Wrap(spacing: Space.s, children: [
            for (final a in article.authors)
              GestureDetector(
                onTap: a.slug.isEmpty
                    ? null
                    : () => ArticleListScreen.open(context,
                        title: a.name, author: a.slug),
                child: Text(a.name,
                    style: t.bodyMedium?.copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: c.outlineVariant)),
              ),
          ]),
        ],
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: Space.xs),
          Text(metaParts.join(' · '),
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
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
              icon: Icon(article.hasAudio
                  ? Icons.play_arrow_rounded
                  : Icons.schedule_rounded),
              label: Text(playLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: Space.s),
          IconButton.outlined(
            tooltip: saved ? 'Uit mijn lijst halen' : 'Bewaren in mijn lijst',
            onPressed: () => lib.toggleSaved(detail?.toSummary() ?? article),
            icon: Icon(
                saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: saved ? HrpColors.red : null),
          ),
        ]),
        if (progress != null &&
            progress.positionMs > 0 &&
            article.hasAudio) ...[
          const SizedBox(height: Space.m),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 3,
                    color: HrpColors.red,
                    backgroundColor: c.outlineVariant),
              ),
            ),
            const SizedBox(width: Space.s),
            Text(
                progress.finished
                    ? 'Beluisterd'
                    : 'Nog ${formatDurationShort(progress.remaining.inSeconds)}',
                style: t.labelSmall),
          ]),
        ],
        if (article.excerpt != null) ...[
          const SizedBox(height: Space.l),
          Text(article.excerpt!,
              style: t.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic, color: c.onSurfaceVariant)),
        ],
        const SizedBox(height: Space.m),
        const Divider(),
      ]),
    );
  }
}

/// Achtergrond van de zin die wordt voorgelezen (merkkleur, licht doorschijnend).
const readAlongHighlight = Color(0x38F43160);

/// Tekst letterlijk zoals de site hem publiceert (veilige HTML uit de API); alleen opmaak, nooit inhoud aanpassen.
class _Body extends StatelessWidget {
  const _Body(
      {required this.html, required this.articleUrl, required this.anchorKey});
  final String html;
  final String articleUrl;

  /// Nulbreed punt vóór de zin die wordt voorgelezen, om naartoe te scrollen.
  final GlobalKey anchorKey;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return SelectionArea(
      child: HtmlWidget(
        html,
        textStyle: t.bodyLarge
            ?.copyWith(height: 1.6, fontSize: 17, color: c.onSurface),
        customWidgetBuilder: (element) =>
            element.localName == readAlongAnchorTag
                ? InlineCustomWidget(
                    child: SizedBox(key: anchorKey, width: 0, height: 0))
                : null,
        customStylesBuilder: (element) {
          switch (element.localName) {
            case readAlongMarkTag:
              return {
                'background-color': 'rgba(244, 49, 96, 0.22)',
                'border-radius': '3px'
              };
            case 'h2':
            case 'h3':
              return {'font-family': 'serif', 'margin-top': '1.2em'};
            case 'blockquote':
              return {
                'border-left': '3px solid ${HrpColors.redCss}',
                'padding-left': '12px',
                'margin-left': '0',
                'font-style': 'italic'
              };
            case 'a':
              return {'color': HrpColors.redCss};
          }
          // Interface-elementen van de website (knoppen, deel-links) horen niet in de app.
          if (element.attributes.containsKey('data-hrp-ui')) {
            return {'display': 'none'};
          }
          return null;
        },
        onTapUrl: (url) async {
          if (url.startsWith('#')) return false;
          final uri = Uri.tryParse(articleUrl)?.resolve(url);
          final slug = uri == null ? null : internalArticleSlug(uri);
          if (slug != null) {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ArticleScreen(slug: slug)));
            return true;
          }
          var opened = false;
          if (uri != null &&
              const {'https', 'http', 'mailto', 'tel'}.contains(uri.scheme)) {
            try {
              opened =
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {
              // Geen geschikte app of het platform weigert de link.
            }
          }
          if (!opened && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Deze link kon niet worden geopend.')));
          }
          return true;
        },
      ),
    );
  }
}
