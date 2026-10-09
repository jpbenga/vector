/// A server-recorded Radar publication, strictly older than the kickoff.
class LectorRecordedRadar {
  const LectorRecordedRadar({
    required this.sport,
    required this.fixtureId,
    required this.kickoffAt,
    required this.capturedAt,
    required this.players,
  });
  final String sport, fixtureId;
  final DateTime kickoffAt, capturedAt;
  final List<LectorRecordedRadarPlayer> players;
  static LectorRecordedRadar? parse(
    Object? raw,
    String sport,
    String fixtureId,
  ) {
    if (raw is! Map<String, dynamic> ||
        raw['sport'] != sport ||
        raw['fixtureId'] != fixtureId) {
      return null;
    }
    final kickoff = DateTime.tryParse('${raw['kickoffAt']}');
    final at = DateTime.tryParse('${raw['capturedAt']}');
    final recorded = DateTime.tryParse('${raw['recordedAt']}');
    if (kickoff == null ||
        at == null ||
        recorded == null ||
        !at.isBefore(kickoff) ||
        !recorded.isBefore(kickoff)) {
      return null;
    }
    try {
      final profiles = (raw['profiles'] as List).cast<Map<String, dynamic>>();
      final players = profiles
          .map((p) => LectorRecordedRadarPlayer.parse(p, sport))
          .toList();
      if (players.any(
            (p) =>
                p.activity.length < 3 ||
                p.activity.any(
                  (a) => !a.playedAt.isBefore(at) || a.matchId == fixtureId,
                ) ||
                p.recentContributions < 2,
          ) ||
          players.map((p) => '${p.teamId}:${p.id}').toSet().length !=
              players.length) {
        return null;
      }
      players.sort((a, b) {
        var d = b.recentDecisive.compareTo(a.recentDecisive);
        if (d == 0) d = b.streak.compareTo(a.streak);
        if (d == 0) d = b.recentContributions.compareTo(a.recentContributions);
        return d == 0 ? a.name.compareTo(b.name) : d;
      });
      return LectorRecordedRadar(
        sport: sport,
        fixtureId: fixtureId,
        kickoffAt: kickoff,
        capturedAt: at,
        players: players,
      );
    } on Object {
      return null;
    }
  }
}

class LectorRecordedRadarPlayer {
  const LectorRecordedRadarPlayer({
    required this.id,
    required this.name,
    required this.teamId,
    required this.teamName,
    required this.activity,
    this.photoUrl,
    this.teamLogoUrl,
  });
  final String id, name, teamId, teamName;
  final String? photoUrl, teamLogoUrl;
  final List<LectorRecordedRadarActivity> activity;
  int get recentContributions => activity
      .skip(activity.length - 3)
      .fold(0, (v, a) => v + (a.contributions ?? 0));
  int get recentDecisive => activity
      .skip(activity.length - 3)
      .where((a) => (a.contributions ?? 0) > 0)
      .length;
  int get streak =>
      activity.reversed.takeWhile((a) => (a.contributions ?? 0) > 0).length;
  factory LectorRecordedRadarPlayer.parse(
    Map<String, dynamic> p,
    String sport,
  ) {
    final football = sport == 'football';
    final player = football ? p['player'] as Map : p;
    final team = p['team'] as Map;
    final activity = (p['activity'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (a) => LectorRecordedRadarActivity(
            matchId: '${a[football ? 'fixture_id' : 'id']}',
            playedAt: DateTime.parse(
              '${a[football ? 'played_at' : 'startsAt']}',
            ),
            contributions: a['goals'] == null || a['assists'] == null
                ? null
                : (a['goals'] as num).toInt() + (a['assists'] as num).toInt(),
            appeared: football ? a['appeared'] as bool? : null,
            substitute: football && a['substitute'] == true,
          ),
        )
        .toList();
    if (activity
        .skip(activity.length - 3)
        .any((a) => a.contributions == null)) {
      throw const FormatException('Incomplete recent Radar');
    }
    return LectorRecordedRadarPlayer(
      id: '${player['id']}',
      name: player['name'] as String,
      teamId: '${team['id']}',
      teamName: team['name'] as String,
      photoUrl: player['photo'] as String?,
      teamLogoUrl: team[football ? 'logo' : 'logoUrl'] as String?,
      activity: activity,
    );
  }
}

class LectorRecordedRadarActivity {
  const LectorRecordedRadarActivity({
    required this.matchId,
    required this.playedAt,
    required this.contributions,
    this.appeared,
    this.substitute = false,
  });
  final String matchId;
  final DateTime playedAt;
  final int? contributions;
  final bool? appeared;
  final bool substitute;
}

class LectorRadarContribution {
  const LectorRadarContribution({required this.playerId, required this.label});
  final String playerId, label;
}
