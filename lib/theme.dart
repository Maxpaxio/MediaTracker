import 'package:flutter/material.dart';

ThemeData buildDarkTheme() {
  const surface = Color(0xFF1B1B1E);
  const surface2 = Color(0xFF232327);
  const onSurface = Colors.white;
  const accent = Color(0xFFB48CFF);

  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: surface,
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      secondary: accent,
      surface: surface,
      onSurface: onSurface,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: surface2,
      foregroundColor: onSurface,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
    ),
    // ✅ FIX: use CardThemeData instead of CardTheme
    cardTheme: CardThemeData(
      color: surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2C2C32),
      thickness: 0.7,
      space: 24,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: Color(0xFF3A3A42),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    ),
  );
}

// Optional shortcut
extension ThemeX on BuildContext {
  Color get accent => const Color(0xFFB48CFF);
}
