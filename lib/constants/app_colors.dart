import 'package:flutter/material.dart';

class AppColors {
  // ==================== LIGHT THEME (PRIMARY) ====================
  // Background & Surfaces (Warm Sand Tinted)
  static const Color background = Color(0xFFF8F5EE);
  static const Color surface = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFF4F0E6);
  static const Color surfaceContainer = Color(0xFFEFEAE0);
  static const Color surfaceContainerHigh = Color(0xFFE8E2D5);
  static const Color surfaceContainerHighest = Color(0xFFE0D9C9);
  static const Color cardColor = Colors.white;

  // Text / Content
  static const Color textPrimary = Color(0xFF1C1B1F);
  static const Color textSecondary = Color(0xFF49454F);
  static const Color textHint = Color(0xFF79747E);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color error = Color(0xFFBA1A1A);

  // Compatibility Aliases for Light Theme
  static const Color lightBackground = background;
  static const Color lightSurface = surface;
  static const Color lightSurfaceVariant = surfaceContainerLow;
  static const Color onBackground = textPrimary;
  static const Color onSurface = textPrimary;

  // ==================== DARK THEME (SECONDARY) ====================
  // Background & Surfaces (Corporate Charcoal)
  static const Color darkBackground = Color(0xFF121416);
  static const Color darkSurface = Color(0xFF121416);
  static const Color darkSurfaceContainerLow = Color(0xFF1A1C1E);
  static const Color darkSurfaceContainer = Color(0xFF1E2022);
  static const Color darkSurfaceContainerHigh = Color(0xFF282A2C);
  static const Color darkSurfaceContainerHighest = Color(0xFF333537);
  static const Color darkCardColor = Color(0xFF1A1C1E);

  // Text / Content
  static const Color darkTextPrimary = Color(0xFFE2E2E5);
  static const Color darkTextSecondary = Color(0xFFA98A80);
  static const Color darkTextHint = Color(0xFF594139);
  static const Color darkOnSurfaceVariant = Color(0xFFE1BFB5);
  static const Color darkError = Color(0xFFFFB4AB);

  // ==================== SHARED BRAND COLORS ====================
  // Primary (Burnt Orange)
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryContainer = Color(0xFFFF6B35);
  static const Color darkPrimary = primary;
  static const Color onPrimary = Colors.white; // High contrast white for buttons in light mode
  static const Color darkOnPrimary = Color(0xFF5D1900); // Legacy dark/brown contrast
  static const Color primaryTint = Color(0xFFFFB59D);

  // Secondary (Sage Teal)
  static const Color secondary = Color(0xFF2E6B68); // Darker teal for light mode readability
  static const Color darkSecondary = Color(0xFF9DD0CD); // Lighter teal for dark mode contrast
  static const Color secondaryContainer = Color(0xFF1D514F);
  static const Color onSecondaryContainer = Color(0xFF8FC2BF);

  // Tertiary (Amber)
  static const Color tertiary = Color(0xFFD69E00); // Adjusted for light mode contrast
  static const Color darkTertiary = Color(0xFFFCBC0C);
  static const Color tertiaryContainer = Color(0xFFC49100);

  // Status & Outline
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFC9C5D0);

  // Logistics status colors
  static const Color statusSubmitted = Color(0xFF9DD0CD); // Teal
  static const Color statusAccepted = Color(0xFF1D514F);
  static const Color statusPending = Color(0xFFFCBC0C);   // Amber
  static const Color statusDelivered = Color(0xFFFF6B35); // Burnt Orange
}