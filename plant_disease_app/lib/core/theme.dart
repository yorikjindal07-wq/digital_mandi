import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color _seedGreen = Color(0xFF2E7D32);
  static const Color _leafGreen = Color(0xFF4CAF50);
  static const Color _forestDark = Color(0xFF102315);
  static const Color _mintLight = Color(0xFFDDF3D0);
  static const Color _soilWarm = Color(0xFFB07A2A);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedGreen,
      brightness: Brightness.light,
    ),
    textTheme: _textTheme(Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFF5F8F1),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: _forestDark,
      ),
      iconTheme: const IconThemeData(color: _forestDark),
      actionsIconTheme: const IconThemeData(color: _forestDark),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _leafGreen,
        foregroundColor: _forestDark,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
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
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: _seedGreen.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _leafGreen, width: 1.4),
      ),
      labelStyle: GoogleFonts.poppins(
        color: _forestDark.withValues(alpha: 0.72),
        fontSize: 13,
      ),
      hintStyle: GoogleFonts.poppins(
        color: _forestDark.withValues(alpha: 0.48),
        fontSize: 14,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _mintLight,
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: _leafGreen.withValues(alpha: 0.2)),
    ),
    extensions: const [AppColors.light],
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedGreen,
      brightness: Brightness.dark,
    ),
    textTheme: _textTheme(Brightness.dark),
    scaffoldBackgroundColor: const Color(0xFF081109),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1B2A1C),
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFA6DB94),
        foregroundColor: _forestDark,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF132517),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF122015),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFA6DB94), width: 1.4),
      ),
      labelStyle: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 13,
      ),
      hintStyle: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 14,
      ),
    ),
    extensions: const [AppColors.dark],
  );

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    return GoogleFonts.poppinsTextTheme(base);
  }
}

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
    soil: AppTheme._soilWarm,
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
  }) {
    return AppColors(
      healthy: healthy ?? this.healthy,
      disease: disease ?? this.disease,
      warning: warning ?? this.warning,
      soil: soil ?? this.soil,
      sky: sky ?? this.sky,
    );
  }

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
