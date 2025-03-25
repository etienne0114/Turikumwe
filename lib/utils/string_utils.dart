// lib/utils/string_utils.dart

class StringUtils {
  /// Capitalize the first letter of a string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Capitalize the first letter of each word in a string
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Truncate a string to a maximum length with an ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Generate initials from a name (e.g., "John Doe" -> "JD")
  static String getInitials(String name) {
    if (name.isEmpty) return '';
    
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    
    return parts[0][0].toUpperCase() + parts[parts.length - 1][0].toUpperCase();
  }

  /// Check if a string is a valid email address
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Check if a string is a valid phone number
  static bool isValidPhone(String phone) {
    // This is a simple validation for Rwandan phone numbers
    // You might want to adjust this for your specific requirements
    final phoneRegex = RegExp(r'^\+?[0-9]{10,12}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Remove diacritics from a string (e.g., "café" -> "cafe")
  static String removeDiacritics(String text) {
    // This is a simplified version that covers common diacritics
    const withDiacritics = 'àáâäæãåāèéêëēėęîïíīįìôöòóœøōõùúûüūÿçćčñń';
    const withoutDiacritics = 'aaaaaaaeeeeeeeiiiiiioooooooouuuuuyccnn';
    
    for (var i = 0; i < withDiacritics.length; i++) {
      text = text.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    
    return text;
  }

  /// Create a slug from a string (e.g., "Hello World" -> "hello-world")
  static String slugify(String text) {
    var result = removeDiacritics(text.toLowerCase());
    result = result.replaceAll(RegExp(r'[^a-z0-9\s-]'), ''); // Remove non-alphanumeric chars
    result = result.replaceAll(RegExp(r'\s+'), '-'); // Replace spaces with hyphens
    result = result.replaceAll(RegExp(r'-+'), '-'); // Replace multiple hyphens with single hyphen
    return result;
  }
  
  /// Extract username from email
  static String getUsernameFromEmail(String email) {
    return email.split('@').first;
  }
  
  /// Format a number with commas for thousands (e.g., 1000 -> "1,000")
  static String formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
  
  /// Convert a string to camelCase
  static String toCamelCase(String text) {
    if (text.isEmpty) return text;
    
    final words = text
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'));
    
    if (words.isEmpty) return '';
    
    final firstWord = words[0].toLowerCase();
    final remainingWords = words.skip(1).map((word) => 
        word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '');
    
    return firstWord + remainingWords.join('');
  }
  
  /// Check if a string is empty or only contains whitespace
  static bool isBlank(String? text) {
    return text == null || text.trim().isEmpty;
  }
  
  /// Check if string contains only digits
  static bool isNumeric(String text) {
    return RegExp(r'^[0-9]+$').hasMatch(text);
  }
  
  /// Check if string is a valid URL
  static bool isValidUrl(String url) {
    return Uri.tryParse(url)?.isAbsolute ?? false;
  }
  
  /// Mask a string (e.g., for credit card numbers or passwords)
  static String mask(String text, {int visibleChars = 4, String maskChar = '*'}) {
    if (text.length <= visibleChars) return text;
    
    final visiblePart = text.substring(text.length - visibleChars);
    final maskedPart = maskChar * (text.length - visibleChars);
    
    return maskedPart + visiblePart;
  }
  
  /// Convert a string to snake_case
  static String toSnakeCase(String text) {
    if (text.isEmpty) return text;
    
    var result = text
        .replaceAllMapped(
          RegExp(r'[A-Z]'), 
          (Match m) => '_${m[0]!.toLowerCase()}'
        )
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[-]+'), '_');
    
    if (result.startsWith('_')) {
      result = result.substring(1);
    }
    
    return result;
  }
  
  /// Reverse a string
  static String reverse(String text) {
    return String.fromCharCodes(text.runes.toList().reversed);
  }
  
  /// Count occurrences of a substring within a string
  static int countOccurrences(String text, String substring) {
    if (substring.isEmpty) return 0;
    
    int count = 0;
    int start = 0;
    while (true) {
      start = text.indexOf(substring, start);
      if (start == -1) break;
      count++;
      start += substring.length;
    }
    
    return count;
  }
}