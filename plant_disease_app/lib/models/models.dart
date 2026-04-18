import 'dart:math';

enum MessageRole { user, assistant }

// ================= CHAT MESSAGE =================

class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final bool isVoice;

  ChatMessage({
    String? id,
    required this.text,
    required this.role,
    DateTime? timestamp,
    this.isVoice = false,
  })  : id = id ?? Random().nextInt(999999).toString(),
        timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == MessageRole.user;
}

// ================= PREDICTION =================

class PredictionModel {
  final String disease;
  final String crop;
  final double confidence;
  final String remedy;
  final DateTime timestamp;

  PredictionModel({
    required this.disease,
    required this.crop,
    required this.confidence,
    required this.remedy,
    required this.timestamp,
  });

  String get displayName {
  return disease
      .replaceAll("_", " ")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  }

  bool get isHealthy => disease.toLowerCase().contains("healthy");

  bool get isUncertain => confidence < 0.7;
}

// ================= CROP INPUT =================

class CropInput {
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double temperature;
  final double humidity;
  final double ph;
  final double rainfall;

  CropInput({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.temperature,
    required this.humidity,
    required this.ph,
    required this.rainfall,
  });

  List<double> toFeatureVector() {
    return [
      nitrogen,
      phosphorus,
      potassium,
      temperature,
      humidity,
      ph,
      rainfall,
    ];
  }
}

// ================= DISEASE REPORT =================

class DiseaseReport {
  final int? id;
  final String imagePath;
  final String disease;
  final String crop;
  final double confidence;
  final DateTime createdAt;
  final bool synced;

  DiseaseReport({
    this.id,
    required this.imagePath,
    required this.disease,
    required this.crop,
    required this.confidence,
    DateTime? createdAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'disease': disease,
      'crop': crop,
      'confidence': confidence,
      'createdAt': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory DiseaseReport.fromMap(Map<String, dynamic> map) {
    return DiseaseReport(
      id: map['id'],
      imagePath: map['imagePath'],
      disease: map['disease'],
      crop: map['crop'],
      confidence: map['confidence'],
      createdAt: DateTime.parse(map['createdAt']),
      synced: map['synced'] == 1,
    );
  }
}
