import 'package:flutter/material.dart';

enum AppThemeVariant {
  vectorDark,
  vectorLight,
  gold,
  aurora;

  String get label {
    return switch (this) {
      AppThemeVariant.vectorDark => 'Vector Dark',
      AppThemeVariant.vectorLight => 'Vector Light',
      AppThemeVariant.gold => 'Vector Gold',
      AppThemeVariant.aurora => 'Vector Aurora',
    };
  }

  String get shortLabel {
    return switch (this) {
      AppThemeVariant.vectorDark => 'Dark',
      AppThemeVariant.vectorLight => 'Light',
      AppThemeVariant.gold => 'Gold',
      AppThemeVariant.aurora => 'Aurora',
    };
  }

  IconData get icon {
    return switch (this) {
      AppThemeVariant.vectorDark => Icons.dark_mode_outlined,
      AppThemeVariant.vectorLight => Icons.light_mode_outlined,
      AppThemeVariant.gold => Icons.palette_outlined,
      AppThemeVariant.aurora => Icons.auto_awesome_rounded,
    };
  }
}

class AppThemeController extends ValueNotifier<AppThemeVariant> {
  AppThemeController() : super(AppThemeVariant.vectorDark);

  AppThemeVariant get variant => value;

  void toggle() {
    final variants = AppThemeVariant.values;
    final nextIndex = (variants.indexOf(value) + 1) % variants.length;
    value = variants[nextIndex];
  }

  void select(AppThemeVariant variant) {
    value = variant;
  }
}

final appThemeController = AppThemeController();
