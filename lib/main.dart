import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/local_store.dart';
import 'providers.dart';
import 'services/tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TrackingService.configure();
  // Read the saved theme before the first frame so the app doesn't flash the wrong colors.
  final themeMode = themeModeFromName(await const LocalStore().readThemeMode());
  runApp(ProviderScope(
    overrides: [initialThemeModeProvider.overrideWithValue(themeMode)],
    child: const LoveTrackingApp(),
  ));
}
