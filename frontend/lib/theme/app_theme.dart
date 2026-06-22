import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primaryBlack = Color(0xFF1D1D1F);
  static const Color secondaryGray = Color(0xFF86868B);
  static const Color borderGray = Color(0xFFE5E5EA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color fillGray = Color(0xFFF5F5F7);
  static const Color pageBackground = Color(0xFFF8F9FC);
  static const Color accentBlue = Color(0xFF0071E3);

  // Design system — purple accent UI
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color primaryPurpleLight = Color(0xFFF0EDFF);
  static const Color statBlue = Color(0xFF4A90E2);
  static const Color statGreen = Color(0xFF34C759);
  static const Color statOrange = Color(0xFFFF9500);
  static const Color statPurple = Color(0xFF7C6CF6);
  static const Color priorityHigh = Color(0xFFFF3B30);
  static const Color priorityMedium = Color(0xFFFF9500);
  static const Color cardShadow = Color(0x0F000000);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.light,
      surface: surfaceWhite,
      onSurface: primaryBlack,
      primary: primaryPurple,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pageBackground,
      fontFamily: '.AppleSystemUIFont',
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryPurple,
        unselectedLabelColor: secondaryGray,
        indicatorColor: primaryPurple,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillGray,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGray, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlack, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1),
        ),
        hintStyle: const TextStyle(
          color: secondaryGray,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: secondaryGray,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlack,
          backgroundColor: surfaceWhite,
          side: const BorderSide(color: borderGray, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryPurple,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  static BoxDecoration cardDecoration = BoxDecoration(
    color: surfaceWhite,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: borderGray.withValues(alpha: 0.6)),
    boxShadow: const [
      BoxShadow(
        color: cardShadow,
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  );
}
