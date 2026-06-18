import 'package:flutter/material.dart';

class AppTheme {
  // Chronoflow Color Palette
  static const Color background = Color(0xFF0D0D0D); // Deep Obsidian
  static const Color surface = Color(0xFF1E1E1E); // Matte Gray Surface
  static const Color primary = Color(0xFF00E5FF); // Electric Cyan Accent
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9E9E9E); // Muted Slate

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: surface,
        // ignore: deprecated_member_use
        background: background,
      ),
      fontFamily: 'Inter', // Default UI font

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primary, width: 1),
        ),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          height: 1.5,
          fontFamily:
              'Inter', // You can change this to a serif like Lora for reading later
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
