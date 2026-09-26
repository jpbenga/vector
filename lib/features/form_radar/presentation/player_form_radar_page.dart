import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../matches/domain/match_board_item.dart';
import '../../matches/presentation/widgets/sports_asset_badge.dart';
import '../data/player_form_radar_fixture.dart';
import '../domain/player_form_radar.dart';
import '../domain/team_form_radar.dart';
import 'player_form_radar_match_detail_sheet.dart';
import 'team_form_radar_match_detail_sheet.dart';

class PlayerFormRadarPage extends StatefulWidget {
  const PlayerFormRadarPage({
    required this.matches,
    required this.selectedDate,
    required this.onOpenMatch,
    super.key,
  });

  final List<MatchBoardItem> matches;
  final DateTime selectedDate;
  final ValueChanged<MatchBoardItem> onOpenMatch;

  @override
  State<PlayerFormRadarPage> createState() => _PlayerFormRadarPageState();
}

class _PlayerFormRadarPageState extends State<PlayerFormRadarPage> {
  Set<int> _playerSelectedLeagueIds = const {};
  Set<int> _teamSelectedLeagueIds = const {};
  bool _showAll = false;
  _RadarContentMode _mode = _RadarContentMode.players;

  @override
  Widget build(BuildContext context) {
    final fixtureSnapshot = formRadarFixtureEnabled
        ? playerFormRadarFixtureForDate(widget.selectedDate)
        : null;
    final profiles =
        fixtureSnapshot?.profiles ?? _profilesForMatches(widget.matches);
    final dataAsOf = fixtureSnapshot?.asOf ?? _latestRadarAsOf(widget.matches);
    final ranked = PlayerFormRadarRanker.rank(profiles);
    final teamProfiles = formRadarFixtureEnabled
        ? _teamProfilesFromPlayerFixture(profiles, widget.matches)
        : _teamProfilesForMatches(widget.matches);
    final rankedTeams = TeamFormRadarRanker.rank(teamProfiles);
    final isTeamRadar = _mode == _RadarContentMode.teams;
    final leagueOptions = _leagueOptions(widget.matches);
    final selectedLeagueIds = isTeamRadar
        ? _teamSelectedLeagueIds
        : _playerSelectedLeagueIds;
    final scoped = selectedLeagueIds.isEmpty
        ? ranked
        : ranked
              .where(
                (entry) => selectedLeagueIds.contains(entry.profile.leagueId),
              )
              .toList(growable: false);
    final scopedTeams = selectedLeagueIds.isEmpty
        ? rankedTeams
        : rankedTeams
              .where(
                (entry) => selectedLeagueIds.contains(entry.profile.leagueId),
              )
              .toList(growable: false);
    final cappedPlayers = scoped.take(20).toList(growable: false);
    final cappedTeams = scopedTeams.take(20).toList(growable: false);
    final visible = _showAll
        ? cappedPlayers
        : cappedPlayers.take(10).toList(growable: false);
    final visibleTeams = _showAll
        ? cappedTeams
        : cappedTeams.take(10).toList(growable: false);
    final radarMatches = _matchesWithHotPlayers(widget.matches, scoped);
    final teamRadarMatches = _matchesWithTeams(widget.matches, scopedTeams);

    return Column(
      key: const ValueKey('player-form-radar-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Radar',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              isTeamRadar
                  ? 'Les équipes les plus en forme des matchs du jour'
                  : 'Les joueurs chauds des matchs du jour',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _RadarModeToggle(
          selected: _mode,
          onChanged: (mode) => setState(() {
            _mode = mode;
            _showAll = false;
          }),
        ),
        if (formRadarFixtureEnabled) ...[
          const SizedBox(height: AppSpacing.sm),
          const _RadarFixtureNotice(),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (_isFutureDay(widget.selectedDate) && dataAsOf != null) ...[
          _RadarFutureDataNotice(
            selectedDate: widget.selectedDate,
            dataAsOf: dataAsOf,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _RadarCompetitionFilterControl(
          totalPlayerCount: isTeamRadar
              ? cappedTeams.length
              : cappedPlayers.length,
          options: leagueOptions,
          selectedLeagueIds: selectedLeagueIds,
          onClear: selectedLeagueIds.isEmpty
              ? null
              : () => setState(() {
                  if (isTeamRadar) {
                    _teamSelectedLeagueIds = const {};
                  } else {
                    _playerSelectedLeagueIds = const {};
                  }
                  _showAll = false;
                }),
          onOpen: () => _openCompetitionFilter(
            options: leagueOptions,
            selectedLeagueIds: selectedLeagueIds,
            mode: _mode,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (isTeamRadar)
          _HotTeamsPanel(
            entries: visibleTeams,
            totalCount: cappedTeams.length,
            showAll: _showAll,
            onShowAll: cappedTeams.length > 10
                ? () => setState(() => _showAll = !_showAll)
                : null,
          )
        else
          _HotPlayersPanel(
            entries: visible,
            totalCount: cappedPlayers.length,
            hasRadarData: profiles.isNotEmpty,
            showAll: _showAll,
            onShowAll: cappedPlayers.length > 10
                ? () => setState(() => _showAll = !_showAll)
                : null,
            matches: widget.matches,
            onOpenMatch: widget.onOpenMatch,
          ),
        const SizedBox(height: AppSpacing.lg),
        if (isTeamRadar)
          _TeamRadarMatchesSection(
            matches: teamRadarMatches,
            onOpenMatch: widget.onOpenMatch,
          )
        else
          _RadarMatchesSection(
            matches: radarMatches,
            entries: scoped,
            onOpenMatch: widget.onOpenMatch,
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Future<void> _openCompetitionFilter({
    required Map<int, String> options,
    required Set<int> selectedLeagueIds,
    required _RadarContentMode mode,
  }) async {
    final selection = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RadarCompetitionFilterSheet(
        options: options,
        initialSelectedLeagueIds: selectedLeagueIds,
      ),
    );
    if (!mounted || selection == null) return;
    setState(() {
      if (mode == _RadarContentMode.teams) {
        _teamSelectedLeagueIds = Set.unmodifiable(selection);
      } else {
        _playerSelectedLeagueIds = Set.unmodifiable(selection);
      }
      _showAll = false;
    });
  }
}

class _RadarFutureDataNotice extends StatelessWidget {
  const _RadarFutureDataNotice({
    required this.selectedDate,
    required this.dataAsOf,
  });

  final DateTime selectedDate;
  final DateTime dataAsOf;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.backgroundSecondary,
      border: Border.all(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: context.brand.accent),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Matchs à venir : forme mise à jour le ${_radarDateLabel(dataAsOf)}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RadarFixtureNotice extends StatelessWidget {
  const _RadarFixtureNotice();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.brand.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.control),
      border: Border.all(color: context.brand.accent.withValues(alpha: 0.34)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 18, color: context.brand.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Aperçu local : joueurs et historiques d’exemple. '
              'Aucune donnée fictive n’est envoyée à Supabase.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

enum _RadarContentMode { players, teams }

class _RadarModeToggle extends StatelessWidget {
  const _RadarModeToggle({required this.selected, required this.onChanged});

  final _RadarContentMode selected;
  final ValueChanged<_RadarContentMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = context.brand.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onChanged(_RadarContentMode.players),
              borderRadius: BorderRadius.circular(AppRadius.card - 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected == _RadarContentMode.players
                      ? accent
                      : AppColors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.card - 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Center(
                    child: Text(
                      'Joueurs',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected == _RadarContentMode.players
                            ? context.brand.onAccent
                            : context.textColors.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => onChanged(_RadarContentMode.teams),
              borderRadius: BorderRadius.circular(AppRadius.card - 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected == _RadarContentMode.teams
                      ? accent
                      : AppColors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.card - 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Center(
                    child: Text(
                      'Équipes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected == _RadarContentMode.teams
                            ? context.brand.onAccent
                            : context.textColors.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarCompetitionFilterControl extends StatelessWidget {
  const _RadarCompetitionFilterControl({
    required this.totalPlayerCount,
    required this.options,
    required this.selectedLeagueIds,
    required this.onClear,
    required this.onOpen,
  });

  final int totalPlayerCount;
  final Map<int, String> options;
  final Set<int> selectedLeagueIds;
  final VoidCallback? onClear;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final label = selectedLeagueIds.isEmpty
        ? 'Tous les championnats'
        : selectedLeagueIds.length == 1
        ? options[selectedLeagueIds.single] ?? '1 championnat'
        : '${selectedLeagueIds.length} championnats';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.brand.accent.withValues(alpha: .15),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Text(
                      '$totalPlayerCount',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.brand.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 26, color: context.surfaces.border),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (onClear != null)
                    IconButton(
                      tooltip: 'Retirer le filtre',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Filtrer les championnats',
              onPressed: onOpen,
              icon: Icon(Icons.tune_rounded, color: context.brand.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarCompetitionFilterSheet extends StatefulWidget {
  const _RadarCompetitionFilterSheet({
    required this.options,
    required this.initialSelectedLeagueIds,
  });

  final Map<int, String> options;
  final Set<int> initialSelectedLeagueIds;

  @override
  State<_RadarCompetitionFilterSheet> createState() =>
      _RadarCompetitionFilterSheetState();
}

class _RadarCompetitionFilterSheetState
    extends State<_RadarCompetitionFilterSheet> {
  late Set<int> _selectedLeagueIds = {...widget.initialSelectedLeagueIds};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final options = widget.options.entries.toList()
      ..sort((left, right) => left.value.compareTo(right.value));
    final query = _query.trim().toLowerCase();
    final visible = options
        .where(
          (option) =>
              query.isEmpty || option.value.toLowerCase().contains(query),
        )
        .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtrer les championnats',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                'Le classement Radar reste limité aux championnats choisis.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un championnat',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              ChoiceChip(
                label: const Text('Tous les championnats'),
                selected: _selectedLeagueIds.isEmpty,
                onSelected: (_) => setState(() => _selectedLeagueIds = {}),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final option in visible)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: _selectedLeagueIds.contains(option.key),
                        title: Text(
                          option.value,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.textColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        onChanged: (value) => setState(() {
                          if (value ?? false) {
                            _selectedLeagueIds.add(option.key);
                          } else {
                            _selectedLeagueIds.remove(option.key);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _selectedLeagueIds = {}),
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(Set<int>.unmodifiable(_selectedLeagueIds)),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotPlayersPanel extends StatelessWidget {
  const _HotPlayersPanel({
    required this.entries,
    required this.totalCount,
    required this.hasRadarData,
    required this.showAll,
    required this.onShowAll,
    required this.matches,
    required this.onOpenMatch,
  });
  final List<PlayerFormRadarEntry> entries;
  final int totalCount;
  final bool hasRadarData;
  final bool showAll;
  final VoidCallback? onShowAll;
  final List<MatchBoardItem> matches;
  final ValueChanged<MatchBoardItem> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    final matrixColumns = entries.fold<int>(
      PlayerFormRadarRanker.recentWindow,
      (current, entry) => entry.profile.activity.length > current
          ? entry.profile.activity.length
          : current,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: entries.isEmpty
            ? _RadarEmptyState(hasRadarData: hasRadarData)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: context.semantic.warning,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Joueurs les plus chauds',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: context.textColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      Text(
                        showAll ? '$totalCount joueurs' : 'Top 10',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: context.textColors.secondary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: _RadarLegend()),
                      const SizedBox(width: 12),
                      _RadarPeriodLabel(columnCount: matrixColumns),
                    ],
                  ),
                  Divider(height: 18, color: context.surfaces.border),
                  for (final indexed in entries.indexed) ...[
                    _HotPlayerRow(
                      rank: indexed.$1 + 1,
                      entry: indexed.$2,
                      match: _matchForTeam(matches, indexed.$2.profile.teamId),
                      onOpenMatch: onOpenMatch,
                      matrixColumns: matrixColumns,
                    ),
                    if (indexed.$1 != entries.length - 1)
                      Divider(height: 18, color: context.surfaces.border),
                  ],
                  if (onShowAll != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onShowAll,
                        icon: Icon(
                          showAll
                              ? Icons.expand_less_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          showAll
                              ? 'Réduire la liste'
                              : 'Voir les $totalCount joueurs chauds',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _HotTeamsPanel extends StatelessWidget {
  const _HotTeamsPanel({
    required this.entries,
    required this.totalCount,
    required this.showAll,
    required this.onShowAll,
  });

  final List<TeamFormRadarEntry> entries;
  final int totalCount;
  final bool showAll;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.backgroundSecondary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.surfaces.border),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: entries.isEmpty
          ? const _TeamRadarEmptyState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.groups_rounded, color: context.brand.accent),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Équipes les plus chaudes',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: context.textColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    Text(
                      showAll ? '$totalCount équipes' : 'Top 10',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final indexed in entries.indexed) ...[
                  _HotTeamRow(rank: indexed.$1 + 1, entry: indexed.$2),
                  if (indexed.$1 != entries.length - 1)
                    Divider(height: 16, color: context.surfaces.border),
                ],
                if (onShowAll != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onShowAll,
                      icon: Icon(
                        showAll
                            ? Icons.expand_less_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        showAll
                            ? 'Réduire la liste'
                            : 'Voir les ${totalCount.clamp(0, 20)} équipes',
                      ),
                    ),
                  ),
                ],
              ],
            ),
    ),
  );
}

class _TeamRadarEmptyState extends StatelessWidget {
  const _TeamRadarEmptyState();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Données de forme indisponibles',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: context.textColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'Le Radar équipe attend au moins trois matchs de championnat terminés.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.textColors.secondary,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _HotTeamRow extends StatelessWidget {
  const _HotTeamRow({required this.rank, required this.entry});

  final int rank;
  final TeamFormRadarEntry entry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 22,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      SportsAssetBadge(
        size: 34,
        imageUrl: entry.profile.logoUrl,
        fallbackLabel: entry.profile.teamName,
        borderRadius: 17,
        contrastPlate: true,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.profile.teamName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              entry.profile.leagueName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      _TeamFormStrip(
        matches: entry.profile.activity,
        onMatchTap: (index) => showTeamFormRadarMatchDetail(
          context,
          profile: entry.profile,
          initialIndex: index,
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 44,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.points}/15',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'série ${entry.unbeatenStreak}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.semantic.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TeamFormStrip extends StatelessWidget {
  const _TeamFormStrip({required this.matches, this.onMatchTap});
  final List<TeamRecentMatchSnapshot> matches;
  final ValueChanged<int>? onMatchTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final indexed in matches.take(5).indexed) ...[
        InkWell(
          onTap: onMatchTap == null ? null : () => onMatchTap!(indexed.$1),
          borderRadius: BorderRadius.circular(3),
          child: Container(
            width: 13,
            height: 13,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _colorForResult(context, indexed.$2.result),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        if (indexed.$1 != matches.take(5).length - 1) const SizedBox(width: 3),
      ],
    ],
  );

  Color _colorForResult(BuildContext context, String result) =>
      switch (result.toUpperCase()) {
        'W' || 'V' => context.semantic.success,
        'D' || 'N' => context.textColors.secondary.withValues(alpha: .27),
        _ => context.semantic.error,
      };
}

class _RadarEmptyState extends StatelessWidget {
  const _RadarEmptyState({required this.hasRadarData});
  final bool hasRadarData;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        hasRadarData
            ? 'Aucun joueur chaud détecté'
            : 'Données Radar indisponibles',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: context.textColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        hasRadarData
            ? 'Le Radar attend au moins deux actions décisives sur les trois derniers matchs terminés.'
            : 'Ce snapshot ne contient pas encore les activités joueur par match. Lector ne fabrique pas de tendance à partir de données incomplètes.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.textColors.secondary,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _RadarLegend extends StatelessWidget {
  const _RadarLegend();
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 7,
    children: [
      _LegendItem(marker: _RadarCell.empty(context), label: 'Absent'),
      _LegendItem(marker: _RadarCell.started(context), label: 'Titulaire'),
      _LegendItem(marker: _RadarCell.substitute(context), label: 'Entrée'),
      _LegendItem(marker: _RadarCell.decisive(context, 1), label: '1 action'),
      _LegendItem(marker: _RadarCell.decisive(context, 2), label: '2+ actions'),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.marker, required this.label});
  final Widget marker;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 16, child: Center(child: marker)),
      const SizedBox(width: 4),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.textColors.secondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _RadarPeriodLabel extends StatelessWidget {
  const _RadarPeriodLabel({required this.columnCount});
  final int columnCount;

  @override
  Widget build(BuildContext context) {
    final historyColumns = _historyColumns(columnCount);
    return SizedBox(
      width: _matrixWidth(columnCount),
      child: Row(
        children: [
          SizedBox(
            width: _cellsWidth(historyColumns),
            child: Text(
              'Historique',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _MatrixDivider(color: context.brand.accent),
          SizedBox(
            width: _cellsWidth(PlayerFormRadarRanker.recentWindow),
            child: Semantics(
              label: 'Trois derniers matchs',
              child: Text(
                '3 récents',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.brand.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotPlayerRow extends StatelessWidget {
  const _HotPlayerRow({
    required this.rank,
    required this.entry,
    required this.match,
    required this.onOpenMatch,
    required this.matrixColumns,
  });
  final int rank;
  final PlayerFormRadarEntry entry;
  final MatchBoardItem? match;
  final ValueChanged<MatchBoardItem> onOpenMatch;
  final int matrixColumns;

  @override
  Widget build(BuildContext context) {
    final recentLine =
        '${entry.recentDecisiveMatches}/3 déc. · série ${entry.decisiveStreak}';
    final stats =
        '⚽ ${entry.goals} · 🥾 ${entry.assists} · ${entry.recentMinutes} min';
    final teamLogoUrl =
        entry.profile.teamLogoUrl ??
        _teamLogoForMatch(match, entry.profile.teamId);
    return Semantics(
      button: match != null,
      label: '${entry.profile.playerName}, $recentLine',
      child: InkWell(
        onTap: match == null ? null : () => onOpenMatch(match!),
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SportsAssetBadge(
                size: 38,
                imageUrl: entry.profile.photoUrl,
                fallbackLabel: entry.profile.playerName,
                borderRadius: 19,
                backgroundColor: AppColors.transparent,
                contrastPlate: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.profile.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        SportsAssetBadge(
                          size: 15,
                          imageUrl: teamLogoUrl,
                          fallbackLabel: entry.profile.teamName,
                          borderRadius: 4,
                          contrastPlate: true,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            entry.profile.teamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: context.textColors.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      recentLine,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.semantic.success,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      stats,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PlayerActivityMatrix(
                activity: entry.profile.activity,
                columnCount: matrixColumns,
                onMatchTap: (activity) => showPlayerFormRadarMatchDetail(
                  context,
                  profile: entry.profile,
                  activity: entry.profile.activity,
                  initialFixtureId: activity.fixtureId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerActivityMatrix extends StatelessWidget {
  const _PlayerActivityMatrix({
    required this.activity,
    required this.columnCount,
    this.onMatchTap,
  });
  final List<PlayerFormRadarMatchSnapshot> activity;
  final int columnCount;
  final ValueChanged<PlayerFormRadarMatchSnapshot>? onMatchTap;

  @override
  Widget build(BuildContext context) {
    final historyColumns = _historyColumns(columnCount);
    final allPrior = activity.length <= PlayerFormRadarRanker.recentWindow
        ? const <PlayerFormRadarMatchSnapshot>[]
        : activity.sublist(
            0,
            activity.length - PlayerFormRadarRanker.recentWindow,
          );
    final prior = allPrior.length <= historyColumns
        ? allPrior
        : allPrior.sublist(allPrior.length - historyColumns);
    final recent = activity.length < PlayerFormRadarRanker.recentWindow
        ? activity
        : activity.sublist(
            activity.length - PlayerFormRadarRanker.recentWindow,
          );
    return SizedBox(
      width: _matrixWidth(columnCount),
      child: Row(
        children: [
          SizedBox(
            width: _cellsWidth(historyColumns),
            child: Align(
              alignment: Alignment.centerRight,
              child: _RadarCellStrip(matches: prior, onMatchTap: onMatchTap),
            ),
          ),
          _MatrixDivider(color: context.brand.accent),
          SizedBox(
            width: _cellsWidth(PlayerFormRadarRanker.recentWindow),
            child: _RadarCellStrip(matches: recent, onMatchTap: onMatchTap),
          ),
        ],
      ),
    );
  }
}

class _RadarCellStrip extends StatelessWidget {
  const _RadarCellStrip({required this.matches, this.onMatchTap});
  final List<PlayerFormRadarMatchSnapshot> matches;
  final ValueChanged<PlayerFormRadarMatchSnapshot>? onMatchTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final indexed in matches.indexed) ...[
        Semantics(
          button: onMatchTap != null,
          label: 'Match du ${_radarDateLabel(indexed.$2.playedAt)}',
          child: InkWell(
            onTap: onMatchTap == null ? null : () => onMatchTap!(indexed.$2),
            borderRadius: BorderRadius.circular(3),
            child: _RadarCell.forMatch(context, indexed.$2),
          ),
        ),
        if (indexed.$1 != matches.length - 1)
          const SizedBox(width: _radarCellSpacing),
      ],
    ],
  );
}

class _MatrixDivider extends StatelessWidget {
  const _MatrixDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: _radarDividerGap),
    width: 2,
    height: 19,
    color: color,
  );
}

const double _radarCellSize = 14;
const double _radarCellSpacing = 3;
const double _radarDividerGap = 5;

int _historyColumns(int columnCount) =>
    (columnCount - PlayerFormRadarRanker.recentWindow).clamp(0, 99);

double _cellsWidth(int count) =>
    count == 0 ? 0 : count * _radarCellSize + (count - 1) * _radarCellSpacing;

double _matrixWidth(int columnCount) =>
    _cellsWidth(_historyColumns(columnCount)) +
    _cellsWidth(PlayerFormRadarRanker.recentWindow) +
    2 +
    _radarDividerGap * 2;

String? _teamLogoForMatch(MatchBoardItem? match, int teamId) {
  if (match == null) return null;
  if (match.homeTeam.apiFootballTeamId == teamId) return match.homeTeam.logoUrl;
  if (match.awayTeam.apiFootballTeamId == teamId) return match.awayTeam.logoUrl;
  return null;
}

class _RadarCell extends StatelessWidget {
  const _RadarCell._({required this.child});
  final Widget child;

  factory _RadarCell.forMatch(
    BuildContext context,
    PlayerFormRadarMatchSnapshot match,
  ) {
    if (!match.appeared) return _RadarCell.empty(context);
    if (match.isDecisive) {
      return _RadarCell.decisive(
        context,
        match.contributions,
        substitute: match.substitute,
      );
    }
    return match.substitute
        ? _RadarCell.substitute(context)
        : _RadarCell.started(context);
  }
  factory _RadarCell.empty(BuildContext context) => _RadarCell._(
    child: Container(
      width: _radarCellSize,
      height: _radarCellSize,
      decoration: BoxDecoration(
        border: Border.all(color: context.surfaces.border),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
  factory _RadarCell.started(BuildContext context) => _RadarCell._(
    child: Container(
      width: _radarCellSize,
      height: _radarCellSize,
      decoration: BoxDecoration(
        color: context.textColors.secondary.withValues(alpha: .27),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
  factory _RadarCell.substitute(BuildContext context) => _RadarCell._(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: _radarCellSize,
        height: 6,
        decoration: BoxDecoration(
          color: context.semantic.warning,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
  factory _RadarCell.decisive(
    BuildContext context,
    int contributions, {
    bool substitute = false,
  }) => _RadarCell._(
    child: Container(
      width: _radarCellSize,
      height: _radarCellSize,
      decoration: BoxDecoration(
        color: context.semantic.success.withValues(
          alpha: contributions > 1 ? 1 : .58,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.bottomCenter,
      child: substitute
          ? Container(height: 3, color: context.semantic.warning)
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => child;
}

class _TeamRadarMatchesSection extends StatelessWidget {
  const _TeamRadarMatchesSection({
    required this.matches,
    required this.onOpenMatch,
  });

  final List<MatchBoardItem> matches;
  final ValueChanged<MatchBoardItem> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    final visibleMatches = matches.take(20).toList(growable: false);
    if (visibleMatches.isEmpty) return const SizedBox.shrink();
    final grouped = <String, List<MatchBoardItem>>{};
    for (final match in visibleMatches) {
      grouped.putIfAbsent(match.competition.id, () => []).add(match);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Matchs de ces équipes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Les 20 prochaines rencontres au maximum.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        for (final group in grouped.values) ...[
          _RadarCompetitionHeader(matches: group),
          const SizedBox(height: 7),
          for (final match in group) ...[
            _RadarMatchCard(
              match: match,
              entries: const [],
              onOpen: () => onOpenMatch(match),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _RadarMatchesSection extends StatelessWidget {
  const _RadarMatchesSection({
    required this.matches,
    required this.entries,
    required this.onOpenMatch,
  });
  final List<MatchBoardItem> matches;
  final List<PlayerFormRadarEntry> entries;
  final ValueChanged<MatchBoardItem> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    final grouped = <String, List<MatchBoardItem>>{};
    for (final match in matches) {
      grouped.putIfAbsent(match.competition.id, () => []).add(match);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Matchs du jour',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Les rencontres où jouent les joueurs chauds.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        for (final group in grouped.values) ...[
          _RadarCompetitionHeader(matches: group),
          const SizedBox(height: 7),
          for (final match in group) ...[
            _RadarMatchCard(
              match: match,
              entries: _entriesForMatch(entries, match),
              onOpen: () => onOpenMatch(match),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _RadarCompetitionHeader extends StatelessWidget {
  const _RadarCompetitionHeader({required this.matches});
  final List<MatchBoardItem> matches;
  @override
  Widget build(BuildContext context) {
    final competition = matches.first.competition;
    return Row(
      children: [
        SportsAssetBadge(
          size: 30,
          imageUrl: competition.country.flagUrl ?? competition.logoUrl,
          fallbackLabel: competition.country.name,
          borderRadius: 5,
          contrastPlate: true,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            competition.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '${matches.length} match${matches.length > 1 ? 's' : ''}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RadarMatchCard extends StatelessWidget {
  const _RadarMatchCard({
    required this.match,
    required this.entries,
    required this.onOpen,
  });
  final MatchBoardItem match;
  final List<PlayerFormRadarEntry> entries;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final readingCount = match.analysis.computedReadings
        .where((reading) => !reading.isContradiction)
        .length;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.surfaces.backgroundSecondary,
          border: Border.all(color: context.surfaces.border),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: context.brand.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    match.fixture.kickoffLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (readingCount > 0) ...[
                    Icon(
                      Icons.radar_rounded,
                      color: context.brand.accent,
                      size: 19,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$readingCount lecture${readingCount > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
              Divider(height: 18, color: context.surfaces.border),
              Row(
                children: [
                  Expanded(child: _TeamStack(match: match)),
                  _RadarMatchResultOdds(match: match),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.textColors.secondary,
                  ),
                ],
              ),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 10),
                _RadarSignalsPanel(entries: entries),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamStack extends StatelessWidget {
  const _TeamStack({required this.match});
  final MatchBoardItem match;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _TeamLine(team: match.homeTeam),
      const SizedBox(height: 5),
      _TeamLine(team: match.awayTeam),
    ],
  );
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.team});
  final TeamInfo team;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SportsAssetBadge(
        size: 24,
        imageUrl: team.logoUrl,
        fallbackLabel: team.name,
        borderRadius: 12,
        contrastPlate: true,
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class _RadarMatchResultOdds extends StatelessWidget {
  const _RadarMatchResultOdds({required this.match});
  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final selections =
        match.defaultMarket?.selections.take(3).toList() ??
        const <MarketOdds>[];
    if (selections.length != 3) return const SizedBox(width: 47);
    return SizedBox(
      width: 47,
      height: 66,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final indexed in selections.indexed)
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(text: '${const ['1', 'N', '2'][indexed.$1]} '),
                  TextSpan(
                    text: indexed.$2.odds.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RadarSignalsPanel extends StatelessWidget {
  const _RadarSignalsPanel({required this.entries});
  final List<PlayerFormRadarEntry> entries;
  @override
  Widget build(BuildContext context) {
    final matrixColumns = entries.fold<int>(
      PlayerFormRadarRanker.recentWindow,
      (current, entry) => entry.profile.activity.length > current
          ? entry.profile.activity.length
          : current,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.background.withValues(alpha: .45),
        border: Border.all(color: context.surfaces.border),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  color: context.brand.accent,
                  size: 19,
                ),
                const SizedBox(width: 6),
                Text(
                  'Signaux Form Radar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entries.length} signal${entries.length > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.textColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: _RadarPeriodLabel(columnCount: matrixColumns),
            ),
            const SizedBox(height: 4),
            for (final indexed in entries.indexed) ...[
              if (indexed.$1 > 0)
                Divider(height: 12, color: context.surfaces.border),
              _RadarSignalRow(entry: indexed.$2, matrixColumns: matrixColumns),
            ],
          ],
        ),
      ),
    );
  }
}

class _RadarSignalRow extends StatelessWidget {
  const _RadarSignalRow({required this.entry, required this.matrixColumns});
  final PlayerFormRadarEntry entry;
  final int matrixColumns;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SportsAssetBadge(
        size: 30,
        imageUrl: entry.profile.photoUrl,
        fallbackLabel: entry.profile.playerName,
        borderRadius: 15,
        contrastPlate: true,
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.profile.playerName,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${entry.recentDecisiveMatches}/3 décisif · série ${entry.decisiveStreak}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        width: _matrixWidth(matrixColumns),
        child: _PlayerActivityMatrix(
          activity: entry.profile.activity,
          columnCount: matrixColumns,
        ),
      ),
    ],
  );
}

List<PlayerFormRadarProfile> _profilesForMatches(List<MatchBoardItem> matches) {
  final values = <String, PlayerFormRadarProfile>{};
  for (final match in matches) {
    for (final profile in match.analysis.playerFormRadarProfiles) {
      values.putIfAbsent(
        '${profile.leagueId}:${profile.teamId}:${profile.playerId}',
        () => profile,
      );
    }
  }
  return values.values.toList(growable: false);
}

DateTime? _latestRadarAsOf(List<MatchBoardItem> matches) {
  DateTime? latest;
  for (final match in matches) {
    final asOf = match.analysis.asOf;
    if (asOf != null && (latest == null || asOf.isAfter(latest))) {
      latest = asOf;
    }
  }
  return latest;
}

bool _isFutureDay(DateTime value) {
  final local = value.toLocal();
  final selectedDay = DateTime(local.year, local.month, local.day);
  final now = DateTime.now().toLocal();
  final today = DateTime(now.year, now.month, now.day);
  return selectedDay.isAfter(today);
}

String _radarDateLabel(DateTime value) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]}';
}

Map<int, String> _leagueOptions(List<MatchBoardItem> matches) {
  final names = <int, String>{};
  for (final match in matches) {
    final id = match.competition.apiFootballLeagueId;
    if (id != null) names[id] = match.competition.name;
  }
  return Map.fromEntries(
    names.entries.toList()..sort((a, b) => a.value.compareTo(b.value)),
  );
}

List<TeamFormRadarProfile> _teamProfilesForMatches(
  List<MatchBoardItem> matches,
) {
  final values = <String, TeamFormRadarProfile>{};
  for (final match in matches) {
    final leagueId = match.competition.apiFootballLeagueId;
    if (leagueId == null) continue;
    void add(TeamInfo team, List<TeamRecentMatchSnapshot> activity) {
      final teamId = team.apiFootballTeamId;
      if (teamId == null || activity.isEmpty) return;
      final ordered = [...activity]
        ..sort((left, right) {
          final leftDate =
              left.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate =
              right.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return leftDate.compareTo(rightDate);
        });
      values.putIfAbsent(
        '$leagueId:$teamId',
        () => TeamFormRadarProfile(
          teamId: teamId,
          teamName: team.name,
          logoUrl: team.logoUrl,
          leagueId: leagueId,
          leagueName: match.competition.name,
          activity:
              (ordered.length <= TeamFormRadarRanker.window
                      ? ordered
                      : ordered.sublist(
                          ordered.length - TeamFormRadarRanker.window,
                        ))
                  .toList(growable: false),
        ),
      );
    }

    add(match.homeTeam, match.analysis.homeRecentLeagueMatches);
    add(match.awayTeam, match.analysis.awayRecentLeagueMatches);
  }
  return values.values.toList(growable: false);
}

List<TeamFormRadarProfile> _teamProfilesFromPlayerFixture(
  List<PlayerFormRadarProfile> profiles,
  List<MatchBoardItem> matches,
) {
  final teams = <String, TeamFormRadarProfile>{};
  var templateIndex = 0;
  for (final match in matches) {
    final leagueId = match.competition.apiFootballLeagueId;
    if (leagueId == null || profiles.isEmpty) continue;
    for (final team in [match.homeTeam, match.awayTeam]) {
      final teamId = team.apiFootballTeamId;
      if (teamId == null) continue;
      final key = '$leagueId:$teamId';
      if (teams.containsKey(key)) continue;
      final profile = profiles[templateIndex % profiles.length];
      templateIndex += 1;
      teams[key] = _teamFixtureProfile(
        profile: profile,
        teamId: teamId,
        teamName: team.name,
        logoUrl: team.logoUrl,
        leagueId: leagueId,
        leagueName: match.competition.name,
      );
    }
  }
  if (teams.isNotEmpty) return teams.values.toList(growable: false);
  for (final profile in profiles) {
    teams.putIfAbsent(
      '${profile.leagueId}:${profile.teamId}',
      () => _teamFixtureProfile(
        profile: profile,
        teamId: profile.teamId,
        teamName: profile.teamName,
        logoUrl: profile.teamLogoUrl,
        leagueId: profile.leagueId,
        leagueName: 'Championnat',
      ),
    );
  }
  return teams.values.toList(growable: false);
}

TeamFormRadarProfile _teamFixtureProfile({
  required PlayerFormRadarProfile profile,
  required int teamId,
  required String teamName,
  required String? logoUrl,
  required int leagueId,
  required String leagueName,
}) {
  final source = profile.activity.length <= TeamFormRadarRanker.window
      ? profile.activity
      : profile.activity.sublist(
          profile.activity.length - TeamFormRadarRanker.window,
        );
  return TeamFormRadarProfile(
    teamId: teamId,
    teamName: teamName,
    logoUrl: logoUrl,
    leagueId: leagueId,
    leagueName: leagueName,
    activity: [
      for (final activity in source)
        TeamRecentMatchSnapshot(
          fixtureId: activity.fixtureId,
          opponentName: 'Adversaire',
          venue: RecentMatchVenue.home,
          result: activity.isDecisive ? 'W' : 'D',
          playedAt: activity.playedAt,
          competitionName: leagueName,
          teamLogoUrl: logoUrl,
          goalsFor: activity.contributions,
          goalsAgainst: activity.isDecisive ? 0 : 1,
          events: [
            for (final action in activity.actions)
              TeamRecentMatchEventSnapshot(
                minute: action.minute,
                teamId: teamId,
                teamName: teamName,
                playerName: profile.playerName,
              ),
          ],
          statistics: TeamRecentMatchStatisticsSnapshot(
            shotsFor: (12 + activity.contributions * 2).toDouble(),
            shotsAgainst: 8.0,
            shotsOnTargetFor: (5 + activity.contributions).toDouble(),
            shotsOnTargetAgainst: 3.0,
            expectedGoalsFor: 1.24 + activity.contributions * .28,
            expectedGoalsAgainst: .82,
            possessionFor: 56.0,
            possessionAgainst: 44.0,
          ),
        ),
    ],
  );
}

MatchBoardItem? _matchForTeam(List<MatchBoardItem> matches, int teamId) {
  for (final match in matches) {
    if (match.homeTeam.apiFootballTeamId == teamId ||
        match.awayTeam.apiFootballTeamId == teamId) {
      return match;
    }
  }
  return null;
}

List<MatchBoardItem> _matchesWithHotPlayers(
  List<MatchBoardItem> matches,
  List<PlayerFormRadarEntry> entries,
) {
  final teams = entries.map((entry) => entry.profile.teamId).toSet();
  return matches
      .where(
        (match) =>
            teams.contains(match.homeTeam.apiFootballTeamId) ||
            teams.contains(match.awayTeam.apiFootballTeamId),
      )
      .toList(growable: false);
}

List<MatchBoardItem> _matchesWithTeams(
  List<MatchBoardItem> matches,
  List<TeamFormRadarEntry> entries,
) {
  final teamIds = entries.map((entry) => entry.profile.teamId).toSet();
  final result =
      matches
          .where(
            (match) =>
                teamIds.contains(match.homeTeam.apiFootballTeamId) ||
                teamIds.contains(match.awayTeam.apiFootballTeamId),
          )
          .toList(growable: false)
        ..sort((left, right) {
          final leftDate =
              left.fixture.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate =
              right.fixture.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0);
          return leftDate.compareTo(rightDate);
        });
  return result;
}

List<PlayerFormRadarEntry> _entriesForMatch(
  List<PlayerFormRadarEntry> entries,
  MatchBoardItem match,
) => entries
    .where(
      (entry) =>
          entry.profile.teamId == match.homeTeam.apiFootballTeamId ||
          entry.profile.teamId == match.awayTeam.apiFootballTeamId,
    )
    .toList(growable: false);
