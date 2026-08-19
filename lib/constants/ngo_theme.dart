import 'package:flutter/material.dart';
import 'app_colors.dart';

/// A theme-aware color resolver for the NGO module.
/// Usage: final c = NgoTheme.of(context);
///         then use c.background, c.surface, c.textPrimary etc.
class NgoTheme {
  final Color background;
  final Color surface;
  final Color surfaceContainerLow;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceContainer;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color cardColor;
  final Color outline;
  final Color outlineVariant;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color error;
  final bool isDark;

  const NgoTheme({
    required this.background,
    required this.surface,
    required this.surfaceContainerLow,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceContainer,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.cardColor,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.error,
    required this.isDark,
  });

  factory NgoTheme.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const NgoTheme(
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        surfaceContainerLow: AppColors.darkSurfaceContainerLow,
        surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
        surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
        surfaceContainer: AppColors.darkSurfaceContainer,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        textHint: AppColors.darkTextHint,
        cardColor: AppColors.darkCardColor,
        outline: AppColors.darkSurfaceContainerHighest,
        outlineVariant: AppColors.darkSurfaceContainerHighest,
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkSecondary,
        tertiary: AppColors.darkTertiary,
        error: AppColors.darkError,
        isDark: true,
      );
    }
    return const NgoTheme(
      background: AppColors.background,
      surface: AppColors.lightSurface,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      surfaceContainer: AppColors.surfaceContainer,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textHint: AppColors.textHint,
      cardColor: AppColors.cardColor,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      error: AppColors.error,
      isDark: false,
    );
  }
}
