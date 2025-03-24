// lib/utils/file_utils.dart
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FileUtils {
  /// Get a temporary directory path
  static Future<String> getTemporaryDirectoryPath() async {
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  /// Get an application documents directory path
  static Future<String> getApplicationDocumentsDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Generate a unique filename with extension
  static String generateUniqueFileName(String extension) {
    const uuid = Uuid();
    return '${uuid.v4()}.$extension';
  }

  /// Get the file size in a human-readable format
  static String getFileSize(File file, {int decimals = 1}) {
    final bytes = file.lengthSync();
    if (bytes <= 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Get the file extension from a path
  static String getFileExtension(String path) {
    return path.split('.').last;
  }

  /// Get the file name from a path
  static String getFileName(String path) {
    return path.split('/').last;
  }

  /// Check if a file exists at the given path
  static Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  /// Write a string to a file
  static Future<File> writeStringToFile(String path, String content) async {
    final file = File(path);
    return file.writeAsString(content);
  }

  /// Read a string from a file
  static Future<String> readStringFromFile(String path) async {
    final file = File(path);
    return file.readAsString();
  }

  /// Delete a file
  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}