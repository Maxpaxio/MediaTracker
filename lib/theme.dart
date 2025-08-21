import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  colorSchemeSeed: Colors.deepPurple,
  useMaterial3: true,
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorSchemeSeed: Colors.deepPurple,
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFF1E1E1E), // dark gray
  cardColor: const Color(0xFF232323),
  dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF232323)),
);
