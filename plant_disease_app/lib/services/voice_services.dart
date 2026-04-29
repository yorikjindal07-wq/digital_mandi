// ═══════════════════════════════════════════════════════════════
// lib/services/voice_services.dart
// Text-to-Speech (TTS) and Speech-to-Text (STT) services
// Multi-language support for Indian languages
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';

/// ──────────────────────────────────────────────────────────────
/// TTS SERVICE - TEXT TO SPEECH
/// ──────────────────────────────────────────────────────────────

class TTSService extends ChangeNotifier {
  TTSService._();
  static final TTSService instance = TTSService._();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String _currentLanguage = 'en-IN';

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  String get currentLanguage => _currentLanguage;

  /// Initialize TTS with appropriate settings for rural users
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('🔊 Initializing TTS...');

      // Set TTS parameters
      await _tts.setVolume(AppConstants.ttsVolume);
      await _tts.setSpeechRate(
        AppConstants.ttsSpeechRate,
      ); // Slower for clarity
      await _tts.setPitch(AppConstants.ttsPitch);

      // Set callbacks
      _tts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
        debugPrint('🔊 TTS: Speaking started');
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
        debugPrint('🔊 TTS: Speaking completed');
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
        notifyListeners();
        debugPrint('🔊 TTS: Speaking cancelled');
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        notifyListeners();
        debugPrint('🔊 TTS Error: $msg');
      });

      // Set default language
      await setLanguage('en');

      _isInitialized = true;
      debugPrint('✅ TTS initialized successfully');
      return true;
    } catch (e) {
      debugPrint('🔥 TTS initialization error: $e');
      return false;
    }
  }

  /// Set language for TTS
  Future<bool> setLanguage(String languageCode) async {
    try {
      final locale = _languageToLocale(languageCode);
      await _tts.setLanguage(locale);
      _currentLanguage = locale;
      debugPrint('✅ TTS language set to: $locale');
      return true;
    } catch (e) {
      debugPrint('⚠️  Set language error: $e');
      return false;
    }
  }

  /// Speak text with specified language
  Future<void> speak(
    String text, {
    String languageCode = 'en',
    double rate = -1,
    double pitch = -1,
    double volume = -1,
  }) async {
    try {
      if (!_isInitialized) {
        final ok = await initialize();
        if (!ok) return;
      }

      await stop(); // Stop any ongoing speech

      // Set language
      await setLanguage(languageCode);

      // Apply custom parameters if provided
      if (rate > 0) await _tts.setSpeechRate(rate);
      if (pitch > 0) await _tts.setPitch(pitch);
      if (volume > 0) await _tts.setVolume(volume);

      debugPrint('🔊 Speaking: "$text" in $languageCode');
      await _tts.speak(text);
    } catch (e) {
      debugPrint('🔥 Speak error: $e');
      _isSpeaking = false;
      notifyListeners();
    }
  }

  /// Stop ongoing speech
  Future<void> stop() async {
    try {
      if (_isSpeaking) {
        await _tts.stop();
        _isSpeaking = false;
        notifyListeners();
        debugPrint('🔊 TTS stopped');
      }
    } catch (e) {
      debugPrint('⚠️  Stop error: $e');
    }
  }

  /// Pause ongoing speech
  Future<void> pause() async {
    try {
      await _tts.pause();
      debugPrint('⏸️  TTS paused');
    } catch (e) {
      debugPrint('⚠️  Pause error: $e');
    }
  }

  /// Resume paused speech
  Future<void> resume() async {
    try {
      debugPrint('▶️  TTS resumed');
    } catch (e) {
      debugPrint('⚠️  Resume error: $e');
    }
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    try {
      final langs = await _tts.getLanguages as List<dynamic>?;
      return langs?.map((l) => l.toString()).toList() ?? [];
    } catch (e) {
      debugPrint('⚠️  Get languages error: $e');
      return [];
    }
  }

  /// Map language codes to system locales
  static String _languageToLocale(String code) {
    const map = {
      'en': 'en-IN',
      'hi': 'hi-IN',
      'pa': 'pa-IN',
      'mr': 'mr-IN',
      'te': 'te-IN',
    };
    return map[code] ?? 'en-IN';
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// ──────────────────────────────────────────────────────────────
/// STT SERVICE - SPEECH TO TEXT
/// ──────────────────────────────────────────────────────────────

class STTService extends ChangeNotifier {
  STTService._();
  static final STTService instance = STTService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentLanguage = 'en_IN';
  String _partialResult = '';
  String _finalResult = '';

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentLanguage => _currentLanguage;
  String get partialResult => _partialResult;
  String get finalResult => _finalResult;

  /// Initialize STT with microphone permission
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('🎤 Initializing STT...');

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('❌ Microphone permission denied');
        return false;
      }

      // Initialize speech recognition
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('🎤 STT Error: ${error.errorMsg}');
          _isListening = false;
          notifyListeners();
        },
        onStatus: (status) {
          debugPrint('🎤 STT Status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
          }
        },
        debugLogging: false,
      );

      debugPrint('✅ STT initialized successfully');
      return _isInitialized;
    } catch (e) {
      debugPrint('🔥 STT initialization error: $e');
      return false;
    }
  }

  /// Start listening for speech
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function()? onListeningStart,
    Function()? onListeningStop,
    String languageCode = 'en',
  }) async {
    try {
      if (!_isInitialized) {
        final ok = await initialize();
        if (!ok) return;
      }

      if (_isListening) return;

      final locale = _languageToLocale(languageCode);
      _currentLanguage = locale;

      _isListening = true;
      _partialResult = '';
      _finalResult = '';

      onListeningStart?.call();
      notifyListeners();

      debugPrint('🎤 Starting speech recognition in $locale');

      await _speech.listen(
        onResult: (result) {
          _partialResult = result.recognizedWords;

          if (result.finalResult) {
            _finalResult = result.recognizedWords;
            onResult(_finalResult);
            _isListening = false;
            onListeningStop?.call();
            notifyListeners();
          } else {
            onPartialResult?.call(_partialResult);
            notifyListeners();
          }
        },
        localeId: locale,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
        ),
        onSoundLevelChange: (level) {
          // Reserved for future voice-level UI feedback.
        },
      );
    } catch (e) {
      debugPrint('🔥 Start listening error: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stop listening
  Future<void> stopListening({Function()? onStop}) async {
    try {
      if (_isListening) {
        await _speech.stop();
        _isListening = false;
        onStop?.call();
        notifyListeners();
        debugPrint('🎤 Listening stopped');
      }
    } catch (e) {
      debugPrint('⚠️  Stop listening error: $e');
    }
  }

  /// Cancel current listening session
  Future<void> cancel() async {
    try {
      await _speech.cancel();
      _isListening = false;
      _partialResult = '';
      _finalResult = '';
      notifyListeners();
      debugPrint('🎤 Listening cancelled');
    } catch (e) {
      debugPrint('⚠️  Cancel error: $e');
    }
  }

  /// Get available locales for STT
  Future<List<String>> getAvailableLocales() async {
    try {
      final locales = await _speech.locales();
      return locales.map((l) => l.localeId).toList();
    } catch (e) {
      debugPrint('⚠️  Get locales error: $e');
      return [];
    }
  }

  /// Map language codes to system locales
  static String _languageToLocale(String code) {
    const map = {
      'en': 'en_IN',
      'hi': 'hi_IN',
      'pa': 'pa_IN',
      'mr': 'mr_IN',
      'te': 'te_IN',
    };
    return map[code] ?? 'en_IN';
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}

/// ──────────────────────────────────────────────────────────────
/// VOICE HELPER SERVICE
/// ──────────────────────────────────────────────────────────────

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  /// Get voice-ready response (text + audio)
  Future<void> speakAndListen({
    required String text,
    required String languageCode,
    required Function(String) onSpeechResult,
    Function()? onListeningStart,
    Function()? onListeningStop,
  }) async {
    try {
      // First, speak the response
      await TTSService.instance.speak(text, languageCode: languageCode);

      // Wait for speech to finish
      await Future.delayed(Duration(milliseconds: (text.length * 50).toInt()));

      // Then start listening
      await STTService.instance.startListening(
        onResult: onSpeechResult,
        onListeningStart: onListeningStart,
        onListeningStop: onListeningStop,
        languageCode: languageCode,
      );
    } catch (e) {
      debugPrint('🔥 Voice interaction error: $e');
    }
  }

  /// Initialize all voice services
  Future<bool> initializeAll() async {
    try {
      final ttsOk = await TTSService.instance.initialize();
      final sttOk = await STTService.instance.initialize();
      return ttsOk && sttOk;
    } catch (e) {
      debugPrint('🔥 Voice initialization error: $e');
      return false;
    }
  }

  /// Cleanup all voice services
  Future<void> dispose() async {
    try {
      await TTSService.instance.stop();
      await STTService.instance.cancel();
      debugPrint('✅ Voice services disposed');
    } catch (e) {
      debugPrint('⚠️  Dispose error: $e');
    }
  }
}
