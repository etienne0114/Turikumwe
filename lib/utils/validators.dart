// lib/utils/validators.dart
import 'package:turikumwe/utils/string_utils.dart';

class Validators {
  /// Validate that a field is not empty
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate that a field is a valid email address
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    
    if (!StringUtils.isValidEmail(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  /// Validate that a field is a valid phone number
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    
    if (!StringUtils.isValidPhone(value)) {
      return 'Please enter a valid phone number';
    }
    
    return null;
  }

  /// Validate that a password meets minimum requirements
  static String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }

  /// Validate that a field matches another field (e.g., for password confirmation)
  static String? validateMatch(String? value, String? matchValue, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (value != matchValue) {
      return '$fieldName does not match';
    }
    
    return null;
  }

  /// Validate that a field has a minimum length
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    
    return null;
  }

  /// Validate that a field has a maximum length
  static String? validateMaxLength(String? value, int maxLength, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters';
    }
    
    return null;
  }
  
  /// Validate a date is not in the past
  static String? validateFutureDate(DateTime? value, String fieldName) {
    if (value == null) {
      return '$fieldName is required';
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (value.isBefore(today)) {
      return '$fieldName must be in the future';
    }
    
    return null;
  }
  
  /// Validate a numeric value is within range
  static String? validateRange(num? value, num min, num max, String fieldName) {
    if (value == null) {
      return '$fieldName is required';
    }
    
    if (value < min) {
      return '$fieldName must be at least $min';
    }
    
    if (value > max) {
      return '$fieldName must not exceed $max';
    }
    
    return null;
  }
  
  /// Validate a field contains only numbers
  static String? validateNumeric(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (!StringUtils.isNumeric(value)) {
      return '$fieldName must contain only numbers';
    }
    
    return null;
  }
}