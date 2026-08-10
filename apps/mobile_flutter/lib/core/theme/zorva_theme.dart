import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Single Source of Truth for Zorva Brand Aesthetics & Design Tokens
class ZorvaTheme {
  // Brand Color Palette (Obsidian & Elite Light Gold)
  static const Color background = Color(0xFF0B0C0E);
  static const Color surface = Color(0xFF141619);
  static const Color surfaceContainer = Color(0xFF1C2024);
  static const Color surfaceElevated = Color(0xFF323539);

  // Backward-compatible aliases for legacy components
  static const Color cardBg = Color(0xFF141619);
  static const Color cardBgLight = Color(0xFF1C2024);
  static const Color cardGlass = Color(0x1A27272A);

  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color primaryGoldLight = Color(0xFFFFF0B3);
  static const Color primaryGoldDark = Color(0xFFC59B27);

  static const Color textPrimary = Color(0xFFE0E2E8);
  static const Color textSecondary = Color(0xFFD0C5AF);
  static const Color textMuted = Color(0xFF99907C);

  static const Color borderSubtle = Color(0x4499907C);
  static const Color borderDark = Color(0x4499907C);
  static const Color borderGold = Color(0x66D4AF37);

  // Status & Feedback Colors
  static const Color success = Color(0xFF34D399);
  static const Color accentGreen = Color(0xFF34D399);
  static const Color error = Color(0xFFF87171);
  static const Color accentRed = Color(0xFFF87171);

  // Luxury Gradients
  static const LinearGradient goldGradient = LinearGradient(
    colors: [primaryGoldLight, primaryGold, primaryGoldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1B1A14), Color(0xFF0F0E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient goldGlowAura = RadialGradient(
    colors: [Color(0x33D4AF37), Colors.transparent],
    radius: 0.8,
  );

  // Global ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryGold,
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        secondary: primaryGold,
        surface: surface,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'Space Grotesk',
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: background,
          elevation: 4,
          shadowColor: const Color(0x66D4AF37),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold, width: 1.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
