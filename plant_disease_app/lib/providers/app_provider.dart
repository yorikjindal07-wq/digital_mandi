// ─────────────────────────────────────────────
// providers/app_provider.dart
// Global app state managed with Provider.
// Keeps: current language, theme mode, and
// any cross-screen shared state.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../data/local_db.dart';

class AppProvider extends ChangeNotifier {
  AppProvider() {
    _loadSettings();
  }

  // ── State ────────────────────────────────────
  String _languageCode = 'en';
  ThemeMode _themeMode = ThemeMode.system;
  bool _isFirstLaunch = true;

  // ── Getters ───────────────────────────────────
  String get languageCode => _languageCode;
  ThemeMode get themeMode => _themeMode;
  bool get isFirstLaunch => _isFirstLaunch;
  AppLocalizations get l10n => AppLocalizations.of(_languageCode);

  // ── Setters ───────────────────────────────────
  Future<void> setLanguage(String code) async {
    if (!AppConstants.supportedLanguages.contains(code)) return;
    _languageCode = code;
    await LocalDatabase.instance.saveSetting('language', code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await LocalDatabase.instance.saveSetting('theme', mode.name);
    notifyListeners();
  }

  Future<void> completeFirstLaunch() async {
    _isFirstLaunch = false;
    await LocalDatabase.instance.saveSetting('first_launch', 'false');
    notifyListeners();
  }

  // ── Load persisted settings ───────────────────
  Future<void> _loadSettings() async {
    final db = LocalDatabase.instance;
    final lang = await db.getSetting('language');
    if (lang != null) _languageCode = lang;

    final theme = await db.getSetting('theme');
    if (theme != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == theme,
        orElse: () => ThemeMode.system,
      );
    }

    final firstLaunch = await db.getSetting('first_launch');
    _isFirstLaunch = firstLaunch == null;

    notifyListeners();
  }
}
