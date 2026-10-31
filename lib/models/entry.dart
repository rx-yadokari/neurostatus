import 'dart:convert';

class MoodEntry {
  final int? id;
  final DateTime timestamp;
  final int mood;
  final int? fatigue;
  final List<String> emotions;
  final List<String> contacts;
  final String? event;
  final DateTime createdAt;

  MoodEntry({
    this.id,
    required this.timestamp,
    required this.mood,
    this.fatigue,
    required this.emotions,
    this.contacts = const [],
    this.event,
    required this.createdAt,
  });

  /// Calendar day this entry belongs to (several entries can share a day).
  DateTime get date => DateTime(timestamp.year, timestamp.month, timestamp.day);

  static String dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String().split('T').first;
  }

  String get dateStr => dateKey(timestamp);

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'date': dateStr,
      'mood': mood,
      'fatigue': fatigue,
      'emotions': jsonEncode(emotions),
      'contacts': jsonEncode(contacts),
      'event': event,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MoodEntry.fromMap(Map<String, Object?> map) {
    return MoodEntry(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      mood: map['mood'] as int,
      fatigue: map['fatigue'] as int?,
      emotions: (jsonDecode(map['emotions'] as String) as List).cast<String>(),
      contacts: map['contacts'] == null
          ? const []
          : (jsonDecode(map['contacts'] as String) as List).cast<String>(),
      event: map['event'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
