import 'package:flutter/material.dart';

class AppColors {
  // ==================== LIGHT ENTERPRISE SYSTEM ====================
  // Background & Canvas (Soft Cream / Off-White)
  static const Color background = Color(0xFFFAF7F2);
  static const Color surface = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFF6F2EB);
  static const Color surfaceContainer = Color(0xFFEFEAE0);
  static const Color surfaceContainerHigh = Color(0xFFE8E2D5);
  static const Color surfaceContainerHighest = Color(0xFFE0D9C9);
  static const Color cardColor = Colors.white;
  static const Color borderLight = Color(0xFFEAE5DD);

  // Text / Typography (Slate & Charcoal)
  static const Color textPrimary = Color(0xFF1E2022);
  static const Color textSecondary = Color(0xFF687076);
  static const Color textHint = Color(0xFF9EA5AD);
  static const Color onSurfaceVariant = Color(0xFF687076);
  static const Color error = Color(0xFFD32F2F);

  // Compatibility Aliases for Light & Dark Theme
  static const Color lightBackground = background;
  static const Color lightSurface = surface;
  static const Color lightSurfaceVariant = surfaceContainerLow;
  static const Color onBackground = textPrimary;
  static const Color onSurface = textPrimary;
  static const Color darkBackground = Color(0xFF121416);
  static const Color darkSurface = Color(0xFF121416);
  static const Color darkSurfaceContainerLow = Color(0xFF181A1C);
  static const Color darkSurfaceContainer = Color(0xFF222529);
  static const Color darkSurfaceContainerHigh = Color(0xFF2B2E33);
  static const Color darkSurfaceContainerHighest = Color(0xFF383C42);
  static const Color darkCardColor = Color(0xFF1E2023);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextHint = Color(0xFF6B7280);
  static const Color darkOnSurfaceVariant = Color(0xFFD1D5DB);
  static const Color darkError = Color(0xFFFF6B6B);

  // ==================== SHARED BRAND COLORS ====================
  // Primary Accent (Warm Burnt Orange)
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryAccent = Color(0xFFFF5722);
  static const Color primaryContainer = Color(0xFFFF6B35);
  static const Color darkPrimary = primary;
  static const Color onPrimary = Colors.white;
  static const Color darkOnPrimary = Color(0xFF5D1900);
  static const Color primaryTint = Color(0xFFFFEAD5);

  // Secondary Accent (Sage Teal)
  static const Color secondary = Color(0xFF00B8A9);
  static const Color darkSecondary = Color(0xFF9DD0CD);
  static const Color secondaryContainer = Color(0xFFE0F7F5);
  static const Color onSecondaryContainer = Color(0xFF00B8A9);

  // Tertiary (Amber / Warning)
  static const Color tertiary = Color(0xFFFCBC0C);
  static const Color darkTertiary = Color(0xFFFCBC0C);
  static const Color tertiaryContainer = Color(0xFFFFF8E1);

  // Status & Outline
  static const Color outline = Color(0xFFEAE5DD);
  static const Color outlineVariant = Color(0xFFD5CFB9);

  // Logistics & Order Status Colors (Light Theme Semantic)
  static const Color statusPending = Color(0xFFE65100);   // Deep Orange/Amber
  static const Color statusAccepted = Color(0xFF1976D2);  // Royal Blue
  static const Color statusTransit = Color(0xFF00897B);   // Deep Teal
  static const Color statusDelivered = Color(0xFF2E7D32); // Forest Green
  static const Color statusCancelled = Color(0xFFC62828); // Crimson Red
}