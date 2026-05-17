import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/ml_service.dart';
import '../services/sync_service.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _selectedImage;
  bool _isAnalyzing = false;
  String _selectedCrop = 'tomato';

  static const _crops = ['tomato', 'potato', 'wheat', 'rice', 'cotton'];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    unawaited(_warmUpModels());
  }

  Future<void> _warmUpModels() async {
    if (MLService.instance.isLoaded) return;

    try {
      await MLService.instance.loadModels();
    } catch (e) {
      debugPrint('Camera screen ML warm-up failed: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedImage = File(picked.path);
      _isAnalyzing = false;
    });
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) {
      return;
    }

    final l10n = context.read<AppProvider>().l10n;
    if (!MLService.instance.isLoaded) {
      _showSnackBar(l10n['ai_model_wait']);
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final prediction = await MLService.instance.detectDisease(
        _selectedImage!,
        crop: _selectedCrop,
      );

      final report = DiseaseReport(
        crop: _selectedCrop,
        disease: prediction.disease,
        confidence: prediction.confidence,
        imagePath: _selectedImage!.path,
        createdAt: DateTime.now(),
      );
      await SyncService.instance.saveReportLocally(report);

      if (!mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultScreen(prediction: prediction, imageFile: _selectedImage!),
        ),
      );
    } catch (e, st) {
      debugPrint('Analysis failed: $e');
      debugPrintStack(stackTrace: st);
      final message = e is AppException
          ? e.message
          : l10n['analysis_failed_retry'];
      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n['detect_disease'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      '${l10n['crop_label']}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCrop,
                          items: _crops
                              .map(
                                (crop) => DropdownMenuItem(
                                  value: crop,
                                  child: Text(_localizedCropName(l10n, crop)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedCrop = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  color: scheme.primary.withValues(alpha: 0.05),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 64,
                            color: scheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n['no_image_selected'],
                            style: TextStyle(
                              color: scheme.primary.withValues(alpha: 0.7),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n['tap_select_gallery'],
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: Text(l10n['select_gallery']),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(l10n['capture_image']),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isAnalyzing
                  ? SizedBox(
                      height: 52,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 12),
                          Text(l10n['analyzing']),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _selectedImage != null ? _analyzeImage : null,
                      icon: const Icon(Icons.search_rounded),
                      label: Text(l10n['analyze_now']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            _TipsCard(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.l10n});

  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tips_and_updates, color: Color(0xFFF57F17)),
                const SizedBox(width: 8),
                Text(
                  l10n['tips_title'],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...[
              l10n['tips_1'],
              l10n['tips_2'],
              l10n['tips_3'],
              l10n['tips_4'],
            ].map(
              (tip) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(tip, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _localizedCropName(AppL10n l10n, String crop) {
  switch (crop) {
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
      return crop[0].toUpperCase() + crop.substring(1);
  }
}
