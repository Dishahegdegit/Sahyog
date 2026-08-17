import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global notifier — listen to this to rebuild MaterialApp with new ThemeMode.
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

Future<void> loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
}

Future<void> saveThemePreference(bool isDark) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isDarkMode', isDark);
}

/// Convenient getter — true when dark mode is active.
bool get isDarkMode => themeNotifier.value == ThemeMode.dark;
