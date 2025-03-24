
// lib/utils/navigation_utils.dart
import 'package:flutter/material.dart';

class NavigationUtils {
  /// Navigate to a new screen
  static Future<T?> navigateTo<T>(BuildContext context, Widget screen) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  /// Navigate to a new screen and replace the current one
  static Future<T?> navigateToReplacement<T>(BuildContext context, Widget screen) {
    return Navigator.pushReplacement<T, T>(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  /// Navigate to a new screen and remove all previous screens
  static Future<T?> navigateToAndRemoveUntil<T>(BuildContext context, Widget screen) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      MaterialPageRoute(builder: (context) => screen),
      (route) => false,
    );
  }

  /// Navigate back to the previous screen
  static void goBack<T>(BuildContext context, [T? result]) {
    Navigator.pop<T>(context, result);
  }

  /// Pop until a specific route name
  static void popUntilNamed(BuildContext context, String routeName) {
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }

  /// Show a dialog
  static Future<T?> showAppDialog<T>(
    BuildContext context, {
    required Widget title,
    required Widget content,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: title,
          content: content,
          actions: actions,
        );
      },
    );
  }

  /// Show a bottom sheet
  static Future<T?> showAppBottomSheet<T>(
    BuildContext context, {
    required Widget content,
    bool isScrollControlled = false,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      builder: (BuildContext context) {
        return content;
      },
    );
  }
}