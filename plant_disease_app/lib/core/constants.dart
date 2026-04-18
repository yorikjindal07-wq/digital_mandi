// ─────────────────────────────────────────────
// core/constants.dart
// All app-wide constants. Never hard-code these
// values elsewhere in the codebase.
// ─────────────────────────────────────────────

class AppConstants {
  AppConstants._();

  // ── Model paths (relative to assets/) ──────
  static const String diseaseModelPath = 'assets/model/vision_model.tflite';
  static const String cropModelPath = 'assets/model/crop_model.tflite';

  // ── Data paths ──────────────────────────────
  static const String treatmentsPath = 'assets/data/treatments.json';
  static const String cropsPath = 'assets/data/crops.json';
  static const String weatherHistoryPath = 'assets/data/weather_history.json';
  static const String chatbotResponsesPath =
      'assets/data/chatbot_responses.json';

  // ── Disease labels (must match training order) ──
  static const List<String> diseaseLabels = [
    'early_blight',
    'healthy',
    'late_blight',
    'leaf_mold',
  ];

  // ── Crop recommendation feature order ───────
  static const List<String> cropFeatures = [
    'N',
    'P',
    'K',
    'temperature',
    'humidity',
    'ph',
    'rainfall',
  ];

  // ── Confidence threshold ─────────────────────
  static const double confidenceThreshold = 0.60;

  // ── Backend URL (used only when online) ──────
  static const String backendBaseUrl = 'http://192.168.1.100:8000';

  // ── Hive box names ───────────────────────────
  static const String reportsBoxName = 'reports';
  static const String settingsBoxName = 'settings';
  static const String chatHistoryBoxName = 'chat_history';

  // ── Supported language codes ─────────────────
  static const List<String> supportedLanguages = [
    'en', // English
    'hi', // Hindi
    'pa', // Punjabi
    'mr', // Marathi
    'te', // Telugu
  ];

  // ── Image input dimensions ───────────────────
  static const int modelInputWidth = 224;
  static const int modelInputHeight = 224;
  static const int modelInputChannels = 3;
}
