import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../state/player_controller.dart';
import '../state/settings_store.dart';
import '../theme/tokens.dart';
import '../util/format.dart';
import '../widgets/cover_art.dart';
import 'article_screen.dart';

/// Volledige speler: cover, voortgang, -10/+30 s, snelheid, slaaptimer en "lees mee".
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const PlayerScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic)).animate(anim),
        child: child,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final article = ctrl.current;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    if (article == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Er speelt niets.')));
    }
    final color = HrpColors.forKey(article.category?.slug ?? '${article.id}');

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, c.surface, 0.55)!, c.surface],
            stops: const [0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            child: Column(children: [
              Row(children: [
                IconButton(
                  tooltip: 'Speler sluiten',
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(article.category?.name ?? 'Nu aan het luisteren',
                      textAlign: TextAlign.center, style: t.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  tooltip: 'Stoppen',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () async {
                    await ctrl.stop();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ]),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.l),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Radii.l),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 30, offset: Offset(0, 14))],
                          ),
                          child: CoverArt(article: article, radius: Radii.l),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(article.title, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.titleLarge?.copyWith(fontFamily: 'serif')),
              if (article.authorLine.isNotEmpty) ...[
                const SizedBox(height: Space.xs),
                Text(article.authorLine, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
              ],
              if (ctrl.error != null) ...[
                const SizedBox(height: Space.s),
                Text(ctrl.error!, style: t.bodySmall?.copyWith(color: c.error), textAlign: TextAlign.center),
              ],
              const SizedBox(height: Space.l),
              _ProgressBar(player: ctrl.player, onSeek: ctrl.seek),
              const SizedBox(height: Space.s),
              _Controls(ctrl: ctrl),
              const SizedBox(height: Space.l),
              _BottomActions(ctrl: ctrl),
              const SizedBox(height: Space.l),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.player, required this.onSeek});
  final AudioPlayer player;
  final Future<void> Function(Duration) onSeek;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      builder: (context, snap) {
        final dur = widget.player.duration ?? Duration.zero;
        final pos = snap.data ?? Duration.zero;
        final max = dur.inMilliseconds.toDouble();
        final value = (_dragValue ?? pos.inMilliseconds.toDouble()).clamp(0.0, max > 0 ? max : 1.0);
        final shown = Duration(milliseconds: value.round());
        return Column(children: [
          Slider(
            value: value,
            max: max > 0 ? max : 1.0,
            semanticFormatterCallback: (v) => '${formatClock(Duration(milliseconds: v.round()))} van ${formatClock(dur)}',
            onChanged: max > 0 ? (v) => setState(() => _dragValue = v) : null,
            onChangeEnd: max > 0
                ? (v) async {
                    await widget.onSeek(Duration(milliseconds: v.round()));
                    if (mounted) setState(() => _dragValue = null);
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            child: Row(children: [
              Text(formatClock(shown), style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
              const Spacer(),
              Text(dur == Duration.zero ? '--:--' : '-${formatClock(dur - shown)}', style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
            ]),
          ),
        ]);
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.ctrl});
  final PlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: ctrl.player.playerStateStream,
      builder: (context, snap) {
        final s = snap.data;
        final busy = ctrl.loading || s?.processingState == ProcessingState.loading || s?.processingState == ProcessingState.buffering;
        final playing = s?.playing ?? false;
        return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(
            tooltip: '10 seconden terug',
            iconSize: 36,
            icon: const Icon(Icons.replay_10_rounded),
            onPressed: () => ctrl.seekRelative(const Duration(seconds: -10)),
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: Material(
              color: HrpColors.red,
              shape: const CircleBorder(),
              child: busy
                  ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : IconButton(
                      tooltip: playing ? 'Pauzeren' : 'Afspelen',
                      iconSize: 44,
                      color: Colors.white,
                      icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      onPressed: ctrl.togglePlay,
                    ),
            ),
          ),
          IconButton(
            tooltip: '30 seconden vooruit',
            iconSize: 36,
            icon: const Icon(Icons.forward_30_rounded),
            onPressed: () => ctrl.seekRelative(const Duration(seconds: 30)),
          ),
        ]);
      },
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.ctrl});
  final PlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final speed = context.select<SettingsStore, double>((s) => s.speed);
    final article = ctrl.current!;
    final sleepLabel = switch (ctrl.sleep) {
      SleepAfter() => 'Tot ${TimeOfDay.fromDateTime(ctrl.sleepEndsAt!).format(context)}',
      SleepAtEnd() => 'Einde artikel',
      SleepOff() || null => 'Slaaptimer',
    };
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      TextButton.icon(
        onPressed: () {
          const speeds = SettingsStore.speeds;
          final i = speeds.indexOf(speed);
          ctrl.setSpeed(speeds[(i + 1) % speeds.length]);
        },
        icon: const Icon(Icons.speed_rounded),
        label: Text('${_fmtSpeed(speed)}×'),
      ),
      TextButton.icon(
        onPressed: () => _pickSleep(context),
        icon: Icon(ctrl.sleep == null ? Icons.bedtime_outlined : Icons.bedtime_rounded),
        label: Text(sleepLabel),
      ),
      TextButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleScreen(summary: article))),
        icon: const Icon(Icons.article_outlined),
        label: const Text('Lees mee'),
      ),
    ]);
  }

  String _fmtSpeed(double s) => s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toString().replaceAll('.', ',');

  Future<void> _pickSleep(BuildContext context) async {
    final choice = await showModalBottomSheet<SleepTimer?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final m in [5, 15, 30, 45, 60])
            ListTile(title: Text('$m minuten'), onTap: () => Navigator.pop(context, SleepAfter(Duration(minutes: m)))),
          ListTile(title: const Text('Einde van het artikel'), onTap: () => Navigator.pop(context, const SleepAtEnd())),
          if (ctrl.sleep != null)
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Slaaptimer uitzetten'),
              onTap: () => Navigator.pop(context, const SleepOff()),
            ),
        ]),
      ),
    );
    if (choice == null) return; // sheet gesloten zonder keuze
    ctrl.setSleepTimer(choice);
  }
}
