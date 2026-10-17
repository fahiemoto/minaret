import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/library_store.dart';
import '../theme/tokens.dart';
import '../widgets/article_widgets.dart';
import '../widgets/common.dart';

enum _Shelf { listening, saved, finished }

/// Mijn lijst: verder luisteren, bewaard en beluisterd (lokaal op dit toestel).
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _Shelf _shelf = _Shelf.listening;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final labels = {_Shelf.listening: 'Verder luisteren', _Shelf.saved: 'Bewaard', _Shelf.finished: 'Beluisterd'};

    Widget list;
    switch (_shelf) {
      case _Shelf.listening:
        final items = lib.continueListening;
        list = items.isEmpty
            ? const StatusView(
                icon: Icons.headphones_rounded,
                title: 'Nog niets aan het luisteren',
                message: 'Start een artikel met audio; je kunt hier later verder waar je gebleven was.',
              )
            : _list(items.map((p) => ArticleTile(
                  article: p.article,
                  progress: p,
                  trailing: IconButton(
                    tooltip: 'Verwijderen uit verder luisteren',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => lib.removeProgress(p.article.id),
                  ),
                )));
      case _Shelf.saved:
        final items = lib.saved;
        list = items.isEmpty
            ? const StatusView(
                icon: Icons.favorite_border_rounded,
                title: 'Nog niets bewaard',
                message: 'Tik op het hartje bij een artikel om het hier te bewaren.',
              )
            : _list(items.map((a) => ArticleTile(
                  article: a,
                  progress: lib.progressFor(a.id),
                  trailing: IconButton(
                    tooltip: 'Uit mijn lijst halen',
                    icon: const Icon(Icons.favorite_rounded, color: HrpColors.red),
                    onPressed: () => lib.toggleSaved(a),
                  ),
                )));
      case _Shelf.finished:
        final items = lib.finished;
        list = items.isEmpty
            ? const StatusView(icon: Icons.check_circle_outline_rounded, title: 'Nog niets beluisterd')
            : _list(items.map((p) => ArticleTile(article: p.article, progress: p)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mijn lijst')),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.s),
            children: [
              for (final s in _Shelf.values) ...[
                ChoiceChip(label: Text(labels[s]!), selected: _shelf == s, onSelected: (_) => setState(() => _shelf = s)),
                const SizedBox(width: Space.s),
              ],
            ],
          ),
        ),
        Expanded(child: list),
      ]),
    );
  }

  Widget _list(Iterable<Widget> tiles) {
    final items = tiles.toList();
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 180),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(indent: Space.l, endIndent: Space.l),
      itemBuilder: (_, i) => items[i],
    );
  }
}
