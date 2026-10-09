import '../../../core/identity/identity_scope.dart';

/// Exact membership from the native Radar rankers, across every Top 50 page.
/// No prices or unverified statistics are accepted from this read scope.
class RadarScope {
  const RadarScope({
    required this.mode,
    required this.category,
    required this.capturedAt,
    required this.sourceIds,
    required this.teams,
    required this.players,
    this.includeWomen = false,
    this.includeYouth = false,
    this.competitionId,
  });
  final String mode, category;
  final DateTime? capturedAt;
  final List<String> sourceIds;
  final List<RadarMember> teams, players;
  final bool includeWomen, includeYouth;
  final String? competitionId;
  Map<String, Object?> toJson() => {
    'version': 1,
    'mode': mode,
    'category': category,
    'capturedAt': capturedAt?.toUtc().toIso8601String(),
    'sourceIds': sourceIds,
    'includeWomen': includeWomen,
    'includeYouth': includeYouth,
    'competitionId': competitionId,
    'teams': teams.map((m) => m.toJson()).toList(),
    'players': players.map((m) => m.toJson()).toList(),
  };
}

class RadarMember {
  const RadarMember({
    required this.id,
    required this.teamId,
    required this.rank,
    required this.matchIds,
  });
  final String id, teamId;
  final int rank;
  final List<String> matchIds;
  Map<String, Object?> toJson() => {
    'id': id,
    'teamId': teamId,
    'rank': rank,
    'matchIds': matchIds,
  };
}

/// Preserve the actual Radar controls while navigating to the Generator.
/// Public scopes are bounded and separated by account, sport and calendar day.
abstract final class RadarScopeSession {
  static final _values = <String, RadarScope>{};
  static void clear() => _values.clear();
  static String _key(IdentityScope owner, String sport, DateTime day) =>
      '${owner.stableKey}:$sport:${day.year}-${day.month}-${day.day}';
  static RadarScope? read(IdentityScope owner, String sport, DateTime day) =>
      _values[_key(owner, sport, day)];
  static void remember(
    IdentityScope owner,
    String sport,
    DateTime day,
    RadarScope scope,
  ) {
    final key = _key(owner, sport, day);
    _values.remove(key);
    _values[key] = scope;
    while (_values.length > 24) {
      _values.remove(_values.keys.first);
    }
  }
}
