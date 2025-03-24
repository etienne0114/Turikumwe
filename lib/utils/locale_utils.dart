
// lib/utils/locale_utils.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleUtils {
  static const String localeKey = 'app_locale';
  static const Locale defaultLocale = Locale('en');
  
  static final List<Locale> supportedLocales = [
    const Locale('en'), // English
    const Locale('rw'), // Kinyarwanda
    const Locale('fr'), // French
  ];

  /// Get the display name of a locale
  static String getDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'rw':
        return 'Kinyarwanda';
      case 'fr':
        return 'Français';
      default:
        return locale.languageCode;
    }
  }

  /// Get the flag emoji for a locale
  static String getFlagEmoji(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return '🇬🇧';
      case 'rw':
        return '🇷🇼';
      case 'fr':
        return '🇫🇷';
      default:
        return '';
    }
  }

  /// Get the saved locale from shared preferences
  static Future<Locale> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(localeKey);
    
    if (savedLocale == null) {
      return defaultLocale;
    }
    
    return Locale(savedLocale);
  }

  /// Save the locale to shared preferences
  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localeKey, locale.languageCode);
  }

  /// Check if the language is read from right to left
  static bool isRTL(Locale locale) {
    final rtlLanguages = ['ar', 'he', 'fa', 'ur'];
    return rtlLanguages.contains(locale.languageCode);
  }
}