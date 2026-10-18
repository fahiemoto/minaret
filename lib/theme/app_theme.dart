import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: HrpColors.red,
      brightness: b,
      primary: HrpColors.red,
      onPrimary: Colors.white,
      surface: dark ? HrpColors.darkBg : HrpColors.paper,
      onSurface: dark ? const Color(0xFFF2F0EC) : HrpColors.ink,
    ).copyWith(
      surfaceContainerLow: dark ? HrpColors.darkSurface : Colors.white,
      surfaceContainer: dark ? HrpColors.darkSurface : const Color(0xFFF1EEE9),
      surfaceContainerHigh:
          dark ? HrpColors.darkSurfaceHigh : const Color(0xFFE9E5DF),
      onSurfaceVariant:
          dark ? const Color(0xFFB9B5AE) : const Color(0xFF5E5A54),
      outlineVariant: dark ? const Color(0xFF34343A) : const Color(0xFFDDD8D0),
    );

    final base =
        ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
    final text = base.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        // Serif voor koppen sluit aan bij het woordmerk; body blijft goed leesbaar sans-serif.
        headlineMedium: text.headlineMedium?.copyWith(
            fontFamily: 'serif', fontWeight: FontWeight.w700, height: 1.15),
        headlineSmall: text.headlineSmall?.copyWith(
            fontFamily: 'serif', fontWeight: FontWeight.w700, height: 1.2),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.onSurface,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.surface),
        showCheckmark: false,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: HrpColors.red,
        thumbColor: HrpColors.red,
        inactiveTrackColor: scheme.outlineVariant,
        trackHeight: 3,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
