import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/library_store.dart';
import '../state/settings_store.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Profiel en instellingen. Versie 1 heeft geen account: alles staat lokaal op dit toestel.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final lib = context.watch<LibraryStore>();
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profiel')),
      body: ListView(padding: const EdgeInsets.only(bottom: Space.xxl), children: [
        const SizedBox(height: Space.l),
        const Center(child: HrpLogo(height: 22)),
        const SizedBox(height: Space.l),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          child: Container(
            padding: const EdgeInsets.all(Space.l),
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: c.outlineVariant)),
            child: Row(children: [
              const Icon(Icons.phone_iphone_rounded, color: HrpColors.red),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text(
                  'Je voortgang en bewaarde artikelen staan op dit toestel. '
                  '${lib.continueListening.length} bezig · ${lib.saved.length} bewaard · ${lib.finished.length} beluisterd.',
                  style: t.bodyMedium,
                ),
              ),
            ]),
          ),
        ),
        const _Header('Weergave'),
        RadioGroupTiles<ThemeMode>(
          value: settings.themeMode,
          onChanged: settings.setThemeMode,
          options: const {ThemeMode.light: 'Licht', ThemeMode.dark: 'Donker', ThemeMode.system: 'Zoals het systeem'},
        ),
        const _Header('Afspelen'),
        ListTile(
          leading: const Icon(Icons.speed_rounded),
          title: const Text('Standaard afspeelsnelheid'),
          trailing: DropdownButton<double>(
            value: settings.speed,
            underline: const SizedBox.shrink(),
            items: [
              for (final s in SettingsStore.speeds)
                DropdownMenuItem(value: s, child: Text('${s.toString().replaceAll('.', ',').replaceAll(RegExp(r',0$'), '')}×')),
            ],
            onChanged: (v) {
              if (v != null) settings.setSpeed(v);
            },
          ),
        ),
        const _Header('Gegevens'),
        ListTile(
          leading: const Icon(Icons.delete_outline_rounded),
          title: const Text('Lokale gegevens wissen'),
          subtitle: const Text('Voortgang en bewaarde artikelen op dit toestel'),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Alles wissen?'),
                content: const Text('Je luistervoortgang en bewaarde artikelen worden van dit toestel verwijderd. Dit kun je niet ongedaan maken.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Wissen')),
                ],
              ),
            );
            if (ok == true) {
              await lib.clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lokale gegevens gewist.')));
              }
            }
          },
        ),
        const _Header('Over'),
        const ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text('Het Rechte Pad'),
          subtitle: Text('Artikelen van ${AppConfig.websiteUrl}. Teksten worden letterlijk overgenomen van de website.'),
        ),
        const ListTile(
          leading: Icon(Icons.cloud_outlined),
          title: Text('Server'),
          subtitle: Text(AppConfig.apiBaseUrl),
        ),
        const ListTile(leading: Icon(Icons.tag_rounded), title: Text('Versie'), subtitle: Text('0.1.0')),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.xl, Space.l, Space.xs),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: HrpColors.red, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
      );
}

/// Eenvoudige keuzelijst (zonder afhankelijkheid van nieuwere RadioGroup-API's).
class RadioGroupTiles<T> extends StatelessWidget {
  const RadioGroupTiles({super.key, required this.value, required this.onChanged, required this.options});

  final T value;
  final ValueChanged<T> onChanged;
  final Map<T, String> options;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final e in options.entries)
        ListTile(
          title: Text(e.value),
          trailing: e.key == value ? const Icon(Icons.check_rounded, color: HrpColors.red) : null,
          selected: e.key == value,
          onTap: () => onChanged(e.key),
        ),
    ]);
  }
}
