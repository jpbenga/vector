import '../../../core/widgets/lector_live_badge.dart';
import '../../matches/presentation/widgets/live_fixture_builder.dart';
import '../../../core/widgets/lector_player_radar.dart';
import '../../../core/widgets/lector_radar.dart';
import '../../../core/widgets/lector_competition_browser.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/identity/identity_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../matches/domain/match_board_item.dart';
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
  Widget build(BuildContext context) => LectorRadarModeToggle(
    firstLabel: 'Joueurs',
    secondLabel: 'Équipes',
    secondSelected: selected == _RadarContentMode.teams,
    onChanged: (second) =>
        onChanged(second ? _RadarContentMode.teams : _RadarContentMode.players),
  );
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final historyCount = entries.fold<int>(
        PlayerFormRadarRanker.recentWindow,
        (current, entry) => entry.profile.activity.length > current
            ? entry.profile.activity.length
            : current,
      );
      final matrixColumns = lectorPlayerMatrixColumns(
        historyCount,
        constraints.maxWidth - 24,
      );
      return LectorRadarRankingPanel(
        title: 'Joueurs les plus chauds',
        totalCount: totalCount,
        icon: Icons.local_fire_department_rounded,
        emptyState: _RadarEmptyState(hasRadarData: hasRadarData),
        description: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: LectorPlayerRadarLegend()),
                const SizedBox(width: 12),
                FormRadarPeriodLabel(columnCount: matrixColumns),
              ],
            ),
            Divider(height: 18, color: context.surfaces.border),
          ],
        ),
        footer: totalCount > _radarPageSize
            ? LectorRadarPagination(
                keyPrefix: 'player',
                itemCount: totalCount,
                page: page,
                pageSize: _radarPageSize,
                onPageChanged: onPageChanged,
              )
            : null,
        children: [
          for (final indexed in entries.indexed)
            LectorRadarEntryCard(
              child: _HotPlayerRow(
                rank: page * _radarPageSize + indexed.$1 + 1,
                entry: indexed.$2,
                match: _matchForTeam(matches, indexed.$2.profile.teamId),
                onOpenMatch: onOpenMatch,
                matrixColumns: matrixColumns,
              ),
            ),
        ],
      );
    },
  );
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
  Widget build(BuildContext context) => LectorRadarRankingPanel(
    title: 'Équipes les plus chaudes',
    totalCount: totalCount,
    description: const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Points sur 5 matchs. À égalité : 6ᵉ match, puis 7ᵉ, etc.'),
          SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: LectorTeamFormHistoryLegend(),
          ),
        ],
      ),
    ),
    emptyState: const _TeamRadarEmptyState(),
    footer: totalCount > _radarPageSize
        ? LectorRadarPagination(
            keyPrefix: 'team',
            itemCount: totalCount,
            page: page,
            pageSize: _radarPageSize,
            onPageChanged: onPageChanged,
          )
        : null,
    children: [
      for (final indexed in entries.indexed)
        LectorRadarEntryCard(
          child: _HotTeamRow(
            rank: page * _radarPageSize + indexed.$1 + 1,
            entry: indexed.$2,
            match: _matchForTeam(matches, indexed.$2.profile.teamId),
          ),
        ),
    ],
  );
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
        'Le Radar équipe attend au moins cinq matchs de championnat terminés.',
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
  Widget _buildRow(BuildContext context) => LectorRadarTeamRow(
    rank: rank,
    name: entry.profile.teamName,
    logoUrl: entry.profile.logoUrl,
    competitionName: entry.profile.leagueName,
    metric: '${entry.points}/15',
    streakLabel: entry.streakLabel,
    activity: LectorFormResultStrip(
      historyColumns: 5,
      results: entry.profile.activity.map((m) => m.result).toList(),
      tooltips: [
        for (final m in entry.profile.activity)
          '${m.playedAt == null ? '' : DateFormat('dd/MM').format(m.playedAt!.toLocal())} · ${m.venue == RecentMatchVenue.home ? 'Dom.' : 'Ext.'} · ${m.opponentName}${m.goalsFor == null || m.goalsAgainst == null ? '' : ' · ${m.goalsFor}–${m.goalsAgainst}'}',
      ],
      onMatchTap: (index) => showTeamFormRadarMatchDetail(
        context,
        profile: entry.profile,
        initialIndex: index,
      ),
    ),
  );
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
    return LectorRadarPlayerRow(
      rank: rank,
      name: entry.profile.playerName,
      teamName: entry.profile.teamName,
      photoUrl: entry.profile.photoUrl,
      teamLogoUrl: teamLogoUrl,
      recentLine: recentLine,
      stats: stats,
      onTap: match == null ? null : () => onOpenMatch(match!),
      activity: LectorPlayerActivityMatrix(
        activity: entry.profile.activity.map(footballPlayerActivity).toList(),
        columnCount: matrixColumns,
        onMatchTap: (index) => showPlayerFormRadarMatchDetail(
          context,
          profile: entry.profile,
          activity: entry.profile.activity,
          initialFixtureId: entry.profile.activity[index].fixtureId,
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) => LectorCompetitionHeader(
    name: matches.first.competition.name,
    count: matches.length,
    flagUrl: matches.first.competition.country.flagUrl,
    logoUrl: matches.first.competition.logoUrl,
    country: matches.first.competition.country.name,
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
  final source = profile.activity;
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

String? _teamLogoForMatch(MatchBoardItem? match, int teamId) {
  if (match == null) return null;
  if (match.homeTeam.apiFootballTeamId == teamId) return match.homeTeam.logoUrl;
  if (match.awayTeam.apiFootballTeamId == teamId) return match.awayTeam.logoUrl;
  return null;
}
