// lib/models/event.dart
class Event {
  final int id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final String? image;
  final int? groupId;
  final int organizerId;
  final String? attendeesIds;
  final String? district;
  final String? category;
  final String? createdAt;
  final String? updatedAt;
  
  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    this.image,
    this.groupId,
    required this.organizerId,
    this.attendeesIds,
    this.district,
    this.category,
    this.createdAt,
    this.updatedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'location': location,
      'image': image,
      'groupId': groupId,
      'organizerId': organizerId,
      'attendeesIds': attendeesIds,
      'district': district,
      'category': category,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
  
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      date: DateTime.parse(map['date']),
      location: map['location'],
      image: map['image'],
      groupId: map['groupId'],
      organizerId: map['organizerId'],
      attendeesIds: map['attendeesIds'],
      district: map['district'],
      category: map['category'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }
  
  // Helper method to get attendees as a list of integers
  List<int> getAttendeesList() {
    if (attendeesIds == null || attendeesIds!.isEmpty) {
      return [];
    }
    
    return attendeesIds!
        .split(',')
        .map((idStr) => int.parse(idStr.trim()))
        .toList();
  }
}