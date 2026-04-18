// ─────────────────────────────────────────────
// services/stt_service.dart
// Speech-to-text using speech_to_text plugin.
// Works offline with on-device recognition.
// ─────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class STTService {
  STTService._();
  static final STTService instance = STTService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized  = false;
  bool _isListening    = false;

  bool get isListening    => _isListening;
  bool get isInitialized  => _isInitialized;

  // ── Initialise & request permission ──────────
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

  // ── Start listening ───────────────────────────
  Future<void> startListening(
    void Function(String text) onResult, {
    required void Function() onListeningStart,
    required void Function() onListeningStop,
    String languageCode = 'en',
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    if (_isListening) return;

    _isListening = true;
    onListeningStart();

    await _speech.listen(
      (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          _isListening = false;
          onListeningStop();
        }
      },
      localeId:      _languageToLocale(languageCode),
      listenMode:    stt.ListenMode.dictation,
      pauseFor:      const Duration(seconds: 3),
      listenFor:     const Duration(seconds: 30),
      cancelOnError: true,
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