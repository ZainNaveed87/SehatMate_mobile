import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFFF8FAFC);
  static const foreground = Color(0xFF0F172A);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF0F766E);
  static const primaryDark = Color(0xFF105E59);
  static const primaryLight = Color(0xFFCCFBF1);
  static const accentForeground = Color(0xFF134E4A);
  static const secondary = Color(0xFFF1F5F9);
  static const muted = Color(0xFF64748B);
  static const subtle = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const input = Color(0xFFCBD5E1);
  static const success = Color(0xFF16A34A);
  static const successForeground = Color(0xFF006828);
  static const successSoft = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97708);
  static const warningForeground = Color(0xFF9E5200);
  static const warningSoft = Color(0xFFFEF3C7);
  static const critical = Color(0xFFDC2626);
  static const criticalForeground = Color(0xFFBE1218);
  static const criticalSoft = Color(0xFFFEE2E2);
  static const info = Color(0xFF2563EB);
  static const infoForeground = Color(0xFF1B53CF);
  static const infoSoft = Color(0xFFDBEAFE);
}

abstract final class AppRadii {
  static const sm = 10.0;
  static const md = 12.0;
  static const lg = 14.0;
  static const xl = 18.0;
  static const xxl = 22.0;
  static const xxxl = 26.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: AppColors.foreground,
      displayColor: AppColors.foreground,
    );
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: const BorderSide(color: AppColors.input),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.card,
        error: AppColors.critical,
      ),
      textTheme: textTheme.copyWith(
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.55),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.45,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.39,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.foreground,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          foregroundColor: AppColors.foreground,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
