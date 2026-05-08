import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider();

  final AuthService _authService = AuthService.instance;

  bool _isLoading = false;
  bool _isReady = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  bool get isAuthenticated => _authService.isAuthenticated;
  String? get errorMessage => _errorMessage;
  AuthSession? get session => _authService.session;
  AuthUser? get user => _authService.currentUser;

  Future<void> initialize() async {
    if (_isReady) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _authService.initialize();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      _isReady = true;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    return _runAuthAction(
      () => _authService.login(email: email, password: password),
    );
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    return _runAuthAction(
      () => _authService.register(email: email, password: password),
    );
  }

  Future<void> logout() async {
    _errorMessage = null;
    await _authService.logout();
    notifyListeners();
  }

  Future<void> refreshSession() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.refreshSession();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _runAuthAction(Future<AuthSession> Function() action) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      await action();
      return true;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('AuthException: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
