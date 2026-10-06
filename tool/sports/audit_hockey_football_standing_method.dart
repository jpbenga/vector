import 'dart:convert';
import 'dart:io';

import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/features/matches/domain/match_context_key_builder.dart';
import 'package:copilot/features/matches/domain/match_context_key_models.dart';

/// Offline what-if audit: calls the real football distribution builder on
/// hockey points per game. No application rule, preference or publication is
/// changed. Five completed games per opponent is a proposed hockey guard.
void main(List<String> args) {
  final path = args.isEmpty ? 'var/sports/hockey/published.json' : args.single;
  final snapshot = SportPublicationCodec.decode(
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
    SportId.hockey,
  );
  const builder = ChampionshipContextReferenceBuilder();
  final tables = <Map<String, Object?>>[];
  final examples = <Map<String, Object?>>[];
  for (final competition in snapshot.competitions) {
    final regularTables = competition.tables
        .where((t) => t.stage.toLowerCase().contains('regular'))
        .toList();
    for (final table in regularTables) {
      final distribution = builder.distributionForValues(
        metric: ChampionshipContextMetric.pointsPerGame,
        values: [
          for (final row in table.rows)
            if (row.played > 0)
              ChampionshipContextValue(
                teamId: int.parse(row.team.id.value),
                teamName: row.team.name,
                value: row.points / row.played,
              ),
        ],
      );
      String zone(int id) =>
          distribution?.zoneForTeam(id)?.side.name ?? 'middle';
      tables.add({
        'league': competition.name,
        'competitionId': competition.id.value,
        'stage': table.stage,
        'group': table.group,
        'teams': table.rows.length,
        'minimumReferenceGames': table.rows
            .map((r) => r.played)
            .reduce((a, b) => a < b ? a : b),
        'distributionAvailable': distribution != null,
        'upperFence': distribution?.upperFence,
        'high': distribution?.highZone?.values.map((v) => v.teamName).toList(),
        'low': distribution?.lowZone?.values.map((v) => v.teamName).toList(),
        'rows': [
          for (final row in table.rows)
            {
              'id': row.team.id.value,
              'team': row.team.name,
              'rank': row.rank,
              'played': row.played,
              'points': row.points,
              'ppg': row.pointsPerGame,
              'zone': zone(int.parse(row.team.id.value)),
            },
        ],
      });
    }
    for (final fixture in snapshot.items.where(
      (f) =>
          f.competition == competition.id &&
          f.season == competition.season &&
          f.status == SportFixtureStatus.scheduled &&
          f.startsAt != null &&
          f.startsAt!.isAfter(snapshot.capturedAt),
    )) {
      final common =
          regularTables
              .where(
                (t) =>
                    t.rows.any((r) => r.team.id == fixture.home.id) &&
                    t.rows.any((r) => r.team.id == fixture.away.id),
              )
              .toList()
            ..sort((a, b) => b.rows.length.compareTo(a.rows.length));
      if (common.isEmpty) {
        examples.add({
          'league': competition.name,
          'matchId': fixture.id.value,
          'startsAt': fixture.startsAt!.toIso8601String(),
          'away': fixture.away.name,
          'home': fixture.home.name,
          'decision': 'insufficientData',
          'reason': 'no common provider table',
        });
        continue;
      }
      final table = common.first;
      final home = table.rows.firstWhere((r) => r.team.id == fixture.home.id);
      final away = table.rows.firstWhere((r) => r.team.id == fixture.away.id);
      final consistent = [home, away].every(
        (row) => regularTables
            .expand((t) => t.rows)
            .where((r) => r.team.id == row.team.id)
            .every((r) => r.points == row.points && r.played == row.played),
      );
      final d = builder.distributionForValues(
        metric: ChampionshipContextMetric.pointsPerGame,
        values: [
          for (final row in table.rows)
            if (row.played > 0)
              ChampionshipContextValue(
                teamId: int.parse(row.team.id.value),
                teamName: row.team.name,
                value: row.pointsPerGame,
              ),
        ],
      );
      final homeZone = d?.zoneForTeam(int.parse(home.team.id.value));
      final awayZone = d?.zoneForTeam(int.parse(away.team.id.value));
      final sampleOk = home.played >= 5 && away.played >= 5;
      final detected =
          (homeZone != null || awayZone != null) && homeZone != awayZone;
      final eligible = sampleOk && consistent && d != null;
      examples.add({
        'league': competition.name,
        'matchId': fixture.id.value,
        'startsAt': fixture.startsAt!.toIso8601String(),
        'group': table.group,
        'away': fixture.away.name,
        'home': fixture.home.name,
        'awayRank': away.rank,
        'homeRank': home.rank,
        'awayPlayed': away.played,
        'homePlayed': home.played,
        'awayPoints': away.points,
        'homePoints': home.points,
        'awayPpg': away.pointsPerGame,
        'homePpg': home.pointsPerGame,
        'awayZone': awayZone?.side.name ?? 'middle',
        'homeZone': homeZone?.side.name ?? 'middle',
        'referenceTeamCount': table.rows.length,
        'referenceMinimumPlayed': table.rows
            .map((r) => r.played)
            .reduce((a, b) => a < b ? a : b),
        'pointsGap': (home.points - away.points).abs(),
        'playedGap': (home.played - away.played).abs(),
        'eligible': eligible,
        'reason': !sampleOk
            ? 'under five games'
            : !consistent
            ? 'inconsistent provider tables'
            : d == null
            ? 'under ten reference teams'
            : null,
        'decision': !eligible
            ? 'insufficientData'
            : detected
            ? 'detected'
            : 'notDetected',
        'subject': eligible && detected
            ? (home.rank < away.rank ? home.team.name : away.team.name)
            : null,
        'highZone': d?.highZone?.values.map((v) => v.teamName).toList(),
        'lowZone': d?.lowZone?.values.map((v) => v.teamName).toList(),
      });
    }
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'source': path,
      'capturedAt': snapshot.capturedAt.toIso8601String(),
      'method': 'football distributionForValues + five-game hockey guard',
      'fixedPointsThreshold': null,
      'maximumPlayedGap': null,
      'tables': tables,
      'examples': examples,
    }),
  );
}
