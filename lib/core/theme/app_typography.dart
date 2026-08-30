import 'package:flutter/material.dart';

class AppTypography {
  static const fontFamily = 'Inter';

  static TextTheme textTheme({required Color color}) {
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 54, height: 1.12),
      displayMedium: TextStyle(fontSize: 42, height: 1.16),
      displaySmall: TextStyle(fontSize: 34, height: 1.20),
      headlineLarge: TextStyle(fontSize: 30, height: 1.24),
      headlineMedium: TextStyle(fontSize: 26, height: 1.26),
      headlineSmall: TextStyle(fontSize: 22, height: 1.30),
      titleLarge: TextStyle(fontSize: 20, height: 1.26),
      titleMedium: TextStyle(fontSize: 15, height: 1.32),
      titleSmall: TextStyle(fontSize: 13, height: 1.32),
      bodyLarge: TextStyle(fontSize: 15, height: 1.40),
      bodyMedium: TextStyle(fontSize: 13, height: 1.40),
      bodySmall: TextStyle(fontSize: 11, height: 1.35),
      labelLarge: TextStyle(fontSize: 13, height: 1.22),
      labelMedium: TextStyle(fontSize: 11, height: 1.22),
      labelSmall: TextStyle(fontSize: 10, height: 1.18),
    ).apply(fontFamily: fontFamily, bodyColor: color, displayColor: color);
  }

  const AppTypography._();
}
