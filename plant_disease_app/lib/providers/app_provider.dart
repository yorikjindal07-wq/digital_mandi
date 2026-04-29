import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../data/local_db.dart';

class AppL10n {
  const AppL10n(this._values);

  final Map<String, String> _values;

  String operator [](String key) => _values[key] ?? key;
}

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _languageCode = AppConstants.defaultLanguage;
  AppL10n _currentL10n = _getDefaultL10n(AppConstants.defaultLanguage);

  bool _isLoading = false;
  String? _errorMessage;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _autoSync = true;
  bool _isFirstLaunch = true;

  AppProvider() {
    _initializeAsync();
  }

  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;
  AppL10n get l10n => _currentL10n;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get autoSync => _autoSync;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isFirstLaunch => _isFirstLaunch;

  Future<void> _initializeAsync() async {
    try {
      final db = LocalDatabase.instance;

      final savedLang = await db.getSetting(
        'language',
        defaultValue: AppConstants.defaultLanguage,
      );
      if (savedLang != null &&
          AppConstants.supportedLanguages.contains(savedLang)) {
        _languageCode = savedLang;
        _currentL10n = _getDefaultL10n(savedLang);
      }

      final savedTheme =
          await db.getSetting('theme_mode') ?? await db.getSetting('theme');
      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'system') {
        _themeMode = ThemeMode.system;
      }

      _soundEnabled = (await db.getSetting('sound_enabled')) != 'false';
      _vibrationEnabled = (await db.getSetting('vibration_enabled')) != 'false';
      _autoSync = (await db.getSetting('auto_sync')) != 'false';

      final firstLaunch = await db.getSetting('first_launch');
      _isFirstLaunch = firstLaunch == null || firstLaunch == 'true';

      notifyListeners();
    } catch (_) {
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    try {
      await LocalDatabase.instance.saveSetting('theme_mode', mode.name);
      await LocalDatabase.instance.saveSetting('theme', mode.name);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (!AppConstants.supportedLanguages.contains(languageCode)) return;
    _languageCode = languageCode;
    _currentL10n = _getDefaultL10n(languageCode);
    try {
      await LocalDatabase.instance.saveSetting('language', languageCode);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      await LocalDatabase.instance.saveSetting(
        'sound_enabled',
        enabled.toString(),
      );
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    try {
      await LocalDatabase.instance.saveSetting(
        'vibration_enabled',
        enabled.toString(),
      );
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setAutoSync(bool enabled) async {
    _autoSync = enabled;
    try {
      await LocalDatabase.instance.saveSetting('auto_sync', enabled.toString());
    } catch (_) {}
    notifyListeners();
  }

  Future<void> completeFirstLaunch() async {
    _isFirstLaunch = false;
    try {
      await LocalDatabase.instance.saveSetting('first_launch', 'false');
    } catch (_) {}
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  static AppL10n _getDefaultL10n(String langCode) {
    const translations = {
      'en': {
        'app_name': 'Digital Mandi',
        'home_title': 'Welcome Farmer',
        'home_subtitle':
            'Everything you need for crop health, weather, and farming support in one place.',
        'home_pill_scan': 'Fast disease scan',
        'home_pill_multilang': 'Multi-language support',
        'feature_detect_subtitle': 'Scan a leaf and identify disease quickly.',
        'feature_crop_subtitle': 'Find crops that fit your soil and weather.',
        'feature_chat_subtitle': 'Ask farming questions in a simple way.',
        'feature_weather_subtitle': 'See live weather and the next forecast.',
        'feature_history_subtitle': 'Review saved detections and reports.',
        'feature_settings_subtitle': 'Theme, language, and app preferences.',
        'open_action': 'Open',
        'sync_in_progress': 'Sync in progress',
        'reports_synced': 'Reports synced',
        'partially_synced': 'Partially synced',
        'sync_needs_attention': 'Sync needs attention',
        'offline_mode': 'Offline mode',
        'ready_to_help': 'Ready to help',
        'no_internet': 'Offline Mode - Limited Connectivity',
        'detect_disease': 'Detect Disease',
        'crop_recommend': 'Crop Advisor',
        'chat_assistant': 'Chat Assistant',
        'weather': 'Weather',
        'history': 'My Reports',
        'settings': 'Settings',
        'dark_mode': 'Dark Mode',
        'change_language': 'Change Language',
        'select_language': 'Select Language',
        'close': 'Close',
        'no_image_selected': 'No Image Selected',
        'select_gallery': 'Choose from Gallery',
        'capture_image': 'Take Photo',
        'analyzing': 'Analyzing Image...',
        'analyzing_short': 'Analyzing...',
        'disease_detected': 'Disease Detection Result',
        'confidence': 'Confidence',
        'treatment': 'Treatment Recommendation',
        'low_confidence':
            'Low confidence in prediction. Please try another image.',
        'nitrogen': 'Nitrogen (N)',
        'phosphorus': 'Phosphorus (P)',
        'potassium': 'Potassium (K)',
        'temperature': 'Temperature',
        'humidity': 'Humidity',
        'ph_level': 'Soil pH',
        'rainfall': 'Rainfall',
        'get_recommendation': 'Get Recommendation',
        'best_crops': 'Recommended Crops',
        'crop_intro':
            'Enter your soil and climate data below to get AI-powered crop suggestions.',
        'chat_placeholder': 'Ask about diseases, crops, fertilizers...',
        'weather_notice':
            'Seasonal guidance is preloaded, and live weather can be loaded for any Indian city when internet is available.',
        'live_weather': 'Live Weather',
        'next_3_days': 'Next 3 Days',
        'wind': 'Wind',
        'live_farming_alerts': 'Live Farming Alerts',
        'irrigation': 'Irrigation',
        'disease_risk': 'Disease Risk',
        'select_state': 'Select State',
        'suggested_city': 'Suggested City',
        'city': 'City',
        'city_hint': 'Type any Indian city name',
        'load_live_weather': 'Load Live Weather',
        'summer': 'Summer',
        'kharif': 'Kharif',
        'winter': 'Winter',
        'summer_label': 'Summer (Mar-Jun)',
        'kharif_label': 'Kharif (Jul-Oct)',
        'winter_label': 'Winter (Nov-Feb)',
        'seasonal_farming_advice': 'Seasonal Farming Advice',
        'seasonal_offline_notice':
            'Seasonal offline averages are currently preloaded for Punjab, Haryana, Maharashtra, and Uttar Pradesh only. Live weather works for any state and any city you enter.',
        'weather_load_error': 'Could not load live weather right now.',
        'farming_calendar': 'Farming Calendar',
        'language': 'Language',
        'loading': 'Loading...',
        'error': 'Error',
        'retry': 'Retry',
        'cancel': 'Cancel',
        'ok': 'OK',
        'save': 'Save',
        'delete': 'Delete',
        'back': 'Back',
      },
      'hi': {
        'app_name': 'Digital Mandi',
        'home_title': 'स्वागत है किसान',
        'home_subtitle':
            'फसल स्वास्थ्य, मौसम और खेती सहायता के लिए जो चाहिए, वह सब एक ही जगह पर।',
        'home_pill_scan': 'तेज़ रोग जांच',
        'home_pill_multilang': 'बहुभाषी सहायता',
        'feature_detect_subtitle': 'पत्ते की फोटो से रोग जल्दी पहचानें।',
        'feature_crop_subtitle': 'मिट्टी और मौसम के अनुसार फसल सुझाव पाएँ।',
        'feature_chat_subtitle': 'खेती के सवाल आसान भाषा में पूछें।',
        'feature_weather_subtitle':
            'लाइव मौसम और अगले दिनों का पूर्वानुमान देखें।',
        'feature_history_subtitle': 'सेव की गई रिपोर्ट और जांच देखें।',
        'feature_settings_subtitle': 'थीम, भाषा और ऐप सेटिंग बदलें।',
        'open_action': 'खोलें',
        'sync_in_progress': 'सिंक जारी है',
        'reports_synced': 'रिपोर्ट सिंक हो गई',
        'partially_synced': 'कुछ रिपोर्ट सिंक हुई',
        'sync_needs_attention': 'सिंक पर ध्यान दें',
        'offline_mode': 'ऑफलाइन मोड',
        'ready_to_help': 'मदद के लिए तैयार',
        'no_internet': 'ऑफलाइन मोड - सीमित कनेक्टिविटी',
        'detect_disease': 'रोग पहचान',
        'crop_recommend': 'फसल सलाह',
        'chat_assistant': 'चैट सहायक',
        'weather': 'मौसम',
        'history': 'मेरी रिपोर्ट',
        'settings': 'सेटिंग्स',
        'dark_mode': 'डार्क मोड',
        'change_language': 'भाषा बदलें',
        'select_language': 'भाषा चुनें',
        'close': 'बंद करें',
        'no_image_selected': 'कोई छवि नहीं चुनी गई',
        'select_gallery': 'गैलरी से चुनें',
        'capture_image': 'फोटो लें',
        'analyzing': 'छवि का विश्लेषण हो रहा है...',
        'analyzing_short': 'विश्लेषण हो रहा है...',
        'disease_detected': 'रोग पहचान परिणाम',
        'confidence': 'विश्वास स्तर',
        'treatment': 'उपचार की सलाह',
        'low_confidence': 'विश्वास कम है। कृपया दूसरी छवि लें।',
        'nitrogen': 'Nitrogen (N)',
        'phosphorus': 'Phosphorus (P)',
        'potassium': 'Potassium (K)',
        'temperature': 'तापमान',
        'humidity': 'नमी',
        'ph_level': 'मिट्टी pH',
        'rainfall': 'वर्षा',
        'get_recommendation': 'सिफारिश प्राप्त करें',
        'best_crops': 'अनुशंसित फसलें',
        'crop_intro':
            'अपनी मिट्टी और मौसम की जानकारी भरें और AI आधारित फसल सुझाव पाएँ।',
        'chat_placeholder': 'रोग, फसल, खाद के बारे में पूछें...',
        'weather_notice':
            'मौसमी सलाह पहले से उपलब्ध है, और इंटरनेट होने पर किसी भी भारतीय शहर का लाइव मौसम देखा जा सकता है।',
        'live_weather': 'लाइव मौसम',
        'next_3_days': 'अगले 3 दिन',
        'wind': 'हवा',
        'live_farming_alerts': 'लाइव खेती अलर्ट',
        'irrigation': 'सिंचाई',
        'disease_risk': 'रोग जोखिम',
        'select_state': 'राज्य चुनें',
        'suggested_city': 'सुझावित शहर',
        'city': 'शहर',
        'city_hint': 'किसी भी भारतीय शहर का नाम लिखें',
        'load_live_weather': 'लाइव मौसम लोड करें',
        'summer': 'गर्मी',
        'kharif': 'खरीफ',
        'winter': 'सर्दी',
        'summer_label': 'गर्मी (मार्च-जून)',
        'kharif_label': 'खरीफ (जुलाई-अक्टूबर)',
        'winter_label': 'सर्दी (नवंबर-फरवरी)',
        'seasonal_farming_advice': 'मौसमी खेती सलाह',
        'seasonal_offline_notice':
            'ऑफलाइन मौसमी औसत अभी केवल पंजाब, हरियाणा, महाराष्ट्र और उत्तर प्रदेश के लिए उपलब्ध हैं। लाइव मौसम किसी भी राज्य और शहर के लिए काम करता है।',
        'weather_load_error': 'अभी लाइव मौसम लोड नहीं हो सका।',
        'farming_calendar': 'खेती कैलेंडर',
        'language': 'भाषा',
        'loading': 'लोड हो रहा है...',
        'error': 'त्रुटि',
        'retry': 'फिर से प्रयास करें',
        'cancel': 'रद्द करें',
        'ok': 'ठीक है',
        'save': 'सेव करें',
        'delete': 'हटाएँ',
        'back': 'वापस',
      },
      'pa': {
        'app_name': 'Digital Mandi',
        'home_title': 'ਕਿਸਾਨ ਜੀ ਆਇਆਂ ਨੂੰ',
        'home_subtitle':
            'ਫਸਲ ਸਿਹਤ, ਮੌਸਮ ਅਤੇ ਖੇਤੀ ਸਹਾਇਤਾ ਲਈ ਲੋੜੀਂਦੀ ਹਰ ਚੀਜ਼ ਇੱਕ ਥਾਂ ਉੱਤੇ।',
        'home_pill_scan': 'ਤੇਜ਼ ਰੋਗ ਜਾਂਚ',
        'home_pill_multilang': 'ਕਈ ਭਾਸ਼ਾਵਾਂ ਦੀ ਸਹਾਇਤਾ',
        'feature_detect_subtitle': 'ਪੱਤੇ ਦੀ ਫੋਟੋ ਨਾਲ ਰੋਗ ਜਲਦੀ ਪਛਾਣੋ।',
        'feature_crop_subtitle': 'ਮਿੱਟੀ ਅਤੇ ਮੌਸਮ ਅਨੁਸਾਰ ਫਸਲ ਸਲਾਹ ਲਵੋ।',
        'feature_chat_subtitle': 'ਖੇਤੀ ਸਬੰਧੀ ਸਵਾਲ ਆਸਾਨ ਤਰੀਕੇ ਨਾਲ ਪੁੱਛੋ।',
        'feature_weather_subtitle': 'ਲਾਈਵ ਮੌਸਮ ਅਤੇ ਅਗਲੇ ਦਿਨਾਂ ਦੀ ਜਾਣਕਾਰੀ ਵੇਖੋ।',
        'feature_history_subtitle': 'ਸੇਵ ਕੀਤੀਆਂ ਰਿਪੋਰਟਾਂ ਅਤੇ ਜਾਂਚ ਵੇਖੋ।',
        'feature_settings_subtitle': 'ਥੀਮ, ਭਾਸ਼ਾ ਅਤੇ ਐਪ ਸੈਟਿੰਗ ਬਦਲੋ।',
        'open_action': 'ਖੋਲ੍ਹੋ',
        'sync_in_progress': 'ਸਿੰਕ ਚੱਲ ਰਿਹਾ ਹੈ',
        'reports_synced': 'ਰਿਪੋਰਟਾਂ ਸਿੰਕ ਹੋ ਗਈਆਂ',
        'partially_synced': 'ਕੁਝ ਰਿਪੋਰਟਾਂ ਸਿੰਕ ਹੋਈਆਂ',
        'sync_needs_attention': 'ਸਿੰਕ ਲਈ ਧਿਆਨ ਚਾਹੀਦਾ ਹੈ',
        'offline_mode': 'ਆਫਲਾਈਨ ਮੋਡ',
        'ready_to_help': 'ਮਦਦ ਲਈ ਤਿਆਰ',
        'no_internet': 'ਆਫਲਾਈਨ ਮੋਡ - ਸੀਮਤ ਕਨੈਕਟੀਵਿਟੀ',
        'detect_disease': 'ਰੋਗ ਪਛਾਣੋ',
        'crop_recommend': 'ਫਸਲ ਸਲਾਹ',
        'chat_assistant': 'ਚੈਟ ਸਹਾਇਕ',
        'weather': 'ਮੌਸਮ',
        'history': 'ਮੇਰੀਆਂ ਰਿਪੋਰਟਾਂ',
        'settings': 'ਸੈਟਿੰਗਾਂ',
        'dark_mode': 'ਡਾਰਕ ਮੋਡ',
        'change_language': 'ਭਾਸ਼ਾ ਬਦਲੋ',
        'select_language': 'ਭਾਸ਼ਾ ਚੁਣੋ',
        'close': 'ਬੰਦ ਕਰੋ',
        'no_image_selected': 'ਕੋਈ ਤਸਵੀਰ ਨਹੀਂ ਚੁਣੀ ਗਈ',
        'select_gallery': 'ਗੈਲਰੀ ਤੋਂ ਚੁਣੋ',
        'capture_image': 'ਫੋਟੋ ਲਵੋ',
        'analyzing': 'ਤਸਵੀਰ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ ਹੋ ਰਿਹਾ ਹੈ...',
        'analyzing_short': 'ਵਿਸ਼ਲੇਸ਼ਣ ਹੋ ਰਿਹਾ ਹੈ...',
        'disease_detected': 'ਰੋਗ ਪਛਾਣ ਨਤੀਜਾ',
        'confidence': 'ਭਰੋਸਾ ਪੱਧਰ',
        'treatment': 'ਇਲਾਜ ਦੀ ਸਲਾਹ',
        'low_confidence': 'ਭਰੋਸਾ ਘੱਟ ਹੈ। ਹੋਰ ਤਸਵੀਰ ਲਵੋ।',
        'nitrogen': 'Nitrogen (N)',
        'phosphorus': 'Phosphorus (P)',
        'potassium': 'Potassium (K)',
        'temperature': 'ਤਾਪਮਾਨ',
        'humidity': 'ਨਮੀ',
        'ph_level': 'ਮਿੱਟੀ pH',
        'rainfall': 'ਬਰਸਾਤ',
        'get_recommendation': 'ਸਿਫਾਰਸ਼ ਲਵੋ',
        'best_crops': 'ਸਿਫਾਰਸ਼ ਕੀਤੀਆਂ ਫਸਲਾਂ',
        'crop_intro':
            'ਆਪਣੀ ਮਿੱਟੀ ਅਤੇ ਮੌਸਮ ਦੀ ਜਾਣਕਾਰੀ ਭਰੋ ਅਤੇ AI ਅਧਾਰਿਤ ਫਸਲ ਸਲਾਹ ਲਵੋ।',
        'chat_placeholder': 'ਰੋਗ, ਫਸਲ, ਖਾਦ ਬਾਰੇ ਪੁੱਛੋ...',
        'weather_notice':
            'ਮੌਸਮੀ ਸਲਾਹ ਪਹਿਲਾਂ ਤੋਂ ਉਪਲਬਧ ਹੈ, ਅਤੇ ਇੰਟਰਨੈੱਟ ਹੋਣ ਤੇ ਕਿਸੇ ਵੀ ਭਾਰਤੀ ਸ਼ਹਿਰ ਦਾ ਲਾਈਵ ਮੌਸਮ ਵੇਖਿਆ ਜਾ ਸਕਦਾ ਹੈ।',
        'live_weather': 'ਲਾਈਵ ਮੌਸਮ',
        'next_3_days': 'ਅਗਲੇ 3 ਦਿਨ',
        'wind': 'ਹਵਾ',
        'live_farming_alerts': 'ਲਾਈਵ ਖੇਤੀ ਅਲਰਟ',
        'irrigation': 'ਸਿੰਚਾਈ',
        'disease_risk': 'ਰੋਗ ਖਤਰਾ',
        'select_state': 'ਰਾਜ ਚੁਣੋ',
        'suggested_city': 'ਸੁਝਾਇਆ ਸ਼ਹਿਰ',
        'city': 'ਸ਼ਹਿਰ',
        'city_hint': 'ਕਿਸੇ ਵੀ ਭਾਰਤੀ ਸ਼ਹਿਰ ਦਾ ਨਾਮ ਲਿਖੋ',
        'load_live_weather': 'ਲਾਈਵ ਮੌਸਮ ਲੋਡ ਕਰੋ',
        'summer': 'ਗਰਮੀ',
        'kharif': 'ਖਰੀਫ',
        'winter': 'ਸਰਦੀ',
        'summer_label': 'ਗਰਮੀ (ਮਾਰਚ-ਜੂਨ)',
        'kharif_label': 'ਖਰੀਫ (ਜੁਲਾਈ-ਅਕਤੂਬਰ)',
        'winter_label': 'ਸਰਦੀ (ਨਵੰਬਰ-ਫਰਵਰੀ)',
        'seasonal_farming_advice': 'ਮੌਸਮੀ ਖੇਤੀ ਸਲਾਹ',
        'seasonal_offline_notice':
            'ਆਫਲਾਈਨ ਮੌਸਮੀ ਔਸਤ ਇਸ ਵੇਲੇ ਸਿਰਫ਼ ਪੰਜਾਬ, ਹਰਿਆਣਾ, ਮਹਾਰਾਸ਼ਟਰ ਅਤੇ ਉੱਤਰ ਪ੍ਰਦੇਸ਼ ਲਈ ਉਪਲਬਧ ਹਨ। ਲਾਈਵ ਮੌਸਮ ਕਿਸੇ ਵੀ ਰਾਜ ਅਤੇ ਸ਼ਹਿਰ ਲਈ ਕੰਮ ਕਰਦਾ ਹੈ।',
        'weather_load_error': 'ਇਸ ਵੇਲੇ ਲਾਈਵ ਮੌਸਮ ਲੋਡ ਨਹੀਂ ਹੋ ਸਕਿਆ।',
        'farming_calendar': 'ਖੇਤੀ ਕੈਲੰਡਰ',
        'language': 'ਭਾਸ਼ਾ',
        'loading': 'ਲੋਡ ਹੋ ਰਿਹਾ ਹੈ...',
        'error': 'ਗਲਤੀ',
        'retry': 'ਮੁੜ ਕੋਸ਼ਿਸ਼ ਕਰੋ',
        'cancel': 'ਰੱਦ ਕਰੋ',
        'ok': 'ਠੀਕ ਹੈ',
        'save': 'ਸੇਵ ਕਰੋ',
        'delete': 'ਹਟਾਓ',
        'back': 'ਵਾਪਸ',
      },
      'mr': {
        'app_name': 'डिजिटल मंडी',
        'home_title': 'स्वागत शेतकरी',
        'home_subtitle':
            'पीक आरोग्य, हवामान आणि शेती सहाय्यासाठी लागणारी सर्व माहिती एका ठिकाणी.',
        'home_pill_scan': 'जलद रोग तपासणी',
        'home_pill_multilang': 'बहुभाषिक सहाय्य',
        'feature_detect_subtitle': 'पानाचा फोटो घेऊन रोग पटकन ओळखा.',
        'feature_crop_subtitle': 'माती आणि हवामानानुसार पीक सल्ला मिळवा.',
        'feature_chat_subtitle': 'शेतीचे प्रश्न सोप्या भाषेत विचारा.',
        'feature_weather_subtitle':
            'लाईव्ह हवामान आणि पुढील दिवसांचा अंदाज पाहा.',
        'feature_history_subtitle': 'जतन केलेले अहवाल आणि तपासण्या पाहा.',
        'feature_settings_subtitle': 'थीम, भाषा आणि ॲप सेटिंग बदला.',
        'open_action': 'उघडा',
        'sync_in_progress': 'सिंक सुरू आहे',
        'reports_synced': 'अहवाल सिंक झाले',
        'partially_synced': 'काही अहवाल सिंक झाले',
        'sync_needs_attention': 'सिंककडे लक्ष द्या',
        'offline_mode': 'ऑफलाइन मोड',
        'ready_to_help': 'मदतीसाठी तयार',
        'no_internet': 'ऑफलाइन मोड - मर्यादित कनेक्टिव्हिटी',
        'detect_disease': 'रोग ओळखा',
        'crop_recommend': 'पीक सल्ला',
        'chat_assistant': 'चॅट सहाय्यक',
        'weather': 'हवामान',
        'history': 'माझे अहवाल',
        'settings': 'सेटिंग्स',
        'dark_mode': 'डार्क मोड',
        'change_language': 'भाषा बदला',
        'select_language': 'भाषा निवडा',
        'close': 'बंद करा',
        'no_image_selected': 'कोणतीही प्रतिमा निवडलेली नाही',
        'select_gallery': 'गॅलरीतून निवडा',
        'capture_image': 'फोटो घ्या',
        'analyzing': 'प्रतिमेचे विश्लेषण सुरू आहे...',
        'analyzing_short': 'विश्लेषण सुरू आहे...',
        'disease_detected': 'रोग ओळख परिणाम',
        'confidence': 'विश्वास पातळी',
        'treatment': 'उपचार सल्ला',
        'low_confidence': 'विश्वास कमी आहे. कृपया दुसरी प्रतिमा वापरा.',
        'nitrogen': 'नायट्रोजन (N)',
        'phosphorus': 'फॉस्फरस (P)',
        'potassium': 'पोटॅशियम (K)',
        'temperature': 'तापमान',
        'humidity': 'आर्द्रता',
        'ph_level': 'माती pH',
        'rainfall': 'पाऊस',
        'get_recommendation': 'शिफारस मिळवा',
        'best_crops': 'शिफारस केलेली पिके',
        'crop_intro':
            'तुमची माती आणि हवामानाची माहिती भरा आणि AI आधारित पीक सूचना मिळवा.',
        'chat_placeholder': 'रोग, पीक, खत याबद्दल विचारा...',
        'weather_notice':
            'हंगामी मार्गदर्शन आधीपासून उपलब्ध आहे, आणि इंटरनेट असेल तर कोणत्याही भारतीय शहराचे लाईव्ह हवामान पाहता येते.',
        'live_weather': 'लाईव्ह हवामान',
        'next_3_days': 'पुढील 3 दिवस',
        'wind': 'वारा',
        'live_farming_alerts': 'लाईव्ह शेती सूचना',
        'irrigation': 'सिंचन',
        'disease_risk': 'रोग धोका',
        'select_state': 'राज्य निवडा',
        'suggested_city': 'सूचवलेले शहर',
        'city': 'शहर',
        'city_hint': 'कोणत्याही भारतीय शहराचे नाव टाइप करा',
        'load_live_weather': 'लाईव्ह हवामान लोड करा',
        'summer': 'उन्हाळा',
        'kharif': 'खरीप',
        'winter': 'हिवाळा',
        'summer_label': 'उन्हाळा (मार्च-जून)',
        'kharif_label': 'खरीप (जुलै-ऑक्टोबर)',
        'winter_label': 'हिवाळा (नोव्हेंबर-फेब्रुवारी)',
        'seasonal_farming_advice': 'हंगामी शेती सल्ला',
        'seasonal_offline_notice':
            'ऑफलाइन हंगामी सरासरी सध्या फक्त पंजाब, हरियाणा, महाराष्ट्र आणि उत्तर प्रदेशसाठी उपलब्ध आहेत. लाईव्ह हवामान कोणत्याही राज्य आणि शहरासाठी चालते.',
        'weather_load_error': 'सध्या लाईव्ह हवामान लोड करता आले नाही.',
        'farming_calendar': 'शेती दिनदर्शिका',
        'language': 'भाषा',
        'loading': 'लोड होत आहे...',
        'error': 'त्रुटी',
        'retry': 'पुन्हा प्रयत्न करा',
        'cancel': 'रद्द करा',
        'ok': 'ठीक आहे',
        'save': 'जतन करा',
        'delete': 'हटवा',
        'back': 'मागे',
      },
      'te': {
        'app_name': 'డిజిటల్ మండి',
        'home_title': 'స్వాగతం రైతు',
        'home_subtitle':
            'పంట ఆరోగ్యం, వాతావరణం మరియు వ్యవసాయ సహాయం కోసం కావాల్సినది అంతా ఒకే చోట.',
        'home_pill_scan': 'వేగవంతమైన రోగ నిర్ధారణ',
        'home_pill_multilang': 'బహుభాషా సహాయం',
        'feature_detect_subtitle':
            'ఆకుపై ఫోటో తీసి రోగాన్ని త్వరగా గుర్తించండి.',
        'feature_crop_subtitle':
            'మట్టి మరియు వాతావరణానికి సరిపోయే పంట సలహా పొందండి.',
        'feature_chat_subtitle': 'వ్యవసాయ ప్రశ్నలను సులభంగా అడగండి.',
        'feature_weather_subtitle':
            'ప్రస్తుత వాతావరణం మరియు రాబోయే రోజుల అంచనాను చూడండి.',
        'feature_history_subtitle':
            'సేవ్ చేసిన నివేదికలు మరియు గుర్తింపులను చూడండి.',
        'feature_settings_subtitle':
            'థీమ్, భాష మరియు యాప్ సెట్టింగ్స్ మార్చండి.',
        'open_action': 'తెరవండి',
        'sync_in_progress': 'సింక్ జరుగుతోంది',
        'reports_synced': 'నివేదికలు సింక్ అయ్యాయి',
        'partially_synced': 'కొన్ని నివేదికలు సింక్ అయ్యాయి',
        'sync_needs_attention': 'సింక్ పై దృష్టి అవసరం',
        'offline_mode': 'ఆఫ్లైన్ మోడ్',
        'ready_to_help': 'సహాయం చేయడానికి సిద్ధంగా ఉంది',
        'no_internet': 'ఆఫ్లైన్ మోడ్ - పరిమిత కనెక్టివిటీ',
        'detect_disease': 'రోగాన్ని గుర్తించండి',
        'crop_recommend': 'పంట సలహాదారు',
        'chat_assistant': 'చాట్ సహాయకుడు',
        'weather': 'వాతావరణం',
        'history': 'నా నివేదికలు',
        'settings': 'సెట్టింగ్స్',
        'dark_mode': 'డార్క్ మోడ్',
        'change_language': 'భాష మార్చండి',
        'select_language': 'భాషను ఎంచుకోండి',
        'close': 'మూసివేయండి',
        'no_image_selected': 'ఏ చిత్రం ఎంచుకోలేదు',
        'select_gallery': 'గ్యాలరీ నుంచి ఎంచుకోండి',
        'capture_image': 'ఫోటో తీయండి',
        'analyzing': 'చిత్రాన్ని విశ్లేషిస్తోంది...',
        'analyzing_short': 'విశ్లేషిస్తోంది...',
        'disease_detected': 'రోగ గుర్తింపు ఫలితం',
        'confidence': 'నమ్మక స్థాయి',
        'treatment': 'చికిత్స సూచన',
        'low_confidence':
            'నమ్మకం తక్కువగా ఉంది. దయచేసి మరో చిత్రం ఉపయోగించండి.',
        'nitrogen': 'నైట్రోజన్ (N)',
        'phosphorus': 'ఫాస్పరస్ (P)',
        'potassium': 'పొటాషియం (K)',
        'temperature': 'ఉష్ణోగ్రత',
        'humidity': 'తేమ',
        'ph_level': 'మట్టి pH',
        'rainfall': 'వర్షపాతం',
        'get_recommendation': 'సిఫారసు పొందండి',
        'best_crops': 'సిఫారసు చేసిన పంటలు',
        'crop_intro':
            'మీ మట్టి మరియు వాతావరణ వివరాలు ఇవ్వండి, AI ఆధారిత పంట సలహాలు పొందండి.',
        'chat_placeholder': 'రోగాలు, పంటలు, ఎరువుల గురించి అడగండి...',
        'weather_notice':
            'సీజనల్ మార్గదర్శకం ముందే అందుబాటులో ఉంది, మరియు ఇంటర్నెట్ ఉంటే ఏ భారతీయ నగరానికైనా ప్రస్తుత వాతావరణం చూడవచ్చు.',
        'live_weather': 'ప్రస్తుత వాతావరణం',
        'next_3_days': 'తదుపరి 3 రోజులు',
        'wind': 'గాలి',
        'live_farming_alerts': 'ప్రస్తుత వ్యవసాయ హెచ్చరికలు',
        'irrigation': 'పారుదల',
        'disease_risk': 'రోగ ప్రమాదం',
        'select_state': 'రాష్ట్రాన్ని ఎంచుకోండి',
        'suggested_city': 'సూచించిన నగరం',
        'city': 'నగరం',
        'city_hint': 'ఏ భారతీయ నగరానైనా టైప్ చేయండి',
        'load_live_weather': 'ప్రస్తుత వాతావరణం లోడ్ చేయండి',
        'summer': 'వేసవి',
        'kharif': 'ఖరీఫ్',
        'winter': 'శీతాకాలం',
        'summer_label': 'వేసవి (మార్చి-జూన్)',
        'kharif_label': 'ఖరీఫ్ (జూలై-అక్టోబర్)',
        'winter_label': 'శీతాకాలం (నవంబర్-ఫిబ్రవరి)',
        'seasonal_farming_advice': 'సీజనల్ వ్యవసాయ సలహా',
        'seasonal_offline_notice':
            'ఆఫ్లైన్ సీజనల్ సగటు వివరాలు ప్రస్తుతం పంజాబ్, హర్యానా, మహారాష్ట్ర మరియు ఉత్తర ప్రదేశ్ రాష్ట్రాలకే అందుబాటులో ఉన్నాయి. ప్రస్తుత వాతావరణం ఏ రాష్ట్రం, ఏ నగరానికైనా పనిచేస్తుంది.',
        'weather_load_error': 'ప్రస్తుత వాతావరణాన్ని ఇప్పుడు లోడ్ చేయలేకపోయాం.',
        'farming_calendar': 'వ్యవసాయ క్యాలెండర్',
        'language': 'భాష',
        'loading': 'లోడ్ అవుతోంది...',
        'error': 'లోపం',
        'retry': 'మళ్లీ ప్రయత్నించండి',
        'cancel': 'రద్దు చేయండి',
        'ok': 'సరే',
        'save': 'సేవ్ చేయండి',
        'delete': 'తొలగించండి',
        'back': 'వెనక్కి',
      },
    };

    return AppL10n(
      (translations[langCode] ?? translations['en'])!.cast<String, String>(),
    );
  }
}
