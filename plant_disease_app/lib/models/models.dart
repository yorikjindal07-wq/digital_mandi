// ═══════════════════════════════════════════════════════════════
// lib/models/models.dart
// Complete data models for the Digital Mandi app
// ═══════════════════════════════════════════════════════════════

export 'weather_model.dart' show WeatherData;

/// ──────────────────────────────────────────────────────────────
/// MESSAGE ROLES AND CHAT
/// ──────────────────────────────────────────────────────────────

enum MessageRole { user, assistant }

class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final bool isVoice;
  // final String language;

  ChatMessage({
    String? id,
    required this.text,
    required this.role,
    DateTime? timestamp,
    this.isVoice = false,
    // this.language = 'en',
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
      'is_voice': isVoice ? 1 : 0,
      // 'language': language,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      role: MessageRole.values.byName(map['role'] as String? ?? 'user'),
      timestamp: DateTime.parse(map['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      isVoice: (map['is_voice'] as int? ?? 0) == 1,
      // language: map['language'] as String? ?? 'en',
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// DISEASE DETECTION & PREDICTION
/// ──────────────────────────────────────────────────────────────

class PredictionModel {
  final String disease;
  final String crop;
  final double confidence;
  final String remedy;
  final DateTime timestamp;
  final String? imageBase64;

  PredictionModel({
    required this.disease,
    required this.crop,
    required this.confidence,
    required this.remedy,
    DateTime? timestamp,
    this.imageBase64,
  }) : timestamp = timestamp ?? DateTime.now();

  String get displayName {
    return disease
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  bool get isHealthy => disease.toLowerCase().contains('healthy');
  bool get isUncertain => confidence < 0.70;
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  Map<String, dynamic> toJson() => {
    'disease': disease,
    'crop': crop,
    'confidence': confidence,
    'remedy': remedy,
    'timestamp': timestamp.toIso8601String(),
    'image_base64': imageBase64,
  };

  factory PredictionModel.fromJson(Map<String, dynamic> json) => PredictionModel(
    disease: json['disease'] as String,
    crop: json['crop'] as String,
    confidence: (json['confidence'] as num).toDouble(),
    remedy: json['remedy'] as String? ?? '',
    timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'] as String) 
        : DateTime.now(),
    imageBase64: json['image_base64'] as String?,
  );
}

/// ──────────────────────────────────────────────────────────────
/// CROP RECOMMENDATION
/// ──────────────────────────────────────────────────────────────

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

  /// Returns feature vector in exact order expected by ML model
  List<double> toFeatureVector() => [
    nitrogen,
    phosphorus,
    potassium,
    temperature,
    humidity,
    ph,
    rainfall,
  ];

  /// Validates input ranges (prevent NaN)
  bool isValid() {
    return nitrogen >= 0 && nitrogen <= 140 &&
        phosphorus >= 0 && phosphorus <= 145 &&
        potassium >= 0 && potassium <= 205 &&
        temperature >= -50 && temperature <= 60 &&
        humidity >= 0 && humidity <= 100 &&
        ph >= 3.0 && ph <= 10.0 &&
        rainfall >= 0 && rainfall <= 500;
  }

  String getValidationError() {
    if (nitrogen < 0 || nitrogen > 140) return 'Nitrogen must be 0-140';
    if (phosphorus < 0 || phosphorus > 145) return 'Phosphorus must be 0-145';
    if (potassium < 0 || potassium > 205) return 'Potassium must be 0-205';
    if (temperature < -50 || temperature > 60) return 'Temperature must be -50 to 60°C';
    if (humidity < 0 || humidity > 100) return 'Humidity must be 0-100%';
    if (ph < 3.0 || ph > 10.0) return 'pH must be 3.0-10.0';
    if (rainfall < 0 || rainfall > 500) return 'Rainfall must be 0-500mm';
    return '';
  }
}

class CropResult {
  final String cropName;
  final double score;
  final String season;
  final String soilType;
  final String description;
  final List<String> fertilizers;
  final String emoji;

  const CropResult({
    required this.cropName,
    required this.score,
    required this.season,
    required this.soilType,
    required this.description,
    required this.fertilizers,
    required this.emoji,
  });

  factory CropResult.fromJson(Map<String, dynamic> json) => CropResult(
    cropName: json['crop_name'] as String,
    score: (json['score'] as num).toDouble(),
    season: json['season'] as String,
    soilType: json['soil_type'] as String,
    description: json['description'] as String,
    fertilizers: List<String>.from(json['fertilizers'] as List? ?? []),
    emoji: json['emoji'] as String? ?? '🌾',
  );
}

/// ──────────────────────────────────────────────────────────────
/// DISEASE REPORT (PERSISTENT TO DATABASE)
/// ──────────────────────────────────────────────────────────────

class DiseaseReport {
  final int? id;
  final String crop;
  final String disease;
  final double confidence;
  final String? imagePath;
  final DateTime createdAt;
  final bool synced;
  final int syncAttempts;

  DiseaseReport({
    this.id,
    required this.crop,
    required this.disease,
    required this.confidence,
    this.imagePath,
    DateTime? createdAt,
    this.synced = false,
    this.syncAttempts = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'crop': crop,
      'disease': disease,
      'confidence': confidence,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'sync_attempts': syncAttempts,
    };
  }

  factory DiseaseReport.fromMap(Map<String, dynamic> map) {
    return DiseaseReport(
      id: map['id'] as int?,
      crop: map['crop'] as String,
      disease: map['disease'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      imagePath: map['image_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: (map['synced'] as int?) == 1,
      syncAttempts: map['sync_attempts'] as int? ?? 0,
    );
  }

  DiseaseReport copyWith({
    int? id,
    String? crop,
    String? disease,
    double? confidence,
    String? imagePath,
    DateTime? createdAt,
    bool? synced,
    int? syncAttempts,
  }) {
    return DiseaseReport(
      id: id ?? this.id,
      crop: crop ?? this.crop,
      disease: disease ?? this.disease,
      confidence: confidence ?? this.confidence,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      syncAttempts: syncAttempts ?? this.syncAttempts,
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// API RESPONSE MODELS
/// ──────────────────────────────────────────────────────────────

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final String? error;

  ApiResponse({
    required this.success,
    this.data,
    required this.message,
    this.error,
  });

  factory ApiResponse.success({required T data, String message = 'Success'}) {
    return ApiResponse(
      success: true,
      data: data,
      message: message,
    );
  }

  factory ApiResponse.error({required String error, String message = 'Error'}) {
    return ApiResponse(
      success: false,
      message: message,
      error: error,
    );
  }

  factory ApiResponse.fromJson(Map<String, dynamic> json, Function(dynamic) fromJsonT) {
    return ApiResponse(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      message: json['message'] as String? ?? '',
      error: json['error'] as String?,
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// SYNC STATUS & CONNECTIVITY
/// ──────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, failed, offline, partialSuccess }

class SyncResult {
  final SyncStatus status;
  final int totalItems;
  final int successCount;
  final int failureCount;
  final List<String> errors;
  final DateTime timestamp;

  SyncResult({
    required this.status,
    required this.totalItems,
    this.successCount = 0,
    this.failureCount = 0,
    this.errors = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isSuccessful => status == SyncStatus.success || status == SyncStatus.partialSuccess;
  double get successRate => totalItems == 0 ? 0 : (successCount / totalItems);

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'total_items': totalItems,
    'success_count': successCount,
    'failure_count': failureCount,
    'errors': errors,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// ──────────────────────────────────────────────────────────────
/// EXCEPTION MODELS
/// ──────────────────────────────────────────────────────────────

class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  AppException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() => 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

class NetworkException extends AppException {
  NetworkException({String? message})
      : super(
          message: message ?? 'Network error occurred',
          code: 'NETWORK_ERROR',
        );
}

class ValidationException extends AppException {
  ValidationException({String? message})
      : super(
          message: message ?? 'Validation failed',
          code: 'VALIDATION_ERROR',
        );
}

class SyncException extends AppException {
  final List<String> failedItems;

  SyncException({
    String? message,
    this.failedItems = const [],
  }) : super(
    message: message ?? 'Sync failed',
    code: 'SYNC_ERROR',
  );
}
