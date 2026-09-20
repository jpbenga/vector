import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeVariant {
  vectorDark,
  vectorLight,
  gold,
  aurora,
  dracula,
  tokyoNight,
  catppuccinMocha,
  catppuccinLatte,
  solarizedLight,
  quietLight;

  String get label {
    return switch (this) {
      AppThemeVariant.vectorDark => 'Vector Dark',
      AppThemeVariant.vectorLight => 'Vector Light',
      AppThemeVariant.gold => 'Vector Gold',
      AppThemeVariant.aurora => 'Vector Aurora',
      AppThemeVariant.dracula => 'Dracula',
      AppThemeVariant.tokyoNight => 'Tokyo Night',
      AppThemeVariant.catppuccinMocha => 'Catppuccin Mocha',
      AppThemeVariant.catppuccinLatte => 'Catppuccin Latte',
      AppThemeVariant.solarizedLight => 'Solarized Light',
      AppThemeVariant.quietLight => 'Quiet Light',
    };
  }

  String get shortLabel {
    return switch (this) {
      AppThemeVariant.vectorDark => 'Dark',
      AppThemeVariant.vectorLight => 'Light',
      AppThemeVariant.gold => 'Gold',
      AppThemeVariant.aurora => 'Aurora',
      AppThemeVariant.dracula => 'Dracula',
      AppThemeVariant.tokyoNight => 'Tokyo',
      AppThemeVariant.catppuccinMocha => 'Mocha',
      AppThemeVariant.catppuccinLatte => 'Latte',
      AppThemeVariant.solarizedLight => 'Solarized',
      AppThemeVariant.quietLight => 'Quiet',
    };
  }

  Brightness get brightness {
    return switch (this) {
      AppThemeVariant.vectorLight ||
      AppThemeVariant.catppuccinLatte ||
      AppThemeVariant.solarizedLight ||
      AppThemeVariant.quietLight => Brightness.light,
      _ => Brightness.dark,
    };
  }

  bool get isLight => brightness == Brightness.light;

  IconData get icon {
    return switch (this) {
      AppThemeVariant.vectorDark => Icons.dark_mode_outlined,
      AppThemeVariant.vectorLight => Icons.light_mode_outlined,
      AppThemeVariant.gold => Icons.palette_outlined,
      AppThemeVariant.aurora => Icons.auto_awesome_rounded,
      AppThemeVariant.dracula => Icons.nights_stay_outlined,
      AppThemeVariant.tokyoNight => Icons.nightlight_round,
      AppThemeVariant.catppuccinMocha => Icons.coffee_outlined,
      AppThemeVariant.catppuccinLatte => Icons.coffee_rounded,
      AppThemeVariant.solarizedLight => Icons.wb_sunny_outlined,
      AppThemeVariant.quietLight => Icons.light_mode_outlined,
    };
  }
}

abstract interface class AppThemePreferenceStore {
  Future<String?> readVariantName();

  Future<void> writeVariantName(String value);
}

class SharedPreferencesThemePreferenceStore implements AppThemePreferenceStore {
  static const _key = 'app_theme_variant_v1';

  @override
  Future<String?> readVariantName() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key);
  }

  @override
  Future<void> writeVariantName(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, value);
  }
}

class AppThemeController extends ValueNotifier<AppThemeVariant> {
  AppThemeController({
    AppThemeVariant initialVariant = AppThemeVariant.vectorDark,
    AppThemePreferenceStore? preferenceStore,
  }) : super(initialVariant) {
    _preferenceStore = preferenceStore;
  }

  AppThemePreferenceStore? _preferenceStore;

  AppThemeVariant get variant => value;

  void toggle() {
    final variants = AppThemeVariant.values;
    final nextIndex = (variants.indexOf(value) + 1) % variants.length;
    select(variants[nextIndex]);
  }

  void toggleBrightness() {
    select(
      value.isLight ? AppThemeVariant.vectorDark : AppThemeVariant.vectorLight,
    );
  }

  void select(AppThemeVariant variant) {
    value = variant;
    final store = _preferenceStore;
    if (store != null) {
      unawaited(_persist(store, variant));
    }
  }

  /// Restores an app-level setting independently of authentication.
  /// Reconnecting therefore never resets the user's theme.
  Future<void> restore([AppThemePreferenceStore? preferenceStore]) async {
    _preferenceStore = preferenceStore ?? _preferenceStore;
    final store = _preferenceStore;
    if (store == null) return;

    try {
      final name = await store.readVariantName();
      final restored = AppThemeVariant.values
          .where((variant) => variant.name == name)
          .firstOrNull;
      if (restored != null) {
        value = restored;
      }
    } catch (_) {
      // A storage failure must not block application startup.
    }
  }

  Future<void> _persist(
    AppThemePreferenceStore store,
    AppThemeVariant variant,
  ) async {
    try {
      await store.writeVariantName(variant.name);
    } catch (_) {
      // Keep the selected theme for this session when storage is unavailable.
    }
  }
}

final appThemeController = AppThemeController();
