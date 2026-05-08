import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../data/local_db.dart' as local_db;
import '../models/models.dart';
import 'auth_service.dart';

class SyncService extends ChangeNotifier {
  SyncService._();

  static final SyncService instance = SyncService._();

  SyncStatus _status = SyncStatus.idle;
  SyncResult? _lastResult;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;

  bool _isSyncing = false;
  int _failureCount = 0;
  bool _syncDisabledForSession = false;

  SyncStatus get status => _status;
  SyncResult? get lastResult => _lastResult;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _status != SyncStatus.offline;

  Future<void> initialize() async {
    try {
      debugPrint('Initializing SyncService...');

      if (!AppConstants.hasBackendBaseUrl) {
        debugPrint(
          'SyncService disabled: BACKEND_BASE_URL is not configured for this run.',
        );
        _status = SyncStatus.idle;
        notifyListeners();
        return;
      }

      await _checkConnectivity();

      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        _handleConnectivityChange,
      );

      _syncTimer = Timer.periodic(
        AppConstants.syncCheckInterval,
        (_) => _periodicSync(),
      );

      debugPrint('SyncService initialized');
    } catch (error) {
      debugPrint('SyncService initialization error: $error');
    }
  }

  void startListening() {
    initialize();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<bool> checkConnectivity() async {
    return _checkConnectivity();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final online = results.any(
        (result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet,
      );

      _status = online ? SyncStatus.idle : SyncStatus.offline;
      notifyListeners();
      return online;
    } catch (error) {
      debugPrint('Connectivity check error: $error');
      return false;
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final online = results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );

    if (online && _status == SyncStatus.offline) {
      _status = SyncStatus.idle;
      unawaited(syncPendingData());
    } else if (!online) {
      _status = SyncStatus.offline;
    }

    notifyListeners();
  }

  Future<SyncResult> syncPendingData() async {
    if (_isSyncing) {
      return _lastResult ?? SyncResult(status: SyncStatus.idle, totalItems: 0);
    }

    if (!AppConstants.hasBackendBaseUrl || _syncDisabledForSession) {
      final message = !AppConstants.hasBackendBaseUrl
          ? 'Sync skipped: BACKEND_BASE_URL is not configured.'
          : 'Sync skipped: backend sync is disabled for this session after client errors.';
      _status = SyncStatus.idle;
      _lastResult = SyncResult(
        status: SyncStatus.idle,
        totalItems: 0,
        errors: [message],
      );
      notifyListeners();
      return _lastResult!;
    }

    final accessToken = await AuthService.instance.getValidAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      _status = SyncStatus.idle;
      _lastResult = SyncResult(
        status: SyncStatus.idle,
        totalItems: 0,
        errors: const [
          'Sync skipped: sign in first so reports can sync with your secure account.',
        ],
      );
      notifyListeners();
      return _lastResult!;
    }

    try {
      _isSyncing = true;
      _status = SyncStatus.syncing;
      notifyListeners();

      final db = local_db.LocalDatabase.instance;
      final reports = await db.getUnsyncedReports();

      if (reports.isEmpty) {
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

      var successCount = 0;
      var failureCount = 0;
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
        } catch (error) {
          failureCount++;
          errors.add('Report ${report.id}: $error');
          if (report.id != null) {
            await db.incrementSyncAttempts(report.id!);
          }
        }
      }

      final finalStatus = failureCount == 0
          ? SyncStatus.success
          : successCount > 0
          ? SyncStatus.partialSuccess
          : SyncStatus.failed;
      _failureCount = finalStatus == SyncStatus.success ? 0 : _failureCount + 1;

      _lastResult = SyncResult(
        status: finalStatus,
        totalItems: reports.length,
        successCount: successCount,
        failureCount: failureCount,
        errors: errors,
      );
      await db.logSync(_lastResult!);
      _status = finalStatus;
      notifyListeners();
      return _lastResult!;
    } catch (error) {
      _status = SyncStatus.failed;
      _failureCount++;
      _lastResult = SyncResult(
        status: SyncStatus.failed,
        totalItems: 0,
        errors: [error.toString()],
      );
      notifyListeners();
      return _lastResult!;
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _syncReport(DiseaseReport report) async {
    final syncUri = AppConstants.backendUri('/reports');
    if (syncUri == null) {
      return false;
    }

    final payload = {
      'crop': report.crop,
      'disease': report.disease,
      'confidence': report.confidence,
      'created_at': report.createdAt.toIso8601String(),
    };

    final response = await _postAuthorizedJson(syncUri, payload);
    if (response == null) {
      return false;
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    }

    if (response.statusCode == 404 || response.statusCode == 403) {
      _syncDisabledForSession = true;
    }

    if (response.statusCode == 401) {
      debugPrint('Secure sync requires signing in again.');
    }

    return false;
  }

  Future<void> _periodicSync() async {
    if (_isSyncing ||
        _status == SyncStatus.offline ||
        _syncDisabledForSession) {
      return;
    }

    if (_failureCount >= AppConstants.maxSyncRetries) {
      return;
    }

    final isOnlineNow = await _checkConnectivity();
    if (isOnlineNow) {
      await syncPendingData();
    }
  }

  Future<int> saveDiseaseReport(DiseaseReport report) async {
    final db = local_db.LocalDatabase.instance;
    final id = await db.insertReport(report);

    if (!_syncDisabledForSession &&
        AppConstants.hasBackendBaseUrl &&
        await _checkConnectivity()) {
      unawaited(syncPendingData());
    }

    return id;
  }

  Future<int> saveReportLocally(DiseaseReport report) async {
    return saveDiseaseReport(report);
  }

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
    } catch (error) {
      return {'error': error.toString()};
    }
  }

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
      notifyListeners();
    } catch (error) {
      debugPrint('Clear sync error: $error');
    }
  }

  Future<http.Response?> _postAuthorizedJson(
    Uri uri,
    Map<String, dynamic> payload,
  ) async {
    final headers = await AuthService.instance.buildAuthorizedJsonHeaders();
    if (headers == null) {
      return null;
    }

    var response = await http
        .post(uri, headers: headers, body: jsonEncode(payload))
        .timeout(AppConstants.syncTimeout);

    if (response.statusCode == 401) {
      final refreshedSession = await AuthService.instance.refreshSession();
      if (refreshedSession == null) {
        return response;
      }

      final retryHeaders = await AuthService.instance
          .buildAuthorizedJsonHeaders();
      if (retryHeaders == null) {
        return response;
      }

      response = await http
          .post(uri, headers: retryHeaders, body: jsonEncode(payload))
          .timeout(AppConstants.syncTimeout);
    }

    return response;
  }
}
