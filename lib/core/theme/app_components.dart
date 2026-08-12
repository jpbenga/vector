import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class AppBrandPalette extends ThemeExtension<AppBrandPalette> {
  const AppBrandPalette({
    required this.accent,
    required this.accentHover,
    required this.accentDark,
    required this.onAccent,
  });

  final Color accent;
  final Color accentHover;
  final Color accentDark;
  final Color onAccent;

  static const vectorDark = AppBrandPalette(
    accent: AppColors.accent,
    accentHover: AppColors.accentHover,
    accentDark: AppColors.accentDark,
    onAccent: AppColors.primaryButtonText,
  );

  static const vectorLight = AppBrandPalette(
    accent: AppLightColors.accent,
    accentHover: AppLightColors.accentHover,
    accentDark: AppLightColors.accentDark,
    onAccent: AppLightColors.primaryButtonText,
  );

  static const gold = AppBrandPalette(
    accent: AppGoldColors.accent,
    accentHover: AppGoldColors.accentHover,
    accentDark: AppGoldColors.accentDark,
    onAccent: AppGoldColors.primaryButtonText,
  );

  static const aurora = AppBrandPalette(
    accent: AppAuroraColors.accent,
    accentHover: AppAuroraColors.accentHover,
    accentDark: AppAuroraColors.accentDark,
    onAccent: AppAuroraColors.primaryButtonText,
  );

  @override
  AppBrandPalette copyWith({
    Color? accent,
    Color? accentHover,
    Color? accentDark,
    Color? onAccent,
  }) {
    return AppBrandPalette(
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentDark: accentDark ?? this.accentDark,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  AppBrandPalette lerp(ThemeExtension<AppBrandPalette>? other, double t) {
    if (other is! AppBrandPalette) return this;
    return AppBrandPalette(
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

@immutable
class AppSurfacePalette extends ThemeExtension<AppSurfacePalette> {
  const AppSurfacePalette({
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceHover,
    required this.border,
    required this.disabled,
    required this.shadow,
    required this.scrim,
  });

  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceHover;
  final Color border;
  final Color disabled;
  final Color shadow;
  final Color scrim;

  static const vectorDark = AppSurfacePalette(
    background: AppColors.background,
    backgroundSecondary: AppColors.backgroundSecondary,
    surface: AppColors.surface,
    surfaceHover: AppColors.surfaceHover,
    border: AppColors.border,
    disabled: AppColors.disabledButtonBackground,
    shadow: AppColors.shadow,
    scrim: AppColors.shadow,
  );

  static const vectorLight = AppSurfacePalette(
    background: AppLightColors.background,
    backgroundSecondary: AppLightColors.backgroundSecondary,
    surface: AppLightColors.surface,
    surfaceHover: AppLightColors.surfaceHover,
    border: AppLightColors.border,
    disabled: AppLightColors.disabledButtonBackground,
    shadow: AppLightColors.shadow,
    scrim: AppLightColors.shadow,
  );

  static const gold = AppSurfacePalette(
    background: AppGoldColors.background,
    backgroundSecondary: AppGoldColors.backgroundSecondary,
    surface: AppGoldColors.surface,
    surfaceHover: AppGoldColors.surfaceHover,
    border: AppGoldColors.border,
    disabled: AppGoldColors.disabledButtonBackground,
    shadow: AppGoldColors.shadow,
    scrim: AppGoldColors.shadow,
  );

  static const aurora = AppSurfacePalette(
    background: AppAuroraColors.background,
    backgroundSecondary: AppAuroraColors.backgroundSecondary,
    surface: AppAuroraColors.surface,
    surfaceHover: AppAuroraColors.surfaceHover,
    border: AppAuroraColors.border,
    disabled: AppAuroraColors.disabledButtonBackground,
    shadow: AppAuroraColors.shadow,
    scrim: AppAuroraColors.shadow,
  );

  @override
  AppSurfacePalette copyWith({
    Color? background,
    Color? backgroundSecondary,
    Color? surface,
    Color? surfaceHover,
    Color? border,
    Color? disabled,
    Color? shadow,
    Color? scrim,
  }) {
    return AppSurfacePalette(
      background: background ?? this.background,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      surface: surface ?? this.surface,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      border: border ?? this.border,
      disabled: disabled ?? this.disabled,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppSurfacePalette lerp(ThemeExtension<AppSurfacePalette>? other, double t) {
    if (other is! AppSurfacePalette) return this;
    return AppSurfacePalette(
      background: Color.lerp(background, other.background, t)!,
      backgroundSecondary: Color.lerp(
        backgroundSecondary,
        other.backgroundSecondary,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      border: Color.lerp(border, other.border, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

@immutable
class AppTextPalette extends ThemeExtension<AppTextPalette> {
  const AppTextPalette({
    required this.primary,
    required this.secondary,
    required this.weak,
    required this.disabled,
  });

  final Color primary;
  final Color secondary;
  final Color weak;
  final Color disabled;

  static const vectorDark = AppTextPalette(
    primary: AppColors.textPrimary,
    secondary: AppColors.textSecondary,
    weak: AppColors.textWeak,
    disabled: AppColors.textDisabled,
  );

  static const vectorLight = AppTextPalette(
    primary: AppLightColors.textPrimary,
    secondary: AppLightColors.textSecondary,
    weak: AppLightColors.textWeak,
    disabled: AppLightColors.textDisabled,
  );

  static const gold = AppTextPalette(
    primary: AppGoldColors.textPrimary,
    secondary: AppGoldColors.textSecondary,
    weak: AppGoldColors.textWeak,
    disabled: AppGoldColors.textDisabled,
  );

  static const aurora = AppTextPalette(
    primary: AppAuroraColors.textPrimary,
    secondary: AppAuroraColors.textSecondary,
    weak: AppAuroraColors.textWeak,
    disabled: AppAuroraColors.textDisabled,
  );

  @override
  AppTextPalette copyWith({
    Color? primary,
    Color? secondary,
    Color? weak,
    Color? disabled,
  }) {
    return AppTextPalette(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      weak: weak ?? this.weak,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  AppTextPalette lerp(ThemeExtension<AppTextPalette>? other, double t) {
    if (other is! AppTextPalette) return this;
    return AppTextPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      weak: Color.lerp(weak, other.weak, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}

@immutable
class AppSemanticPalette extends ThemeExtension<AppSemanticPalette> {
  const AppSemanticPalette({
    required this.success,
    required this.successHover,
    required this.warning,
    required this.error,
    required this.live,
    required this.info,
  });

  final Color success;
  final Color successHover;
  final Color warning;
  final Color error;
  final Color live;
  final Color info;

  static const vectorDark = AppSemanticPalette(
    success: AppColors.success,
    successHover: AppColors.successHover,
    warning: AppColors.warning,
    error: AppColors.error,
    live: AppColors.live,
    info: AppColors.info,
  );

  static const vectorLight = AppSemanticPalette(
    success: AppLightColors.success,
    successHover: AppLightColors.successHover,
    warning: AppLightColors.warning,
    error: AppLightColors.error,
    live: AppLightColors.live,
    info: AppLightColors.info,
  );

  static const gold = AppSemanticPalette(
    success: AppGoldColors.success,
    successHover: AppGoldColors.successHover,
    warning: AppGoldColors.warning,
    error: AppGoldColors.error,
    live: AppGoldColors.live,
    info: AppGoldColors.info,
  );

  static const aurora = AppSemanticPalette(
    success: AppAuroraColors.success,
    successHover: AppAuroraColors.successHover,
    warning: AppAuroraColors.warning,
    error: AppAuroraColors.error,
    live: AppAuroraColors.live,
    info: AppAuroraColors.info,
  );

  @override
  AppSemanticPalette copyWith({
    Color? success,
    Color? successHover,
    Color? warning,
    Color? error,
    Color? live,
    Color? info,
  }) {
    return AppSemanticPalette(
      success: success ?? this.success,
      successHover: successHover ?? this.successHover,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      live: live ?? this.live,
      info: info ?? this.info,
    );
  }

  @override
  AppSemanticPalette lerp(ThemeExtension<AppSemanticPalette>? other, double t) {
    if (other is! AppSemanticPalette) return this;
    return AppSemanticPalette(
      success: Color.lerp(success, other.success, t)!,
      successHover: Color.lerp(successHover, other.successHover, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      live: Color.lerp(live, other.live, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

@immutable
class AppComponentColors extends ThemeExtension<AppComponentColors> {
  const AppComponentColors({
    required this.oddsBackground,
    required this.oddsText,
    required this.oddsBorder,
    required this.liveBadgeBackground,
    required this.liveBadgeText,
    required this.analyzeBadgeBackground,
    required this.analyzeBadgeText,
    required this.resultBadgeBackground,
    required this.resultBadgeText,
    required this.postponedBadgeBackground,
    required this.postponedBadgeText,
    required this.favorite,
  });

  final Color oddsBackground;
  final Color oddsText;
  final Color oddsBorder;
  final Color liveBadgeBackground;
  final Color liveBadgeText;
  final Color analyzeBadgeBackground;
  final Color analyzeBadgeText;
  final Color resultBadgeBackground;
  final Color resultBadgeText;
  final Color postponedBadgeBackground;
  final Color postponedBadgeText;
  final Color favorite;

  static const vectorDark = AppComponentColors(
    oddsBackground: AppColors.oddsBackground,
    oddsText: AppColors.oddsText,
    oddsBorder: AppColors.oddsBorder,
    liveBadgeBackground: AppColors.liveBadgeBackground,
    liveBadgeText: AppColors.liveBadgeText,
    analyzeBadgeBackground: AppColors.analyzeBadgeBackground,
    analyzeBadgeText: AppColors.accent,
    resultBadgeBackground: AppColors.resultBadgeBackground,
    resultBadgeText: AppColors.resultBadgeText,
    postponedBadgeBackground: AppColors.postponedBadgeBackground,
    postponedBadgeText: AppColors.postponedBadgeText,
    favorite: AppColors.warning,
  );

  static const dark = vectorDark;

  static const vectorLight = AppComponentColors(
    oddsBackground: AppLightColors.oddsBackground,
    oddsText: AppLightColors.oddsText,
    oddsBorder: AppLightColors.oddsBorder,
    liveBadgeBackground: AppLightColors.liveBadgeBackground,
    liveBadgeText: AppLightColors.liveBadgeText,
    analyzeBadgeBackground: AppLightColors.analyzeBadgeBackground,
    analyzeBadgeText: AppLightColors.accentDark,
    resultBadgeBackground: AppLightColors.resultBadgeBackground,
    resultBadgeText: AppLightColors.resultBadgeText,
    postponedBadgeBackground: AppLightColors.postponedBadgeBackground,
    postponedBadgeText: AppLightColors.postponedBadgeText,
    favorite: AppLightColors.warning,
  );

  static const gold = AppComponentColors(
    oddsBackground: AppGoldColors.oddsBackground,
    oddsText: AppGoldColors.oddsText,
    oddsBorder: AppGoldColors.oddsBorder,
    liveBadgeBackground: AppGoldColors.liveBadgeBackground,
    liveBadgeText: AppGoldColors.liveBadgeText,
    analyzeBadgeBackground: AppGoldColors.analyzeBadgeBackground,
    analyzeBadgeText: AppGoldColors.oddsText,
    resultBadgeBackground: AppGoldColors.resultBadgeBackground,
    resultBadgeText: AppGoldColors.resultBadgeText,
    postponedBadgeBackground: AppGoldColors.postponedBadgeBackground,
    postponedBadgeText: AppGoldColors.postponedBadgeText,
    favorite: AppGoldColors.warning,
  );

  static const aurora = AppComponentColors(
    oddsBackground: AppAuroraColors.oddsBackground,
    oddsText: AppAuroraColors.oddsText,
    oddsBorder: AppAuroraColors.oddsBorder,
    liveBadgeBackground: AppAuroraColors.liveBadgeBackground,
    liveBadgeText: AppAuroraColors.liveBadgeText,
    analyzeBadgeBackground: AppAuroraColors.analyzeBadgeBackground,
    analyzeBadgeText: AppAuroraColors.oddsText,
    resultBadgeBackground: AppAuroraColors.resultBadgeBackground,
    resultBadgeText: AppAuroraColors.resultBadgeText,
    postponedBadgeBackground: AppAuroraColors.postponedBadgeBackground,
    postponedBadgeText: AppAuroraColors.postponedBadgeText,
    favorite: AppAuroraColors.warning,
  );

  @override
  AppComponentColors copyWith({
    Color? oddsBackground,
    Color? oddsText,
    Color? oddsBorder,
    Color? liveBadgeBackground,
    Color? liveBadgeText,
    Color? analyzeBadgeBackground,
    Color? analyzeBadgeText,
    Color? resultBadgeBackground,
    Color? resultBadgeText,
    Color? postponedBadgeBackground,
    Color? postponedBadgeText,
    Color? favorite,
  }) {
    return AppComponentColors(
      oddsBackground: oddsBackground ?? this.oddsBackground,
      oddsText: oddsText ?? this.oddsText,
      oddsBorder: oddsBorder ?? this.oddsBorder,
      liveBadgeBackground: liveBadgeBackground ?? this.liveBadgeBackground,
      liveBadgeText: liveBadgeText ?? this.liveBadgeText,
      analyzeBadgeBackground:
          analyzeBadgeBackground ?? this.analyzeBadgeBackground,
      analyzeBadgeText: analyzeBadgeText ?? this.analyzeBadgeText,
      resultBadgeBackground:
          resultBadgeBackground ?? this.resultBadgeBackground,
      resultBadgeText: resultBadgeText ?? this.resultBadgeText,
      postponedBadgeBackground:
          postponedBadgeBackground ?? this.postponedBadgeBackground,
      postponedBadgeText: postponedBadgeText ?? this.postponedBadgeText,
      favorite: favorite ?? this.favorite,
    );
  }

  @override
  AppComponentColors lerp(ThemeExtension<AppComponentColors>? other, double t) {
    if (other is! AppComponentColors) return this;
    return AppComponentColors(
      oddsBackground: Color.lerp(oddsBackground, other.oddsBackground, t)!,
      oddsText: Color.lerp(oddsText, other.oddsText, t)!,
      oddsBorder: Color.lerp(oddsBorder, other.oddsBorder, t)!,
      liveBadgeBackground: Color.lerp(
        liveBadgeBackground,
        other.liveBadgeBackground,
        t,
      )!,
      liveBadgeText: Color.lerp(liveBadgeText, other.liveBadgeText, t)!,
      analyzeBadgeBackground: Color.lerp(
        analyzeBadgeBackground,
        other.analyzeBadgeBackground,
        t,
      )!,
      analyzeBadgeText: Color.lerp(
        analyzeBadgeText,
        other.analyzeBadgeText,
        t,
      )!,
      resultBadgeBackground: Color.lerp(
        resultBadgeBackground,
        other.resultBadgeBackground,
        t,
      )!,
      resultBadgeText: Color.lerp(resultBadgeText, other.resultBadgeText, t)!,
      postponedBadgeBackground: Color.lerp(
        postponedBadgeBackground,
        other.postponedBadgeBackground,
        t,
      )!,
      postponedBadgeText: Color.lerp(
        postponedBadgeText,
        other.postponedBadgeText,
        t,
      )!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
    );
  }
}

enum AppReadingBadgeVariant { simple, combined, soft }

@immutable
class AppReadingBadgeStyle {
  const AppReadingBadgeStyle({
    required this.foreground,
    required this.background,
    required this.border,
    required this.iconColor,
  });

  final Color foreground;
  final Color background;
  final Color border;
  final Color iconColor;

  AppReadingBadgeStyle copyWith({
    Color? foreground,
    Color? background,
    Color? border,
    Color? iconColor,
  }) {
    return AppReadingBadgeStyle(
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      border: border ?? this.border,
      iconColor: iconColor ?? this.iconColor,
    );
  }

  AppReadingBadgeStyle lerp(AppReadingBadgeStyle other, double t) {
    return AppReadingBadgeStyle(
      foreground: Color.lerp(foreground, other.foreground, t)!,
      background: Color.lerp(background, other.background, t)!,
      border: Color.lerp(border, other.border, t)!,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
    );
  }
}

@immutable
class AppReadingFamilyStyle {
  const AppReadingFamilyStyle({
    required this.color,
    required this.simple,
    required this.combined,
    required this.soft,
  });

  final Color color;
  final AppReadingBadgeStyle simple;
  final AppReadingBadgeStyle combined;
  final AppReadingBadgeStyle soft;

  factory AppReadingFamilyStyle.fromColor({
    required Color color,
    required Color surface,
    required Color surfaceHover,
    double simpleBackgroundAlpha = 0.06,
    double simpleBorderAlpha = 0.46,
    double combinedBackgroundAlpha = 0.14,
    double combinedBorderAlpha = 0.72,
    double softBackgroundAlpha = 0.10,
    double softBorderAlpha = 0.24,
  }) {
    Color blend(double alpha, Color base) {
      return Color.alphaBlend(color.withValues(alpha: alpha), base);
    }

    return AppReadingFamilyStyle(
      color: color,
      simple: AppReadingBadgeStyle(
        foreground: color,
        background: blend(simpleBackgroundAlpha, surface),
        border: blend(simpleBorderAlpha, surface),
        iconColor: color,
      ),
      combined: AppReadingBadgeStyle(
        foreground: color,
        background: blend(combinedBackgroundAlpha, surfaceHover),
        border: blend(combinedBorderAlpha, surfaceHover),
        iconColor: color,
      ),
      soft: AppReadingBadgeStyle(
        foreground: color,
        background: blend(softBackgroundAlpha, surface),
        border: blend(softBorderAlpha, surface),
        iconColor: color,
      ),
    );
  }

  AppReadingBadgeStyle badgeFor(AppReadingBadgeVariant variant) {
    return switch (variant) {
      AppReadingBadgeVariant.simple => simple,
      AppReadingBadgeVariant.combined => combined,
      AppReadingBadgeVariant.soft => soft,
    };
  }

  AppReadingFamilyStyle copyWith({
    Color? color,
    AppReadingBadgeStyle? simple,
    AppReadingBadgeStyle? combined,
    AppReadingBadgeStyle? soft,
  }) {
    return AppReadingFamilyStyle(
      color: color ?? this.color,
      simple: simple ?? this.simple,
      combined: combined ?? this.combined,
      soft: soft ?? this.soft,
    );
  }

  AppReadingFamilyStyle lerp(AppReadingFamilyStyle other, double t) {
    return AppReadingFamilyStyle(
      color: Color.lerp(color, other.color, t)!,
      simple: simple.lerp(other.simple, t),
      combined: combined.lerp(other.combined, t),
      soft: soft.lerp(other.soft, t),
    );
  }
}

@immutable
class AppOpportunityPalette extends ThemeExtension<AppOpportunityPalette> {
  const AppOpportunityPalette({
    required this.solidFavoriteStyle,
    required this.openMatchStyle,
    required this.closedMatchStyle,
    required this.levelGapStyle,
    required this.credibleOutsiderStyle,
    required this.fragileDefenseStyle,
    required this.prolificAttackStyle,
    required this.positiveStreakStyle,
    required this.negativeStreakStyle,
    required this.strugglingTeamStyle,
  });

  final AppReadingFamilyStyle solidFavoriteStyle;
  final AppReadingFamilyStyle openMatchStyle;
  final AppReadingFamilyStyle closedMatchStyle;
  final AppReadingFamilyStyle levelGapStyle;
  final AppReadingFamilyStyle credibleOutsiderStyle;
  final AppReadingFamilyStyle fragileDefenseStyle;
  final AppReadingFamilyStyle prolificAttackStyle;
  final AppReadingFamilyStyle positiveStreakStyle;
  final AppReadingFamilyStyle negativeStreakStyle;
  final AppReadingFamilyStyle strugglingTeamStyle;

  Color get solidFavorite => solidFavoriteStyle.color;
  Color get openMatch => openMatchStyle.color;
  Color get closedMatch => closedMatchStyle.color;
  Color get levelGap => levelGapStyle.color;
  Color get credibleOutsider => credibleOutsiderStyle.color;
  Color get fragileDefense => fragileDefenseStyle.color;
  Color get prolificAttack => prolificAttackStyle.color;
  Color get positiveStreak => positiveStreakStyle.color;
  Color get negativeStreak => negativeStreakStyle.color;
  Color get strugglingTeam => strugglingTeamStyle.color;

  static final vectorDark = AppOpportunityPalette.fromColors(
    surface: AppColors.surface,
    surfaceHover: AppColors.surfaceHover,
    solidFavorite: AppOpportunityColors.solidFavorite,
    openMatch: AppOpportunityColors.openMatch,
    closedMatch: AppOpportunityColors.closedMatch,
    levelGap: AppOpportunityColors.levelGap,
    credibleOutsider: AppOpportunityColors.credibleOutsider,
    fragileDefense: AppOpportunityColors.fragileDefense,
    prolificAttack: AppOpportunityColors.prolificAttack,
    positiveStreak: AppOpportunityColors.positiveStreak,
    negativeStreak: AppOpportunityColors.negativeStreak,
    strugglingTeam: AppOpportunityColors.strugglingTeam,
  );

  static final dark = vectorDark;

  static final vectorLight = AppOpportunityPalette.fromColors(
    surface: AppLightColors.surface,
    surfaceHover: AppLightColors.surfaceHover,
    solidFavorite: AppLightOpportunityColors.solidFavorite,
    openMatch: AppLightOpportunityColors.openMatch,
    closedMatch: AppLightOpportunityColors.closedMatch,
    levelGap: AppLightOpportunityColors.levelGap,
    credibleOutsider: AppLightOpportunityColors.credibleOutsider,
    fragileDefense: AppLightOpportunityColors.fragileDefense,
    prolificAttack: AppLightOpportunityColors.prolificAttack,
    positiveStreak: AppLightOpportunityColors.positiveStreak,
    negativeStreak: AppLightOpportunityColors.negativeStreak,
    strugglingTeam: AppLightOpportunityColors.strugglingTeam,
  );

  static final gold = AppOpportunityPalette.fromColors(
    surface: AppGoldColors.surface,
    surfaceHover: AppGoldColors.surfaceHover,
    solidFavorite: AppGoldOpportunityColors.solidFavorite,
    openMatch: AppGoldOpportunityColors.openMatch,
    closedMatch: AppGoldOpportunityColors.closedMatch,
    levelGap: AppGoldOpportunityColors.levelGap,
    credibleOutsider: AppGoldOpportunityColors.credibleOutsider,
    fragileDefense: AppGoldOpportunityColors.fragileDefense,
    prolificAttack: AppGoldOpportunityColors.prolificAttack,
    positiveStreak: AppGoldOpportunityColors.positiveStreak,
    negativeStreak: AppGoldOpportunityColors.negativeStreak,
    strugglingTeam: AppGoldOpportunityColors.strugglingTeam,
  );

  static final aurora = AppOpportunityPalette.fromColors(
    surface: AppAuroraColors.surface,
    surfaceHover: AppAuroraColors.surfaceHover,
    solidFavorite: AppAuroraOpportunityColors.solidFavorite,
    openMatch: AppAuroraOpportunityColors.openMatch,
    closedMatch: AppAuroraOpportunityColors.closedMatch,
    levelGap: AppAuroraOpportunityColors.levelGap,
    credibleOutsider: AppAuroraOpportunityColors.credibleOutsider,
    fragileDefense: AppAuroraOpportunityColors.fragileDefense,
    prolificAttack: AppAuroraOpportunityColors.prolificAttack,
    positiveStreak: AppAuroraOpportunityColors.positiveStreak,
    negativeStreak: AppAuroraOpportunityColors.negativeStreak,
    strugglingTeam: AppAuroraOpportunityColors.strugglingTeam,
  );

  factory AppOpportunityPalette.fromColors({
    required Color surface,
    required Color surfaceHover,
    required Color solidFavorite,
    required Color openMatch,
    required Color closedMatch,
    required Color levelGap,
    required Color credibleOutsider,
    required Color fragileDefense,
    required Color prolificAttack,
    required Color positiveStreak,
    required Color negativeStreak,
    required Color strugglingTeam,
  }) {
    AppReadingFamilyStyle family(Color color) {
      return AppReadingFamilyStyle.fromColor(
        color: color,
        surface: surface,
        surfaceHover: surfaceHover,
      );
    }

    return AppOpportunityPalette(
      solidFavoriteStyle: family(solidFavorite),
      openMatchStyle: family(openMatch),
      closedMatchStyle: family(closedMatch),
      levelGapStyle: family(levelGap),
      credibleOutsiderStyle: family(credibleOutsider),
      fragileDefenseStyle: family(fragileDefense),
      prolificAttackStyle: family(prolificAttack),
      positiveStreakStyle: family(positiveStreak),
      negativeStreakStyle: family(negativeStreak),
      strugglingTeamStyle: family(strugglingTeam),
    );
  }

  Color byThesisId(String id) {
    return familyForThesisId(id).color;
  }

  AppReadingFamilyStyle familyForThesisId(String id) {
    return switch (id) {
      'solid_favorite' || 'home_strength' => solidFavoriteStyle,
      'open_match' ||
      'offensive_match' ||
      'open_match_profile' => openMatchStyle,
      'closed_match' || 'closed_match_profile' => closedMatchStyle,
      'level_gap' ||
      'ranking_gap' ||
      'ranking_superiority' ||
      'structural_level_gap' => levelGapStyle,
      'credible_outsider' || 'market_favorite' => credibleOutsiderStyle,
      'fragile_defense' ||
      'defensive_weakness' ||
      'contradiction' => fragileDefenseStyle,
      'prolific_attack' ||
      'strong_attack' ||
      'xg_creation' ||
      'high_xg_creation' ||
      'frequent_over_25' ||
      'frequent_btts' => prolificAttackStyle,
      'positive_streak' ||
      'strong_recent_form' ||
      'positive_form' => positiveStreakStyle,
      'negative_streak' ||
      'weak_recent_form' ||
      'declining_form' ||
      'scoring_difficulty' ||
      'low_xg_creation' ||
      'offensive_underperformance' => negativeStreakStyle,
      'team_in_difficulty' ||
      'poor_overall_performance' ||
      'solid_defense' ||
      'frequent_under_25' ||
      'high_xg_conceded' ||
      'offensive_overperformance' => strugglingTeamStyle,
      _ => prolificAttackStyle,
    };
  }

  AppReadingBadgeStyle badgeFor(
    String id, {
    AppReadingBadgeVariant variant = AppReadingBadgeVariant.simple,
  }) {
    return familyForThesisId(id).badgeFor(variant);
  }

  @override
  AppOpportunityPalette copyWith({
    AppReadingFamilyStyle? solidFavoriteStyle,
    AppReadingFamilyStyle? openMatchStyle,
    AppReadingFamilyStyle? closedMatchStyle,
    AppReadingFamilyStyle? levelGapStyle,
    AppReadingFamilyStyle? credibleOutsiderStyle,
    AppReadingFamilyStyle? fragileDefenseStyle,
    AppReadingFamilyStyle? prolificAttackStyle,
    AppReadingFamilyStyle? positiveStreakStyle,
    AppReadingFamilyStyle? negativeStreakStyle,
    AppReadingFamilyStyle? strugglingTeamStyle,
  }) {
    return AppOpportunityPalette(
      solidFavoriteStyle: solidFavoriteStyle ?? this.solidFavoriteStyle,
      openMatchStyle: openMatchStyle ?? this.openMatchStyle,
      closedMatchStyle: closedMatchStyle ?? this.closedMatchStyle,
      levelGapStyle: levelGapStyle ?? this.levelGapStyle,
      credibleOutsiderStyle:
          credibleOutsiderStyle ?? this.credibleOutsiderStyle,
      fragileDefenseStyle: fragileDefenseStyle ?? this.fragileDefenseStyle,
      prolificAttackStyle: prolificAttackStyle ?? this.prolificAttackStyle,
      positiveStreakStyle: positiveStreakStyle ?? this.positiveStreakStyle,
      negativeStreakStyle: negativeStreakStyle ?? this.negativeStreakStyle,
      strugglingTeamStyle: strugglingTeamStyle ?? this.strugglingTeamStyle,
    );
  }

  @override
  AppOpportunityPalette lerp(
    ThemeExtension<AppOpportunityPalette>? other,
    double t,
  ) {
    if (other is! AppOpportunityPalette) return this;
    return AppOpportunityPalette(
      solidFavoriteStyle: solidFavoriteStyle.lerp(other.solidFavoriteStyle, t),
      openMatchStyle: openMatchStyle.lerp(other.openMatchStyle, t),
      closedMatchStyle: closedMatchStyle.lerp(other.closedMatchStyle, t),
      levelGapStyle: levelGapStyle.lerp(other.levelGapStyle, t),
      credibleOutsiderStyle: credibleOutsiderStyle.lerp(
        other.credibleOutsiderStyle,
        t,
      ),
      fragileDefenseStyle: fragileDefenseStyle.lerp(
        other.fragileDefenseStyle,
        t,
      ),
      prolificAttackStyle: prolificAttackStyle.lerp(
        other.prolificAttackStyle,
        t,
      ),
      positiveStreakStyle: positiveStreakStyle.lerp(
        other.positiveStreakStyle,
        t,
      ),
      negativeStreakStyle: negativeStreakStyle.lerp(
        other.negativeStreakStyle,
        t,
      ),
      strugglingTeamStyle: strugglingTeamStyle.lerp(
        other.strugglingTeamStyle,
        t,
      ),
    );
  }
}

extension AppThemeComponents on BuildContext {
  AppBrandPalette get brand {
    return Theme.of(this).extension<AppBrandPalette>() ??
        AppBrandPalette.vectorDark;
  }

  AppSurfacePalette get surfaces {
    return Theme.of(this).extension<AppSurfacePalette>() ??
        AppSurfacePalette.vectorDark;
  }

  AppTextPalette get textColors {
    return Theme.of(this).extension<AppTextPalette>() ??
        AppTextPalette.vectorDark;
  }

  AppSemanticPalette get semantic {
    return Theme.of(this).extension<AppSemanticPalette>() ??
        AppSemanticPalette.vectorDark;
  }

  AppComponentColors get components {
    return Theme.of(this).extension<AppComponentColors>() ??
        AppComponentColors.vectorDark;
  }

  AppOpportunityPalette get opportunities {
    return Theme.of(this).extension<AppOpportunityPalette>() ??
        AppOpportunityPalette.vectorDark;
  }
}
