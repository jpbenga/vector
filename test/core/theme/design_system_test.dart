import 'dart:io';

import 'package:copilot/core/theme/app_colors.dart';
import 'package:copilot/core/theme/app_components.dart';
import 'package:copilot/core/theme/app_radius.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Design system tokens', () {
    test('keep the validated MVP palette stable', () {
      expect(AppColors.background, const Color(0xFF0B1015));
      expect(AppColors.backgroundSecondary, const Color(0xFF11181F));
      expect(AppColors.surface, const Color(0xFF161F26));
      expect(AppColors.surfaceHover, const Color(0xFF1B262E));
      expect(AppColors.border, const Color(0xFF2B3944));
      expect(AppColors.accent, const Color(0xFF2FE6D3));
      expect(AppColors.oddsBackground, const Color(0xFF112B2D));
      expect(AppColors.oddsText, const Color(0xFF4EF2D8));
      expect(AppColors.oddsBorder, const Color(0xFF235D61));
    });

    test('provide a real light Vector palette', () {
      expect(AppLightColors.background, const Color(0xFFF6F9FB));
      expect(AppLightColors.surface, const Color(0xFFFFFFFF));
      expect(AppLightColors.textPrimary, const Color(0xFF071215));
      expect(AppLightColors.accent, const Color(0xFF0D8179));
      expect(AppLightColors.oddsText, const Color(0xFF087F75));
    });

    test('provide the Vector Gold palette as a complete variant', () {
      expect(AppGoldColors.background, const Color(0xFF08111A));
      expect(AppGoldColors.surface, const Color(0xFF15222D));
      expect(AppGoldColors.textPrimary, const Color(0xFFF8F1E6));
      expect(AppGoldColors.accent, const Color(0xFFE8B66A));
      expect(AppGoldColors.oddsText, const Color(0xFFF0BE69));
      expect(
        AppGoldOpportunityColors.prolificAttack,
        isNot(AppGoldColors.accent),
      );
    });

    test('provide the Aurora palette as a complete variant', () {
      expect(AppAuroraColors.background, const Color(0xFF08051E));
      expect(AppAuroraColors.surface, const Color(0xFF171039));
      expect(AppAuroraColors.textPrimary, const Color(0xFFF7F1FF));
      expect(AppAuroraColors.accent, const Color(0xFFA970FF));
      expect(AppAuroraColors.oddsText, const Color(0xFF65F2E4));
      expect(
        AppAuroraOpportunityColors.prolificAttack,
        isNot(AppAuroraColors.accent),
      );
    });

    test('build dark and light themes from distinct token sets', () {
      final dark = CopilotTheme.dark;
      final light = CopilotTheme.light;
      final gold = CopilotTheme.gold;
      final aurora = CopilotTheme.aurora;

      expect(dark.brightness, Brightness.dark);
      expect(light.brightness, Brightness.light);
      expect(gold.brightness, Brightness.dark);
      expect(aurora.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, AppColors.background);
      expect(light.scaffoldBackgroundColor, AppLightColors.background);
      expect(gold.scaffoldBackgroundColor, AppGoldColors.background);
      expect(aurora.scaffoldBackgroundColor, AppAuroraColors.background);
      expect(dark.colorScheme.surface, AppColors.background);
      expect(light.colorScheme.surface, AppLightColors.background);
      expect(gold.colorScheme.surface, AppGoldColors.background);
      expect(aurora.colorScheme.surface, AppAuroraColors.background);
      expect(dark.colorScheme.primary, AppColors.accent);
      expect(light.colorScheme.primary, AppLightColors.accent);
      expect(gold.colorScheme.primary, AppGoldColors.accent);
      expect(aurora.colorScheme.primary, AppAuroraColors.accent);
    });

    test('register semantic theme extensions for dark and light modes', () {
      final dark = CopilotTheme.dark;
      final light = CopilotTheme.light;
      final gold = CopilotTheme.gold;
      final aurora = CopilotTheme.aurora;

      expect(dark.extension<AppSurfacePalette>()?.surface, AppColors.surface);
      expect(
        light.extension<AppSurfacePalette>()?.surface,
        AppLightColors.surface,
      );
      expect(
        gold.extension<AppSurfacePalette>()?.surface,
        AppGoldColors.surface,
      );
      expect(
        aurora.extension<AppSurfacePalette>()?.surface,
        AppAuroraColors.surface,
      );
      expect(dark.extension<AppTextPalette>()?.primary, AppColors.textPrimary);
      expect(
        light.extension<AppTextPalette>()?.primary,
        AppLightColors.textPrimary,
      );
      expect(
        gold.extension<AppTextPalette>()?.primary,
        AppGoldColors.textPrimary,
      );
      expect(
        aurora.extension<AppTextPalette>()?.primary,
        AppAuroraColors.textPrimary,
      );
      expect(dark.extension<AppBrandPalette>()?.accent, AppColors.accent);
      expect(light.extension<AppBrandPalette>()?.accent, AppLightColors.accent);
      expect(gold.extension<AppBrandPalette>()?.accent, AppGoldColors.accent);
      expect(
        aurora.extension<AppBrandPalette>()?.accent,
        AppAuroraColors.accent,
      );
      expect(dark.extension<AppSemanticPalette>()?.error, AppColors.error);
      expect(
        light.extension<AppSemanticPalette>()?.error,
        AppLightColors.error,
      );
      expect(gold.extension<AppSemanticPalette>()?.error, AppGoldColors.error);
      expect(
        aurora.extension<AppSemanticPalette>()?.error,
        AppAuroraColors.error,
      );
      expect(
        light.extension<AppComponentColors>()?.oddsBackground,
        AppLightColors.oddsBackground,
      );
      expect(
        gold.extension<AppComponentColors>()?.oddsBackground,
        AppGoldColors.oddsBackground,
      );
      expect(
        aurora.extension<AppComponentColors>()?.oddsBackground,
        AppAuroraColors.oddsBackground,
      );
      expect(
        light.extension<AppOpportunityPalette>()?.fragileDefense,
        AppLightOpportunityColors.fragileDefense,
      );
      expect(
        gold.extension<AppOpportunityPalette>()?.fragileDefense,
        AppGoldOpportunityColors.fragileDefense,
      );
      expect(
        aurora.extension<AppOpportunityPalette>()?.fragileDefense,
        AppAuroraOpportunityColors.fragileDefense,
      );
    });

    test('resolve reading ids to compatible family colors', () {
      final opportunities = CopilotTheme.dark
          .extension<AppOpportunityPalette>()!;

      expect(
        opportunities.byThesisId('open_match_profile'),
        opportunities.openMatch,
      );
      expect(opportunities.byThesisId('ranking_gap'), opportunities.levelGap);
      expect(
        opportunities.byThesisId('strong_attack'),
        opportunities.prolificAttack,
      );
      expect(
        opportunities.byThesisId('positive_form'),
        opportunities.positiveStreak,
      );
      expect(
        opportunities.byThesisId('contradiction'),
        opportunities.fragileDefense,
      );
    });

    test('provide distinct reading badge styles by variant', () {
      final opportunities = CopilotTheme.dark
          .extension<AppOpportunityPalette>()!;
      final simple = opportunities.badgeFor(
        'open_match',
        variant: AppReadingBadgeVariant.simple,
      );
      final combined = opportunities.badgeFor(
        'open_match',
        variant: AppReadingBadgeVariant.combined,
      );
      final soft = opportunities.badgeFor(
        'open_match',
        variant: AppReadingBadgeVariant.soft,
      );

      expect(simple.foreground, opportunities.openMatch);
      expect(combined.foreground, opportunities.openMatch);
      expect(soft.foreground, opportunities.openMatch);
      expect(simple.background, isNot(combined.background));
      expect(combined.border, isNot(soft.border));
    });

    test('keep reading badges readable in every theme variant', () {
      final themes = [
        CopilotTheme.dark,
        CopilotTheme.light,
        CopilotTheme.gold,
        CopilotTheme.aurora,
      ];
      final ids = [
        'solid_favorite',
        'open_match',
        'closed_match',
        'level_gap',
        'credible_outsider',
        'fragile_defense',
        'prolific_attack',
        'positive_streak',
        'negative_streak',
        'team_in_difficulty',
      ];

      for (final theme in themes) {
        final opportunities = theme.extension<AppOpportunityPalette>()!;
        for (final id in ids) {
          for (final variant in AppReadingBadgeVariant.values) {
            final badge = opportunities.badgeFor(id, variant: variant);
            expect(
              _contrastRatio(badge.foreground, badge.background),
              greaterThanOrEqualTo(3),
              reason: '$id/$variant must contrast in ${theme.brightness}',
            );
            expect(
              _contrastRatio(badge.iconColor, badge.background),
              greaterThanOrEqualTo(3),
              reason: '$id/$variant icon must contrast in ${theme.brightness}',
            );
          }
        }
      }
    });

    test('migrated reading widgets do not build business badges locally', () {
      final files = [
        File('lib/features/matches/presentation/matches_home_page.dart'),
        File('lib/features/matches/presentation/match_detail_page.dart'),
        File('lib/features/tickets/presentation/ticket_generator_page.dart'),
      ];

      final forbiddenPatterns = [
        RegExp(r'byThesisId\([^;\n]+\);\s*[\s\S]{0,240}withValues\(alpha'),
        RegExp(r'reading\.color\.withValues\(alpha'),
      ];

      for (final file in files) {
        final content = file.readAsStringSync();
        for (final pattern in forbiddenPatterns) {
          expect(
            pattern.hasMatch(content),
            isFalse,
            reason: '${file.path} still builds a reading badge locally',
          );
        }
      }
    });

    test('keeps the light theme readable through semantic tokens', () {
      final light = CopilotTheme.light;
      final colorScheme = light.colorScheme;
      final components = light.extension<AppComponentColors>()!;

      expect(
        _contrastRatio(colorScheme.onSurface, colorScheme.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          colorScheme.onSurfaceVariant,
          colorScheme.surfaceContainer,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(components.oddsText, components.oddsBackground),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(colorScheme.primary, colorScheme.surfaceContainer),
        greaterThanOrEqualTo(3),
      );
    });

    test('keeps the Vector Gold variant readable through semantic tokens', () {
      final gold = CopilotTheme.gold;
      final colorScheme = gold.colorScheme;
      final text = gold.extension<AppTextPalette>()!;
      final components = gold.extension<AppComponentColors>()!;
      final semantic = gold.extension<AppSemanticPalette>()!;
      final opportunities = gold.extension<AppOpportunityPalette>()!;

      expect(
        _contrastRatio(colorScheme.onSurface, colorScheme.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          colorScheme.onSurfaceVariant,
          colorScheme.surfaceContainer,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(text.weak, colorScheme.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(components.oddsText, components.oddsBackground),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(colorScheme.primary, colorScheme.surfaceContainer),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(semantic.live, colorScheme.surfaceContainer),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(
          opportunities.prolificAttack,
          colorScheme.surfaceContainer,
        ),
        greaterThanOrEqualTo(3),
      );
    });

    test('keeps the Aurora variant readable through semantic tokens', () {
      final aurora = CopilotTheme.aurora;
      final colorScheme = aurora.colorScheme;
      final text = aurora.extension<AppTextPalette>()!;
      final components = aurora.extension<AppComponentColors>()!;
      final semantic = aurora.extension<AppSemanticPalette>()!;
      final opportunities = aurora.extension<AppOpportunityPalette>()!;

      expect(
        _contrastRatio(colorScheme.onSurface, colorScheme.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          colorScheme.onSurfaceVariant,
          colorScheme.surfaceContainer,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(text.weak, colorScheme.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(components.oddsText, components.oddsBackground),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(colorScheme.primary, colorScheme.surfaceContainer),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(semantic.live, colorScheme.surfaceContainer),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(
          opportunities.prolificAttack,
          colorScheme.surfaceContainer,
        ),
        greaterThanOrEqualTo(3),
      );
    });

    test('keeps switch tokens light-mode compatible', () {
      final lightSwitch = CopilotTheme.light.switchTheme;

      expect(
        lightSwitch.thumbColor?.resolve({WidgetState.selected}),
        AppLightColors.surface,
      );
      expect(
        lightSwitch.trackColor?.resolve({WidgetState.selected}),
        AppLightColors.accent,
      );
      expect(lightSwitch.trackOutlineColor?.resolve({}), AppLightColors.border);
    });

    test('keep radii aligned with the mobile component scale', () {
      expect(AppRadius.card, 18);
      expect(AppRadius.input, 14);
      expect(AppRadius.button, 14);
      expect(AppRadius.odds, 10);
      expect(AppRadius.control, 8);
      expect(AppRadius.tight, 6);
      expect(AppRadius.indicator, 4);
      expect(AppRadius.chip, 999);
    });

    test('production widgets do not declare new hex colors directly', () {
      final offenders = _dartFilesUnder('lib')
          .where(
            (file) =>
                !file.path.endsWith('lib/core/theme/app_colors.dart') &&
                !file.path.endsWith('lib/core/theme/app_shadows.dart'),
          )
          .where((file) => file.readAsStringSync().contains('Color(0x'))
          .map((file) => file.path)
          .toList();

      expect(offenders, isEmpty);
    });

    test(
      'production widgets use AppColors for transparent and shadow colors',
      () {
        final forbiddenColors = RegExp(
          r'(?<!App)Colors\.(black|transparent|white|red|green|orange|blue|grey)',
        );
        final offenders = _dartFilesUnder('lib')
            .where(
              (file) =>
                  !file.path.endsWith('lib/core/theme/app_colors.dart') &&
                  forbiddenColors.hasMatch(file.readAsStringSync()),
            )
            .map((file) => file.path)
            .toList();

        expect(offenders, isEmpty);
      },
    );

    test('feature widgets do not use fixed non-transparent AppColors', () {
      final fixedAppColors = RegExp(r'AppColors\.(?!transparent\b)');
      final offenders = _dartFilesUnder('lib')
          .where(
            (file) =>
                !file.path.contains('lib/core/theme/') &&
                fixedAppColors.hasMatch(file.readAsStringSync()),
          )
          .map((file) => file.path)
          .toList();

      expect(offenders, isEmpty);
    });

    test('production widgets use AppRadius for canonical component radii', () {
      final rawRadius = RegExp(
        r'BorderRadius\.circular\((4|6|8|10|14|18|999)\)',
      );
      final offenders = _dartFilesUnder('lib')
          .where((file) => rawRadius.hasMatch(file.readAsStringSync()))
          .map((file) => file.path)
          .toList();

      expect(offenders, isEmpty);
    });
  });
}

double _contrastRatio(Color a, Color b) {
  final luminanceA = a.computeLuminance();
  final luminanceB = b.computeLuminance();
  final lighter = luminanceA > luminanceB ? luminanceA : luminanceB;
  final darker = luminanceA > luminanceB ? luminanceB : luminanceA;
  return (lighter + 0.05) / (darker + 0.05);
}

List<File> _dartFilesUnder(String path) {
  return Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}
