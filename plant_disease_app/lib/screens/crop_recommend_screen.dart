// ─────────────────────────────────────────────
// screens/crop_recommend_screen.dart
// Farmers enter soil + climate parameters and
// get AI-ranked crop recommendations with
// fertiliser and season info.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ml_service.dart';
import '../models/models.dart';

// ── Crop database (fallback when ML not available) ──
const Map<String, Map<String, dynamic>> _cropDatabase = {
  'rice': {
    'emoji': '🌾',
    'season': 'Kharif (Jun–Nov)',
    'soil': 'Clay loam',
    'minTemp': 20.0,
    'maxTemp': 35.0,
    'minRain': 100.0,
    'minPh': 5.5,
    'maxPh': 7.0,
    'desc': 'Water-loving crop. Needs flooded fields. High N demand.',
    'fertilizers': ['DAP 50 kg/acre', 'Urea 40 kg/acre', 'MOP 25 kg/acre'],
  },
  'wheat': {
    'emoji': '🌿',
    'season': 'Rabi (Oct–Mar)',
    'soil': 'Loamy',
    'minTemp': 12.0,
    'maxTemp': 25.0,
    'minRain': 25.0,
    'minPh': 6.0,
    'maxPh': 7.5,
    'desc': 'Cool-season crop. Tolerates frost. Moderate water needs.',
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
    'desc': 'Fast growing. Good for intercropping. High yield potential.',
    'fertilizers': ['NPK 12:32:16 @ 50 kg', 'Urea 45 kg/acre'],
  },
  'cotton': {
    'emoji': '🌸',
    'season': 'Kharif (Apr–Nov)',
    'soil': 'Black cotton soil',
    'minTemp': 20.0,
    'maxTemp': 38.0,
    'minRain': 50.0,
    'minPh': 6.0,
    'maxPh': 8.0,
    'desc': 'Cash crop. Needs deep black soil and long growing season.',
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
    'desc': 'Long duration crop (12–18 months). High water requirement.',
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
    'desc': 'High-value vegetable. Disease-prone. Needs good drainage.',
    'fertilizers': ['NPK 19:19:19 @ 4g/L', 'CaNO3 spray after fruiting'],
  },
  'potato': {
    'emoji': '🥔',
    'season': 'Rabi (Oct–Mar)',
    'soil': 'Sandy loam',
    'minTemp': 15.0,
    'maxTemp': 25.0,
    'minRain': 50.0,
    'minPh': 5.0,
    'maxPh': 6.5,
    'desc': 'High starch content. Needs cool temperatures. Disease-sensitive.',
    'fertilizers': ['DAP 50 kg/acre', 'MOP 50 kg/acre', 'Urea 35 kg/acre'],
  },
  'chickpea': {
    'emoji': '🫘',
    'season': 'Rabi (Oct–Feb)',
    'soil': 'Well-drained loam',
    'minTemp': 10.0,
    'maxTemp': 25.0,
    'minRain': 20.0,
    'minPh': 6.0,
    'maxPh': 8.0,
    'desc': 'Nitrogen-fixing legume. Low water requirement. Drought tolerant.',
    'fertilizers': [
      'DAP 25 kg/acre (only at sowing)',
      'Rhizobium seed treatment',
    ],
  },
};

class CropRecommendScreen extends StatefulWidget {
  const CropRecommendScreen({super.key});

  @override
  State<CropRecommendScreen> createState() => _CropRecommendScreenState();
}

class _CropRecommendScreenState extends State<CropRecommendScreen> {
  // Form values
  double _nitrogen = 50;
  double _phosphorus = 40;
  double _potassium = 40;
  double _temperature = 25;
  double _humidity = 60;
  double _ph = 6.5;
  double _rainfall = 60;

  List<Map<String, dynamic>>? _results;
  bool _isLoading = false;

  // ── Rule-based scoring fallback ───────────────
  List<Map<String, dynamic>> _ruleBasedRecommend() {
    final scored = <Map<String, dynamic>>[];

    for (final entry in _cropDatabase.entries) {
      final crop = entry.value;
      double score = 0;

      // Temperature match
      if (_temperature >= (crop['minTemp'] as double) &&
          _temperature <= (crop['maxTemp'] as double))
        score += 25;
      else
        score += 5;

      // Rainfall match
      if (_rainfall >= (crop['minRain'] as double)) score += 20;

      // pH match
      if (_ph >= (crop['minPh'] as double) && _ph <= (crop['maxPh'] as double))
        score += 25;
      else
        score += 5;

      // Soil nutrient balance
      if (_nitrogen > 60) score += 10;
      if (_phosphorus > 30) score += 10;
      if (_potassium > 30) score += 10;

      scored.add({
        'name': entry.key,
        'score': score,
        'emoji': crop['emoji'],
        'season': crop['season'],
        'soil': crop['soil'],
        'desc': crop['desc'],
        'fertilizers': crop['fertilizers'],
      });
    }

    scored.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );
    return scored.take(4).toList();
  }

  Future<void> _getRecommendation() async {
    setState(() {
      _isLoading = true;
      _results = null;
    });

    await Future.delayed(const Duration(milliseconds: 600)); // UX polish

    // Try ML model first, fall back to rule-based
    List<Map<String, dynamic>> results;

    if (MLService.instance.isLoaded) {
      try {
        final input = CropInput(
          nitrogen: _nitrogen,
          phosphorus: _phosphorus,
          potassium: _potassium,
          temperature: _temperature,
          humidity: _humidity,
          ph: _ph,
          rainfall: _rainfall,
        );
        final topCrops = await MLService.instance.recommendCrops(input);
        // topCrops are indices — map them to crop database
        results = _ruleBasedRecommend(); // fallback for now
      } catch (e) {
        results = _ruleBasedRecommend();
      }
    } else {
      results = _ruleBasedRecommend();
    }

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n['crop_recommend'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ──────────────────────
            Card(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: const [
                    Text('🌱', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enter your soil and climate data below to get AI-powered crop suggestions.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Input sliders ────────────────────
            _SliderInput(
              label: '${l10n['nitrogen']} (${_nitrogen.round()})',
              value: _nitrogen,
              min: 0,
              max: 140,
              onChanged: (v) => setState(() => _nitrogen = v),
            ),
            _SliderInput(
              label: '${l10n['phosphorus']} (${_phosphorus.round()})',
              value: _phosphorus,
              min: 5,
              max: 145,
              onChanged: (v) => setState(() => _phosphorus = v),
            ),
            _SliderInput(
              label: '${l10n['potassium']} (${_potassium.round()})',
              value: _potassium,
              min: 5,
              max: 205,
              onChanged: (v) => setState(() => _potassium = v),
            ),
            _SliderInput(
              label:
                  '${l10n['temperature']} (${_temperature.toStringAsFixed(1)}°C)',
              value: _temperature,
              min: 5,
              max: 45,
              onChanged: (v) => setState(() => _temperature = v),
            ),
            _SliderInput(
              label: '${l10n['humidity']} (${_humidity.round()}%)',
              value: _humidity,
              min: 10,
              max: 100,
              onChanged: (v) => setState(() => _humidity = v),
            ),
            _SliderInput(
              label: '${l10n['ph_level']} (${_ph.toStringAsFixed(1)})',
              value: _ph,
              min: 3.5,
              max: 9.5,
              onChanged: (v) => setState(() => _ph = v),
            ),
            _SliderInput(
              label: '${l10n['rainfall']} (${_rainfall.round()} mm)',
              value: _rainfall,
              min: 10,
              max: 300,
              onChanged: (v) => setState(() => _rainfall = v),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _getRecommendation,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isLoading ? 'Analyzing...' : l10n['get_recommendation'],
              ),
            ),

            const SizedBox(height: 24),

            // ── Results ──────────────────────────
            if (_results != null) ...[
              Text(
                l10n['best_crops'],
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ..._results!.asMap().entries.map(
                (e) => _CropResultCard(crop: e.value, rank: e.key + 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Slider input widget ───────────────────────
class _SliderInput extends StatelessWidget {
  const _SliderInput({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final double value, min, max;
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
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Crop result card ──────────────────────────
class _CropResultCard extends StatelessWidget {
  const _CropResultCard({required this.crop, required this.rank});
  final Map<String, dynamic> crop;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      const Color(0xFFFFD700), // gold
      const Color(0xFFC0C0C0), // silver
      const Color(0xFFCD7F32), // bronze
      scheme.primary.withOpacity(0.3),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colors[rank - 1].withOpacity(0.2),
          child: Text(
            crop['emoji'] as String,
            style: const TextStyle(fontSize: 22),
          ),
        ),
        title: Text(
          '#$rank  ${(crop['name'] as String)[0].toUpperCase()}'
          '${(crop['name'] as String).substring(1)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          crop['season'] as String,
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow('Soil type', crop['soil'] as String),
                _InfoRow('Description', crop['desc'] as String),
                const SizedBox(height: 8),
                const Text(
                  'Recommended Fertilizers',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ...(crop['fertilizers'] as List).map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Text('• $f', style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
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
