import 'package:flutter/material.dart';

/// Soft multicolor pastel theme: pink as the lead color, lavender and mint
/// as accents. Each hue comes from Material 3's own seed algorithm (via a
/// throwaway ColorScheme per hue) so contrast-safe "on" colors are computed
/// for us rather than hand-picked.
ColorScheme _kawaiiScheme(Brightness brightness) {
  final pink = ColorScheme.fromSeed(
    seedColor: const Color(0xFFFF8FAB),
    brightness: brightness,
  );
  final lavender = ColorScheme.fromSeed(
    seedColor: const Color(0xFFB9A9F0),
    brightness: brightness,
  );
  final mint = ColorScheme.fromSeed(
    seedColor: const Color(0xFF8ED1B0),
    brightness: brightness,
  );

  return pink.copyWith(
    secondary: lavender.primary,
    onSecondary: lavender.onPrimary,
    secondaryContainer: lavender.primaryContainer,
    onSecondaryContainer: lavender.onPrimaryContainer,
    tertiary: mint.primary,
    onTertiary: mint.onPrimary,
    tertiaryContainer: mint.primaryContainer,
    onTertiaryContainer: mint.onPrimaryContainer,
  );
}

ThemeData _kawaiiTheme(Brightness brightness) {
  final colorScheme = _kawaiiScheme(brightness);
  const radius = 20.0;
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Baloo2',
    scaffoldBackgroundColor: colorScheme.surface,
    cardTheme: CardThemeData(
      shape: shape,
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: colorScheme.surfaceContainerHigh,
      selectedColor: colorScheme.primaryContainer,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: const StadiumBorder()),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorShape: const StadiumBorder(),
      backgroundColor: colorScheme.surfaceContainerLow,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      centerTitle: true,
    ),
    dialogTheme: DialogThemeData(shape: shape),
    bottomSheetTheme: BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      ),
    ),
  );
}

final kawaiiLightTheme = _kawaiiTheme(Brightness.light);
final kawaiiDarkTheme = _kawaiiTheme(Brightness.dark);
