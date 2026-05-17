import 'dart:convert';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../data/local_db.dart' as local_db;
import '../models/models.dart';

enum ChatMode { online, offline }

class ChatbotService {
  ChatbotService._();

  static final ChatbotService instance = ChatbotService._();
  static const Set<String> _backendOnlineLanguages = {'en', 'hi', 'pa'};
  static const Map<String, Map<String, String>> _builtInResponses = {
    'hi': {
      'weather_general':
          'मौसम सेक्शन लाइव मौसम और मौसमी खेती सलाह दोनों दिखाता है। बारिश या ज्यादा नमी के दिनों में सिंचाई घटाएँ और फफूंद रोगों पर नजर रखें।',
      'fertilizer_general':
          'सिर्फ यूरिया पर निर्भर न रहें। बुवाई या रोपाई के समय बेसल फॉस्फोरस और पोटाश दें, फिर नाइट्रोजन 2-3 किस्तों में दें।',
      'pesticide_general':
          'पहले एकीकृत कीट प्रबंधन अपनाएँ: खेत की सफाई, पीले ट्रैप, नीम-आधारित उपाय और जरूरत होने पर ही रसायन।',
      'irrigation_general':
          'सिंचाई फसल की अवस्था के हिसाब से करें। फूल, दाना भराव, फल लगने या रोपाई के बाद की अवस्था सबसे महत्वपूर्ण होती है।',
      'soil_general':
          'अधिकांश फसलों के लिए मिट्टी का pH 6.5-7.5 अच्छा रहता है, लेकिन जल निकास और जैविक पदार्थ भी बहुत जरूरी हैं।',
    },
    'pa': {
      'crop_general':
          'Crop Advisor ਫੀਚਰ ਵਰਤੋ। ਆਪਣੇ ਖੇਤ ਦੇ NPK, pH, ਤਾਪਮਾਨ, ਨਮੀ ਅਤੇ ਮੀਂਹ ਦੀ ਜਾਣਕਾਰੀ ਦੇ ਕੇ ਢੁੱਕਵੀਂ ਫਸਲ ਦੀ ਸਿਫਾਰਸ਼ ਲਵੋ।',
      'weather_general':
          'ਮੌਸਮ ਸੈਕਸ਼ਨ ਲਾਈਵ ਮੌਸਮ ਨੂੰ ਮੌਸਮੀ ਖੇਤੀ ਸਲਾਹ ਨਾਲ ਜੋੜਦਾ ਹੈ। ਮੀਂਹ ਜਾਂ ਵੱਧ ਨਮੀ ਵੇਲੇ ਸਿੰਚਾਈ ਘਟਾਓ ਅਤੇ ਫੰਗਲ ਰੋਗਾਂ ਦਾ ਧਿਆਨ ਰੱਖੋ।',
      'pesticide_general':
          'ਸਭ ਤੋਂ ਪਹਿਲਾਂ ਇੱਕੀਕ੍ਰਿਤ ਕੀਟ ਪ੍ਰਬੰਧਨ ਅਪਣਾਓ: ਖੇਤ ਸਾਫ਼ ਰੱਖੋ, ਟ੍ਰੈਪ ਵਰਤੋ, ਨੀਮ ਆਧਾਰਤ ਹੱਲ ਲਗਾਓ ਅਤੇ ਲੋੜ ਪੈਣ ਤੇ ਹੀ ਦਵਾ ਵਰਤੋ।',
      'irrigation_general':
          'ਸਿੰਚਾਈ ਹਮੇਸ਼ਾਂ ਫਸਲ ਦੀ ਵਾਧੀ ਦੇ ਪੜਾਅ ਅਨੁਸਾਰ ਕਰੋ। ਫੁੱਲ, ਦਾਣਾ ਭਰਨ ਅਤੇ ਫਲ ਲੱਗਣ ਵਾਲੇ ਪੜਾਅ ਸਭ ਤੋਂ ਮਹੱਤਵਪੂਰਨ ਹੁੰਦੇ ਹਨ।',
      'soil_general':
          'ਜ਼ਿਆਦਾਤਰ ਫਸਲਾਂ ਲਈ ਮਿੱਟੀ ਦਾ pH 6.5-7.5 ਵਧੀਆ ਮੰਨਿਆ ਜਾਂਦਾ ਹੈ, ਪਰ ਨਿਕਾਸੀ ਅਤੇ ਜੈਵਿਕ ਪਦਾਰਥ ਵੀ ਬਹੁਤ ਜ਼ਰੂਰੀ ਹਨ।',
    },
    'mr': {
      'greeting':
          'नमस्कार! मी तुमचा डिजिटल मंडी शेती सहाय्यक आहे. मी पिके, रोग, खत, पाणी, कीड नियंत्रण आणि हवामानाबद्दल मदत करू शकतो.',
      'disease_general':
          'अचूक रोग ओळखण्यासाठी कॅमेरा वापरा. बाधित पानाचा स्वच्छ क्लोज-अप फोटो चांगल्या प्रकाशात घ्या.',
      'crop_general':
          'Crop Advisor वापरा. मातीतील NPK, pH, तापमान, आर्द्रता आणि पावसाची माहिती दिल्यास योग्य पीक सुचवता येते.',
      'weather_general':
          'हवामान विभागात लाईव्ह हवामान आणि हंगामी शेती सल्ला मिळतो. जास्त पाऊस किंवा आर्द्रता असेल तर पाणी कमी द्या आणि बुरशीजन्य रोगांवर लक्ष ठेवा.',
      'fertilizer_general':
          'फक्त युरिया वापरू नका. बेसल फॉस्फरस आणि पोटॅश द्या आणि नायट्रोजन 2-3 हप्त्यांत द्या.',
      'pesticide_general':
          'सर्वप्रथम एकात्मिक कीड व्यवस्थापन वापरा: शेत स्वच्छ ठेवा, ट्रॅप्स वापरा, नीम-आधारित उपाय करा आणि गरज पडल्यावरच रसायने वापरा.',
      'irrigation_general':
          'सिंचन पीकाच्या वाढीच्या टप्प्यानुसार करा. फुलोरा, फळधारणा आणि दाणा भरण्याच्या अवस्थेत पाणी सर्वाधिक महत्त्वाचे असते.',
      'soil_general':
          'अनेक पिकांसाठी मातीचा pH 6.5-7.5 चांगला असतो, पण निचरा आणि सेंद्रिय पदार्थ देखील महत्त्वाचे असतात.',
      'unknown':
          'मी रोग, खत, सिंचन, पीक निवड, हवामानावर आधारित सल्ला आणि सरकारी योजनांबद्दल मदत करू शकतो.',
    },
    'te': {
      'greeting':
          'నమస్కారం! నేను మీ డిజిటల్ మండీ వ్యవసాయ సహాయకుడిని. పంటలు, రోగాలు, ఎరువులు, నీటిపారుదల, వాతావరణం మరియు కీటక నియంత్రణపై నేను మీకు సహాయం చేయగలను.',
      'disease_general':
          'రోగాన్ని సరిగ్గా గుర్తించడానికి కెమెరా వాడండి. బాధిత ఆకు యొక్క స్పష్టమైన ఫోటోను మంచి వెలుతురులో తీసుకోండి.',
      'crop_general':
          'Crop Advisor ఉపయోగించండి. మీ మట్టి NPK, pH, ఉష్ణోగ్రత, ఆర్ద్రత మరియు వర్షపాతం ఆధారంగా సరైన పంటను ఎంపిక చేయవచ్చు.',
      'weather_general':
          'వాతావరణ విభాగంలో లైవ్ వాతావరణం మరియు సీజనల్ వ్యవసాయ సలహా రెండూ ఉంటాయి. ఎక్కువ వర్షం లేదా తేమ ఉన్నప్పుడు నీటిపారుదల తగ్గించండి మరియు ఫంగల్ రోగాలను గమనించండి.',
      'fertilizer_general':
          'కేవలం యూరియా మీద ఆధారపడవద్దు. బేసల్ దశలో ఫాస్ఫరస్, పొటాష్ ఇవ్వండి మరియు నత్రజనిని 2-3 విడతల్లో ఇవ్వండి.',
      'pesticide_general':
          'ముందుగా సమగ్ర కీటక నియంత్రణ పాటించండి: శుభ్రత, ట్రాప్స్, నిమ్ ఆధారిత పరిష్కారాలు మరియు అవసరమైనప్పుడు మాత్రమే రసాయనాలు ఉపయోగించండి.',
      'irrigation_general':
          'నీటిపారుదల పంట దశల ప్రకారం ఉండాలి. పుష్పదశ, ఫలదశ మరియు గింజ నింపే దశల్లో నీరు చాలా ముఖ్యమైనది.',
      'soil_general':
          'చాలా పంటలకు మట్టి pH 6.5-7.5 మంచిది. కానీ డ్రైనేజ్ మరియు ఆర్గానిక్ పదార్థం కూడా అంతే ముఖ్యం.',
      'unknown':
          'నేను రోగాలు, ఎరువులు, నీటిపారుదల, పంట ఎంపిక, వాతావరణ సలహా మరియు ప్రభుత్వ పథకాల గురించి సహాయం చేయగలను.',
    },
  };

  final Connectivity _connectivity = Connectivity();
  final List<ChatMessage> _history = [];

  Map<String, dynamic>? _offlineResponses;
  ChatMode _lastMode = ChatMode.offline;
  bool _onlineDisabledForSession = false;

  ChatMode get lastMode => _lastMode;
  bool get isOnline => _lastMode == ChatMode.online;
  int get historyLength => _history.length;

  Future<void> initialize() async {
    if (_offlineResponses != null) return;

    try {
      final raw = await rootBundle.loadString(
        AppConstants.chatbotResponsesPath,
      );
      _offlineResponses = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to load offline knowledge base: $e');
      _offlineResponses = _defaultFallback();
    }
  }

  Future<String> generateReply(
    String userMessage, {
    String languageCode = 'en',
    String? cropContext,
    String? locationContext,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      await initialize();

      _history.add(
        ChatMessage(
          text: userMessage,
          role: MessageRole.user,
          // language: languageCode,
        ),
      );

      if (_history.length > 50) {
        _history.removeRange(0, 10);
      }

      final online = await _checkConnectivity();
      late final String reply;

      if (online &&
          !_onlineDisabledForSession &&
          _canUseOnlineModel(languageCode)) {
        try {
          final usingBackendChat = AppConstants.hasBackendBaseUrl;
          final onlineReply = await _callOnlineModel(
            userMessage,
            languageCode: languageCode,
            cropContext: cropContext,
            locationContext: locationContext,
            timeout: timeout,
          );
          if (_shouldUseSafeOfflineFallback(
            onlineReply,
            userMessage,
            languageCode,
            fromBackend: usingBackendChat,
            cropContext: cropContext,
            locationContext: locationContext,
          )) {
            debugPrint(
              'Online chatbot reply failed multilingual quality checks, using local fallback.',
            );
            reply = _offlineReply(
              userMessage,
              languageCode,
              cropContext: cropContext,
              locationContext: locationContext,
              hasInternetConnection: online,
            );
            _lastMode = ChatMode.offline;
          } else {
            reply = onlineReply;
            _lastMode = ChatMode.online;
          }
        } catch (e) {
          if (_shouldDisableOnlineForSession(e)) {
            _onlineDisabledForSession = true;
            debugPrint(
              'Disabling online chatbot for this session after client error: $e',
            );
          }
          debugPrint(
            'Online chatbot request failed, using offline fallback: $e',
          );
          reply = _offlineReply(
            userMessage,
            languageCode,
            cropContext: cropContext,
            locationContext: locationContext,
            hasInternetConnection: online,
          );
          _lastMode = ChatMode.offline;
        }
      } else {
        reply = _offlineReply(
          userMessage,
          languageCode,
          cropContext: cropContext,
          locationContext: locationContext,
          hasInternetConnection: online,
        );
        _lastMode = ChatMode.offline;
      }

      _history.add(
        ChatMessage(
          text: reply,
          role: MessageRole.assistant,
          // language: languageCode,
        ),
      );

      final db = local_db.LocalDatabase.instance;
      await db.saveMessage(
        ChatMessage(
          text: userMessage,
          role: MessageRole.user,
          // language: languageCode,
        ),
      );
      await db.saveMessage(
        ChatMessage(
          text: reply,
          role: MessageRole.assistant,
          // language: languageCode,
        ),
      );

      return reply;
    } catch (e) {
      debugPrint('Error in generateReply: $e');
      return _offlineFallback(languageCode);
    }
  }

  Future<String> _callOnlineModel(
    String userMessage, {
    required String languageCode,
    String? cropContext,
    String? locationContext,
    required Duration timeout,
  }) async {
    final recentHistory = _recentConversationHistory();

    if (AppConstants.hasBackendBaseUrl) {
      return _callBackendChat(
        userMessage,
        languageCode: languageCode,
        cropContext: cropContext,
        locationContext: locationContext,
        timeout: timeout,
        recentHistory: recentHistory,
      );
    }

    final systemPrompt = _buildSystemPrompt(languageCode);
    var context = '';
    if (cropContext != null && cropContext.isNotEmpty) {
      context += '\nCrop: $cropContext';
    }
    if (locationContext != null && locationContext.isNotEmpty) {
      context += '\nLocation: $locationContext';
    }

    final payload = {
      'model': AppConstants.huggingFaceChatModel,
      'messages': [
        {
          'role': 'system',
          'content':
              '${systemPrompt.trim()}${context.trim().isEmpty ? '' : '\n$context'}',
        },
        ...recentHistory.map(
          (msg) => {'role': msg.role.name, 'content': msg.text},
        ),
        {'role': 'user', 'content': userMessage},
      ],
      'max_tokens': 220,
      'temperature': 0.4,
    };

    final directAiUri = AppConstants.huggingFaceUri;
    if (directAiUri == null || !AppConstants.canUseDirectAiProvider) {
      throw NetworkException(
        message:
            'Direct AI provider access is disabled. Configure a secure backend for online chat.',
      );
    }

    final response = await http
        .post(
          directAiUri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConstants.huggingFaceApiKey}',
          },
          body: jsonEncode(payload),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw NetworkException(
        message: 'Online chatbot request failed with ${response.statusCode}',
      );
    }

    return _extractOnlineReply(jsonDecode(response.body));
  }

  List<ChatMessage> _recentConversationHistory() {
    if (_history.length <= 1) return const <ChatMessage>[];

    final start = math.max(0, _history.length - 11);
    final recentHistory = _history.sublist(start, _history.length - 1);
    return recentHistory;
  }

  Future<String> _callBackendChat(
    String userMessage, {
    required String languageCode,
    required Duration timeout,
    required List<ChatMessage> recentHistory,
    String? cropContext,
    String? locationContext,
  }) async {
    final backendChatUri = AppConstants.backendUri('/api/v1/chat');
    if (backendChatUri == null) {
      throw NetworkException(
        message:
            'Secure backend URL is not configured. Use an HTTPS backend for online chat.',
      );
    }
    final payload = {
      'message': userMessage,
      'language': languageCode,
      'history': recentHistory
          .map((msg) => {'role': msg.role.name, 'content': msg.text})
          .toList(),
      'location': locationContext,
      'crop_context': cropContext,
      'max_turns': 10,
    };

    final response = await http
        .post(
          backendChatUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw NetworkException(
        message: 'Backend chat request failed with ${response.statusCode}',
      );
    }

    final dynamic data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      final reply = data['reply'] as String?;
      if (reply != null && reply.trim().isNotEmpty) {
        return reply.trim();
      }
      final detail = data['detail'] as String?;
      if (detail != null && detail.trim().isNotEmpty) {
        throw NetworkException(message: detail.trim());
      }
    }

    throw NetworkException(message: 'Backend chat returned no usable reply');
  }

  String _extractOnlineReply(dynamic data) {
    if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
      final text =
          (data.first as Map<String, dynamic>)['generated_text'] as String?;
      if (text != null && text.trim().isNotEmpty) {
        return text.trim();
      }
    }

    if (data is Map<String, dynamic>) {
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final firstChoice = choices.first as Map<String, dynamic>?;
        final message = firstChoice?['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
      }

      final text = data['generated_text'] as String?;
      if (text != null && text.trim().isNotEmpty) {
        return text.trim();
      }

      final error = data['error'] as String?;
      if (error != null && error.isNotEmpty) {
        throw NetworkException(message: error);
      }
    }

    throw NetworkException(message: 'Online chatbot returned no usable reply');
  }

  String _offlineReply(
    String input,
    String lang, {
    String? cropContext,
    String? locationContext,
    bool hasInternetConnection = false,
  }) {
    final lower = _normalizeDomainTerms(input.toLowerCase());
    final normalized = _normalizeText(lower);

    final quickAnswer = _matchQuickAnswer(normalized);
    if (quickAnswer != null) return quickAnswer;

    final diseaseReply = _matchDisease(normalized, lang);
    if (diseaseReply.isNotEmpty) return diseaseReply;

    final cropSpecificReply = _matchCropSpecificAdvice(
      normalized,
      lang,
      cropContext: cropContext,
      locationContext: locationContext,
    );
    if (cropSpecificReply != null) return cropSpecificReply;

    final languageReply = _matchLanguageSupportRequest(normalized, lang);
    if (languageReply != null) return languageReply;

    final clarifyingReply = _buildClarifyingReply(
      normalized,
      lang,
      cropContext: cropContext,
      locationContext: locationContext,
    );
    if (clarifyingReply != null) return clarifyingReply;

    if (_matchKeywords(lower, [
      'hello',
      'hi',
      'namaste',
      'नमस्ते',
      'ਸਤ ਸ੍ਰੀ',
    ])) {
      return _getResponse(lang, 'greeting') ??
          'Namaste! How can I help you with farming today?';
    }

    if (_matchKeywords(lower, ['disease', 'blight', 'mold', 'रोग', 'ਰੋਗ'])) {
      return _getResponse(lang, 'disease_general') ??
          'Use the camera to detect plant diseases. I can help identify issues.';
    }

    if (_matchKeywords(lower, ['fertilizer', 'urea', 'npk', 'दाद', 'खाद'])) {
      return _replyByLanguage(
        lang,
        en: 'Use balanced fertilizers, not only urea. Give any exact product or dose only after confirming the crop, growth stage, and local soil condition.',
        hi: 'संतुलित खाद का उपयोग करें, केवल यूरिया पर निर्भर न रहें। कोई भी सटीक खाद या मात्रा तभी तय करें जब फसल, उसकी अवस्था और स्थानीय मिट्टी की स्थिति स्पष्ट हो।',
        pa: 'ਸੰਤੁਲਿਤ ਖਾਦ ਵਰਤੋ, ਸਿਰਫ ਯੂਰੀਆ ਤੇ ਨਿਰਭਰ ਨਾ ਰਹੋ। ਕੋਈ ਵੀ ਪੱਕੀ ਖਾਦ ਜਾਂ ਮਾਤਰਾ ਤਦ ਹੀ ਤੈਅ ਕਰੋ ਜਦੋਂ ਫਸਲ, ਉਸ ਦੀ ਅਵਸਥਾ ਅਤੇ ਸਥਾਨਕ ਮਿੱਟੀ ਦੀ ਹਾਲਤ ਸਪੱਸ਼ਟ ਹੋਵੇ।',
      );
    }

    if (_matchKeywords(lower, ['crop', 'grow', 'fasal', 'फसल', 'ਫਸਲ'])) {
      return _getResponse(lang, 'crop_general') ??
          'Use Crop Advisor for personalized recommendations based on your soil and weather.';
    }

    if (_matchKeywords(lower, ['weather', 'rain', 'मौसम', 'ਮੌਸਮ'])) {
      return _getResponse(lang, 'weather_general') ??
          'Check the Weather section for seasonal patterns and forecasts.';
    }

    if (_matchKeywords(lower, ['water', 'irrigation', 'पानी', 'ਪਾਣੀ'])) {
      return _getResponse(lang, 'irrigation_general') ??
          'Irrigate during critical growth stages and check crop-specific recommendations.';
    }

    if (_matchKeywords(lower, ['pest', 'insect', 'spray', 'कीट', 'ਕੀਟ'])) {
      return _replyByLanguage(
        lang,
        en: 'Use integrated pest management first: field sanitation, traps, and neem-based options where suitable. Pick any spray only after confirming the crop, pest, and infestation level.',
        hi: 'पहले समेकित कीट प्रबंधन अपनाइए: खेत की सफाई, ट्रैप और जरूरत हो तो नीम आधारित उपाय। कोई भी दवा या छिड़काव तभी चुनें जब फसल, कीट और प्रकोप का स्तर स्पष्ट हो।',
        pa: 'ਸਭ ਤੋਂ ਪਹਿਲਾਂ ਇਕੀਕ੍ਰਿਤ ਕੀਟ ਪ੍ਰਬੰਧਨ ਅਪਣਾਓ: ਖੇਤ ਦੀ ਸਫਾਈ, ਟ੍ਰੈਪ ਅਤੇ ਜਿੱਥੇ ਢੁੱਕਵਾਂ ਹੋਵੇ ਉੱਥੇ ਨੀਮ-ਆਧਾਰਿਤ ਉਪਾਅ। ਕੋਈ ਵੀ ਦਵਾਈ ਜਾਂ ਛਿੜਕਾਅ ਤਦ ਹੀ ਚੁਣੋ ਜਦੋਂ ਫਸਲ, ਕੀਟ ਅਤੇ ਪ੍ਰਕੋਪ ਦਾ ਪੱਧਰ ਸਪੱਸ਼ਟ ਹੋਵੇ।',
      );
    }

    if (_matchKeywords(lower, ['soil', 'ph', 'mitti', 'मिट्टी', 'ਮਿੱਟੀ'])) {
      return _getResponse(lang, 'soil_general') ??
          'Ideal soil pH is 6.5 to 7.5 for most crops. Soil testing is recommended.';
    }

    if (_matchKeywords(lower, ['price', 'mandi', 'भाव', 'ਭਾਅ'])) {
      return lang == 'hi'
          ? 'e-NAM पोर्टल (enam.gov.in) पर मंडी भाव देखें।'
          : 'Check the e-NAM portal (enam.gov.in) for live mandi prices.';
    }

    if (_matchKeywords(lower, ['scheme', 'pmkisan', 'योजना', 'ਯੋਜਨਾ'])) {
      return lang == 'hi'
          ? 'PM-KISAN, फसल बीमा, और मृदा स्वास्थ्य कार्ड जैसी योजनाएं देखें।'
          : 'Key schemes include PM-KISAN, crop insurance, and the Soil Health Card.';
    }

    return hasInternetConnection
        ? _localAssistantFallback(lang)
        : _offlineFallback(lang);
  }

  String? _buildClarifyingReply(
    String input,
    String lang, {
    String? cropContext,
    String? locationContext,
  }) {
    final crop = _detectCrop(input, cropContext);
    final wantsChemicalAdvice = _matchKeywords(input, [
      'fertilizer',
      'fertiliser',
      'urea',
      'dap',
      'npk',
      'potash',
      'spray',
      'pesticide',
      'fungicide',
      'herbicide',
      'insecticide',
      'medicine',
      'dose',
      'dosage',
      'quantity',
      'amount',
    ]);
    if (wantsChemicalAdvice && crop == null) {
      return _replyByLanguage(
        lang,
        en: 'To give safe fertilizer or spray advice, tell me 2 things: 1. Which crop is it? 2. Is the issue fertilizer need, pest, disease, or spray timing?',
        hi: 'सुरक्षित खाद या दवा की सलाह देने के लिए 2 बातें बताइए: 1. फसल कौन-सी है? 2. समस्या खाद की है, कीट की है, रोग की है या छिड़काव के समय की?',
        pa: 'ਸੁਰੱਖਿਅਤ ਖਾਦ ਜਾਂ ਦਵਾਈ ਦੀ ਸਲਾਹ ਲਈ 2 ਗੱਲਾਂ ਦੱਸੋ: 1. ਫਸਲ ਕਿਹੜੀ ਹੈ? 2. ਸਮੱਸਿਆ ਖਾਦ, ਕੀਟ, ਰੋਗ ਜਾਂ ਛਿੜਕਾਅ ਦੇ ਸਮੇਂ ਨਾਲ ਜੁੜੀ ਹੈ?',
      );
    }

    final wantsIrrigation = _matchKeywords(input, [
      'water',
      'irrigation',
      'schedule',
      'drip',
      'sprinkler',
    ]);
    if (wantsIrrigation && crop == null) {
      return _replyByLanguage(
        lang,
        en: 'For irrigation advice, tell me the crop and growth stage first. For example: wheat at crown root initiation, tomato at flowering, or rice after transplanting.',
        hi: 'सिंचाई की सही सलाह के लिए पहले फसल और उसकी अवस्था बताइए। उदाहरण: गेहूं में CRI अवस्था, टमाटर में फूल आना, या धान में रोपाई के बाद।',
        pa: 'ਸਿੰਚਾਈ ਦੀ ਸਹੀ ਸਲਾਹ ਲਈ ਪਹਿਲਾਂ ਫਸਲ ਅਤੇ ਉਸ ਦੀ ਅਵਸਥਾ ਦੱਸੋ। ਉਦਾਹਰਨ: ਕਣਕ ਦੀ CRI ਅਵਸਥਾ, ਟਮਾਟਰ ਵਿੱਚ ਫੁੱਲ ਆਉਣ ਦਾ ਸਮਾਂ, ਜਾਂ ਧਾਨ ਦੀ ਰੋਪਾਈ ਤੋਂ ਬਾਅਦ।',
      );
    }

    final wantsDiseaseHelp = _matchKeywords(input, [
      'disease',
      'blight',
      'mold',
      'spot',
      'rust',
      'virus',
      'leaf',
      'symptom',
    ]);
    if (wantsDiseaseHelp && crop == null) {
      return _replyByLanguage(
        lang,
        en: 'For safer disease advice, tell me the crop and the main symptom. If possible, use the camera feature and share the disease result shown in the app.',
        hi: 'रोग की सुरक्षित सलाह के लिए फसल का नाम और मुख्य लक्षण बताइए। अगर संभव हो, ऐप का कैमरा फीचर चलाकर जो रोग-परिणाम दिखे वह भी बताइए।',
        pa: 'ਰੋਗ ਬਾਰੇ ਸੁਰੱਖਿਅਤ ਸਲਾਹ ਲਈ ਫਸਲ ਦਾ ਨਾਮ ਅਤੇ ਮੁੱਖ ਲੱਛਣ ਦੱਸੋ। ਜੇ ਹੋ ਸਕੇ ਤਾਂ ਐਪ ਦੇ ਕੈਮਰਾ ਫੀਚਰ ਨਾਲ ਜੋ ਨਤੀਜਾ ਆਵੇ, ਉਹ ਵੀ ਦੱਸੋ।',
      );
    }

    final wantsWeather = _matchKeywords(input, [
      'weather',
      'rain',
      'temperature',
      'humidity',
      'forecast',
    ]);
    final hasLocation =
        locationContext != null && locationContext.trim().isNotEmpty;
    if (wantsWeather && !hasLocation) {
      return _replyByLanguage(
        lang,
        en: 'For weather-based advice, tell me your village, district, or nearest town so I can keep the answer relevant to your area.',
        hi: 'मौसम आधारित सलाह के लिए अपना गांव, जिला या नजदीकी कस्बा बताइए, ताकि जवाब आपके इलाके के हिसाब से दिया जा सके।',
        pa: 'ਮੌਸਮ ਅਧਾਰਿਤ ਸਲਾਹ ਲਈ ਆਪਣਾ ਪਿੰਡ, ਜ਼ਿਲ੍ਹਾ ਜਾਂ ਨੇੜਲਾ ਸ਼ਹਿਰ ਦੱਸੋ, ਤਾਂ ਜੋ ਜਵਾਬ ਤੁਹਾਡੇ ਇਲਾਕੇ ਅਨੁਸਾਰ ਹੋਵੇ।',
      );
    }

    return null;
  }

  String _normalizeText(String input) {
    return input
        .replaceAll(RegExp(r'[_\-]'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeDomainTerms(String input) {
    const replacements = {
      'नमस्ते': ' hello ',
      'नमस्कार': ' hello ',
      'ਸਤ ਸ੍ਰੀ': ' hello ',
      'ਸਤ ਸ੍ਰੀ ਅਕਾਲ': ' hello ',
      'ਨਮਸਕਾਰ': ' hello ',
      'నమస్తే': ' hello ',
      'నమస్కారం': ' hello ',
      'रोग': ' disease ',
      'बीमारी': ' disease ',
      'ਰੋਗ': ' disease ',
      'ਬਿਮਾਰੀ': ' disease ',
      'व्याधी': ' disease ',
      'వ్యాధి': ' disease ',
      'రోగం': ' disease ',
      'खाद': ' fertilizer ',
      'खत': ' fertilizer ',
      'ਖਾਦ': ' fertilizer ',
      'ఎరువు': ' fertilizer ',
      'ఎరువులు': ' fertilizer ',
      'फसल': ' crop ',
      'फसलें': ' crop ',
      'ਫਸਲ': ' crop ',
      'पीक': ' crop ',
      'పంట': ' crop ',
      'गेहूं': ' wheat ',
      'गेहूँ': ' wheat ',
      'गेंहू': ' wheat ',
      'कणक': ' wheat ',
      'ਕਣਕ': ' wheat ',
      'धान': ' rice ',
      'झोना': ' rice ',
      'ਝੋਨਾ': ' rice ',
      'ਧਾਨ': ' rice ',
      'कपास': ' cotton ',
      'ਕਪਾਹ': ' cotton ',
      'टमाटर': ' tomato ',
      'ਟਮਾਟਰ': ' tomato ',
      'मक्का': ' maize ',
      'ਮੱਕੀ': ' maize ',
      'सरसों': ' mustard ',
      'ਸਰੋਂ': ' mustard ',
      'गन्ना': ' sugarcane ',
      'ਗੰਨਾ': ' sugarcane ',
      'मौसम': ' weather ',
      'हवामान': ' weather ',
      'ਮੌਸਮ': ' weather ',
      'వాతావరణం': ' weather ',
      'पानी': ' water ',
      'सिंचाई': ' irrigation ',
      'पाणी': ' water ',
      'सिंचन': ' irrigation ',
      'ਪਾਣੀ': ' water ',
      'ਸਿੰਚਾਈ': ' irrigation ',
      'నీరు': ' water ',
      'నీటిపారుదల': ' irrigation ',
      'मिट्टी': ' soil ',
      'माती': ' soil ',
      'ਮਿੱਟੀ': ' soil ',
      'నేల': ' soil ',
      'कीट': ' pest ',
      'कीड': ' pest ',
      'ਕੀਟ': ' pest ',
      'పురుగు': ' pest ',
      'योजना': ' scheme ',
      'योजने': ' scheme ',
      'ਯੋਜਨਾ': ' scheme ',
      'పథకం': ' scheme ',
      'भाव': ' price ',
      'दर': ' price ',
      'ਭਾਅ': ' price ',
      'ధర': ' price ',
      'हिंदी': ' hindi ',
      'ਪੰਜਾਬੀ': ' punjabi ',
      'मराठी': ' marathi ',
      'తెలుగు': ' telugu ',
    };

    var normalized = input;
    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });
    return normalized;
  }

  String _matchDisease(String input, String lang) {
    final diseases =
        (_offlineResponses?['diseases'] ?? const <String, dynamic>{})
            as Map<String, dynamic>;

    for (final entry in diseases.entries) {
      if (input.contains(entry.key.replaceAll('_', ' ')) ||
          input.contains(entry.key)) {
        final info = entry.value as Map<String, dynamic>?;
        if (info != null) {
          final name = info['name'] ?? entry.key;
          final treatment =
              info['treatment'] ?? 'Contact an expert for treatment.';
          return '$name: $treatment';
        }
      }
    }

    return '';
  }

  String? _matchQuickAnswer(String input) {
    final quickAnswers =
        (_offlineResponses?['quick_answers'] ?? const <String, dynamic>{})
            as Map<String, dynamic>;
    if (quickAnswers.isEmpty || input.isEmpty) return null;

    String? bestAnswer;
    var bestScore = 0;

    for (final entry in quickAnswers.entries) {
      final key = _normalizeText(entry.key.toLowerCase());
      final answer = entry.value as String?;
      if (answer == null || answer.trim().isEmpty) continue;

      if (input.contains(key) || key.contains(input)) {
        return answer;
      }

      final score = _tokenOverlapScore(input, key);
      if (score > bestScore) {
        bestScore = score;
        bestAnswer = answer;
      }
    }

    return bestScore >= 2 ? bestAnswer : null;
  }

  int _tokenOverlapScore(String input, String pattern) {
    final inputTokens = input
        .split(' ')
        .where((token) => token.isNotEmpty && token.length > 2)
        .toSet();
    final patternTokens = pattern
        .split(' ')
        .where((token) => token.isNotEmpty && token.length > 2)
        .toSet();
    return inputTokens.intersection(patternTokens).length;
  }

  String? _matchCropSpecificAdvice(
    String input,
    String lang, {
    String? cropContext,
    String? locationContext,
  }) {
    final crop = _detectCrop(input, cropContext);
    final wantsFertilizer = _matchKeywords(input, [
      'fertilizer',
      'fertiliser',
      'urea',
      'dap',
      'npk',
      'potash',
      'compost',
    ]);
    final wantsIrrigation = _matchKeywords(input, [
      'water',
      'irrigation',
      'drip',
      'sprinkler',
      'schedule',
    ]);
    final wantsDisease = _matchKeywords(input, [
      'disease',
      'blight',
      'mold',
      'spot',
      'rust',
      'virus',
      'leaf',
    ]);
    final wantsWeather = _matchKeywords(input, [
      'weather',
      'rain',
      'temperature',
      'humidity',
      'forecast',
    ]);

    if (wantsWeather) {
      final location = locationContext?.trim();
      if (location != null && location.isNotEmpty) {
        return _replyByLanguage(
          lang,
          en: 'For $location, check the Weather screen for live conditions and seasonal guidance. If rain is above 5 mm or humidity stays above 75%, reduce irrigation and watch for fungal disease.',
          hi: '$location के लिए Weather स्क्रीन देखें। अगर बारिश 5 मिमी से ज्यादा हो या आर्द्रता 75% से ऊपर रहे, तो सिंचाई घटाइए और फफूंद रोगों पर नजर रखिए।',
          pa: '$location ਲਈ Weather ਸਕ੍ਰੀਨ ਵੇਖੋ। ਜੇ ਮੀਂਹ 5 ਮਿ.ਮੀ. ਤੋਂ ਵੱਧ ਹੋਵੇ ਜਾਂ ਨਮੀ 75% ਤੋਂ ਉੱਪਰ ਰਹੇ, ਤਾਂ ਸਿੰਚਾਈ ਘਟਾਓ ਅਤੇ ਫਫੂੰਦ ਵਾਲੇ ਰੋਗਾਂ ਉੱਤੇ ਨਜ਼ਰ ਰੱਖੋ।',
        );
      }
      if (crop != null) {
        return _replyByLanguage(
          lang,
          en: 'For $crop, use the Weather screen to compare live weather with seasonal averages. Hot dry days mean more irrigation, while high humidity and rain increase fungal disease risk.',
          hi: '$crop के लिए Weather स्क्रीन पर लाइव मौसम और मौसमी औसत की तुलना करें। गर्म और सूखे दिनों में सिंचाई की जरूरत बढ़ती है, जबकि ज्यादा नमी और बारिश से फफूंद रोग का खतरा बढ़ता है।',
          pa: '$crop ਲਈ Weather ਸਕ੍ਰੀਨ ਤੇ ਲਾਈਵ ਮੌਸਮ ਨੂੰ ਮੌਸਮੀ ਔਸਤ ਨਾਲ ਮਿਲਾਓ। ਗਰਮ ਤੇ ਸੁੱਕੇ ਦਿਨਾਂ ਵਿੱਚ ਸਿੰਚਾਈ ਵੱਧ ਲੱਗਦੀ ਹੈ, ਜਦਕਿ ਵੱਧ ਨਮੀ ਅਤੇ ਮੀਂਹ ਨਾਲ ਫਫੂੰਦ ਰੋਗ ਦਾ ਖਤਰਾ ਵੱਧਦਾ ਹੈ।',
        );
      }
    }

    if (crop == null) return null;

    switch (crop) {
      case 'wheat':
        if (wantsFertilizer) {
          return _replyByLanguage(
            lang,
            en: 'Wheat fertilizer guide: apply basal phosphorus at sowing, then split nitrogen into 2 doses. The first top dressing is most important at crown root initiation, and the second is usually before booting. Use local soil-test guidance before fixing the exact dose.',
            hi: 'गेहूं के लिए खाद सलाह: बुवाई के समय बेसल फॉस्फोरस दें और नाइट्रोजन को 2 खुराकों में बांटें। पहली टॉप ड्रेसिंग CRI अवस्था पर सबसे जरूरी होती है और दूसरी आमतौर पर बूटिंग से पहले दी जाती है। सही मात्रा तय करने से पहले स्थानीय मिट्टी जांच या कृषि सलाह जरूर देखें।',
            pa: 'ਕਣਕ ਲਈ ਖਾਦ ਸਲਾਹ: ਬਿਜਾਈ ਵੇਲੇ ਬੇਸਲ ਫਾਸਫੋਰਸ ਦਿਓ ਅਤੇ ਨਾਈਟ੍ਰੋਜਨ ਨੂੰ 2 ਖੁਰਾਕਾਂ ਵਿੱਚ ਦਿਓ। ਪਹਿਲੀ ਟਾਪ ਡ੍ਰੈਸਿੰਗ CRI ਅਵਸਥਾ ਤੇ ਸਭ ਤੋਂ ਮਹੱਤਵਪੂਰਨ ਹੁੰਦੀ ਹੈ ਅਤੇ ਦੂਜੀ ਆਮ ਤੌਰ ਤੇ ਬੂਟਿੰਗ ਤੋਂ ਪਹਿਲਾਂ। ਅੰਤਿਮ ਮਾਤਰਾ ਲਈ ਸਥਾਨਕ ਮਿੱਟੀ ਟੈਸਟ ਜਾਂ ਖੇਤੀ ਸਲਾਹ ਜ਼ਰੂਰ ਵੇਖੋ।',
          );
        }
        if (wantsIrrigation) {
          return _replyByLanguage(
            lang,
            en: 'Wheat irrigation is most critical at crown root initiation, jointing, flowering, and milk stage. If water is limited, never skip crown root initiation and flowering.',
            hi: 'गेहूं में सिंचाई CRI, जॉइंटिंग, फूल आने और दूधिया दाना अवस्था पर सबसे जरूरी होती है। अगर पानी सीमित हो, तो CRI और फूल आने की सिंचाई कभी न छोड़ें।',
            pa: 'ਕਣਕ ਵਿੱਚ ਸਿੰਚਾਈ CRI, ਜੌਇੰਟਿੰਗ, ਫੁੱਲ ਆਉਣ ਅਤੇ ਦੁੱਧੀਆ ਦਾਣਾ ਅਵਸਥਾ ਤੇ ਸਭ ਤੋਂ ਜ਼ਰੂਰੀ ਹੁੰਦੀ ਹੈ। ਜੇ ਪਾਣੀ ਘੱਟ ਹੋਵੇ ਤਾਂ CRI ਅਤੇ ਫੁੱਲਾਂ ਵਾਲੀ ਸਿੰਚਾਈ ਕਦੇ ਨਾ ਛੱਡੋ।',
          );
        }
        break;
      case 'rice':
      case 'paddy':
        if (wantsFertilizer) {
          return _replyByLanguage(
            lang,
            en: 'Rice fertilizer guide: split nitrogen instead of applying it all at once. Give basal phosphorus and potash around transplanting, then top dress nitrogen at tillering and panicle initiation. Fix the exact dose from local soil and variety guidance.',
            hi: 'धान के लिए खाद सलाह: सारी नाइट्रोजन एक साथ न दें, उसे हिस्सों में दें। रोपाई के आसपास बेसल फॉस्फोरस और पोटाश दें, फिर नाइट्रोजन को टिलरिंग और पैनिकल इनिशिएशन पर दें। सही मात्रा स्थानीय मिट्टी और किस्म के अनुसार तय करें।',
            pa: 'ਧਾਨ ਲਈ ਖਾਦ ਸਲਾਹ: ਸਾਰੀ ਨਾਈਟ੍ਰੋਜਨ ਇੱਕੋ ਵਾਰ ਨਾ ਦਿਓ, ਇਸਨੂੰ ਹਿੱਸਿਆਂ ਵਿੱਚ ਦਿਓ। ਰੋਪਾਈ ਦੇ ਸਮੇਂ ਬੇਸਲ ਫਾਸਫੋਰਸ ਅਤੇ ਪੋਟਾਸ਼ ਦਿਓ, ਫਿਰ ਨਾਈਟ੍ਰੋਜਨ ਨੂੰ ਟਿਲਰਿੰਗ ਅਤੇ ਪੈਨਿਕਲ ਇਨੀਸ਼ੀਏਸ਼ਨ ਤੇ ਦਿਓ। ਅੰਤਿਮ ਮਾਤਰਾ ਸਥਾਨਕ ਮਿੱਟੀ ਅਤੇ ਕਿਸਮ ਦੇ ਹਿਸਾਬ ਨਾਲ ਤੈਅ ਕਰੋ।',
          );
        }
        if (wantsIrrigation) {
          return _replyByLanguage(
            lang,
            en: 'Rice needs reliable water at transplanting, tillering, and panicle initiation. Do not keep deep standing water continuously; shallow irrigation with proper drainage is safer for roots.',
            hi: 'धान में रोपाई, टिलरिंग और पैनिकल इनिशिएशन के समय पानी बहुत जरूरी होता है। लगातार गहरा पानी खड़ा न रखें; हल्का पानी और अच्छा निकास जड़ों के लिए ज्यादा सुरक्षित है।',
            pa: 'ਧਾਨ ਵਿੱਚ ਰੋਪਾਈ, ਟਿਲਰਿੰਗ ਅਤੇ ਪੈਨਿਕਲ ਇਨੀਸ਼ੀਏਸ਼ਨ ਵੇਲੇ ਪਾਣੀ ਬਹੁਤ ਜ਼ਰੂਰੀ ਹੁੰਦਾ ਹੈ। ਲਗਾਤਾਰ ਡੂੰਘਾ ਖੜ੍ਹਾ ਪਾਣੀ ਨਾ ਰੱਖੋ; ਹਲਕੀ ਸਿੰਚਾਈ ਅਤੇ ਚੰਗੀ ਨਿਕਾਸੀ ਜੜ੍ਹਾਂ ਲਈ ਜ਼ਿਆਦਾ ਸੁਰੱਖਿਅਤ ਹੈ।',
          );
        }
        break;
      case 'cotton':
        if (wantsFertilizer) {
          return _replyByLanguage(
            lang,
            en: 'Cotton fertilizer guide: use balanced nutrition, not only urea. Give phosphorus and potash at sowing, then split nitrogen into smaller doses. Too much nitrogen pushes leaf growth and can increase pest pressure.',
            hi: 'कपास के लिए खाद सलाह: केवल यूरिया पर निर्भर न रहें। बुवाई के समय फॉस्फोरस और पोटाश दें, फिर नाइट्रोजन को छोटी-छोटी खुराकों में दें। ज्यादा नाइट्रोजन से पत्तेदार बढ़वार और कीट दबाव बढ़ सकता है।',
            pa: 'ਕਪਾਹ ਲਈ ਖਾਦ ਸਲਾਹ: ਕੇਵਲ ਯੂਰੀਆ ਤੇ ਨਿਰਭਰ ਨਾ ਰਹੋ। ਬਿਜਾਈ ਵੇਲੇ ਫਾਸਫੋਰਸ ਅਤੇ ਪੋਟਾਸ਼ ਦਿਓ, ਫਿਰ ਨਾਈਟ੍ਰੋਜਨ ਨੂੰ ਛੋਟੀਆਂ ਖੁਰਾਕਾਂ ਵਿੱਚ ਦਿਓ। ਵੱਧ ਨਾਈਟ੍ਰੋਜਨ ਨਾਲ ਪੱਤਿਆਂ ਦੀ ਵਾਧੂ ਵਰਧੀ ਅਤੇ ਕੀਟ ਦਬਾਅ ਵੱਧ ਸਕਦਾ ਹੈ।',
          );
        }
        if (wantsIrrigation) {
          return _replyByLanguage(
            lang,
            en: 'Cotton prefers deep but less frequent irrigation. Avoid waterlogging, especially during flowering and boll formation, because it increases root stress and disease risk.',
            hi: 'कपास में गहरी लेकिन कम बार सिंचाई बेहतर रहती है। खासकर फूल और बॉल बनने के समय जलभराव से बचें, क्योंकि इससे जड़ों पर तनाव और रोग का खतरा बढ़ता है।',
            pa: 'ਕਪਾਹ ਵਿੱਚ ਡੂੰਘੀ ਪਰ ਘੱਟ ਵਾਰ ਸਿੰਚਾਈ ਚੰਗੀ ਰਹਿੰਦੀ ਹੈ। ਖਾਸ ਕਰਕੇ ਫੁੱਲ ਅਤੇ ਬੋਲ ਬਣਨ ਵੇਲੇ ਪਾਣੀ ਖੜ੍ਹਾ ਨਾ ਹੋਣ ਦਿਓ, ਨਹੀਂ ਤਾਂ ਜੜ੍ਹਾਂ ਉੱਤੇ ਤਣਾਅ ਅਤੇ ਰੋਗ ਦਾ ਖਤਰਾ ਵੱਧਦਾ ਹੈ।',
          );
        }
        break;
      case 'tomato':
        if (wantsDisease) {
          return _replyByLanguage(
            lang,
            en: 'For tomato disease, first identify whether it looks like early blight, late blight, leaf mold, or viral leaf curl. Use the disease camera flow for the exact label, then follow the treatment shown on the result screen.',
            hi: 'टमाटर के रोग में पहले यह पहचानें कि लक्षण अर्ली ब्लाइट, लेट ब्लाइट, लीफ मोल्ड या वायरल लीफ कर्ल जैसे हैं या नहीं। सही पहचान के लिए ऐप का रोग-कैमरा चलाइए, फिर रिजल्ट स्क्रीन पर दिखी सलाह मानिए।',
            pa: 'ਟਮਾਟਰ ਦੇ ਰੋਗ ਲਈ ਪਹਿਲਾਂ ਵੇਖੋ ਕਿ ਲੱਛਣ ਅਰਲੀ ਬਲਾਈਟ, ਲੇਟ ਬਲਾਈਟ, ਲੀਫ ਮੋਲਡ ਜਾਂ ਵਾਇਰਲ ਲੀਫ ਕਰਲ ਵਰਗੇ ਹਨ ਜਾਂ ਨਹੀਂ। ਪੱਕੀ ਪਛਾਣ ਲਈ ਐਪ ਦਾ ਰੋਗ-ਕੈਮਰਾ ਚਲਾਓ, ਫਿਰ ਨਤੀਜੇ ਵਾਲੀ ਸਕ੍ਰੀਨ ਉੱਤੇ ਦਿੱਤੀ ਸਲਾਹ ਮੰਨੋ।',
          );
        }
        if (wantsFertilizer) {
          return _replyByLanguage(
            lang,
            en: 'Tomato needs balanced feeding. Start with compost and basal phosphorus, then split nitrogen and potassium through the season. Too much nitrogen gives lush leaves but weak fruiting.',
            hi: 'टमाटर को संतुलित पोषण चाहिए। शुरुआत में कंपोस्ट और बेसल फॉस्फोरस दें, फिर मौसम के दौरान नाइट्रोजन और पोटाश को हिस्सों में दें। ज्यादा नाइट्रोजन से पत्ते तो बढ़ते हैं, लेकिन फलन कमजोर हो सकती है।',
            pa: 'ਟਮਾਟਰ ਨੂੰ ਸੰਤੁਲਿਤ ਪੋਸ਼ਣ ਚਾਹੀਦਾ ਹੈ। ਸ਼ੁਰੂ ਵਿੱਚ ਕੰਪੋਸਟ ਅਤੇ ਬੇਸਲ ਫਾਸਫੋਰਸ ਦਿਓ, ਫਿਰ ਮੌਸਮ ਦੌਰਾਨ ਨਾਈਟ੍ਰੋਜਨ ਅਤੇ ਪੋਟਾਸ਼ ਨੂੰ ਹਿੱਸਿਆਂ ਵਿੱਚ ਦਿਓ। ਵੱਧ ਨਾਈਟ੍ਰੋਜਨ ਨਾਲ ਪੱਤੇ ਤਾਂ ਵੱਧਦੇ ਹਨ, ਪਰ ਫਲ ਘੱਟ ਬੰਨ੍ਹਦੇ ਹਨ।',
          );
        }
        if (wantsIrrigation) {
          return _replyByLanguage(
            lang,
            en: 'Tomato does best with regular light irrigation and dry foliage. Use drip if possible, and avoid wetting leaves late in the day because it increases blight and leaf mold risk.',
            hi: 'टमाटर में नियमित हल्की सिंचाई और सूखी पत्तियां बेहतर रहती हैं। संभव हो तो ड्रिप का उपयोग करें और शाम के बाद पत्तियों को गीला न करें, क्योंकि इससे ब्लाइट और लीफ मोल्ड का खतरा बढ़ता है।',
            pa: 'ਟਮਾਟਰ ਵਿੱਚ ਨਿਯਮਿਤ ਹਲਕੀ ਸਿੰਚਾਈ ਅਤੇ ਸੁੱਕੀਆਂ ਪੱਤੀਆਂ ਵਧੀਆ ਰਹਿੰਦੀਆਂ ਹਨ। ਸੰਭਵ ਹੋਵੇ ਤਾਂ ਡ੍ਰਿਪ ਵਰਤੋ ਅਤੇ ਦੇਰ ਸ਼ਾਮ ਪੱਤੀਆਂ ਨੂੰ ਭਿੱਜਣ ਤੋਂ ਬਚਾਓ, ਕਿਉਂਕਿ ਇਸ ਨਾਲ ਬਲਾਈਟ ਅਤੇ ਲੀਫ ਮੋਲਡ ਦਾ ਖਤਰਾ ਵੱਧਦਾ ਹੈ।',
          );
        }
        break;
      case 'maize':
        if (wantsFertilizer) {
          return _replyByLanguage(
            lang,
            en: 'Maize responds well to split nitrogen. Apply basal phosphorus and potash at sowing, then top dress nitrogen at knee-high stage and before tasseling. Do not delay the second nitrogen split if the crop looks pale.',
            hi: 'मक्का में नाइट्रोजन को हिस्सों में देने से अच्छा लाभ मिलता है। बुवाई पर बेसल फॉस्फोरस और पोटाश दें, फिर नाइट्रोजन को घुटना अवस्था और टासलिंग से पहले दें। अगर फसल पीली दिख रही हो तो दूसरी खुराक देर से न दें।',
            pa: 'ਮੱਕੀ ਵਿੱਚ ਨਾਈਟ੍ਰੋਜਨ ਨੂੰ ਹਿੱਸਿਆਂ ਵਿੱਚ ਦੇਣ ਨਾਲ ਚੰਗਾ ਨਤੀਜਾ ਮਿਲਦਾ ਹੈ। ਬਿਜਾਈ ਵੇਲੇ ਬੇਸਲ ਫਾਸਫੋਰਸ ਅਤੇ ਪੋਟਾਸ਼ ਦਿਓ, ਫਿਰ ਨਾਈਟ੍ਰੋਜਨ ਨੂੰ ਘੁੱਟਣਾ ਅਵਸਥਾ ਅਤੇ ਟਾਸਲਿੰਗ ਤੋਂ ਪਹਿਲਾਂ ਦਿਓ। ਜੇ ਫਸਲ ਪੀਲੀ ਲੱਗੇ ਤਾਂ ਦੂਜੀ ਖੁਰਾਕ ਵਿੱਚ ਦੇਰ ਨਾ ਕਰੋ।',
          );
        }
        if (wantsIrrigation) {
          return _replyByLanguage(
            lang,
            en: 'Maize needs the most water at knee-high, tasseling, silking, and grain filling. Moisture stress at tasseling and silking can sharply reduce yield.',
            hi: 'मक्का में घुटना अवस्था, टासलिंग, सिल्किंग और दाना भरने के समय पानी सबसे ज्यादा जरूरी होता है। टासलिंग और सिल्किंग पर नमी की कमी से उपज काफी घट सकती है।',
            pa: 'ਮੱਕੀ ਵਿੱਚ ਘੁੱਟਣਾ ਅਵਸਥਾ, ਟਾਸਲਿੰਗ, ਸਿਲਕਿੰਗ ਅਤੇ ਦਾਣਾ ਭਰਨ ਵੇਲੇ ਪਾਣੀ ਸਭ ਤੋਂ ਵੱਧ ਜ਼ਰੂਰੀ ਹੁੰਦਾ ਹੈ। ਟਾਸਲਿੰਗ ਅਤੇ ਸਿਲਕਿੰਗ ਸਮੇਂ ਨਮੀ ਦੀ ਘਾਟ ਨਾਲ ਪੈਦਾਵਾਰ ਕਾਫੀ ਘਟ ਸਕਦੀ ਹੈ।',
          );
        }
        break;
      case 'mustard':
        if (wantsFertilizer) {
          return _replyByLanguage(
            lang,
            en: 'Mustard needs sulphur along with nitrogen and phosphorus. Basal phosphorus is useful, but sulphur deficiency can reduce oil yield, so include a sulphur source where local advice recommends it.',
            hi: 'सरसों में नाइट्रोजन और फॉस्फोरस के साथ सल्फर भी जरूरी है। बेसल फॉस्फोरस उपयोगी रहता है, लेकिन सल्फर की कमी से तेल वाली उपज घट सकती है, इसलिए स्थानीय सलाह के अनुसार सल्फर स्रोत जरूर दें।',
            pa: 'ਸਰੋਂ ਵਿੱਚ ਨਾਈਟ੍ਰੋਜਨ ਅਤੇ ਫਾਸਫੋਰਸ ਦੇ ਨਾਲ ਗੰਧਕ ਵੀ ਜ਼ਰੂਰੀ ਹੈ। ਬੇਸਲ ਫਾਸਫੋਰਸ ਲਾਭਦਾਇਕ ਰਹਿੰਦਾ ਹੈ, ਪਰ ਗੰਧਕ ਦੀ ਘਾਟ ਨਾਲ ਤੇਲ ਵਾਲੀ ਪੈਦਾਵਾਰ ਘਟ ਸਕਦੀ ਹੈ, ਇਸ ਲਈ ਸਥਾਨਕ ਸਲਾਹ ਅਨੁਸਾਰ ਗੰਧਕ ਦਾ ਸਰੋਤ ਦਿਓ।',
          );
        }
        if (wantsIrrigation) {
          return _replyByLanguage(
            lang,
            en: 'Mustard usually needs light irrigation at branching, flowering, and pod formation. Avoid excess watering because mustard is sensitive to waterlogging.',
            hi: 'सरसों में शाखा बनना, फूल आना और फली बनना, इन अवस्थाओं पर हल्की सिंचाई फायदेमंद रहती है। ज्यादा पानी से बचें, क्योंकि सरसों जलभराव के प्रति संवेदनशील होती है।',
            pa: 'ਸਰੋਂ ਵਿੱਚ ਟਾਹਣੀਆਂ ਬਣਨ, ਫੁੱਲ ਆਉਣ ਅਤੇ ਫਲੀ ਬਣਨ ਵੇਲੇ ਹਲਕੀ ਸਿੰਚਾਈ ਲਾਭਦਾਇਕ ਹੁੰਦੀ ਹੈ। ਵੱਧ ਪਾਣੀ ਤੋਂ ਬਚੋ, ਕਿਉਂਕਿ ਸਰੋਂ ਪਾਣੀ ਖੜ੍ਹੇ ਰਹਿਣ ਨਾਲ ਜਲਦੀ ਨੁਕਸਾਨ ਖਾਂਦੀ ਹੈ।',
          );
        }
        break;
      case 'sugarcane':
        if (wantsFertilizer) {
          return _replyByLanguage(
            lang,
            en: 'Sugarcane is a heavy feeder. Apply farmyard manure before planting, give basal phosphorus and potash, and split nitrogen across early growth stages instead of one heavy dose.',
            hi: 'गन्ना ज्यादा पोषण लेने वाली फसल है। रोपाई से पहले गोबर की सड़ी खाद दें, बेसल फॉस्फोरस और पोटाश दें, और नाइट्रोजन को शुरुआती वृद्धि अवस्थाओं में हिस्सों में दें, एक बार में भारी मात्रा न दें।',
            pa: 'ਗੰਨਾ ਵੱਧ ਪੋਸ਼ਣ ਲੈਣ ਵਾਲੀ ਫਸਲ ਹੈ। ਰੋਪਾਈ ਤੋਂ ਪਹਿਲਾਂ ਚੰਗੀ ਤਰ੍ਹਾਂ ਸੜੀ ਹੋਈ ਖਾਦ ਦਿਓ, ਬੇਸਲ ਫਾਸਫੋਰਸ ਅਤੇ ਪੋਟਾਸ਼ ਦਿਓ, ਅਤੇ ਨਾਈਟ੍ਰੋਜਨ ਨੂੰ ਸ਼ੁਰੂਆਤੀ ਵਾਧੇ ਵਾਲੀਆਂ ਅਵਸਥਾਵਾਂ ਵਿੱਚ ਹਿੱਸਿਆਂ ਵਿੱਚ ਦਿਓ, ਇੱਕੋ ਵਾਰ ਭਾਰੀ ਮਾਤਰਾ ਨਾ ਦਿਓ।',
          );
        }
        if (wantsIrrigation) {
          return _replyByLanguage(
            lang,
            en: 'Sugarcane should be irrigated regularly during tillering and grand growth stage. Keep moisture steady, but improve drainage during rainy periods to prevent root stress.',
            hi: 'गन्ने में टिलरिंग और तेज बढ़वार वाली अवस्था में नियमित सिंचाई जरूरी होती है। मिट्टी में नमी स्थिर रखें, लेकिन बारिश के समय निकास अच्छा रखें ताकि जड़ों पर तनाव न पड़े।',
            pa: 'ਗੰਨੇ ਵਿੱਚ ਟਿਲਰਿੰਗ ਅਤੇ ਤੇਜ਼ ਵਾਧੇ ਵਾਲੀ ਅਵਸਥਾ ਦੌਰਾਨ ਨਿਯਮਿਤ ਸਿੰਚਾਈ ਜ਼ਰੂਰੀ ਹੁੰਦੀ ਹੈ। ਮਿੱਟੀ ਦੀ ਨਮੀ ਸਥਿਰ ਰੱਖੋ, ਪਰ ਮੀਂਹ ਦੇ ਸਮੇਂ ਨਿਕਾਸ ਚੰਗਾ ਰੱਖੋ ਤਾਂ ਜੋ ਜੜ੍ਹਾਂ ਉੱਤੇ ਤਣਾਅ ਨਾ ਪਏ।',
          );
        }
        break;
    }

    return null;
  }

  String? _detectCrop(String input, String? cropContext) {
    final haystack = '$input ${cropContext ?? ''}'.toLowerCase();
    const aliases = {
      'wheat': ['wheat', 'gehu'],
      'rice': ['rice', 'paddy', 'dhan'],
      'paddy': ['rice', 'paddy', 'dhan'],
      'cotton': ['cotton', 'kapas'],
      'tomato': ['tomato'],
      'maize': ['maize', 'corn', 'makka'],
      'mustard': ['mustard', 'sarson'],
      'sugarcane': ['sugarcane', 'ganna'],
    };

    for (final entry in aliases.entries) {
      if (entry.value.any(haystack.contains)) {
        return entry.key;
      }
    }
    return null;
  }

  String _replyByLanguage(
    String lang, {
    required String en,
    String? hi,
    String? pa,
  }) {
    switch (lang) {
      case 'hi':
        return hi ?? en;
      case 'pa':
        return pa ?? en;
      default:
        return en;
    }
  }

  bool _shouldUseSafeOfflineFallback(
    String reply,
    String userMessage,
    String lang, {
    bool fromBackend = false,
    String? cropContext,
    String? locationContext,
  }) {
    final trimmedReply = reply.trim();
    if (trimmedReply.isEmpty) return true;
    if (!_hasExpectedScript(trimmedReply, lang)) return true;
    if (_hasSevereTokenRepetition(trimmedReply)) return true;

    if (!fromBackend) {
      final requiredClarification = _buildClarifyingReply(
        _normalizeText(_normalizeDomainTerms(userMessage.toLowerCase())),
        lang,
        cropContext: cropContext,
        locationContext: locationContext,
      );
      if (requiredClarification != null &&
          !_looksLikeClarifyingReply(trimmedReply, lang)) {
        return true;
      }
    }

    return false;
  }

  bool _hasExpectedScript(String reply, String lang) {
    switch (lang) {
      case 'hi':
        return RegExp(r'[\u0900-\u097F]').hasMatch(reply);
      case 'pa':
        return RegExp(r'[\u0A00-\u0A7F]').hasMatch(reply);
      default:
        return true;
    }
  }

  bool _hasSevereTokenRepetition(String reply) {
    final tokens = _normalizeText(reply.toLowerCase())
        .split(' ')
        .where((token) => token.isNotEmpty && token.length > 1)
        .toList();
    if (tokens.length < 5) return false;

    var adjacentRepeats = 0;
    final counts = <String, int>{};
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      counts[token] = (counts[token] ?? 0) + 1;
      if (i > 0 && tokens[i - 1] == token) {
        adjacentRepeats++;
      }
    }

    final mostFrequent = counts.values.fold<int>(0, math.max);
    final repeatedTokenDominates =
        mostFrequent >= 3 && mostFrequent >= (tokens.length / 3).ceil();
    return adjacentRepeats > 0 || repeatedTokenDominates;
  }

  bool _looksLikeClarifyingReply(String reply, String lang) {
    if (reply.contains('?')) return true;

    final lower = reply.toLowerCase();
    final hints = <String>[
      'which crop',
      'what crop',
      'growth stage',
      'location',
      'कौन',
      'किस',
      'बताइए',
      'ਗੱਲਾਂ ਦੱਸੋ',
      'ਕਿਹੜੀ',
      'ਦੱਸੋ',
    ];
    return hints.any(lower.contains);
  }

  bool _shouldDisableOnlineForSession(Object error) {
    final message = error.toString();
    return message.contains('404') ||
        message.contains('401') ||
        message.contains('403') ||
        message.contains('Model') ||
        message.contains('not found');
  }

  bool _canUseOnlineModel(String languageCode) {
    if (AppConstants.hasBackendBaseUrl) {
      return _backendOnlineLanguages.contains(languageCode);
    }
    return languageCode == 'en' && AppConstants.canUseDirectAiProvider;
  }

  String? _matchLanguageSupportRequest(String input, String lang) {
    if (!_matchKeywords(input, [
      'speak',
      'talk',
      'language',
      'punjabi',
      'hindi',
      'marathi',
      'telugu',
      'english',
    ])) {
      return null;
    }

    if (lang == 'pa') {
      return 'ਮੈਂ ਪੰਜਾਬੀ ਵਿੱਚ ਗੱਲ ਕਰ ਸਕਦਾ ਹਾਂ। ਤੁਸੀਂ ਫਸਲ, ਖਾਦ, ਸਿੰਚਾਈ, ਮੌਸਮ ਜਾਂ ਰੋਗ ਬਾਰੇ ਪੁੱਛੋ, ਮੈਂ ਸੌਖੇ ਸ਼ਬਦਾਂ ਵਿੱਚ ਮਦਦ ਕਰਾਂਗਾ।';
    }

    if (lang == 'hi') {
      return 'मैं हिंदी में मदद कर सकता हूँ। अगर आप पंजाबी में जवाब चाहते हैं, तो ऐप के भाषा चयन से Punjabi चुनें। आप फसल, खाद, सिंचाई, मौसम या रोग के बारे में पूछ सकते हैं।';
    }

    if (lang == 'mr') {
      return 'मी मराठीत मदत करू शकतो. पीक, खत, सिंचन, हवामान किंवा रोग याबद्दल प्रश्न विचारा.';
    }

    if (lang == 'te') {
      return 'నేను తెలుగులో మీకు సహాయం చేయగలను. పంట, ఎరువు, నీటిపారుదల, వాతావరణం లేదా రోగాల గురించి అడగండి.';
    }

    return 'I can help in English here. If you want Hindi, Punjabi, Marathi, or Telugu replies, switch the app language from the language selector and then ask your farming question again.';
  }

  bool _matchKeywords(String input, List<String> keywords) {
    return keywords.any((keyword) => input.contains(keyword.toLowerCase()));
  }

  String? _getResponse(String lang, String key) {
    final builtIn = _builtInResponses[lang]?[key];
    if (builtIn != null) return builtIn;

    final section =
        (_offlineResponses?[lang] ?? _offlineResponses?['en'])
            as Map<String, dynamic>?;
    return section?[key] as String?;
  }

  String _offlineFallback(String lang) {
    if (lang == 'mr') {
      return 'मी सध्या ऑफलाइन आहे. संपूर्ण मदतीसाठी इंटरनेट जोडा. रोग, खत, पाणी, पीक किंवा हवामानाबद्दल विचारा.';
    }
    if (lang == 'te') {
      return 'నేను ప్రస్తుతం ఆఫ్లైన్‌లో ఉన్నాను. పూర్తి సహాయం కోసం ఇంటర్నెట్ కనెక్ట్ చేయండి. రోగాలు, ఎరువు, నీరు, పంట లేదా వాతావరణం గురించి అడగండి.';
    }

    const fallbacks = {
      'en':
          'I am currently offline. Connect to the internet for AI assistance. Try asking about diseases, fertilizers, water, crops, or weather.',
      'hi':
          'मैं अभी ऑफलाइन हूं। पूरी मदद के लिए इंटरनेट कनेक्ट करें। रोग, खाद, पानी, फसल, या मौसम के बारे में पूछें।',
      'pa':
          'ਮੈਂ ਇਸ ਵੇਲੇ ਆਫਲਾਈਨ ਹਾਂ। ਪੂਰੀ ਮਦਦ ਲਈ ਇੰਟਰਨੈੱਟ ਨਾਲ ਜੁੜੋ। ਰੋਗ, ਖਾਦ, ਪਾਣੀ, ਫਸਲ ਜਾਂ ਮੌਸਮ ਬਾਰੇ ਪੁੱਛੋ।',
    };
    return fallbacks[lang] ?? fallbacks['en']!;
  }

  String _localAssistantFallback(String lang) {
    if (lang == 'mr') {
      return 'मी आत्ता स्थानिक शेती मार्गदर्शन मोडमध्ये आहे. रोग, खत, सिंचन, पीक किंवा हवामान सल्ल्याबद्दल विचारा.';
    }
    if (lang == 'te') {
      return 'నేను ఇప్పుడు స్థానిక వ్యవసాయ మార్గదర్శక మోడ్‌లో ఉన్నాను. రోగాలు, ఎరువు, నీటిపారుదల, పంట లేదా వాతావరణ సలహా గురించి అడగండి.';
    }

    const fallbacks = {
      'en':
          'I am using local farming guidance right now. Ask me about disease treatment, fertilizers, irrigation, crops, or weather advice.',
      'hi':
          'मैं अभी लोकल फार्मिंग गाइडेंस मोड में हूँ। आप रोग, खाद, सिंचाई, फसल या मौसम सलाह के बारे में पूछ सकते हैं।',
      'pa':
          'ਮੈਂ ਇਸ ਵੇਲੇ ਲੋਕਲ ਫਾਰਮਿੰਗ ਗਾਈਡੈਂਸ ਮੋਡ ਵਿੱਚ ਹਾਂ। ਤੁਸੀਂ ਰੋਗ, ਖਾਦ, ਸਿੰਚਾਈ, ਫਸਲ ਜਾਂ ਮੌਸਮ ਬਾਰੇ ਪੁੱਛ ਸਕਦੇ ਹੋ।',
    };
    return fallbacks[lang] ?? fallbacks['en']!;
  }

  String _buildSystemPrompt(String lang) {
    return '''You are an AI agricultural assistant for Indian farmers.
Perform all reasoning internally and return only the final answer.

Internally:
1. Detect the user's language.
2. Translate to simple English if needed.
3. Identify the crop, likely issue, and user intent.
4. Use agricultural knowledge carefully.
5. Reply in the original user language.

Rules:
- Use simple farmer-friendly language.
- Prefer short bullet points.
- Do not mention these internal steps.
- Never invent pesticide names, chemical doses, or unsafe treatments.
- If fertilizer, pesticide, or spray advice depends on crop, stage, or symptom and that detail is missing, ask 1 or 2 short clarifying questions instead of guessing.
- For Hindi replies, use natural Devanagari Hindi.
- For Punjabi replies, use natural Gurmukhi Punjabi.
- Do not transliterate full answers into another script.
- If confidence is low, ask 1 or 2 clarifying questions instead of guessing.
- Keep the answer practical and suitable for Indian farmers.

Preferred app language: $lang''';
  }

  Future<bool> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any(
        (result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet,
      );
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      return false;
    }
  }

  void clearHistory() {
    _history.clear();
    _onlineDisabledForSession = false;
  }

  List<ChatMessage> getHistory() => List.unmodifiable(_history);

  Map<String, dynamic> _defaultFallback() {
    return {
      'en': {
        'greeting': 'Namaste! How can I help you?',
        'disease_general': 'Use the camera to detect diseases.',
        'fertilizer_general': 'Apply recommended fertilizers based on crop.',
      },
      'hi': {
        'greeting': 'नमस्ते! कैसे मदद कर सकता हूं?',
        'disease_general': 'कैमरा का उपयोग करके रोग का पता लगाएं।',
        'fertilizer_general': 'सिफारिश की गई खाद लागू करें।',
      },
    };
  }
}
