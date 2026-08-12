import 'package:flutter/material.dart';

class AppTypography {
  static const fontFamily = 'Inter';

  static TextTheme textTheme({required Color color}) {
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 57, height: 1.12),
      displayMedium: TextStyle(fontSize: 45, height: 1.16),
      displaySmall: TextStyle(fontSize: 36, height: 1.22),
      headlineLarge: TextStyle(fontSize: 32, height: 1.25),
      headlineMedium: TextStyle(fontSize: 28, height: 1.28),
      headlineSmall: TextStyle(fontSize: 24, height: 1.32),
      titleLarge: TextStyle(fontSize: 22, height: 1.28),
      titleMedium: TextStyle(fontSize: 16, height: 1.35),
      titleSmall: TextStyle(fontSize: 14, height: 1.35),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, height: 1.42),
      labelLarge: TextStyle(fontSize: 14, height: 1.25),
      labelMedium: TextStyle(fontSize: 12, height: 1.25),
      labelSmall: TextStyle(fontSize: 11, height: 1.20),
    ).apply(fontFamily: fontFamily, bodyColor: color, displayColor: color);
  }

  const AppTypography._();
}
