import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokale voorkeuren. Licht is de standaard zonder opgeslagen keuze (zoals op de website).
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs) {
    _themeMode = switch (_prefs.getString(_themeKey)) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    _speed = _prefs.getDouble(_speedKey) ?? 1.0;
  }

  static const _themeKey = 'settings.theme';
  static const _speedKey = 'settings.speed';
  static const speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  final SharedPreferences _prefs;
  late ThemeMode _themeMode;
  late double _speed;

  ThemeMode get themeMode => _themeMode;
  double get speed => _speed;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> setSpeed(double value) async {
    _speed = value;
    notifyListeners();
    await _prefs.setDouble(_speedKey, value);
  }
}
