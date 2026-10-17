import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../screens/player_screen.dart';
import '../state/player_controller.dart';
import '../theme/tokens.dart';
import 'cover_art.dart';

/// Compacte speler onderaan; tik opent de volledige speler. Verborgen als er niets speelt.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final article = ctrl.current;
    if (article == null) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.s),
      child: Material(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.l),
        elevation: 6,
        shadowColor: Colors.black26,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => PlayerScreen.open(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.s, Space.s, Space.xs, Space.s),
            child: Row(children: [
              SizedBox(width: 44, height: 44, child: CoverArt(article: article, radius: Radii.s, showTitle: false)),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(article.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  StreamBuilder<Duration>(
                    stream: ctrl.player.positionStream,
                    builder: (context, snap) {
                      final dur = ctrl.player.duration ?? Duration.zero;
                      final pos = snap.data ?? Duration.zero;
                      final pct = dur.inMilliseconds == 0 ? 0 : (pos.inMilliseconds * 100 ~/ dur.inMilliseconds);
                      return Text('$pct%', style: t.labelSmall?.copyWith(color: c.onSurfaceVariant));
                    },
                  ),
                ]),
              ),
              StreamBuilder<PlayerState>(
                stream: ctrl.player.playerStateStream,
                builder: (context, snap) {
                  final state = snap.data;
                  final busy = ctrl.loading ||
                      state?.processingState == ProcessingState.loading ||
                      state?.processingState == ProcessingState.buffering;
                  final playing = state?.playing ?? false;
                  return SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(alignment: Alignment.center, children: [
                      StreamBuilder<Duration>(
                        stream: ctrl.player.positionStream,
                        builder: (context, s) {
                          final dur = ctrl.player.duration ?? Duration.zero;
                          final v = dur.inMilliseconds == 0 ? 0.0 : (s.data ?? Duration.zero).inMilliseconds / dur.inMilliseconds;
                          return CircularProgressIndicator(
                            value: busy ? null : v.clamp(0.0, 1.0),
                            strokeWidth: 2.5,
                            color: HrpColors.red,
                            backgroundColor: c.outlineVariant,
                          );
                        },
                      ),
                      IconButton(
                        tooltip: playing ? 'Pauzeren' : 'Afspelen',
                        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        onPressed: ctrl.togglePlay,
                      ),
                    ]),
                  );
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
