import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
  });

  final int id;
  final String email;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      lastLoginAt: DateTime.tryParse(json['last_login_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'is_active': isActive,
    'created_at': createdAt.toUtc().toIso8601String(),
    'last_login_at': lastLoginAt?.toUtc().toIso8601String(),
  };
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;
  final AuthUser user;

  bool get isAccessTokenFresh =>
      accessToken.isNotEmpty &&
      accessTokenExpiresAt.isAfter(
        DateTime.now().toUtc().add(const Duration(seconds: 30)),
      );

  bool get canRefresh =>
      refreshToken.isNotEmpty &&
      refreshTokenExpiresAt.isAfter(
        DateTime.now().toUtc().add(const Duration(seconds: 30)),
      );

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      accessTokenExpiresAt:
          DateTime.tryParse(json['access_token_expires_at'] as String? ?? '') ??
          DateTime.now(),
      refreshTokenExpiresAt:
          DateTime.tryParse(
            json['refresh_token_expires_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      user: AuthUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'access_token_expires_at': accessTokenExpiresAt.toUtc().toIso8601String(),
    'refresh_token_expires_at': refreshTokenExpiresAt.toUtc().toIso8601String(),
    'user': user.toJson(),
  };
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _sessionStorageKey = 'auth_session';

  final http.Client _client = http.Client();

  AuthSession? _session;
  Future<AuthSession?>? _refreshFuture;
  bool _isInitialized = false;

  AuthSession? get session => _session;
  AuthUser? get currentUser => _session?.user;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _session != null;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;
    if (!AppConstants.hasBackendBaseUrl) {
      return;
    }

    final serialized = await _storage.read(key: _sessionStorageKey);
    if (serialized == null || serialized.trim().isEmpty) {
      return;
    }

    try {
      final payload = jsonDecode(serialized) as Map<String, dynamic>;
      _session = AuthSession.fromJson(payload);
      await getValidAccessToken();
    } catch (error) {
      debugPrint('Failed to restore auth session: $error');
      await logout();
    }
  }

  Future<AuthSession> register({
    required String email,
    required String password,
  }) {
    return _submitCredentials('/api/v1/auth/register', email, password);
  }

  Future<AuthSession> login({required String email, required String password}) {
    return _submitCredentials('/api/v1/auth/login', email, password);
  }

  Future<AuthSession?> refreshSession() async {
    if (_refreshFuture != null) {
      return _refreshFuture;
    }
    _refreshFuture = _performRefresh();
    final refreshed = await _refreshFuture;
    _refreshFuture = null;
    return refreshed;
  }

  Future<String?> getValidAccessToken() async {
    final current = _session;
    if (current == null) {
      return null;
    }
    if (current.isAccessTokenFresh) {
      return current.accessToken;
    }
    if (!current.canRefresh) {
      await logout();
      return null;
    }

    final refreshed = await refreshSession();
    return refreshed?.accessToken;
  }

  Future<Map<String, String>?> buildAuthorizedJsonHeaders() async {
    final token = await getValidAccessToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> logout() async {
    _session = null;
    await _storage.delete(key: _sessionStorageKey);
  }

  Future<AuthSession> _submitCredentials(
    String path,
    String email,
    String password,
  ) async {
    final authUri = AppConstants.backendUri(path);
    if (authUri == null) {
      throw AuthException(
        'Secure backend URL is not configured. Set BACKEND_BASE_URL first.',
      );
    }

    final response = await _client
        .post(
          authUri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(AppConstants.apiTimeout);

    return _handleAuthResponse(response);
  }

  Future<AuthSession?> _performRefresh() async {
    final current = _session;
    final refreshUri = AppConstants.backendUri('/api/v1/auth/refresh');
    if (current == null || refreshUri == null || !current.canRefresh) {
      return null;
    }

    try {
      final response = await _client
          .post(
            refreshUri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh_token': current.refreshToken}),
          )
          .timeout(AppConstants.apiTimeout);
      return await _handleAuthResponse(response);
    } catch (error) {
      debugPrint('Token refresh failed: $error');
      await logout();
      return null;
    }
  }

  Future<AuthSession> _handleAuthResponse(http.Response response) async {
    final data = _decodeJson(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final session = AuthSession.fromJson(data);
      _session = session;
      await _storage.write(
        key: _sessionStorageKey,
        value: jsonEncode(session.toJson()),
      );
      return session;
    }

    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      throw AuthException(detail.trim());
    }

    throw AuthException(
      'Authentication failed with status ${response.statusCode}.',
    );
  }

  Map<String, dynamic> _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return const {};
  }
}
