import 'package:copilot/core/sports/domain/sport_player_activity.dart';
import 'package:copilot/core/sports/domain/sport_competition_context.dart';
import 'package:copilot/features/hockey/presentation/hockey_player_radar_panel.dart';
import '../../fixtures/sports/hockey_readings_fixture.dart';
import 'dart:convert';
import 'dart:io';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_feed_repository.dart';
import 'package:copilot/core/widgets/lector_player_radar.dart';
import 'package:copilot/core/widgets/lector_radar.dart';
import 'package:copilot/features/hockey/domain/hockey_player_radar.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> playersPayload() =>
    jsonDecode(
          File(
            'test/fixtures/sports/hockey_players_compact.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

class _Feed implements SportFeedRepository {
  _Feed([this.data]);
  final Map<String, dynamic>? data;
  @override
  SportId get sport => SportId.hockey;
  @override
  Future<SportFeedResult> load(DateTime date) async =>
      SportFeedResult.available(
        SportPublicationCodec.decode(data ?? playersPayload(), sport),
      );
}

SportPlayerProfile historyProfile(String name, List<int?> actions) =>
    SportPlayerProfile(
      id: hockeyId(SportEntityKind.player, name),
      name: name,
      competition: hockeyId(SportEntityKind.competition, '35'),
      season: '2026',
      team: hockeyTeam('Team'),
      identitySource: 'event-name',
      activity: [
        for (var i = 0; i < actions.length; i++)
          SportPlayerMatchActivity(
            result: SportFormResult(
              matchId: hockeyId(SportEntityKind.match, '$name-$i'),
              startsAt: readingCutoff.subtract(
                Duration(days: actions.length - i),
              ),
              opponent: 'Opponent $i',
              home: true,
              scored: 20,
              conceded: 1,
              outcome: SportFormOutcome.win,
              providerStatus: 'FT',
            ),
            goals: actions[i],
            assists: actions[i] == null ? null : 0,
          ),
      ],
    );

Map<String, dynamic> extendedPlayersPayload() {
  final p = playersPayload();
  final profile = p['playerRadar']['profiles'][0] as Map<String, dynamic>;
  final competition = (p['competitions'] as List).firstWhere(
    (c) => c['id'] == profile['competitionId'],
  );
  final standing = (competition['tables'] as List)
      .expand((t) => t['rows'] as List)
      .firstWhere((r) => r['team']['id'] == profile['team']['id']);
  final history = standing['form'] as List;
  final recent = profile['activity'] as List;
  assert(history.length > 3);
  final older = history
      .take(history.length - 3)
      .map((r) => {...r as Map<String, dynamic>, 'goals': 0, 'assists': 0})
      .toList();
  profile['activity'] = [...older, ...recent];
  p['playerRadar']['profiles'] = [profile];
  final coverage = (p['playerRadar']['coverage'] as List).firstWhere(
    (c) =>
        c['competitionId'] == profile['competitionId'] &&
        c['teamId'] == profile['team']['id'],
  );
  coverage['history'] = history;
  return p;
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  test(
    'real collected players survive public decoding and ranking without future games',
    () {
      final snapshot = SportPublicationCodec.decode(
        playersPayload(),
        SportId.hockey,
      );
      final entries = HockeyPlayerRadarRanker.rank(
        snapshot.players,
        before: snapshot.capturedAt,
      );
      expect(entries, hasLength(18));
      expect(entries.every((e) => e.goals + e.assists >= 2), isTrue);
      expect(entries.every((e) => e.profile.activity.length == 3), isTrue);
      expect(
        HockeyPlayerRadarRanker.rank(
          snapshot.players,
          before: DateTime.utc(2026, 1, 1),
        ),
        isEmpty,
      );
    },
  );
  test(
    'real full-season collection decodes and keeps recent counters separate from older matches',
    () {
      final p =
          jsonDecode(
                File(
                  'test/fixtures/sports/hockey_player_history_compact.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final snapshot = SportPublicationCodec.decode(p, SportId.hockey);
      final entries = HockeyPlayerRadarRanker.rank(
        snapshot.players,
        before: snapshot.capturedAt,
      );
      expect(entries, hasLength(4));
      expect(entries.every((e) => e.profile.activity.length > 3), isTrue);
      for (final entry in entries) {
        expect(
          entry.goals,
          entry.profile.activity
              .skip(entry.profile.activity.length - 3)
              .fold<int>(0, (n, r) => n + r.goals!),
        );
        expect(
          entry.assists,
          entry.profile.activity
              .skip(entry.profile.activity.length - 3)
              .fold<int>(0, (n, r) => n + r.assists!),
        );
      }
    },
  );
  test(
    'compact reader rejects incomplete coverage and a shifted three-game window',
    () {
      final noCoverage = playersPayload();
      (noCoverage['playerRadar']['coverage'] as List).clear();
      expect(
        () => SportPublicationCodec.decode(noCoverage, SportId.hockey),
        throwsFormatException,
      );
      final wrongMatch = playersPayload();
      wrongMatch['playerRadar']['profiles'][0]['activity'][0]['id'] =
          'unrelated';
      expect(
        () => SportPublicationCodec.decode(wrongMatch, SportId.hockey),
        throwsFormatException,
      );
      final wrongScore = playersPayload();
      wrongScore['playerRadar']['profiles'][0]['activity'][0]['scored'] = 99;
      expect(
        () => SportPublicationCodec.decode(wrongScore, SportId.hockey),
        throwsFormatException,
      );
      final future = playersPayload();
      future['playerRadar']['profiles'][0]['activity'][0]['startsAt'] =
          '2027-01-01T10:00:00Z';
      expect(
        () => SportPublicationCodec.decode(future, SportId.hockey),
        throwsFormatException,
      );
    },
  );
  test(
    'past contributions cannot qualify a cooled player; recent metrics and full-history series remain separate',
    () {
      final cooled = historyProfile('Past star', [10, 10, 10, 0, 0, 1]);
      final steady = historyProfile('Steady', [1, 1, 1, 1, 1, 1]);
      final burst = historyProfile('Burst', [0, 0, 0, 0, 0, 9]);
      final entries = HockeyPlayerRadarRanker.rank([
        cooled,
        burst,
        steady,
      ], before: readingCutoff);
      expect(entries.map((e) => e.profile.name), ['Steady', 'Burst']);
      expect(entries.first.goals, 3);
      expect(entries.first.decisiveMatches, 3);
      expect(entries.first.streak, 6);
      final unknown = HockeyPlayerRadarRanker.rank([
        historyProfile('Unknown', [1, 1, null, 1, 1, 1]),
      ], before: readingCutoff).single;
      expect(unknown.streak, 3);
      expect(unknown.streakLimitedByUnknown, isTrue);
      expect(
        HockeyPlayerRadarRanker.rank([
          historyProfile('Missing recent', [10, 1, 1, null]),
        ], before: readingCutoff),
        isEmpty,
      );
    },
  );

  test(
    'public reader preserves extended history and rejects shifted, fabricated or unknown recent contributions',
    () {
      final p = extendedPlayersPayload();
      final player = SportPublicationCodec.decode(
        p,
        SportId.hockey,
      ).players.single;
      expect(player.activity.length, greaterThan(3));
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (p) => p['playerRadar']['profiles'][0]['activity'][0]['id'] = 'foreign',
        (p) =>
            (p['playerRadar']['profiles'][0]['activity'] as List)
                    .last['goals'] =
                null,
        (p) =>
            (p['playerRadar']['profiles'][0]['activity'] as List)
                    .last['assists'] =
                null,
        (p) => p['playerRadar']['profiles'][0]['activity'][0]['goals'] = 999,
      ]) {
        final altered = extendedPlayersPayload();
        mutate(altered);
        expect(
          () => SportPublicationCodec.decode(altered, SportId.hockey),
          throwsFormatException,
        );
      }
      p['playerRadar']['profiles'][0]['activity'][0]['goals'] = null;
      p['playerRadar']['profiles'][0]['activity'][0]['assists'] = null;
      expect(
        SportPublicationCodec.decode(
          p,
          SportId.hockey,
        ).players.single.activity.first.contributions,
        isNull,
      );
    },
  );

  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'real expanded hockey history appears in the main Radar at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p =
            jsonDecode(
                  File(
                    'test/fixtures/sports/hockey_player_history_compact.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: HockeyWorkspace(
                repository: _Feed(p),
                initialDate: DateTime(2026, 10, 5),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Radar'));
        await tester.pumpAndSettle();
        final panel = find.byType(LectorRadarRankingPanel);
        expect(
          find.descendant(of: panel, matching: find.text('Avant')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: panel, matching: find.text('3 récents')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: panel, matching: find.text('Inconnu')),
          findsOneWidget,
        );
        final matrices = tester.widgetList<LectorPlayerActivityMatrix>(
          find.descendant(
            of: panel,
            matching: find.byType(LectorPlayerActivityMatrix),
          ),
        );
        expect(matrices, hasLength(4));
        expect(matrices.every((m) => m.activity.length > 3), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'full hockey history and three-game divider share the football matrix at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final entry = HockeyPlayerRadarRanker.rank([
          historyProfile('History', List.filled(30, 1)),
        ], before: readingCutoff).single;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(body: HockeyPlayerSignalPanel(entries: [entry])),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Avant'), findsOneWidget);
        expect(find.text('3 récents'), findsOneWidget);
        expect(find.text('3/3 décisif · série 30'), findsOneWidget);
        final matrix = tester.widget<LectorPlayerActivityMatrix>(
          find.byType(LectorPlayerActivityMatrix),
        );
        expect(matrix.activity, hasLength(30));
        expect(matrix.recentWindow, 3);
        expect(matrix.columnCount, lessThan(30));
        expect(find.byType(LectorPlayerActivityCell), findsNWidgets(30));
        final olderScroll = find.descendant(
          of: find.byType(LectorPlayerActivityMatrix),
          matching: find.byType(SingleChildScrollView),
        );
        expect(olderScroll, findsOneWidget);
        await tester.drag(olderScroll, const Offset(200, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'hockey player Radar uses shared football widgets and pagination at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: HockeyWorkspace(
                repository: _Feed(),
                initialDate: DateTime(2026, 10, 5),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Radar'));
        await tester.pumpAndSettle();
        expect(find.text('Joueurs'), findsOneWidget);
        expect(find.text('Équipes'), findsOneWidget);
        expect(find.text('Classements'), findsNothing);
        expect(find.text('Joueurs les plus chauds'), findsOneWidget);
        expect(find.byType(LectorRadarPlayerRow), findsNWidgets(10));
        expect(find.byType(LectorPlayerActivityMatrix), findsWidgets);
        expect(find.byType(LectorPlayerPeriodLabel), findsWidgets);
        expect(find.text('Titulaire'), findsNothing);
        expect(find.text('Absent'), findsNothing);
        final pager = tester.widget<LectorRadarPagination>(
          find.byType(LectorRadarPagination),
        );
        expect(pager.itemCount, 18);
        await tester.ensureVisible(
          find.byKey(const ValueKey('hockey-player-next')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('hockey-player-next')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<LectorRadarPlayerRow>(
                find.byType(LectorRadarPlayerRow).first,
              )
              .rank,
          11,
        );
        expect(find.byType(LectorRadarPlayerRow), findsNWidgets(8));
        await tester.ensureVisible(find.text('Équipes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Équipes'));
        await tester.pumpAndSettle();
        expect(find.byType(LectorRadarPlayerRow), findsNothing);
        expect(find.byType(LectorRadarTeamRow), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
