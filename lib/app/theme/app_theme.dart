import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_controller.dart';

class AppTheme {
  static ThemeData get light => CopilotTheme.light;

  static ThemeData get dark => CopilotTheme.dark;

  static ThemeData get gold => CopilotTheme.gold;

  static ThemeData get aurora => CopilotTheme.aurora;

  static ThemeData get dracula => CopilotTheme.dracula;

  static ThemeData get tokyoNight => CopilotTheme.tokyoNight;

  static ThemeData get catppuccinMocha => CopilotTheme.catppuccinMocha;

  static ThemeData get catppuccinLatte => CopilotTheme.catppuccinLatte;

  static ThemeData get solarizedLight => CopilotTheme.solarizedLight;

  static ThemeData get quietLight => CopilotTheme.quietLight;

  static ThemeData forVariant(AppThemeVariant variant) {
    return switch (variant) {
      AppThemeVariant.vectorDark => dark,
      AppThemeVariant.vectorLight => light,
      AppThemeVariant.gold => gold,
      AppThemeVariant.aurora => aurora,
      AppThemeVariant.dracula => dracula,
      AppThemeVariant.tokyoNight => tokyoNight,
      AppThemeVariant.catppuccinMocha => catppuccinMocha,
      AppThemeVariant.catppuccinLatte => catppuccinLatte,
      AppThemeVariant.solarizedLight => solarizedLight,
      AppThemeVariant.quietLight => quietLight,
    };
  }

  const AppTheme._();
}
