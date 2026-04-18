// ─────────────────────────────────────────────
// services/voice_services.dart
// Contains both TTSService and STTService
// ─────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────
// TTS SERVICE - Text to Speech
// ─────────────────────────────────────────────

class TTSService {
  TTSService._();
  static final TTSService instance = TTSService._();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.45);  // Slower for rural users
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('TTS error: $msg');
    });

    _isInitialized = true;
  }

  Future<void> speak(String text, {String languageCode = 'en'}) async {
    await initialize();
    await stop();

    // Map app language codes to BCP-47 locales
    final locale = _languageToLocale(languageCode);
    await _tts.setLanguage(locale);

    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }

  Future<List<String>> getAvailableLanguages() async {
    final langs = await _tts.getLanguages as List<dynamic>?;
    return langs?.map((l) => l.toString()).toList() ?? [];
  }

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

  void dispose() => _tts.stop();
}

// ─────────────────────────────────────────────
// STT SERVICE - Speech to Text
// ─────────────────────────────────────────────

class STTService {
  STTService._();
  static final STTService instance = STTService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  // Callback for when speech is recognized
  Function(String)? _onResultCallback;

  // ── Initialize & request permission ──────────
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('Microphone permission denied');
      return false;
    }

    _isInitialized = await _speech.initialize(
      onError: (error) {
        debugPrint('STT error: ${error.errorMsg}');
        _isListening = false;
      },
      onStatus: (status) {
        debugPrint('STT status: $status');
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );

    return _isInitialized;
  }

  // ── Start listening with positional callback ──
  Future<void> startListening(
    Function(String) onResult, {
    Function()? onListeningStart,
    Function()? onListeningStop,
    String languageCode = 'en',
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    if (_isListening) return;

    _isListening = true;
    _onResultCallback = onResult;
    onListeningStart?.call();

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          _isListening = false;
          onListeningStop?.call();
        }
      },
      localeId: _languageToLocale(languageCode),
      listenMode: stt.ListenMode.dictation,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      cancelOnError: true,
      partialResults: true,
    );
  }

  // ── Stop listening ────────────────────────────
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  // ── Available locales ─────────────────────────
  Future<List<String>> getAvailableLocales() async {
    final locales = await _speech.locales();
    return locales.map((l) => l.localeId).toList();
  }

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
}