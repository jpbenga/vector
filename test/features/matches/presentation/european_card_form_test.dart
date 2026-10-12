import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/domain/compact_match_data.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/data/api_football_match_adapter.dart';
import 'package:copilot/features/matches/data/supabase_match_feed_snapshot_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/compact_football_match_adapter.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'Liverpool card and detail share five dated domestic results, including compact delivery',
    () {
      final full = match(source()), compact = match(day());
      expect(full.analysis.awayRecentLeagueMatches, hasLength(1));
      for (final m in [full, compact]) {
        final card = compactFootballMatch(match: m, showReadings: false);
        expect(card.away.name, 'Liverpool');
        expect(card.home.form.scope, MatchFormScope.championship);
        expect(card.away.form.scope, MatchFormScope.championship);
        expect(card.home.form.latest, hasLength(5));
        expect(card.away.form.latest, hasLength(5));
        expect(card.away.domesticCompetition, 'Premier League');
        expect(
          card.away.form.latest.map((r) => r.fixtureId),
          full.analysis.europeanComparison!.away.domesticMatches.map(
            (r) => '${r.fixtureId}',
          ),
        );
      }
      expect(compact.analysis.europeanComparison, isNull);
      expect(compact.analysis.europeanCardForm, isNotNull);
    },
  );
  test(
    'Missing or partial domestic form never falls back to a European sample or hides the other club',
    () {
      final json = day();
      final context =
          (json['raw']['european_card_forms'] as List).single as Map;
      (context['home'] as Map)['domesticRecentMatches'] = <Object?>[];
      (context['away'] as Map)['domesticRecentMatches'] =
          ((context['away'] as Map)['domesticRecentMatches'] as List)
              .take(3)
              .toList();
      final card = compactFootballMatch(
        match: match(json),
        showReadings: false,
      );
      expect(card.home.form.latest, isEmpty);
      expect(card.away.form.latest, hasLength(3));
      expect(card.home.form.scope, card.away.form.scope);
      json['raw']['european_card_forms'] = <Object?>[];
      final absent = compactFootballMatch(
        match: match(json),
        showReadings: false,
      );
      expect(absent.away.form.latest, isEmpty);
    },
  );
  test(
    'Snapshot merging retains matching dossiers; mismatched fixture identities are rejected',
    () {
      final json = day();
      final merged = mergeMatchFeedSnapshotPayloads([
        Map<String, Object?>.from(json),
      ])!;
      expect(
        match(Map<String, dynamic>.from(merged)).analysis.europeanCardForm,
        isNotNull,
      );
      final context =
          (json['raw']['european_card_forms'] as List).single as Map;
      (context['away'] as Map)['teamId'] = 999;
      expect(match(json).analysis.europeanCardForm, isNull);
      final original = source();
      final fullMerged = mergeMatchFeedSnapshotPayloads([
        Map<String, Object?>.from(original),
      ])!;
      expect(
        match(
          Map<String, dynamic>.from(fullMerged),
        ).analysis.europeanComparison,
        isNotNull,
      );
    },
  );
  testWidgets(
    'European cards show five real championship results at small widths',
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
        expect(find.text('Forme (championnat)'), findsOneWidget);
        expect(find.text('1/5'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
