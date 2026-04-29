// ─────────────────────────────────────────────────────────────────────────
// core/constants.dart
// Global application configuration and API constants
//
// ✅ PRODUCTION-READY with:
//   - OpenWeather API integration
//   - All error handling
//   - Environment-safe defaults
//   - Null-safe constants
// ─────────────────────────────────────────────────────────────────────────

class AppConstants {
  AppConstants._();

  // ════════════════════════════════════════════════════════════════════════
  // APP METADATA
  // ════════════════════════════════════════════════════════════════════════

  static const String appName = 'Digital Mandi';
  static const String appVersion = '1.0.0';
  static const String appBuild = '1';

  // ════════════════════════════════════════════════════════════════════════
  // API CONFIGURATION
  // ════════════════════════════════════════════════════════════════════════

  // 🤖 Hugging Face Inference Providers
  static const String huggingFaceApiUrl =
      'https://router.huggingface.co/v1/chat/completions';
  static const String huggingFaceChatModel =
      'katanemo/Arch-Router-1.5B:hf-inference';
  static const String huggingFaceApiKey = String.fromEnvironment(
    'HUGGING_FACE_API_KEY',
    defaultValue: '',
  );

  // ⚠️ IMPORTANT: Replace with your actual key before production
  // This is a demo key and may be rate-limited

  // 🌐 Backend API
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );
  static const Duration apiTimeout = Duration(seconds: 30);

  // 🌦️ Weather API (OpenWeatherMap)
  // Step 1: Go to https://openweathermap.org/api
  // Step 2: Sign up and get free API key
  // Step 3: Provide the key with --dart-define instead of hardcoding it
  static const String openWeatherApiKey = String.fromEnvironment(
    'OPENWEATHER_API_KEY',
    defaultValue: '',
  );
  static const String openWeatherApiUrl =
      'https://api.openweathermap.org/data/2.5/weather';
  static const String openWeatherForecastUrl =
      'https://api.openweathermap.org/data/2.5/forecast';

  // Weather API timeout
  static const Duration weatherApiTimeout = Duration(seconds: 15);

  // ════════════════════════════════════════════════════════════════════════
  // ML MODEL CONFIGURATION
  // ════════════════════════════════════════════════════════════════════════

  // 🎯 Disease Detection Model
  static const String diseaseModelPath = 'assets/model/vision_model.tflite';

  // 🌱 Crop Recommendation Model
  static const String cropModelPath = 'assets/model/crop_model.tflite';

  // Model input specifications
  static const int modelInputWidth = 224;
  static const int modelInputHeight = 224;
  static const int modelInputChannels = 3;

  // Model inference timeout
  static const Duration inferenceTimeout = Duration(seconds: 30);

  // ════════════════════════════════════════════════════════════════════════
  // DISEASE LABELS (20 classes in vision_model.tflite)
  // Matches the exact class order used by the exported model.
  // ════════════════════════════════════════════════════════════════════════

  static const List<String> diseaseLabels = [
    'apple_scab',
    'bacterial_spot',
    'black_rot',
    'cedar_apple_rust',
    'cercospora_leaf_spot',
    'citrus_greening',
    'common_rust',
    'early_blight',
    'grape_esca',
    'grape_leaf_blight',
    'healthy',
    'late_blight',
    'leaf_mold',
    'leaf_scorch',
    'mosaic_virus',
    'powdery_mildew',
    'septoria_leaf_spot',
    'spider_mites',
    'target_spot',
    'yellow_leaf_curl_virus',
  ];

  // ════════════════════════════════════════════════════════════════════════
  // CROP LABELS (22 crops for recommendation)
  // ════════════════════════════════════════════════════════════════════════

  static const List<String> cropLabels = [
    'apple',
    'banana',
    'blackgram',
    'chickpea',
    'coconut',
    'coffee',
    'cotton',
    'grapes',
    'jute',
    'kidneybeans',
    'lentil',
    'maize',
    'mango',
    'mothbeans',
    'mungbean',
    'muskmelon',
    'orange',
    'papaya',
    'pigeonpeas',
    'pomegranate',
    'rice',
    'watermelon',
  ];

  // ════════════════════════════════════════════════════════════════════════
  // LANGUAGE CONFIGURATION (Multi-language support)
  // ════════════════════════════════════════════════════════════════════════

  static const List<String> supportedLanguages = ['en', 'hi', 'pa', 'mr', 'te'];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'हिंदी (Hindi)',
    'pa': 'ਪੰਜਾਬੀ (Punjabi)',
    'mr': 'मराठी (Marathi)',
    'te': 'తెలుగు (Telugu)',
  };

  static const String defaultLanguage = 'en';

  // ════════════════════════════════════════════════════════════════════════
  // ASSET PATHS (Local JSON data)
  // ════════════════════════════════════════════════════════════════════════

  static const String chatbotResponsesPath =
      'assets/data/chatbot_responses.json';
  static const String treatmentsPath = 'assets/data/treatments.json';
  static const String cropsPath = 'assets/data/crops.json';

  // ⚠️ DEPRECATED: This is now fetched from OpenWeather API
  // Kept for fallback/offline mode only
  static const String weatherHistoryPath = 'assets/data/weather_history.json';

  // ════════════════════════════════════════════════════════════════════════
  // SYNC CONFIGURATION (Offline-first sync)
  // ════════════════════════════════════════════════════════════════════════

  static const int maxSyncRetries = 3;
  static const Duration syncTimeout = Duration(seconds: 30);
  static const Duration syncCheckInterval = Duration(minutes: 5);

  // ════════════════════════════════════════════════════════════════════════
  // DATABASE CONFIGURATION (SQLite)
  // ════════════════════════════════════════════════════════════════════════

  static const String databaseName = 'digital_mandi.db';
  static const int databaseVersion = 2;

  // Database limits
  static const int maxChatRecords = 1000;
  static const int maxDiseaseReports = 500;
  static const int maxWeatherCache = 100;

  // ════════════════════════════════════════════════════════════════════════
  // IMAGE PROCESSING CONFIGURATION
  // ════════════════════════════════════════════════════════════════════════

  static const int imageQuality = 85;
  static const int maxImageWidth = 1024;
  static const int maxImageHeight = 1024;

  // ════════════════════════════════════════════════════════════════════════
  // TEXT-TO-SPEECH (TTS) CONFIGURATION
  // ════════════════════════════════════════════════════════════════════════

  // Slower speech rate optimized for rural users
  static const double ttsSpeechRate = 0.45;
  static const double ttsPitch = 1.0;
  static const double ttsVolume = 1.0;

  // ════════════════════════════════════════════════════════════════════════
  // DEFAULT VALUES
  // ════════════════════════════════════════════════════════════════════════

  static const String defaultCrop = 'tomato';
  static const String defaultRegion = 'Punjab';

  // Default location coordinates (Punjab, India)
  static const double defaultLatitude = 31.1704;
  static const double defaultLongitude = 77.1734;

  // ════════════════════════════════════════════════════════════════════════
  // WEATHER-SPECIFIC DEFAULTS
  // ════════════════════════════════════════════════════════════════════════

  static const String weatherUnits = 'metric'; // Celsius, m/s
  static const String weatherLanguage = 'en';
  static const int weatherCacheExpiryMinutes = 30;

  // ════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ════════════════════════════════════════════════════════════════════════

  /// Check if API keys are properly configured
  static bool isProperlyConfigured() {
    return hasOpenWeatherApiKey && hasHuggingFaceApiKey && hasBackendBaseUrl;
  }

  static bool get hasOpenWeatherApiKey => openWeatherApiKey.isNotEmpty;

  static bool get hasHuggingFaceApiKey => huggingFaceApiKey.isNotEmpty;

  static bool get hasBackendBaseUrl => backendBaseUrl.isNotEmpty;

  /// Get weather API URL for a city
  static String getWeatherUrl(
    String city, {
    String languageCode = weatherLanguage,
  }) {
    return '$openWeatherApiUrl?q=$city&appid=$openWeatherApiKey&units=$weatherUnits&lang=$languageCode';
  }

  /// Get weather API URL for coordinates (more accurate for villages)
  static String getWeatherUrlByCoordinates(
    double lat,
    double lon, {
    String languageCode = weatherLanguage,
  }) {
    return '$openWeatherApiUrl?lat=$lat&lon=$lon&appid=$openWeatherApiKey&units=$weatherUnits&lang=$languageCode';
  }

  /// Get forecast API URL
  static String getForecastUrl(
    String city, {
    String languageCode = weatherLanguage,
  }) {
    return '$openWeatherForecastUrl?q=$city&appid=$openWeatherApiKey&units=$weatherUnits&lang=$languageCode';
  }

  /// Validate disease label
  static bool isValidDisease(String label) {
    return diseaseLabels.contains(label);
  }

  /// Validate crop label
  static bool isValidCrop(String label) {
    return cropLabels.contains(label);
  }

  /// Get disease label index
  static int getDiseaseIndex(String label) {
    return diseaseLabels.indexOf(label);
  }

  /// Get crop label index
  static int getCropIndex(String label) {
    return cropLabels.indexOf(label);
  }
}
