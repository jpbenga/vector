import 'match_board_item.dart';

/// Versioned, pre-kickoff dossier produced from the server's published sources.
/// The UI never replaces a historical standing with today's table.
class EuropeanFixtureComparison {
  EuropeanFixtureComparison({
    required this.fixtureId,
    required this.kickoffAt,
    required this.home,
    required this.away,
    required this.json,
  });
  final int fixtureId;
  final DateTime kickoffAt;
  final EuropeanTeamContext home, away;
  final Map<String, Object?> json;
  List<Map<String, Object?>> get notices => _rows(json['notices']);
  List<String> get limitations =>
      (_map(json['dataQuality'])['limitations'] as List? ?? [])
          .map((v) => '$v')
          .toList();
  bool get stale => _map(json['dataQuality'])['stale'] == true;
  DateTime? get capturedAt =>
      DateTime.tryParse('${_map(json['dataQuality'])['capturedAt'] ?? ''}');
  Map<String, Object?>? get firstLeg =>
      json['firstLeg'] is Map ? _map(json['firstLeg']) : null;
  List<HeadToHeadFixtureSnapshot> get headToHead => _rows(json['headToHead'])
      .where(
        (m) =>
            DateTime.tryParse(
              '${_map(m['fixture'])['date']}',
            )?.isBefore(kickoffAt) ==
            true,
      )
      .map((m) {
        final teams = _map(m['teams']),
            h = _map(teams['home']),
            a = _map(teams['away']),
            g = _map(m['goals']),
            f = _map(m['fixture']),
            l = _map(m['league']);
        return HeadToHeadFixtureSnapshot(
          playedAt: DateTime.parse('${f['date']}'),
          fixtureId: _int(f['id']),
          competitionId: _int(l['id']) ?? 0,
          competitionName: l['name']?.toString() ?? 'Compétition',
          homeTeamId: _int(h['id'])!,
          homeTeamName: '${h['name']}',
          awayTeamId: _int(a['id'])!,
          awayTeamName: '${a['name']}',
          homeGoals: _int(g['home'])!,
          awayGoals: _int(g['away'])!,
        );
      })
      .toList();
  static EuropeanFixtureComparison? decode(Object? value) {
    final j = _map(value),
        id = _int(j['fixtureId']),
        kickoff = DateTime.tryParse('${j['kickoffAt'] ?? ''}');
    if (j['schemaVersion'] != 1 || id == null || kickoff == null) return null;
    final home = EuropeanTeamContext.decode(_map(j['home']), kickoff),
        away = EuropeanTeamContext.decode(_map(j['away']), kickoff);
    if (home == null || away == null) return null;
    return EuropeanFixtureComparison(
      fixtureId: id,
      kickoffAt: kickoff,
      home: home,
      away: away,
      json: Map.unmodifiable(j),
    );
  }

  static EuropeanFixtureComparison unavailable(
    NormalizedFixture f,
  ) => EuropeanFixtureComparison(
    fixtureId: f.apiFootballFixtureId ?? 0,
    kickoffAt: f.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0),
    home: EuropeanTeamContext.missing(f.homeTeam),
    away: EuropeanTeamContext.missing(f.awayTeam),
    json: const {
      'notices': [],
      'dataQuality': {
        'limitations': [
          'Le dossier de parcours n’est pas encore disponible dans cette publication. Actualisez la fiche après la prochaine collecte.',
        ],
      },
    },
  );
}

/// Lightweight card projection of results in the fixture’s European competition.
/// Domestic form and complete journeys remain in the individual detail payload.
class EuropeanMatchCardFormContext {
  const EuropeanMatchCardFormContext({
    required this.fixtureId,
    required this.kickoffAt,
    required this.home,
    required this.away,
  });
  final int fixtureId;
  final DateTime kickoffAt;
  final EuropeanTeamContext home, away;
  static EuropeanMatchCardFormContext? decode(Object? value) {
    final j = _map(value), id = _int(j['fixtureId']);
    final kickoff = DateTime.tryParse('${j['kickoffAt'] ?? ''}');
    if (j['schemaVersion'] != 1 ||
        id == null ||
        kickoff == null ||
        _map(j['home'])['europeanRecentMatches'] is! List ||
        _map(j['away'])['europeanRecentMatches'] is! List) {
      return null;
    }
    final home = EuropeanTeamContext.decode(_map(j['home']), kickoff);
    final away = EuropeanTeamContext.decode(_map(j['away']), kickoff);
    if (home == null || away == null) return null;
    return EuropeanMatchCardFormContext(
      fixtureId: id,
      kickoffAt: kickoff,
      home: home,
      away: away,
    );
  }
}

class EuropeanTeamContext {
  const EuropeanTeamContext({
    required this.team,
    required this.domesticMatches,
    required this.europeanMatches,
    required this.phaseMatches,
    required this.json,
    this.domesticCompetition,
    this.domesticStanding,
    this.europeanStanding,
  });
  final TeamInfo team;
  final CompetitionInfo? domesticCompetition;
  final TeamStandingSnapshot? domesticStanding, europeanStanding;
  final List<TeamRecentMatchSnapshot> domesticMatches,
      europeanMatches,
      phaseMatches;
  final Map<String, Object?> json;
  bool get europeanCoverageComplete => json['europeanCoverageComplete'] == true;
  String get phase => '${json['europeanPhase'] ?? 'unknown'}';
  Map<String, Object?>? get domesticSummary =>
      json['domesticSummary'] is Map ? _map(json['domesticSummary']) : null;
  Map<String, Object?>? get europeanSummary =>
      json['europeanSummary'] is Map ? _map(json['europeanSummary']) : null;
  String get domesticState => '${json['domesticState'] ?? 'missing'}';
  DateTime? get observedAt =>
      DateTime.tryParse('${json['europeanObservedAt'] ?? ''}');
  static EuropeanTeamContext missing(TeamInfo team) => EuropeanTeamContext(
    team: team,
    domesticMatches: const [],
    europeanMatches: const [],
    phaseMatches: const [],
    json: const {},
  );
  static EuropeanTeamContext? decode(Map<String, Object?> j, DateTime cutoff) {
    final id = _int(j['teamId']);
    if (id == null) return null;
    final d = _map(j['domesticCompetition']),
        domesticId = _int(d['id']),
        season = _int(d['season']);
    final competition = domesticId == null || season == null
        ? null
        : CompetitionInfo(
            id: '$domesticId',
            apiFootballLeagueId: domesticId,
            name: '${d['name']}',
            season: season,
            logoUrl: d['logo']?.toString(),
            country: CountryInfo(code: '', name: '${d['country'] ?? ''}'),
          );
    return EuropeanTeamContext(
      team: TeamInfo(
        id: '$id',
        apiFootballTeamId: id,
        name: '${j['name']}',
        logoUrl: j['logo']?.toString(),
      ),
      domesticCompetition: competition,
      domesticStanding: _standing(j['domesticStanding'], cutoff),
      europeanStanding: _standing(j['europeanStanding'], cutoff),
      domesticMatches: _matches(j['domesticRecentMatches'], cutoff),
      europeanMatches: _matches(j['europeanRecentMatches'], cutoff),
      phaseMatches: _matches(j['europeanPhaseMatches'], cutoff),
      json: Map.unmodifiable(j),
    );
  }
}

Map<String, Object?> _map(Object? v) =>
    v is Map ? Map<String, Object?>.from(v) : {};
List<Map<String, Object?>> _rows(Object? v) =>
    v is List ? v.map(_map).toList() : [];
int? _int(Object? v) => v is num ? v.toInt() : null;
TeamStandingSnapshot? _standing(Object? v, DateTime cutoff) {
  final s = _map(v),
      observed = DateTime.tryParse('${s['observedAt'] ?? ''}'),
      id = _int(s['teamId']);
  if (id == null || observed == null || !observed.isBefore(cutoff)) return null;
  return TeamStandingSnapshot(
    teamId: id,
    teamName: '${s['teamName']}',
    rank: _int(s['rank']),
    points: _int(s['points']),
    played: _int(s['played']),
    wins: _int(s['wins']),
    draws: _int(s['draws']),
    losses: _int(s['losses']),
    goalsFor: _int(s['goalsFor']),
    goalsAgainst: _int(s['goalsAgainst']),
    goalDiff: _int(s['goalDiff']),
    group: s['group']?.toString(),
  );
}

List<TeamRecentMatchSnapshot> _matches(Object? v, DateTime cutoff) {
  final result = <int, TeamRecentMatchSnapshot>{};
  for (final m in _rows(v)) {
    final id = _int(m['fixtureId']),
        d = DateTime.tryParse('${m['playedAt'] ?? ''}'),
        gf = _int(m['goalsFor']),
        ga = _int(m['goalsAgainst']);
    if (id == null ||
        d == null ||
        !d.isBefore(cutoff) ||
        gf == null ||
        ga == null) {
      continue;
    }
    result[id] = TeamRecentMatchSnapshot(
      fixtureId: id,
      competitionId: _int(m['competitionId']),
      season: _int(m['season']),
      round: m['round']?.toString(),
      penaltyDecision: m['penaltyDecision'] == true,
      opponentTeamId: _int(m['opponentTeamId']),
      opponentName: '${m['opponentName']}',
      opponentLogoUrl: m['opponentLogo']?.toString(),
      competitionName: m['competitionName']?.toString(),
      venue: m['venue'] == 'home'
          ? RecentMatchVenue.home
          : RecentMatchVenue.away,
      result:
          m['penaltyDecision'] == true &&
              const ['W', 'D', 'L'].contains(m['result'])
          ? '${m['result']}'
          : gf > ga
          ? 'W'
          : gf == ga
          ? 'D'
          : 'L',
      goalsFor: gf,
      goalsAgainst: ga,
      playedAt: d,
    );
  }
  return List.unmodifiable(
    result.values.toList()..sort((a, b) => a.playedAt!.compareTo(b.playedAt!)),
  );
}
