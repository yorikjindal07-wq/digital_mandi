import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class TreatmentService {
  TreatmentService._();

  static final TreatmentService instance = TreatmentService._();

  final http.Client _client = http.Client();
  Map<String, dynamic>? _assetTreatmentsCache;
  final Map<String, Map<String, dynamic>> _backendEntryCache = {};

  Future<Map<String, dynamic>> getDiseaseEntry(String disease) async {
    final normalizedDisease = disease.trim();
    if (normalizedDisease.isEmpty) {
      return const {};
    }

    final cachedBackendEntry = _backendEntryCache[normalizedDisease];
    if (cachedBackendEntry != null) {
      return cachedBackendEntry;
    }

    final backendUri = AppConstants.backendUri(
      '/api/v1/treatments/$normalizedDisease',
    );

    if (backendUri != null) {
      try {
        final response = await _client
            .get(backendUri)
            .timeout(AppConstants.apiTimeout);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            _backendEntryCache[normalizedDisease] = decoded;
            return decoded;
          }
        } else if (response.statusCode != 404) {
          debugPrint(
            'Treatment backend request failed for $normalizedDisease with status ${response.statusCode}. Falling back to asset data.',
          );
        }
      } catch (error) {
        debugPrint(
          'Treatment backend fetch failed for $normalizedDisease: $error',
        );
      }
    }

    final assetTreatments = await _loadAssetTreatments();
    final assetEntry = assetTreatments[normalizedDisease];
    if (assetEntry is Map<String, dynamic>) {
      return assetEntry;
    }

    return const {};
  }

  Future<Map<String, dynamic>> _loadAssetTreatments() async {
    final cached = _assetTreatmentsCache;
    if (cached != null) {
      return cached;
    }

    try {
      final jsonString = await rootBundle.loadString(
        AppConstants.treatmentsPath,
      );
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        _assetTreatmentsCache = decoded;
        return decoded;
      }
    } catch (error) {
      debugPrint('Failed to load fallback treatment asset: $error');
    }

    const empty = <String, dynamic>{};
    _assetTreatmentsCache = empty;
    return empty;
  }
}
