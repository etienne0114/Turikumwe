// lib/helpers/event_creator.dart

import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/services/database_service.dart';

class EventCreator {
  final DatabaseService _databaseService = DatabaseService();

  // Create an event with proper error handling for the database schema
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
    bool isPrivate = false,
    double? price,
    String? paymentMethod,
  }) async {
    // First, ensure the database schema is updated
    await _databaseService.updateEventTableIfNeeded();

    // Prepare the event data
    final Map<String, dynamic> eventData = {
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'location': location,
      'image': image,
      'groupId': groupId,
      'organizerId': organizerId,
      'district': district,
      'category': category,
      'isPrivate': isPrivate ? 1 : 0, // Convert boolean to SQLite integer
      'price': price,
      'paymentMethod': paymentMethod,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // Use the safe insert method
    return await _databaseService.safeInsertEvent(eventData);
  }

  // Update an existing event
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
  }) async {
    // First, get the current event
    final event = await _databaseService.getEventById(id);
    if (event == null) {
      return false;
    }

    // Create updated event data
    final Map<String, dynamic> eventData = {
      'id': id,
      'title': title ?? event.title,
      'description': description ?? event.description,
      'date': date != null ? date.toIso8601String() : event.date.toIso8601String(),
      'location': location ?? event.location,
      'image': image ?? event.image,
      'groupId': groupId ?? event.groupId,
      'organizerId': event.organizerId, // Cannot change organizer
      'district': district ?? event.district,
      'category': category ?? event.category,
      'isPrivate': isPrivate != null ? (isPrivate ? 1 : 0) : (event.isPrivate ?? false ? 1 : 0),
      'price': price ?? event.price,
      'paymentMethod': paymentMethod ?? event.paymentMethod,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // First ensure the schema is updated
    await _databaseService.updateEventTableIfNeeded();

    // Update the event
    final result = await _databaseService.updateEvent(eventData);
    return result > 0;
  }

  // Toggle event visibility
  Future<bool> toggleEventVisibility(int eventId) async {
    final event = await _databaseService.getEventById(eventId);
    if (event == null) {
      return false;
    }

    // Toggle the isPrivate value
    final isCurrentlyPrivate = event.isPrivate ?? false;
    
    final Map<String, dynamic> eventData = {
      'id': eventId,
      'isPrivate': isCurrentlyPrivate ? 0 : 1,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // Update the event
    final result = await _databaseService.updateEvent(eventData);
    return result > 0;
  }
}