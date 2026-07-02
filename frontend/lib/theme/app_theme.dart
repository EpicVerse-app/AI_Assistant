import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Orzen warm gradient palette (gold tan → bronze → espresso)
  static const Color gradientTop = Color(0xFFC9A873);
  static const Color gradientMid = Color(0xFF6B4E32);
  static const Color gradientBottom = Color(0xFF1A1510);

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientTop, gradientMid, gradientBottom],
    stops: [0.0, 0.42, 1.0],
  );

  static const Color primaryBlack = Color(0xFFF5ECD8);
  static const Color secondaryGray = Color(0xFFB8A088);
  static const Color borderGray = Color(0xFF5C4A38);
  static const Color surfaceWhite = Color(0xFF3A2E24);
  static const Color fillGray = Color(0xFF2D241C);
  static const Color pageBackground = Color(0xFF1A1510);
  static const Color accentBlue = Color(0xFFD4AF6A);

  // Button accent — unchanged per request
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color primaryPurpleLight = Color(0xFF4A3D66);

  // "Add" action accent (FAB, New Meeting button) — gold/bronze gradient
  static const Color addButtonStart = Color(0xFF8D6736);
  static const Color addButtonEnd = Color(0xFFB18850);
  static const LinearGradient addButtonGradient = LinearGradient(
    colors: [addButtonStart, addButtonEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color statBlue = Color(0xFFD4AF6A);
  static const Color statGreen = Color(0xFF8FB86A);
  static const Color statOrange = Color(0xFFE8A54B);
  static const Color statPurple = Color(0xFFC9A873);
  static const Color priorityHigh = Color(0xFFFF3B30);
  static const Color priorityMedium = Color(0xFFFF9500);
  static const Color cardShadow = Color(0x40000000);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentBlue,
      brightness: Brightness.dark,
      surface: surfaceWhite,
      onSurface: primaryBlack,
      primary: accentBlue,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: '.AppleSystemUIFont',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xCC2A2218),
        foregroundColor: primaryBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: accentBlue,
        unselectedLabelColor: secondaryGray,
        indicatorColor: accentBlue,
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
          borderSide: const BorderSide(color: accentBlue, width: 1.5),
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

  static BoxDecoration get pageBackgroundDecoration => const BoxDecoration(
        gradient: pageGradient,
      );

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
