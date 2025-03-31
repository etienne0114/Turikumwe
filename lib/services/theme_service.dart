// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _darkModeKey = 'dark_mode_enabled';
  
  late ThemeMode _themeMode;
  bool _isDarkMode = false;
  
  ThemeService() {
    _themeMode = ThemeMode.light;
    _loadSettings();
  }
  
  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _themeMode;
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
      _themeMode = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (e) {
      // Default to light mode if there's an error
      _isDarkMode = false;
      _themeMode = ThemeMode.light;
    }
  }
  
  Future<void> setDarkMode(bool isDarkMode) async {
    if (_isDarkMode == isDarkMode) return;
    
    _isDarkMode = isDarkMode;
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    
    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode);
    
    notifyListeners();
  }
  
  Future<void> toggleTheme() async {
    await setDarkMode(!_isDarkMode);
  }
  
  // Get theme based on current mode
  ThemeData getTheme(BuildContext context) {
    return _isDarkMode ? _getDarkTheme(context) : _getLightTheme(context);
  }
  
  ThemeData _getLightTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      // Define your light theme properties here
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Add more theme configurations as needed
    );
  }
  
  ThemeData _getDarkTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      // Define your dark theme properties here
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF303030),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF424242),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Add more theme configurations as needed
    );
  }
}