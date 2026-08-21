import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_notifier.dart';

/// Riverpod provider for app-wide ThemeMode (light / dark).
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(themeNotifier.value);

  bool get isDark => state == ThemeMode.dark;

  void toggleTheme() {
    setDark(state != ThemeMode.dark);
  }

  void setDark(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    themeNotifier.value = state;
    saveThemePreference(isDark);
  }
}
