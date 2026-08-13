import 'dart:convert';

class CrisisLog {
  final int? id;
  final DateTime timestamp;
  final int intensity;
  final int? durationMinutes;
  final String? trigger;
  final List<String> emotions;

  CrisisLog({
    this.id,
    required this.timestamp,
    required this.intensity,
    this.durationMinutes,
    this.trigger,
    required this.emotions,
  });

  String get dateStr => timestamp.toIso8601String().split('T').first;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'intensity': intensity,
      'duration_minutes': durationMinutes,
      'trigger': trigger,
      'emotions': jsonEncode(emotions),
    };
  }

  factory CrisisLog.fromMap(Map<String, Object?> map) {
    return CrisisLog(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      intensity: map['intensity'] as int,
      durationMinutes: map['duration_minutes'] as int?,
      trigger: map['trigger'] as String?,
      emotions: (jsonDecode(map['emotions'] as String) as List).cast<String>(),
    );
  }
}
