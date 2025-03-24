// lib/models/notification.dart
class Notification {
  final int id;
  final int userId;
  final String title;
  final String content;
  final String type;
  final int? relatedId;
  final DateTime timestamp;
  final bool isRead;
  
  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.type,
    this.relatedId,
    required this.timestamp,
    this.isRead = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'type': type,
      'relatedId': relatedId,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead ? 1 : 0,
    };
  }
  
  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      content: map['content'],
      type: map['type'],
      relatedId: map['relatedId'],
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['isRead'] == 1,
    );
  }
}