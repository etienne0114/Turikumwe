// lib/models/message.dart
class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final int? groupId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  
  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.groupId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'groupId': groupId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead ? 1 : 0,
    };
  }
  
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      groupId: map['groupId'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['isRead'] == 1,
    );
  }
}