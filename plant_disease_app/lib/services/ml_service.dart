// ─────────────────────────────────────────────
// services/ml_service.dart
// Runs TFLite models completely on-device.
// Two models:
//   1. Disease detection (image → label)
//   2. Crop recommendation (features → label)
// Both use tflite_flutter ^0.12.1.
// ─────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../core/constants.dart';
import '../models/models.dart';
import 'ml/remedy_service.dart';

class MLService {
  MLService._();
  static final MLService instance = MLService._();

  Interpreter? _diseaseInterpreter;
  Interpreter? _cropInterpreter;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // ── Load both models at app startup ──────────
  Future<void> loadModels() async {
    try {
      _diseaseInterpreter = await Interpreter.fromAsset(
        AppConstants.diseaseModelPath,
      );
      debugPrint('✅ Disease model loaded');

      _cropInterpreter = await Interpreter.fromAsset(
        AppConstants.cropModelPath,
      );
      debugPrint('✅ Crop model loaded');

      _isLoaded = true;
    } catch (e) {
      debugPrint('❌ Failed to load ML models: $e');
      // Non-fatal — app works without models, camera screen shows message
    }
  }

  // ── Disease Detection ─────────────────────────
  /// Takes an image [File], returns a [PredictionModel].
  Future<PredictionModel> detectDisease(File imageFile, {String crop = 'tomato'}) async {
    if (_diseaseInterpreter == null) {
      throw StateError('Disease model not loaded. Call loadModels() first.');
    }

    // 1. Read and pre-process image
    final inputTensor = await _preprocessImage(imageFile);

    // 2. Prepare output buffer — shape: [1, numClasses]
    final numClasses = AppConstants.diseaseLabels.length;
    final output = List.generate(1, (_) => List.filled(numClasses, 0.0));

    // 3. Run inference
    _diseaseInterpreter!.run(inputTensor, output);

    // 4. Find top class
    final scores = output[0];
    int topIndex = 0;
    double topScore = scores[0];
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > topScore) {
        topScore = scores[i];
        topIndex = i;
      }
    }

    final disease = AppConstants.diseaseLabels[topIndex];

    return PredictionModel(
      disease:    disease,
      confidence: topScore,
      crop:       crop,
      remedy:     RemedyService.getRemedy(disease),
      timestamp:  DateTime.now(),
    );
  }

  // ── Crop Recommendation ───────────────────────
  /// Takes a [CropInput], returns ranked list of [CropResult].
  Future<List<String>> recommendCrops(CropInput input) async {
    if (_cropInterpreter == null) {
      throw StateError('Crop model not loaded. Call loadModels() first.');
    }

    // 1. Build float32 input tensor — shape: [1, 7]
    final features = input.toFeatureVector();
    final inputTensor = [
      Float32List.fromList(features)
    ];

    // 2. Get output shape from model
    final outputShape = _cropInterpreter!.getOutputTensor(0).shape;
    final numClasses  = outputShape.last;
    final output      = List.generate(1, (_) => List.filled(numClasses, 0.0));

    // 3. Run inference
    _cropInterpreter!.run(inputTensor, output);

    // 4. Rank by score — return top 3 class indices as strings
    final scores  = output[0];
    final indexed = List.generate(scores.length, (i) => MapEntry(i, scores[i]));
    indexed.sort((a, b) => b.value.compareTo(a.value));

    return indexed.take(3).map((e) => e.key.toString()).toList();
  }

  // ── Image pre-processing ─────────────────────
  Future<List<List<List<List<double>>>>> _preprocessImage(File imageFile) async {
    final bytes    = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) throw Exception('Could not decode image');

    final resized = img.copyResize(
      original,
      width:  AppConstants.modelInputWidth,
      height: AppConstants.modelInputHeight,
    );

    // Shape: [1, H, W, C]
    final inputTensor = List.generate(
      1, (_) => List.generate(
        AppConstants.modelInputHeight, (y) => List.generate(
          AppConstants.modelInputWidth, (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    return inputTensor;
  }

  // ── Cleanup ───────────────────────────────────
  void dispose() {
    _diseaseInterpreter?.close();
    _cropInterpreter?.close();
    _isLoaded = false;
  }
}