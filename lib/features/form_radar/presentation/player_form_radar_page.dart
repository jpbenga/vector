import '../../../core/widgets/lector_live_badge.dart';
import '../../matches/presentation/widgets/live_fixture_builder.dart';
import 'package:flutter/material.dart';

import '../../../core/identity/identity_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../matches/domain/match_board_item.dart';
import '../../matches/presentation/widgets/sports_asset_badge.dart';
import '../../matches/presentation/widgets/match_feed_card.dart';
import 'form_radar_signal_panel.dart';
import '../data/player_form_radar_fixture.dart';
import '../domain/player_form_radar.dart';
import '../domain/team_form_radar.dart';
import '../domain/radar_audience_filter.dart';
import '../data/radar_audience_filter_store.dart';
import 'player_form_radar_match_detail_sheet.dart';
import 'team_form_radar_match_detail_sheet.dart';

const _radarPageSize = 10;
const _radarTopLimit = 50;

class PlayerFormRadarPage extends StatefulWidget {
  const PlayerFormRadarPage({
    required this.matches,
    required this.selectedDate,
    required this.onOpenMatch,
    this.radarSourceMatches = const [],
    this.personalizedMatches = const [],
    this.showProfileReadings = false,
    this.teamProfiles = const [],
    this.identityScope = const IdentityScope.device(),
    this.filterStore = const SharedPreferencesRadarAudienceFilterStore(),
    super.key,
  });

  final List<MatchBoardItem> matches;

  /// All fixtures loaded from the same snapshot. They carry the global form
  /// profiles; [matches] remains the selected calendar day's fixture list.
  final List<MatchBoardItem> radarSourceMatches;

  /// Matches analyzed with the account's enabled readings and scenarios across
  /// all loaded competitions, including competitions the account does not
  /// follow. These determine which Lector readings appear on a Radar card.
  final List<MatchBoardItem> personalizedMatches;
  final bool showProfileReadings;
  final DateTime selectedDate;
  final ValueChanged<MatchBoardItem> onOpenMatch;
  final List<TeamFormRadarProfile> teamProfiles;
  final IdentityScope identityScope;
  final RadarAudienceFilterStore filterStore;

  @override
  State<PlayerFormRadarPage> createState() => _PlayerFormRadarPageState();
}

class _PlayerFormRadarPageState extends State<PlayerFormRadarPage> {
  int _playerPage = 0;
  int _teamPage = 0;
  _RadarContentMode _mode = _RadarContentMode.players;
  _RadarScope _scope = _RadarScope.club;
  RadarAudienceFilter _audienceFilter = const RadarAudienceFilter();
  int _filterGeneration = 0;
  Future<void> _pendingSave = Future.value();

  @override
  void initState() {
    super.initState();
    _restoreFilters();
  }

  @override
  void didUpdateWidget(PlayerFormRadarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identityScope != widget.identityScope ||
        oldWidget.filterStore != widget.filterStore) {
      _audienceFilter = const RadarAudienceFilter();
      _playerPage = 0;
      _teamPage = 0;
      _restoreFilters();
    }
  }

  Future<void> _restoreFilters() async {
    final generation = ++_filterGeneration;
    final store = widget.filterStore;
    final scope = widget.identityScope;
    try {
      await _pendingSave;
      final filter = await store.load(scope);
      if (!mounted || generation != _filterGeneration) return;
      setState(() => _audienceFilter = filter);
    } on Object {
      // Storage failures keep the safe defaults and never block the Radar.
    }
  }

  Future<void> _chooseFilters() async {
    final scope = widget.identityScope;
    final filter = await showModalBottomSheet<RadarAudienceFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _RadarAudienceFilterSheet(initial: _audienceFilter),
    );
    if (!mounted || filter == null || scope != widget.identityScope) return;
    ++_filterGeneration;
    setState(() {
      _audienceFilter = filter;
      _playerPage = 0;
      _teamPage = 0;
    });
    final store = widget.filterStore;
    _pendingSave = _pendingSave.then((_) async {
      try {
        await store.save(scope, filter);
      } on Object {
        // Apply the current choice even if this device cannot persist it.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fixtureSnapshot = formRadarFixtureEnabled
        ? playerFormRadarFixtureForDate(widget.selectedDate)
        : null;
    final profiles =
        fixtureSnapshot?.profiles ??
        _profilesForMatches(widget.radarSourceMatches);
    final dataAsOf =
        fixtureSnapshot?.asOf ?? _latestRadarAsOf(widget.radarSourceMatches);
    final ranked = PlayerFormRadarRanker.rank(profiles);
    final teamProfiles = formRadarFixtureEnabled
        ? _teamProfilesFromPlayerFixture(profiles, widget.matches)
        : widget.teamProfiles.isNotEmpty
        ? widget.teamProfiles
        : _teamProfilesForMatches(widget.radarSourceMatches);
    final rankedTeams = TeamFormRadarRanker.rank(teamProfiles);
    final competitionNames = <int, String>{
      for (final match in widget.radarSourceMatches)
        if (match.competition.apiFootballLeagueId case final int id)
          id: match.competition.name,
    };
    final isTeamRadar = _mode == _RadarContentMode.teams;
    final allScoped = ranked
        .where((entry) => _scope.includesLeague(entry.profile.leagueId))
        .toList(growable: false);
    final allScopedTeams = rankedTeams
        .where((entry) => _scope.includesLeague(entry.profile.leagueId))
        .toList(growable: false);
    final scoped = allScoped
        .where((entry) {
          final profile = entry.profile;
          final competitionName =
              competitionNames[profile.leagueId] ??
              profile.activity.reversed
                  .map((match) => match.competitionName)
                  .whereType<String>()
                  .firstOrNull ??
              '';
          return _audienceFilter.includes(
            leagueId: profile.leagueId,
            teamName: profile.teamName,
            competitionName: competitionName,
          );
        })
        .toList(growable: false);
    final scopedTeams = allScopedTeams
        .where(
          (entry) => _audienceFilter.includes(
            leagueId: entry.profile.leagueId,
            teamName: entry.profile.teamName,
            competitionName: entry.profile.leagueName,
          ),
        )
        .toList(growable: false);
    final hiddenCount = isTeamRadar
        ? allScopedTeams.length - scopedTeams.length
        : allScoped.length - scoped.length;
    final cappedPlayers = scoped.take(_radarTopLimit).toList(growable: false);
    final cappedTeams = scopedTeams
        .take(_radarTopLimit)
        .toList(growable: false);
    final playerPage = _playerPage
        .clamp(0, _lastPage(cappedPlayers.length, _radarPageSize))
        .toInt();
    final teamPage = _teamPage
        .clamp(0, _lastPage(cappedTeams.length, _radarPageSize))
        .toInt();
    final visible = _pageSlice(cappedPlayers, playerPage, _radarPageSize);
    final visibleTeams = _pageSlice(cappedTeams, teamPage, _radarPageSize);
    final allowedMatches = widget.matches
        .where(_audienceFilter.includesMatch)
        .toList(growable: false);
    final radarMatches = _matchesWithHotPlayers(allowedMatches, scoped);
    final teamRadarMatches = _matchesWithTeams(allowedMatches, scopedTeams);
    final personalizedMatchesById = {
      for (final match in widget.personalizedMatches) match.id: match,
    };

    return Column(
      key: const ValueKey('player-form-radar-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Radar',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('radar-audience-filters'),
                  onPressed: _chooseFilters,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  label: Text(
                    _audienceFilter.exclusionCount == 0
                        ? 'Filtres'
                        : 'Filtres (${_audienceFilter.exclusionCount})',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              isTeamRadar
                  ? 'Les équipes les plus en forme ${_scope.label}'
                  : 'Les joueurs chauds ${_scope.label}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_audienceFilter.label}'
          '${hiddenCount == 0 ? '' : ' · $hiddenCount profil${hiddenCount > 1 ? 's' : ''} masqué${hiddenCount > 1 ? 's' : ''}'}',
          key: const ValueKey('radar-audience-summary'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textColors.secondary),
        ),
        const SizedBox(height: AppSpacing.md),
        _RadarModeToggle(
          selected: _mode,
          onChanged: (mode) => setState(() {
            _mode = mode;
            _playerPage = 0;
            _teamPage = 0;
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
        _RadarScopeFilterControl(
          totalPlayerCount: isTeamRadar
              ? cappedTeams.length
              : cappedPlayers.length,
          scope: _scope,
          onChanged: (scope) => setState(() {
            _scope = scope;
            _playerPage = 0;
            _teamPage = 0;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        if (isTeamRadar)
          _HotTeamsPanel(
            matches: widget.matches,
            entries: visibleTeams,
            totalCount: cappedTeams.length,
            page: teamPage,
            onPageChanged: (page) => setState(() => _teamPage = page),
          )
        else
          _HotPlayersPanel(
            entries: visible,
            totalCount: cappedPlayers.length,
            hasRadarData: profiles.isNotEmpty,
            page: playerPage,
            onPageChanged: (page) => setState(() => _playerPage = page),
            matches: widget.matches,
            onOpenMatch: widget.onOpenMatch,
          ),
        const SizedBox(height: AppSpacing.lg),
        if (isTeamRadar)
          _TeamRadarMatchesSection(
            matches: teamRadarMatches,
            personalizedMatchesById: personalizedMatchesById,
            showProfileReadings: widget.showProfileReadings,
            onOpenMatch: widget.onOpenMatch,
          )
        else
          _RadarMatchesSection(
            matches: radarMatches,
            entries: scoped,
            personalizedMatchesById: personalizedMatchesById,
            showProfileReadings: widget.showProfileReadings,
            onOpenMatch: widget.onOpenMatch,
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _RadarAudienceFilterSheet extends StatefulWidget {
  const _RadarAudienceFilterSheet({required this.initial});

  final RadarAudienceFilter initial;

  @override
  State<_RadarAudienceFilterSheet> createState() =>
      _RadarAudienceFilterSheetState();
}

class _RadarAudienceFilterSheetState extends State<_RadarAudienceFilterSheet> {
  late RadarAudienceFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtres du radar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Choisissez les catégories à explorer. Le filtre s’applique aux '
              'joueurs, aux équipes et aux matchs proposés dans le radar.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.textColors.secondary,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              key: const ValueKey('radar-include-women'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Inclure le football féminin'),
              subtitle: const Text('Joueuses, clubs et sélections féminines.'),
              value: _draft.includeWomen,
              onChanged: (value) => setState(
                () => _draft = RadarAudienceFilter(
                  includeWomen: value,
                  includeYouth: _draft.includeYouth,
                ),
              ),
            ),
            SwitchListTile.adaptive(
              key: const ValueKey('radar-include-youth'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Inclure les équipes de jeunes'),
              subtitle: const Text(
                'U17, U19, U20, U21, U23… équipes et joueurs.',
              ),
              value: _draft.includeYouth,
              onChanged: (value) => setState(
                () => _draft = RadarAudienceFilter(
                  includeWomen: _draft.includeWomen,
                  includeYouth: value,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(
                    () => _draft = const RadarAudienceFilter(
                      includeWomen: true,
                      includeYouth: true,
                    ),
                  ),
                  child: const Text('Tout inclure'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _draft = const RadarAudienceFilter()),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Réinitialiser'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('radar-apply-audience-filters'),
                onPressed: () => Navigator.pop(context, _draft),
                child: const Text('Appliquer'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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

enum _RadarScope {
  club,
  nationalTeam;

  String get label => switch (this) {
    _RadarScope.club => 'en club',
    _RadarScope.nationalTeam => 'en équipe nationale',
  };

  bool includesLeague(int leagueId) => switch (this) {
    _RadarScope.club => !_nationalTeamCompetitionLeagueIds.contains(leagueId),
    _RadarScope.nationalTeam => _nationalTeamCompetitionLeagueIds.contains(
      leagueId,
    ),
  };
}

const _nationalTeamCompetitionLeagueIds = <int>{
  1, // Coupe du Monde
  4, // Euro
  5, // UEFA Nations League
  6, // Coupe d’Afrique des Nations
  7, // Coupe d’Asie
  8, // Coupe du Monde féminine
  9, // Copa America
  10, // Matchs amicaux internationaux
  22, // CONCACAF Gold Cup
  32, // Qualifications Coupe du Monde Europe
  38, // Euro U21
  536, // CONCACAF Nations League
};

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

class _RadarScopeFilterControl extends StatelessWidget {
  const _RadarScopeFilterControl({
    required this.totalPlayerCount,
    required this.scope,
    required this.onChanged,
  });

  final int totalPlayerCount;
  final _RadarScope scope;
  final ValueChanged<_RadarScope> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
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
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                _ScopeFilterOption(
                  key: const ValueKey('form-radar-scope-club'),
                  icon: Icons.shield_outlined,
                  label: 'Club',
                  selected: scope == _RadarScope.club,
                  onTap: () => onChanged(_RadarScope.club),
                ),
                const SizedBox(width: 6),
                _ScopeFilterOption(
                  key: const ValueKey('form-radar-scope-national-team'),
                  icon: Icons.public_rounded,
                  label: 'Équipe nationale',
                  selected: scope == _RadarScope.nationalTeam,
                  onTap: () => onChanged(_RadarScope.nationalTeam),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    ),
  );
}

class _ScopeFilterOption extends StatelessWidget {
  const _ScopeFilterOption({
    required super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? context.brand.accent.withValues(alpha: .14)
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: selected ? context.brand.accent : AppColors.transparent,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? context.brand.accent
                      : context.textColors.secondary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? context.brand.accent
                          : context.textColors.secondary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _HotPlayersPanel extends StatelessWidget {
  const _HotPlayersPanel({
    required this.entries,
    required this.totalCount,
    required this.hasRadarData,
    required this.page,
    required this.onPageChanged,
    required this.matches,
    required this.onOpenMatch,
  });
  final List<PlayerFormRadarEntry> entries;
  final int totalCount;
  final bool hasRadarData;
  final int page;
  final ValueChanged<int> onPageChanged;
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
                        'Top $totalCount',
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
                      FormRadarPeriodLabel(columnCount: matrixColumns),
                    ],
                  ),
                  Divider(height: 18, color: context.surfaces.border),
                  for (final indexed in entries.indexed) ...[
                    _PremiumRadarEntryCard(
                      child: _HotPlayerRow(
                        rank: page * _radarPageSize + indexed.$1 + 1,
                        entry: indexed.$2,
                        match: _matchForTeam(
                          matches,
                          indexed.$2.profile.teamId,
                        ),
                        onOpenMatch: onOpenMatch,
                        matrixColumns: matrixColumns,
                      ),
                    ),
                  ],
                  if (totalCount > _radarPageSize)
                    _RadarPagination(
                      keyPrefix: 'player',
                      itemCount: totalCount,
                      page: page,
                      pageSize: _radarPageSize,
                      onPageChanged: onPageChanged,
                    ),
                ],
              ),
      ),
    );
  }
}

class _HotTeamsPanel extends StatelessWidget {
  const _HotTeamsPanel({
    required this.entries,
    this.matches = const [],
    required this.totalCount,
    required this.page,
    required this.onPageChanged,
  });

  final List<TeamFormRadarEntry> entries;
  final List<MatchBoardItem> matches;
  final int totalCount;
  final int page;
  final ValueChanged<int> onPageChanged;

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
                      'Top $totalCount',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final indexed in entries.indexed) ...[
                  _PremiumRadarEntryCard(
                    child: _HotTeamRow(
                      rank: page * _radarPageSize + indexed.$1 + 1,
                      entry: indexed.$2,
                      match: _matchForTeam(matches, indexed.$2.profile.teamId),
                    ),
                  ),
                ],
                if (totalCount > _radarPageSize)
                  _RadarPagination(
                    keyPrefix: 'team',
                    itemCount: totalCount,
                    page: page,
                    pageSize: _radarPageSize,
                    onPageChanged: onPageChanged,
                  ),
              ],
            ),
    ),
  );
}

class _PremiumRadarEntryCard extends StatelessWidget {
  const _PremiumRadarEntryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.control);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: context.surfaces.surface,
        elevation: 2,
        shadowColor: context.surfaces.shadow.withValues(alpha: .16),
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: context.surfaces.border.withValues(alpha: .8),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RadarPagination extends StatelessWidget {
  const _RadarPagination({
    required this.keyPrefix,
    required this.itemCount,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
  });

  final String keyPrefix;
  final int itemCount;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pageCount = _lastPage(itemCount, pageSize) + 1;
    final first = itemCount == 0 ? 0 : page * pageSize + 1;
    final last = ((page + 1) * pageSize).clamp(0, itemCount);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.surfaces.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: context.surfaces.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              IconButton(
                key: ValueKey('$keyPrefix-previous'),
                tooltip: 'Page précédente',
                onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$first–$last sur $itemCount',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Page ${page + 1} sur $pageCount',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('$keyPrefix-next'),
                tooltip: 'Page suivante',
                onPressed: page + 1 < pageCount
                    ? () => onPageChanged(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _lastPage(int itemCount, int pageSize) =>
    itemCount == 0 ? 0 : (itemCount - 1) ~/ pageSize;

List<T> _pageSlice<T>(List<T> entries, int page, int pageSize) =>
    entries.skip(page * pageSize).take(pageSize).toList(growable: false);

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
  const _HotTeamRow({required this.rank, required this.entry, this.match});

  final int rank;
  final TeamFormRadarEntry entry;
  final MatchBoardItem? match;

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
  Widget build(BuildContext context) => LiveFixtureBuilder(
    fixtureId: match?.fixture.apiFootballFixtureId,
    builder: (context, state) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state?.isLive == true)
          Align(
            alignment: Alignment.centerRight,
            child: LectorLiveBadge(state: state!.temporal),
          ),
        _buildRow(context),
      ],
    ),
  );
  Widget _buildRow(BuildContext context) {
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
          if (historyColumns > 0) ...[
            SizedBox(
              width: _cellsWidth(historyColumns),
              child: Align(
                alignment: Alignment.centerRight,
                child: _RadarCellStrip(matches: prior, onMatchTap: onMatchTap),
              ),
            ),
            _MatrixDivider(color: context.brand.accent),
          ],
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

double _matrixWidth(int columnCount) => formRadarMatrixWidth(columnCount);

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
    required this.personalizedMatchesById,
    required this.showProfileReadings,
    required this.onOpenMatch,
  });

  final List<MatchBoardItem> matches;
  final Map<String, MatchBoardItem> personalizedMatchesById;
  final bool showProfileReadings;
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
            MatchFeedCard(
              match: match,
              showCompetitionHeader: false,
              radarEntries: const [],
              readingMatch: personalizedMatchesById[match.id],
              showReadings:
                  showProfileReadings &&
                  personalizedMatchesById.containsKey(match.id),
              onTap: () => onOpenMatch(
                showProfileReadings
                    ? personalizedMatchesById[match.id] ?? match
                    : match,
              ),
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
    required this.personalizedMatchesById,
    required this.showProfileReadings,
    required this.onOpenMatch,
  });
  final List<MatchBoardItem> matches;
  final List<PlayerFormRadarEntry> entries;
  final Map<String, MatchBoardItem> personalizedMatchesById;
  final bool showProfileReadings;
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
            MatchFeedCard(
              match: match,
              showCompetitionHeader: false,
              radarEntries: _entriesForMatch(entries, match),
              readingMatch: personalizedMatchesById[match.id],
              showReadings:
                  showProfileReadings &&
                  personalizedMatchesById.containsKey(match.id),
              onTap: () => onOpenMatch(
                showProfileReadings
                    ? personalizedMatchesById[match.id] ?? match
                    : match,
              ),
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

List<TeamFormRadarProfile> _teamProfilesForMatches(
  List<MatchBoardItem> matches,
) {
  final values = <String, TeamFormRadarProfile>{};
  for (final match in matches) {
    final leagueId = match.competition.apiFootballLeagueId;
    if (leagueId == null) continue;
    final knownTeams = <int, TeamInfo>{
      if (match.homeTeam.apiFootballTeamId != null)
        match.homeTeam.apiFootballTeamId!: match.homeTeam,
      if (match.awayTeam.apiFootballTeamId != null)
        match.awayTeam.apiFootballTeamId!: match.awayTeam,
    };
    final standingNames = <int, String>{
      for (final standing in match.analysis.leagueStandings)
        standing.teamId: standing.teamName,
    };
    for (final entry in match.analysis.leagueRecentLeagueMatches.entries) {
      final teamId = entry.key;
      final activity = entry.value;
      if (activity.isEmpty) continue;
      final ordered = [...activity]
        ..sort((left, right) {
          final leftDate =
              left.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate =
              right.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return leftDate.compareTo(rightDate);
        });
      final knownTeam = knownTeams[teamId];
      final name =
          knownTeam?.name ??
          standingNames[teamId] ??
          ordered
              .map((item) => item.teamName)
              .whereType<String>()
              .firstOrNull ??
          'Équipe';
      final logoUrl =
          knownTeam?.logoUrl ??
          ordered
              .map((item) => item.teamLogoUrl)
              .whereType<String>()
              .firstOrNull ??
          _apiFootballTeamLogoUrl(teamId);
      values.putIfAbsent(
        '$leagueId:$teamId',
        () => TeamFormRadarProfile(
          teamId: teamId,
          teamName: name,
          logoUrl: logoUrl,
          leagueId: leagueId,
          leagueName: match.competition.name,
          activity: ordered,
        ),
      );
    }
  }
  return values.values.toList(growable: false);
}

String _apiFootballTeamLogoUrl(int teamId) =>
    'https://media.api-sports.io/football/teams/$teamId.png';

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
