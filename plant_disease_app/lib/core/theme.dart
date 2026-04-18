// ─────────────────────────────────────────────
// core/theme.dart
// Farming-inspired Material 3 theme.
// Supports light and dark modes out of the box.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Brand colours ────────────────────────────
  static const Color _seedGreen = Color(0xFF2E7D32); // rich farm green
  static const Color _leafGreen = Color(0xFF4CAF50);
  static const Color _soilBrown = Color(0xFF795548);
  static const Color _skyBlue = Color(0xFF0288D1);
  static const Color _warningAmber = Color(0xFFF9A825);
  static const Color _dangerRed = Color(0xFFC62828);

  // ── Light theme ──────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedGreen,
      brightness: Brightness.light,
    ),
    textTheme: _textTheme(Brightness.light),
    appBarTheme: AppBarTheme(
      backgroundColor: _seedGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _seedGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _leafGreen.withOpacity(0.12),
      labelStyle: GoogleFonts.poppins(fontSize: 12),
      side: BorderSide(color: _leafGreen.withOpacity(0.3)),
    ),
    extensions: const [AppColors.light],
  );

  // ── Dark theme ───────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedGreen,
      brightness: Brightness.dark,
    ),
    textTheme: _textTheme(Brightness.dark),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1B2A1C),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      color: const Color(0xFF1E2E1F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    extensions: const [AppColors.dark],
  );

  // ── Text theme ───────────────────────────────
  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    return GoogleFonts.poppinsTextTheme(base);
  }
}

// ─────────────────────────────────────────────
// Custom theme extension for semantic colours
// ─────────────────────────────────────────────
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.healthy,
    required this.disease,
    required this.warning,
    required this.soil,
    required this.sky,
  });

  final Color healthy;
  final Color disease;
  final Color warning;
  final Color soil;
  final Color sky;

  static const light = AppColors(
    healthy: Color(0xFF2E7D32),
    disease: Color(0xFFC62828),
    warning: Color(0xFFF9A825),
    soil: Color(0xFF795548),
    sky: Color(0xFF0288D1),
  );

  static const dark = AppColors(
    healthy: Color(0xFF66BB6A),
    disease: Color(0xFFEF9A9A),
    warning: Color(0xFFFFCA28),
    soil: Color(0xFFBCAAA4),
    sky: Color(0xFF4FC3F7),
  );

  @override
  AppColors copyWith({
    Color? healthy,
    Color? disease,
    Color? warning,
    Color? soil,
    Color? sky,
  }) => AppColors(
    healthy: healthy ?? this.healthy,
    disease: disease ?? this.disease,
    warning: warning ?? this.warning,
    soil: soil ?? this.soil,
    sky: sky ?? this.sky,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      healthy: Color.lerp(healthy, other.healthy, t)!,
      disease: Color.lerp(disease, other.disease, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      soil: Color.lerp(soil, other.soil, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
    );
  }
}
