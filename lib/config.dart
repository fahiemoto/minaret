/// Centrale configuratie. Overschrijf bij het starten, bijvoorbeeld:
///   flutter run --dart-define=API_BASE_URL=http://localhost:8888/hetrechtepad/api/v1
/// (Android-emulator: gebruik 10.0.2.2 in plaats van localhost.)
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.hetrechtepad.nl/api/v1',
  );

  static const appName = 'Het Rechte Pad';
  static const websiteUrl = 'https://www.hetrechtepad.nl';
}
