import 'package:flutter/material.dart';

/// Fixed status-style colors for the 1-5 mood scale, worst to best. These are
/// mode-invariant (same hex in light and dark) like the design system's
/// status palette, since the mood score is a state indicator, not an
/// open-ended category — height on the chart already carries the same
/// magnitude, so color here is a redundant, not sole, cue.
class MoodColors {
  static const Map<int, Color> _byScore = {
    1: Color(0xFFD03B3B), // critical
    2: Color(0xFFEC835A), // serious
    3: Color(0xFFFAB219), // warning
    4: Color(0xFF83AA12), // leaning good
    5: Color(0xFF0CA30C), // good
  };

  static Color colorFor(int mood) => _byScore[mood.clamp(1, 5)]!;

  static const legend = [1, 2, 3, 4, 5];
}
