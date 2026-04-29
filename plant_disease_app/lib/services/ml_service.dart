// ═══════════════════════════════════════════════════════════════
// lib/services/ml_service.dart
// TFLite model inference for disease detection and crop recommendation
// Production-grade error handling and fallback mechanisms
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/models.dart';
import '../core/constants.dart';
import 'ml/remedy_service.dart';

class MLService {
  MLService._();
  static final MLService instance = MLService._();

  Interpreter? _diseaseInterpreter;
  Interpreter? _cropInterpreter;
  bool _isInitialized = false;
  String? _lastError;

  bool get isInitialized => _isInitialized;
  bool get isLoaded => _isInitialized;
  bool get isDiseaseModelLoaded => _diseaseInterpreter != null;
  bool get isCropModelLoaded => _cropInterpreter != null;
  String? get lastError => _lastError;

  /// ──────────────────────────────────────────────────────────────
  /// INITIALIZATION
  /// ──────────────────────────────────────────────────────────────

  /// Load both ML models with comprehensive error handling
  Future<bool> loadModels() async {
    try {
      debugPrint('📱 Starting ML model loading...');
      
      // Load disease detection model
      try {
        _diseaseInterpreter = await Interpreter.fromAsset(
          AppConstants.diseaseModelPath,
        );
        debugPrint('✅ Disease detection model loaded');
      } catch (e) {
        debugPrint('❌ Disease model error: $e');
        _lastError = 'Disease model: $e';
      }

      // Load crop recommendation model
      try {
        _cropInterpreter = await Interpreter.fromAsset(
          AppConstants.cropModelPath,
        );
        debugPrint('✅ Crop recommendation model loaded');
      } catch (e) {
        debugPrint('❌ Crop model error: $e');
        _lastError = 'Crop model: $e';
      }

      // Mark as initialized if at least one model loaded
      _isInitialized = _diseaseInterpreter != null || _cropInterpreter != null;
      
      if (_isInitialized) {
        debugPrint('✅ ML Service initialized successfully');
      } else {
        debugPrint('❌ ML Service failed to initialize');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('🔥 Critical ML initialization error: $e');
      _lastError = 'Initialization failed: $e';
      _isInitialized = false;
      return false;
    }
  }

  /// ──────────────────────────────────────────────────────────────
  /// DISEASE DETECTION
  /// ──────────────────────────────────────────────────────────────

  /// Detect disease from image file
  /// Returns PredictionModel with disease, confidence, and remedy
  Future<PredictionModel> detectDisease(
    File imageFile, {
    String crop = 'tomato',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      // Validate inputs
      if (_diseaseInterpreter == null) {
        throw AppException(
          message: 'Disease model not loaded. Call loadModels() first.',
          code: 'MODEL_NOT_LOADED',
        );
      }

      if (!await imageFile.exists()) {
        throw AppException(
          message: 'Image file not found',
          code: 'FILE_NOT_FOUND',
        );
      }

      final inputMeta = _diseaseInterpreter!.getInputTensor(0);
      final outputMeta = _diseaseInterpreter!.getOutputTensor(0);

      debugPrint(
        '🧠 Disease model input: shape=${inputMeta.shape}, type=${inputMeta.type}',
      );
      debugPrint(
        '🧠 Disease model output: shape=${outputMeta.shape}, type=${outputMeta.type}',
      );

      // Pre-process image with timeout
      debugPrint('🖼️  Processing image: ${imageFile.path}');
      final inputTensor =
          await _preprocessImage(imageFile, inputMeta).timeout(timeout);

      // Prepare output tensor
      final output = _createOutputBuffer(outputMeta.shape, outputMeta.type);

      // Run inference
      debugPrint('🧠 Running disease inference...');
      _diseaseInterpreter!.run(inputTensor, output);

      // Find top prediction
      final scores = _flattenOutputScores(output, outputMeta);
      if (scores.isEmpty) {
        throw AppException(
          message: 'Disease model returned no output scores.',
          code: 'EMPTY_OUTPUT',
        );
      }

      if (scores.length != AppConstants.diseaseLabels.length) {
        throw AppException(
          message:
              'Disease model output has ${scores.length} classes, but the app expects ${AppConstants.diseaseLabels.length} labels.',
          code: 'LABEL_MISMATCH',
        );
      }

      int topIndex = 0;
      double topScore = scores[0];
      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > topScore) {
          topScore = scores[i];
          topIndex = i;
        }
      }

      // Clamp confidence to valid range
      final confidence = topScore.clamp(0.0, 1.0);
      final disease = AppConstants.diseaseLabels[topIndex];
      final remedy = RemedyService.getRemedy(disease);

      debugPrint('✅ Prediction: $disease (${(confidence * 100).toStringAsFixed(1)}%)');

      return PredictionModel(
        disease: disease,
        confidence: confidence,
        crop: crop,
        remedy: remedy,
        timestamp: DateTime.now(),
      );
    } on AppException catch (e) {
      debugPrint('⚠️  Validation error: $e');
      rethrow;
    } catch (e) {
      debugPrint('🔥 Inference error: $e');
      throw AppException(
        message: 'Disease detection failed',
        code: 'INFERENCE_ERROR',
        originalException: e,
      );
    }
  }

  /// ──────────────────────────────────────────────────────────────
  /// CROP RECOMMENDATION
  /// ──────────────────────────────────────────────────────────────

  /// Recommend crops based on soil and climate parameters
  /// Returns list of top 3 recommended crop indices
  Future<List<String>> recommendCrops(
    CropInput input, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      // Validate inputs
      if (_cropInterpreter == null) {
        throw AppException(
          message: 'Crop model not loaded',
          code: 'MODEL_NOT_LOADED',
        );
      }

      final validationError = input.getValidationError();
      if (validationError.isNotEmpty) {
        throw ValidationException(message: validationError);
      }

      debugPrint('🌾 Processing crop recommendation...');

      // Build input tensor
      final features = input.toFeatureVector();
      final inputTensor = [Float32List.fromList(features)];

      // Get output shape
      final outputTensor = _cropInterpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      final numClasses = outputShape.isNotEmpty ? outputShape.last : 22;

      // Prepare output buffer
      final output = List.generate(1, (_) => List.filled(numClasses, 0.0));

      // Run inference with timeout
      debugPrint('🧠 Running crop inference...');
      await Future.delayed(Duration.zero).timeout(timeout);
      _cropInterpreter!.run(inputTensor, output);

      // Get top 3 crops
      final scores = output[0];
      final indexed = List.generate(
        scores.length,
        (i) => MapEntry(i, scores[i]),
      );
      indexed.sort((a, b) => b.value.compareTo(a.value));

      final topCrops = indexed
          .take(3)
          .map((e) => AppConstants.cropLabels[e.key % AppConstants.cropLabels.length])
          .toList();

      debugPrint('✅ Top crops: $topCrops');
      return topCrops;
    } on ValidationException catch (e) {
      debugPrint('⚠️  Validation error: $e');
      rethrow;
    } catch (e) {
      debugPrint('🔥 Crop inference error: $e');
      throw AppException(
        message: 'Crop recommendation failed',
        code: 'INFERENCE_ERROR',
        originalException: e,
      );
    }
  }

  /// ──────────────────────────────────────────────────────────────
  /// IMAGE PRE-PROCESSING
  /// ──────────────────────────────────────────────────────────────

  /// Pre-process image for disease detection model
  /// Returns a tensor object matching the model's declared input shape and type.
  Future<Object> _preprocessImage(
    File imageFile,
    Tensor inputTensor,
  ) async {
    try {
      debugPrint('🖼️  Reading image from: ${imageFile.path}');
      final bytes = await imageFile.readAsBytes();

      // Decode image
      final original = img.decodeImage(bytes);
      if (original == null) {
        throw AppException(
          message: 'Could not decode image',
          code: 'IMAGE_DECODE_ERROR',
        );
      }

      debugPrint('📐 Original size: ${original.width}x${original.height}');

      final config = _resolveImageTensorConfig(inputTensor);

      // Resize to model input size
      final resized = img.copyResize(
        original,
        width: config.width,
        height: config.height,
        interpolation: img.Interpolation.linear,
      );

      final tensor = config.channelsFirst
          ? [
              List.generate(
                config.channels,
                (channel) => List.generate(
                  config.height,
                  (y) => List.generate(
                    config.width,
                    (x) => _convertPixelValue(
                      resized.getPixelSafe(x, y),
                      channel,
                      config.channels,
                      inputTensor,
                    ),
                  ),
                ),
              ),
            ]
          : [
              List.generate(
                config.height,
                (y) => List.generate(
                  config.width,
                  (x) => List.generate(
                    config.channels,
                    (channel) => _convertPixelValue(
                      resized.getPixelSafe(x, y),
                      channel,
                      config.channels,
                      inputTensor,
                    ),
                  ),
                ),
              ),
            ];

      debugPrint(
        '✅ Image preprocessed for shape=${inputTensor.shape}, type=${inputTensor.type}',
      );
      return tensor;
    } catch (e) {
      debugPrint('🔥 Preprocessing error: $e');
      throw AppException(
        message: 'Image preprocessing failed',
        code: 'PREPROCESS_ERROR',
        originalException: e,
      );
    }
  }

  /// ──────────────────────────────────────────────────────────────
  /// CLEANUP
  /// ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    try {
      _diseaseInterpreter?.close();
      _cropInterpreter?.close();
      _isInitialized = false;
      debugPrint('✅ ML Service disposed');
    } catch (e) {
      debugPrint('⚠️  Error disposing ML Service: $e');
    }
  }

  _ImageTensorConfig _resolveImageTensorConfig(Tensor tensor) {
    final shape = tensor.shape;
    if (shape.length != 4 || shape.first != 1) {
      throw AppException(
        message: 'Unsupported disease model input shape: $shape',
        code: 'UNSUPPORTED_INPUT_SHAPE',
      );
    }

    final channelsLast = shape[3] >= 1 && shape[3] <= 4;
    final channelsFirst = shape[1] >= 1 && shape[1] <= 4;

    if (!channelsLast && !channelsFirst) {
      throw AppException(
        message: 'Cannot infer channel placement from disease model shape: $shape',
        code: 'UNSUPPORTED_INPUT_SHAPE',
      );
    }

    if (channelsLast) {
      return _ImageTensorConfig(
        width: shape[2],
        height: shape[1],
        channels: shape[3],
        channelsFirst: false,
      );
    }

    return _ImageTensorConfig(
      width: shape[3],
      height: shape[2],
      channels: shape[1],
      channelsFirst: true,
    );
  }

  Object _convertPixelValue(
    img.Pixel pixel,
    int channel,
    int channelCount,
    Tensor inputTensor,
  ) {
    final rawValue = _rawChannelValue(pixel, channel, channelCount);

    switch (inputTensor.type) {
      case TensorType.float32:
        return rawValue / 255.0;
      case TensorType.uint8:
        if (inputTensor.params.scale > 0) {
          final quantized =
              ((rawValue / 255.0) / inputTensor.params.scale + inputTensor.params.zeroPoint)
                  .round();
          return quantized.clamp(0, 255);
        }
        return rawValue.clamp(0, 255);
      case TensorType.int8:
        if (inputTensor.params.scale > 0) {
          final quantized =
              ((rawValue / 255.0) / inputTensor.params.scale + inputTensor.params.zeroPoint)
                  .round();
          return quantized.clamp(-128, 127);
        }
        return (rawValue - 128).clamp(-128, 127);
      default:
        throw AppException(
          message:
              'Unsupported disease model input tensor type: ${inputTensor.type}',
          code: 'UNSUPPORTED_INPUT_TYPE',
        );
    }
  }

  int _rawChannelValue(img.Pixel pixel, int channel, int channelCount) {
    if (channelCount == 1) {
      return ((pixel.r + pixel.g + pixel.b) / 3).round();
    }

    switch (channel) {
      case 0:
        return pixel.r.toInt();
      case 1:
        return pixel.g.toInt();
      case 2:
        return pixel.b.toInt();
      case 3:
        return 255;
      default:
        return 0;
    }
  }

  Object _createOutputBuffer(List<int> shape, TensorType type) {
    if (shape.isEmpty) {
      throw AppException(
        message: 'Unsupported scalar disease model output shape.',
        code: 'UNSUPPORTED_OUTPUT_SHAPE',
      );
    }

    Object build(int dimension) {
      final length = shape[dimension];
      if (dimension == shape.length - 1) {
        return List.generate(length, (_) => _zeroValueForTensorType(type));
      }

      return List.generate(length, (_) => build(dimension + 1));
    }

    return build(0);
  }

  Object _zeroValueForTensorType(TensorType type) {
    switch (type) {
      case TensorType.float32:
        return 0.0;
      case TensorType.uint8:
      case TensorType.int8:
      case TensorType.int16:
      case TensorType.int32:
      case TensorType.int64:
        return 0;
      default:
        throw AppException(
          message: 'Unsupported disease model output tensor type: $type',
          code: 'UNSUPPORTED_OUTPUT_TYPE',
        );
    }
  }

  List<double> _flattenOutputScores(Object output, Tensor outputTensor) {
    final values = <double>[];

    void collect(Object? node) {
      if (node is List) {
        for (final item in node) {
          collect(item);
        }
        return;
      }

      if (node is num) {
        switch (outputTensor.type) {
          case TensorType.uint8:
          case TensorType.int8:
          case TensorType.int16:
          case TensorType.int32:
          case TensorType.int64:
            if (outputTensor.params.scale > 0) {
              values.add(
                (node.toDouble() - outputTensor.params.zeroPoint) *
                    outputTensor.params.scale,
              );
            } else {
              values.add(node.toDouble());
            }
            return;
          default:
            values.add(node.toDouble());
            return;
        }
      }
    }

    collect(output);
    return values;
  }
}

class _ImageTensorConfig {
  const _ImageTensorConfig({
    required this.width,
    required this.height,
    required this.channels,
    required this.channelsFirst,
  });

  final int width;
  final int height;
  final int channels;
  final bool channelsFirst;
}
