// lib/utils/image_utils.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class ImageUtils {
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from the gallery
  static Future<File?> pickImageFromGallery({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    
    return null;
  }

  /// Take a photo with the camera
  static Future<File?> takePhoto({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    
    return null;
  }

  /// Get a temporary file path for an image with a unique name
  static Future<String> getTemporaryImagePath() async {
    final directory = await getTemporaryDirectory();
    const uuid = Uuid();
    return '${directory.path}/${uuid.v4()}.jpg';
  }

  /// Download an image from a URL
  static Future<File?> downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        const uuid = Uuid();
        final filePath = '${directory.path}/${uuid.v4()}.jpg';
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        return file;
      }
    } catch (e) {
      print('Error downloading image: $e');
    }
    
    return null;
  }

  /// Get image dimensions
  static Future<Size> getImageDimensions(File imageFile) async {
    final image = await decodeImageFromList(await imageFile.readAsBytes());
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  /// Check if a file is an image
  static bool isImageFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }
}
