import '../data/contacts_repository.dart';
import '../data/database.dart';
import '../models/entry.dart';

/// Mood on days a contact was tagged versus mood on every other day.
///
/// This is a plain average comparison over self-reported logs, not a
/// controlled study — it can't separate "this person affects my mood" from
/// "I tend to see this person on days that are already good/bad for other
/// reasons". [delta] is hidden below [ContactInfluenceService.minSample] on
/// either side so a single data point can't produce a dramatic-looking score.
class ContactInfluence {
  final String name;
  final int daysWith;
  final double avgMoodWith;
  final int daysWithout;
  final double avgMoodWithout;

  ContactInfluence({
    required this.name,
    required this.daysWith,
    required this.avgMoodWith,
    required this.daysWithout,
    required this.avgMoodWithout,
  });

  bool get hasEnoughData =>
      daysWith >= ContactInfluenceService.minSample &&
      daysWithout >= ContactInfluenceService.minSample;

  /// Difference in average mood (with minus without), on the 1-5 scale.
  /// Null when there isn't enough data on one side to compare.
  double? get delta => hasEnoughData ? avgMoodWith - avgMoodWithout : null;
}

class ContactInfluenceService {
  static const int minSample = 2;

  Future<List<ContactInfluence>> computeAll() async {
    final entries = await AppDatabase.instance.allEntries();
    final contacts = await ContactsRepository.instance.allContacts();
    return [for (final name in contacts) _influenceFor(name, entries)];
  }

  ContactInfluence _influenceFor(String name, List<MoodEntry> entries) {
    final withMoods = <int>[];
    final withoutMoods = <int>[];
    for (final entry in entries) {
      if (entry.contacts.contains(name)) {
        withMoods.add(entry.mood);
      } else {
        withoutMoods.add(entry.mood);
      }
    }
    return ContactInfluence(
      name: name,
      daysWith: withMoods.length,
      avgMoodWith: _average(withMoods),
      daysWithout: withoutMoods.length,
      avgMoodWithout: _average(withoutMoods),
    );
  }

  double _average(List<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
