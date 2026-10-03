import '../../onboarding/domain/decision_profile_catalogs.dart';
import '../data/match_reading_bilan_repository.dart';

/// Combines server counts, never percentages. One match may carry several
/// announcements; these are reading occurrences, not independent matches.
MatchReadingBilanSummary combineBilanSummaries(
  Iterable<MatchReadingBilanSummary> summaries, {
  required String id,
  required String label,
}) {
  final rows = summaries.toList(growable: false);
  int sum(int Function(MatchReadingBilanSummary) value) =>
      rows.fold(0, (total, row) => total + value(row));
  return MatchReadingBilanSummary(
    readingId: id,
    readingLabel: label,
    total: sum((row) => row.total),
    confirmed: sum((row) => row.confirmed),
    contradicted: sum((row) => row.contradicted),
    notEvaluable: sum((row) => row.notEvaluable),
    contextOnly: sum((row) => row.contextOnly),
    pending: sum((row) => row.pending),
    homeEvaluable: sum((row) => row.homeEvaluable),
    homeConfirmed: sum((row) => row.homeConfirmed),
    awayEvaluable: sum((row) => row.awayEvaluable),
    awayConfirmed: sum((row) => row.awayConfirmed),
    outcomeRules: {for (final row in rows) ...row.outcomeRules}.toList(),
  );
}

String bilanCompetitionName(int? leagueId, String? name) {
  if (name != null && name.trim().isNotEmpty) return name;
  for (final competition in RuntimeCompetitionCatalog.values) {
    if (competition.apiFootballLeagueId == leagueId) return competition.name;
  }
  return 'Compétition non renseignée';
}

String bilanOutcomeRuleText(String? rule) => switch (rule) {
  'over_25' => 'Au moins trois buts dans le match.',
  'under_25' => 'Au plus deux buts dans le match.',
  'btts' => 'Les deux équipes marquent.',
  'team_win' => 'L’équipe concernée remporte le match.',
  'team_not_lose' => 'L’équipe concernée gagne ou fait match nul.',
  'team_loss' => 'L’équipe concernée perd le match.',
  'team_scores' => 'L’équipe concernée marque au moins un but.',
  'team_no_score' => 'L’équipe concernée ne marque pas.',
  'team_clean_sheet' => 'L’équipe concernée ne concède aucun but.',
  'team_concedes' => 'L’équipe concernée concède au moins un but.',
  'first_half_scores' => 'L’équipe concernée marque en première mi-temps.',
  'first_half_concedes' => 'L’équipe concernée encaisse en première mi-temps.',
  'second_half_scores' => 'L’équipe concernée marque en seconde mi-temps.',
  'second_half_concedes' => 'L’équipe concernée encaisse en seconde mi-temps.',
  'player_decisive' =>
    'Le joueur concerné marque ou délivre une passe décisive.',
  _ =>
    'Constat d’avant-match : aucune règle de résultat ne permet de le valider.',
};
