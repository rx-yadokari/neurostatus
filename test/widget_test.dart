import 'package:flutter_test/flutter_test.dart';

import 'package:neurostatus/models/entry.dart';

void main() {
  test('MoodEntry round-trips through map encoding', () {
    final entry = MoodEntry(
      date: DateTime(2026, 1, 15),
      mood: 7,
      emotions: const ['Joie', 'Fatigue'],
      contacts: const ['Alice', 'Groupe Foot'],
      event: 'Entretien important',
      createdAt: DateTime(2026, 1, 15, 20, 30),
    );

    final decoded = MoodEntry.fromMap(entry.toMap());

    expect(decoded.dateStr, '2026-01-15');
    expect(decoded.mood, 7);
    expect(decoded.emotions, ['Joie', 'Fatigue']);
    expect(decoded.contacts, ['Alice', 'Groupe Foot']);
    expect(decoded.event, 'Entretien important');
  });
}
