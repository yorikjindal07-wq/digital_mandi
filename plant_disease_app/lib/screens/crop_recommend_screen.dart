import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/ml_service.dart';
import '../services/soil_report_ocr_service.dart';

const Map<String, Map<String, dynamic>> _cropDatabase = {
  'rice': {
    'emoji': '🌾',
    'season': 'Kharif (Jun-Nov)',
    'soil': 'Clay loam',
    'minTemp': 20.0,
    'maxTemp': 35.0,
    'minRain': 100.0,
    'minPh': 5.5,
    'maxPh': 7.0,
    'desc': 'Water-loving crop with high nitrogen demand.',
    'fertilizers': ['DAP 50 kg/acre', 'Urea 40 kg/acre', 'MOP 25 kg/acre'],
  },
  'wheat': {
    'emoji': '🌿',
    'season': 'Rabi (Oct-Mar)',
    'soil': 'Loamy',
    'minTemp': 12.0,
    'maxTemp': 25.0,
    'minRain': 25.0,
    'minPh': 6.0,
    'maxPh': 7.5,
    'desc': 'Cool-season crop with moderate water need.',
    'fertilizers': ['DAP 50 kg/acre', 'Urea 55 kg/acre'],
  },
  'maize': {
    'emoji': '🌽',
    'season': 'Kharif / Rabi',
    'soil': 'Well-drained loam',
    'minTemp': 18.0,
    'maxTemp': 32.0,
    'minRain': 50.0,
    'minPh': 5.8,
    'maxPh': 7.2,
    'desc': 'Fast-growing crop with strong yield potential.',
    'fertilizers': ['NPK 12:32:16 @ 50 kg', 'Urea 45 kg/acre'],
  },
  'cotton': {
    'emoji': '🌸',
    'season': 'Kharif (Apr-Nov)',
    'soil': 'Black cotton soil',
    'minTemp': 20.0,
    'maxTemp': 38.0,
    'minRain': 50.0,
    'minPh': 6.0,
    'maxPh': 8.0,
    'desc': 'Cash crop that does well in deeper black soils.',
    'fertilizers': ['DAP 35 kg/acre', 'Potash 25 kg/acre'],
  },
  'sugarcane': {
    'emoji': '🎋',
    'season': 'Year-round',
    'soil': 'Loam / Clay loam',
    'minTemp': 20.0,
    'maxTemp': 35.0,
    'minRain': 75.0,
    'minPh': 6.0,
    'maxPh': 8.0,
    'desc': 'Long-duration crop with high water requirement.',
    'fertilizers': ['Urea 100 kg/acre', 'SSP 100 kg/acre', 'MOP 50 kg/acre'],
  },
  'tomato': {
    'emoji': '🍅',
    'season': 'All seasons (with irrigation)',
    'soil': 'Sandy loam',
    'minTemp': 18.0,
    'maxTemp': 30.0,
    'minRain': 40.0,
    'minPh': 6.0,
    'maxPh': 7.0,
    'desc': 'High-value vegetable that needs good drainage.',
    'fertilizers': ['NPK 19:19:19 @ 4g/L', 'CaNO3 spray after fruiting'],
  },
  'potato': {
    'emoji': '🥔',
    'season': 'Rabi (Oct-Mar)',
    'soil': 'Sandy loam',
    'minTemp': 15.0,
    'maxTemp': 25.0,
    'minRain': 50.0,
    'minPh': 5.0,
    'maxPh': 6.5,
    'desc': 'Cool-season crop that responds well to balanced fertility.',
    'fertilizers': ['DAP 50 kg/acre', 'MOP 50 kg/acre', 'Urea 35 kg/acre'],
  },
  'chickpea': {
    'emoji': '🫘',
    'season': 'Rabi (Oct-Feb)',
    'soil': 'Well-drained loam',
    'minTemp': 10.0,
    'maxTemp': 25.0,
    'minRain': 20.0,
    'minPh': 6.0,
    'maxPh': 8.0,
    'desc': 'Nitrogen-fixing legume with lower water demand.',
    'fertilizers': ['DAP 25 kg/acre at sowing', 'Rhizobium seed treatment'],
  },
};

const List<_GovernmentHelpItem> _governmentHelpItems = [
  _GovernmentHelpItem(
    title: 'Nearest soil testing lab',
    detail:
        'Use the official Soil Health Card lab finder to search your nearest lab by district or location.',
    value: 'https://soilhealth.dac.gov.in/soil-lab',
    copyLabel: 'Copy lab finder',
    icon: Icons.location_on_outlined,
  ),
  _GovernmentHelpItem(
    title: 'Track or download report',
    detail:
        'Track the sample and download the Soil Health Card by mobile number when the test is ready.',
    value: 'https://soilhealth.dac.gov.in/print-shc',
    copyLabel: 'Copy tracking link',
    icon: Icons.description_outlined,
  ),
  _GovernmentHelpItem(
    title: 'Government helpline',
    detail:
        'Kisan Call Centre toll-free support for soil, crop, and farming guidance.',
    value: '1800-180-1551 (6:00 AM - 10:00 PM)',
    copyLabel: 'Copy helpline',
    icon: Icons.support_agent_outlined,
  ),
];

class CropRecommendScreen extends StatefulWidget {
  const CropRecommendScreen({super.key});

  @override
  State<CropRecommendScreen> createState() => _CropRecommendScreenState();
}

class _CropRecommendScreenState extends State<CropRecommendScreen> {
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nitrogenController = TextEditingController(
    text: '50',
  );
  final TextEditingController _phosphorusController = TextEditingController(
    text: '40',
  );
  final TextEditingController _potassiumController = TextEditingController(
    text: '40',
  );
  final TextEditingController _phController = TextEditingController(
    text: '6.5',
  );
  final TextEditingController _ecController = TextEditingController(
    text: '0.6',
  );
  final TextEditingController _organicCarbonController = TextEditingController(
    text: '0.6',
  );
  final TextEditingController _sulphurController = TextEditingController(
    text: '12',
  );
  final TextEditingController _zincController = TextEditingController(
    text: '0.8',
  );
  final TextEditingController _ironController = TextEditingController(
    text: '6',
  );
  final TextEditingController _manganeseController = TextEditingController(
    text: '3',
  );
  final TextEditingController _copperController = TextEditingController(
    text: '0.4',
  );
  final TextEditingController _boronController = TextEditingController(
    text: '0.7',
  );

  double _temperature = 25;
  double _humidity = 60;
  double _rainfall = 60;

  File? _reportImage;
  bool _isReadingReport = false;
  bool _isLoading = false;
  bool _showAdvancedValues = false;
  String? _reportStatus;
  String? _recognizedPreview;
  Map<String, double> _extractedValues = const {};
  List<_CropRecommendation>? _results;
  List<_SoilHealthFinding>? _soilAnalysis;

  @override
  void dispose() {
    _nitrogenController.dispose();
    _phosphorusController.dispose();
    _potassiumController.dispose();
    _phController.dispose();
    _ecController.dispose();
    _organicCarbonController.dispose();
    _sulphurController.dispose();
    _zincController.dispose();
    _ironController.dispose();
    _manganeseController.dispose();
    _copperController.dispose();
    _boronController.dispose();
    super.dispose();
  }

  Future<void> _copyValue(String label, String value) async {
    final lang = context.read<AppProvider>().languageCode;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_cropDynamicText(lang, 'copied', label: label))),
    );
  }

  Future<void> _pickReportImage(ImageSource source) async {
    final lang = context.read<AppProvider>().languageCode;
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _reportImage = File(picked.path);
      _reportStatus = _cropText(
        lang,
        'Report photo selected. Tap analyze to read values.',
      );
      _recognizedPreview = null;
      _extractedValues = const {};
    });
  }

  Future<void> _analyzeReportPhoto() async {
    if (_reportImage == null) {
      return;
    }
    final lang = context.read<AppProvider>().languageCode;

    setState(() {
      _isReadingReport = true;
      _reportStatus = _cropText(lang, 'Reading report photo...');
    });

    try {
      final result = await SoilReportOcrService.instance.analyzeReportImage(
        _reportImage!,
      );

      if (!mounted) {
        return;
      }

      _applyOcrValues(result.values);
      setState(() {
        _recognizedPreview = result.previewText;
        _extractedValues = result.values;
        _reportStatus = result.values.isEmpty
            ? _cropText(
                lang,
                'Photo read completed, but values were not detected clearly. Please review and enter manually.',
              )
            : _cropDynamicText(
                lang,
                'filled_values',
                count: result.values.length,
              );
        if (result.values.length >= 5) {
          _showAdvancedValues = true;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _reportStatus = _cropText(
          lang,
          'Could not read the report photo clearly. Please retake the photo or enter values manually.',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cropDynamicText(lang, 'photo_failed', error: error.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isReadingReport = false;
        });
      }
    }
  }

  void _applyOcrValues(Map<String, double> values) {
    _setControllerIfFound(_nitrogenController, values['nitrogen']);
    _setControllerIfFound(_phosphorusController, values['phosphorus']);
    _setControllerIfFound(_potassiumController, values['potassium']);
    _setControllerIfFound(_phController, values['ph'], decimals: 1);
    _setControllerIfFound(_ecController, values['ec'], decimals: 1);
    _setControllerIfFound(
      _organicCarbonController,
      values['organicCarbon'],
      decimals: 2,
    );
    _setControllerIfFound(_sulphurController, values['sulphur'], decimals: 1);
    _setControllerIfFound(_zincController, values['zinc'], decimals: 2);
    _setControllerIfFound(_ironController, values['iron'], decimals: 1);
    _setControllerIfFound(
      _manganeseController,
      values['manganese'],
      decimals: 1,
    );
    _setControllerIfFound(_copperController, values['copper'], decimals: 2);
    _setControllerIfFound(_boronController, values['boron'], decimals: 2);
  }

  void _setControllerIfFound(
    TextEditingController controller,
    double? value, {
    int decimals = 0,
  }) {
    if (value == null) {
      return;
    }

    controller.text = decimals == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(decimals);
  }

  Future<void> _getRecommendation() async {
    final lang = context.read<AppProvider>().languageCode;
    final nitrogen = _readField(
      controller: _nitrogenController,
      label: _soilFieldLabel(
        context.read<AppProvider>().l10n,
        lang,
        'nitrogen',
      ),
      fallback: 50,
    );
    final phosphorus = _readField(
      controller: _phosphorusController,
      label: _soilFieldLabel(
        context.read<AppProvider>().l10n,
        lang,
        'phosphorus',
      ),
      fallback: 40,
    );
    final potassium = _readField(
      controller: _potassiumController,
      label: _soilFieldLabel(
        context.read<AppProvider>().l10n,
        lang,
        'potassium',
      ),
      fallback: 40,
    );
    final soilPh = _readField(
      controller: _phController,
      label: _soilFieldLabel(context.read<AppProvider>().l10n, lang, 'ph'),
      fallback: 6.5,
    );
    final soilEc = _readField(
      controller: _ecController,
      label: _soilFieldLabel(context.read<AppProvider>().l10n, lang, 'ec'),
      fallback: 0.6,
    );
    final organicCarbon = _readField(
      controller: _organicCarbonController,
      label: _soilFieldLabel(
        context.read<AppProvider>().l10n,
        lang,
        'organicCarbon',
      ),
      fallback: 0.6,
    );
    final sulphur = _readField(
      controller: _sulphurController,
      label: _soilFieldLabel(context.read<AppProvider>().l10n, lang, 'sulphur'),
      fallback: 12,
    );
    final zinc = _readField(
      controller: _zincController,
      label: _soilFieldLabel(context.read<AppProvider>().l10n, lang, 'zinc'),
      fallback: 0.8,
    );
    final iron = _readField(
      controller: _ironController,
      label: _soilFieldLabel(context.read<AppProvider>().l10n, lang, 'iron'),
      fallback: 6,
    );
    final manganese = _readField(
      controller: _manganeseController,
      label: _soilFieldLabel(
        context.read<AppProvider>().l10n,
        lang,
        'manganese',
      ),
      fallback: 3,
    );
    final copper = _readField(
      controller: _copperController,
      label: _soilFieldLabel(context.read<AppProvider>().l10n, lang, 'copper'),
      fallback: 0.4,
    );
    final boron = _readField(
      controller: _boronController,
      label: _soilFieldLabel(context.read<AppProvider>().l10n, lang, 'boron'),
      fallback: 0.7,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _results = null;
      _soilAnalysis = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    final input = CropInput(
      nitrogen: nitrogen,
      phosphorus: phosphorus,
      potassium: potassium,
      temperature: _temperature,
      humidity: _humidity,
      ph: soilPh,
      rainfall: _rainfall,
    );

    List<String> mlHints = const [];
    if (MLService.instance.isLoaded) {
      try {
        mlHints = await MLService.instance.recommendCrops(input);
      } catch (_) {}
    }

    final soilState = _SoilState(
      nitrogen: nitrogen,
      phosphorus: phosphorus,
      potassium: potassium,
      ph: soilPh,
      ec: soilEc,
      organicCarbon: organicCarbon,
      sulphur: sulphur,
      zinc: zinc,
      iron: iron,
      manganese: manganese,
      copper: copper,
      boron: boron,
      temperature: _temperature,
      humidity: _humidity,
      rainfall: _rainfall,
    );

    final analysis = _buildSoilFindings(soilState);
    final results = _buildDisplayedRecommendations(
      soilState: soilState,
      mlHints: mlHints,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _soilAnalysis = analysis;
      _results = results;
      _isLoading = false;
    });
  }

  double _readField({
    required TextEditingController controller,
    required String label,
    required double fallback,
  }) {
    final lang = context.read<AppProvider>().languageCode;
    final text = controller.text.trim();
    if (text.isEmpty) {
      return fallback;
    }

    final parsed = double.tryParse(text);
    if (parsed != null) {
      return parsed;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_cropDynamicText(lang, 'valid_number', label: label)),
      ),
    );
    throw FormatException('Invalid number for $label');
  }

  List<_CropRecommendation> _ruleBasedRecommend({
    required _SoilState soilState,
    List<String> mlHints = const [],
  }) {
    final lang = context.read<AppProvider>().languageCode;
    final scored = <_CropRecommendation>[];

    for (final entry in _cropDatabase.entries) {
      final cropName = entry.key;
      final crop = entry.value;
      final notes = <String>[];
      double score = 0;

      final minTemp = crop['minTemp'] as double;
      final maxTemp = crop['maxTemp'] as double;
      final minRain = crop['minRain'] as double;
      final minPh = crop['minPh'] as double;
      final maxPh = crop['maxPh'] as double;

      if (soilState.temperature >= minTemp &&
          soilState.temperature <= maxTemp) {
        score += 25;
        notes.add(_cropText(lang, 'Temperature fits this crop range.'));
      } else {
        score += 5;
        notes.add(_cropText(lang, 'Temperature is outside the ideal band.'));
      }

      if (soilState.rainfall >= minRain) {
        score += 20;
        notes.add(_cropText(lang, 'Rainfall support looks workable.'));
      } else {
        notes.add(_cropText(lang, 'Extra irrigation planning may be needed.'));
      }

      if (soilState.ph >= minPh && soilState.ph <= maxPh) {
        score += 25;
        notes.add(_cropText(lang, 'Soil pH matches the crop preference.'));
      } else if (soilState.ph < minPh) {
        score += 5;
        notes.add(
          _cropText(lang, 'Soil is more acidic than this crop prefers.'),
        );
      } else {
        score += 5;
        notes.add(
          _cropText(lang, 'Soil is more alkaline than this crop prefers.'),
        );
      }

      if (soilState.nitrogen > 60) {
        score += 10;
      }
      if (soilState.phosphorus > 30) {
        score += 10;
      }
      if (soilState.potassium > 30) {
        score += 10;
      }

      score += _soilSpecificAdjustment(
        cropName: cropName,
        soilState: soilState,
        notes: notes,
      );

      final mlIndex = mlHints.indexOf(cropName);
      if (mlIndex != -1) {
        score += 12 - (mlIndex * 3);
        notes.add(_cropText(lang, 'Also matched by the on-device AI model.'));
      }

      scored.add(
        _CropRecommendation(
          name: cropName,
          emoji: crop['emoji'] as String,
          season: _cropText(lang, crop['season'] as String),
          soil: _cropText(lang, crop['soil'] as String),
          description: _cropText(lang, crop['desc'] as String),
          fertilizers: List<String>.from(crop['fertilizers'] as List),
          notes: notes.take(4).toList(),
          score: score,
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  List<_CropRecommendation> _buildDisplayedRecommendations({
    required _SoilState soilState,
    List<String> mlHints = const [],
  }) {
    final scored = _ruleBasedRecommend(soilState: soilState, mlHints: mlHints);
    if (mlHints.isEmpty) {
      return scored.take(4).toList();
    }

    final scoredByName = {
      for (final recommendation in scored) recommendation.name: recommendation,
    };

    final ordered = <_CropRecommendation>[];
    final seen = <String>{};

    for (int i = 0; i < mlHints.length; i++) {
      final cropName = mlHints[i];
      final recommendation =
          scoredByName[cropName] ?? _buildMlHintRecommendation(cropName, i);
      if (seen.add(recommendation.name)) {
        ordered.add(recommendation);
      }
      if (ordered.length == 4) {
        return ordered;
      }
    }

    for (final recommendation in scored) {
      if (seen.add(recommendation.name)) {
        ordered.add(recommendation);
      }
      if (ordered.length == 4) {
        break;
      }
    }

    return ordered;
  }

  _CropRecommendation _buildMlHintRecommendation(String cropName, int mlIndex) {
    final lang = context.read<AppProvider>().languageCode;
    return _CropRecommendation(
      name: cropName,
      emoji: _emojiForCrop(cropName),
      season: _cropText(lang, 'AI model suggestion'),
      soil: _cropText(lang, 'General suitability'),
      description: _cropText(
        lang,
        'This crop came from the AI model output for your soil and weather values.',
      ),
      fertilizers: const [],
      notes: [
        _cropText(lang, 'Direct suggestion from the on-device AI crop model.'),
        _cropText(
          lang,
          'Use local season, irrigation, and market conditions before final selection.',
        ),
        _cropText(
          lang,
          'Detailed advisory for this crop is limited in the current app database.',
        ),
      ],
      score: 96 - (mlIndex * 3),
    );
  }

  double _soilSpecificAdjustment({
    required String cropName,
    required _SoilState soilState,
    required List<String> notes,
  }) {
    final lang = context.read<AppProvider>().languageCode;
    double adjustment = 0;

    if (soilState.organicCarbon < 0.5) {
      if (<String>{'tomato', 'potato', 'rice', 'maize'}.contains(cropName)) {
        adjustment -= 4;
      } else {
        adjustment -= 2;
      }
      notes.add(
        _cropText(
          lang,
          'Low organic carbon means FYM or compost support is important.',
        ),
      );
    } else if (soilState.organicCarbon > 0.75) {
      if (<String>{'tomato', 'maize', 'sugarcane', 'rice'}.contains(cropName)) {
        adjustment += 4;
      } else {
        adjustment += 2;
      }
    }

    if (soilState.ec >= 4) {
      adjustment -= 18;
      notes.add(
        _cropText(lang, 'High salinity can sharply reduce establishment.'),
      );
    } else if (soilState.ec >= 2) {
      if (<String>{'tomato', 'potato', 'chickpea'}.contains(cropName)) {
        adjustment -= 10;
      } else {
        adjustment -= 5;
      }
      notes.add(_cropText(lang, 'Salinity is a caution point for this field.'));
    } else if (soilState.ec >= 1 &&
        <String>{'tomato', 'potato', 'chickpea'}.contains(cropName)) {
      adjustment -= 4;
    }

    if (soilState.sulphur < 10 &&
        <String>{'maize', 'chickpea', 'potato'}.contains(cropName)) {
      adjustment -= 3;
      notes.add(_cropText(lang, 'Sulphur correction will help crop response.'));
    }

    if (soilState.zinc < 0.6 &&
        <String>{'rice', 'maize', 'tomato'}.contains(cropName)) {
      adjustment -= 4;
      notes.add(_cropText(lang, 'Zinc deficiency may limit early growth.'));
    }

    if (soilState.iron < 4.5 &&
        <String>{'rice', 'potato', 'tomato'}.contains(cropName)) {
      adjustment -= 3;
      notes.add(_cropText(lang, 'Iron level is on the lower side.'));
    }

    if (soilState.boron < 0.5 &&
        <String>{'tomato', 'potato', 'cotton'}.contains(cropName)) {
      adjustment -= 3;
      notes.add(
        _cropText(lang, 'Boron correction can improve flowering and quality.'),
      );
    }

    if (soilState.manganese < 2.0 &&
        <String>{'rice', 'wheat', 'maize'}.contains(cropName)) {
      adjustment -= 2;
    }

    if (soilState.copper < 0.2 &&
        <String>{'wheat', 'tomato'}.contains(cropName)) {
      adjustment -= 2;
    }

    return adjustment;
  }

  List<_SoilHealthFinding> _buildSoilFindings(_SoilState soilState) {
    final lang = context.read<AppProvider>().languageCode;
    final deficiencies = _deficientNutrients(soilState);

    return [
      _SoilHealthFinding(
        title: _cropText(lang, 'Soil reaction'),
        detail: _describePh(soilState.ph),
        color: _isPhBalanced(soilState.ph) ? Colors.green : Colors.orange,
      ),
      _SoilHealthFinding(
        title: _cropText(lang, 'Salt load (EC)'),
        detail: _describeEc(soilState.ec),
        color: soilState.ec < 1
            ? Colors.green
            : soilState.ec < 2
            ? Colors.orange
            : Colors.red,
      ),
      _SoilHealthFinding(
        title: _cropText(lang, 'Organic carbon'),
        detail: _describeOrganicCarbon(soilState.organicCarbon),
        color: soilState.organicCarbon > 0.75
            ? Colors.green
            : soilState.organicCarbon >= 0.5
            ? Colors.orange
            : Colors.red,
      ),
      _SoilHealthFinding(
        title: _cropText(lang, 'Secondary nutrient'),
        detail: soilState.sulphur < 10
            ? _cropText(lang, 'Sulphur appears deficient (<10 ppm).')
            : _cropText(
                lang,
                'Sulphur appears sufficient for normal crop growth.',
              ),
        color: soilState.sulphur < 10 ? Colors.red : Colors.green,
      ),
      _SoilHealthFinding(
        title: _cropText(lang, 'Micronutrient check'),
        detail: deficiencies.isEmpty
            ? _cropText(
                lang,
                'Zinc, iron, manganese, copper and boron look broadly sufficient.',
              )
            : _cropDynamicText(
                lang,
                'correction_priority',
                label: _joinLocalizedNutrients(context, deficiencies),
              ),
        color: deficiencies.isEmpty ? Colors.green : Colors.orange,
      ),
      _SoilHealthFinding(
        title: _cropText(lang, 'Field action'),
        detail: _buildFieldAction(
          soilState: soilState,
          deficiencies: deficiencies,
        ),
        color: Theme.of(context).colorScheme.primary,
      ),
    ];
  }

  bool _isPhBalanced(double ph) => ph >= 6.0 && ph <= 7.5;

  String _describePh(double ph) {
    final lang = context.read<AppProvider>().languageCode;
    if (ph < 4.5) {
      return _cropText(lang, 'Strongly acidic soil. Liming may be needed.');
    }
    if (ph < 5.6) {
      return _cropText(
        lang,
        'Moderately acidic soil. Acid-sensitive crops may struggle.',
      );
    }
    if (ph < 6.6) {
      return _cropText(lang, 'Slightly acidic soil. Suitable for many crops.');
    }
    if (ph <= 7.5) {
      return _cropText(
        lang,
        'Neutral soil. This is a strong general crop zone.',
      );
    }
    if (ph <= 8.5) {
      return _cropText(
        lang,
        'Slightly alkaline soil. Watch micronutrient availability.',
      );
    }
    if (ph <= 9.5) {
      return _cropText(
        lang,
        'Moderately alkaline soil. Soil amendment may be needed.',
      );
    }
    return _cropText(
      lang,
      'Strongly alkaline soil. Sensitive crops will need correction first.',
    );
  }

  String _describeEc(double ec) {
    final lang = context.read<AppProvider>().languageCode;
    if (ec < 1) {
      return _cropText(lang, 'Normal EC. Salt stress risk is low.');
    }
    if (ec < 2) {
      return _cropText(
        lang,
        'Critical for germination. Sensitive crops need extra care.',
      );
    }
    if (ec < 4) {
      return _cropText(lang, 'High enough to affect sensitive crops.');
    }
    return _cropText(
      lang,
      'Very high salinity. Most crops may suffer without treatment.',
    );
  }

  String _describeOrganicCarbon(double organicCarbon) {
    final lang = context.read<AppProvider>().languageCode;
    if (organicCarbon < 0.5) {
      return _cropText(
        lang,
        'Low organic carbon. Add compost, FYM, or residue biomass.',
      );
    }
    if (organicCarbon <= 0.75) {
      return _cropText(
        lang,
        'Medium organic carbon. Soil is workable but can still improve.',
      );
    }
    return _cropText(
      lang,
      'High organic carbon. Soil structure and microbial activity look better.',
    );
  }

  List<String> _deficientNutrients(_SoilState soilState) {
    final deficiencies = <String>[];

    if (soilState.sulphur < 10) {
      deficiencies.add('sulphur');
    }
    if (soilState.zinc < 0.6) {
      deficiencies.add('zinc');
    }
    if (soilState.iron < 4.5) {
      deficiencies.add('iron');
    }
    if (soilState.manganese < 2.0) {
      deficiencies.add('manganese');
    }
    if (soilState.copper < 0.2) {
      deficiencies.add('copper');
    }
    if (soilState.boron < 0.5) {
      deficiencies.add('boron');
    }

    return deficiencies;
  }

  String _buildFieldAction({
    required _SoilState soilState,
    required List<String> deficiencies,
  }) {
    final lang = context.read<AppProvider>().languageCode;
    final actions = <String>[];

    if (soilState.ec >= 2) {
      actions.add(
        _cropText(
          lang,
          'Prefer lower-salt irrigation water and improve drainage.',
        ),
      );
    }
    if (soilState.organicCarbon < 0.5) {
      actions.add(_cropText(lang, 'Mix in compost or FYM before sowing.'));
    }
    if (soilState.ph < 5.5) {
      actions.add(
        _cropText(lang, 'Discuss liming with the local agriculture officer.'),
      );
    } else if (soilState.ph > 8.5) {
      actions.add(
        _cropText(lang, 'Discuss gypsum or amendment needs with the lab.'),
      );
    }
    if (deficiencies.isNotEmpty) {
      actions.add(
        _cropDynamicText(
          lang,
          'correct_nutrients',
          label: _joinLocalizedNutrients(context, deficiencies),
        ),
      );
    }
    if (actions.isEmpty) {
      actions.add(
        _cropText(
          lang,
          'Soil report looks usable. Focus on crop-season fit and balanced fertiliser.',
        ),
      );
    }

    return actions.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;
    final lang = context.watch<AppProvider>().languageCode;
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final fieldWidth = width > 700 ? (width - 72) / 3 : (width - 56) / 2;

    return Scaffold(
      appBar: AppBar(title: Text(l10n['crop_recommend'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IntroBanner(scheme: scheme, introText: l10n['crop_intro']),
            const SizedBox(height: 16),
            _StepCard(
              title: _cropText(lang, 'Step 1: Upload the soil report photo'),
              subtitle: _cropText(
                lang,
                'Take a clear photo of the Soil Health Card or lab report. The app will try to read the values and fill the form.',
              ),
              child: Column(
                children: [
                  if (_reportImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        _reportImage!,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 170,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.document_scanner_outlined,
                            size: 56,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _cropText(lang, 'Upload report photo'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cropText(
                              lang,
                              'Keep the paper flat and capture all values clearly.',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _pickReportImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(_cropText(lang, 'Gallery')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickReportImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(_cropText(lang, 'Camera')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _reportImage == null || _isReadingReport
                          ? null
                          : _analyzeReportPhoto,
                      icon: _isReadingReport
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_fix_high_outlined),
                      label: Text(
                        _isReadingReport
                            ? _cropText(lang, 'Reading photo...')
                            : _cropText(lang, 'Analyze report photo'),
                      ),
                    ),
                  ),
                  if (_reportStatus != null) ...[
                    const SizedBox(height: 10),
                    _StatusBox(
                      text: _reportStatus!,
                      color: _extractedValues.isEmpty
                          ? scheme.secondaryContainer
                          : scheme.primaryContainer,
                    ),
                  ],
                  if (_extractedValues.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _extractedValues.entries
                            .map(
                              (entry) => Chip(
                                label: Text(
                                  '${_soilFieldLabel(l10n, lang, entry.key)}: ${entry.value}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  if (_recognizedPreview != null &&
                      _recognizedPreview!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(_cropText(lang, 'Preview recognized text')),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _recognizedPreview!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _StepCard(
              title: _cropText(lang, 'Step 2: Check the main soil values'),
              subtitle: _cropText(
                lang,
                'These are the most important values for crop recommendation. You can edit anything the photo reader missed.',
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InputFieldCard(
                    label: l10n['nitrogen'],
                    hint: 'kg/ha',
                    controller: _nitrogenController,
                    width: fieldWidth,
                  ),
                  _InputFieldCard(
                    label: l10n['phosphorus'],
                    hint: 'kg/ha',
                    controller: _phosphorusController,
                    width: fieldWidth,
                  ),
                  _InputFieldCard(
                    label: l10n['potassium'],
                    hint: 'kg/ha',
                    controller: _potassiumController,
                    width: fieldWidth,
                  ),
                  _InputFieldCard(
                    label: l10n['ph_level'],
                    hint: '3.5 - 9.5',
                    controller: _phController,
                    width: fieldWidth,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                initiallyExpanded: _showAdvancedValues,
                onExpansionChanged: (value) {
                  setState(() {
                    _showAdvancedValues = value;
                  });
                },
                title: Text(
                  _cropText(lang, 'More report values'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _cropText(
                    lang,
                    'EC, organic carbon, sulphur, zinc, iron, manganese, copper, boron',
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InputFieldCard(
                          label: _soilFieldLabel(l10n, lang, 'ec'),
                          hint: 'dS/m',
                          controller: _ecController,
                          width: fieldWidth,
                        ),
                        _InputFieldCard(
                          label: _soilFieldLabel(l10n, lang, 'organicCarbon'),
                          hint: '%',
                          controller: _organicCarbonController,
                          width: fieldWidth,
                        ),
                        _InputFieldCard(
                          label: _soilFieldLabel(l10n, lang, 'sulphur'),
                          hint: 'ppm',
                          controller: _sulphurController,
                          width: fieldWidth,
                        ),
                        _InputFieldCard(
                          label: _soilFieldLabel(l10n, lang, 'zinc'),
                          hint: 'ppm',
                          controller: _zincController,
                          width: fieldWidth,
                        ),
                        _InputFieldCard(
                          label: _soilFieldLabel(l10n, lang, 'iron'),
                          hint: 'ppm',
                          controller: _ironController,
                          width: fieldWidth,
                        ),
                        _InputFieldCard(
                          label: _soilFieldLabel(l10n, lang, 'manganese'),
                          hint: 'ppm',
                          controller: _manganeseController,
                          width: fieldWidth,
                        ),
                        _InputFieldCard(
                          label: _soilFieldLabel(l10n, lang, 'copper'),
                          hint: 'ppm',
                          controller: _copperController,
                          width: fieldWidth,
                        ),
                        _InputFieldCard(
                          label: _soilFieldLabel(l10n, lang, 'boron'),
                          hint: 'ppm',
                          controller: _boronController,
                          width: fieldWidth,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _StepCard(
              title: _cropText(lang, 'Step 3: Add local weather'),
              subtitle: _cropText(
                lang,
                'Farmers often know this roughly, so simple sliders are easier here than exact report numbers.',
              ),
              child: Column(
                children: [
                  _SliderInput(
                    label:
                        '${l10n['temperature']} (${_temperature.toStringAsFixed(1)} C)',
                    value: _temperature,
                    min: 5,
                    max: 45,
                    onChanged: (value) {
                      setState(() {
                        _temperature = value;
                      });
                    },
                  ),
                  _SliderInput(
                    label: '${l10n['humidity']} (${_humidity.round()}%)',
                    value: _humidity,
                    min: 10,
                    max: 100,
                    onChanged: (value) {
                      setState(() {
                        _humidity = value;
                      });
                    },
                  ),
                  _SliderInput(
                    label: '${l10n['rainfall']} (${_rainfall.round()} mm)',
                    value: _rainfall,
                    min: 10,
                    max: 300,
                    onChanged: (value) {
                      setState(() {
                        _rainfall = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleRecommendationPressed,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.agriculture_outlined),
                label: Text(
                  _isLoading
                      ? l10n['analyzing_short']
                      : _cropText(
                          lang,
                          'Recommend crops from this soil report',
                        ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_soilAnalysis != null) ...[
              _SectionTitle(_cropText(lang, 'Soil report analysis')),
              const SizedBox(height: 10),
              _SoilAnalysisCard(findings: _soilAnalysis!),
              const SizedBox(height: 20),
            ],
            if (_results != null) ...[
              Text(
                l10n['best_crops'],
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ..._results!.asMap().entries.map(
                (entry) =>
                    _CropResultCard(crop: entry.value, rank: entry.key + 1),
              ),
              const SizedBox(height: 20),
            ],
            _GovernmentHelpCard(
              onCopy: _copyValue,
              items: _governmentHelpItems,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRecommendationPressed() async {
    try {
      await _getRecommendation();
    } on FormatException {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner({required this.scheme, required this.introText});

  final ColorScheme scheme;
  final String introText;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppProvider>().languageCode;
    return Card(
      color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa_outlined, color: scheme.primary, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(introText, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _cropText(
                lang,
                'This screen is now designed for farmers to use a real soil report. First upload the photo, then check the auto-filled values, and finally get crop recommendations.',
              ),
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.80),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _InputFieldCard extends StatelessWidget {
  const _InputFieldCard({
    required this.label,
    required this.hint,
    required this.controller,
    required this.width,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderInput extends StatelessWidget {
  const _SliderInput({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 2).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SoilAnalysisCard extends StatelessWidget {
  const _SoilAnalysisCard({required this.findings});

  final List<_SoilHealthFinding> findings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: findings
              .map(
                (finding) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: finding.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              finding.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              finding.detail,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _CropResultCard extends StatelessWidget {
  const _CropResultCard({required this.crop, required this.rank});

  final _CropRecommendation crop;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppProvider>().languageCode;
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
      scheme.primary.withValues(alpha: 0.30),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colors[rank - 1].withValues(alpha: 0.20),
          child: Text(crop.emoji, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(
          '#$rank  ${_localizedCropResultName(context, crop.name)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${crop.season}  |  ${_cropText(lang, 'Score')} ${crop.score.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(_cropText(lang, 'Soil type'), crop.soil),
                _InfoRow(_cropText(lang, 'Description'), crop.description),
                const SizedBox(height: 8),
                Text(
                  _cropText(lang, 'Why this crop fits'),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ...crop.notes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      '• $note',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                if (crop.fertilizers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _cropText(lang, 'Recommended Fertilizers'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ...crop.fertilizers.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 2),
                      child: Text(
                        '• $item',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GovernmentHelpCard extends StatelessWidget {
  const _GovernmentHelpCard({required this.onCopy, required this.items});

  final Future<void> Function(String label, String value) onCopy;
  final List<_GovernmentHelpItem> items;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppProvider>().languageCode;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.40),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _cropText(lang, 'How farmers can get a soil report'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _cropText(
                lang,
                'Official Soil Health Card guidance says trained staff collect samples from 15-20 cm depth in a V-shape, taking soil from four corners and the centre, mixing it well, avoiding shaded areas, and then sending it to a soil lab.',
              ),
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              _cropText(lang, 'Suggested farmer flow:'),
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _cropText(
                lang,
                '1. Visit the nearest agriculture office, KVK, or use the official lab finder.',
              ),
            ),
            Text(
              _cropText(
                lang,
                '2. Submit a soil sample or request collection support if available locally.',
              ),
            ),
            Text(
              _cropText(
                lang,
                '3. Keep the same mobile number during sample registration.',
              ),
            ),
            Text(
              _cropText(
                lang,
                '4. Track the report online and use the values here for crop recommendation.',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _cropText(
                lang,
                'The official SHC network may include department labs, mobile labs, mini labs, village-level labs, ICAR/KVK labs, and registered private labs.',
              ),
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _cropText(lang, item.title),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _cropText(lang, item.detail),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            item.value,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () => onCopy(item.copyLabel, item.value),
                            icon: const Icon(Icons.copy, size: 16),
                            label: Text(_cropText(lang, item.copyLabel)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              _cropText(
                lang,
                'Official sources used in this section: Soil Health Card portal FAQs/manuals and Government of India Kisan Call Centre information.',
              ),
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

String _localizedCropResultName(BuildContext context, String cropName) {
  final l10n = context.read<AppProvider>().l10n;
  switch (cropName) {
    case 'tomato':
      return l10n['crop_name_tomato'];
    case 'potato':
      return l10n['crop_name_potato'];
    case 'wheat':
      return l10n['crop_name_wheat'];
    case 'rice':
      return l10n['crop_name_rice'];
    case 'cotton':
      return l10n['crop_name_cotton'];
    default:
      return _humanizeCropName(cropName);
  }
}

String _humanizeCropName(String cropName) {
  const known = {
    'blackgram': 'Blackgram',
    'chickpea': 'Chickpea',
    'coconut': 'Coconut',
    'coffee': 'Coffee',
    'cotton': 'Cotton',
    'grapes': 'Grapes',
    'jute': 'Jute',
    'kidneybeans': 'Kidney Beans',
    'lentil': 'Lentil',
    'maize': 'Maize',
    'mango': 'Mango',
    'mothbeans': 'Moth Beans',
    'mungbean': 'Mung Bean',
    'muskmelon': 'Muskmelon',
    'orange': 'Orange',
    'papaya': 'Papaya',
    'pigeonpeas': 'Pigeon Peas',
    'pomegranate': 'Pomegranate',
    'rice': 'Rice',
    'watermelon': 'Watermelon',
    'apple': 'Apple',
    'banana': 'Banana',
    'potato': 'Potato',
    'tomato': 'Tomato',
    'wheat': 'Wheat',
    'sugarcane': 'Sugarcane',
  };
  return known[cropName] ??
      cropName
          .split('_')
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' ');
}

String _emojiForCrop(String cropName) {
  const emojis = {
    'apple': '🍎',
    'banana': '🍌',
    'blackgram': '🫘',
    'chickpea': '🫘',
    'coconut': '🥥',
    'coffee': '☕',
    'cotton': '🌸',
    'grapes': '🍇',
    'jute': '🌿',
    'kidneybeans': '🫘',
    'lentil': '🫘',
    'maize': '🌽',
    'mango': '🥭',
    'mothbeans': '🫘',
    'mungbean': '🫘',
    'muskmelon': '🍈',
    'orange': '🍊',
    'papaya': '🍈',
    'pigeonpeas': '🫘',
    'pomegranate': '🍎',
    'rice': '🌾',
    'watermelon': '🍉',
    'wheat': '🌿',
    'sugarcane': '🎋',
    'tomato': '🍅',
    'potato': '🥔',
  };
  return emojis[cropName] ?? '🌱';
}

String _joinLocalizedNutrients(BuildContext context, List<String> nutrients) {
  final provider = context.read<AppProvider>();
  return nutrients
      .map(
        (item) => _soilFieldLabel(provider.l10n, provider.languageCode, item),
      )
      .join(', ');
}

String _soilFieldLabel(AppL10n l10n, String lang, String key) {
  switch (key) {
    case 'nitrogen':
      return l10n['nitrogen'];
    case 'phosphorus':
      return l10n['phosphorus'];
    case 'potassium':
      return l10n['potassium'];
    case 'ph':
      return l10n['ph_level'];
    case 'ec':
      return _cropText(lang, 'EC');
    case 'organicCarbon':
      return _cropText(lang, 'Organic Carbon');
    case 'sulphur':
      return _cropText(lang, 'Sulphur');
    case 'zinc':
      return _cropText(lang, 'Zinc');
    case 'iron':
      return _cropText(lang, 'Iron');
    case 'manganese':
      return _cropText(lang, 'Manganese');
    case 'copper':
      return _cropText(lang, 'Copper');
    case 'boron':
      return _cropText(lang, 'Boron');
    default:
      return SoilReportOcrService.prettyLabel(key);
  }
}

String _cropDynamicText(
  String lang,
  String key, {
  String? label,
  String? error,
  int? count,
}) {
  switch (key) {
    case 'copied':
      if (lang == 'hi') {
        return '$label कॉपी किया गया';
      }
      if (lang == 'pa') {
        return '$label ਕਾਪੀ ਕੀਤਾ ਗਿਆ';
      }
      if (lang == 'mr') {
        return '$label कॉपी केले';
      }
      if (lang == 'te') {
        return '$label కాపీ చేయబడింది';
      }
      return '$label copied';
    case 'filled_values':
      if (lang == 'hi') {
        return 'फोटो का विश्लेषण हो गया। $count मान अपने आप भर दिए गए।';
      }
      if (lang == 'pa') {
        return 'ਫੋਟੋ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ ਹੋ ਗਿਆ। $count ਮੁੱਲ ਆਪਣੇ ਆਪ ਭਰ ਦਿੱਤੇ ਗਏ ਹਨ।';
      }
      if (lang == 'mr') {
        return 'फोटोचे विश्लेषण झाले. $count मूल्ये आपोआप भरली गेली.';
      }
      if (lang == 'te') {
        return 'ఫోటో విశ్లేషణ పూర్తైంది. $count విలువలు స్వయంగా నింపబడ్డాయి.';
      }
      return 'Photo analyzed. $count values were filled automatically.';
    case 'photo_failed':
      if (lang == 'hi') {
        return 'फोटो विश्लेषण विफल: $error';
      }
      if (lang == 'pa') {
        return 'ਫੋਟੋ ਵਿਸ਼ਲੇਸ਼ਣ ਅਸਫਲ: $error';
      }
      if (lang == 'mr') {
        return 'फोटो विश्लेषण अयशस्वी: $error';
      }
      if (lang == 'te') {
        return 'ఫోటో విశ్లేషణ విఫలమైంది: $error';
      }
      return 'Photo analysis failed: $error';
    case 'valid_number':
      if (lang == 'hi') {
        return '$label के लिए सही संख्या दर्ज करें।';
      }
      if (lang == 'pa') {
        return '$label ਲਈ ਠੀਕ ਅੰਕ ਦਰਜ ਕਰੋ।';
      }
      if (lang == 'mr') {
        return '$label साठी योग्य संख्या भरा.';
      }
      if (lang == 'te') {
        return '$label కోసం సరైన సంఖ్యను నమోదు చేయండి.';
      }
      return 'Please enter a valid number for $label.';
    case 'correction_priority':
      if (lang == 'hi') {
        return 'सुधार की प्राथमिकता: $label।';
      }
      if (lang == 'pa') {
        return 'ਸੁਧਾਰ ਦੀ ਪਹਿਲ: $label।';
      }
      if (lang == 'mr') {
        return 'सुधारणेची प्राधान्ये: $label.';
      }
      if (lang == 'te') {
        return 'సరిదిద్దాల్సిన ప్రాధాన్యం: $label.';
      }
      return 'Correction priority: $label.';
    case 'correct_nutrients':
      if (lang == 'hi') {
        return 'रिपोर्ट की मात्रा के अनुसार $label को सुधारें।';
      }
      if (lang == 'pa') {
        return 'ਰਿਪੋਰਟ ਵਿੱਚ ਦਿੱਤੀ ਮਾਤਰਾ ਅਨੁਸਾਰ $label ਠੀਕ ਕਰੋ।';
      }
      if (lang == 'mr') {
        return 'अहवालातील मात्रेनुसार $label दुरुस्त करा.';
      }
      if (lang == 'te') {
        return 'అహ్వాలులో ఉన్న మోతాదుకు అనుగుణంగా $label సరిచేయండి.';
      }
      return 'Correct $label based on the report dose.';
    default:
      return key;
  }
}

String _cropText(String lang, String text) {
  const hi = {
    'Nearest soil testing lab': 'निकटतम मिट्टी जांच प्रयोगशाला',
    'Use the official Soil Health Card lab finder to search your nearest lab by district or location.':
        'जिले या स्थान के अनुसार नजदीकी लैब खोजने के लिए आधिकारिक सॉइल हेल्थ कार्ड लैब फाइंडर का उपयोग करें।',
    'Copy lab finder': 'लैब लिंक कॉपी करें',
    'Track or download report': 'रिपोर्ट ट्रैक या डाउनलोड करें',
    'Track the sample and download the Soil Health Card by mobile number when the test is ready.':
        'जांच तैयार होने पर मोबाइल नंबर से नमूना ट्रैक करें और सॉइल हेल्थ कार्ड डाउनलोड करें।',
    'Copy tracking link': 'ट्रैकिंग लिंक कॉपी करें',
    'Government helpline': 'सरकारी हेल्पलाइन',
    'Kisan Call Centre toll-free support for soil, crop, and farming guidance.':
        'मिट्टी, फसल और खेती संबंधी सलाह के लिए किसान कॉल सेंटर की टोल-फ्री सहायता।',
    'Copy helpline': 'हेल्पलाइन कॉपी करें',
    'Report photo selected. Tap analyze to read values.':
        'रिपोर्ट की फोटो चुन ली गई है। मान पढ़ने के लिए विश्लेषण दबाएं।',
    'Reading report photo...': 'रिपोर्ट फोटो पढ़ी जा रही है...',
    'Photo read completed, but values were not detected clearly. Please review and enter manually.':
        'फोटो पढ़ ली गई, लेकिन मान साफ़ नहीं मिले। कृपया जांचकर हाथ से भरें।',
    'Could not read the report photo clearly. Please retake the photo or enter values manually.':
        'रिपोर्ट फोटो साफ़ नहीं पढ़ी जा सकी। कृपया दोबारा फोटो लें या मान हाथ से भरें।',
    'Temperature fits this crop range.': 'तापमान इस फसल के लिए उपयुक्त है।',
    'Temperature is outside the ideal band.': 'तापमान आदर्श सीमा से बाहर है।',
    'Rainfall support looks workable.': 'वर्षा की स्थिति काम चलाने लायक है।',
    'Extra irrigation planning may be needed.':
        'अतिरिक्त सिंचाई की योजना बनानी पड़ सकती है।',
    'Soil pH matches the crop preference.': 'मिट्टी का pH इस फसल के अनुकूल है।',
    'Soil is more acidic than this crop prefers.':
        'मिट्टी इस फसल की पसंद से अधिक अम्लीय है।',
    'Soil is more alkaline than this crop prefers.':
        'मिट्टी इस फसल की पसंद से अधिक क्षारीय है।',
    'Also matched by the on-device AI model.':
        'यह ऑन-डिवाइस एआई मॉडल से भी मेल खाती है।',
    'Low organic carbon means FYM or compost support is important.':
        'कम ऑर्गेनिक कार्बन का मतलब है कि गोबर खाद या कम्पोस्ट जरूरी है।',
    'High salinity can sharply reduce establishment.':
        'अधिक लवणता फसल की शुरुआती स्थापना को काफी कम कर सकती है।',
    'Salinity is a caution point for this field.':
        'इस खेत में लवणता एक सावधानी वाला बिंदु है।',
    'Sulphur correction will help crop response.':
        'सल्फर सुधार से फसल की प्रतिक्रिया बेहतर होगी।',
    'Zinc deficiency may limit early growth.':
        'जिंक की कमी शुरुआती बढ़वार को रोक सकती है।',
    'Iron level is on the lower side.': 'लौह स्तर थोड़ा कम है।',
    'Boron correction can improve flowering and quality.':
        'बोरॉन सुधार से फूल और गुणवत्ता बेहतर हो सकती है।',
    'Soil reaction': 'मिट्टी की प्रतिक्रिया',
    'Salt load (EC)': 'लवणता भार (EC)',
    'Organic carbon': 'ऑर्गेनिक कार्बन',
    'Secondary nutrient': 'द्वितीयक पोषक तत्व',
    'Sulphur appears deficient (<10 ppm).':
        'सल्फर कम दिखाई दे रहा है (<10 ppm)।',
    'Sulphur appears sufficient for normal crop growth.':
        'सामान्य फसल बढ़वार के लिए सल्फर पर्याप्त लगता है।',
    'Micronutrient check': 'सूक्ष्म पोषक जांच',
    'Zinc, iron, manganese, copper and boron look broadly sufficient.':
        'जिंक, आयरन, मैंगनीज, कॉपर और बोरॉन सामान्य रूप से पर्याप्त लगते हैं।',
    'Field action': 'खेत के लिए कार्रवाई',
    'Strongly acidic soil. Liming may be needed.':
        'मिट्टी बहुत अधिक अम्लीय है। चूना डालना पड़ सकता है।',
    'Moderately acidic soil. Acid-sensitive crops may struggle.':
        'मिट्टी मध्यम अम्लीय है। अम्ल-संवेदनशील फसलें कमजोर पड़ सकती हैं।',
    'Slightly acidic soil. Suitable for many crops.':
        'मिट्टी हल्की अम्लीय है। कई फसलों के लिए ठीक है।',
    'Neutral soil. This is a strong general crop zone.':
        'मिट्टी तटस्थ है। यह सामान्य फसलों के लिए अच्छा क्षेत्र है।',
    'Slightly alkaline soil. Watch micronutrient availability.':
        'मिट्टी हल्की क्षारीय है। सूक्ष्म पोषक तत्वों की उपलब्धता पर ध्यान दें।',
    'Moderately alkaline soil. Soil amendment may be needed.':
        'मिट्टी मध्यम क्षारीय है। सुधार की आवश्यकता हो सकती है।',
    'Strongly alkaline soil. Sensitive crops will need correction first.':
        'मिट्टी बहुत अधिक क्षारीय है। संवेदनशील फसलों से पहले सुधार जरूरी है।',
    'Normal EC. Salt stress risk is low.':
        'EC सामान्य है। लवण तनाव का खतरा कम है।',
    'Critical for germination. Sensitive crops need extra care.':
        'अंकुरण के लिए संवेदनशील स्थिति है। नाजुक फसलों को अतिरिक्त देखभाल चाहिए।',
    'High enough to affect sensitive crops.':
        'यह स्तर संवेदनशील फसलों को प्रभावित कर सकता है।',
    'Very high salinity. Most crops may suffer without treatment.':
        'लवणता बहुत अधिक है। बिना उपचार अधिकतर फसलें प्रभावित होंगी।',
    'Low organic carbon. Add compost, FYM, or residue biomass.':
        'ऑर्गेनिक कार्बन कम है। कम्पोस्ट, गोबर खाद या अवशेष जैव पदार्थ मिलाएं।',
    'Medium organic carbon. Soil is workable but can still improve.':
        'ऑर्गेनिक कार्बन मध्यम है। मिट्टी उपयोगी है लेकिन सुधार की गुंजाइश है।',
    'High organic carbon. Soil structure and microbial activity look better.':
        'ऑर्गेनिक कार्बन अच्छा है। मिट्टी की बनावट और सूक्ष्मजीव गतिविधि बेहतर लगती है।',
    'Prefer lower-salt irrigation water and improve drainage.':
        'कम लवण वाले सिंचाई जल का उपयोग करें और निकास बेहतर करें।',
    'Mix in compost or FYM before sowing.':
        'बुवाई से पहले कम्पोस्ट या गोबर खाद मिलाएं।',
    'Discuss liming with the local agriculture officer.':
        'चूना उपचार के बारे में स्थानीय कृषि अधिकारी से बात करें।',
    'Discuss gypsum or amendment needs with the lab.':
        'जिप्सम या सुधार की जरूरत पर लैब से सलाह लें।',
    'Soil report looks usable. Focus on crop-season fit and balanced fertiliser.':
        'मिट्टी रिपोर्ट उपयोगी लग रही है। फसल-मौसम मिलान और संतुलित खाद पर ध्यान दें।',
    'Kharif (Jun-Nov)': 'खरीफ (जून-नवंबर)',
    'Clay loam': 'चिकनी दोमट',
    'Water-loving crop with high nitrogen demand.':
        'यह पानी पसंद करने वाली फसल है और इसे अधिक नाइट्रोजन चाहिए।',
    'Rabi (Oct-Mar)': 'रबी (अक्टूबर-मार्च)',
    'Loamy': 'दोमट',
    'Cool-season crop with moderate water need.':
        'ठंडे मौसम की फसल, जिसे मध्यम पानी चाहिए।',
    'Kharif / Rabi': 'खरीफ / रबी',
    'Well-drained loam': 'अच्छे निकास वाली दोमट',
    'Fast-growing crop with strong yield potential.':
        'तेजी से बढ़ने वाली फसल, जिसमें अच्छी पैदावार की क्षमता है।',
    'Kharif (Apr-Nov)': 'खरीफ (अप्रैल-नवंबर)',
    'Black cotton soil': 'काली कपासी मिट्टी',
    'Cash crop that does well in deeper black soils.':
        'नकदी फसल जो गहरी काली मिट्टी में अच्छी रहती है।',
    'Year-round': 'साल भर',
    'Loam / Clay loam': 'दोमट / चिकनी दोमट',
    'Long-duration crop with high water requirement.':
        'लंबी अवधि की फसल जिसे अधिक पानी चाहिए।',
    'All seasons (with irrigation)': 'सभी मौसम (सिंचाई के साथ)',
    'Sandy loam': 'बलुई दोमट',
    'High-value vegetable that needs good drainage.':
        'उच्च मूल्य की सब्जी जिसे अच्छा निकास चाहिए।',
    'Cool-season crop that responds well to balanced fertility.':
        'ठंडे मौसम की फसल जो संतुलित उर्वरता पर अच्छी प्रतिक्रिया देती है।',
    'Rabi (Oct-Feb)': 'रबी (अक्टूबर-फरवरी)',
    'Nitrogen-fixing legume with lower water demand.':
        'नाइट्रोजन स्थिर करने वाली दलहनी फसल, जिसे कम पानी चाहिए।',
    'Step 1: Upload the soil report photo':
        'चरण 1: मिट्टी रिपोर्ट की फोटो अपलोड करें',
    'Take a clear photo of the Soil Health Card or lab report. The app will try to read the values and fill the form.':
        'सॉइल हेल्थ कार्ड या लैब रिपोर्ट की साफ फोटो लें। ऐप मान पढ़कर फॉर्म भरने की कोशिश करेगा।',
    'Upload report photo': 'रिपोर्ट फोटो अपलोड करें',
    'Keep the paper flat and capture all values clearly.':
        'कागज सीधा रखें और सभी मान साफ़ दिखने दें।',
    'Gallery': 'गैलरी',
    'Camera': 'कैमरा',
    'Reading photo...': 'फोटो पढ़ी जा रही है...',
    'Analyze report photo': 'रिपोर्ट फोटो का विश्लेषण करें',
    'Preview recognized text': 'पहचाना गया पाठ देखें',
    'Step 2: Check the main soil values': 'चरण 2: मुख्य मिट्टी मान जांचें',
    'These are the most important values for crop recommendation. You can edit anything the photo reader missed.':
        'फसल सलाह के लिए ये सबसे जरूरी मान हैं। फोटो रीडर से छूटी चीज़ें आप बदल सकते हैं।',
    'More report values': 'रिपोर्ट के और मान',
    'EC, organic carbon, sulphur, zinc, iron, manganese, copper, boron':
        'EC, ऑर्गेनिक कार्बन, सल्फर, जिंक, आयरन, मैंगनीज, कॉपर, बोरॉन',
    'Step 3: Add local weather': 'चरण 3: स्थानीय मौसम जोड़ें',
    'Farmers often know this roughly, so simple sliders are easier here than exact report numbers.':
        'किसान अक्सर इसका अनुमान जानते हैं, इसलिए यहां सटीक अंकों की जगह आसान स्लाइडर दिए गए हैं।',
    'Recommend crops from this soil report':
        'इस मिट्टी रिपोर्ट के अनुसार फसल सुझाएं',
    'Soil report analysis': 'मिट्टी रिपोर्ट विश्लेषण',
    'This screen is now designed for farmers to use a real soil report. First upload the photo, then check the auto-filled values, and finally get crop recommendations.':
        'यह स्क्रीन अब असली मिट्टी रिपोर्ट के साथ किसान उपयोग के लिए बनाई गई है। पहले फोटो अपलोड करें, फिर भरे गए मान जांचें, और अंत में फसल सलाह लें।',
    'Score': 'स्कोर',
    'Soil type': 'मिट्टी का प्रकार',
    'Description': 'विवरण',
    'Why this crop fits': 'यह फसल क्यों उपयुक्त है',
    'Recommended Fertilizers': 'सुझाई गई खाद',
    'How farmers can get a soil report':
        'किसान मिट्टी रिपोर्ट कैसे प्राप्त करें',
    'Official Soil Health Card guidance says trained staff collect samples from 15-20 cm depth in a V-shape, taking soil from four corners and the centre, mixing it well, avoiding shaded areas, and then sending it to a soil lab.':
        'आधिकारिक सॉइल हेल्थ कार्ड मार्गदर्शन के अनुसार प्रशिक्षित कर्मचारी 15-20 सेमी गहराई से V-आकार में नमूना लेते हैं, चारों कोनों और बीच की मिट्टी मिलाते हैं, छायादार जगहों से बचते हैं, और फिर नमूना लैब भेजते हैं।',
    'Suggested farmer flow:': 'किसान के लिए सुझाया गया तरीका:',
    '1. Visit the nearest agriculture office, KVK, or use the official lab finder.':
        '1. नजदीकी कृषि कार्यालय, केवीके जाएं या आधिकारिक लैब फाइंडर इस्तेमाल करें।',
    '2. Submit a soil sample or request collection support if available locally.':
        '2. मिट्टी का नमूना जमा करें या स्थानीय सुविधा हो तो संग्रह सहायता मांगें।',
    '3. Keep the same mobile number during sample registration.':
        '3. नमूना पंजीकरण के समय वही मोबाइल नंबर रखें।',
    '4. Track the report online and use the values here for crop recommendation.':
        '4. रिपोर्ट को ऑनलाइन ट्रैक करें और यहां उन्हीं मानों से फसल सलाह लें।',
    'The official SHC network may include department labs, mobile labs, mini labs, village-level labs, ICAR/KVK labs, and registered private labs.':
        'आधिकारिक SHC नेटवर्क में विभागीय लैब, मोबाइल लैब, मिनी लैब, गांव स्तर की लैब, ICAR/KVK लैब और पंजीकृत निजी लैब शामिल हो सकती हैं।',
    'Official sources used in this section: Soil Health Card portal FAQs/manuals and Government of India Kisan Call Centre information.':
        'इस भाग में आधिकारिक स्रोत: सॉइल हेल्थ कार्ड पोर्टल के FAQ/मैनुअल और भारत सरकार किसान कॉल सेंटर की जानकारी।',
    'EC': 'EC',
    'Organic Carbon': 'ऑर्गेनिक कार्बन',
    'Sulphur': 'सल्फर',
    'Zinc': 'जिंक',
    'Iron': 'आयरन',
    'Manganese': 'मैंगनीज',
    'Copper': 'कॉपर',
    'Boron': 'बोरॉन',
  };

  const pa = {
    'Nearest soil testing lab': 'ਨਜ਼ਦੀਕੀ ਮਿੱਟੀ ਜਾਂਚ ਲੈਬ',
    'Use the official Soil Health Card lab finder to search your nearest lab by district or location.':
        'ਜ਼ਿਲ੍ਹੇ ਜਾਂ ਥਾਂ ਮੁਤਾਬਕ ਨਜ਼ਦੀਕੀ ਲੈਬ ਲੱਭਣ ਲਈ ਅਧਿਕਾਰਕ Soil Health Card lab finder ਵਰਤੋ।',
    'Copy lab finder': 'ਲੈਬ ਲਿੰਕ ਕਾਪੀ ਕਰੋ',
    'Track or download report': 'ਰਿਪੋਰਟ ਟਰੈਕ ਜਾਂ ਡਾਊਨਲੋਡ ਕਰੋ',
    'Track the sample and download the Soil Health Card by mobile number when the test is ready.':
        'ਟੈਸਟ ਤਿਆਰ ਹੋਣ ਤੇ ਮੋਬਾਈਲ ਨੰਬਰ ਨਾਲ ਨਮੂਨਾ ਟਰੈਕ ਕਰੋ ਅਤੇ Soil Health Card ਡਾਊਨਲੋਡ ਕਰੋ।',
    'Copy tracking link': 'ਟਰੈਕਿੰਗ ਲਿੰਕ ਕਾਪੀ ਕਰੋ',
    'Government helpline': 'ਸਰਕਾਰੀ ਹੈਲਪਲਾਈਨ',
    'Kisan Call Centre toll-free support for soil, crop, and farming guidance.':
        'ਮਿੱਟੀ, ਫਸਲ ਅਤੇ ਖੇਤੀ ਸਬੰਧੀ ਸਲਾਹ ਲਈ Kisan Call Centre ਦੀ ਟੋਲ-ਫ੍ਰੀ ਸਹਾਇਤਾ।',
    'Copy helpline': 'ਹੈਲਪਲਾਈਨ ਕਾਪੀ ਕਰੋ',
    'Report photo selected. Tap analyze to read values.':
        'ਰਿਪੋਰਟ ਦੀ ਫੋਟੋ ਚੁਣ ਲਈ ਗਈ ਹੈ। ਮੁੱਲ ਪੜ੍ਹਨ ਲਈ ਵਿਸ਼ਲੇਸ਼ਣ ਦਬਾਓ।',
    'Reading report photo...': 'ਰਿਪੋਰਟ ਫੋਟੋ ਪੜ੍ਹੀ ਜਾ ਰਹੀ ਹੈ...',
    'Photo read completed, but values were not detected clearly. Please review and enter manually.':
        'ਫੋਟੋ ਪੜ੍ਹ ਲਈ ਗਈ ਹੈ, ਪਰ ਮੁੱਲ ਸਪਸ਼ਟ ਨਹੀਂ ਮਿਲੇ। ਕਿਰਪਾ ਕਰਕੇ ਵੇਖੋ ਅਤੇ ਹੱਥੋਂ ਭਰੋ।',
    'Could not read the report photo clearly. Please retake the photo or enter values manually.':
        'ਰਿਪੋਰਟ ਫੋਟੋ ਸਾਫ਼ ਨਹੀਂ ਪੜ੍ਹੀ ਜਾ ਸਕੀ। ਕਿਰਪਾ ਕਰਕੇ ਫੋਟੋ ਦੁਬਾਰਾ ਲਓ ਜਾਂ ਮੁੱਲ ਹੱਥੋਂ ਭਰੋ।',
    'Temperature fits this crop range.': 'ਤਾਪਮਾਨ ਇਸ ਫਸਲ ਲਈ ਠੀਕ ਹੈ।',
    'Temperature is outside the ideal band.': 'ਤਾਪਮਾਨ ਆਦਰਸ਼ ਹੱਦ ਤੋਂ ਬਾਹਰ ਹੈ।',
    'Rainfall support looks workable.': 'ਵਰਖਾ ਦੀ ਸਥਿਤੀ ਕਾਬਲ-ਇਸਤेमाल ਲੱਗਦੀ ਹੈ।',
    'Extra irrigation planning may be needed.':
        'ਵਾਧੂ ਸਿੰਚਾਈ ਦੀ ਯੋਜਨਾ ਦੀ ਲੋੜ ਪੈ ਸਕਦੀ ਹੈ।',
    'Soil pH matches the crop preference.': 'ਮਿੱਟੀ ਦਾ pH ਇਸ ਫਸਲ ਲਈ ਢੁੱਕਵਾਂ ਹੈ।',
    'Soil is more acidic than this crop prefers.':
        'ਮਿੱਟੀ ਇਸ ਫਸਲ ਦੀ ਲੋੜ ਨਾਲੋਂ ਵੱਧ ਅਮਲੀ ਹੈ।',
    'Soil is more alkaline than this crop prefers.':
        'ਮਿੱਟੀ ਇਸ ਫਸਲ ਦੀ ਲੋੜ ਨਾਲੋਂ ਵੱਧ ਖਾਰੀਆ ਹੈ।',
    'Also matched by the on-device AI model.':
        'ਇਹ on-device AI model ਨਾਲ ਵੀ ਮੇਲ ਖਾਂਦੀ ਹੈ।',
    'Low organic carbon means FYM or compost support is important.':
        'ਘੱਟ organic carbon ਦਾ ਮਤਲਬ ਹੈ ਕਿ FYM ਜਾਂ compost ਮਹੱਤਵਪੂਰਨ ਹੈ।',
    'High salinity can sharply reduce establishment.':
        'ਵੱਧ ਲੂਣਪਨ ਸ਼ੁਰੂਆਤੀ ਸਥਾਪਨਾ ਨੂੰ ਕਾਫੀ ਘਟਾ ਸਕਦਾ ਹੈ।',
    'Salinity is a caution point for this field.':
        'ਇਸ ਖੇਤ ਲਈ ਲੂਣਪਨ ਧਿਆਨ ਵਾਲੀ ਗੱਲ ਹੈ।',
    'Sulphur correction will help crop response.':
        'ਸਲਫਰ ਦੀ ਠੀਕਾਈ ਨਾਲ ਫਸਲ ਦੀ ਪ੍ਰਤੀਕਿਰਿਆ ਸੁਧਰੇਗੀ।',
    'Zinc deficiency may limit early growth.':
        'ਜ਼ਿੰਕ ਦੀ ਘਾਟ ਸ਼ੁਰੂਆਤੀ ਵਾਧੇ ਨੂੰ ਰੋਕ ਸਕਦੀ ਹੈ।',
    'Iron level is on the lower side.': 'ਆਇਰਨ ਦਾ ਪੱਧਰ ਥੋੜ੍ਹਾ ਘੱਟ ਹੈ।',
    'Boron correction can improve flowering and quality.':
        'ਬੋਰਾਨ ਦੀ ਠੀਕਾਈ ਨਾਲ ਫੁੱਲ ਅਤੇ ਗੁਣਵੱਤਾ ਸੁਧਰ ਸਕਦੀ ਹੈ।',
    'Soil reaction': 'ਮਿੱਟੀ ਦੀ ਪ੍ਰਤੀਕਿਰਿਆ',
    'Salt load (EC)': 'ਲੂਣਪਨ ਭਾਰ (EC)',
    'Organic carbon': 'ਆਰਗੈਨਿਕ ਕਾਰਬਨ',
    'Secondary nutrient': 'ਦੂਜਾ ਪੋਸ਼ਕ ਤੱਤ',
    'Sulphur appears deficient (<10 ppm).': 'ਸਲਫਰ ਘੱਟ ਲੱਗਦਾ ਹੈ (<10 ppm)।',
    'Sulphur appears sufficient for normal crop growth.':
        'ਸਧਾਰਣ ਵਾਧੇ ਲਈ ਸਲਫਰ ਕਾਫੀ ਲੱਗਦਾ ਹੈ।',
    'Micronutrient check': 'ਸੂਖਮ ਪੋਸ਼ਕ ਜਾਂਚ',
    'Zinc, iron, manganese, copper and boron look broadly sufficient.':
        'ਜ਼ਿੰਕ, ਆਇਰਨ, ਮੈੰਗਨੀਜ਼, ਕਾਪਰ ਅਤੇ ਬੋਰਾਨ ਆਮ ਤੌਰ ਤੇ ਕਾਫੀ ਲੱਗਦੇ ਹਨ।',
    'Field action': 'ਖੇਤ ਲਈ ਕਾਰਵਾਈ',
    'Strongly acidic soil. Liming may be needed.':
        'ਮਿੱਟੀ ਬਹੁਤ ਅਮਲੀ ਹੈ। ਚੂਨਾ ਲੋੜੀਂਦਾ ਹੋ ਸਕਦਾ ਹੈ।',
    'Moderately acidic soil. Acid-sensitive crops may struggle.':
        'ਮਿੱਟੀ ਦਰਮਿਆਨੀ ਅਮਲੀ ਹੈ। ਅਮਲੀ ਸੰਵੇਦਨਸ਼ੀਲ ਫਸਲਾਂ ਨੂੰ ਮੁਸ਼ਕਲ ਹੋ ਸਕਦੀ ਹੈ।',
    'Slightly acidic soil. Suitable for many crops.':
        'ਮਿੱਟੀ ਹਲਕੀ ਅਮਲੀ ਹੈ। ਕਈ ਫਸਲਾਂ ਲਈ ਢੁੱਕਵੀ ਹੈ।',
    'Neutral soil. This is a strong general crop zone.':
        'ਮਿੱਟੀ ਤਟਸਥ ਹੈ। ਇਹ ਆਮ ਫਸਲਾਂ ਲਈ ਵਧੀਆ ਹਾਲਤ ਹੈ।',
    'Slightly alkaline soil. Watch micronutrient availability.':
        'ਮਿੱਟੀ ਹਲਕੀ ਖਾਰੀਆ ਹੈ। ਸੂਖਮ ਪੋਸ਼ਕ ਤੱਤਾਂ ਦੀ ਉਪਲਬਧਤਾ ਤੇ ਧਿਆਨ ਦਿਓ।',
    'Moderately alkaline soil. Soil amendment may be needed.':
        'ਮਿੱਟੀ ਦਰਮਿਆਨੀ ਖਾਰੀਆ ਹੈ। ਸੁਧਾਰ ਦੀ ਲੋੜ ਹੋ ਸਕਦੀ ਹੈ।',
    'Strongly alkaline soil. Sensitive crops will need correction first.':
        'ਮਿੱਟੀ ਬਹੁਤ ਖਾਰੀਆ ਹੈ। ਸੰਵੇਦਨਸ਼ੀਲ ਫਸਲਾਂ ਤੋਂ ਪਹਿਲਾਂ ਸੁਧਾਰ ਕਰੋ।',
    'Normal EC. Salt stress risk is low.':
        'EC ਸਧਾਰਣ ਹੈ। ਲੂਣ ਤਣਾਅ ਦਾ ਖਤਰਾ ਘੱਟ ਹੈ।',
    'Critical for germination. Sensitive crops need extra care.':
        'ਅੰਕੁਰਣ ਲਈ ਸੰਵੇਦਨਸ਼ੀਲ ਹਾਲਤ ਹੈ। ਨਾਜ਼ੁਕ ਫਸਲਾਂ ਨੂੰ ਵਾਧੂ ਧਿਆਨ ਚਾਹੀਦਾ ਹੈ।',
    'High enough to affect sensitive crops.':
        'ਇਹ ਪੱਧਰ ਸੰਵੇਦਨਸ਼ੀਲ ਫਸਲਾਂ ਨੂੰ ਪ੍ਰਭਾਵਿਤ ਕਰ ਸਕਦਾ ਹੈ।',
    'Very high salinity. Most crops may suffer without treatment.':
        'ਲੂਣਪਨ ਬਹੁਤ ਵੱਧ ਹੈ। ਬਿਨਾਂ ਇਲਾਜ ਜ਼ਿਆਦਾਤਰ ਫਸਲਾਂ ਪ੍ਰਭਾਵਿਤ ਹੋਣਗੀਆਂ।',
    'Low organic carbon. Add compost, FYM, or residue biomass.':
        'ਆਰਗੈਨਿਕ ਕਾਰਬਨ ਘੱਟ ਹੈ। compost, FYM ਜਾਂ ਫਸਲੀ ਅਵਸ਼ੇਸ਼ ਮਿਲਾਓ।',
    'Medium organic carbon. Soil is workable but can still improve.':
        'ਆਰਗੈਨਿਕ ਕਾਰਬਨ ਦਰਮਿਆਨਾ ਹੈ। ਮਿੱਟੀ ਵਰਤੋਂਯੋਗ ਹੈ ਪਰ ਹੋਰ ਸੁਧਰ ਸਕਦੀ ਹੈ।',
    'High organic carbon. Soil structure and microbial activity look better.':
        'ਆਰਗੈਨਿਕ ਕਾਰਬਨ ਚੰਗਾ ਹੈ। ਮਿੱਟੀ ਦੀ ਬਣਤਰ ਅਤੇ ਜੀਵਾਣੂ ਗਤੀਵਿਧੀ ਵਧੀਆ ਲੱਗਦੀ ਹੈ।',
    'Prefer lower-salt irrigation water and improve drainage.':
        'ਘੱਟ ਲੂਣ ਵਾਲਾ ਸਿੰਚਾਈ ਪਾਣੀ ਵਰਤੋ ਅਤੇ ਨਿਕਾਸ ਸੁਧਾਰੋ।',
    'Mix in compost or FYM before sowing.':
        'ਬਿਜਾਈ ਤੋਂ ਪਹਿਲਾਂ compost ਜਾਂ FYM ਮਿਲਾਓ।',
    'Discuss liming with the local agriculture officer.':
        'ਚੂਨਾ ਇਲਾਜ ਬਾਰੇ ਸਥਾਨਕ ਖੇਤੀ ਅਧਿਕਾਰੀ ਨਾਲ ਗੱਲ ਕਰੋ।',
    'Discuss gypsum or amendment needs with the lab.':
        'ਜਿਪਸਮ ਜਾਂ ਸੁਧਾਰ ਦੀ ਲੋੜ ਬਾਰੇ ਲੈਬ ਨਾਲ ਸਲਾਹ ਕਰੋ।',
    'Soil report looks usable. Focus on crop-season fit and balanced fertiliser.':
        'ਮਿੱਟੀ ਦੀ ਰਿਪੋਰਟ ਵਰਤੋਂਯੋਗ ਲੱਗਦੀ ਹੈ। ਫਸਲ-ਮੌਸਮ ਮੇਲ ਅਤੇ ਸੰਤੁਲਿਤ ਖਾਦ ਤੇ ਧਿਆਨ ਦਿਓ।',
    'Kharif (Jun-Nov)': 'ਖਰੀਫ (ਜੂਨ-ਨਵੰਬਰ)',
    'Clay loam': 'ਚਿਕਣੀ ਦੋਮਟ',
    'Water-loving crop with high nitrogen demand.':
        'ਪਾਣੀ ਪਸੰਦ ਕਰਨ ਵਾਲੀ ਫਸਲ, ਜਿਸ ਨੂੰ ਵੱਧ ਨਾਈਟਰੋਜਨ ਚਾਹੀਦੀ ਹੈ।',
    'Rabi (Oct-Mar)': 'ਰਬੀ (ਅਕਤੂਬਰ-ਮਾਰਚ)',
    'Loamy': 'ਦੋਮਟ',
    'Cool-season crop with moderate water need.':
        'ਠੰਡੇ ਮੌਸਮ ਦੀ ਫਸਲ ਜਿਸ ਨੂੰ ਦਰਮਿਆਨਾ ਪਾਣੀ ਚਾਹੀਦਾ ਹੈ।',
    'Kharif / Rabi': 'ਖਰੀਫ / ਰਬੀ',
    'Well-drained loam': 'ਚੰਗੇ ਨਿਕਾਸ ਵਾਲੀ ਦੋਮਟ',
    'Fast-growing crop with strong yield potential.':
        'ਤੇਜ਼ੀ ਨਾਲ ਵਧਣ ਵਾਲੀ ਫਸਲ ਜਿਸ ਵਿੱਚ ਚੰਗੀ ਪੈਦਾਵਾਰ ਦੀ ਸੰਭਾਵਨਾ ਹੈ।',
    'Kharif (Apr-Nov)': 'ਖਰੀਫ (ਅਪ੍ਰੈਲ-ਨਵੰਬਰ)',
    'Black cotton soil': 'ਕਾਲੀ ਕਪਾਹੀ ਮਿੱਟੀ',
    'Cash crop that does well in deeper black soils.':
        'ਨਕਦੀ ਫਸਲ ਜੋ ਡੂੰਘੀ ਕਾਲੀ ਮਿੱਟੀ ਵਿੱਚ ਚੰਗੀ ਰਹਿੰਦੀ ਹੈ।',
    'Year-round': 'ਸਾਲ ਭਰ',
    'Loam / Clay loam': 'ਦੋਮਟ / ਚਿਕਣੀ ਦੋਮਟ',
    'Long-duration crop with high water requirement.':
        'ਲੰਬੇ ਸਮੇਂ ਦੀ ਫਸਲ ਜਿਸ ਨੂੰ ਵੱਧ ਪਾਣੀ ਚਾਹੀਦਾ ਹੈ।',
    'All seasons (with irrigation)': 'ਸਾਰੇ ਮੌਸਮ (ਸਿੰਚਾਈ ਨਾਲ)',
    'Sandy loam': 'ਬਲੂਈ ਦੋਮਟ',
    'High-value vegetable that needs good drainage.':
        'ਉੱਚ ਮੁੱਲ ਵਾਲੀ ਸਬਜ਼ੀ ਜਿਸ ਨੂੰ ਚੰਗਾ ਨਿਕਾਸ ਚਾਹੀਦਾ ਹੈ।',
    'Cool-season crop that responds well to balanced fertility.':
        'ਠੰਡੇ ਮੌਸਮ ਦੀ ਫਸਲ ਜੋ ਸੰਤੁਲਿਤ ਉਰਵਰਤਾ ਨਾਲ ਚੰਗੀ ਪ੍ਰਤੀਕਿਰਿਆ ਦਿੰਦੀ ਹੈ।',
    'Rabi (Oct-Feb)': 'ਰਬੀ (ਅਕਤੂਬਰ-ਫ਼ਰਵਰੀ)',
    'Nitrogen-fixing legume with lower water demand.':
        'ਨਾਈਟਰੋਜਨ ਫਿਕਸ ਕਰਨ ਵਾਲੀ ਦਾਲੀ ਫਸਲ, ਜਿਸ ਨੂੰ ਘੱਟ ਪਾਣੀ ਚਾਹੀਦਾ ਹੈ।',
    'Step 1: Upload the soil report photo':
        'ਕਦਮ 1: ਮਿੱਟੀ ਰਿਪੋਰਟ ਦੀ ਫੋਟੋ ਅਪਲੋਡ ਕਰੋ',
    'Take a clear photo of the Soil Health Card or lab report. The app will try to read the values and fill the form.':
        'Soil Health Card ਜਾਂ ਲੈਬ ਰਿਪੋਰਟ ਦੀ ਸਾਫ਼ ਫੋਟੋ ਲਵੋ। ਐਪ ਮੁੱਲ ਪੜ੍ਹ ਕੇ ਫਾਰਮ ਭਰਨ ਦੀ ਕੋਸ਼ਿਸ਼ ਕਰੇਗੀ।',
    'Upload report photo': 'ਰਿਪੋਰਟ ਫੋਟੋ ਅਪਲੋਡ ਕਰੋ',
    'Keep the paper flat and capture all values clearly.':
        'ਕਾਗਜ਼ ਸਮਾਨ ਰੱਖੋ ਅਤੇ ਸਾਰੇ ਮੁੱਲ ਸਾਫ਼ ਦਿਖਾਓ।',
    'Gallery': 'ਗੈਲਰੀ',
    'Camera': 'ਕੈਮਰਾ',
    'Reading photo...': 'ਫੋਟੋ ਪੜ੍ਹੀ ਜਾ ਰਹੀ ਹੈ...',
    'Analyze report photo': 'ਰਿਪੋਰਟ ਫੋਟੋ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ ਕਰੋ',
    'Preview recognized text': 'ਪਛਾਣਿਆ ਟੈਕਸਟ ਵੇਖੋ',
    'Step 2: Check the main soil values': 'ਕਦਮ 2: ਮੁੱਖ ਮਿੱਟੀ ਮੁੱਲ ਚੈੱਕ ਕਰੋ',
    'These are the most important values for crop recommendation. You can edit anything the photo reader missed.':
        'ਫਸਲ ਸਲਾਹ ਲਈ ਇਹ ਸਭ ਤੋਂ ਮਹੱਤਵਪੂਰਨ ਮੁੱਲ ਹਨ। ਫੋਟੋ ਰੀਡਰ ਵੱਲੋਂ ਛੱਡੀ ਗਈ ਕੋਈ ਵੀ ਚੀਜ਼ ਤੁਸੀਂ ਠੀਕ ਕਰ ਸਕਦੇ ਹੋ।',
    'More report values': 'ਹੋਰ ਰਿਪੋਰਟ ਮੁੱਲ',
    'EC, organic carbon, sulphur, zinc, iron, manganese, copper, boron':
        'EC, ਆਰਗੈਨਿਕ ਕਾਰਬਨ, ਸਲਫਰ, ਜ਼ਿੰਕ, ਆਇਰਨ, ਮੈੰਗਨੀਜ਼, ਕਾਪਰ, ਬੋਰਾਨ',
    'Step 3: Add local weather': 'ਕਦਮ 3: ਸਥਾਨਕ ਮੌਸਮ ਜੋੜੋ',
    'Farmers often know this roughly, so simple sliders are easier here than exact report numbers.':
        'ਕਿਸਾਨ ਆਮ ਤੌਰ ਤੇ ਇਸਦਾ ਅੰਦਾਜ਼ਾ ਜਾਣਦੇ ਹਨ, ਇਸ ਲਈ ਇੱਥੇ ਆਸਾਨ ਸਲਾਈਡਰ ਦਿੱਤੇ ਗਏ ਹਨ।',
    'Recommend crops from this soil report':
        'ਇਸ ਮਿੱਟੀ ਰਿਪੋਰਟ ਅਨੁਸਾਰ ਫਸਲਾਂ ਸੁਝਾਓ',
    'Soil report analysis': 'ਮਿੱਟੀ ਰਿਪੋਰਟ ਵਿਸ਼ਲੇਸ਼ਣ',
    'This screen is now designed for farmers to use a real soil report. First upload the photo, then check the auto-filled values, and finally get crop recommendations.':
        'ਇਹ ਸਕ੍ਰੀਨ ਹੁਣ ਕਿਸਾਨਾਂ ਲਈ ਅਸਲੀ ਮਿੱਟੀ ਰਿਪੋਰਟ ਨਾਲ ਵਰਤੋਂ ਲਈ ਤਿਆਰ ਕੀਤੀ ਗਈ ਹੈ। ਪਹਿਲਾਂ ਫੋਟੋ ਅਪਲੋਡ ਕਰੋ, ਫਿਰ ਭਰੇ ਮੁੱਲ ਚੈੱਕ ਕਰੋ, ਅਤੇ ਅੰਤ ਵਿੱਚ ਫਸਲ ਸਲਾਹ ਲਵੋ।',
    'Score': 'ਸਕੋਰ',
    'Soil type': 'ਮਿੱਟੀ ਦੀ ਕਿਸਮ',
    'Description': 'ਵੇਰਵਾ',
    'Why this crop fits': 'ਇਹ ਫਸਲ ਕਿਉਂ ਢੁੱਕਵੀ ਹੈ',
    'Recommended Fertilizers': 'ਸੁਝਾਈਆਂ ਖਾਦਾਂ',
    'How farmers can get a soil report':
        'ਕਿਸਾਨ ਮਿੱਟੀ ਦੀ ਰਿਪੋਰਟ ਕਿਵੇਂ ਲੈ ਸਕਦੇ ਹਨ',
    'Official Soil Health Card guidance says trained staff collect samples from 15-20 cm depth in a V-shape, taking soil from four corners and the centre, mixing it well, avoiding shaded areas, and then sending it to a soil lab.':
        'ਅਧਿਕਾਰਕ Soil Health Card ਦਿਸ਼ਾ-ਨਿਰਦੇਸ਼ ਅਨੁਸਾਰ ਤਜਰਬੇਕਾਰ ਸਟਾਫ 15-20 ਸੈਮੀ ਗਹਿਰਾਈ ਤੋਂ V-ਆਕਾਰ ਵਿੱਚ ਨਮੂਨਾ ਲੈਂਦਾ ਹੈ, ਚਾਰ ਕੋਨਿਆਂ ਅਤੇ ਵਿਚਕਾਰਲੀ ਮਿੱਟੀ ਮਿਲਾਉਂਦਾ ਹੈ, ਛਾਂ ਵਾਲੀ ਥਾਂ ਤੋਂ ਬਚਦਾ ਹੈ, ਅਤੇ ਫਿਰ ਨਮੂਨਾ ਲੈਬ ਭੇਜਦਾ ਹੈ।',
    'Suggested farmer flow:': 'ਕਿਸਾਨ ਲਈ ਸੁਝਾਇਆ ਤਰੀਕਾ:',
    '1. Visit the nearest agriculture office, KVK, or use the official lab finder.':
        '1. ਨਜ਼ਦੀਕੀ ਖੇਤੀ ਦਫ਼ਤਰ ਜਾਂ KVK ਜਾਓ ਜਾਂ ਅਧਿਕਾਰਕ lab finder ਵਰਤੋ।',
    '2. Submit a soil sample or request collection support if available locally.':
        '2. ਮਿੱਟੀ ਦਾ ਨਮੂਨਾ ਜਮ੍ਹਾਂ ਕਰੋ ਜਾਂ ਜੇ ਸਹੂਲਤ ਹੋਵੇ ਤਾਂ ਇਕੱਠਾ ਕਰਨ ਦੀ ਮਦਦ ਮੰਗੋ।',
    '3. Keep the same mobile number during sample registration.':
        '3. ਨਮੂਨਾ ਰਜਿਸਟ੍ਰੇਸ਼ਨ ਦੌਰਾਨ ਉਹੀ ਮੋਬਾਈਲ ਨੰਬਰ ਵਰਤੋ।',
    '4. Track the report online and use the values here for crop recommendation.':
        '4. ਰਿਪੋਰਟ ਨੂੰ ਆਨਲਾਈਨ ਟਰੈਕ ਕਰੋ ਅਤੇ ਇੱਥੇ ਉਹੀ ਮੁੱਲ ਵਰਤੋ।',
    'The official SHC network may include department labs, mobile labs, mini labs, village-level labs, ICAR/KVK labs, and registered private labs.':
        'ਅਧਿਕਾਰਕ SHC ਨੈੱਟਵਰਕ ਵਿੱਚ ਵਿਭਾਗੀ ਲੈਬਾਂ, ਮੋਬਾਈਲ ਲੈਬਾਂ, ਮਿਨੀ ਲੈਬਾਂ, ਪਿੰਡ-ਪੱਧਰੀ ਲੈਬਾਂ, ICAR/KVK ਲੈਬਾਂ ਅਤੇ ਰਜਿਸਟਰਡ ਨਿੱਜੀ ਲੈਬਾਂ ਸ਼ਾਮਲ ਹੋ ਸਕਦੀਆਂ ਹਨ।',
    'Official sources used in this section: Soil Health Card portal FAQs/manuals and Government of India Kisan Call Centre information.':
        'ਇਸ ਭਾਗ ਵਿੱਚ ਵਰਤੇ ਅਧਿਕਾਰਕ ਸਰੋਤ: Soil Health Card portal ਦੇ FAQ/manuals ਅਤੇ Government of India Kisan Call Centre ਦੀ ਜਾਣਕਾਰੀ।',
    'EC': 'EC',
    'Organic Carbon': 'ਆਰਗੈਨਿਕ ਕਾਰਬਨ',
    'Sulphur': 'ਸਲਫਰ',
    'Zinc': 'ਜ਼ਿੰਕ',
    'Iron': 'ਆਇਰਨ',
    'Manganese': 'ਮੈੰਗਨੀਜ਼',
    'Copper': 'ਕਾਪਰ',
    'Boron': 'ਬੋਰਾਨ',
  };

  if (lang == 'hi') {
    return hi[text] ?? text;
  }
  if (lang == 'pa') {
    return pa[text] ?? text;
  }
  if (lang == 'mr') {
    switch (text) {
      case 'Nearest soil testing lab':
        return 'जवळची माती परीक्षण प्रयोगशाळा';
      case 'Use the official Soil Health Card lab finder to search your nearest lab by district or location.':
        return 'जिल्हा किंवा स्थानानुसार जवळची प्रयोगशाळा शोधण्यासाठी अधिकृत Soil Health Card lab finder वापरा.';
      case 'Copy lab finder':
        return 'लॅब लिंक कॉपी करा';
      case 'Track or download report':
        return 'अहवाल ट्रॅक करा किंवा डाउनलोड करा';
      case 'Track the sample and download the Soil Health Card by mobile number when the test is ready.':
        return 'चाचणी पूर्ण झाल्यावर मोबाईल क्रमांकाने नमुना ट्रॅक करा आणि Soil Health Card डाउनलोड करा.';
      case 'Copy tracking link':
        return 'ट्रॅकिंग लिंक कॉपी करा';
      case 'Government helpline':
        return 'शासकीय हेल्पलाइन';
      case 'Kisan Call Centre toll-free support for soil, crop, and farming guidance.':
        return 'माती, पीक आणि शेती मार्गदर्शनासाठी किसान कॉल सेंटरची टोल-फ्री मदत.';
      case 'Copy helpline':
        return 'హेल्पलाइन कॉपी करा';
      case 'Report photo selected. Tap analyze to read values.':
        return 'अहवालाचा फोटो निवडला आहे. मूल्ये वाचण्यासाठी विश्लेषण करा.';
      case 'Reading report photo...':
        return 'अहवालाचा फोटो वाचला जात आहे...';
      case 'Photo read completed, but values were not detected clearly. Please review and enter manually.':
        return 'फोटो वाचला गेला, पण मूल्ये स्पष्ट दिसली नाहीत. कृपया तपासून हाताने भरा.';
      case 'Could not read the report photo clearly. Please retake the photo or enter values manually.':
        return 'अहवालाचा फोटो स्पष्ट वाचता आला नाही. कृपया पुन्हा फोटो घ्या किंवा हाताने मूल्ये भरा.';
      case 'Temperature fits this crop range.':
        return 'तापमान या पिकासाठी योग्य आहे.';
      case 'Temperature is outside the ideal band.':
        return 'तापमान योग्य मर्यादेबाहेर आहे.';
      case 'Rainfall support looks workable.':
        return 'पावसाची स्थिती कामचलाऊ दिसते.';
      case 'Extra irrigation planning may be needed.':
        return 'अतिरिक्त सिंचन नियोजनाची गरज लागू शकते.';
      case 'Soil pH matches the crop preference.':
        return 'मातीचे pH या पिकासाठी योग्य आहे.';
      case 'Soil is more acidic than this crop prefers.':
        return 'ही माती या पिकासाठी जास्त आम्लधर्मी आहे.';
      case 'Soil is more alkaline than this crop prefers.':
        return 'ही माती या पिकासाठी जास्त क्षारधर्मी आहे.';
      case 'Also matched by the on-device AI model.':
        return 'हे ऑन-डिव्हाइस AI मॉडेलशीही जुळते.';
      case 'Low organic carbon means FYM or compost support is important.':
        return 'ऑर्गेनिक कार्बन कमी असल्यास शेणखत किंवा कंपोस्ट महत्त्वाचे असते.';
      case 'High salinity can sharply reduce establishment.':
        return 'जास्त क्षारता रोपांची सुरुवात कमी करू शकते.';
      case 'Salinity is a caution point for this field.':
        return 'या शेतासाठी क्षारता लक्ष देण्यासारखी बाब आहे.';
      case 'Sulphur correction will help crop response.':
        return 'सल्फरची दुरुस्ती केल्यास पिकाची प्रतिक्रिया सुधारेल.';
      case 'Zinc deficiency may limit early growth.':
        return 'जस्ताची कमतरता सुरुवातीची वाढ कमी करू शकते.';
      case 'Iron level is on the lower side.':
        return 'लोहाचे प्रमाण कमी आहे.';
      case 'Boron correction can improve flowering and quality.':
        return 'बोरॉनची दुरुस्ती केल्यास फुलधारणा आणि गुणवत्ता सुधारू शकते.';
      case 'Soil reaction':
        return 'मातीची प्रतिक्रिया';
      case 'Salt load (EC)':
        return 'क्षार भार (EC)';
      case 'Organic carbon':
        return 'सेंद्रिय कार्बन';
      case 'Secondary nutrient':
        return 'दुय्यम पोषक घटक';
      case 'Sulphur appears deficient (<10 ppm).':
        return 'सल्फर कमी दिसत आहे (<10 ppm).';
      case 'Sulphur appears sufficient for normal crop growth.':
        return 'सामान्य पिकवाढीसाठी सल्फर पुरेसे दिसते.';
      case 'Micronutrient check':
        return 'सूक्ष्म अन्नद्रव्य तपासणी';
      case 'Zinc, iron, manganese, copper and boron look broadly sufficient.':
        return 'जस्त, लोह, मॅंगनीज, तांबे आणि बोरॉन साधारणतः पुरेसे दिसतात.';
      case 'Field action':
        return 'शेतासाठी कृती';
      case 'Strongly acidic soil. Liming may be needed.':
        return 'माती खूप आम्लधर्मी आहे. चुना देण्याची गरज असू शकते.';
      case 'Moderately acidic soil. Acid-sensitive crops may struggle.':
        return 'माती मध्यम आम्लधर्मी आहे. संवेदनशील पिकांना अडचण येऊ शकते.';
      case 'Slightly acidic soil. Suitable for many crops.':
        return 'माती किंचित आम्लधर्मी आहे. अनेक पिकांसाठी योग्य आहे.';
      case 'Neutral soil. This is a strong general crop zone.':
        return 'माती तटस्थ आहे. सर्वसाधारण पिकांसाठी चांगली आहे.';
      case 'Slightly alkaline soil. Watch micronutrient availability.':
        return 'माती किंचित क्षारधर्मी आहे. सूक्ष्म अन्नद्रव्यांकडे लक्ष द्या.';
      case 'Moderately alkaline soil. Soil amendment may be needed.':
        return 'माती मध्यम क्षारधर्मी आहे. सुधारणेची गरज असू शकते.';
      case 'Strongly alkaline soil. Sensitive crops will need correction first.':
        return 'माती खूप क्षारधर्मी आहे. संवेदनशील पिकांपूर्वी सुधारणा करा.';
      case 'Normal EC. Salt stress risk is low.':
        return 'EC सामान्य आहे. क्षार ताणाचा धोका कमी आहे.';
      case 'Critical for germination. Sensitive crops need extra care.':
        return 'उगवणीसाठी ही संवेदनशील स्थिती आहे. नाजूक पिकांना अधिक काळजी लागेल.';
      case 'High enough to affect sensitive crops.':
        return 'हे प्रमाण संवेदनशील पिकांवर परिणाम करू शकते.';
      case 'Very high salinity. Most crops may suffer without treatment.':
        return 'क्षारता खूप जास्त आहे. उपचाराशिवाय बहुतेक पिकांना त्रास होईल.';
      case 'Low organic carbon. Add compost, FYM, or residue biomass.':
        return 'सेंद्रिय कार्बन कमी आहे. कंपोस्ट, शेणखत किंवा अवशेष मिसळा.';
      case 'Medium organic carbon. Soil is workable but can still improve.':
        return 'सेंद्रिय कार्बन मध्यम आहे. माती वापरण्याजोगी आहे पण सुधारू शकते.';
      case 'High organic carbon. Soil structure and microbial activity look better.':
        return 'सेंद्रिय कार्बन चांगला आहे. मातीची रचना आणि जिवाणू क्रिया चांगली आहे.';
      case 'Prefer lower-salt irrigation water and improve drainage.':
        return 'कमी क्षार असलेले पाणी वापरा आणि निचरा सुधारवा.';
      case 'Mix in compost or FYM before sowing.':
        return 'पेरणीपूर्वी कंपोस्ट किंवा शेणखत मिसळा.';
      case 'Discuss liming with the local agriculture officer.':
        return 'चुना देण्याबाबत स्थानिक कृषी अधिकाऱ्याशी चर्चा करा.';
      case 'Discuss gypsum or amendment needs with the lab.':
        return 'जिप्सम किंवा इतर सुधारणांबाबत प्रयोगशाळेशी चर्चा करा.';
      case 'Soil report looks usable. Focus on crop-season fit and balanced fertiliser.':
        return 'मातीचा अहवाल वापरण्याजोगा दिसतो. पीक-मोसमानुरूपता आणि संतुलित खतावर भर द्या.';
      case 'Kharif (Jun-Nov)':
        return 'खरीप (जून-नोव्हेंबर)';
      case 'Clay loam':
        return 'चिकण दोमट';
      case 'Water-loving crop with high nitrogen demand.':
        return 'पाणी आवडणारे आणि जास्त नायट्रोजन लागणारे पीक.';
      case 'Rabi (Oct-Mar)':
        return 'रब्बी (ऑक्टोबर-मार्च)';
      case 'Loamy':
        return 'दोमट';
      case 'Cool-season crop with moderate water need.':
        return 'थंड हवामानातील आणि मध्यम पाण्याची गरज असलेले पीक.';
      case 'Kharif / Rabi':
        return 'खरीप / रब्बी';
      case 'Well-drained loam':
        return 'चांगला निचरा असलेली दोमट माती';
      case 'Fast-growing crop with strong yield potential.':
        return 'जलद वाढणारे आणि चांगल्या उत्पादनक्षमतेचे पीक.';
      case 'Kharif (Apr-Nov)':
        return 'खरीप (एप्रिल-नोव्हेंबर)';
      case 'Black cotton soil':
        return 'काळी कापसाची माती';
      case 'Cash crop that does well in deeper black soils.':
        return 'खोल काळ्या मातीत चांगले येणारे नगदी पीक.';
      case 'Year-round':
        return 'संपूर्ण वर्ष';
      case 'Loam / Clay loam':
        return 'दोमट / चिकण दोमट';
      case 'Long-duration crop with high water requirement.':
        return 'दीर्घकालीन आणि जास्त पाण्याची गरज असलेले पीक.';
      case 'All seasons (with irrigation)':
        return 'सर्व हंगाम (सिंचनासह)';
      case 'Sandy loam':
        return 'वालुकामय दोमट';
      case 'High-value vegetable that needs good drainage.':
        return 'चांगल्या निचऱ्याची गरज असलेली उच्च मूल्य भाजी.';
      case 'Cool-season crop that responds well to balanced fertility.':
        return 'संतुलित सुपीकतेला चांगली प्रतिक्रिया देणारे थंड हवामानातील पीक.';
      case 'Rabi (Oct-Feb)':
        return 'रब्बी (ऑक्टोबर-फेब्रुवारी)';
      case 'Nitrogen-fixing legume with lower water demand.':
        return 'नायट्रोजन स्थिरीकरण करणारे आणि कमी पाण्याची गरज असलेले डाळीवर्गीय पीक.';
      case 'Step 1: Upload the soil report photo':
        return 'पायरी 1: माती अहवालाचा फोटो अपलोड करा';
      case 'Take a clear photo of the Soil Health Card or lab report. The app will try to read the values and fill the form.':
        return 'Soil Health Card किंवा लॅब अहवालाचा स्पष्ट फोटो घ्या. अॅप मूल्ये वाचून फॉर्म भरण्याचा प्रयत्न करेल.';
      case 'Upload report photo':
        return 'अहवालाचा फोटो अपलोड करा';
      case 'Keep the paper flat and capture all values clearly.':
        return 'कागद सरळ ठेवा आणि सर्व मूल्ये स्पष्ट दिसतील याची काळजी घ्या.';
      case 'Gallery':
        return 'गॅलरी';
      case 'Camera':
        return 'कॅमेरा';
      case 'Reading photo...':
        return 'फोटो वाचला जात आहे...';
      case 'Analyze report photo':
        return 'अहवालाचा फोटो विश्लेषित करा';
      case 'Preview recognized text':
        return 'ओळखलेला मजकूर पहा';
      case 'Step 2: Check the main soil values':
        return 'पायरी 2: मुख्य माती मूल्ये तपासा';
      case 'These are the most important values for crop recommendation. You can edit anything the photo reader missed.':
        return 'पीक शिफारसीसाठी ही सर्वात महत्त्वाची मूल्ये आहेत. फोटो रीडरने चुकवलेले काहीही तुम्ही दुरुस्त करू शकता.';
      case 'More report values':
        return 'अधिक अहवाल मूल्ये';
      case 'EC, organic carbon, sulphur, zinc, iron, manganese, copper, boron':
        return 'EC, सेंद्रिय कार्बन, सल्फर, जस्त, लोह, मॅंगनीज, तांबे, बोरॉन';
      case 'Step 3: Add local weather':
        return 'पायरी 3: स्थानिक हवामान जोडा';
      case 'Farmers often know this roughly, so simple sliders are easier here than exact report numbers.':
        return 'शेतकऱ्यांना याचा साधारण अंदाज असतो, त्यामुळे इथे सोपे स्लायडर अधिक सोयीचे आहेत.';
      case 'Recommend crops from this soil report':
        return 'या माती अहवालानुसार पिकांची शिफारस करा';
      case 'Soil report analysis':
        return 'माती अहवाल विश्लेषण';
      case 'This screen is now designed for farmers to use a real soil report. First upload the photo, then check the auto-filled values, and finally get crop recommendations.':
        return 'ही स्क्रीन आता प्रत्यक्ष माती अहवालासह वापरण्यासाठी तयार केली आहे. प्रथम फोटो अपलोड करा, मग भरलेली मूल्ये तपासा आणि नंतर पीक शिफारस घ्या.';
      case 'Score':
        return 'गुण';
      case 'Soil type':
        return 'मातीचा प्रकार';
      case 'Description':
        return 'वर्णन';
      case 'Why this crop fits':
        return 'हे पीक का योग्य आहे';
      case 'Recommended Fertilizers':
        return 'सुचवलेली खते';
      case 'How farmers can get a soil report':
        return 'शेतकरी मातीचा अहवाल कसा मिळवू शकतात';
      case 'Suggested farmer flow:':
        return 'शेतकऱ्यांसाठी सुचवलेली पद्धत:';
      case '1. Visit the nearest agriculture office, KVK, or use the official lab finder.':
        return '1. जवळच्या कृषी कार्यालयाला, KVK ला भेट द्या किंवा अधिकृत lab finder वापरा.';
      case '2. Submit a soil sample or request collection support if available locally.':
        return '2. मातीचा नमुना द्या किंवा स्थानिक पातळीवर सेवा असेल तर नमुना संकलनाची मदत घ्या.';
      case '3. Keep the same mobile number during sample registration.':
        return '3. नमुना नोंदणीवेळी तोच मोबाईल क्रमांक वापरा.';
      case '4. Track the report online and use the values here for crop recommendation.':
        return '4. अहवाल ऑनलाइन ट्रॅक करा आणि इथल्या शिफारसींसाठी तीच मूल्ये वापरा.';
      case 'Official sources used in this section: Soil Health Card portal FAQs/manuals and Government of India Kisan Call Centre information.':
        return 'या विभागातील अधिकृत स्रोत: Soil Health Card portal FAQ/manuals आणि भारत सरकार किसान कॉल सेंटर माहिती.';
      case 'EC':
        return 'EC';
      case 'Organic Carbon':
        return 'सेंद्रिय कार्बन';
      case 'Sulphur':
        return 'सल्फर';
      case 'Zinc':
        return 'जस्त';
      case 'Iron':
        return 'लोह';
      case 'Manganese':
        return 'मॅंगनीज';
      case 'Copper':
        return 'तांबे';
      case 'Boron':
        return 'बोरॉन';
      default:
        return text;
    }
  }
  if (lang == 'te') {
    switch (text) {
      case 'Nearest soil testing lab':
        return 'సమీప మట్టి పరీక్షా ప్రయోగశాల';
      case 'Use the official Soil Health Card lab finder to search your nearest lab by district or location.':
        return 'జిల్లా లేదా స్థలాన్ని బట్టి సమీప ప్రయోగశాలను కనుగొనడానికి అధికారిక Soil Health Card lab finder ఉపయోగించండి.';
      case 'Copy lab finder':
        return 'ల్యాబ్ లింక్ కాపీ చేయండి';
      case 'Track or download report':
        return 'నివేదికను ట్రాక్ చేయండి లేదా డౌన్‌లోడ్ చేయండి';
      case 'Track the sample and download the Soil Health Card by mobile number when the test is ready.':
        return 'పరీక్ష పూర్తయిన తర్వాత మొబైల్ నంబర్‌తో నమూనాను ట్రాక్ చేసి Soil Health Card డౌన్‌లోడ్ చేయండి.';
      case 'Copy tracking link':
        return 'ట్రాకింగ్ లింక్ కాపీ చేయండి';
      case 'Government helpline':
        return 'ప్రభుత్వ హెల్ప్‌లైన్';
      case 'Kisan Call Centre toll-free support for soil, crop, and farming guidance.':
        return 'మట్టి, పంట, వ్యవసాయ మార్గదర్శకానికి Kisan Call Centre టోల్-ఫ్రీ సహాయం.';
      case 'Copy helpline':
        return 'హెల్ప్‌లైన్ కాపీ చేయండి';
      case 'Report photo selected. Tap analyze to read values.':
        return 'నివేదిక ఫోటో ఎంపికైంది. విలువలు చదవడానికి విశ్లేషణ నొక్కండి.';
      case 'Reading report photo...':
        return 'నివేదిక ఫోటో చదవబడుతోంది...';
      case 'Photo read completed, but values were not detected clearly. Please review and enter manually.':
        return 'ఫోటో చదవబడింది, కానీ విలువలు స్పష్టంగా కనిపించలేదు. దయచేసి చూసి చేతితో నమోదు చేయండి.';
      case 'Could not read the report photo clearly. Please retake the photo or enter values manually.':
        return 'నివేదిక ఫోటో స్పష్టంగా చదవలేకపోయాం. దయచేసి మళ్లీ ఫోటో తీసి లేదా చేతితో విలువలు నమోదు చేయండి.';
      case 'Temperature fits this crop range':
        return 'ఈ పంటకు ఉష్ణోగ్రత సరిపోతుంది.';
      case 'Temperature fits this crop range.':
        return 'ఈ పంటకు ఉష్ణోగ్రత సరిపోతుంది.';
      case 'Temperature is outside the ideal band.':
        return 'ఉష్ణోగ్రత అనుకూల పరిధికి బయట ఉంది.';
      case 'Rainfall support looks workable.':
        return 'వర్షపాతం పరిస్థితి సరిపడేలా ఉంది.';
      case 'Extra irrigation planning may be needed.':
        return 'అదనపు నీటిపారుదల ప్రణాళిక అవసరం కావచ్చు.';
      case 'Soil pH matches the crop preference.':
        return 'మట్టి pH ఈ పంటకు సరిపోతుంది.';
      case 'Soil is more acidic than this crop prefers.':
        return 'ఈ పంటకు అవసరమైనదానికంటే మట్టి ఎక్కువ ఆమ్లత్వం కలిగి ఉంది.';
      case 'Soil is more alkaline than this crop prefers.':
        return 'ఈ పంటకు అవసరమైనదానికంటే మట్టి ఎక్కువ క్షారత్వం కలిగి ఉంది.';
      case 'Also matched by the on-device AI model.':
        return 'ఇది on-device AI model‌తో కూడా సరిపోలింది.';
      case 'Low organic carbon means FYM or compost support is important.':
        return 'సేంద్రియ కార్బన్ తక్కువైతే FYM లేదా కంపోస్ట్ అవసరం ఎక్కువగా ఉంటుంది.';
      case 'High salinity can sharply reduce establishment.':
        return 'అధిక ఉప్పుతనం ప్రారంభ స్థిరీకరణను తగ్గించవచ్చు.';
      case 'Salinity is a caution point for this field.':
        return 'ఈ పొలంలో ఉప్పుతనం జాగ్రత్తగా చూడాల్సిన అంశం.';
      case 'Sulphur correction will help crop response.':
        return 'సల్ఫర్ సరిచేస్తే పంట ప్రతిస్పందన మెరుగవుతుంది.';
      case 'Zinc deficiency may limit early growth.':
        return 'జింక్ లోపం ప్రారంభ వృద్ధిని తగ్గించవచ్చు.';
      case 'Iron level is on the lower side.':
        return 'ఇనుము స్థాయి కొంచెం తక్కువగా ఉంది.';
      case 'Boron correction can improve flowering and quality.':
        return 'బోరాన్ సరిచేస్తే పుష్పధారణ మరియు నాణ్యత మెరుగవుతుంది.';
      case 'Soil reaction':
        return 'మట్టి ప్రతిచర్య';
      case 'Salt load (EC)':
        return 'ఉప్పు భారం (EC)';
      case 'Organic carbon':
        return 'సేంద్రియ కార్బన్';
      case 'Secondary nutrient':
        return 'ద్వితీయ పోషకం';
      case 'Sulphur appears deficient (<10 ppm).':
        return 'సల్ఫర్ లోపంగా ఉంది (<10 ppm).';
      case 'Sulphur appears sufficient for normal crop growth.':
        return 'సాధారణ పంట వృద్ధికి సల్ఫర్ సరిపడినట్టు ఉంది.';
      case 'Micronutrient check':
        return 'సూక్ష్మ పోషక పరీక్ష';
      case 'Zinc, iron, manganese, copper and boron look broadly sufficient.':
        return 'జింక్, ఇనుము, మాంగనీస్, రాగి, బోరాన్ సాధారణంగా సరిపడేలా ఉన్నాయి.';
      case 'Field action':
        return 'పొలానికి చర్య';
      case 'Strongly acidic soil. Liming may be needed.':
        return 'మట్టి ఎక్కువ ఆమ్లత్వంతో ఉంది. చున్నం అవసరం కావచ్చు.';
      case 'Moderately acidic soil. Acid-sensitive crops may struggle.':
        return 'మట్టి మోస్తరు ఆమ్లత్వంలో ఉంది. సున్నితమైన పంటలకు ఇబ్బంది కలగవచ్చు.';
      case 'Slightly acidic soil. Suitable for many crops.':
        return 'మట్టి స్వల్ప ఆమ్లత్వంతో ఉంది. అనేక పంటలకు అనుకూలం.';
      case 'Neutral soil. This is a strong general crop zone.':
        return 'మట్టి సమతుల్యంగా ఉంది. సాధారణ పంటలకు ఇది మంచి స్థితి.';
      case 'Slightly alkaline soil. Watch micronutrient availability.':
        return 'మట్టి స్వల్ప క్షారత్వంలో ఉంది. సూక్ష్మ పోషకాల అందుబాటుపై దృష్టి పెట్టండి.';
      case 'Moderately alkaline soil. Soil amendment may be needed.':
        return 'మట్టి మోస్తరు క్షారత్వంలో ఉంది. సవరణ అవసరం కావచ్చు.';
      case 'Strongly alkaline soil. Sensitive crops will need correction first.':
        return 'మట్టి ఎక్కువ క్షారత్వంలో ఉంది. సున్నితమైన పంటలకు ముందు సవరణ అవసరం.';
      case 'Normal EC. Salt stress risk is low.':
        return 'EC సాధారణంగా ఉంది. ఉప్పు ఒత్తిడి ప్రమాదం తక్కువ.';
      case 'Critical for germination. Sensitive crops need extra care.':
        return 'మొలకెత్తుదలకు ఇది సున్నితమైన పరిస్థితి. సున్నితమైన పంటలకు ఎక్కువ జాగ్రత్త అవసరం.';
      case 'High enough to affect sensitive crops.':
        return 'ఈ స్థాయి సున్నితమైన పంటలపై ప్రభావం చూపవచ్చు.';
      case 'Very high salinity. Most crops may suffer without treatment.':
        return 'ఉప్పుతనం చాలా ఎక్కువగా ఉంది. చికిత్స లేకపోతే ఎక్కువ పంటలు నష్టపోతాయి.';
      case 'Low organic carbon. Add compost, FYM, or residue biomass.':
        return 'సేంద్రియ కార్బన్ తక్కువగా ఉంది. కంపోస్ట్, FYM లేదా అవశేష జీవపదార్థం కలపండి.';
      case 'Medium organic carbon. Soil is workable but can still improve.':
        return 'సేంద్రియ కార్బన్ మోస్తరు స్థాయిలో ఉంది. మట్టి ఉపయోగకరంగా ఉంది కానీ ఇంకా మెరుగవచ్చు.';
      case 'High organic carbon. Soil structure and microbial activity look better.':
        return 'సేంద్రియ కార్బన్ బాగుంది. మట్టి నిర్మాణం మరియు సూక్ష్మజీవుల క్రియాశీలత మెరుగ్గా కనిపిస్తున్నాయి.';
      case 'Prefer lower-salt irrigation water and improve drainage.':
        return 'తక్కువ ఉప్పుతనం గల నీటిని వాడండి మరియు డ్రైనేజ్ మెరుగుపరచండి.';
      case 'Mix in compost or FYM before sowing.':
        return 'విత్తే ముందు కంపోస్ట్ లేదా FYM కలపండి.';
      case 'Discuss liming with the local agriculture officer.':
        return 'చున్నం వాడకం గురించి స్థానిక వ్యవసాయ అధికారితో చర్చించండి.';
      case 'Discuss gypsum or amendment needs with the lab.':
        return 'జిప్సం లేదా ఇతర సవరణల గురించి ల్యాబ్‌తో చర్చించండి.';
      case 'Soil report looks usable. Focus on crop-season fit and balanced fertiliser.':
        return 'మట్టి నివేదిక ఉపయోగకరంగా కనిపిస్తోంది. పంట-కాలం సరిపోవడం మరియు సమతుల్య ఎరువుపై దృష్టి పెట్టండి.';
      case 'Kharif (Jun-Nov)':
        return 'ఖరీఫ్ (జూన్-నవంబర్)';
      case 'Clay loam':
        return 'చిక్కటి లోమీ మట్టి';
      case 'Water-loving crop with high nitrogen demand.':
        return 'ఎక్కువ నీరు మరియు నైట్రోజన్ అవసరమయ్యే పంట.';
      case 'Rabi (Oct-Mar)':
        return 'రబీ (అక్టోబర్-మార్చి)';
      case 'Loamy':
        return 'లోమీ';
      case 'Cool-season crop with moderate water need.':
        return 'చల్లని కాలంలో పెరిగే మరియు మోస్తరు నీటి అవసరమున్న పంట.';
      case 'Kharif / Rabi':
        return 'ఖరీఫ్ / రబీ';
      case 'Well-drained loam':
        return 'మంచి డ్రైనేజ్ గల లోమీ మట్టి';
      case 'Fast-growing crop with strong yield potential.':
        return 'త్వరగా పెరిగే మరియు మంచి దిగుబడి సామర్థ్యం గల పంట.';
      case 'Kharif (Apr-Nov)':
        return 'ఖరీఫ్ (ఏప్రిల్-నవంబర్)';
      case 'Black cotton soil':
        return 'నల్ల పత్తి మట్టి';
      case 'Cash crop that does well in deeper black soils.':
        return 'లోతైన నల్ల మట్టిలో బాగా పెరిగే వాణిజ్య పంట.';
      case 'Year-round':
        return 'సంవత్సరం మొత్తం';
      case 'Loam / Clay loam':
        return 'లోమీ / చిక్కటి లోమీ';
      case 'Long-duration crop with high water requirement.':
        return 'ఎక్కువ కాలం పెరిగే మరియు ఎక్కువ నీటి అవసరమున్న పంట.';
      case 'All seasons (with irrigation)':
        return 'అన్ని కాలాలు (నీటిపారుదలతో)';
      case 'Sandy loam':
        return 'ఇసుక లోమీ';
      case 'High-value vegetable that needs good drainage.':
        return 'మంచి డ్రైనేజ్ కావాల్సిన అధిక విలువ గల కూరగాయ.';
      case 'Cool-season crop that responds well to balanced fertility.':
        return 'సమతుల్య సారానికి మంచి ప్రతిస్పందన ఇచ్చే చల్లని కాలపు పంట.';
      case 'Rabi (Oct-Feb)':
        return 'రబీ (అక్టోబర్-ఫిబ్రవరి)';
      case 'Nitrogen-fixing legume with lower water demand.':
        return 'తక్కువ నీరు అవసరమయ్యే నైట్రోజన్ స్థిరపరచే పప్పుదినుసు పంట.';
      case 'Step 1: Upload the soil report photo':
        return 'దశ 1: మట్టి నివేదిక ఫోటో అప్లోడ్ చేయండి';
      case 'Take a clear photo of the Soil Health Card or lab report. The app will try to read the values and fill the form.':
        return 'Soil Health Card లేదా ల్యాబ్ నివేదికకు స్పష్టమైన ఫోటో తీసుకోండి. యాప్ విలువలను చదివి ఫారం నింపడానికి ప్రయత్నిస్తుంది.';
      case 'Upload report photo':
        return 'నివేదిక ఫోటో అప్లోడ్ చేయండి';
      case 'Keep the paper flat and capture all values clearly.':
        return 'కాగితాన్ని సూటిగా ఉంచి అన్ని విలువలు స్పష్టంగా కనిపించేలా ఫోటో తీయండి.';
      case 'Gallery':
        return 'గ్యాలరీ';
      case 'Camera':
        return 'కెమెరా';
      case 'Reading photo...':
        return 'ఫోటో చదవబడుతోంది...';
      case 'Analyze report photo':
        return 'నివేదిక ఫోటోను విశ్లేషించండి';
      case 'Preview recognized text':
        return 'గుర్తించిన పాఠ్యాన్ని చూడండి';
      case 'Step 2: Check the main soil values':
        return 'దశ 2: ప్రధాన మట్టి విలువలను తనిఖీ చేయండి';
      case 'These are the most important values for crop recommendation. You can edit anything the photo reader missed.':
        return 'పంట సిఫారసుకు ఇవే ముఖ్యమైన విలువలు. ఫోటో రీడర్ మిస్ చేసినవి మీరు సవరించవచ్చు.';
      case 'More report values':
        return 'ఇంకా నివేదిక విలువలు';
      case 'EC, organic carbon, sulphur, zinc, iron, manganese, copper, boron':
        return 'EC, సేంద్రియ కార్బన్, సల్ఫర్, జింక్, ఇనుము, మాంగనీస్, రాగి, బోరాన్';
      case 'Step 3: Add local weather':
        return 'దశ 3: స్థానిక వాతావరణాన్ని జోడించండి';
      case 'Farmers often know this roughly, so simple sliders are easier here than exact report numbers.':
        return 'రైతులకు దీనిపై సుమారు అవగాహన ఉంటుంది కాబట్టి ఇక్కడ సరళమైన స్లైడర్లు ఉపయోగించాం.';
      case 'Recommend crops from this soil report':
        return 'ఈ మట్టి నివేదిక ప్రకారం పంటలను సూచించండి';
      case 'Soil report analysis':
        return 'మట్టి నివేదిక విశ్లేషణ';
      case 'This screen is now designed for farmers to use a real soil report. First upload the photo, then check the auto-filled values, and finally get crop recommendations.':
        return 'ఈ స్క్రీన్ నిజమైన మట్టి నివేదికతో రైతులు ఉపయోగించేందుకు రూపొందించబడింది. మొదట ఫోటో అప్లోడ్ చేసి, తర్వాత నింపబడిన విలువలు చూసి, చివరగా పంట సిఫారసులు పొందండి.';
      case 'Score':
        return 'స్కోర్';
      case 'Soil type':
        return 'మట్టి రకం';
      case 'Description':
        return 'వివరణ';
      case 'Why this crop fits':
        return 'ఈ పంట ఎందుకు సరిపోతుంది';
      case 'Recommended Fertilizers':
        return 'సూచించిన ఎరువులు';
      case 'How farmers can get a soil report':
        return 'రైతులు మట్టి నివేదికను ఎలా పొందవచ్చు';
      case 'Suggested farmer flow:':
        return 'రైతులకు సూచించిన విధానం:';
      case '1. Visit the nearest agriculture office, KVK, or use the official lab finder.':
        return '1. సమీప వ్యవసాయ కార్యాలయం, KVK ను సందర్శించండి లేదా అధికారిక lab finder ఉపయోగించండి.';
      case '2. Submit a soil sample or request collection support if available locally.':
        return '2. మట్టి నమూనా ఇవ్వండి లేదా స్థానికంగా సదుపాయం ఉంటే సేకరణ సహాయం కోరండి.';
      case '3. Keep the same mobile number during sample registration.':
        return '3. నమూనా నమోదు సమయంలో అదే మొబైల్ నంబర్ వాడండి.';
      case '4. Track the report online and use the values here for crop recommendation.':
        return '4. నివేదికను ఆన్‌లైన్‌లో ట్రాక్ చేసి, ఇక్కడి సిఫారసులకు అదే విలువలు వాడండి.';
      case 'Official sources used in this section: Soil Health Card portal FAQs/manuals and Government of India Kisan Call Centre information.':
        return 'ఈ విభాగంలో ఉపయోగించిన అధికారిక మూలాలు: Soil Health Card portal FAQ/manuals మరియు Government of India Kisan Call Centre సమాచారం.';
      case 'EC':
        return 'EC';
      case 'Organic Carbon':
        return 'సేంద్రియ కార్బన్';
      case 'Sulphur':
        return 'సల్ఫర్';
      case 'Zinc':
        return 'జింక్';
      case 'Iron':
        return 'ఇనుము';
      case 'Manganese':
        return 'మాంగనీస్';
      case 'Copper':
        return 'రాగి';
      case 'Boron':
        return 'బోరాన్';
      default:
        return text;
    }
  }
  return text;
}

class _CropRecommendation {
  const _CropRecommendation({
    required this.name,
    required this.emoji,
    required this.season,
    required this.soil,
    required this.description,
    required this.fertilizers,
    required this.notes,
    required this.score,
  });

  final String name;
  final String emoji;
  final String season;
  final String soil;
  final String description;
  final List<String> fertilizers;
  final List<String> notes;
  final double score;
}

class _SoilHealthFinding {
  const _SoilHealthFinding({
    required this.title,
    required this.detail,
    required this.color,
  });

  final String title;
  final String detail;
  final Color color;
}

class _GovernmentHelpItem {
  const _GovernmentHelpItem({
    required this.title,
    required this.detail,
    required this.value,
    required this.copyLabel,
    required this.icon,
  });

  final String title;
  final String detail;
  final String value;
  final String copyLabel;
  final IconData icon;
}

class _SoilState {
  const _SoilState({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.ph,
    required this.ec,
    required this.organicCarbon,
    required this.sulphur,
    required this.zinc,
    required this.iron,
    required this.manganese,
    required this.copper,
    required this.boron,
    required this.temperature,
    required this.humidity,
    required this.rainfall,
  });

  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double ph;
  final double ec;
  final double organicCarbon;
  final double sulphur;
  final double zinc;
  final double iron;
  final double manganese;
  final double copper;
  final double boron;
  final double temperature;
  final double humidity;
  final double rainfall;
}
