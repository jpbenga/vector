import 'package:copilot/core/widgets/lector_competition_browser.dart';
import 'package:copilot/core/widgets/lector_radar.dart';
import 'package:copilot/core/sports/presentation/sport_fixture_card.dart';
import 'package:copilot/core/widgets/sports_asset_badge.dart';
import 'dart:convert';
import 'dart:io';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/sports/domain/sport_competition_context.dart';
import 'package:copilot/core/widgets/lector_calendar.dart';
import 'package:copilot/core/widgets/lector_match_card.dart';
import 'package:copilot/core/widgets/lector_workspace_header.dart';
import 'package:copilot/core/widgets/lector_workspace_navigation.dart';
import 'package:copilot/features/hockey/domain/hockey_tier_preview.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> payload() =>
    jsonDecode(
          File(
            'test/fixtures/sports/seven_leagues_compact.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

class _Feed implements SportFeedRepository {
  @override
  SportId get sport => SportId.hockey;
  @override
  Future<SportFeedResult> load(DateTime selectedDate) async =>
      SportFeedResult.available(SportPublicationCodec.decode(payload(), sport));
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  test(
    'hockey live labels retain a factual period and clock, including breaks',
    () {
      final p = payload();
      final row = (p['items'] as List).first as Map<String, dynamic>;
      row['status'] = 'live';
      row['providerStatus'] = 'P2';
      row['clock'] = '12:34';
      var fixture = SportPublicationCodec.decode(p, SportId.hockey).items.first;
      expect(fixture.temporal.compactLabel, 'P2 · 12:34');
      row['providerStatus'] = 'BT';
      row.remove('clock');
      fixture = SportPublicationCodec.decode(p, SportId.hockey).items.first;
      expect(fixture.temporal.compactLabel, 'Pause');
      expect(fixture.temporal.clock, isNull);
    },
  );
  test(
    'seven real leagues keep identities, season, groups and factual form',
    () {
      final p = payload(), s = SportPublicationCodec.decode(p, SportId.hockey);
      expect(s.competitions, hasLength(7));
      expect(s.items, hasLength(7));
      expect(s.competitions.map((c) => c.id.value).toSet(), {
        '57',
        '58',
        '35',
        '10',
        '18',
        '16',
        '47',
      });
      for (final f in s.items) {
        expect(f.competition.sport, SportId.hockey);
        expect(
          s.competitions.singleWhere((c) => c.id == f.competition).season,
          f.season,
        );
        for (final r in [...f.homeForm, ...f.awayForm]) {
          expect(r.startsAt.isBefore(f.startsAt!), isTrue);
          expect(r.matchId, isNot(f.id));
        }
      }
      final nhl = s.competitions.singleWhere((c) => c.id.value == '57');
      expect(nhl.formPhaseVerified, isFalse);
      expect(nhl.tables.every((t) => !t.stage.contains('Pre-season')), isTrue);
      expect(
        nhl.tables.expand((t) => t.rows).every((r) => r.form.isEmpty),
        isTrue,
      );
      expect(
        s.competitions
            .singleWhere((c) => c.id.value == '18')
            .tables
            .single
            .rows
            .first
            .form,
        hasLength(5),
      );
      final bad = payload();
      (bad['items'] as List).first['season'] = '1900';
      expect(
        () => SportPublicationCodec.decode(bad, SportId.hockey),
        throwsFormatException,
      );
    },
  );
  test('the public reader rejects future or duplicate form results', () {
    final p = payload();
    final item = (p['items'] as List).firstWhere(
      (f) => (f['recentForm']['home'] as List).isNotEmpty,
    );
    item['recentForm']['home'][0]['startsAt'] = '2200-01-01T00:00:00Z';
    expect(
      () => SportPublicationCodec.decode(p, SportId.hockey),
      throwsFormatException,
    );
    final duplicate = payload();
    final game = (duplicate['items'] as List).firstWhere(
      (f) => (f['recentForm']['home'] as List).length >= 2,
    );
    game['recentForm']['home'][1] = game['recentForm']['home'][0];
    expect(
      () => SportPublicationCodec.decode(duplicate, SportId.hockey),
      throwsFormatException,
    );
  });
  test(
    'tiers use Lector anchors on continuous tables and reject immature samples',
    () {
      final s = SportPublicationCodec.decode(payload(), SportId.hockey);
      final sample = s.competitions.last.tables.first.rows;
      SportStandingTable table(List<int> points, int played) =>
          SportStandingTable(
            stage: 'Regular Season',
            group: 'One group',
            rows: [
              for (var i = 0; i < points.length; i++)
                SportStandingRow(
                  team: SportParticipant(
                    id: SportEntityId(
                      sport: SportId.hockey,
                      provider: 'api-hockey',
                      kind: SportEntityKind.team,
                      value: '${i + 1}',
                    ),
                    name: 'Team $i',
                  ),
                  rank: i + 1,
                  played: played,
                  points: points[i],
                  wins: 0,
                  overtimeWins: 0,
                  losses: 0,
                  overtimeLosses: 0,
                ),
            ],
          );
      expect(HockeyTierPreview.classify(table([20, 20, 10, 10], 4)), isEmpty);
      expect(
        HockeyTierPreview.classify(table([20, 19, 18, 17], 10)).values.toList(),
        [1, 3, 3, 5],
      );
      expect(
        HockeyTierPreview.classify(table([20, 20, 10, 10], 10)).values.toList(),
        [1, 1, 5, 5],
      );
      expect(sample, isNotEmpty);
    },
  );
  testWidgets(
    'country navigation keeps AHL in USA and calendar emptiness accessible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: HockeyWorkspace(
              repository: _Feed(),
              initialDate: DateTime(2026, 10, 3),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tous'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('hockey-competition-filter')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('hockey-country-États-Unis')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('hockey-country-Russie')), findsNothing);
      await tester.tap(find.text('États-Unis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AHL'));
      await tester.pumpAndSettle();
      expect(find.byType(LectorMatchCard), findsOneWidget);
      final calendar = tester.widget<CopilotCalendar>(
        find.byType(CopilotCalendar),
      );
      calendar.onDateSelected(DateTime(2026, 10, 2));
      await tester.pumpAndSettle();
      expect(find.byType(LectorMatchCard), findsNothing);
      expect(
        find.text('Aucune rencontre hockey programmée pour ce jour.'),
        findsOneWidget,
      );
      expect(find.byType(LectorWorkspaceNavigation), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'shared shell, league filter, radar and standings render at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final raw = payload(),
            day = DateTime.parse(
              (raw['items'] as List).first['calendarDate'] as String,
            );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: HockeyWorkspace(repository: _Feed(), initialDate: day),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LectorWorkspaceHeader), findsOneWidget);
        expect(find.byType(CopilotCalendar), findsOneWidget);
        expect(find.byType(LectorWorkspaceNavigation), findsOneWidget);
        // A public feed must never silently become the user's opportunity feed.
        expect(find.byType(SportFixtureCard), findsNothing);
        expect(find.byType(LectorMatchCard), findsNothing);
        expect(find.text('Personnalisez votre Lector'), findsOneWidget);
        await tester.tap(find.text('Tous'));
        await tester.pumpAndSettle();
        expect(find.byType(LectorCompetitionGroup), findsWidgets);
        expect(find.byType(LectorMatchCard), findsNothing);
        final country = find.byKey(const ValueKey('hockey-country-États-Unis'));
        await tester.ensureVisible(country);
        await tester.tap(
          find.descendant(of: country, matching: find.text('États-Unis')),
        );
        await tester.pumpAndSettle();
        final league = find.byKey(const ValueKey('hockey-league-57'));
        await tester.ensureVisible(league);
        await tester.tap(
          find.descendant(of: league, matching: find.text('NHL')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LectorMatchCard), findsOneWidget);
        final badge = tester.widget<SportsAssetBadge>(
          find
              .descendant(of: league, matching: find.byType(SportsAssetBadge))
              .first,
        );
        expect(badge.imageUrl, contains('/hockey/leagues/57'));
        await tester.ensureVisible(find.text('Pour moi'));
        await tester.tap(find.text('Pour moi'));
        await tester.pumpAndSettle();
        expect(find.byType(SportFixtureCard), findsNothing);
        expect(find.byType(LectorMatchCard), findsNothing);
        expect(
          tester.getSize(find.byType(LectorWorkspaceNavigation)).width,
          lessThanOrEqualTo(520),
        );
        await tester.ensureVisible(find.text('Radar'));
        await tester.tap(find.text('Radar'));
        await tester.pumpAndSettle();
        expect(find.text('Joueurs'), findsOneWidget);
        expect(find.text('Classements'), findsNothing);
        await tester.ensureVisible(find.text('Équipes'));
        await tester.tap(find.text('Équipes'));
        await tester.pumpAndSettle();
        expect(find.text('Équipes les plus chaudes'), findsOneWidget);
        expect(find.byType(LectorRadarRankingPanel), findsOneWidget);
        expect(find.byType(LectorRadarEntryCard), findsWidgets);
        expect(find.byType(LectorRadarTeamRow), findsNWidgets(10));
        expect(find.byType(LectorFormResultStrip), findsWidgets);
        final pagination = tester.widget<LectorRadarPagination>(
          find.byType(LectorRadarPagination),
        );
        expect(pagination.itemCount, 15);
        expect(pagination.page, 0);
        await tester.ensureVisible(
          find.byKey(const ValueKey('hockey-team-next')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('hockey-team-next')));
        await tester.pumpAndSettle();
        final rows = tester.widgetList<LectorRadarTeamRow>(
          find.byType(LectorRadarTeamRow),
        );
        expect(
          tester
              .widget<LectorRadarPagination>(find.byType(LectorRadarPagination))
              .page,
          1,
        );
        expect(rows.first.rank, 11);
        expect(find.text('Signaux Form Radar'), findsNothing);
        await tester.ensureVisible(find.text('Joueurs'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Joueurs'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Aucun joueur éligible'), findsOneWidget);
        expect(find.byType(LectorRadarTeamRow), findsNothing);
        expect(find.text('Classements'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
