// lib/utils/date_formatter.dart
import 'package:intl/intl.dart';

class DateFormatter {
  /// Format a DateTime object to a string in the format "Jan 1, 2023"
  static String formatDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  /// Format a DateTime object to a string in the format "01/01/2023"
  static String formatShortDate(DateTime date) {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  /// Format a DateTime object to a string in the format "January 1, 2023"
  static String formatLongDate(DateTime date) {
    return DateFormat.yMMMMd().format(date);
  }

  /// Format a DateTime object to a string in the format "Jan 1, 2023 at 12:00 PM"
  static String formatDateWithTime(DateTime date) {
    return DateFormat('MMM d, yyyy \'at\' h:mm a').format(date);
  }

  /// Format a DateTime object to a string in the format "Monday"
  static String formatDayOfWeek(DateTime date) {
    return DateFormat.EEEE().format(date);
  }

  /// Format a DateTime object to a relative time (today, yesterday, 2 days ago, etc.)
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  /// Check if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }

  /// Check if a date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return yesterday.year == date.year &&
        yesterday.month == date.month &&
        yesterday.day == date.day;
  }

  /// Get a date range string (e.g., "Jan 1 - Jan 5, 2023")
  static String formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      // Same month and year, e.g., "Jan 1-5, 2023"
      return '${DateFormat('MMM d').format(start)}-${DateFormat('d, yyyy').format(end)}';
    } else if (start.year == end.year) {
      // Same year, e.g., "Jan 1 - Feb 5, 2023"
      return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
    } else {
      // Different years, e.g., "Dec 31, 2022 - Jan 1, 2023"
      return '${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
    }
  }
}

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
}
