// lib/models/event_analytics.dart
class EventAnalytics {
  final int id;
  final int eventId;
  final int viewCount;
  final int shareCount;
  final int clickCount;
  final DateTime lastUpdated;

  EventAnalytics({
    required this.id,
    required this.eventId,
    required this.viewCount,
    required this.shareCount,
    required this.clickCount,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'viewCount': viewCount,
      'shareCount': shareCount,
      'clickCount': clickCount,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory EventAnalytics.fromMap(Map<String, dynamic> map) {
    return EventAnalytics(
      id: map['id'],
      eventId: map['eventId'],
      viewCount: map['viewCount'],
      shareCount: map['shareCount'],
      clickCount: map['clickCount'],
      lastUpdated: DateTime.parse(map['lastUpdated']),
    );
  }

  // Create a copy with updated fields
  EventAnalytics copyWith({
    int? id,
    int? eventId,
    int? viewCount,
    int? shareCount,
    int? clickCount,
    DateTime? lastUpdated,
  }) {
    return EventAnalytics(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      viewCount: viewCount ?? this.viewCount,
      shareCount: shareCount ?? this.shareCount,
      clickCount: clickCount ?? this.clickCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}