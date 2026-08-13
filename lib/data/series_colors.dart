import 'package:flutter/material.dart';

/// Fixed 8-hue categorical order for labeled, positionally-distinct series
/// (each row/legend entry carries its own text label, so full CVD separation
/// across all 8 isn't required the way it is for unlabeled adjacent marks).
class SeriesColors {
  static const int maxSeries = 8;

  static const List<Color> _light = [
    Color(0xFF2A78D6),
    Color(0xFFEB6834),
    Color(0xFF1BAF7A),
    Color(0xFFEDA100),
    Color(0xFFE87BA4),
    Color(0xFF008300),
    Color(0xFF4A3AA7),
    Color(0xFFE34948),
  ];

  static const List<Color> _dark = [
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
    Color(0xFF9085E9),
    Color(0xFFE66767),
  ];

  /// [stableIndex] should come from the entity's fixed position in its
  /// catalog (not from its position among a currently-selected subset), so
  /// color never repaints when the selection changes.
  static Color colorFor(int stableIndex, Brightness brightness) {
    final palette = brightness == Brightness.dark ? _dark : _light;
    return palette[stableIndex % palette.length];
  }
}
