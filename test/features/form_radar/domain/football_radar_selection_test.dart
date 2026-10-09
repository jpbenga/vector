import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/features/form_radar/domain/football_radar_selection.dart';
import 'package:copilot/features/form_radar/domain/radar_audience_filter.dart';
import 'package:copilot/features/form_radar/domain/radar_scope.dart';
import 'package:copilot/features/form_radar/domain/team_form_radar.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter_test/flutter_test.dart';

TeamFormRadarProfile team(
  int id,
  String name, {
  int league = 61,
  List<String>? results,
}) => TeamFormRadarProfile(
  teamId: id,
  teamName: name,
  leagueId: league,
  leagueName: 'League',
  activity: [
    for (final (i, r) in (results ?? List.filled(7, 'W')).indexed)
      TeamRecentMatchSnapshot(
        fixtureId: id * 100 + i,
        opponentName: 'Opponent',
        venue: RecentMatchVenue.home,
        result: r,
        playedAt: DateTime.utc(2026, 9, i + 1),
      ),
  ],
);
FootballRadarSelection select(
  List<TeamFormRadarProfile> teams, {
  bool national = false,
  RadarAudienceFilter filter = const RadarAudienceFilter(),
}) => FootballRadarSelection(
  players: [],
  teams: teams,
  audience: filter,
  nationalTeams: national,
  mode: 'teams',
  capturedAt: DateTime.utc(2026, 10, 9),
  sourceIds: const ['11111111-1111-4111-8111-111111111111'],
);
void main() {
  test(
    'Top 50 membership is shared by the display and Generator across all pages',
    () {
      final s = select([
        team(1, 'Penafiel'),
        for (var i = 2; i <= 51; i++)
          team(
            i,
            'Club ${i.toString().padLeft(2, '0')}',
            results: ['W', 'W', 'W', 'W', 'D'],
          ),
        team(52, 'Viking', results: ['L', 'L', 'W', 'W', 'D']),
        team(53, 'Lyon', results: ['L', 'D', 'W', 'W', 'W']),
      ]);
      expect(s.teams, hasLength(50));
      expect(s.scope.teams, hasLength(50));
      expect(
        s.scope.teams.map((m) => m.teamId),
        s.teams.map((e) => '${e.profile.teamId}'),
      );
      expect(s.scope.teams.any((m) => m.id == '52' || m.id == '53'), false);
      expect(s.scope.teams.map((m) => m.rank), List.generate(50, (i) => i + 1));
      expect(s.scope.teams.first.matchIds, hasLength(5));
      expect(s.scope.toJson()['sourceIds'], s.sourceIds);
    },
  );
  test(
    'club/national, women and youth filters apply before the shared cap',
    () {
      final teams = [
        team(1, 'France', league: 5),
        team(2, 'France U21', league: 10),
        team(3, 'Club W'),
        team(4, 'Adult club'),
      ];
      expect(select(teams).scope.teams.map((m) => m.id), ['4']);
      expect(select(teams, national: true).scope.teams.map((m) => m.id), ['1']);
      expect(
        select(
          teams,
          national: true,
          filter: const RadarAudienceFilter(includeYouth: true),
        ).scope.teams.map((m) => m.id),
        containsAll(['1', '2']),
      );
      expect(
        select(
          teams,
          filter: const RadarAudienceFilter(includeWomen: true),
        ).scope.teams.map((m) => m.id),
        containsAll(['3', '4']),
      );
    },
  );
  test(
    'read scope retains the exact five references and isolates account, sport and day',
    () {
      final day = DateTime(2026, 10, 9), s = select([team(1, 'Penafiel')]);
      expect(s.scope.teams.single.matchIds, [
        '102',
        '103',
        '104',
        '105',
        '106',
      ]);
      const owner = IdentityScope.account('radar-scope-selection');
      final saved = s.scope;
      RadarScopeSession.remember(owner, 'football', day, saved);
      expect(RadarScopeSession.read(owner, 'football', day), same(saved));
      expect(RadarScopeSession.read(owner, 'hockey', day), null);
      expect(
        RadarScopeSession.read(
          const IdentityScope.account('another-owner'),
          'football',
          day,
        ),
        null,
      );
      expect(
        RadarScopeSession.read(owner, 'football', DateTime(2026, 10, 10)),
        null,
      );
    },
  );
}
