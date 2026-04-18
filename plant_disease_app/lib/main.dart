// ─────────────────────────────────────────────
// main.dart  +  app.dart
// App entry point. Initialises all services
// before the first frame renders.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme.dart';
import 'core/constants.dart';
import 'services/ml_service.dart';
import 'services/chatbot_service.dart';
import 'services/sync_service.dart';
import 'services/voice_services.dart';
import 'data/local_db.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for farming-first UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init local storage
  await Hive.initFlutter();

  // Init ML models — non-fatal: app works in offline mode without models
  try {
    await MLService.instance.loadModels();
  } catch (e) {
    debugPrint('⚠️  ML models not loaded (placeholder files?): $e');
    // App continues — camera screen will show a message if model is missing
  }

  // Init chatbot knowledge base
  await ChatbotService.instance.initialize();

  // Init voice services
  await TTSService.instance.initialize();

  // Start background sync listener
  SyncService.instance.startListening();

  runApp(const DigitalMandiApp());
}

class DigitalMandiApp extends StatelessWidget {
  const DigitalMandiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'Digital Mandi',
            debugShowCheckedModeBanner: false,
            theme:      AppTheme.light,
            darkTheme:  AppTheme.dark,
            themeMode:  provider.themeMode,
            home:       const HomeScreen(),
          );
        },
      ),
    );
  }
}