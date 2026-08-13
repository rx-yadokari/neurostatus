import 'package:shared_preferences/shared_preferences.dart';

class EmotionsRepository {
  EmotionsRepository._();
  static final EmotionsRepository instance = EmotionsRepository._();

  static const _prefsKey = 'custom_emotions';

  static const List<String> predefined = [
    'Joie',
    'Tristesse',
    'Colère',
    'Peur',
    'Anxiété',
    'Sérénité',
    'Fatigue',
    'Gratitude',
    'Espoir',
    'Solitude',
    'Ennui',
    'Excitation',
    'Amour',
    'Incertitude',
    'Désespoir',
    'Satisfaction',
  ];

  // Tags that turned out not to be emotions (Daylio sleep-quality import
  // artifacts) and get pruned from custom storage the next time it's read.
  static const _nonEmotionTags = ['Mauvaise nuit', 'Nuit moyenne'];

  Future<List<String>> customEmotions() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? [];
    final cleaned = stored
        .where((e) => !predefined.contains(e) && !_nonEmotionTags.contains(e))
        .toList();
    if (cleaned.length != stored.length) {
      await prefs.setStringList(_prefsKey, cleaned);
    }
    return cleaned;
  }

  Future<void> removeCustomEmotion(String emotion) async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_prefsKey) ?? [];
    custom.remove(emotion);
    await prefs.setStringList(_prefsKey, custom);
  }

  Future<List<String>> allEmotions() async {
    final custom = await customEmotions();
    final merged = [...predefined];
    for (final e in custom) {
      if (!merged.contains(e)) merged.add(e);
    }
    return merged;
  }

  Future<void> addCustomEmotion(String emotion) async {
    final trimmed = emotion.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_prefsKey) ?? [];
    if (!predefined.contains(trimmed) && !custom.contains(trimmed)) {
      custom.add(trimmed);
      await prefs.setStringList(_prefsKey, custom);
    }
  }
}
