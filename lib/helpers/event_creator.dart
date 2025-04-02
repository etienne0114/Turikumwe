// lib/helpers/event_creator.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:turikumwe/services/database_service.dart';

/// Helper class to handle event creation/editing logic including image processing
class EventCreator {
  final DatabaseService _databaseService = DatabaseService();
  
  /// Create a new event
  Future<int> createEvent({
    required String title,
    required String description,
    required DateTime date,
    required String location,
    String? image,
    int? groupId,
    required int organizerId,
    String? district,
    String? category,
    bool? isPrivate,
    double? price,
    String? paymentMethod,
    bool? hasQuestionnaire,
    Map<String, dynamic>? questionnaireData,
  }) async {
    try {
      // Process image if any
      String? processedImagePath;
      if (image != null && image.isNotEmpty) {
        if (image.startsWith('http')) {
          processedImagePath = image; // Already a URL, no processing needed
        } else {
          processedImagePath = await _processLocalImage(image);
        }
      }
      
      // Convert questionnaireData to JSON string if provided
      String? questionnaireDataJson;
      if (questionnaireData != null) {
        questionnaireDataJson = jsonEncode(questionnaireData);
      }
      
      // Create the event data map
      final event = {
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'location': location,
        'image': processedImagePath,
        'groupId': groupId,
        'organizerId': organizerId,
        'district': district,
        'category': category,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isPrivate': isPrivate == true ? 1 : 0,
        'price': price,
        'paymentMethod': paymentMethod,
        'hasQuestionnaire': hasQuestionnaire == true ? 1 : 0,
        'questionnaireData': questionnaireDataJson,
      };
      
      // Insert into database
      return await _databaseService.safeInsertEvent(event);
    } catch (e) {
      debugPrint('Error creating event: $e');
      return 0;
    }
  }
  
  /// Update an existing event
  Future<bool> updateEvent({
    required int id,
    String? title,
    String? description,
    DateTime? date,
    String? location,
    String? image,
    int? groupId,
    String? district,
    String? category,
    bool? isPrivate,
    double? price,
    String? paymentMethod,
    bool? hasQuestionnaire,
    Map<String, dynamic>? questionnaireData,
  }) async {
    try {
      // Get existing event
      final existingEvent = await _databaseService.getEventById(id);
      if (existingEvent == null) {
        return false;
      }
      
      // Process image if changed
      String? processedImagePath = existingEvent.image;
      if (image != null && image != existingEvent.image) {
        if (image.startsWith('http')) {
          processedImagePath = image; // Already a URL, no processing needed
        } else {
          processedImagePath = await _processLocalImage(image);
        }
      }
      
      // Convert questionnaireData to JSON string if provided
      String? questionnaireDataJson;
      if (questionnaireData != null) {
        questionnaireDataJson = jsonEncode(questionnaireData);
      } else if (existingEvent.questionnaireData != null) {
        // Keep existing questionnaire data
        questionnaireDataJson = jsonEncode(existingEvent.questionnaireData);
      }
      
      // Create the event data map with updates
      final event = {
        'id': id,
        'title': title ?? existingEvent.title,
        'description': description ?? existingEvent.description,
        'date': date != null ? date.toIso8601String() : existingEvent.date.toIso8601String(),
        'location': location ?? existingEvent.location,
        'image': processedImagePath,
        'groupId': groupId ?? existingEvent.groupId,
        'district': district ?? existingEvent.district,
        'category': category ?? existingEvent.category,
        'updatedAt': DateTime.now().toIso8601String(),
        'isPrivate': isPrivate == true ? 1 : (existingEvent.isPrivate == true ? 1 : 0),
        'price': price ?? existingEvent.price,
        'paymentMethod': paymentMethod ?? existingEvent.paymentMethod,
        'hasQuestionnaire': hasQuestionnaire == true ? 1 : (existingEvent.hasQuestionnaire == true ? 1 : 0),
        'questionnaireData': questionnaireDataJson,
      };
      
      // Update in database
      final result = await _databaseService.updateEvent(event);
      return result > 0;
    } catch (e) {
      debugPrint('Error updating event: $e');
      return false;
    }
  }
  
  /// Process a local image file (copy to app documents directory)
  Future<String> _processLocalImage(String imagePath) async {
    try {
      // Generate a unique filename
      final uuid = const Uuid().v4();
      final extension = path.extension(imagePath);
      final filename = 'event_image_$uuid$extension';
      
      // Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final targetPath = path.join(appDir.path, filename);
      
      // Copy the file
      final File sourceFile = File(imagePath);
      await sourceFile.copy(targetPath);
      
      return targetPath;
    } catch (e) {
      debugPrint('Error processing image: $e');
      return imagePath; // Return original path on error
    }
  }
}