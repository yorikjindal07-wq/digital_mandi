// ─────────────────────────────────────────────
// screens/history_screen.dart
// Shows all past disease detection reports
// stored locally in SQLite.
// ─────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/local_db.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<DiseaseReport>? _reports;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final reports = await LocalDatabase.instance.getAllReports();
    if (mounted) {
      setState(() {
        _reports = reports;
        _loading = false;
      });
    }
  }

  Future<void> _deleteReport(DiseaseReport report) async {
    if (report.id == null) return;
    await LocalDatabase.instance.deleteReport(report.id!);
    _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n['history']),
        actions: [
          if (_reports != null && _reports!.isNotEmpty)
            Chip(
              label: Text('${_reports!.length} ${l10n['reports_suffix']}'),
              backgroundColor: scheme.primary.withValues(alpha: 0.1),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports == null || _reports!.isEmpty
          ? _EmptyState(l10n: l10n)
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _reports!.length,
                itemBuilder: (context, index) {
                  final report = _reports![index];
                  return _ReportCard(
                    report: report,
                    onDelete: () => _deleteReport(report),
                  );
                },
              ),
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onDelete});
  final DiseaseReport report;
  final VoidCallback onDelete;

  Color _colorForDisease(String disease) {
    if (disease == 'healthy') return Colors.green;
    if (disease.contains('blight')) return Colors.red;
    if (disease.contains('mold')) return Colors.orange;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForDisease(report.disease);
    final l10n = context.watch<AppProvider>().l10n;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading:
            report.imagePath != null && File(report.imagePath!).existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(report.imagePath!),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            : CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Icons.eco, color: color),
              ),
        title: Text(
          report.disease.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 13,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n['crop_short_label']}: ${_localizedHistoryCropName(l10n, report.crop)}  •  ${(report.confidence * 100).toStringAsFixed(1)}% ${l10n['confidence_suffix']}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDate(report.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sync indicator
            Icon(
              report.synced ? Icons.cloud_done : Icons.cloud_off,
              size: 16,
              color: report.synced ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(l10n['delete_report_title']),
                  content: Text(l10n['delete_report_message']),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n['cancel']),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                      child: Text(
                        l10n['delete'],
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});
  final dynamic l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📋', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            l10n['no_reports_title'],
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n['no_reports_subtitle'],
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

String _localizedHistoryCropName(AppL10n l10n, String crop) {
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
      return crop;
  }
}
