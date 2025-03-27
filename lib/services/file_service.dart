// lib/services/file_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:turikumwe/services/database_service.dart';

// Conditionally import file_picker only on mobile platforms
import 'dart:io' show File, Platform;
// We'll only use file_picker on mobile platforms (Android, iOS)
// ignore: depend_on_referenced_packages
import 'package:file_picker/file_picker.dart' if (dart.library.html) 'package:turikumwe/utils/web_file_picker_stub.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  final DatabaseService _databaseService = DatabaseService();
  final Dio _dio = Dio();
  final Uuid _uuid = const Uuid();
  
  bool get isMobilePlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // Pick any file type (document, image, video, etc.)
  Future<FileResult?> pickFile() async {
    if (!isMobilePlatform) {
      return null; // Not supported on non-mobile platforms
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileExtension = path.extension(fileName).toLowerCase();
        final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
        
        String fileType = 'file';
        if (mimeType.startsWith('image/')) {
          fileType = 'image';
        } else if (mimeType.startsWith('video/')) {
          fileType = 'video';
        } else if (mimeType.startsWith('audio/')) {
          fileType = 'audio';
        } else if (['.pdf', '.doc', '.docx', '.txt', '.xls', '.xlsx'].contains(fileExtension)) {
          fileType = 'document';
        }

        return FileResult(
          file: file,
          fileName: fileName,
          fileType: fileType,
          mimeType: mimeType,
        );
      }
    } catch (e) {
      print('Error picking file: $e');
    }
    
    return null;
  }

  // Pick image from gallery
  Future<FileResult?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (image != null) {
        final file = File(image.path);
        final fileName = path.basename(image.path);
        final mimeType = lookupMimeType(fileName) ?? 'image/jpeg';
        
        return FileResult(
          file: file,
          fileName: fileName,
          fileType: 'image',
          mimeType: mimeType,
        );
      }
    } catch (e) {
      print('Error picking image: $e');
    }
    
    return null;
  }

  // Pick video from gallery or record new video
  Future<FileResult?> pickVideo({bool fromCamera = false}) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );

      if (video != null) {
        final file = File(video.path);
        final fileName = path.basename(video.path);
        final mimeType = lookupMimeType(fileName) ?? 'video/mp4';
        
        return FileResult(
          file: file,
          fileName: fileName,
          fileType: 'video',
          mimeType: mimeType,
        );
      }
    } catch (e) {
      print('Error picking video: $e');
    }
    
    return null;
  }

  // Upload a file to your server and store the message in the database
  Future<String?> uploadFileAndSaveMessage({
    required FileResult fileResult,
    required int senderId,
    required int receiverId,
    int? groupId,
    String? message,
  }) async {
    try {
      // Generate a unique file name
      final String uniqueFileName = '${_uuid.v4()}${path.extension(fileResult.fileName)}';
      
      // In a real app, upload the file to your server/cloud storage
      // This is a placeholder for the actual upload process
      final String? fileUrl = await _uploadFile(fileResult.file, uniqueFileName);
      
      if (fileUrl != null) {
        // Create message content (optional text + file info)
        final String content = message?.isNotEmpty == true 
            ? message! 
            : '[${fileResult.fileType}] ${fileResult.fileName}';
        
        // Save message to database
        final messageData = {
          'senderId': senderId,
          'receiverId': receiverId,
          'groupId': groupId,
          'content': content,
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': 0,
          'fileUrl': fileUrl,
          'fileType': fileResult.fileType,
          'fileName': fileResult.fileName,
        };
        
        final messageId = await _databaseService.storeFileAttachment(messageData);
        return fileUrl;
      }
    } catch (e) {
      print('Error uploading file: $e');
    }
    
    return null;
  }
  
  // Simulated file upload (In a real app, this would upload to your server)
  Future<String?> _uploadFile(File file, String fileName) async {
    try {
      // In a real app, you would upload the file to your server/cloud storage
      // For this demo, we'll just simulate a delay and return a fake URL
      await Future.delayed(const Duration(seconds: 1));
      
      // For demo purposes, we're just returning a placeholder URL
      // In a real app, this would be the actual URL from your server
      return 'https://yourserver.com/uploads/$fileName';
      
      // Example of a real upload:
      /*
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });
      
      final response = await _dio.post(
        'https://yourserver.com/upload',
        data: formData,
      );
      
      if (response.statusCode == 200) {
        return response.data['fileUrl'];
      }
      */
    } catch (e) {
      print('Error during file upload: $e');
      return null;
    }
  }
  
  // Download a file from a URL (for viewing/opening attachments)
  Future<File?> downloadFile(String url, String fileName) async {
    try {
      // Get the temporary directory
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$fileName';
      
      // Check if the file already exists
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      
      // Download the file
      await _dio.download(url, filePath);
      
      return File(filePath);
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }
}

class FileResult {
  final File file;
  final String fileName;
  final String fileType;
  final String mimeType;
  
  FileResult({
    required this.file,
    required this.fileName,
    required this.fileType,
    required this.mimeType,
  });
}