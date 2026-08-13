import 'package:csv/csv.dart';

import '../data/database.dart';
import '../data/emotions_repository.dart';
import '../models/entry.dart';

class ImportResult {
  int imported = 0;
  int skippedExisting = 0;
  int skippedInvalid = 0;

  int get total => imported + skippedExisting + skippedInvalid;
}

class DaylioImportService {
  /// Daylio's default 5-point mood scale (French labels), mapped 1:1 onto
  /// Neurostatus' 1-5 scale: horrible=1, mauvais=2, mouais=3, bien=4, super=5.
  static const Map<String, int> _moodScores = {
    'horrible': 1,
    'mauvais': 2,
    'mouais': 3,
    'bien': 4,
    'super': 5,
  };

  /// Daylio "activities" tags this export actually used as emotion tags,
  /// mapped to the closest Neurostatus emotion. Tags with no good match are
  /// imported as new custom emotions instead (see [_customEmotionLabel]).
  static const Map<String, String> _emotionMap = {
    'anxieux': 'Anxiété',
    'stressé': 'Anxiété',
    'en colère': 'Colère',
    'fatigué': 'Fatigue',
    'heureux': 'Joie',
    'reconnaissant': 'Gratitude',
    'excité': 'Excitation',
    'triste': 'Tristesse',
    'détendu': 'Sérénité',
    'ennui': 'Ennui',
  };

  static String _customEmotionLabel(String rawTag) {
    const overrides = {
      'désespéré': 'Désespoir',
      'incertain': 'Incertitude',
      'satisfait': 'Satisfaction',
      'mauvaise nuit': 'Mauvaise nuit',
      'nuit moyenne': 'Nuit moyenne',
    };
    if (overrides.containsKey(rawTag)) return overrides[rawTag]!;
    if (rawTag.isEmpty) return rawTag;
    return rawTag[0].toUpperCase() + rawTag.substring(1);
  }

  String mapEmotion(String rawTag) {
    final normalized = rawTag.trim().toLowerCase();
    return _emotionMap[normalized] ?? _customEmotionLabel(normalized);
  }

  int? mapMood(String rawMood) => _moodScores[rawMood.trim().toLowerCase()];

  Future<ImportResult> importCsv(
    String csvContent, {
    bool overwriteExisting = false,
  }) async {
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvContent);
    final result = ImportResult();
    if (rows.isEmpty) return result;

    final header = rows.first.map((h) => h.toString().trim()).toList();
    final dateIdx = header.indexOf('full_date');
    final moodIdx = header.indexOf('mood');
    final activitiesIdx = header.indexOf('activities');
    final noteTitleIdx = header.indexOf('note_title');
    final noteIdx = header.indexOf('note');
    final scalesIdx = header.indexOf('scales');

    if (dateIdx == -1 || moodIdx == -1) {
      throw const FormatException(
        'Colonnes attendues introuvables (full_date, mood).',
      );
    }

    for (final row in rows.skip(1)) {
      if (row.length <= moodIdx || row.length <= dateIdx) {
        result.skippedInvalid++;
        continue;
      }

      final dateStr = row[dateIdx].toString().trim();
      DateTime date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        result.skippedInvalid++;
        continue;
      }

      final mood = mapMood(row[moodIdx].toString());
      if (mood == null) {
        result.skippedInvalid++;
        continue;
      }

      if (!overwriteExisting) {
        final existing = await AppDatabase.instance.entryForDate(date);
        if (existing != null) {
          result.skippedExisting++;
          continue;
        }
      }

      final emotions = <String>[];
      if (activitiesIdx != -1 && row.length > activitiesIdx) {
        final raw = row[activitiesIdx].toString();
        for (final tag in raw.split('|')) {
          final trimmed = tag.trim();
          if (trimmed.isEmpty) continue;
          final emotion = mapEmotion(trimmed);
          if (!emotions.contains(emotion)) emotions.add(emotion);
        }
      }
      for (final emotion in emotions) {
        await EmotionsRepository.instance.addCustomEmotion(emotion);
      }

      final eventParts = <String>[];
      for (final idx in [noteTitleIdx, noteIdx, scalesIdx]) {
        if (idx == -1 || row.length <= idx) continue;
        final value = row[idx].toString().trim();
        if (value.isNotEmpty) eventParts.add(value);
      }

      await AppDatabase.instance.upsertEntry(
        MoodEntry(
          date: date,
          mood: mood,
          emotions: emotions,
          event: eventParts.isEmpty ? null : eventParts.join(' — '),
          createdAt: DateTime.now(),
        ),
      );
      result.imported++;
    }

    return result;
  }
}
