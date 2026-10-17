import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Kop boven een rij, met optionele "meer"-actie (hele kop is aanklikbaar, groot genoeg voor duimen).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.onMore});

  final String title;
  final String? subtitle;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.s, Space.s),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Text(subtitle!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
        if (onMore != null) const Padding(padding: EdgeInsets.all(Space.s), child: Icon(Icons.chevron_right_rounded)),
      ]),
    );
    return onMore == null
        ? content
        : Semantics(button: true, label: '$title, toon alles', child: InkWell(onTap: onMore, child: content));
  }
}

/// Laad-, fout- en leegstaat in één consistente vorm.
class StatusView extends StatelessWidget {
  const StatusView({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});

  const StatusView.error({super.key, required String this.message, this.onAction})
      : icon = Icons.wifi_off_rounded,
        title = 'Dat lukte niet',
        actionLabel = 'Opnieuw proberen';

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: HrpColors.red),
          const SizedBox(height: Space.l),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: Space.s),
            Text(message!, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.l),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(Space.xxl), child: CircularProgressIndicator(color: HrpColors.red)));
}

/// Officieel woordmerk: rood op licht, wit op donker (verhoudingen blijven behouden).
class HrpLogo extends StatelessWidget {
  const HrpLogo({super.key, this.height = 18});
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? 'assets/brand/logo-wit.png' : 'assets/brand/logo-rood.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Het Rechte Pad',
    );
  }
}
