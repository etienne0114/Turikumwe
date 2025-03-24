// lib/utils/theme_utils.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeUtils {
  static const String themeKey = 'app_theme_mode';

  /// Get the saved theme mode
  static Future<ThemeMode> getSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(themeKey);
    
    if (themeIndex == null) {
      return ThemeMode.system;
    }
    
    return ThemeMode.values[themeIndex];
  }

  /// Save the theme mode
  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(themeKey, mode.index);
  }

  /// Get the theme mode name
  static String getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  /// Check if dark mode is active
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Get the appropriate color based on the brightness
  static Color getColorBasedOnBrightness(
    BuildContext context, {
    required Color lightColor,
    required Color darkColor,
  }) {
    return isDarkMode(context) ? darkColor : lightColor;
  }
}