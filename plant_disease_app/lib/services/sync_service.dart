// ═══════════════════════════════════════════════════════════════
// lib/services/sync_service.dart
// Background sync for disease reports and chat history
// Handles offline-first pattern with retry logic
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants.dart';
import '../data/local_db.dart' as local_db;
import '../models/models.dart';

class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  SyncStatus _status = SyncStatus.idle;
  SyncResult? _lastResult;
  StreamSubscription? _connectivitySubscription;
  Timer? _syncTimer;

  bool _isSyncing = false;
  int _failureCount = 0;
  bool _syncDisabledForSession = false;

  SyncStatus get status => _status;
  SyncResult? get lastResult => _lastResult;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _status != SyncStatus.offline;

  /// ──────────────────────────────────────────────────────────────
  /// INITIALIZATION & CLEANUP
  /// ──────────────────────────────────────────────────────────────

  /// Start listening to connectivity changes and periodic sync
  Future<void> initialize() async {
    try {
      debugPrint('🔄 Initializing SyncService...');

      if (!AppConstants.hasBackendBaseUrl) {
        debugPrint(
          'SyncService disabled: BACKEND_BASE_URL is not configured for this run.',
        );
        _status = SyncStatus.idle;
        notifyListeners();
        return;
      }

      // Check initial connectivity
      await _checkConnectivity();

      // Listen to connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        _handleConnectivityChange,
      );

      // Start periodic sync timer
      _syncTimer = Timer.periodic(
        AppConstants.syncCheckInterval,
        (_) => _periodicSync(),
      );

      debugPrint('✅ SyncService initialized');
    } catch (e) {
      debugPrint('🔥 SyncService initialization error: $e');
    }
  }

  void startListening() {
    initialize();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    try {
      debugPrint('✅ SyncService disposed');
    } catch (e) {
      debugPrint('⚠️  Dispose error: $e');
    }
    super.dispose();
  }

  /// ──────────────────────────────────────────────────────────────
  /// CONNECTIVITY MANAGEMENT
  /// ──────────────────────────────────────────────────────────────

  Future<bool> checkConnectivity() async {
    return _checkConnectivity();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final online = results.any(
        (r) =>
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.ethernet,
      );

      _status = online ? SyncStatus.idle : SyncStatus.offline;
      debugPrint('📡 Connectivity: ${online ? 'ONLINE' : 'OFFLINE'}');
      notifyListeners();

      return online;
    } catch (e) {
      debugPrint('⚠️  Connectivity check error: $e');
      return false;
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final online = results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet,
    );

    if (online && _status == SyncStatus.offline) {
      debugPrint('🌐 Back online - triggering sync');
      _status = SyncStatus.idle;
      syncPendingData();
    } else if (!online) {
      _status = SyncStatus.offline;
      debugPrint('📴 Went offline');
    }

    notifyListeners();
  }

  /// ──────────────────────────────────────────────────────────────
  /// SYNC OPERATIONS
  /// ──────────────────────────────────────────────────────────────

  /// Sync all pending disease reports
  Future<SyncResult> syncPendingData() async {
    if (_isSyncing) {
      debugPrint('⏳ Sync already in progress');
      return _lastResult ?? SyncResult(status: SyncStatus.idle, totalItems: 0);
    }

    if (!AppConstants.hasBackendBaseUrl || _syncDisabledForSession) {
      final message = !AppConstants.hasBackendBaseUrl
          ? 'Sync skipped: BACKEND_BASE_URL is not configured.'
          : 'Sync skipped: backend sync is disabled for this session after client errors.';
      debugPrint(message);
      _status = SyncStatus.idle;
      _lastResult = SyncResult(
        status: SyncStatus.idle,
        totalItems: 0,
        errors: [message],
      );
      notifyListeners();
      return _lastResult!;
    }

    try {
      _isSyncing = true;
      _status = SyncStatus.syncing;
      notifyListeners();

      debugPrint('🔄 Starting sync...');

      final db = local_db.LocalDatabase.instance;
      final reports = await db.getUnsyncedReports();

      if (reports.isEmpty) {
        debugPrint('✅ No items to sync');
        _status = SyncStatus.success;
        _failureCount = 0;
        _lastResult = SyncResult(
          status: SyncStatus.success,
          totalItems: 0,
          successCount: 0,
        );
        notifyListeners();
        return _lastResult!;
      }

      debugPrint('📤 Syncing ${reports.length} disease reports...');

      int successCount = 0;
      int failureCount = 0;
      final errors = <String>[];

      for (final report in reports) {
        try {
          final synced = await _syncReport(report);
          if (synced) {
            successCount++;
            if (report.id != null) {
              await db.markSynced(report.id!);
            }
          } else {
            failureCount++;
            if (report.id != null) {
              await db.incrementSyncAttempts(report.id!);
            }
          }
        } catch (e) {
          failureCount++;
          errors.add('Report ${report.id}: $e');
          if (report.id != null) {
            await db.incrementSyncAttempts(report.id!);
          }
        }
      }

      // Determine final status
      SyncStatus finalStatus;
      if (failureCount == 0) {
        finalStatus = SyncStatus.success;
        _failureCount = 0;
      } else if (successCount > 0) {
        finalStatus = SyncStatus.partialSuccess;
        _failureCount++;
      } else {
        finalStatus = SyncStatus.failed;
        _failureCount++;
      }

      _lastResult = SyncResult(
        status: finalStatus,
        totalItems: reports.length,
        successCount: successCount,
        failureCount: failureCount,
        errors: errors,
      );

      // Log sync result
      await db.logSync(_lastResult!);

      _status = finalStatus;
      debugPrint('✅ Sync complete: $successCount/${reports.length} success');
      notifyListeners();

      return _lastResult!;
    } catch (e) {
      debugPrint('🔥 Sync error: $e');
      _status = SyncStatus.failed;
      _failureCount++;
      _lastResult = SyncResult(
        status: SyncStatus.failed,
        totalItems: 0,
        errors: [e.toString()],
      );
      notifyListeners();
      return _lastResult!;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single disease report
  Future<bool> _syncReport(DiseaseReport report) async {
    try {
      final payload = {
        'crop': report.crop,
        'disease': report.disease,
        'confidence': report.confidence,
        'created_at': report.createdAt.toIso8601String(),
      };

      debugPrint('📨 Syncing report: ${report.disease}');

      final response = await http
          .post(
            Uri.parse('${AppConstants.backendBaseUrl}/reports'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(AppConstants.syncTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Report synced successfully');
        return true;
      } else {
        if (response.statusCode == 404 ||
            response.statusCode == 401 ||
            response.statusCode == 403) {
          _syncDisabledForSession = true;
          debugPrint(
            'Disabling sync for this session after backend client error: ${response.statusCode}',
          );
        }
        debugPrint('⚠️  Report sync failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('🔥 Report sync exception: $e');
      return false;
    }
  }

  /// ──────────────────────────────────────────────────────────────
  /// PERIODIC SYNC
  /// ──────────────────────────────────────────────────────────────

  Future<void> _periodicSync() async {
    if (_isSyncing ||
        _status == SyncStatus.offline ||
        _syncDisabledForSession) {
      return;
    }

    if (_failureCount >= AppConstants.maxSyncRetries) {
      debugPrint('⏸️  Max retries reached, stopping periodic sync');
      return;
    }

    final isOnline = await _checkConnectivity();
    if (isOnline) {
      await syncPendingData();
    }
  }

  /// ──────────────────────────────────────────────────────────────
  /// MANUAL SAVE OPERATIONS
  /// ──────────────────────────────────────────────────────────────

  /// Save a disease report locally (offline-first)
  Future<int> saveDiseaseReport(DiseaseReport report) async {
    try {
      final db = local_db.LocalDatabase.instance;
      final id = await db.insertReport(report);
      debugPrint('✅ Disease report saved locally: ID=$id');

      // Try to sync immediately if online
      if (!_syncDisabledForSession &&
          AppConstants.hasBackendBaseUrl &&
          await _checkConnectivity()) {
        unawaited(syncPendingData());
      }

      return id;
    } catch (e) {
      debugPrint('🔥 Save report error: $e');
      rethrow;
    }
  }

  Future<int> saveReportLocally(DiseaseReport report) async {
    return saveDiseaseReport(report);
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final db = local_db.LocalDatabase.instance;
      final pendingReports = await db.getUnsyncedReports();
      final dbStats = await db.getDatabaseStats();

      return {
        'pending_sync': pendingReports.length,
        'total_reports': dbStats['reports'] ?? 0,
        'total_messages': dbStats['messages'] ?? 0,
        'last_sync': _lastResult?.timestamp.toIso8601String(),
        'sync_status': _status.name,
        'is_online': isOnline,
        'failure_count': _failureCount,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Clear all sync data (for testing)
  Future<void> clearSyncData() async {
    try {
      final db = local_db.LocalDatabase.instance;
      final reports = await db.getUnsyncedReports();
      for (final report in reports) {
        if (report.id != null) {
          await db.deleteReport(report.id!);
        }
      }
      _failureCount = 0;
      _lastResult = null;
      debugPrint('✅ Sync data cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️  Clear sync error: $e');
    }
  }
}
