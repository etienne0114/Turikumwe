// lib/utils/app_info_utils.dart
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;
import 'dart:developer' as developer;

class AppInfoUtils {
  /// Get the app version
  static Future<String> getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      developer.log('Error getting app version: $e', name: 'AppInfoUtils');
      return 'Unknown';
    }
  }

  /// Get the app build number
  static Future<String> getBuildNumber() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.buildNumber;
    } catch (e) {
      developer.log('Error getting build number: $e', name: 'AppInfoUtils');
      return 'Unknown';
    }
  }

  /// Get the app name
  static Future<String> getAppName() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.appName;
    } catch (e) {
      developer.log('Error getting app name: $e', name: 'AppInfoUtils');
      return 'Unknown';
    }
  }

  /// Get the package name
  static Future<String> getPackageName() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.packageName;
    } catch (e) {
      developer.log('Error getting package name: $e', name: 'AppInfoUtils');
      return 'Unknown';
    }
  }

  /// Get device information
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final Map<String, dynamic> deviceData = <String, dynamic>{};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceData['platform'] = 'android';
        deviceData['version'] = androidInfo.version.release;
        deviceData['sdkInt'] = androidInfo.version.sdkInt;
        deviceData['manufacturer'] = androidInfo.manufacturer;
        deviceData['model'] = androidInfo.model;
        deviceData['isPhysicalDevice'] =
            androidInfo.isPhysicalDevice; // Added for Android
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceData['platform'] = 'ios';
        deviceData['version'] = iosInfo.systemVersion;
        deviceData['name'] = iosInfo.name;
        deviceData['model'] = iosInfo.model;
        deviceData['isPhysicalDevice'] =
            iosInfo.isPhysicalDevice; // Added for iOS
      } else {
        // Handle unsupported platforms
        deviceData['platform'] = 'unsupported';
        deviceData['message'] = 'This platform is not supported';
      }
    } catch (e, stackTrace) {
      // Enhanced error logging with stack trace
      developer.log(
        'Error getting device info: $e',
        name: 'AppInfoUtils',
        error: e,
        stackTrace: stackTrace,
      );
      deviceData['error'] = 'Failed to retrieve device info';
    }

    return deviceData;
  }
}
