import 'package:flutter/material.dart';

/// Ontwerptokens voor de app. Primaire kleur is het roze-rood van het Minaret-logo (#f43160).
class HrpColors {
  static const red = Color(0xFFF43160);
  static const redDeep = Color(0xFFE11D46); // stip in het logo

  /// Dezelfde kleur voor CSS in de artikel-HTML.
  static const redCss = '#f43160';
  static const ink = Color(0xFF151517);
  static const paper = Color(0xFFFAF8F5);

  static const darkBg = Color(0xFF111113);
  static const darkSurface = Color(0xFF1C1C1F);
  static const darkSurfaceHigh = Color(0xFF26262A);

  /// Warme, rustige palette voor gegenereerde covers en onderwerptegels (geen merk-assets).
  static const palette = <Color>[
    Color(0xFFF43160), // Minaret-rood
    Color(0xFF1F3A5F), // inktblauw
    Color(0xFF2F6B4F), // olijfgroen
    Color(0xFFC98A1B), // saffraan
    Color(0xFF6B2E5F), // pruim
    Color(0xFF1E6F7A), // petrol
    Color(0xFF8C4A2F), // terracotta
    Color(0xFF3D3A8C), // indigo
  ];

  /// Stabiele kleur per sleutel (bijv. categorie-slug of artikel-id).
  static Color forKey(String key) {
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }
}

class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class Radii {
  static const s = 8.0;
  static const m = 14.0;
  static const l = 22.0;
  static const pill = 999.0;
}
