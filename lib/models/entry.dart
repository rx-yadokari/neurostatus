import 'dart:convert';

class MoodEntry {
  final int? id;
  final DateTime date;
  final int mood;
  final List<String> emotions;
  final String? event;
  final DateTime createdAt;

  MoodEntry({
    this.id,
    required this.date,
    required this.mood,
    required this.emotions,
    this.event,
    required this.createdAt,
  });

  static String dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String().split('T').first;
  }

  String get dateStr => dateKey(date);

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': dateStr,
      'mood': mood,
      'emotions': jsonEncode(emotions),
      'event': event,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MoodEntry.fromMap(Map<String, Object?> map) {
    return MoodEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      mood: map['mood'] as int,
      emotions: (jsonDecode(map['emotions'] as String) as List).cast<String>(),
      event: map['event'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
