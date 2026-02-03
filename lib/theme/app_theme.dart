import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light {
    const c = AppColors.light;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme.light(
        primary: c.primary,
        secondary: c.primary,
        surface: c.surface,
        surfaceContainerHighest: c.surfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.cardBorder),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
            color: c.textPrimary, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: c.textPrimary),
        bodyMedium: TextStyle(color: c.textSecondary),
      ),
      dividerColor: c.divider,
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        thumbColor: c.primary,
        inactiveTrackColor: c.divider,
      ),
      extensions: const [AppColors.light],
    );
  }

  static ThemeData get dark {
    const c = AppColors.dark;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme.dark(
        primary: c.primary,
        secondary: c.primary,
        surface: c.surface,
        surfaceContainerHighest: c.surfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.cardBorder),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
            color: c.textPrimary, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: c.textPrimary),
        bodyMedium: TextStyle(color: c.textSecondary),
      ),
      dividerColor: c.divider,
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        thumbColor: c.primary,
        inactiveTrackColor: c.divider,
      ),
      extensions: const [AppColors.dark],
    );
  }
}
