import '../../../../core/widgets/lector_live_badge.dart';
import '../../../../core/widgets/lector_compact_match_card.dart';
import '../../../../core/widgets/lector_match_supplement.dart';
import '../../../../core/domain/compact_match_data.dart';
import '../compact_football_match_adapter.dart';
import '../../../shortlist/presentation/shortlist_actions.dart';
import '../../../../core/widgets/lector_recorded_radar_panel.dart';
import '../../../../core/domain/lector_radar_contributions.dart';
import '../../../../core/domain/lector_recorded_radar.dart';
import '../../../../core/widgets/lector_reading_pill.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_components.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../form_radar/data/player_form_radar_fixture.dart';
import '../../../form_radar/domain/player_form_radar.dart';
import '../../../form_radar/presentation/form_radar_signal_panel.dart';
import '../../../onboarding/domain/decision_profile_catalogs.dart';
import '../../domain/match_board_item.dart';
import '../../domain/live_match_state.dart';
import 'live_fixture_builder.dart';
import 'live_match_status.dart';

class MatchCardReading {
  const MatchCardReading({required this.id, required this.label});

  final String id;
  final String label;
}

class MatchCardScenario {
  const MatchCardScenario({required this.label, required this.summary});

  final String label;
  final String summary;
}

class MatchFeedCard extends StatelessWidget {
  const MatchFeedCard({
    required this.match,
    required this.onTap,
    this.showCompetitionHeader = true,
    this.showReadings = true,
    this.readingMatch,
    this.radarEntries,
    this.liveState,
    super.key,
  });
  final MatchBoardItem match;
  final VoidCallback onTap;
  final bool showCompetitionHeader;
  final bool showReadings;
  final MatchBoardItem? readingMatch;
  final List<PlayerFormRadarEntry>? radarEntries;

  /// Explicit state for the local preview and regression tests.
  final LiveMatchState? liveState;
  @override
  Widget build(BuildContext context) => LiveFixtureBuilder(
    fixtureId: liveState == null ? match.fixture.apiFootballFixtureId : null,
    builder: (context, received) {
      final state = liveState ?? received;
      return _MatchFeedCardContent(
        match: state?.overlay(match) ?? match,
        readingMatch: readingMatch ?? match,
        onTap: onTap,
        showCompetitionHeader: showCompetitionHeader,
        showReadings: showReadings,
        radarEntries: radarEntries,
        liveState: state,
      );
    },
  );
}

class _MatchFeedCardContent extends StatelessWidget {
  const _MatchFeedCardContent({
    required this.match,
    required this.onTap,
    this.showCompetitionHeader = true,
    this.showReadings = true,
    this.readingMatch,
    this.radarEntries,
    this.liveState,
  });

  final MatchBoardItem match;
  final VoidCallback onTap;
  final bool showCompetitionHeader;

  /// Whether this screen permits readings for the current identity.
  /// [readingMatch] must already have been analyzed for that identity/profile.
  final bool showReadings;
  final MatchBoardItem? readingMatch;
  final List<PlayerFormRadarEntry>? radarEntries;
  final LiveMatchState? liveState;

  @override
  Widget build(BuildContext context) {
    final analyzedMatch = readingMatch ?? match;
    final readings = showReadings
        ? _representativeReadingTags(analyzedMatch)
        : const <MatchCardReading>[];
    final scenarios = showReadings
        ? _representativeScenarios(analyzedMatch)
        : const <MatchCardScenario>[];
    final storedRadarEntries = radarEntries ?? _formRadarEntriesForMatch(match);
    final usesLocalRadarPreview =
        radarEntries == null &&
        storedRadarEntries.isEmpty &&
        formRadarFixtureEnabled;
    final visibleRadarEntries = usesLocalRadarPreview
        ? playerFormRadarFixtureEntriesForMatch(match)
        : storedRadarEntries;
    final contributions = liveState?.radarSnapshot == null
        ? const <LectorRadarContribution>[]
        : footballRadarContributions(
            liveState!.radarSnapshot!,
            liveState!.events,
            liveState!.eventsCapturedAt,
          );
    final hasSelectedPlayerReading =
        showReadings &&
        analyzedMatch.profileStatus == MatchProfileStatus.inProfile &&
        analyzedMatch.signals.any(
          (s) => s.id.startsWith('standout_decisive_player'),
        );
    final contextPanel = !hasSelectedPlayerReading
        ? null
        : liveState?.radarSnapshot != null
        ? LectorRecordedRadarPanel(
            snapshot: liveState!.radarSnapshot!,
            contributions: contributions,
            isLive: liveState!.isLive,
          )
        : visibleRadarEntries.isEmpty
        ? null
        : FormRadarSignalPanel(
            entries: visibleRadarEntries,
            isLocalPreview: usesLocalRadarPreview,
          );
    final summary = liveState == null || !showReadings
        ? null
        : LiveReadingSummary(
            match: match,
            onOpenMatch: onTap,
            state: liveState!,
            hasReadings: readings.isNotEmpty,
            entries: liveState!.visibleReadings(
              {
                ...readings.map((r) => r.id),
                ...analyzedMatch.signals
                    .where((s) => s.id.startsWith('standout_decisive_player'))
                    .map((_) => 'standout_decisive_player'),
              },
              scenarioIds: analyzedMatch.signals
                  .where((s) => s.id.startsWith('scenario:'))
                  .map((s) => s.id.substring(9))
                  .toSet(),
            ),
          );
    return LectorCompactMatchCard(
      data: compactFootballMatch(
        match: match,
        analyzedMatch: analyzedMatch,
        showReadings: showReadings,
        liveLabel: liveState?.temporal.compactLabel,
        competitionFormScope:
            match.competition.isContinentalTournament ||
                !(match.fixture.round?.startsWith('Regular Season') ?? false)
            ? MatchFormScope.competition
            : MatchFormScope.championship,
      ),
      preparationAction: ShortlistAddButton(fixture: shortlistFootball(match)),
      onOpen: onTap,
      statusWidget: liveState?.isLive == true
          ? LectorLiveBadge(state: liveState!.temporal)
          : null,
      liveFooter: liveState == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiveMatchStatus(
                  state: liveState!,
                  showBadge: false,
                  showStatus: false,
                ),
                ?summary,
              ],
            ),
      supplement: contextPanel == null && scenarios.isEmpty && readings.isEmpty
          ? null
          : LectorMatchSupplement(
              identity: match.id,
              decisiveCount: contributions
                  .map((c) => c.playerId)
                  .toSet()
                  .length,
              isLive: liveState?.isLive == true,
              label: contextPanel != null
                  ? 'Signaux Form Radar'
                  : 'Lectures et suivi',
              children: [
                if (scenarios.isNotEmpty || readings.isNotEmpty)
                  _StoryInsights(
                    scenarios: scenarios,
                    readings: readings,
                    fallbackSummary: showReadings
                        ? _storySummary(analyzedMatch)
                        : '',
                  ),
                ?contextPanel,
              ],
            ),
    );
  }
}

List<PlayerFormRadarEntry> _formRadarEntriesForMatch(MatchBoardItem match) {
  final hotPlayers = PlayerFormRadarRanker.rank(
    match.analysis.playerFormRadarProfiles,
  );
  return hotPlayers
      .where(
        (entry) =>
            entry.profile.teamId == match.homeTeam.apiFootballTeamId ||
            entry.profile.teamId == match.awayTeam.apiFootballTeamId,
      )
      .toList(growable: false);
}

class _StoryInsights extends StatelessWidget {
  const _StoryInsights({
    required this.scenarios,
    required this.readings,
    required this.fallbackSummary,
  });

  final List<MatchCardScenario> scenarios;
  final List<MatchCardReading> readings;
  final String fallbackSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final scenario in scenarios) ...[
          _StoryScenarioPanel(scenario: scenario),
          const SizedBox(height: 7),
        ],
        _StoryReadingTags(tags: readings),
        if (scenarios.isEmpty && fallbackSummary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            fallbackSummary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _StoryScenarioPanel extends StatelessWidget {
  const _StoryScenarioPanel({required this.scenario});

  final MatchCardScenario scenario;

  @override
  Widget build(BuildContext context) {
    final color = context.strategies.violetStyle.color;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: color.withValues(alpha: 0.68)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.track_changes_rounded, color: color, size: 23),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCÉNARIO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                  Text(
                    scenario.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (scenario.summary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      scenario.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                        height: 1.18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryReadingTags extends StatelessWidget {
  const _StoryReadingTags({required this.tags});

  final List<MatchCardReading> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: [
        for (final tag in tags)
          LectorReadingPill(
            label: tag.label,
            style: context.opportunities.badgeFor(
              tag.id,
              variant: AppReadingBadgeVariant.soft,
            ),
            icon: context.opportunities.readingIdentityForId(tag.id).icon,
          ),
      ],
    );
  }
}

/// Displays only profile-retained signals, never published facts or thesis evidence.
List<MatchCardReading> publishedMatchCardReadings(MatchBoardItem match) =>
    _representativeReadingTags(match);

List<MatchCardScenario> publishedMatchCardScenarios(MatchBoardItem match) =>
    _representativeScenarios(match);

int publishedMatchCardReadingCount(MatchBoardItem match) =>
    _storyReadingCount(match, _representativeReadingTags(match));

List<MatchCardReading> _representativeReadingTags(MatchBoardItem match) {
  if (match.profileStatus != MatchProfileStatus.inProfile) return const [];
  final readingsById = <String, MatchCardReading>{};
  void add(String id, String label) {
    if (id.isNotEmpty && !readingsById.containsKey(id)) {
      readingsById[id] = MatchCardReading(id: id, label: label);
    }
  }

  for (final signal in match.signals) {
    if (signal.id.startsWith('scenario:') || signal.id.startsWith('market:')) {
      continue;
    }
    if (ReadingPreferenceCatalog.preferenceIdsForReading(signal.id).isEmpty ||
        signal.id.startsWith('standout_decisive_player')) {
      continue;
    }
    add(signal.id, matchReadingLabelForId(signal.id, fallback: signal.title));
  }
  return readingsById.values.toList(growable: false);
}

int _storyReadingCount(
  MatchBoardItem match,
  List<MatchCardReading> displayedReadings,
) {
  if (match.profileStatus != MatchProfileStatus.inProfile) return 0;
  if (displayedReadings.isEmpty) return 0;
  if (match.profileRelevance.readingMatches > 0) {
    return match.profileRelevance.readingMatches;
  }
  return displayedReadings.length;
}

List<MatchCardScenario> _representativeScenarios(MatchBoardItem match) {
  if (match.profileStatus != MatchProfileStatus.inProfile) return const [];
  final scenariosByRuntimeId = <String, MatchCardScenario>{};
  for (final signal in match.signals) {
    if (!signal.id.startsWith('scenario:')) {
      continue;
    }
    final parts = signal.id.split(':');
    if (parts.length < 2 || parts[1].isEmpty) {
      continue;
    }
    final scenarioId = parts[1];
    final catalogLabel = OpportunityProfileCatalog.byId(
      scenarioId,
    )?.displayLabel;
    if (catalogLabel == null) {
      continue;
    }
    final signalLabel = signal.title.trim();
    scenariosByRuntimeId[signal.id] = MatchCardScenario(
      label: signalLabel.isNotEmpty
          ? signalLabel
          : catalogLabel ?? 'Scénario détecté',
      summary: signal.summary.trim(),
    );
  }
  return scenariosByRuntimeId.values.toList(growable: false);
}

String _storySummary(MatchBoardItem match) {
  for (final signal in match.signals) {
    if (ReadingPreferenceCatalog.preferenceIdsForReading(signal.id).isEmpty) {
      continue;
    }
    final summary = signal.summary.trim();
    if (summary.isNotEmpty) {
      return summary;
    }
  }
  return '';
}

String matchReadingLabelForId(String id, {required String fallback}) {
  return switch (id) {
    'ranking_gap' || 'structural_level_gap' => 'Avantage classement',
    'ranking_superiority' => 'Écart au classement',
    'balanced_hierarchy' => 'Hiérarchie équilibrée',
    'winning_streak' ||
    'home_winning_streak' ||
    'away_winning_streak' ||
    'positive_streak' ||
    'improving_form' ||
    'form_advantage' ||
    'form_gap' => 'Forme',
    'negative_streak' || 'declining_form' => 'Dynamique négative',
    'head_to_head_dominance' => 'Domination TAT',
    'frequent_first_half_scoring' => 'Marque en première mi-temps',
    'frequent_first_half_conceding' => 'Encaisse en première mi-temps',
    'frequent_second_half_scoring' => 'Marque en seconde mi-temps',
    'frequent_second_half_conceding' => 'Encaisse en seconde mi-temps',
    'match_shot_profile' => 'Rythme de tirs attendu',
    'match_corner_profile' => 'Potentiel corners',
    'match_card_profile' => 'Intensité des cartons',
    'high_shot_volume' => 'Volume de tirs élevé',
    'low_shot_volume' => 'Faible volume de tirs',
    'high_shots_on_target' => 'Nombreux tirs cadrés',
    'low_shot_accuracy' => 'Difficulté à cadrer',
    'high_shots_conceded' => 'Concède beaucoup de tirs',
    'high_shots_on_target_conceded' => 'Concède des tirs cadrés',
    'high_corner_creation' => 'Obtient beaucoup de corners',
    'high_corners_conceded' => 'Concède beaucoup de corners',
    'high_total_corners_profile' => 'Match riche en corners',
    'low_total_corners_profile' => 'Match pauvre en corners',
    'high_card_rate' => 'Beaucoup de cartons',
    'low_card_rate' => 'Équipe disciplinée',
    'high_total_cards_profile' => 'Match riche en cartons',
    'fragile_defense' ||
    'high_xg_conceded' ||
    'defensive_underperformance' => 'Défense fragile',
    'prolific_attack' ||
    'high_xg_creation' ||
    'attack_in_form' => 'Attaque efficace',
    'open_match' ||
    'open_match_profile' ||
    'frequent_over_25' ||
    'frequent_btts' => 'Match ouvert',
    'closed_match' ||
    'closed_match_profile' ||
    'frequent_under_25' => 'Match fermé',
    'expected_domination' ||
    'solid_favorite' ||
    'controlled_favorite' => 'Domination attendue',
    'credible_outsider' => 'Outsider crédible',
    'contradiction' || 'conflicting_signals' => 'Contexte',
    _ => fallback,
  };
}

class MatchResultOdd {
  const MatchResultOdd({required this.label, required this.value});

  final String label;
  final MarketOdds value;
}

/// Returns the canonical 1/N/2 market in its visual order.  Home cards only
/// expose the basic result market; they never substitute an unrelated market
/// merely to fill the available space.
List<MatchResultOdd> matchResultOddsFor(MatchBoardItem match) {
  MatchMarket? market;
  for (final candidate in match.availableMarkets) {
    if (candidate.id == 'matchResult') {
      market = candidate;
      break;
    }
  }
  if (market == null) return const [];

  MarketOdds? selectionFor(String expectedValue) {
    for (final selection in market!.selections) {
      final apiValue = selection.apiFootballValue?.toLowerCase();
      final label = selection.label.trim().toLowerCase();
      if (apiValue == expectedValue || label == expectedValue) {
        return selection;
      }
    }
    return null;
  }

  final home = selectionFor('home');
  final draw = selectionFor('draw');
  final away = selectionFor('away');
  if (home == null || draw == null || away == null) return const [];
  if (!home.odds.isFinite || !draw.odds.isFinite || !away.odds.isFinite) {
    return const [];
  }
  return [
    MatchResultOdd(label: '1', value: home),
    MatchResultOdd(label: 'N', value: draw),
    MatchResultOdd(label: '2', value: away),
  ];
}

String matchFixtureTime(NormalizedFixture fixture) {
  final kickoff = fixture.kickoff?.toLocal();
  if (kickoff != null) {
    return '${kickoff.hour.toString().padLeft(2, '0')}:${kickoff.minute.toString().padLeft(2, '0')}';
  }
  return fixture.kickoffLabel;
}
