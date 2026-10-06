import 'sport.dart';
import 'sport_fixture.dart';
import 'sport_competition_context.dart';

/// Factual player contributions; unknown appearance/minutes remain unknown.
class SportPlayerMatchActivity {
  const SportPlayerMatchActivity({
    required this.result,
    required this.goals,
    required this.assists,
  });
  final SportFormResult result;
  final int? goals, assists;
  bool get contributionsKnown => goals != null && assists != null;
  int? get contributions => contributionsKnown ? goals! + assists! : null;
}

class SportPlayerProfile {
  SportPlayerProfile({
    required this.id,
    required this.name,
    required this.competition,
    required this.season,
    required this.team,
    required this.identitySource,
    required Iterable<SportPlayerMatchActivity> activity,
  }) : activity = List.unmodifiable(activity);
  final SportEntityId id, competition;
  final String name, season, identitySource;
  final SportParticipant team;
  final List<SportPlayerMatchActivity> activity;
}

class SportPlayerRadarCoverage {
  const SportPlayerRadarCoverage({
    required this.competition,
    required this.team,
    required this.status,
    this.history,
  });
  final SportEntityId competition, team;
  final String status;
  final List<SportFormResult>? history;
}
