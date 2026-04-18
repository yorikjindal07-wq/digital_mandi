// ─────────────────────────────────────────────
// screens/result_screen.dart
// Shows disease prediction result, confidence
// bar, treatment recommendations, and lets
// user hear the result via TTS.
// ─────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/voice_services.dart';
import '../core/theme.dart';
import '../models/models.dart';

// ── Treatment data (mirrors JSON asset) ───────
const Map<String, Map<String, String>> _treatments = {
  'early_blight': {
    'en':
        'Apply Chlorothalonil 75WP @ 2g/L. Remove infected lower leaves. Spray every 7–10 days. Avoid wet foliage at night.',
    'hi':
        'क्लोरोथैलोनिल 75WP @ 2g/L लगाएं। संक्रमित पत्तियां हटाएं। 7-10 दिनों में एक बार स्प्रे करें।',
    'pa':
        'ਕਲੋਰੋਥੈਲੋਨਿਲ 75WP @ 2g/L ਲਗਾਓ। ਸੰਕ੍ਰਮਿਤ ਪੱਤੇ ਹਟਾਓ। 7-10 ਦਿਨਾਂ ਵਿੱਚ ਸਪ੍ਰੇ ਕਰੋ।',
  },
  'late_blight': {
    'en':
        'Apply Metalaxyl + Mancozeb @ 2.5g/L. Drain excess water from field. Spray copper fungicide preventively.',
    'hi':
        'मेटालैक्सिल + मैनकोज़ेब @ 2.5g/L लगाएं। खेत से अतिरिक्त पानी निकालें। कॉपर फंगीसाइड का छिड़काव करें।',
    'pa': 'ਮੈਟਲਐਕਸਿਲ + ਮੈਨਕੋਜ਼ੇਬ @ 2.5g/L ਲਗਾਓ। ਖੇਤ ਤੋਂ ਪਾਣੀ ਕੱਢੋ।',
  },
  'leaf_mold': {
    'en':
        'Improve air circulation in greenhouse. Apply Sulfur dust @ 25kg/ha or Propiconazole @ 1ml/L.',
    'hi':
        'ग्रीनहाउस में वायु संचार सुधारें। सल्फर डस्ट @ 25kg/ha या प्रोपिकोनाज़ोल @ 1ml/L लगाएं।',
    'pa':
        'ਗ੍ਰੀਨਹਾਊਸ ਵਿੱਚ ਹਵਾ ਦੇ ਸੰਚਾਰ ਵਿੱਚ ਸੁਧਾਰ ਕਰੋ। ਸਲਫਰ ਧੂੜ @ 25kg/ha ਲਗਾਓ।',
  },
  'healthy': {
    'en':
        'No disease detected! Your plant is healthy. Continue regular monitoring and good farming practices.',
    'hi': 'कोई रोग नहीं मिला! आपका पौधा स्वस्थ है। नियमित निगरानी जारी रखें।',
    'pa': 'ਕੋਈ ਰੋਗ ਨਹੀਂ ਮਿਲਿਆ! ਤੁਹਾਡਾ ਪੌਦਾ ਸਿਹਤਮੰਦ ਹੈ।',
  },
};

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.prediction,
    required this.imageFile,
  });

  final PredictionModel prediction;
  final File imageFile;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnim = Tween<double>(begin: 0, end: widget.prediction.confidence)
        .animate(
          CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOutCubic),
        );
    _progressCtrl.forward();

    // Auto-read result via TTS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readResult();
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    TTSService.instance.stop();
    super.dispose();
  }

  Future<void> _readResult() async {
    final lang = context.read<AppProvider>().languageCode;
    final treatment = _getTreatment(lang);
    await TTSService.instance.speak(
      '${widget.prediction.displayName}. $treatment',
      languageCode: lang,
    );
  }

  String _getTreatment(String lang) {
    final disease = widget.prediction.disease;
    return _treatments[disease]?[lang] ??
        _treatments[disease]?['en'] ??
        'No treatment information available.';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l10n = provider.l10n;
    final lang = provider.languageCode;
    final pred = widget.prediction;
    final isHealthy = pred.isHealthy;
    final appColors = Theme.of(context).extension<AppColors>();
    final scheme = Theme.of(context).colorScheme;

    final resultColor = pred.isUncertain
        ? appColors?.warning ?? Colors.orange
        : isHealthy
        ? appColors?.healthy ?? Colors.green
        : appColors?.disease ?? Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n['disease_detected']),
        actions: [
          IconButton(
            icon: Icon(
              TTSService.instance.isSpeaking
                  ? Icons.volume_off
                  : Icons.volume_up,
            ),
            onPressed: TTSService.instance.isSpeaking
                ? () => TTSService.instance.stop()
                : _readResult,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Image ────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                widget.imageFile,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 20),

            // ── Result Card ──────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Disease name
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: resultColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: resultColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        pred.isUncertain
                            ? '⚠️  Low Confidence'
                            : isHealthy
                            ? '✅  ${pred.displayName}'
                            : '🚨  ${pred.displayName}',
                        style: TextStyle(
                          color: resultColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Confidence meter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n['confidence'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (_, __) => Text(
                            '${(_progressAnim.value * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: resultColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progressAnim.value,
                          minHeight: 14,
                          backgroundColor: resultColor.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(resultColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Treatment Card ───────────────────
            if (!pred.isUncertain)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.healing_rounded, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            l10n['treatment'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getTreatment(lang),
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),

            if (pred.isUncertain)
              Card(
                color: Colors.orange.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n['low_confidence'],
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── Actions ──────────────────────────
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Scan Another Leaf'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _readResult,
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('Hear Result Again'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
