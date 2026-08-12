import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_controller.dart';

class AppTheme {
  static ThemeData get light => CopilotTheme.light;

  static ThemeData get dark => CopilotTheme.dark;

  static ThemeData get gold => CopilotTheme.gold;

  static ThemeData get aurora => CopilotTheme.aurora;

  static ThemeData forVariant(AppThemeVariant variant) {
    return switch (variant) {
      AppThemeVariant.vectorDark => dark,
      AppThemeVariant.vectorLight => light,
      AppThemeVariant.gold => gold,
      AppThemeVariant.aurora => aurora,
    };
  }

  const AppTheme._();
}
