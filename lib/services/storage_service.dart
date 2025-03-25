import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:turikumwe/constants/api_constants.dart';
import 'package:turikumwe/utils/logger.dart';
import 'package:http_parser/http_parser.dart'; // Add this import for MediaType

class StorageService {
  final Dio _dio = Dio();

  Future<String?> uploadImage(File imageFile) async {
    try {
      // Get MIME type
      final mimeType = lookupMimeType(imageFile.path);
      
      // Create multipart file
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          contentType: MediaType.parse(mimeType ?? 'image/jpeg'),
        ), // Added missing parenthesis here
      });

      // Add headers if needed
      _dio.options.headers['Accept'] = 'application/json';

      // Track upload progress
      final response = await _dio.post(
        ApiConstants.uploadImageUrl,
        data: formData,
        onSendProgress: (sent, total) {
          Logger.i('Upload progress: ${(sent / total * 100).toStringAsFixed(0)}%');
        },
      );

      if (response.statusCode == 200) {
        Logger.i('Image uploaded successfully');
        return response.data['url']; // Adjust based on your API response
      }
      return null;
    } catch (e, stackTrace) {
      Logger.e('Error uploading image', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<File?> downloadImage(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = url.split('/').last;
      final filePath = '${tempDir.path}/$fileName';
      
      await _dio.download(url, filePath);
      return File(filePath);
    } catch (e, stackTrace) {
      Logger.e('Error downloading image', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> deleteImage(String url) async {
    try {
      final response = await _dio.delete(
        '${ApiConstants.deleteImageUrl}?url=${Uri.encodeComponent(url)}',
      );
      return response.statusCode == 200;
    } catch (e, stackTrace) {
      Logger.e('Error deleting image', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  void dispose() {
    _dio.close();
  }
}