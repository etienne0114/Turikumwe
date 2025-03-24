// lib/models/group.dart
class Group {
  final int id;
  final String name;
  final String description;
  final String? image;
  final String category;
  final String? district;
  final int membersCount;
  final DateTime createdAt;
  
  Group({
    required this.id,
    required this.name,
    required this.description,
    this.image,
    required this.category,
    this.district,
    this.membersCount = 0,
    required this.createdAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image': image,
      'category': category,
      'district': district,
      'membersCount': membersCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      image: map['image'],
      category: map['category'],
      district: map['district'],
      membersCount: map['membersCount'] ?? 0,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}