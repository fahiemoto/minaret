import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'app.dart';
import 'config.dart';
import 'state/library_store.dart';
import 'state/player_controller.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Achtergrondaudio + bediening op vergrendelscherm/notificatie.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'nl.hetrechtepad.minaret.audio',
    androidNotificationChannelName: 'Afspelen',
    androidNotificationOngoing: true,
  );
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final settings = SettingsStore(prefs);
  final library = LibraryStore(prefs);

  runApp(MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: library),
      ChangeNotifierProvider(create: (_) => PlayerController(api: api, library: library, settings: settings)),
    ],
    child: const MinaretApp(),
  ));
}
