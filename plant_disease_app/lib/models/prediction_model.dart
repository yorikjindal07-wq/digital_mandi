// ─────────────────────────────────────────────
// models/prediction_model.dart
// ─────────────────────────────────────────────

class PredictionModel {
  final String disease;
  final double confidence;
  final String crop;
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


// ─────────────────────────────────────────────
// models/crop_model.dart
// ─────────────────────────────────────────────

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

  /// Returns values in the exact order the model expects
  List<double> toFeatureVector() => [
    nitrogen, phosphorus, potassium,
    temperature, humidity, ph, rainfall,
  ];
}

class CropResult {
  final String cropName;
  final double score;
  final String season;
  final String soilType;
  final String description;
  final List<String> fertilizers;

  const CropResult({
    required this.cropName,
    required this.score,
    required this.season,
    required this.soilType,
    required this.description,
    required this.fertilizers,
  });

  factory CropResult.fromJson(Map<String, dynamic> json) => CropResult(
    cropName:    json['crop']        as String,
    score:       (json['score'] as num).toDouble(),
    season:      json['season']      as String,
    soilType:    json['soil_type']   as String,
    description: json['description'] as String,
    fertilizers: List<String>.from(json['fertilizers'] as List),
  );
}


// ─────────────────────────────────────────────
// models/chat_message.dart
// ─────────────────────────────────────────────

enum MessageRole { user, assistant }

class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final bool isVoice;

  ChatMessage({
    required this.text,
    required this.role,
    this.isVoice = false,
    String? id,
    DateTime? timestamp,
  }) : id        = id        ?? DateTime.now().microsecondsSinceEpoch.toString(),
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


// ─────────────────────────────────────────────
// models/disease_report.dart
// Persisted to local database
// ─────────────────────────────────────────────

class DiseaseReport {
  final int?   id;
  final String crop;
  final String disease;
  final double confidence;
  final String? imagePath;
  final DateTime createdAt;
  final bool synced;

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
    id:         map['id']         as int?,
    crop:       map['crop']       as String,
    disease:    map['disease']    as String,
    confidence: (map['confidence'] as num).toDouble(),
    imagePath:  map['image_path'] as String?,
    createdAt:  DateTime.parse(map['created_at'] as String),
    synced:     (map['synced'] as int) == 1,
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