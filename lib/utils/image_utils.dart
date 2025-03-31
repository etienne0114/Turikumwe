// lib/utils/image_utils.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:turikumwe/services/storage_service.dart';

class ImageUtils {
  // Existing methods
  static ImageProvider imageFile(String path) {
    return FileImage(File(path));
  }

  static Future<String?> uploadImage(String imagePath) async {
    try {
      // Implement your actual image upload logic here
      // This example assumes you have a StorageService that handles uploads
      return await StorageService().uploadImage(File(imagePath));
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // New methods needed for story functionality
  static Future<File?> pickImage({required ImageSource source, int quality = 80}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: quality,
    );
    
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }
  
  static Future<List<File>> pickMultipleImages({int quality = 80}) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: quality,
    );
    
    return pickedFiles.map((pickedFile) => File(pickedFile.path)).toList();
  }

  // Compress and resize an image
  static Future<File> compressImage(File file, {int quality = 80, int maxWidth = 1200}) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = const Uuid().v4() + path.extension(file.path);
    final targetPath = path.join(tempDir.path, fileName);
    
    try {
      // Read image bytes
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return file; // Return original if decoding fails
      }
      
      // Resize if needed
      img.Image resized = image;
      if (image.width > maxWidth) {
        resized = img.copyResize(
          image,
          width: maxWidth,
          height: (maxWidth / image.width * image.height).round(),
          interpolation: img.Interpolation.linear,
        );
      }
      
      // Encode and save
      final compressedBytes = img.encodeJpg(resized, quality: quality);
      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(compressedBytes);
      
      return compressedFile;
    } catch (e) {
      print('Error compressing image: $e');
      // Return original file if compression fails
      return file;
    }
  }

  // Get a unique filename for an image
  static String getUniqueImageName(String originalPath) {
    final extension = path.extension(originalPath);
    return '${const Uuid().v4()}$extension';
  }
  
  // Parse a comma-separated string of image paths into a list
  static List<String> split(String? imagePathsString) {
    if (imagePathsString == null || imagePathsString.isEmpty) {
      return [];
    }
    return imagePathsString.split(',');
  }
}