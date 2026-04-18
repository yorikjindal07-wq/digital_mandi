// ─────────────────────────────────────────────
// core/localization.dart
// All user-facing strings in every supported
// language. Add new languages by extending
// the _strings map.
// ─────────────────────────────────────────────

class AppLocalizations {
  AppLocalizations(this.locale);

  final String locale;

  // ── Static factory ───────────────────────────
  static AppLocalizations of(String locale) =>
      AppLocalizations(_normalise(locale));

  static String _normalise(String locale) =>
      locale.split('_').first.toLowerCase();

  // ── All strings keyed by [lang][key] ─────────
  static const Map<String, Map<String, String>> _strings = {
    // ── English ──────────────────────────────
    'en': {
      'app_name': 'Digital Mandi',
      'home_title': 'Smart Farming Assistant',
      'detect_disease': 'Detect Disease',
      'crop_recommend': 'Crop Advisor',
      'weather': 'Weather',
      'chat_assistant': 'Ask Assistant',
      'history': 'My Reports',
      'settings': 'Settings',
      'capture_image': 'Take Photo',
      'select_gallery': 'Choose from Gallery',
      'no_image_selected': 'No image selected yet',
      'analyzing': 'Analyzing image...',
      'disease_detected': 'Disease Detected',
      'confidence': 'Confidence',
      'treatment': 'Recommended Treatment',
      'view_details': 'View Full Details',
      'healthy_plant': 'Your plant is healthy!',
      'low_confidence': 'Unclear image. Please retake in good light.',
      'chat_placeholder': 'Ask anything about farming...',
      'send': 'Send',
      'speak': 'Speak',
      'language': 'Language',
      'soil_type': 'Soil Type',
      'temperature': 'Temperature (°C)',
      'humidity': 'Humidity (%)',
      'rainfall': 'Rainfall (mm)',
      'ph_level': 'Soil pH',
      'nitrogen': 'Nitrogen (N)',
      'phosphorus': 'Phosphorus (P)',
      'potassium': 'Potassium (K)',
      'get_recommendation': 'Get Recommendation',
      'best_crops': 'Best Crops for Your Field',
      'no_internet': 'Offline mode — data saved locally',
      'syncing': 'Syncing with server...',
      'sync_done': 'Sync complete',
      'report_saved': 'Report saved locally',
      'loading_model': 'Loading AI model...',
    },

    // ── Hindi ─────────────────────────────────
    'hi': {
      'app_name': 'डिजिटल मंडी',
      'home_title': 'स्मार्ट कृषि सहायक',
      'detect_disease': 'रोग पहचानें',
      'crop_recommend': 'फसल सलाहकार',
      'weather': 'मौसम',
      'chat_assistant': 'सहायक से पूछें',
      'history': 'मेरी रिपोर्ट',
      'settings': 'सेटिंग्स',
      'capture_image': 'फोटो लें',
      'select_gallery': 'गैलरी से चुनें',
      'no_image_selected': 'कोई छवि नहीं चुनी',
      'analyzing': 'छवि विश्लेषण हो रहा है...',
      'disease_detected': 'रोग पहचाना गया',
      'confidence': 'विश्वास स्तर',
      'treatment': 'अनुशंसित उपचार',
      'view_details': 'पूरी जानकारी देखें',
      'healthy_plant': 'आपका पौधा स्वस्थ है!',
      'low_confidence': 'अस्पष्ट छवि। अच्छी रोशनी में दोबारा लें।',
      'chat_placeholder': 'खेती के बारे में कुछ भी पूछें...',
      'send': 'भेजें',
      'speak': 'बोलें',
      'language': 'भाषा',
      'soil_type': 'मिट्टी का प्रकार',
      'temperature': 'तापमान (°C)',
      'humidity': 'आर्द्रता (%)',
      'rainfall': 'वर्षा (mm)',
      'ph_level': 'मिट्टी pH',
      'nitrogen': 'नाइट्रोजन (N)',
      'phosphorus': 'फास्फोरस (P)',
      'potassium': 'पोटेशियम (K)',
      'get_recommendation': 'सिफारिश लें',
      'best_crops': 'आपके खेत के लिए सर्वोत्तम फसलें',
      'no_internet': 'ऑफलाइन मोड — डेटा स्थानीय रूप से सहेजा गया',
      'syncing': 'सर्वर के साथ सिंक हो रहा है...',
      'sync_done': 'सिंक पूर्ण',
      'report_saved': 'रिपोर्ट स्थानीय रूप से सहेजी गई',
      'loading_model': 'AI मॉडल लोड हो रहा है...',
    },

    // ── Punjabi ───────────────────────────────
    'pa': {
      'app_name': 'ਡਿਜੀਟਲ ਮੰਡੀ',
      'home_title': 'ਸਮਾਰਟ ਖੇਤੀਬਾੜੀ ਸਹਾਇਕ',
      'detect_disease': 'ਰੋਗ ਪਛਾਣੋ',
      'crop_recommend': 'ਫਸਲ ਸਲਾਹਕਾਰ',
      'weather': 'ਮੌਸਮ',
      'chat_assistant': 'ਸਹਾਇਕ ਤੋਂ ਪੁੱਛੋ',
      'history': 'ਮੇਰੀਆਂ ਰਿਪੋਰਟਾਂ',
      'settings': 'ਸੈਟਿੰਗਾਂ',
      'capture_image': 'ਫੋਟੋ ਲਓ',
      'select_gallery': 'ਗੈਲਰੀ ਤੋਂ ਚੁਣੋ',
      'no_image_selected': 'ਕੋਈ ਤਸਵੀਰ ਨਹੀਂ ਚੁਣੀ',
      'analyzing': 'ਤਸਵੀਰ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ ਹੋ ਰਿਹਾ ਹੈ...',
      'disease_detected': 'ਰੋਗ ਪਛਾਣਿਆ ਗਿਆ',
      'confidence': 'ਭਰੋਸਾ ਪੱਧਰ',
      'treatment': 'ਸਿਫਾਰਸ਼ ਕੀਤਾ ਇਲਾਜ',
      'view_details': 'ਪੂਰੀ ਜਾਣਕਾਰੀ ਦੇਖੋ',
      'healthy_plant': 'ਤੁਹਾਡਾ ਪੌਦਾ ਸਿਹਤਮੰਦ ਹੈ!',
      'low_confidence': 'ਅਸਪਸ਼ਟ ਤਸਵੀਰ। ਚੰਗੀ ਰੋਸ਼ਨੀ ਵਿੱਚ ਦੁਬਾਰਾ ਲਓ।',
      'chat_placeholder': 'ਖੇਤੀ ਬਾਰੇ ਕੁਝ ਵੀ ਪੁੱਛੋ...',
      'send': 'ਭੇਜੋ',
      'speak': 'ਬੋਲੋ',
      'language': 'ਭਾਸ਼ਾ',
      'soil_type': 'ਮਿੱਟੀ ਦੀ ਕਿਸਮ',
      'get_recommendation': 'ਸਿਫਾਰਸ਼ ਲਓ',
      'best_crops': 'ਤੁਹਾਡੇ ਖੇਤ ਲਈ ਸਰਵੋਤਮ ਫਸਲਾਂ',
      'no_internet': 'ਆਫਲਾਈਨ ਮੋਡ',
      'report_saved': 'ਰਿਪੋਰਟ ਸੁਰੱਖਿਅਤ ਕੀਤੀ ਗਈ',
      'loading_model': 'AI ਮਾਡਲ ਲੋਡ ਹੋ ਰਿਹਾ ਹੈ...',
    },
  };

  // ── Public accessor ───────────────────────────
  String translate(String key) {
    final langMap = _strings[locale] ?? _strings['en']!;
    return langMap[key] ?? _strings['en']![key] ?? key;
  }

  String operator [](String key) => translate(key);
}
