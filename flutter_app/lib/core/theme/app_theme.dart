import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Centralised Ludo Royale theme.
class AppTheme {
  AppTheme._();

  static const Color primary       = Color(AppColors.deepPurple);
  static const Color secondary     = Color(AppColors.royalBlue);
  static const Color accent         = Color(AppColors.goldenYellow);
  static const Color background    = Color(AppColors.darkNavy);
  static const Color cardBackground= Color(AppColors.cardPurple);
  static const Color cardAlt       = Color(AppColors.cardBlue);
  static const Color textPrimary   = Color(AppColors.textPrimary);
  static const Color textSecondary = Color(AppColors.textSecondary);
  static const Color danger        = Color(AppColors.redValue);
  static const Color success       = Color(AppColors.greenValue);

  // Player colors
  static const Color redPlayer    = Color(AppColors.redValue);
  static const Color greenPlayer  = Color(AppColors.greenValue);
  static const Color yellowPlayer = Color(AppColors.yellowValue);
  static const Color bluePlayer   = Color(AppColors.blueValue);

  static Color playerColor(String name) {
    switch (name) {
      case 'red':    return redPlayer;
      case 'green':  return greenPlayer;
      case 'yellow': return yellowPlayer;
      case 'blue':   return bluePlayer;
      default:       return Colors.white;
    }
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: secondary,
        surface: cardBackground,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: accent),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        bodyLarge: TextStyle(color: textPrimary, fontFamily: 'Poppins'),
        bodyMedium: TextStyle(color: textSecondary, fontFamily: 'Poppins'),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
      ),
    );
  }

  static LinearGradient primaryGradient() => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A148C), Color(0xFF1565C0)],
  );

  static LinearGradient goldGradient() => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC107), Color(0xFFFF6F00)],
  );

  static LinearGradient cardGradient() => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF261845), Color(0xFF1B2154)],
  );
}
