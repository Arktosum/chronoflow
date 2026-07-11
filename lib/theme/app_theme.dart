import 'package:flutter/material.dart';

/// The dark cyber soul of The River — near-black, minimal, neon used
/// sparingly as light in the dark, never as paint.
class RiverColors {
  static const Color bg = Color(0xFF050508);
  static const Color surface = Color(0xFF0A0A10);
  static const Color surfaceRaised = Color(0xFF10101A);

  static const Color purple = Color(0xFFB16CFF); // neon violet
  static const Color cyan = Color(0xFF00F0FF); // electric cyan

  static const Color textPrimary = Color(0xFFEAEAF2);
  static const Color textSecondary = Colors.white54;
  static const Color textFaint = Colors.white24;
  static const Color hairline = Colors.white10;

  static const Color flame = Color(0xFFFF9800);
  static const Color flameDim = Color(0xFF7A5230);

  /// Palette offered when picking a color for a habit / favorite tag.
  static const List<Color> tagPalette = [
    Color(0xFFB16CFF), // violet
    Color(0xFF00F0FF), // cyan
    Color(0xFF39FF88), // mint
    Color(0xFFFF9800), // amber
    Color(0xFFFF5470), // coral
    Color(0xFFFF6EC7), // pink
    Color(0xFF5C7CFF), // indigo
    Color(0xFF00C9A7), // teal
    Color(0xFFF4F162), // acid yellow
    Color(0xFF9E9E9E), // grey
  ];

  /// A soft neon glow for the rare elements that deserve it.
  static List<BoxShadow> glow(Color color, {double strength = 1}) => [
        BoxShadow(
          color: color.withValues(alpha: 0.45 * strength),
          blurRadius: 14 * strength,
          spreadRadius: 1,
        ),
      ];
}

ThemeData buildRiverTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: RiverColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: RiverColors.purple,
      secondary: RiverColors.cyan,
      surface: RiverColors.surface,
    ),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: 4.0,
        fontSize: 14,
        color: RiverColors.textPrimary,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: RiverColors.surfaceRaised,
      contentTextStyle: TextStyle(color: RiverColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: RiverColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: RiverColors.hairline),
  );
}
