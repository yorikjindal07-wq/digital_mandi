# ================================================================
# apply_fixes.ps1
# Run this from: D:\digital_mandi\plant_disease_app
# It applies all pending fixes directly to your project files.
# Usage: .\apply_fixes.ps1
# ================================================================

$lib = "lib"

Write-Host "Applying Digital Mandi Flutter fixes..." -ForegroundColor Cyan

# ── Fix 1: Delete old prediction_model.dart if it exists ────────
$oldModel = "$lib\models\prediction_model.dart"
if (Test-Path $oldModel) {
    Remove-Item $oldModel -Force
    Write-Host "  Deleted old: $oldModel" -ForegroundColor Yellow
}

# ── Fix 2: Rewrite models.dart with optional timestamp ──────────
$modelsContent = @'
// lib/models/models.dart — all app data models in one file

class PredictionModel {
  final String   disease;
  final double   confidence;
  final String   crop;
  final DateTime timestamp;

  PredictionModel({
    required this.disease,
    required this.confidence,
    required this.crop,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isHealthy   => disease == 'healthy';
  bool get isUncertain => confidence < 0.60;

  String get displayName => disease
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Map<String, dynamic> toJson() => {
    'disease':    disease,
    'confidence': confidence,
    'crop':       crop,
    'timestamp':  timestamp.toIso8601String(),
  };

  factory PredictionModel.fromJson(Map<String, dynamic> json) =>
      PredictionModel(
        disease:    json['disease']    as String,
        confidence: (json['confidence'] as num).toDouble(),
        crop:       json['crop']       as String,
        timestamp:  DateTime.parse(json['timestamp'] as String),
      );
}

class CropInput {
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double temperature;
  final double humidity;
  final double ph;
  final double rainfall;

  const CropInput({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.temperature,
    required this.humidity,
    required this.ph,
    required this.rainfall,
  });

  List<double> toFeatureVector() => [
    nitrogen, phosphorus, potassium,
    temperature, humidity, ph, rainfall,
  ];
}

class CropResult {
  final String       cropName;
  final double       score;
  final String       season;
  final String       soilType;
  final String       description;
  final List<String> fertilizers;

  const CropResult({
    required this.cropName,
    required this.score,
    required this.season,
    required this.soilType,
    required this.description,
    required this.fertilizers,
  });
}

enum MessageRole { user, assistant }

class ChatMessage {
  final String      id;
  final String      text;
  final MessageRole role;
  final DateTime    timestamp;
  final bool        isVoice;

  ChatMessage({
    required this.text,
    required this.role,
    this.isVoice = false,
    String?   id,
    DateTime? timestamp,
  })  : id        = id        ?? DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  bool get isUser      => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  Map<String, dynamic> toJson() => {
    'id':        id,
    'text':      text,
    'role':      role.name,
    'timestamp': timestamp.toIso8601String(),
    'is_voice':  isVoice,
  };
}

class DiseaseReport {
  final int?     id;
  final String   crop;
  final String   disease;
  final double   confidence;
  final String?  imagePath;
  final DateTime createdAt;
  final bool     synced;

  const DiseaseReport({
    this.id,
    required this.crop,
    required this.disease,
    required this.confidence,
    this.imagePath,
    required this.createdAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'crop':       crop,
    'disease':    disease,
    'confidence': confidence,
    'image_path': imagePath,
    'created_at': createdAt.toIso8601String(),
    'synced':     synced ? 1 : 0,
  };

  factory DiseaseReport.fromMap(Map<String, dynamic> map) => DiseaseReport(
    id:         map['id']          as int?,
    crop:       map['crop']        as String,
    disease:    map['disease']     as String,
    confidence: (map['confidence'] as num).toDouble(),
    imagePath:  map['image_path']  as String?,
    createdAt:  DateTime.parse(map['created_at'] as String),
    synced:     (map['synced']     as int) == 1,
  );

  DiseaseReport copyWith({bool? synced}) => DiseaseReport(
    id:         id,
    crop:       crop,
    disease:    disease,
    confidence: confidence,
    imagePath:  imagePath,
    createdAt:  createdAt,
    synced:     synced ?? this.synced,
  );
}
'@

New-Item -Path "$lib\models" -ItemType Directory -Force | Out-Null
Set-Content -Path "$lib\models\models.dart" -Value $modelsContent -Encoding UTF8
Write-Host "  Fixed: lib\models\models.dart (timestamp now optional)" -ForegroundColor Green

# ── Fix 3: Rewrite voice_services.dart ──────────────────────────
$voiceContent = @'
// lib/services/voice_services.dart
// TTS + STT services for all supported languages.

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

// ── Text To Speech ─────────────────────────────────────────────
class TTSService {
  TTSService._();
  static final TTSService instance = TTSService._();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized   = false;
  bool _isSpeaking      = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(()    { _isSpeaking = true;  });
    _tts.setCompletionHandler(() { _isSpeaking = false; });
    _tts.setErrorHandler((msg)  { _isSpeaking = false; debugPrint('TTS: $msg'); });
    _isInitialized = true;
  }

  Future<void> speak(String text, {String languageCode = 'en'}) async {
    await initialize();
    await stop();
    await _tts.setLanguage(_locale(languageCode));
    await _tts.speak(text);
  }

  Future<void> stop() async {
    if (_isSpeaking) { await _tts.stop(); _isSpeaking = false; }
  }

  static String _locale(String code) => const {
    'en': 'en-IN', 'hi': 'hi-IN', 'pa': 'pa-IN',
    'mr': 'mr-IN', 'te': 'te-IN',
  }[code] ?? 'en-IN';
}

// ── Speech To Text ─────────────────────────────────────────────
class STTService {
  STTService._();
  static final STTService instance = STTService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening   = false;

  bool get isListening   => _isListening;
  bool get isInitialized => _isInitialized;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;
    _isInitialized = await _speech.initialize(
      onError:  (e) { debugPrint('STT error: ${e.errorMsg}'); _isListening = false; },
      onStatus: (s) { if (s == 'done' || s == 'notListening') _isListening = false; },
    );
    return _isInitialized;
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    required void Function()            onListeningStart,
    required void Function()            onListeningStop,
    String languageCode = 'en',
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }
    if (_isListening) return;
    _isListening = true;
    onListeningStart();

    // Compatible with speech_to_text v5 and v6
    // v6 changed onResult to positional — we wrap in a local function
    void handleResult(stt.SpeechRecognitionResult result) {
      if (result.finalResult) {
        onResult(result.recognizedWords);
        _isListening = false;
        onListeningStop();
      }
    }

    try {
      // Try v6 positional API first
      await _speech.listen(
        handleResult,
        localeId:      _locale(languageCode),
        listenMode:    stt.ListenMode.dictation,
        pauseFor:      const Duration(seconds: 3),
        listenFor:     const Duration(seconds: 30),
        cancelOnError: true,
      );
    } catch (_) {
      // Fallback: v5 named API
      await _speech.listen(
        onResult:      handleResult,
        localeId:      _locale(languageCode),
        listenMode:    stt.ListenMode.dictation,
        pauseFor:      const Duration(seconds: 3),
        listenFor:     const Duration(seconds: 30),
        cancelOnError: true,
      );
    }
  }

  Future<void> stopListening() async {
    if (_isListening) { await _speech.stop(); _isListening = false; }
  }

  static String _locale(String code) => const {
    'en': 'en_IN', 'hi': 'hi_IN', 'pa': 'pa_IN',
    'mr': 'mr_IN', 'te': 'te_IN',
  }[code] ?? 'en_IN';
}
'@

New-Item -Path "$lib\services" -ItemType Directory -Force | Out-Null
Set-Content -Path "$lib\services\voice_services.dart" -Value $voiceContent -Encoding UTF8
Write-Host "  Fixed: lib\services\voice_services.dart (STT API v5/v6 compatible)" -ForegroundColor Green

# ── Fix 4: Add missing imports to history_screen.dart ───────────
$historyPath = "$lib\screens\history_screen.dart"
if (Test-Path $historyPath) {
    $hist = Get-Content $historyPath -Raw
    if ($hist -notmatch "package:provider/provider") {
        $hist = $hist -replace "(import 'dart:io';)", "`$1`nimport 'package:flutter/material.dart';`nimport 'package:provider/provider.dart';"
        $hist = $hist -replace "(import '\.\./models/models\.dart';)", "`$1`nimport '../providers/app_provider.dart';"
        Set-Content -Path $historyPath -Value $hist -Encoding UTF8
        Write-Host "  Fixed: lib\screens\history_screen.dart (added provider imports)" -ForegroundColor Green
    } else {
        Write-Host "  OK:    lib\screens\history_screen.dart" -ForegroundColor Gray
    }
}

# ── Done ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "All fixes applied!" -ForegroundColor Green
Write-Host "Now run:" -ForegroundColor Cyan
Write-Host "  flutter clean" -ForegroundColor White
Write-Host "  flutter pub get" -ForegroundColor White
Write-Host "  flutter run" -ForegroundColor White