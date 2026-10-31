import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/entry.dart';

class ExportService {
  static Future<void> exportAndShare(List<MoodEntry> entries) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final csvFile = File('${dir.path}/neurostatus_$timestamp.csv');
    await csvFile.writeAsString(_toCsv(entries));

    final jsonFile = File('${dir.path}/neurostatus_$timestamp.json');
    await jsonFile.writeAsString(_toJson(entries));

    await SharePlus.instance.share(
      ShareParams(
        text: 'Export Neurostatus (${entries.length} entrées)',
        files: [XFile(csvFile.path), XFile(jsonFile.path)],
      ),
    );
  }

  static String _toCsv(List<MoodEntry> entries) {
    final buffer = StringBuffer(
      'timestamp,mood,fatigue,emotions,contacts,event\n',
    );
    for (final e in entries) {
      final fatigue = e.fatigue?.toString() ?? '';
      final emotions = e.emotions.join('|');
      final contacts = e.contacts.join('|');
      final event = (e.event ?? '').replaceAll(',', ';').replaceAll('\n', ' ');
      buffer.writeln(
        '${e.timestamp.toIso8601String()},${e.mood},$fatigue,$emotions,$contacts,$event',
      );
    }
    return buffer.toString();
  }

  static String _toJson(List<MoodEntry> entries) {
    final list = entries
        .map((e) => {
              'timestamp': e.timestamp.toIso8601String(),
              'mood': e.mood,
              'fatigue': e.fatigue,
              'emotions': e.emotions,
              'contacts': e.contacts,
              'event': e.event,
            })
        .toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }
}
