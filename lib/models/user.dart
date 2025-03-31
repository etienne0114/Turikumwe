// lib/models/user.dart
class User {
  final int id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? district;
  final String? profilePicture;
  final String? bio;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool? isAdmin;
  final bool? isVerified;
  
  User({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.district,
    this.profilePicture,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
    this.isAdmin,
    this.isVerified,
  });
  
  // Add getter for fullName to support UserAvatar component
  String get fullName => name;
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'district': district,
      'profilePicture': profilePicture,
      'bio': bio,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isAdmin': isAdmin == true ? 1 : 0,
      'isVerified': isVerified == true ? 1 : 0,
    };
  }
  
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      phoneNumber: map['phoneNumber'],
      district: map['district'],
      profilePicture: map['profilePicture'],
      bio: map['bio'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isAdmin: map['isAdmin'] == 1,
      isVerified: map['isVerified'] == 1,
    );
  }
}