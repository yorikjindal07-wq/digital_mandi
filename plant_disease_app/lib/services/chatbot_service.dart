// chatbot_service.dart — Claude API online + rule-based offline
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../data/local_db.dart';

enum ChatMode { online, offline }

class ChatbotService {
  ChatbotService._();
  static final ChatbotService instance = ChatbotService._();
  Map<String, dynamic>? _offlineResponses;
  final List<Map<String, String>> _history = [];
  ChatMode _lastMode = ChatMode.offline;
  ChatMode get lastMode => _lastMode;

  Future<void> initialize() async {
    if (_offlineResponses != null) return;
    try {
      final raw = await rootBundle.loadString(
        AppConstants.chatbotResponsesPath,
      );
      _offlineResponses = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      _offlineResponses = {};
    }
  }

  Future<String> generateReply(
    String userMessage, {
    String languageCode = 'en',
    String? cropContext,
    String? locationContext,
  }) async {
    await initialize();
    _history.add({'role': 'user', 'content': userMessage});
    if (_history.length > 20) _history.removeRange(0, 2);

    final isOnline = await _checkConnectivity();
    String reply;
    if (isOnline) {
      reply = await _callBackendAPI(
        userMessage,
        languageCode: languageCode,
        cropContext: cropContext,
        locationContext: locationContext,
      );
      _lastMode = ChatMode.online;
    } else {
      reply = _offlineReply(userMessage, languageCode);
      _lastMode = ChatMode.offline;
    }
    _history.add({'role': 'assistant', 'content': reply});
    final db = LocalDatabase.instance;
    await db.saveMessage(
      ChatMessage(text: userMessage, role: MessageRole.user),
    );
    await db.saveMessage(ChatMessage(text: reply, role: MessageRole.assistant));
    return reply;
  }

  Future<String> _callBackendAPI(
    String message, {
    required String languageCode,
    String? cropContext,
    String? locationContext,
  }) async {
    try {
      final historyToSend = _history.take(_history.length - 1).toList();
      final payload = {
        'message': message,
        'language': languageCode,
        'history': historyToSend,
        if (cropContext != null) 'crop_context': cropContext,
        if (locationContext != null) 'location': locationContext,
      };
      final response = await http
          .post(
            Uri.parse('${AppConstants.backendBaseUrl}/api/v1/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = data['reply'] as String? ?? '';
        if (reply.isNotEmpty) return reply;
      }
    } catch (e) {
      debugPrint('Backend chat error: $e');
    }
    _lastMode = ChatMode.offline;
    return _offlineReply(message, languageCode);
  }

  String _offlineReply(String input, String lang) {
    final lower = input.toLowerCase();
    final section =
        ((_offlineResponses![lang] ?? _offlineResponses!['en'])
            as Map<String, dynamic>?) ??
        {};
    if (_m(lower, ['hello', 'hi', 'namaste', 'sat sri', 'नमस्ते', 'ਸਤ ਸ੍ਰੀ']))
      return section['greeting'] as String? ??
          'Namaste! How can I help you today?';
    if (_m(lower, ['disease', 'blight', 'mold', 'रोग', 'ਰੋਗ'])) {
      final s = _specificDisease(lower);
      return s ??
          section['disease_general'] as String? ??
          'Use the camera to detect diseases accurately.';
    }
    if (_m(lower, ['fertilizer', 'urea', 'npk', 'dap', 'खाद', 'ਖਾਦ']))
      return section['fertilizer_general'] as String? ??
          'DAP 50kg/acre at sowing + Urea as per crop stage.';
    if (_m(lower, ['crop', 'grow', 'fasal', 'फसल', 'ਫਸਲ']))
      return section['crop_general'] as String? ??
          'Use the Crop Advisor for personalised recommendations.';
    if (_m(lower, ['weather', 'rain', 'मौसम', 'ਮੌਸਮ']))
      return section['weather_general'] as String? ??
          'Check the Weather section for seasonal patterns.';
    if (_m(lower, ['water', 'irrigation', 'पानी', 'ਪਾਣੀ']))
      return section['irrigation_general'] as String? ??
          'Irrigate at critical growth stages for best yield.';
    if (_m(lower, ['pest', 'insect', 'spray', 'कीट', 'ਕੀਟ']))
      return section['pesticide_general'] as String? ??
          'Use IPM — biological control first, then chemical.';
    if (_m(lower, ['soil', 'ph', 'mitti', 'मिट्टी', 'ਮਿੱਟੀ']))
      return section['soil_general'] as String? ??
          'Ideal soil pH 6.5-7.5 for most crops.';
    if (_m(lower, ['price', 'mandi', 'bhav', 'भाव', 'ਭਾਅ']))
      return lang == 'hi'
          ? 'मंडी भाव के लिए e-NAM (enam.gov.in) या AgMarkNet ऐप देखें।'
          : 'Check e-NAM portal (enam.gov.in) or AgMarkNet app for live mandi prices.';
    if (_m(lower, ['scheme', 'pmkisan', 'bima', 'yojana', 'योजना']))
      return lang == 'hi'
          ? 'मुख्य योजनाएं: PM-KISAN (₹6,000/साल), फसल बीमा (pmfby.gov.in), मृदा स्वास्थ्य कार्ड।'
          : 'Key schemes: PM-KISAN (₹6,000/year), Fasal Bima Yojana (crop insurance), Soil Health Card.';
    return _offlineFallback(lang);
  }

  String? _specificDisease(String input) {
    final diseases =
        (_offlineResponses!['diseases'] as Map<String, dynamic>?) ?? {};
    for (final e in diseases.entries) {
      if (input.contains(e.key.replaceAll('_', ' ')) || input.contains(e.key)) {
        final info = e.value as Map<String, dynamic>?;
        return info != null ? '${info['name']}: ${info['treatment']}' : null;
      }
    }
    return null;
  }

  bool _m(String input, List<String> keys) =>
      keys.any((k) => input.contains(k.toLowerCase()));

  String _offlineFallback(String lang) {
    if (lang == 'hi')
      return 'मैं ऑफलाइन मोड में हूं। इंटरनेट कनेक्ट करें पूर्ण उत्तर के लिए। सामान्य प्रश्नों के बारे में पूछें।';
    if (lang == 'pa') return 'ਮੈਂ ਆਫਲਾਈਨ ਹਾਂ। ਇੰਟਰਨੈੱਟ ਕਨੈਕਟ ਕਰੋ ਪੂਰੀ ਮਦਦ ਲਈ।';
    return 'I am offline. Connect to internet for full AI assistance. I can still answer common questions about diseases, fertilizers, irrigation, and crops.';
  }

  Future<bool> _checkConnectivity() async {
    final r = await Connectivity().checkConnectivity();
    return r.any(
      (x) =>
          x == ConnectivityResult.mobile ||
          x == ConnectivityResult.wifi ||
          x == ConnectivityResult.ethernet,
    );
  }

  Future<String> quickAsk({
    required String question,
    String? disease,
    String? crop,
    String languageCode = 'en',
  }) async {
    final isOnline = await _checkConnectivity();
    if (!isOnline)
      return _specificDisease(disease ?? '') ?? _offlineFallback(languageCode);
    try {
      final payload = {
        'question': question,
        'language': languageCode,
        if (disease != null) 'disease': disease,
        if (crop != null) 'crop': crop,
      };
      final res = await http
          .post(
            Uri.parse('${AppConstants.backendBaseUrl}/api/v1/quick-ask'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200)
        return (jsonDecode(res.body) as Map<String, dynamic>)['reply']
                as String? ??
            _offlineFallback(languageCode);
    } catch (e) {
      debugPrint('quickAsk error: $e');
    }
    return _offlineFallback(languageCode);
  }

  void clearHistory() => _history.clear();
}
