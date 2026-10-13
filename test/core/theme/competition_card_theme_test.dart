import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/theme/app_components.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/theme/competition_card_theme.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:copilot/features/matches/presentation/widgets/european_evening_briefing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, ThemeData> get selectableThemes => {
  'dark': CopilotTheme.dark,
  'light': CopilotTheme.light,
  'gold': CopilotTheme.gold,
  'aurora': CopilotTheme.aurora,
  'dracula': CopilotTheme.dracula,
  'tokyo': CopilotTheme.tokyoNight,
  'mocha': CopilotTheme.catppuccinMocha,
  'latte': CopilotTheme.catppuccinLatte,
  'solarized': CopilotTheme.solarizedLight,
  'quiet': CopilotTheme.quietLight,
};
double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  testWidgets(
    'all competition materials follow every theme with readable artwork',
    (tester) async {
      final genericSurfaces = <Color>{};
      for (final entry in selectableThemes.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            themeAnimationDuration: Duration.zero,
            home: Builder(
              builder: (context) {
                for (final identity in CompetitionCardIdentity.values) {
                  final palette = CompetitionCardTheme(context, identity);
                  final background = palette.background;
                  if (identity == CompetitionCardIdentity.generic) {
                    expect(background, context.surfaces.surface);
                    genericSurfaces.add(background);
                  }
                  for (final color in [
                    background,
                    palette.illustrationExtreme(Colors.white),
                    palette.illustrationExtreme(Colors.black),
                  ]) {
                    expect(
                      contrast(palette.title, color),
                      greaterThanOrEqualTo(4.5),
                      reason: '${entry.key}/$identity title',
                    );
                    expect(
                      contrast(palette.secondaryText, color),
                      greaterThanOrEqualTo(4.5),
                      reason: '${entry.key}/$identity secondary',
                    );
                  }
                  expect(
                    contrast(palette.accent, background),
                    greaterThanOrEqualTo(4.5),
                    reason: '${entry.key}/$identity accent',
                  );
                  expect(
                    contrast(palette.statusText, background),
                    greaterThanOrEqualTo(4.5),
                  );
                  expect(
                    palette.contentTheme.extension<AppOpportunityPalette>(),
                    context.opportunities,
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: entry.key);
      }
      expect(
        genericSurfaces,
        selectableThemes.values
            .map((theme) => theme.extension<AppSurfacePalette>()!.surface)
            .toSet(),
      );
    },
  );
  testWidgets(
    'actual league and Champions cards and briefing fit every theme at 320px',
    (tester) async {
      await initializeDateFormatting('fr');
      tester.view.physicalSize = const Size(320, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final matches = [
        for (final name in ['league', 'champions'])
          SnapshotMatchFeedRepository(
            snapshot:
                jsonDecode(
                      File(
                        'assets/design_preview/$name.json',
                      ).readAsStringSync(),
                    )
                    as Map<String, dynamic>,
          ).allMatches().single,
      ];
      for (final entry in selectableThemes.entries) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(entry.key),
            theme: entry.value,
            themeAnimationDuration: Duration.zero,
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  EuropeanEveningBriefing(
                    matches: matches,
                    date: DateTime(2026, 10, 13),
                    showReadings: false,
                    onOpenMatch: (_) {},
                  ),
                  for (final match in matches)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: MatchFeedCard(
                        match: match,
                        showReadings: false,
                        onTap: () {},
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: entry.key);
        expect(find.text('Explorer la soirée'), findsOneWidget);
      }
    },
  );
}
