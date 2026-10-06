import 'package:copilot/features/hockey/domain/hockey_standing_view.dart';
import 'dart:io';
import 'dart:convert';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/domain/sport_competition_context.dart';
import 'package:copilot/core/theme/app_components.dart';
import 'package:copilot/core/widgets/lector_standing_table.dart';
import 'package:copilot/features/hockey/presentation/hockey_context_panels.dart';
import 'package:copilot/features/hockey/presentation/hockey_match_detail_page.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../fixtures/sports/hockey_readings_fixture.dart';

final _fixture = hockeyReadingFixture();
final _teams = [_fixture.away, hockeyTeam('Other'), _fixture.home];

SportCompetitionContext competition({bool conferences = false}) {
  final rows = [
    for (final (index, team) in _teams.indexed)
      SportStandingRow(
        team: team,
        rank: index + 1,
        played: 12,
        points: 18,
        wins: 8,
        overtimeWins: 0,
        losses: 4,
        overtimeLosses: 0,
      ),
  ];
  final venueRows = [
    for (final (index, team) in _teams.indexed)
      SportVenueStandingRow(
        team: team,
        rank: index + 1,
        played: 6,
        wins: 4,
        losses: 2,
        goalsFor: 18,
        goalsAgainst: 12,
      ),
  ];
  return SportCompetitionContext(
    id: _fixture.competition,
    name: _fixture.competitionName,
    season: _fixture.season,
    country: 'Test',
    formPhaseVerified: true,
    tables: conferences
        ? [
            SportStandingTable(
              stage: 'Regular Season',
              group: 'Est',
              rows: rows.take(2),
            ),
            SportStandingTable(
              stage: 'Regular Season',
              group: 'Ouest',
              rows: rows.skip(2),
            ),
          ]
        : [
            SportStandingTable(
              stage: 'Regular Season',
              group: 'Général',
              rows: rows,
            ),
          ],
    venueStandings: SportVenueStandings(
      collectedAt: readingCutoff,
      home: venueRows,
      away: venueRows.reversed,
      unavailableTeams: const [],
    ),
  );
}

void expectRoles(WidgetTester tester, Map<String, String?> expected) {
  final teams = tester.widgetList<LectorStandingTeam>(
    find.byType(LectorStandingTeam),
  );
  expect({for (final team in teams) team.name: team.sideLabel}, expected);
  for (final team in teams) {
    final context = tester.element(find.byWidget(team));
    final color = expected[team.name] == 'DOM.'
        ? context.brand.accent
        : expected[team.name] == 'EXT.'
        ? context.strategies.violetStyle.color
        : null;
    expect(team.role.color(context), color);
    final row = tester.widget<LectorStandingRow>(
      find.ancestor(
        of: find.byWidget(team),
        matching: find.byType(LectorStandingRow),
      ),
    );
    expect(row.highlightColor, color);
    expect(
      find.descendant(
        of: find.byWidget(team),
        matching: find.byType(LectorStandingSidePill),
      ),
      color == null ? findsNothing : findsOneWidget,
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'hockey detail marks home DOM. and away EXT. in every standings scope at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HockeyMatchDetailPage(
              fixture: _fixture,
              competition: competition(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Classement'));
        await tester.tap(find.text('Classement'));
        await tester.pumpAndSettle();
        for (var scope = 0; scope < 3; scope++) {
          final chip = find.byKey(ValueKey('hockey-standing-scope-$scope'));
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expectRoles(tester, {'Home': 'DOM.', 'Away': 'EXT.', 'Other': null});
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  Map<String, dynamic> collected() =>
      jsonDecode(
            File(
              'test/fixtures/sports/hockey_venue_standings_compact.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  test(
    'calculated venue points reconcile with official totals and corrupt public tables are rejected',
    () {
      final snapshot = SportPublicationCodec.decode(
        collected(),
        SportId.hockey,
      );
      for (final c in snapshot.competitions) {
        final venue = c.venueStandings!;
        expect(venue.status, 'reconciled');
        expect(venue.hasCalculatedPoints, isTrue);
        final unique = {
          for (final t in c.tables)
            for (final r in t.rows) r.team.id: r,
        };
        for (final r in unique.values) {
          final h = venue.home.firstWhere((v) => v.team.id == r.team.id);
          final a = venue.away.firstWhere((v) => v.team.id == r.team.id);
          expect(h.points! + a.points!, r.points);
          expect(h.played + a.played, r.played);
        }
      }
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (p) => p['competitions'][0]['venueStandings']['home'][0]['points']++,
        (p) =>
            p['competitions'][0]['venueStandings']['home'][0]['overtimeWins'] =
                999,
        (p) => p['competitions'][0]['venueStandings']['away'].removeLast(),
        (p) => p['competitions'][0]['venueStandings']['home'][0]['team']['id'] =
            'foreign',
      ]) {
        final p = collected();
        mutate(p);
        expect(
          () => SportPublicationCodec.decode(p, SportId.hockey),
          throwsFormatException,
        );
      }
    },
  );
  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'real inter-conference opposition shows both highlighted teams and calculated home/away points at $width',
      (tester) async {
        final snapshot = SportPublicationCodec.decode(
          collected(),
          SportId.hockey,
        );
        final fixture = snapshot.items.first, c = snapshot.competitions.first;
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HockeyMatchDetailPage(fixture: fixture, competition: c),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Classement'));
        await tester.tap(find.text('Classement'));
        await tester.pumpAndSettle();
        expect(find.byType(LectorStandingDataTable), findsNWidgets(2));
        final expected = {
          for (final t in c.tables.take(2))
            for (final r in t.rows)
              r.team.name: r.team.id == fixture.home.id
                  ? 'DOM.'
                  : r.team.id == fixture.away.id
                  ? 'EXT.'
                  : null,
        };
        expectRoles(tester, expected);
        for (final scope in [1, 2]) {
          final chip = find.byKey(ValueKey('hockey-standing-scope-$scope'));
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expectRoles(tester, expected);
          final rendered = tester
              .widgetList<LectorStandingDataTable>(
                find.byType(LectorStandingDataTable),
              )
              .toList();
          expect(rendered, hasLength(2));
          for (var index = 0; index < rendered.length; index++) {
            final entries = rendered[index].groups
                .expand((g) => g.rows)
                .toList();
            final sourceIndex = c.tables.indexWhere(
              (t) =>
                  t.rows.length == entries.length &&
                  t.rows.every(
                    (r) => entries.any((e) => e.identity == r.team.id.key),
                  ),
            );
            expect(sourceIndex, greaterThanOrEqualTo(0));
            final rows = HockeyStandingView.rows(c, sourceIndex, scope);
            expect(entries.map((r) => r.name), rows.map((r) => r.team.name));
            expect(
              entries.map((r) => r.values.last.text),
              rows.map((r) => '${r.points}'),
            );
            expect(entries.map((r) => r.rank), rows.map((r) => '${r.rank}'));
          }
          expect(find.text('% V'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  test('feature adapters cannot assemble a second standings renderer', () {
    final offenders = <String>[];
    final duplicateRenderers = RegExp(
      r'\bLectorStanding(?:Row|Team|SidePill|Cell|TierGroup|Table)\s*\(',
    );
    for (final file in Directory(
      'lib/features',
    ).listSync(recursive: true).whereType<File>()) {
      if (file.path.endsWith('.dart') &&
          duplicateRenderers.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Sports supply table data to LectorStandingDataTable, never a second row renderer.',
    );
  });

  testWidgets(
    'official positions and points survive tier annotation; venue records never fabricate points',
    (tester) async {
      final teams = [
        hockeyTeam('First'),
        hockeyTeam('Second'),
        hockeyTeam('Third'),
        hockeyTeam('Fourth'),
      ];
      final c = competition();
      final data = SportCompetitionContext(
        id: c.id,
        name: c.name,
        season: c.season,
        country: c.country,
        formPhaseVerified: true,
        venueStandings: c.venueStandings,
        tables: [
          SportStandingTable(
            stage: 'Regular Season',
            group: 'Général',
            rows: [
              for (var i = 0; i < 4; i++)
                SportStandingRow(
                  team: teams[i],
                  rank: i + 1,
                  played: [12, 10, 12, 12][i],
                  points: [24, 22, 12, 10][i],
                  wins: 5,
                  losses: 3,
                  overtimeWins: 1,
                  overtimeLosses: 1,
                  goalsFor: 30,
                  goalsAgainst: 20,
                ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HockeyStandingsPanel(competition: data),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LectorStandingPanel<int>), findsOneWidget);
      expect(find.byType(LectorStandingDataTable), findsOneWidget);
      expect(find.byType(LectorStandingLegend), findsOneWidget);
      final table = tester.widget<LectorStandingDataTable>(
        find.byType(LectorStandingDataTable),
      );
      final entries = table.groups.expand((g) => g.rows).toList();
      // Second has higher points per match, but must keep its official second rank.
      expect(entries.map((r) => r.name), [
        'First',
        'Second',
        'Third',
        'Fourth',
      ]);
      expect(entries.map((r) => r.rank), ['1', '2', '3', '4']);
      expect(entries.map((r) => r.values.last.text), ['24', '22', '12', '10']);
      expect(table.columns.map((c) => c.label), [
        'J',
        'V',
        'D',
        'BP',
        'BC',
        'Diff',
        'Pts',
      ]);
      expect(entries.first.values[1].text, '6');
      expect(entries.first.values[2].text, '4');
      for (final scope in [1, 2]) {
        await tester.ensureVisible(
          find.byKey(ValueKey('hockey-standing-scope-$scope')),
        );
        await tester.tap(find.byKey(ValueKey('hockey-standing-scope-$scope')));
        await tester.pumpAndSettle();
        final venue = tester.widget<LectorStandingDataTable>(
          find.byType(LectorStandingDataTable),
        );
        for (final row in venue.groups.expand((g) => g.rows)) {
          expect(row.rank, '—');
          expect(row.values.last.text, '—');
        }
        expect(
          find.textContaining('points et positions non fournis'),
          findsOneWidget,
        );
        expect(find.text('% V'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hockey badges follow team identity across conferences and refreshes',
    (tester) async {
      Widget panel({bool reverse = false}) => MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HockeyStandingsPanel(
              competition: competition(conferences: true),
              homeTeamId: reverse ? _fixture.away.id : _fixture.home.id,
              awayTeamId: reverse ? _fixture.home.id : _fixture.away.id,
            ),
          ),
        ),
      );
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      expectRoles(tester, {'Home': 'DOM.', 'Away': 'EXT.', 'Other': null});
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ouest').last);
      await tester.pumpAndSettle();
      expectRoles(tester, {'Home': 'DOM.'});
      await tester.pumpWidget(panel(reverse: true));
      await tester.pumpAndSettle();
      expectRoles(tester, {'Home': 'EXT.', 'Away': 'DOM.', 'Other': null});
      expect(tester.takeException(), isNull);
    },
  );
}
