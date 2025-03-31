// lib/models/story.dart
class Story {
  final int id;
  final int userId;
  String title;  // Already non-final which is good
  String content; // Changed to non-final
  List<String>? images; // Changed to non-final
  String category; // Changed to non-final
  final DateTime createdAt;
  int likesCount; // Changed to non-final to allow updates
  
  Story({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.images,
    required this.category,
    required this.createdAt,
    this.likesCount = 0,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'images': images?.join(','),
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'likesCount': likesCount,
    };
  }
  
  factory Story.fromMap(Map<String, dynamic> map) {
    return Story(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      content: map['content'],
      images: map['images'] != null && map['images'].toString().isNotEmpty 
          ? map['images'].toString().split(',') 
          : null,
      category: map['category'],
      createdAt: DateTime.parse(map['createdAt']),
      likesCount: map['likesCount'] ?? 0,
    );
  }
  
  // Copy with method for immutable updates
  Story copyWith({
    int? id,
    int? userId,
    String? title,
    String? content,
    List<String>? images,
    String? category,
    DateTime? createdAt,
    int? likesCount,
  }) {
    return Story(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      images: images ?? this.images,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
    );
  }
  
  // Convert images list to comma-separated string
  String? get imagesString {
    return images?.isNotEmpty == true ? images!.join(',') : null;
  }
  
  // Parse comma-separated string to images list
  static List<String>? parseImages(String? imagesString) {
    if (imagesString == null || imagesString.isEmpty) {
      return null;
    }
    return imagesString.split(',');
  }
}