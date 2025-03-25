// lib/utils/image_utils.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:turikumwe/services/storage_service.dart'; // You'll need to create this

class ImageUtils {
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
}