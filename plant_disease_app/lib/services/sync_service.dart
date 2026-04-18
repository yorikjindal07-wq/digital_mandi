// ─────────────────────────────────────────────
// services/sync_service.dart
// Handles the offline → online sync cycle:
//   1. Queue all reports locally in SQLite
//   2. Check connectivity periodically
//   3. When online, POST unsynced reports to backend
//   4. Mark synced rows once confirmed
// ─────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants.dart';
import '../data/local_db.dart';
import '../models/models.dart';

enum SyncStatus { idle, syncing, done, failed, offline }

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  final _connectivity = Connectivity();

  // ── Start background sync listener ───────────
  void startListening() {
    _connectivity.onConnectivityChanged.listen((results) async {
      final online = results.any(
        (r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi,
      );
      if (online) {
        debugPrint('🌐 Back online — starting sync');
        await syncPendingReports();
      }
    });
  }

  // ── Check if device is online ─────────────────
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any(
      (r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi,
    );
  }

  // ── Sync all unsynced reports ─────────────────
  Future<int> syncPendingReports() async {
    if (_status == SyncStatus.syncing) return 0;

    final online = await isOnline();
    if (!online) {
      _status = SyncStatus.offline;
      return 0;
    }

    _status = SyncStatus.syncing;
    int synced = 0;

    try {
      final db = LocalDatabase.instance;
      final reports = await db.getUnsyncedReports();
      debugPrint('📤 Syncing ${reports.length} reports...');

      for (final report in reports) {
        try {
          final response = await http
              .post(
                Uri.parse('${AppConstants.backendBaseUrl}/report'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'crop': report.crop,
                  'disease': report.disease,
                  'confidence': report.confidence,
                }),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200 && report.id != null) {
            await db.markSynced(report.id!);
            synced++;
          }
        } catch (e) {
          debugPrint('Failed to sync report ${report.id}: $e');
          // Keep in queue — will retry next time
        }
      }

      _status = SyncStatus.done;
      debugPrint('✅ Synced $synced/${reports.length} reports');
    } catch (e) {
      _status = SyncStatus.failed;
      debugPrint('Sync failed: $e');
    }

    return synced;
  }

  // ── Save report locally (always offline-first) ─
  Future<int> saveReportLocally(DiseaseReport report) async {
    return LocalDatabase.instance.insertReport(report);
  }
}
