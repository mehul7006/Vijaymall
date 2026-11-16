import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Design tokens ported from assets/styles.css (:root and base rules).
class AppTheme {
  AppTheme._();

  static const String uiFont = 'PlusJakartaSans';
  static const String displayFont = 'DMSerifDisplay';
  static const String gujaratiFont = 'HindVadodara';

  static const double cardRadius = 20;
  static const double panelRadius = 24;
  static const double fieldRadius = 14;
  static const double chipRadius = 10;
  static const double pillRadius = 999;

  // Spacing scale from styles.css
  static const double sp1 = 4;
  static const double sp2 = 8;
  static const double sp3 = 12;
  static const double sp4 = 16;
  static const double sp5 = 20;
  static const double sp6 = 24;
  static const double sp7 = 32;
  static const double sp8 = 40;

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.red,
        primary: AppColors.red,
        secondary: AppColors.navy2,
        error: AppColors.red3,
        surface: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.bg,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base
        .copyWith(
          // Body / UI text defaults to Plus Jakarta Sans
          bodyLarge: const TextStyle(
            fontFamily: uiFont,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
          ),
          bodyMedium: const TextStyle(
            fontFamily: uiFont,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
          ),
          bodySmall: const TextStyle(
            fontFamily: uiFont,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w400,
            color: AppColors.ink3,
          ),
          labelLarge: const TextStyle(
            fontFamily: uiFont,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          labelMedium: const TextStyle(
            fontFamily: uiFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
            color: AppColors.ink2,
          ),
          labelSmall: const TextStyle(
            fontFamily: uiFont,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
            color: AppColors.ink3,
          ),
          titleLarge: const TextStyle(
            fontFamily: uiFont,
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
          titleMedium: const TextStyle(
            fontFamily: uiFont,
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
          titleSmall: const TextStyle(
            fontFamily: uiFont,
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          // Display headlines use DM Serif Display
          displayLarge: const TextStyle(
            fontFamily: displayFont,
            fontSize: 48,
            height: 1.02,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
          ),
          displayMedium: const TextStyle(
            fontFamily: displayFont,
            fontSize: 40,
            height: 1.05,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
          ),
          displaySmall: const TextStyle(
            fontFamily: displayFont,
            fontSize: 32,
            height: 1.08,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
          ),
          headlineLarge: const TextStyle(
            fontFamily: uiFont,
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        )
        .apply(
          // Gujarati strings fall back to Hind Vadodara
          fontFamily: uiFont,
          decorationColor: AppColors.ink,
        );
  }

  static TextStyle guj({double size = 14, FontWeight w = FontWeight.w400, Color? color}) =>
      TextStyle(fontFamily: gujaratiFont, fontSize: size, height: 1.5, fontWeight: w, color: color ?? AppColors.ink);
}
