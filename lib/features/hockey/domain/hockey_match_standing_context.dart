import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_competition_context.dart';
import 'hockey_standing_view.dart';

enum HockeyStandingRelation {
  sameDivision,
  sameConference,
  differentConferences,
  sameGroup,
  differentGroups,
  unavailable,
}

/// Resolves genuine provider memberships, independently of rank or points.
/// Never builds a synthetic official league ranking from local positions.
class HockeyMatchStandingContext {
  const HockeyMatchStandingContext(this.competition, this.teams);
  final SportCompetitionContext competition;
  final List<SportEntityId> teams;

  int? groupFor(SportEntityId team, SportStandingGroupKind kind) {
    final groups =
        competition.standingContext?.groups
            .where(
              (g) =>
                  g.kind == kind &&
                  competition.tables[g.tableIndex].rows.any(
                    (r) => r.team.id == team,
                  ),
            )
            .toList() ??
        [];
    // Multiple memberships at the same level are ambiguous, not comparable.
    return groups.length == 1 ? groups.single.tableIndex : null;
  }

  List<int> groupsAt(SportStandingGroupKind kind) => {
    for (final team in teams)
      if (groupFor(team, kind) case final int group) group,
  }.toList();

  List<int> get localGroups => {
    for (final team in teams)
      if (HockeyStandingView.localGroup(competition, team) case final int group)
        group,
  }.toList();
  List<int> get divisions => groupsAt(SportStandingGroupKind.division);
  List<int> get conferences => groupsAt(SportStandingGroupKind.conference);

  bool completeLevel(SportStandingGroupKind kind) =>
      teams.length == 2 && teams.every((t) => groupFor(t, kind) != null);

  HockeyStandingRelation get relation {
    if (teams.length != 2 ||
        localGroups.isEmpty ||
        teams.any(
          (t) => HockeyStandingView.localGroup(competition, t) == null,
        )) {
      return HockeyStandingRelation.unavailable;
    }
    if (completeLevel(SportStandingGroupKind.division) &&
        divisions.length == 1) {
      return HockeyStandingRelation.sameDivision;
    }
    if (completeLevel(SportStandingGroupKind.conference)) {
      return conferences.length == 1
          ? HockeyStandingRelation.sameConference
          : HockeyStandingRelation.differentConferences;
    }
    return localGroups.length == 1
        ? HockeyStandingRelation.sameGroup
        : HockeyStandingRelation.differentGroups;
  }

  List<int> get primaryGroups => switch (relation) {
    HockeyStandingRelation.sameDivision => divisions,
    HockeyStandingRelation.sameConference ||
    HockeyStandingRelation.differentConferences => conferences,
    _ => localGroups,
  };

  String get description => switch (relation) {
    HockeyStandingRelation.sameDivision => 'Même division · classement commun',
    HockeyStandingRelation.sameConference =>
      completeLevel(SportStandingGroupKind.division)
          ? 'Divisions différentes · conférence commune'
          : 'Conférence commune',
    HockeyStandingRelation.differentConferences =>
      'Conférences différentes · deux classements distincts',
    HockeyStandingRelation.sameGroup => 'Même groupe · classement commun',
    HockeyStandingRelation.differentGroups => 'Deux groupes différents',
    HockeyStandingRelation.unavailable =>
      'Appartenance des équipes indisponible',
  };

  SportStandingRow? row(SportEntityId team, int scope, {int? group}) {
    final index = group ?? HockeyStandingView.localGroup(competition, team);
    return index == null
        ? null
        : HockeyStandingView.rows(
            competition,
            index,
            scope,
          ).where((r) => r.team.id == team).firstOrNull;
  }

  double? pointsPerGameGap(int scope) {
    if (teams.length != 2) return null;
    final a = row(teams[0], scope), b = row(teams[1], scope);
    if (a == null || b == null || a.played == 0 || b.played == 0) return null;
    return a.pointsPerGame - b.pointsPerGame;
  }

  /// Descriptive comparison only. Automatic readings retain their own policies.
  String commonFacts(int scope) {
    final gap = pointsPerGameGap(scope);
    if (gap == null) {
      return 'Écart indisponible : bilans incomplets ou aucun match joué.';
    }
    final a = row(teams[0], scope)!, b = row(teams[1], scope)!;
    final pace = gap.abs() < .005
        ? 'Même rendement en points par match.'
        : '${gap > 0 ? a.team.name : b.team.name} : +${gap.abs().toStringAsFixed(2).replaceAll('.', ',')} pt/match.';
    return a.played == b.played
        ? pace
        : '$pace Matchs joués : ${a.played} et ${b.played} ; les points cumulés seuls ne sont pas comparables.';
  }

  /// Descriptive comparison only. Automatic readings retain their own policies.
  String interpretation(int scope) {
    final gap = pointsPerGameGap(scope);
    if (gap == null) {
      return 'Pas encore de bilans complets pour comparer les deux équipes dans ce périmètre.';
    }
    final a = row(teams[0], scope)!, b = row(teams[1], scope)!;
    final winner = gap > 0 ? a : b;
    final pace = gap.abs() < .005
        ? 'Les deux équipes ont le même rendement comptable.'
        : '${winner.team.name} présente un meilleur rendement comptable : +${gap.abs().toStringAsFixed(2).replaceAll('.', ',')} point par match.';
    final reverse =
        localGroups.length == 2 &&
            gap.abs() >= .005 &&
            winner.rank > (gap > 0 ? b : a).rank
        ? ' Son rang local est pourtant inférieur à celui de son adversaire ; les rangs de deux groupes ne mesurent pas un écart de niveau.'
        : '';
    final sample = a.played < 5 || b.played < 5
        ? ' Saison encore peu avancée : échantillon inférieur à cinq matchs.'
        : '';
    return '$pace$reverse$sample Les points par match corrigent le nombre de rencontres, mais pas la difficulté du calendrier. Ils ne suffisent pas à désigner l’équipe la plus forte.';
  }
}
