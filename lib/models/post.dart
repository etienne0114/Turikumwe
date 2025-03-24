// lib/models/post.dart
class Post {
  final int id;
  final int userId;
  final int? groupId;
  final String content;
  final List<String>? images;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  
  Post({
    required this.id,
    required this.userId,
    this.groupId,
    required this.content,
    this.images,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'groupId': groupId,
      'content': content,
      'images': images?.join(','),
      'createdAt': createdAt.toIso8601String(),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
    };
  }
  
  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'],
      userId: map['userId'],
      groupId: map['groupId'],
      content: map['content'],
      images: map['images']?.split(','),
      createdAt: DateTime.parse(map['createdAt']),
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
    );
  }
}