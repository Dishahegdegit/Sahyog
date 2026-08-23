import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme_notifier.dart';

/// Riverpod provider for app-wide ThemeMode (light / dark).
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(themeNotifier.value) {
    themeNotifier.addListener(_onNotifierChange);
  }

  void _onNotifierChange() {
    if (state != themeNotifier.value) {
      state = themeNotifier.value;
    }
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onNotifierChange);
    super.dispose();
  }

  bool get isDark => state == ThemeMode.dark;

  void toggleTheme() {
    setDark(state != ThemeMode.dark);
  }

  void setDark(bool isDark) {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    state = themeNotifier.value;
    saveThemePreference(isDark);
  }
}
