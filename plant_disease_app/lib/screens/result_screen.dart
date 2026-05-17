import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/treatment_service.dart';
import '../services/voice_services.dart';

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
  late final AnimationController _progressCtrl;
  late final Animation<double> _progressAnim;
  Map<String, dynamic> _diseaseTreatmentEntry = const {};

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
    _loadTreatments();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    TTSService.instance.stop();
    super.dispose();
  }

  Future<void> _loadTreatments() async {
    try {
      final decoded = await TreatmentService.instance.getDiseaseEntry(
        widget.prediction.disease,
      );
      if (!mounted) return;
      setState(() => _diseaseTreatmentEntry = decoded);
    } catch (_) {
      // Keep the screen usable with the fallback text already present
      // in PredictionModel.remedy.
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _readResult();
        });
      }
    }
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
    final localizedEntry = _diseaseTreatmentEntry[lang];
    if (localizedEntry is Map<String, dynamic>) {
      final treatment = localizedEntry['treatment'];
      if (treatment is String && treatment.isNotEmpty) {
        return treatment;
      }
    }

    final englishEntry = _diseaseTreatmentEntry['en'];
    if (englishEntry is Map<String, dynamic>) {
      final treatment = englishEntry['treatment'];
      if (treatment is String && treatment.isNotEmpty) {
        return treatment;
      }
    }

    if (widget.prediction.remedy.isNotEmpty) {
      return widget.prediction.remedy;
    }

    final l10n = context.read<AppProvider>().l10n;
    return l10n['no_treatment_available'];
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

    final badgeText = pred.isUncertain
        ? l10n['low_confidence_badge']
        : isHealthy
        ? pred.displayName
        : pred.displayName;

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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: resultColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: resultColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: resultColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n['confidence'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (context, child) => Text(
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
                      builder: (context, child) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progressAnim.value,
                          minHeight: 14,
                          backgroundColor: resultColor.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(resultColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
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
                color: Colors.orange.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n['low_confidence'],
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(l10n['scan_another_leaf']),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _readResult,
              icon: const Icon(Icons.volume_up_rounded),
              label: Text(l10n['hear_result_again']),
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
