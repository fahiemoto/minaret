import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/discover_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'state/settings_store.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/mini_player.dart';

class MinaretApp extends StatelessWidget {
  const MinaretApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<SettingsStore, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Het Rechte Pad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      locale: const Locale('nl'),
      supportedLocales: const [Locale('nl')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RootShell(),
    );
  }
}

/// Hoofdnavigatie: Home, Ontdek, Mijn lijst en een aparte zoekknop. De minispeler staat erboven.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (icon: Icons.grid_view_outlined, active: Icons.grid_view_rounded, label: 'Ontdek'),
    (icon: Icons.favorite_border_rounded, active: Icons.favorite_rounded, label: 'Mijn lijst'),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: [
        HomeScreen(onOpenTab: _select),
        const DiscoverScreen(),
        const LibraryScreen(),
        SearchScreen(active: _index == 3),
      ]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const MiniPlayer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.s),
            child: Row(children: [
              Expanded(
                child: Material(
                  color: c.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  elevation: 6,
                  shadowColor: Colors.black26,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(children: [
                      for (var i = 0; i < _tabs.length; i++)
                        Expanded(child: _NavItem(
                          icon: _index == i ? _tabs[i].active : _tabs[i].icon,
                          label: _tabs[i].label,
                          selected: _index == i,
                          onTap: () => _select(i),
                        )),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: Space.s),
              Material(
                color: _index == 3 ? HrpColors.red : c.surfaceContainerHigh,
                shape: const CircleBorder(),
                elevation: 6,
                shadowColor: Colors.black26,
                child: IconButton(
                  tooltip: 'Zoeken',
                  iconSize: 26,
                  padding: const EdgeInsets.all(14),
                  color: _index == 3 ? Colors.white : c.onSurface,
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => _select(3),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fg = selected ? HrpColors.red : c.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? HrpColors.red.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: fg, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
