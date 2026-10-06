import 'sport.dart';
import 'sport_fixture.dart';

/// Factual inputs for presentation; points rules and tier policies stay in modules.
enum SportFormOutcome { win, loss, draw }

class SportFormResult {
  const SportFormResult({
    required this.matchId,
    required this.startsAt,
    required this.opponent,
    required this.home,
    required this.scored,
    required this.conceded,
    required this.outcome,
    required this.providerStatus,
  });
  final SportEntityId matchId;
  final DateTime startsAt;
  final String opponent;
  final bool home;
  final int scored, conceded;
  final SportFormOutcome outcome;
  final String providerStatus;
}

class SportStandingRow {
  SportStandingRow({
    required this.team,
    required this.rank,
    required this.played,
    required this.points,
    required this.wins,
    this.overtimeWins,
    required this.losses,
    this.overtimeLosses,
    this.goalsFor,
    this.goalsAgainst,
    this.description,
    Iterable<SportFormResult> form = const [],
    Iterable<SportFormResult>? formHistory,
  }) : form = List.unmodifiable(form),
       formHistory = List.unmodifiable(formHistory ?? form);
  final SportParticipant team;
  final int rank, played, points, wins, losses;
  final int? overtimeWins, overtimeLosses;
  final int? goalsFor, goalsAgainst;
  final String? description;
  final List<SportFormResult> form;

  /// Completed season history; [form] remains the latest five results.
  final List<SportFormResult> formHistory;
  double get pointsPerGame => played == 0 ? 0 : points / played;
}

class SportStandingTable {
  SportStandingTable({
    required this.stage,
    required this.group,
    required Iterable<SportStandingRow> rows,
  }) : rows = List.unmodifiable(rows);
  final String stage, group;
  final List<SportStandingRow> rows;
}

class SportCompetitionContext {
  SportCompetitionContext({
    required this.id,
    required this.name,
    required this.season,
    required this.country,
    required this.formPhaseVerified,
    this.logoUrl,
    this.countryCode,
    this.countryFlagUrl,
    this.venueStandings,
    this.standingContext,
    required Iterable<SportStandingTable> tables,
  }) : tables = List.unmodifiable(tables);
  final SportEntityId id;
  final String name, season, country;
  final String? logoUrl, countryCode, countryFlagUrl;
  final bool formPhaseVerified;
  final SportVenueStandings? venueStandings;
  final SportStandingContext? standingContext;
  final List<SportStandingTable> tables;
}

/// Provider venue aggregates, distinct from official standings points.
class SportVenueStandingRow {
  const SportVenueStandingRow({
    required this.team,
    required this.rank,
    required this.played,
    required this.wins,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    this.points,
    this.overtimeWins,
    this.overtimeLosses,
  });
  final SportParticipant team;
  final int rank, played, wins, losses, goalsFor, goalsAgainst;
  final int? points, overtimeWins, overtimeLosses;
  double? get winRate => played == 0 ? null : wins / played;
}

class SportVenueStandings {
  SportVenueStandings({
    required this.collectedAt,
    required Iterable<SportVenueStandingRow> home,
    required Iterable<SportVenueStandingRow> away,
    required Iterable<String> unavailableTeams,
    this.source,
    this.status,
    this.phase,
  }) : home = List.unmodifiable(home),
       away = List.unmodifiable(away),
       unavailableTeams = List.unmodifiable(unavailableTeams);
  final DateTime collectedAt;
  final List<SportVenueStandingRow> home, away;
  final List<String> unavailableTeams;
  final String? source, status, phase;
  bool get hasCalculatedPoints =>
      source == 'season-games' && status != 'unsupported';
}

/// Factual performance against teams outside an official group.
class SportGroupResults {
  const SportGroupResults({
    required this.played,
    required this.points,
    required this.goalsFor,
    required this.goalsAgainst,
  });
  final int played, points, goalsFor, goalsAgainst;
  double? share(int maximumPoints) =>
      played == 0 ? null : points / (played * maximumPoints);
}

enum SportStandingGroupKind { league, conference, division }

class SportStandingGroupContext {
  const SportStandingGroupContext({
    required this.tableIndex,
    required this.kind,
    this.parentTableIndex,
    this.all,
    this.home,
    this.away,
  });
  final int tableIndex;
  final SportStandingGroupKind kind;
  final int? parentTableIndex;
  final SportGroupResults? all, home, away;
  SportGroupResults? forScope(int scope) => scope == 1
      ? home
      : scope == 2
      ? away
      : all;
}

class SportStandingContext {
  SportStandingContext({
    required this.phase,
    required this.collectedAt,
    required this.maximumPoints,
    required Iterable<SportStandingGroupContext> groups,
  }) : groups = List.unmodifiable(groups);
  final String phase;
  final DateTime collectedAt;
  final int? maximumPoints;
  final List<SportStandingGroupContext> groups;
}
