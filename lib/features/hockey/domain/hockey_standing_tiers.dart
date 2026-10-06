import '../../../core/domain/structural_tiers/competition_structural_metadata.dart';
import '../../../core/domain/structural_tiers/dynamic_tier_algorithm_v1.dart';
import '../../../core/domain/structural_tiers/tier_input.dart';
import '../../../core/domain/structural_tiers/tier_models.dart';
import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_competition_context.dart';

/// Analytical Lector bands. Official ranks, qualification and relegation stay
/// separate. The partition kernel is the SAME one used by football.
abstract final class HockeyStandingTiers {
  static const version = 'hockey-standing-tiers-v1';
  static const minimumPlayed = 5;
  static const supportedLeagues = {'57', '58', '35', '10', '18', '16', '47'};
  static const labels = {
    1: 'Tête du groupe',
    2: 'Haut de tableau',
    3: 'Milieu de tableau',
    4: 'Bas de tableau',
    5: 'Fin du groupe',
  };

  static HockeyTierClassification classify(
    SportStandingTable table, {
    SportCompetitionContext? competition,
    int scope = 0,
  }) {
    HockeyTierClassification unavailable(String reason) =>
        HockeyTierClassification(tiers: const {}, reason: reason);
    if (competition != null &&
        (competition.id.sport != SportId.hockey ||
            competition.id.provider != 'api-hockey' ||
            competition.season != '2026' ||
            !supportedLeagues.contains(competition.id.value))) {
      return unavailable(
        'Politique de tiers non disponible pour cette compétition et cette saison.',
      );
    }
    if (!table.stage.toLowerCase().contains('regular season')) {
      return unavailable(
        'Les tiers concernent uniquement la saison régulière.',
      );
    }
    final rows = [...table.rows]..sort((a, b) => a.rank.compareTo(b.rank));
    final n = rows.length;
    if (n < 4 ||
        n > 32 ||
        rows.map((r) => r.team.id).toSet().length != n ||
        rows.any((r) => r.played < minimumPlayed || r.points < 0)) {
      return unavailable(
        'Il faut un classement complet et au moins 5 matchs par équipe dans ce périmètre.',
      );
    }
    for (var i = 0; i < n; i++) {
      if (rows[i].team.id.sport != SportId.hockey ||
          rows[i].rank < 1 ||
          rows[i].rank > n ||
          (i > 0 &&
              (rows[i].rank < rows[i - 1].rank ||
                  rows[i].points > rows[i - 1].points)) ||
          (scope == 0 && rows[i].rank != i + 1)) {
        return unavailable('Positions officielles ou points incohérents.');
      }
    }
    // Lector podium anchor: three leaders for >=8 teams, two for 5–7, one
    // for four. Bottom anchor: two teams for >=6, one otherwise. No playoff
    // or relegation rule is inferred from these analytical reference groups.
    var top = n >= 8
        ? 3
        : n >= 5
        ? 2
        : 1;
    var bottom = n - (n >= 6 ? 2 : 1);
    while (top < n && rows[top - 1].points == rows[top].points) {
      top++;
    }
    while (bottom > 0 && rows[bottom - 1].points == rows[bottom].points) {
      bottom--;
    }
    if (top > bottom) {
      return unavailable(
        'Les égalités de points ne permettent pas de séparer les groupes de tête et de fin.',
      );
    }
    final snapshot = const DynamicTierAlgorithmV1().buildSnapshot(
      DynamicTierInput(
        competitionId: competition?.id.key ?? table.group,
        season: int.tryParse(competition?.season ?? '') ?? 2026,
        analysisAsOf:
            competition?.standingContext?.collectedAt ?? DateTime.utc(2026),
        competitionFormat: CompetitionFormat.groupedCompetition,
        supportedFormats: const {CompetitionFormat.groupedCompetition},
        minimumTeams: 4,
        maximumTeams: 32,
        standingsRows: [
          for (final (i, row) in rows.indexed)
            DynamicTierInputStanding(
              teamId: i,
              teamName: row.team.name,
              officialRank: i + 1,
              points: row.points,
              played: row.played,
              group: table.group,
            ),
        ],
        podiumAnchor: CompetitionStructuralAnchor(
          startRank: 1,
          endRank: top,
          source: StructuralAnchorSource.lectorOverride,
        ),
        relegationAnchor: CompetitionStructuralAnchor(
          startRank: bottom + 1,
          endRank: n,
          source: StructuralAnchorSource.lectorOverride,
        ),
        anchorMetadataVersion: version,
        competitionFormatVersion: version,
        structuralMetadataVersion: version,
      ),
    );
    if (snapshot.teamAssignments.isEmpty) {
      return unavailable(
        'Échantillon ou écart de matchs joués insuffisant pour établir les tiers.',
      );
    }
    return HockeyTierClassification(
      structuralRanks: Map.unmodifiable({
        for (final subject in snapshot.teamAssignments)
          subject.officialRank: Set.unmodifiable({
            for (final opponent in snapshot.teamAssignments)
              if (const DynamicTierAlgorithmV1()
                  .deriveStructuralLevelGap(
                    snapshot,
                    subjectTeamId: subject.teamId,
                    opponentTeamId: opponent.teamId,
                  )
                  .exists)
                opponent.officialRank,
          }),
      }),
      tiers: Map.unmodifiable({
        for (final assignment in snapshot.teamAssignments)
          rows[assignment.teamId].team.id.key: assignment.assignedTier.ordinal,
      }),
    );
  }
}

class HockeyTierClassification {
  const HockeyTierClassification({
    required this.tiers,
    this.reason,
    this.structuralRanks = const {},
  });
  final Map<String, int> tiers;
  final String? reason;
  final Map<int, Set<int>> structuralRanks;
  bool get available => tiers.isNotEmpty;
}
