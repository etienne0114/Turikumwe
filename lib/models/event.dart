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
  final List<int>? attendeesIds;
  
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
      'attendeesIds': attendeesIds != null ? attendeesIds!.join(',') : null,
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
      attendeesIds: map['attendeesIds'] != null 
          ? map['attendeesIds'].split(',').map<int>((id) => int.parse(id)).toList() 
          : null,
    );
  }
}