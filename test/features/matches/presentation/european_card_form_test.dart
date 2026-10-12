import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/domain/compact_match_data.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/widgets/recent_form_strip.dart';
import 'package:copilot/features/matches/data/api_football_match_adapter.dart';
import 'package:copilot/features/matches/data/supabase_match_feed_snapshot_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/compact_football_match_adapter.dart';
import 'package:copilot/features/matches/presentation/widgets/european_fixture_sections.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> source() =>
    jsonDecode(
          File(
            'test/fixtures/european_lask_liverpool_card_form.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
Map<String, dynamic> day() =>
    jsonDecode(
          File(
            'test/fixtures/delivery/lask_liverpool_form_day.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
MatchBoardItem match(Map<String, dynamic> json) =>
    const ApiFootballMatchAdapter().fromSnapshot(json).single;

void main() {
  test(
    'Cards use played European results; domestic form stays in the detailed dossier',
    () {
      final full = match(source()), compact = match(day());
      for (final m in [full, compact]) {
        final card = compactFootballMatch(match: m, showReadings: false);
        expect(card.away.name, 'Liverpool');
        expect(card.home.form.scope, MatchFormScope.competition);
        expect(card.away.form.scope, MatchFormScope.competition);
        expect(card.home.form.latest, hasLength(3));
        expect(card.away.form.latest, hasLength(1));
        expect(card.away.form.latest.single.fixtureId, '1635686');
        expect(card.away.domesticCompetition, 'Premier League');
        expect(
          card.home.form.latest.map((r) => r.fixtureId),
          full.analysis.europeanComparison!.home.europeanMatches.map(
            (r) => '${r.fixtureId}',
          ),
        );
      }
      expect(
        full.analysis.europeanComparison!.home.domesticMatches,
        hasLength(5),
      );
      expect(
        full.analysis.europeanComparison!.away.domesticMatches,
        hasLength(5),
      );
      expect(compact.analysis.europeanComparison, isNull);
      expect(compact.analysis.europeanCardForm, isNotNull);
      expect(compact.analysis.europeanCardForm!.away.domesticMatches, isEmpty);
    },
  );

  test(
    'Champions, Europa and Conference keep their competition and season separate',
    () {
      for (final id in [2, 3, 848]) {
        final json = source();
        json['raw']['fixtures'][0]['league']['id'] = id;
        final dossier = json['raw']['european_comparisons'][0] as Map;
        dossier['competition']['id'] = id;
        for (final side in ['home', 'away']) {
          for (final game in dossier[side]['europeanRecentMatches'] as List) {
            game['competitionId'] = id;
          }
        }
        final games = dossier['away']['europeanRecentMatches'] as List;
        final original = Map<String, dynamic>.from(games.single as Map);
        games.add({...original, 'fixtureId': 9991, 'competitionId': 61});
        games.add({...original, 'fixtureId': 9992, 'season': 1999});
        games.add({
          ...original,
          'fixtureId': 9993,
          'playedAt': '2026-10-15T18:00:00Z',
        });
        games.add({...original});
        final card = compactFootballMatch(
          match: match(json),
          showReadings: false,
        );
        expect(card.away.form.latest.map((r) => r.fixtureId), ['1635686']);
      }
    },
  );

  test(
    'An older cached domestic projection cannot masquerade as European form',
    () {
      final json = day();
      for (final side in ['home', 'away']) {
        final team = json['raw']['european_card_forms'][0][side] as Map;
        team['domesticRecentMatches'] = team.remove('europeanRecentMatches');
      }
      final m = match(json);
      expect(m.analysis.europeanCardForm, isNull);
      final card = compactFootballMatch(match: m, showReadings: false);
      expect(card.away.form.latest, hasLength(1));
      expect(card.away.form.scope, MatchFormScope.competition);
    },
  );

  test('An empty European series is never padded with domestic games', () {
    final json = source();
    final dossier = json['raw']['european_comparisons'][0] as Map;
    dossier['home']['europeanRecentMatches'] = <Object?>[];
    final m = match(json);
    final card = compactFootballMatch(match: m, showReadings: false);
    expect(card.home.form.latest, isEmpty);
    expect(card.away.form.latest, hasLength(1));
    expect(m.analysis.europeanComparison!.home.domesticMatches, hasLength(5));
    // Legacy publications also retain competition-only form, without a dossier.
    json['raw']['european_comparisons'] = <Object?>[];
    final legacy = compactFootballMatch(
      match: match(json),
      showReadings: false,
    );
    expect(legacy.away.form.latest, hasLength(1));
    json['raw']['recent_league_matches'] = <Object?>[];
    final absent = compactFootballMatch(
      match: match(json),
      showReadings: false,
    );
    expect(absent.away.form.latest, isEmpty);
  });

  test(
    'Snapshot merging retains dossiers and rejects mismatched team identities',
    () {
      final json = day();
      final merged = mergeMatchFeedSnapshotPayloads([
        Map<String, Object?>.from(json),
      ])!;
      expect(
        match(Map<String, dynamic>.from(merged)).analysis.europeanCardForm,
        isNotNull,
      );
      json['raw']['european_card_forms'][0]['away']['teamId'] = 999;
      expect(match(json).analysis.europeanCardForm, isNull);
      final full = mergeMatchFeedSnapshotPayloads([
        Map<String, Object?>.from(source()),
      ])!;
      expect(
        match(Map<String, dynamic>.from(full)).analysis.europeanComparison,
        isNotNull,
      );
    },
  );

  testWidgets(
    'Synthesis preserves five domestic results and a separate European phase for each club',
    (tester) async {
      await initializeDateFormatting('fr');
      final m = match(source());
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: EuropeanComparisonSections(
                comparison: m.analysis.europeanComparison!,
                index: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Situation domestique et forme récente'),
        findsOneWidget,
      );
      expect(find.text('Parcours européen'), findsOneWidget);
      final strips = tester
          .widgetList<RecentFormStrip>(find.byType(RecentFormStrip))
          .toList();
      expect(
        strips
            .where((w) => w.snapshot.scope == MatchFormScope.championship)
            .map((w) => w.snapshot.latest.length),
        [5, 5],
      );
      expect(
        strips
            .where((w) => w.snapshot.scope == MatchFormScope.competition)
            .map((w) => w.snapshot.latest.length),
        [1, 1],
      );
      expect(find.text('Toutes les phases (3)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cards label the European scope and actual short sample at mobile widths',
    (tester) async {
      final m = match(day());
      for (final width in [320.0, 375.0, 390.0, 430.0, 768.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: CopilotTheme.dark,
            home: Scaffold(
              body: MatchFeedCard(match: m, onTap: () {}, showReadings: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Forme (compétition)'), findsOneWidget);
        expect(find.byTooltip('Forme (Ligue des champions)'), findsOneWidget);
        expect(find.text('Forme (championnat)'), findsNothing);
        expect(find.text('1 match'), findsOneWidget);
        expect(find.text('3 matchs'), findsOneWidget);
        expect(find.text('1/5'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
