import 'package:flutter/foundation.dart';

class Logger {
  static void i(String message, {dynamic data}) {
    if (kDebugMode) {
      print('ℹ️ INFO: $message ${data ?? ''}');
    }
  }

  static void e(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      print('⛔ ERROR: $message');
      if (error != null) print(error);
      if (stackTrace != null) print(stackTrace);
    }
  }
}