import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_components.dart';
import 'app_radius.dart';
import 'app_shadows.dart';
import 'app_typography.dart';

class VectorThemeTokens {
  const VectorThemeTokens({
    required this.brightness,
    required this.brand,
    required this.surfaces,
    required this.text,
    required this.semantic,
    required this.components,
    required this.opportunities,
  });

  final Brightness brightness;
  final AppBrandPalette brand;
  final AppSurfacePalette surfaces;
  final AppTextPalette text;
  final AppSemanticPalette semantic;
  final AppComponentColors components;
  final AppOpportunityPalette opportunities;

  static final vectorDark = VectorThemeTokens(
    brightness: Brightness.dark,
    brand: AppBrandPalette.vectorDark,
    surfaces: AppSurfacePalette.vectorDark,
    text: AppTextPalette.vectorDark,
    semantic: AppSemanticPalette.vectorDark,
    components: AppComponentColors.vectorDark,
    opportunities: AppOpportunityPalette.vectorDark,
  );

  static final vectorLight = VectorThemeTokens(
    brightness: Brightness.light,
    brand: AppBrandPalette.vectorLight,
    surfaces: AppSurfacePalette.vectorLight,
    text: AppTextPalette.vectorLight,
    semantic: AppSemanticPalette.vectorLight,
    components: AppComponentColors.vectorLight,
    opportunities: AppOpportunityPalette.vectorLight,
  );

  static final gold = VectorThemeTokens(
    brightness: Brightness.dark,
    brand: AppBrandPalette.gold,
    surfaces: AppSurfacePalette.gold,
    text: AppTextPalette.gold,
    semantic: AppSemanticPalette.gold,
    components: AppComponentColors.gold,
    opportunities: AppOpportunityPalette.gold,
  );

  static final aurora = VectorThemeTokens(
    brightness: Brightness.dark,
    brand: AppBrandPalette.aurora,
    surfaces: AppSurfacePalette.aurora,
    text: AppTextPalette.aurora,
    semantic: AppSemanticPalette.aurora,
    components: AppComponentColors.aurora,
    opportunities: AppOpportunityPalette.aurora,
  );
}

class CopilotTheme {
  static ThemeData get dark => _buildTheme(VectorThemeTokens.vectorDark);

  static ThemeData get light => _buildTheme(VectorThemeTokens.vectorLight);

  static ThemeData get gold {
    return _buildTheme(VectorThemeTokens.gold);
  }

  static ThemeData get aurora {
    return _buildTheme(VectorThemeTokens.aurora);
  }

  static ThemeData _buildTheme(VectorThemeTokens tokens) {
    final colorScheme = ColorScheme(
      brightness: tokens.brightness,
      primary: tokens.brand.accent,
      onPrimary: tokens.brand.onAccent,
      primaryContainer: tokens.brand.accentDark,
      onPrimaryContainer: tokens.brand.onAccent,
      secondary: tokens.semantic.info,
      onSecondary: tokens.surfaces.background,
      secondaryContainer: tokens.surfaces.surfaceHover,
      onSecondaryContainer: tokens.text.primary,
      tertiary: tokens.semantic.warning,
      onTertiary: tokens.surfaces.background,
      tertiaryContainer: tokens.surfaces.surfaceHover,
      onTertiaryContainer: tokens.text.primary,
      error: tokens.semantic.error,
      onError: tokens.surfaces.background,
      errorContainer: tokens.surfaces.surfaceHover,
      onErrorContainer: tokens.semantic.error,
      surface: tokens.surfaces.background,
      onSurface: tokens.text.primary,
      onSurfaceVariant: tokens.text.secondary,
      outline: tokens.surfaces.border,
      outlineVariant: tokens.surfaces.border,
      shadow: tokens.surfaces.shadow,
      scrim: tokens.surfaces.scrim,
      inverseSurface: tokens.text.primary,
      onInverseSurface: tokens.surfaces.background,
      inversePrimary: tokens.brand.accentHover,
      surfaceTint: tokens.brand.accent,
      surfaceBright: tokens.surfaces.surfaceHover,
      surfaceDim: tokens.surfaces.backgroundSecondary,
      surfaceContainerLowest: tokens.surfaces.backgroundSecondary,
      surfaceContainerLow: tokens.surfaces.backgroundSecondary,
      surfaceContainer: tokens.surfaces.surface,
      surfaceContainerHigh: tokens.surfaces.surfaceHover,
      surfaceContainerHighest: tokens.surfaces.surfaceHover,
    );

    final textTheme = AppTypography.textTheme(color: tokens.text.primary);
    final switchThumbColor = tokens.brightness == Brightness.light
        ? tokens.surfaces.surface
        : tokens.text.primary;

    return ThemeData(
      useMaterial3: true,
      brightness: tokens.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.surfaces.background,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [
        tokens.brand,
        tokens.surfaces,
        tokens.text,
        tokens.semantic,
        tokens.components,
        tokens.opportunities,
      ],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: tokens.surfaces.background,
        foregroundColor: tokens.text.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: tokens.surfaces.surface,
        shadowColor: tokens.surfaces.shadow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: tokens.surfaces.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.surfaces.border,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.brand.accent,
          foregroundColor: tokens.brand.onAccent,
          disabledBackgroundColor: tokens.surfaces.disabled,
          disabledForegroundColor: tokens.text.disabled,
          elevation: 0,
          shadowColor: AppColors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.text.primary,
          disabledForegroundColor: tokens.text.disabled,
          side: BorderSide(color: tokens.surfaces.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.brand.accent,
          disabledForegroundColor: tokens.text.disabled,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: tokens.text.secondary,
          disabledForegroundColor: tokens.text.disabled,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaces.backgroundSecondary,
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.text.weak),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: tokens.text.secondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: tokens.surfaces.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: tokens.surfaces.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: tokens.brand.accent, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: tokens.surfaces.disabled),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaces.backgroundSecondary,
        selectedColor: tokens.brand.accent.withValues(alpha: 0.16),
        disabledColor: tokens.surfaces.disabled,
        labelStyle: textTheme.labelLarge?.copyWith(
          color: tokens.text.primary,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: tokens.brand.accent,
          fontWeight: FontWeight.w800,
        ),
        side: BorderSide(color: tokens.surfaces.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return tokens.text.disabled;
          }
          if (states.contains(WidgetState.selected)) {
            return switchThumbColor;
          }
          return switchThumbColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return tokens.surfaces.disabled;
          }
          if (states.contains(WidgetState.selected)) {
            return tokens.brand.accent;
          }
          return tokens.surfaces.surfaceHover;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.brand.accent;
          }
          return tokens.surfaces.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return tokens.surfaces.disabled;
          }
          if (states.contains(WidgetState.selected)) {
            return tokens.brand.accent;
          }
          return AppColors.transparent;
        }),
        checkColor: WidgetStateProperty.all(tokens.brand.onAccent),
        side: BorderSide(color: tokens.surfaces.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.indicator),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(tokens.surfaces.surface),
          shadowColor: WidgetStatePropertyAll(tokens.surfaces.shadow),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaces.surface,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: tokens.surfaces.border),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.surfaces.backgroundSecondary,
        selectedItemColor: tokens.brand.accent,
        unselectedItemColor: tokens.text.weak,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.brand.accent,
        unselectedLabelColor: tokens.text.secondary,
        indicatorColor: tokens.brand.accent,
        dividerColor: tokens.surfaces.border,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(),
      visualDensity: VisualDensity.standard,
    );
  }

  static BoxDecoration cardDecoration({bool elevated = true}) {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.border),
      boxShadow: elevated ? AppShadows.card : null,
    );
  }

  static BoxDecoration themedCardDecoration(
    BuildContext context, {
    bool elevated = true,
  }) {
    final surfaces = context.surfaces;
    return BoxDecoration(
      color: surfaces.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: surfaces.border),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: surfaces.shadow.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.28
                      : 0.12,
                ),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );
  }

  const CopilotTheme._();
}
