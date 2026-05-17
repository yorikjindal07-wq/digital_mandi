// ─────────────────────────────────────────────
// main.dart  +  app.dart
// App entry point. Initialises all services
// before the first frame renders.
// ─────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme.dart';
import 'core/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/chatbot_service.dart';
import 'services/sync_service.dart';
import 'services/voice_services.dart';
import 'data/local_db.dart' as local_db;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for farming-first UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init local storage
  await Hive.initFlutter();
  // Init SQLite database
  await local_db.LocalDatabase.instance.db;

  if (!AppConstants.hasBackendBaseUrl && !AppConstants.hasOpenWeatherApiKey) {
    debugPrint(
      'Weather API key not configured. Live weather will use cached/offline data.',
    );
  }

  if (!AppConstants.hasBackendBaseUrl) {
    debugPrint(
      'Backend URL not configured. Report sync will stay in offline mode.',
    );
  }

  runApp(const DigitalMandiApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_warmUpOptionalServices());
  });
}

Future<void> _warmUpOptionalServices() async {
  try {
    await ChatbotService.instance.initialize();
  } catch (e) {
    debugPrint('⚠️  Chatbot warm-up failed: $e');
  }

  try {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await TTSService.instance.initialize();
  } catch (e) {
    debugPrint('⚠️  TTS warm-up failed: $e');
  }

  try {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  } catch (e) {
    debugPrint('⚠️  ML models not loaded (placeholder files?): $e');
  }

  try {
    await AuthService.instance.initialize();
  } catch (e) {
    debugPrint('⚠️  Auth warm-up failed: $e');
  }

  SyncService.instance.startListening();
}

class DigitalMandiApp extends StatelessWidget {
  const DigitalMandiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: provider.l10n['app_name'],
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: provider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
