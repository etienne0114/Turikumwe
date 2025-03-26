class Story {
  final int id;
  final int userId;
  final String title;
  final String content;
  final List<String>? images;
  final String category;
  final DateTime createdAt;
  final int likesCount;
  final String? userProfile;
  final String? userName;
  
  Story({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.images,
    required this.category,
    required this.createdAt,
    this.likesCount = 0,
    this.userProfile,
    this.userName,
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
      'userProfile': userProfile,
      'userName': userName,
    };
  }
  
  factory Story.fromMap(Map<String, dynamic> map) {
    return Story(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      content: map['content'],
      images: map['images']?.split(','),
      category: map['category'],
      createdAt: DateTime.parse(map['createdAt']),
      likesCount: map['likesCount'] ?? 0,
      userProfile: map['userProfile'],
      userName: map['userName'],
    );
  }
}