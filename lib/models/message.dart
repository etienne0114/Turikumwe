// lib/models/message.dart
class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final int? groupId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String? fileUrl;
  final String? fileType;
  final String? fileName;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.groupId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.fileUrl,
    this.fileType,
    this.fileName,
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
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileName': fileName,
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
      fileUrl: map['fileUrl'],
      fileType: map['fileType'],
      fileName: map['fileName'],
    );
  }
}