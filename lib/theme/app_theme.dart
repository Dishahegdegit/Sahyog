import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  // ----------------- Light Theme -----------------
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    canvasColor: AppColors.lightBackground,
    cardColor: AppColors.lightSurface,

    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      background: AppColors.lightBackground,
      surface: AppColors.lightSurface,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onPrimary: AppColors.onPrimary,
      onBackground: AppColors.onBackground,
      onSurface: AppColors.onSurface,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      error: AppColors.error,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16.0)),
      ),
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: AppColors.textHint),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceContainerLow,
    ),
    dividerColor: AppColors.surfaceContainerHighest,
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
  );

  // ----------------- Dark Theme -----------------
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    canvasColor: AppColors.darkBackground,
    cardColor: AppColors.darkCardColor,
    primaryColor: AppColors.darkPrimary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.darkSecondary,
      tertiary: AppColors.darkTertiary,
      surface: AppColors.darkSurface,
      surfaceContainerLow: AppColors.darkSurfaceContainerLow,
      surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
      onPrimary: Colors.white,
      onBackground: AppColors.darkTextPrimary,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.darkError,
      outline: AppColors.darkTextHint,
      outlineVariant: AppColors.darkSurfaceContainerHighest,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.darkCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16.0)),
      ),
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceContainerLow,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: AppColors.darkTextHint),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurfaceContainerLow,
    ),
    dividerColor: AppColors.darkSurfaceContainerHighest,
    iconTheme: const IconThemeData(color: AppColors.darkTextSecondary),
  );
}

/// Extension for easy context-aware color access.
/// Use: context.colors.background, context.colors.surface, etc.
extension ThemeColors on BuildContext {
  AppColorSet get colors {
    final dark = Theme.of(this).brightness == Brightness.dark;
    return AppColorSet(dark);
  }
}

class AppColorSet {
  final bool isDark;
  const AppColorSet(this.isDark);

  Color get background => isDark ? AppColors.darkBackground : AppColors.background;
  Color get surface => isDark ? AppColors.darkSurface : AppColors.surface;
  Color get surfaceContainerLow => isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow;
  Color get surfaceContainer => isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer;
  Color get surfaceContainerHigh => isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh;
  Color get surfaceContainerHighest => isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest;
  Color get cardColor => isDark ? AppColors.darkCardColor : AppColors.cardColor;

  Color get textPrimary => isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get textSecondary => isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get textHint => isDark ? AppColors.darkTextHint : AppColors.textHint;
  Color get outlineVariant => isDark ? AppColors.darkSurfaceContainerHighest : AppColors.outlineVariant;
  Color get borderLight => outlineVariant;
  Color get error => isDark ? AppColors.darkError : AppColors.error;

  // Brand colors (same in both, kept for convenience)
  Color get primary => AppColors.primary;
  Color get secondary => isDark ? AppColors.darkSecondary : AppColors.secondary;
  Color get tertiary => isDark ? AppColors.darkTertiary : AppColors.tertiary;
}
