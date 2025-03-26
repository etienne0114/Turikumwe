// lib/models/post.dart
class Post {
  final int id;
  final int userId;
  final int? groupId;
  final String content;
  final String? images;
  final String createdAt;
  
  // Make these non-final so they can be updated
  int likesCount;
  int commentsCount;

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

  // Convert a Post into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'groupId': groupId,
      'content': content,
      'images': images,
      'createdAt': createdAt,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
    };
  }

  // Create a Post from a Map
  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'],
      userId: map['userId'],
      groupId: map['groupId'],
      content: map['content'],
      images: map['images'],
      createdAt: map['createdAt'],
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
    );
  }

  // Create a copy of this Post with given fields replaced with the new values
  Post copyWith({
    int? id,
    int? userId,
    int? groupId,
    String? content,
    String? images,
    String? createdAt,
    int? likesCount,
    int? commentsCount,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      content: content ?? this.content,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}