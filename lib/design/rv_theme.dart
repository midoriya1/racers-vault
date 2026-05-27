import 'package:flutter/material.dart';

import 'rv_colors.dart';

class RvTheme {
  const RvTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: RvColors.crimson,
      brightness: Brightness.dark,
      surface: RvColors.carbon,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: RvColors.obsidian,
      colorScheme: scheme.copyWith(
        primary: RvColors.crimson,
        secondary: RvColors.electricBlue,
        tertiary: RvColors.hyperOrange,
        surface: RvColors.carbon,
        onSurface: RvColors.text,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: RvColors.obsidian,
        foregroundColor: RvColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: RvColors.glass,
        selectedColor: RvColors.glassStrong,
        side: const BorderSide(color: RvColors.border),
        labelStyle: const TextStyle(
          color: RvColors.text,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: RvColors.titanium, size: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return RvColors.glassStrong;
            }
            return RvColors.glass;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return RvColors.text;
            }
            return RvColors.mutedText;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: RvColors.border),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RvColors.crimson,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RvColors.text,
          side: const BorderSide(color: RvColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: RvColors.text,
          fontWeight: FontWeight.w900,
          height: 1.02,
        ),
        headlineSmall: TextStyle(
          color: RvColors.text,
          fontWeight: FontWeight.w900,
          height: 1.08,
        ),
        titleLarge: TextStyle(
          color: RvColors.text,
          fontWeight: FontWeight.w900,
        ),
        titleMedium: TextStyle(
          color: RvColors.text,
          fontWeight: FontWeight.w800,
        ),
        titleSmall: TextStyle(
          color: RvColors.text,
          fontWeight: FontWeight.w800,
        ),
        bodyMedium: TextStyle(color: RvColors.titanium, height: 1.35),
        bodySmall: TextStyle(color: RvColors.mutedText, height: 1.25),
        labelSmall: TextStyle(
          color: RvColors.mutedText,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
