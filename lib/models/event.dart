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
  final bool? isPrivate;
  final double? price;
  final String? paymentMethod;
  
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
    this.isPrivate,
    this.price,
    this.paymentMethod,
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
      'isPrivate': isPrivate,
      'price': price,
      'paymentMethod': paymentMethod,
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
      isPrivate: map['isPrivate'] == 1,
      price: map['price'] != null ? (map['price'] is int ? map['price'].toDouble() : map['price']) : null,
      paymentMethod: map['paymentMethod'],
    );
  }
  
  // Helper method to get attendees as a list of integers
  List<int> getAttendeesList() {
    if (attendeesIds == null || attendeesIds!.isEmpty) {
      return [];
    }
    
    return attendeesIds!
        .split(',')
        .where((id) => id.trim().isNotEmpty)
        .map((idStr) => int.parse(idStr.trim()))
        .toList();
  }
  
  // Get number of attendees
  int get attendeesCount {
    return getAttendeesList().length;
  }
  
  // Check if event is in the past
  bool get isPast {
    return date.isBefore(DateTime.now());
  }
  
  // Check if event is today
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  // Check if event is free
  bool get isFree {
    return price == null || price == 0;
  }
  
  // Create a copy of this event with updated fields
  Event copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? date,
    String? location,
    String? image,
    int? groupId,
    int? organizerId,
    String? attendeesIds,
    String? district,
    String? category,
    String? createdAt,
    String? updatedAt,
    bool? isPrivate,
    double? price,
    String? paymentMethod,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      location: location ?? this.location,
      image: image ?? this.image,
      groupId: groupId ?? this.groupId,
      organizerId: organizerId ?? this.organizerId,
      attendeesIds: attendeesIds ?? this.attendeesIds,
      district: district ?? this.district,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPrivate: isPrivate ?? this.isPrivate,
      price: price ?? this.price,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}