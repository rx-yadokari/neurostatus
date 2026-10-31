/// Emoji shown next to each emotion, for quick visual scanning rather than
/// reading every label. Falls back to a neutral sparkle for custom emotions
/// that aren't in this predefined set.
class EmotionIcons {
  static const Map<String, String> _byName = {
    'Joie': '😄',
    'Tristesse': '😢',
    'Colère': '😠',
    'Peur': '😨',
    'Anxiété': '😰',
    'Sérénité': '😌',
    'Fatigue': '😴',
    'Gratitude': '🙏',
    'Espoir': '🌱',
    'Solitude': '🥺',
    'Ennui': '😑',
    'Excitation': '🤩',
    'Amour': '🥰',
    'Incertitude': '😕',
    'Désespoir': '💔',
    'Satisfaction': '😊',
  };

  static const String _fallback = '✨';

  static String iconFor(String emotion) => _byName[emotion] ?? _fallback;

  /// "😄 Joie" — for inline text (history rows, tooltips) rather than chips.
  static String withIcon(String emotion) => '${iconFor(emotion)} $emotion';
}
