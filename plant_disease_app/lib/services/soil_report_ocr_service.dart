import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class SoilReportOcrService {
  SoilReportOcrService._();

  static final SoilReportOcrService instance = SoilReportOcrService._();

  Future<SoilReportOcrResult> analyzeReportImage(File imageFile) async {
    final textRecognizer = TextRecognizer();

    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognized = await textRecognizer.processImage(inputImage);
      final rawText = recognized.text.replaceAll(',', '.');
      final values = _extractValues(rawText);

      return SoilReportOcrResult(
        rawText: rawText,
        previewText: _buildPreviewText(rawText),
        values: values,
      );
    } finally {
      await textRecognizer.close();
    }
  }

  Map<String, double> _extractValues(String rawText) {
    final values = <String, double>{};

    for (final entry in _patterns.entries) {
      final value = _firstMatch(rawText, entry.value);
      if (value != null) {
        values[entry.key] = value;
      }
    }

    return values;
  }

  double? _firstMatch(String rawText, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(rawText);
      if (match == null) {
        continue;
      }

      final group = match.group(1);
      final parsed = group == null ? null : double.tryParse(group);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  String _buildPreviewText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(12)
        .toList();

    return lines.join('\n');
  }

  static String prettyLabel(String key) {
    switch (key) {
      case 'nitrogen':
        return 'Nitrogen';
      case 'phosphorus':
        return 'Phosphorus';
      case 'potassium':
        return 'Potassium';
      case 'ph':
        return 'pH';
      case 'ec':
        return 'EC';
      case 'organicCarbon':
        return 'Organic Carbon';
      case 'sulphur':
        return 'Sulphur';
      case 'zinc':
        return 'Zinc';
      case 'iron':
        return 'Iron';
      case 'manganese':
        return 'Manganese';
      case 'copper':
        return 'Copper';
      case 'boron':
        return 'Boron';
      default:
        return key;
    }
  }
}

class SoilReportOcrResult {
  const SoilReportOcrResult({
    required this.rawText,
    required this.previewText,
    required this.values,
  });

  final String rawText;
  final String previewText;
  final Map<String, double> values;
}

final Map<String, List<RegExp>> _patterns = {
  'nitrogen': [
    RegExp(
      r'^\s*(?:nitrogen|n)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(r'\bnitrogen\b[^\d]{0,12}(\d+(?:\.\d+)?)', caseSensitive: false),
  ],
  'phosphorus': [
    RegExp(
      r'^\s*(?:phosphorus|phosphorous|p)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(
      r'\bphosph(?:o)?rus\b[^\d]{0,12}(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ),
  ],
  'potassium': [
    RegExp(
      r'^\s*(?:potassium|k)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(r'\bpotassium\b[^\d]{0,12}(\d+(?:\.\d+)?)', caseSensitive: false),
  ],
  'ph': [
    RegExp(
      r'^\s*(?:soil\s*)?ph\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(r'\bph\b[^\d]{0,8}(\d+(?:\.\d+)?)', caseSensitive: false),
  ],
  'ec': [
    RegExp(
      r'^\s*(?:ec|electrical conductivity)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(r'\bec\b[^\d]{0,8}(\d+(?:\.\d+)?)', caseSensitive: false),
  ],
  'organicCarbon': [
    RegExp(
      r'^\s*(?:organic carbon|oc)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(
      r'\borganic carbon\b[^\d]{0,12}(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ),
  ],
  'sulphur': [
    RegExp(
      r'^\s*(?:sulphur|sulfur|s)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(
      r'\bsul(?:ph|f)ur\b[^\d]{0,12}(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ),
  ],
  'zinc': [
    RegExp(
      r'^\s*(?:zinc|zn)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(r'\bzinc\b[^\d]{0,12}(\d+(?:\.\d+)?)', caseSensitive: false),
  ],
  'iron': [
    RegExp(
      r'^\s*(?:iron|fe)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(r'\biron\b[^\d]{0,12}(\d+(?:\.\d+)?)', caseSensitive: false),
  ],
  'manganese': [
    RegExp(
      r'^\s*(?:manganese|mn)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(r'\bmanganese\b[^\d]{0,12}(\d+(?:\.\d+)?)', caseSensitive: false),
  ],
  'copper': [
    RegExp(
      r'^\s*(?:copper|cu)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(r'\bcopper\b[^\d]{0,12}(\d+(?:\.\d+)?)', caseSensitive: false),
  ],
  'boron': [
    RegExp(
      r'^\s*(?:boron|bo|b)\s*[:=-]?\s*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
      multiLine: true,
    ),
    RegExp(r'\bboron\b[^\d]{0,12}(\d+(?:\.\d+)?)', caseSensitive: false),
  ],
};
