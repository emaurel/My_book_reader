import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide themes. The reader has its own per-page background colors
/// (sepia, paper, dark) handled separately in the reader settings.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    );
    return _base(colorScheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFFFAF8F4),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    );
    return _base(colorScheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }

  static ThemeData _base(ColorScheme colorScheme) {
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: colorScheme.brightness).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Reading surface presets (different from app theme).
enum ReaderTheme { light, sepia, dark, black }

extension ReaderThemeColors on ReaderTheme {
  Color get background {
    switch (this) {
      case ReaderTheme.light:
        return const Color(0xFFFAF8F4);
      case ReaderTheme.sepia:
        return const Color(0xFFF4ECD8);
      case ReaderTheme.dark:
        return const Color(0xFF1E1E1E);
      case ReaderTheme.black:
        return Colors.black;
    }
  }

  Color get foreground {
    switch (this) {
      case ReaderTheme.light:
        return const Color(0xFF1A1A1A);
      case ReaderTheme.sepia:
        return const Color(0xFF5B4636);
      case ReaderTheme.dark:
        return const Color(0xFFE0E0E0);
      case ReaderTheme.black:
        return const Color(0xFFAAAAAA);
    }
  }

  String get label {
    switch (this) {
      case ReaderTheme.light:
        return 'Paper';
      case ReaderTheme.sepia:
        return 'Sepia';
      case ReaderTheme.dark:
        return 'Dark';
      case ReaderTheme.black:
        return 'Black';
    }
  }
}
