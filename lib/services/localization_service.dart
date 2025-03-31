// lib/services/localization_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'language';
  
  final Map<String, Locale> _supportedLocales = {
    'English': const Locale('en'),
    'Kinyarwanda': const Locale('rw'),
    'French': const Locale('fr'),
  };
  
  String _currentLanguage = 'English';
  Locale _currentLocale = const Locale('en');
  
  LocalizationService() {
    _loadSettings();
  }
  
  String get currentLanguage => _currentLanguage;
  Locale get currentLocale => _currentLocale;
  
  List<Locale> get supportedLocales => _supportedLocales.values.toList();
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);
      
      if (savedLanguage != null && _supportedLocales.containsKey(savedLanguage)) {
        _currentLanguage = savedLanguage;
        _currentLocale = _supportedLocales[savedLanguage]!;
      }
      
      notifyListeners();
    } catch (e) {
      // Default to English if there's an error
      _currentLanguage = 'English';
      _currentLocale = const Locale('en');
    }
  }
  
  Future<void> setLanguage(String language) async {
    if (_currentLanguage == language || !_supportedLocales.containsKey(language)) {
      return;
    }
    
    _currentLanguage = language;
    _currentLocale = _supportedLocales[language]!;
    
    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    
    notifyListeners();
  }
  
  // Get the locale code (e.g., 'en', 'rw') from language name
  String getLocaleCode(String language) {
    return _supportedLocales[language]?.languageCode ?? 'en';
  }
  
  // Get the language name from locale
  String getLanguageFromLocale(Locale locale) {
    final entry = _supportedLocales.entries.firstWhere(
      (entry) => entry.value.languageCode == locale.languageCode,
      orElse: () => const MapEntry('English', Locale('en')),
    );
    
    return entry.key;
  }
}

// Use this extension to easily get translated strings
extension LocalizationExt on BuildContext {
  // Method to get current translations
  // You'll need to set up Flutter's localization system for this to work
  // This is just a placeholder to demonstrate how it would be used
  String translate(String key) {
    // In a real app, this would use the Flutter localization system
    // For example: AppLocalizations.of(this)?.translate(key) ?? key
    return key;
  }
}