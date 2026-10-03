import '../../matches/domain/match_board_item.dart';
import '../domain/team_form_radar.dart';

/// Builds one team ranking profile from every competition present in the
/// snapshot. A team keeps its five most recent completed matches across those
/// competitions, so an empty daily fixture window does not remove it.
class TeamFormRadarSnapshotAdapter {
  const TeamFormRadarSnapshotAdapter();

  List<TeamFormRadarProfile> fromSnapshot(Map<String, Object?> snapshot) {
    final raw = _map(snapshot['raw']);
    final teams = <int, _TeamFormAccumulator>{};

    for (final value in _list(raw['recent_league_matches'])) {
      final row = _map(value);
      final leagueId = _integer(_map(row['league'])['id']);
      final team = _map(row['team']);
      final teamId = _integer(team['id']);
      if (leagueId == null || teamId == null) continue;

      final matches = _list(row['matches'])
          .map(_recentMatch)
          .whereType<TeamRecentMatchSnapshot>()
          .toList(growable: false);
      if (matches.isEmpty) continue;

      final leagueName = matches
          .map((match) => match.competitionName?.trim())
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .firstOrNull;
      final accumulator = teams.putIfAbsent(
        teamId,
        () => _TeamFormAccumulator(
          teamId: teamId,
          teamName: _text(team['name']) ?? 'Équipe',
          logoUrl: _text(team['logo']),
        ),
      );
      accumulator.addCompetition(
        leagueId,
        leagueName ?? 'Compétition $leagueId',
      );
      accumulator.addMatches(matches);
    }

    final profiles =
        teams.values
            .map((team) => team.profile())
            .whereType<TeamFormRadarProfile>()
            .toList(growable: false)
          ..sort((left, right) => left.teamName.compareTo(right.teamName));
    return List.unmodifiable(profiles);
  }
}

class _TeamFormAccumulator {
  _TeamFormAccumulator({
    required this.teamId,
    required this.teamName,
    required this.logoUrl,
  });

  final int teamId;
  final String teamName;
  String? logoUrl;
  final Map<int, String> competitions = {};
  final Map<String, TeamRecentMatchSnapshot> matches = {};

  void addCompetition(int id, String name) {
    competitions.putIfAbsent(id, () => name);
  }

  void addMatches(Iterable<TeamRecentMatchSnapshot> values) {
    for (final match in values) {
      logoUrl ??= match.teamLogoUrl;
      final key =
          match.fixtureId?.toString() ??
          '${match.playedAt?.toIso8601String()}:${match.opponentTeamId}:${match.opponentName}';
      matches.putIfAbsent(key, () => match);
    }
  }

  TeamFormRadarProfile? profile() {
    if (competitions.isEmpty || matches.isEmpty) return null;
    final ordered = matches.values.toList()
      ..sort((left, right) {
        final leftDate =
            left.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightDate =
            right.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return leftDate.compareTo(rightDate);
      });
    final activity = ordered.length <= TeamFormRadarRanker.window
        ? ordered
        : ordered.sublist(ordered.length - TeamFormRadarRanker.window);
    final primary = competitions.entries.first;
    return TeamFormRadarProfile(
      teamId: teamId,
      teamName: teamName,
      logoUrl: logoUrl,
      leagueId: primary.key,
      leagueName: competitions.length == 1
          ? primary.value
          : 'Toutes compétitions',
      competitionNames: Map.unmodifiable(competitions),
      activity: List.unmodifiable(activity),
    );
  }
}

TeamRecentMatchSnapshot? _recentMatch(Object? value) {
  final row = _map(value);
  final opponent = _map(row['opponent']);
  final opponentName = _text(opponent['name']) ?? _text(row['opponentName']);
  final result = _text(row['result']);
  final venue = switch (_text(row['venue'])?.toLowerCase()) {
    'home' || 'domicile' || 'd' => RecentMatchVenue.home,
    'away' || 'extérieur' || 'exterieur' || 'e' => RecentMatchVenue.away,
    _ => null,
  };
  if (opponentName == null || result == null || venue == null) return null;

  final fixture = _map(row['fixture']);
  final goals = _map(row['goals']);
  final statistics = _statistics(row['statistics']);
  return TeamRecentMatchSnapshot(
    fixtureId: _integer(fixture['id'] ?? row['fixtureId']),
    playedAt: _date(fixture['date'] ?? row['date']),
    opponentTeamId: _integer(opponent['id'] ?? row['opponentId']),
    opponentName: opponentName,
    opponentLogoUrl: _text(opponent['logo'] ?? row['opponentLogo']),
    venue: venue,
    result: result,
    goalsFor: _integer(goals['for'] ?? row['goalsFor']),
    goalsAgainst: _integer(goals['against'] ?? row['goalsAgainst']),
    competitionName:
        _text(row['competition_name']) ?? _text(row['competitionName']),
    teamLogoUrl: _text(row['team_logo']) ?? _text(row['teamLogo']),
    statistics: statistics,
    events: _list(row['events'])
        .map(_event)
        .whereType<TeamRecentMatchEventSnapshot>()
        .toList(growable: false),
  );
}

TeamRecentMatchStatisticsSnapshot? _statistics(Object? value) {
  final row = _map(value);
  if (row.isEmpty) return null;
  return TeamRecentMatchStatisticsSnapshot(
    shotsFor: _decimal(row['shots_for']),
    shotsAgainst: _decimal(row['shots_against']),
    shotsOnTargetFor: _decimal(row['shots_on_target_for']),
    shotsOnTargetAgainst: _decimal(row['shots_on_target_against']),
    expectedGoalsFor: _decimal(row['expected_goals_for']),
    expectedGoalsAgainst: _decimal(row['expected_goals_against']),
    possessionFor: _decimal(row['possession_for']),
    possessionAgainst: _decimal(row['possession_against']),
  );
}

TeamRecentMatchEventSnapshot? _event(Object? value) {
  final row = _map(value);
  final minute = _integer(row['minute']);
  if (minute == null) return null;
  return TeamRecentMatchEventSnapshot(
    minute: minute,
    teamId: _integer(row['team_id']),
    teamName: _text(row['team_name']),
    playerName: _text(row['player_name']),
  );
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
  return const {};
}

List<Object?> _list(Object? value) => value is List ? value : const [];

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _date(Object? value) => DateTime.tryParse(value?.toString() ?? '');
