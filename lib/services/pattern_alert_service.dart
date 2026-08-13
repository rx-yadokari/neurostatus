import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';

class PatternAlertService {
  static const _snoozeKey = 'pattern_alert_snoozed_until';
  static const _concerningEmotions = {'Anxiété', 'Désespoir', 'Peur'};
  static const _minStreak = 3;
  static const _minCrisesPerWeek = 3;

  /// Returns a gentle, non-diagnostic message if the recent logs show a
  /// concerning pattern, or null if nothing stands out (or the alert was
  /// snoozed). This is pattern-matching over self-reported logs, not a
  /// medical assessment.
  Future<String?> checkForConcerningPattern() async {
    final prefs = await SharedPreferences.getInstance();
    final snoozedUntilStr = prefs.getString(_snoozeKey);
    if (snoozedUntilStr != null) {
      if (DateTime.now().isBefore(DateTime.parse(snoozedUntilStr))) {
        return null;
      }
    }

    final entries = await AppDatabase.instance.allEntries(descending: true);
    var streak = 0;
    if (entries.isNotEmpty &&
        DateTime.now().difference(entries.first.date).inDays <= 1) {
      DateTime? prevDate;
      for (final entry in entries) {
        if (prevDate != null &&
            prevDate.difference(entry.date).inDays != 1) {
          break;
        }
        final concerning =
            entry.mood <= 2 &&
            entry.emotions.any(_concerningEmotions.contains);
        if (!concerning) break;
        streak++;
        prevDate = entry.date;
        if (streak >= _minStreak) break;
      }
    }

    final crisisCount = await AppDatabase.instance.crisisLogCountSince(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    if (streak >= _minStreak && crisisCount >= _minCrisesPerWeek) {
      return 'Ton humeur est basse depuis $streak jours et tu as signalé '
          '$crisisCount crises cette semaine.';
    }
    if (streak >= _minStreak) {
      return 'Ton humeur est basse depuis $streak jours, avec de '
          'l\'anxiété, de la peur ou du désespoir associés.';
    }
    if (crisisCount >= _minCrisesPerWeek) {
      return 'Tu as signalé $crisisCount crises ces 7 derniers jours.';
    }
    return null;
  }

  Future<void> snoozeForOneWeek() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _snoozeKey,
      DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    );
  }
}
