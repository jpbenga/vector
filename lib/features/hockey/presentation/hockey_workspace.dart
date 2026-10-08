import '../../../core/widgets/lector_deferred_content.dart';
import '../../../core/data/read_recovery.dart';
import '../../../core/widgets/lector_loading.dart';
import '../../generator/presentation/lector_generator_page.dart';
import '../../generator/domain/generator_context.dart';
import '../../onboarding/data/saved_decision_profile_store.dart';
import '../../onboarding/domain/profile_compiler.dart';
import '../../../app/sports/generator_match_navigation.dart';
import '../../../core/sports/data/sport_live_repository.dart';
import '../../../core/widgets/lector_personalize_invitation.dart';
import '../../../core/identity/identity_controller.dart';
import '../../../core/identity/identity_scope.dart';
import '../../../core/identity/device_identity_store.dart';
import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_reading_preferences.dart';
import '../../../core/sports/data/sport_reading_preferences_store.dart';
import '../../../core/sports/presentation/sport_reading_preferences_page.dart';
import '../../../core/sports/presentation/sport_space_page.dart';
import '../../../core/sports/presentation/sport_reading_insights.dart';
import '../domain/hockey_feed_readings.dart';
import '../../../core/widgets/lector_temporal_feed.dart';
import '../../../core/widgets/lector_live_badge.dart';
import '../../../app/auth/lector_account_sheet.dart';
import '../../../core/widgets/lector_player_radar.dart';
import '../domain/hockey_player_radar.dart';
import '../domain/hockey_team_radar.dart';
import 'hockey_player_radar_panel.dart';
import '../../../core/widgets/lector_competition_browser.dart';
import '../../../core/widgets/lector_radar.dart';
import 'hockey_country_presentation.dart';
import 'hockey_match_detail_page.dart';
import '../../../core/auth/user_presentation.dart';
import 'package:flutter/material.dart';
import '../../../core/domain/lector_temporal_state.dart';
import '../../../core/auth/supabase_auth_controller.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/sports/domain/sport_competition_context.dart';
import '../../../core/sports/domain/sport_feed_repository.dart';
import '../../../core/sports/domain/sport_fixture.dart';
import '../../../core/sports/domain/sport_module.dart';
import '../../../core/sports/presentation/sport_fixture_card.dart';
import '../../../core/widgets/lector_calendar.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import '../../../core/widgets/lector_workspace_header.dart';
import '../../../core/widgets/lector_workspace_navigation.dart';
import '../domain/hockey_module.dart';
import 'hockey_context_panels.dart';

/// Sport-specific data and policies composed into the shared Lector workspace.
class HockeyWorkspace extends StatefulWidget {
  const HockeyWorkspace({
    this.repository,
    this.liveRepository,
    this.initialDate,
    this.preferencesStore = const SportReadingPreferencesStore(),
    this.preferenceScope,
    super.key,
  });
  final SportFeedRepository? repository;
  final SportLiveRepository? liveRepository;
  final DateTime? initialDate;
  final SportReadingPreferencesStore preferencesStore;
  final IdentityScope? preferenceScope;
  @override
  State<HockeyWorkspace> createState() => _HockeyWorkspaceState();
}

class _HockeyWorkspaceState extends State<HockeyWorkspace> {
  LectorWorkspaceSection _section = LectorWorkspaceSection.forMe;
  late DateTime _date;
  SportFeedResult? _feed;
  bool _loading = false, _failed = false, _teamsSelected = false;
  late final ReadRecovery _recovery;
  DateTime? _feedDate;
  int _request = 0, _page = 0;
  SportLiveController? _live;
  String? _league;
  final _readings = const HockeyFeedReadings();
  final _preferenceState = ValueNotifier(
    SportReadingPreferences(sport: SportId.hockey),
  );
  SportReadingPreferences get _preferences => _preferenceState.value;
  set _preferences(SportReadingPreferences value) =>
      _preferenceState.value = value;
  IdentityScope? _scope;
  Listenable? _identity;
  bool _preferencesReady = false;
  int _preferenceRequest = 0;
  @override
  void initState() {
    super.initState();
    _recovery = ReadRecovery(
      onConnectionReturn: () {
        if (mounted) _load();
      },
    );
    final now = widget.initialDate ?? DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _identity = getIt.isRegistered<IdentityController>()
        ? getIt<IdentityController>()
        : getIt.isRegistered<SupabaseAuthController>()
        ? getIt<SupabaseAuthController>()
        : null;
    _identity?.addListener(_reloadPreferences);
    _reloadPreferences();
    if (widget.liveRepository != null) {
      _live = SportLiveController(
        sport: SportId.hockey,
        repository: widget.liveRepository!,
      );
      _live!.addListener(_liveChanged);
    }
    _load();
  }

  void _liveChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant HockeyWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferenceScope != widget.preferenceScope ||
        oldWidget.preferencesStore != widget.preferencesStore) {
      _reloadPreferences();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _recovery.setActive(TickerMode.valuesOf(context).enabled);
  }

  @override
  void dispose() {
    _request++;
    _recovery.dispose();
    final repository = widget.repository;
    if (repository is PreloadingSportFeedRepository) {
      repository.cancelPrefetch();
    }
    _preferenceRequest++;
    _live?.removeListener(_liveChanged);
    _live?.dispose();
    _identity?.removeListener(_reloadPreferences);
    _preferenceState.dispose();
    super.dispose();
  }

  Future<void> _reloadPreferences() async {
    final generation = ++_preferenceRequest;
    // Clear immediately on account switch/logout, including while a read waits.
    setState(() {
      _preferences = SportReadingPreferences(sport: SportId.hockey);
      _preferencesReady = false;
      _scope = null;
    });
    try {
      final identity = getIt.isRegistered<IdentityController>()
          ? getIt<IdentityController>()
          : null;
      final auth = getIt.isRegistered<SupabaseAuthController>()
          ? getIt<SupabaseAuthController>()
          : null;
      final scope =
          widget.preferenceScope ??
          (identity != null
              ? identity.scope
              : auth?.user != null
              ? IdentityScope.account(auth!.user!.id)
              : IdentityScope.guest(
                  await const DeviceIdentityStore()
                      .currentOrRotateConsumedGuestId(),
                ));
      final preferences = scope?.isUserOwned == true
          ? await widget.preferencesStore.load(scope!, SportId.hockey)
          : SportReadingPreferences(sport: SportId.hockey);
      if (!mounted || generation != _preferenceRequest) return;
      setState(() {
        _scope = scope;
        _preferences = preferences;
        _preferencesReady = true;
      });
    } on Object {
      if (mounted && generation == _preferenceRequest) {
        setState(() => _preferencesReady = true);
      }
    }
  }

  Future<void> _openPreferences({
    BuildContext? navigationContext,
    SportPreferenceSection section = SportPreferenceSection.all,
  }) async {
    final scope = _scope;
    final generation = _preferenceRequest;
    if (scope == null || _competitions.isEmpty) return;
    await Navigator.of(navigationContext ?? context).push(
      MaterialPageRoute<void>(
        builder: (_) => SportReadingPreferencesPage(
          module: HockeyModule.definition,
          competitions: _competitions,
          initial: _preferences,
          section: section,
          onSave: (preferences) async {
            if (!mounted ||
                _scope != scope ||
                _preferenceRequest != generation) {
              return false;
            }
            await widget.preferencesStore.save(scope, preferences);
            if (!mounted ||
                _scope != scope ||
                _preferenceRequest != generation) {
              return false;
            }
            setState(() => _preferences = preferences);
            return true;
          },
        ),
      ),
    );
  }

  Future<void> _openSpace() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (spaceContext) => SportSpacePage(
          preferences: _preferenceState,
          onOpenCompetitions: () => _openPreferences(
            navigationContext: spaceContext,
            section: SportPreferenceSection.competitions,
          ),
          onOpenReadings: () => _openPreferences(
            navigationContext: spaceContext,
            section: SportPreferenceSection.readings,
          ),
          onOpenAccount: () => showLectorAccountSheet(spaceContext),
        ),
      ),
    );
  }

  void _selectDate(DateTime value) {
    setState(() => _date = value);
    _load();
  }

  Widget _loadingContent() => ListenableBuilder(
    listenable: _recovery,
    builder: (context, _) => LectorLoading(
      kind: _section == LectorWorkspaceSection.radar
          ? LectorSkeletonKind.radar
          : LectorSkeletonKind.matches,
      label: 'Chargement des rencontres du ${_date.day}/${_date.month}…',
      recovering: _recovery.recovering,
    ),
  );

  Future<void> _load({bool force = false}) async {
    final generation = ++_request;
    final requestedDate = _date;
    final requestedSection = _section;
    final repository = widget.repository;
    final cached = !force && repository is PreloadingSportFeedRepository
        ? repository.peek(
            _date,
            radar: _section == LectorWorkspaceSection.radar,
          )
        : null;
    if (cached != null) {
      setState(() {
        _feed = cached;
        _feedDate = _date;
        _loading = false;
        _failed = false;
        _page = 0;
      });
      _live?.watch(_dayMatches);
    }
    setState(() {
      _loading =
          cached == null &&
          (!force || _feedDate != _date || _feed?.snapshot == null);
      _failed = false;
    });
    try {
      final result = await _recovery.read(() async {
        final refreshed = force && repository is RefreshableSportFeedRepository
            ? await repository.refresh(requestedDate)
            : null;
        return await (requestedSection == LectorWorkspaceSection.radar &&
                    repository is ProgressiveSportFeedRepository
                ? repository.loadRadar(requestedDate)
                : refreshed != null
                ? Future.value(refreshed)
                : repository?.load(requestedDate)) ??
            const SportFeedResult.unavailable(
              SportFeedUnavailableReason.notConnected,
            );
      });
      if (!mounted || generation != _request) return;
      setState(() {
        _feed = result;
        _feedDate = _date;
        _loading = false;
        _page = 0;
      });
      // Score updates do not recompute or replace prematch evidence.
      _live?.watch(_dayMatches);
      if (repository is PreloadingSportFeedRepository) {
        repository.prefetch(_date);
      }
    } catch (error) {
      if (error is ReadCancelled) return;
      if (!mounted || generation != _request) return;
      setState(() {
        if (_feedDate != _date) _feed = null;
        _failed = true;
        _loading = false;
      });
    }
  }

  List<SportCompetitionContext> get _competitions =>
      _feed?.snapshot?.competitions ?? const [];
  List<SportCompetitionContext> get _filteredCompetitions => _competitions
      .where((c) => _league == null || c.id.value == _league)
      .toList();
  String get _unavailable => _failed
      ? 'La source hockey est momentanément indisponible. Vous pouvez continuer à naviguer.'
      : switch (_feed?.unavailableReason) {
          SportFeedUnavailableReason.stale =>
            'La collecte hockey doit être actualisée.',
          SportFeedUnavailableReason.outsideWindow =>
            'Cette date est hors de la fenêtre collectée.',
          SportFeedUnavailableReason.notPublished =>
            'La publication hockey est en préparation.',
          _ => 'Aucune rencontre hockey chargée',
        };
  @override
  Widget build(BuildContext context) {
    final auth = getIt.isRegistered<SupabaseAuthController>()
        ? getIt<SupabaseAuthController>()
        : null;
    Widget identity() => LectorIdentityButton(
      tooltip: auth?.isSignedIn == true ? 'Compte' : 'Connexion',
      label: auth?.isSignedIn == true
          ? lectorInitialsForUser(auth?.user)
          : null,
      icon: auth?.isSignedIn == true ? null : Icons.person_outline_rounded,
      onPressed: () => showLectorAccountSheet(context),
    );
    if (_section == LectorWorkspaceSection.generator &&
        const bool.fromEnvironment('LECTOR_GENERATOR_UI')) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: LectorWorkspaceNavigation(
                  selected: _section,
                  onChanged: (value) {
                    setState(() {
                      _section = value;
                      _page = 0;
                    });
                    _load();
                  },
                ),
              ),
              Expanded(child: _generator(context)),
            ],
          ),
        ),
      );
    }
    return ListView(
      key: const ValueKey('hockey-workspace'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: [
        LectorContent(
          maxWidth: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LectorWorkspaceHeader(
                identity: auth == null
                    ? identity()
                    : ListenableBuilder(
                        listenable: auth,
                        builder: (context, _) => identity(),
                      ),
                onOpenSettings: _openSpace,
              ),
              const SizedBox(height: 8),
              if (_section != LectorWorkspaceSection.bilan)
                CopilotCalendar(
                  selectedDate: _date,
                  visibleWindowDays: 31,
                  onDateSelected: _selectDate,
                  onChooseDate: () async {
                    final now = widget.initialDate ?? DateTime.now();
                    final chosen = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(now.year, now.month, now.day - 7),
                      lastDate: DateTime(now.year, now.month, now.day + 13),
                    );
                    if (chosen != null && mounted) _selectDate(chosen);
                  },
                ),
              const SizedBox(height: 8),
              LectorWorkspaceNavigation(
                selected: _section,
                onChanged: (value) {
                  setState(() {
                    _section = value;
                    _page = 0;
                  });
                  if (value == LectorWorkspaceSection.generator ||
                      value == LectorWorkspaceSection.bilan) {
                    _request++;
                    _recovery.cancel();
                    setState(() => _loading = false);
                  } else {
                    _load();
                  }
                },
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: _recovery,
                builder: (context, _) => _recovery.inProgress && !_loading
                    ? const LectorRefreshStatus()
                    : const SizedBox.shrink(),
              ),
              if (_failed && _feedDate == _date && _feed?.snapshot != null)
                _notice(
                  'Actualisation momentanément indisponible. Dernières données reçues conservées.',
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _section == LectorWorkspaceSection.radar
                          ? 'Radar · Hockey'
                          : _section == LectorWorkspaceSection.all
                          ? 'Tous les matchs'
                          : 'Hockey',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('hockey-preferences'),
                    tooltip: 'Mes préférences hockey',
                    onPressed:
                        _preferencesReady &&
                            _scope != null &&
                            _competitions.isNotEmpty
                        ? _openPreferences
                        : null,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                  IconButton(
                    key: const ValueKey('hockey-rules'),
                    tooltip: 'Lectures et scénarios hockey',
                    onPressed: _showRules,
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                  IconButton(
                    key: const ValueKey('hockey-refresh'),
                    tooltip: 'Relire la publication',
                    onPressed: _loading ? null : () => _load(force: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (_live?.unavailable == true) ...[
                _notice(
                  'Actualisation des scores momentanément indisponible. Derniers résultats reçus conservés.',
                ),
                const SizedBox(height: 8),
              ],
              if (_section == LectorWorkspaceSection.all &&
                  !_loading &&
                  _feed?.snapshot != null) ...[
                Text(
                  '${_dayMatches.length} rencontres · ${_dayMatches.map((f) => f.competition.key).toSet().length} compétitions',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
              ],
              if (_section == LectorWorkspaceSection.radar &&
                  _competitions.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('hockey-competition-filter'),
                  initialValue: _league ?? 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Compétitions'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Toutes les compétitions'),
                    ),
                    for (final c in _competitions)
                      DropdownMenuItem(
                        value: c.id.value,
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _league = value == 'all' ? null : value;
                    _page = 0;
                  }),
                ),
                const SizedBox(height: 12),
              ],
              if (_section == LectorWorkspaceSection.forMe)
                _forMe(context, auth)
              else if (_section == LectorWorkspaceSection.generator &&
                  const bool.fromEnvironment('LECTOR_GENERATOR_UI'))
                _generator(context)
              else if (_section == LectorWorkspaceSection.generator ||
                  _section == LectorWorkspaceSection.bilan)
                _notice(
                  'Cette fonctionnalité sera disponible après la validation des lectures hockey.',
                )
              else if (_loading)
                _loadingContent()
              else if (_failed && _feed?.snapshot == null)
                LectorReadUnavailable(exhausted: _recovery.exhausted)
              else if (_feed?.snapshot == null)
                _notice(_unavailable)
              else if (_section == LectorWorkspaceSection.radar)
                _radar(context)
              else
                LectorTemporalFeed<SportFixture>(
                  key: ValueKey('hockey-time-$_date'),
                  items: _dayMatches,
                  phaseOf: (f) => (_live?.display(f) ?? f).temporal.phase,
                  sectionBuilder: (context, items, phase) => _matches(
                    context,
                    items,
                    forceExpanded: phase == LectorMatchPhase.live,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _generator(BuildContext context) => LectorGeneratorPage(
    date: _date,
    scope: _scope ?? const IdentityScope.guest('unresolved'),
    configurationKey: _preferences.toJson().toString(),
    loadContext: () async {
      final scope = _scope;
      final profile = scope == null
          ? null
          : await const SavedDecisionProfileStore().load(scope: scope);
      return GeneratorContext(
        origin: 'profile',
        preferences: {
          'hockey': GeneratorContext.hockey(_preferences),
          if (profile != null)
            'football': GeneratorContext.football(
              const ProfileCompiler().compile(profile),
            ),
        },
      );
    },
    onPreferences: _openSpace,
    onOpenMatch: (pick) => openGeneratorMatch(context, pick),
  );

  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LectorMatchCardFrame(child: Text(text)),
  );

  Widget _forMe(BuildContext context, SupabaseAuthController? auth) {
    if (!_preferencesReady) {
      return _notice('Chargement de vos préférences hockey…');
    }
    if (!_preferences.isConfigured) {
      return Column(
        children: [
          if (auth?.isSignedIn != true)
            LectorPersonalizeInvitation(
              onConnect: () => showLectorAccountSheet(context),
              onExplore: () =>
                  setState(() => _section = LectorWorkspaceSection.all),
            ),
          _notice(
            'Aucune rencontre à suivre. Choisissez vos compétitions et vos lectures hockey.',
          ),
          FilledButton.icon(
            key: const ValueKey('configure-hockey-preferences'),
            onPressed: _scope != null && _competitions.isNotEmpty
                ? _openPreferences
                : null,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Configurer mon hockey'),
          ),
        ],
      );
    }
    final snapshot = _feed?.snapshot;
    if (_loading) return _loadingContent();
    if (_failed && snapshot == null) {
      return LectorReadUnavailable(exhausted: _recovery.exhausted);
    }
    if (snapshot == null) return _notice(_unavailable);
    final matches = _dayMatches
        .where((f) => _readings.recommends(f, snapshot, _preferences))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _openPreferences,
          icon: const Icon(Icons.tune_rounded),
          label: Text(
            '${_preferences.competitionKeys.length} compétition(s) · ${_preferences.readingIds.length} lecture(s)',
          ),
        ),
        Text(
          'À suivre aujourd’hui',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${matches.length} rencontre${matches.length == 1 ? '' : 's'} correspondant à vos lectures',
        ),
        const SizedBox(height: 12),
        if (matches.isEmpty)
          _notice(
            'Aucune de vos lectures détectée sur vos compétitions pour ce jour. '
            'Les données insuffisantes ne créent pas de proposition.',
          ),
        if (matches.isNotEmpty)
          LectorTemporalFeed<SportFixture>(
            items: matches,
            phaseOf: (f) => (_live?.display(f) ?? f).temporal.phase,
            sectionBuilder: (context, items, phase) => _matches(
              context,
              items,
              forceExpanded: phase == LectorMatchPhase.live,
            ),
          ),
      ],
    );
  }

  List<SportFixture> get _dayMatches =>
      (_feed?.snapshot?.items ?? <SportFixture>[])
          .where(
            (f) => DateUtils.isSameDay(
              f.calendarDate ?? f.startsAt?.toLocal(),
              _date,
            ),
          )
          .toList()
        ..sort((a, b) => (a.startsAt ?? _date).compareTo(b.startsAt ?? _date));

  Widget _fixtureCard(SportFixture fixture) {
    final current = _live?.display(fixture) ?? fixture;
    final snapshot = _feed?.snapshot;
    final assessments = snapshot == null
        ? <SportReadingAssessment>[]
        : _readings.selected(fixture, snapshot, _preferences);
    String subject(SportReadingAssessment r) =>
        r.subject == fixture.home.id ? fixture.home.name : fixture.away.name;
    return SportFixtureCard(
      fixture: current,
      order: HockeyModule.definition.participantOrder,
      readingCount: assessments.isEmpty
          ? null
          : assessments
                .where((r) => r.status == SportReadingStatus.detected)
                .length,
      insights: assessments.isEmpty
          ? null
          : SportReadingInsights(
              readings: assessments,
              definition: HockeyModule.definition,
              subjectName: subject,
            ),
      statusLabel: switch (current.providerStatus) {
        'AOT' => 'Terminé · Prolongation',
        'AP' || 'APEN' => 'Terminé · Tirs au but',
        _ => null,
      },
      contextPanel: HockeyPlayerSignalPanel(
        entries: _players(before: fixture.startsAt)
            .where(
              (e) =>
                  e.profile.competition == fixture.competition &&
                  (e.profile.team.id == fixture.home.id ||
                      e.profile.team.id == fixture.away.id),
            )
            .toList(),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LectorDeferredContent<SportFeedResult>(
            title: '${fixture.away.name} · ${fixture.home.name}',
            load: () async {
              final repository = widget.repository;
              final result = repository is ProgressiveSportFeedRepository
                  ? await repository.loadMatch(_date, fixture.id.value)
                  : _feed!;
              if (result.snapshot?.items.any((f) => f.id == fixture.id) !=
                  true) {
                throw StateError('Détails du match indisponibles');
              }
              return result;
            },
            builder: (_, full) => HockeyMatchDetailPage(
              fixture:
                  full.snapshot?.items
                      .where((f) => f.id == fixture.id)
                      .firstOrNull ??
                  fixture,
              liveController: _live,
              readings: assessments,
              competition: (full.snapshot?.competitions ?? _competitions)
                  .where((c) => c.id == fixture.competition)
                  .firstOrNull,
            ),
          ),
        ),
      ),
    );
  }

  Widget _matches(
    BuildContext context,
    List<SportFixture> matches, {
    bool forceExpanded = false,
  }) {
    final leagues = <String, List<SportFixture>>{};
    for (final fixture in matches) {
      leagues.putIfAbsent(fixture.competition.key, () => []).add(fixture);
    }
    if (_section == LectorWorkspaceSection.forMe) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final group in leagues.values) ...[
            LectorCompetitionHeader(
              name: group.first.competitionName,
              count: group.length,
              logoUrl: _competitions
                  .where((c) => c.id == group.first.competition)
                  .firstOrNull
                  ?.logoUrl,
            ),
            const SizedBox(height: 8),
            for (final fixture in group)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _fixtureCard(fixture),
              ),
          ],
        ],
      );
    }
    final countries = <String, List<SportCompetitionContext>>{};
    for (final group in leagues.values) {
      final f = group.first;
      final competition =
          _competitions.where((c) => c.id == f.competition).firstOrNull ??
          SportCompetitionContext(
            id: f.competition,
            name: f.competitionName,
            season: f.season,
            country: '',
            formPhaseVerified: false,
            tables: const [],
          );
      countries
          .putIfAbsent(hockeyCountryLabel(competition), () => [])
          .add(competition);
    }
    final names = countries.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _section == LectorWorkspaceSection.forMe
              ? 'Vos compétitions'
              : 'Tous les pays',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          'Compétitions classées par pays, de A à Z.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          _notice('Aucune rencontre hockey programmée pour ce jour.'),
        for (final country in names) ...[
          LectorCompetitionGroup(
            key: ValueKey('hockey-country-$country'),
            forceExpanded: forceExpanded,
            identity: country,
            name: country,
            isCountry: true,
            logoUrl: hockeyCountryFlag(countries[country]!.first),
            countLabel:
                '${countries[country]!.length} compétition${countries[country]!.length > 1 ? 's' : ''}',
            children: [
              for (final c
                  in (countries[country]!
                    ..sort((a, b) => a.name.compareTo(b.name)))) ...[
                LectorCompetitionGroup(
                  key: ValueKey('hockey-league-${c.id.value}'),
                  forceExpanded: forceExpanded,
                  identity: c.id.key,
                  name: c.name,
                  logoUrl: c.logoUrl,
                  countLabel:
                      '${leagues[c.id.key]!.length} match${leagues[c.id.key]!.length > 1 ? 's' : ''}',
                  children: [
                    for (final f in leagues[c.id.key]!) ...[
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: _fixtureCard(f),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _radar(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LectorRadarModeToggle(
        firstLabel: 'Joueurs',
        secondLabel: 'Équipes',
        secondSelected: _teamsSelected,
        onChanged: (value) => setState(() {
          _teamsSelected = value;
          _page = 0;
        }),
      ),
      const SizedBox(height: 12),
      if (_teamsSelected) _teamRadar(context) else _playerRadar(context),
    ],
  );

  List<HockeyPlayerRadarEntry> _players({DateTime? before}) {
    final snapshot = _feed?.snapshot;
    if (snapshot == null) return [];
    final cutoff = before ?? DateTime(_date.year, _date.month, _date.day + 1);
    return HockeyPlayerRadarRanker.rank(
      snapshot.players.where(
        (p) => _league == null || p.competition.value == _league,
      ),
      before: cutoff.isBefore(snapshot.capturedAt)
          ? cutoff
          : snapshot.capturedAt,
    );
  }

  Widget _playerRadar(BuildContext context) {
    final top = _players().take(50).toList();
    final count = top.length;
    final page = _page.clamp(0, count == 0 ? 0 : (count - 1) ~/ 10);
    final teamIds = top.map((p) => p.profile.team.id.key).toSet();
    final matches = _dayMatches
        .where(
          (f) =>
              (_league == null || f.competition.value == _league) &&
              (teamIds.contains(f.home.id.key) ||
                  teamIds.contains(f.away.id.key)),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final historyCount = top.fold<int>(
          3,
          (n, e) =>
              e.profile.activity.length > n ? e.profile.activity.length : n,
        );
        final columns = lectorPlayerMatrixColumns(
          historyCount,
          constraints.maxWidth - 24,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Les joueurs les plus chauds en club',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            LectorRadarRankingPanel(
              title: 'Joueurs les plus chauds',
              totalCount: count,
              icon: Icons.local_fire_department_rounded,
              emptyState: const Text(
                'Aucun joueur éligible : il faut trois matchs avec les buteurs et passeurs entièrement renseignés.',
              ),
              description: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buts et passes sur les 3 derniers matchs de l’équipe. Au moins 2 contributions ; priorité à la régularité.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LectorPlayerRadarLegend(
                          presenceKnown: false,
                          showUnknown: true,
                        ),
                      ),
                      SizedBox(width: 12),
                      LectorPlayerPeriodLabel(columnCount: columns),
                    ],
                  ),
                  Divider(height: 18, color: Theme.of(context).dividerColor),
                ],
              ),
              footer: count > 10
                  ? LectorRadarPagination(
                      keyPrefix: 'hockey-player',
                      itemCount: count,
                      page: page,
                      pageSize: 10,
                      onPageChanged: (p) => setState(() => _page = p),
                    )
                  : null,
              children: [
                for (final indexed in top.skip(page * 10).take(10).indexed)
                  LectorRadarEntryCard(
                    child: LectorRadarPlayerRow(
                      rank: page * 10 + indexed.$1 + 1,
                      name: indexed.$2.profile.name,
                      teamName: indexed.$2.profile.team.name,
                      teamLogoUrl: indexed.$2.profile.team.logoUrl,
                      recentLine: hockeyPlayerMetric(indexed.$2),
                      stats:
                          '${indexed.$2.goals} buts · ${indexed.$2.assists} passes',
                      activity: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final f
                              in _dayMatches
                                  .where(
                                    (f) =>
                                        f.temporal.isLive &&
                                        f.competition ==
                                            indexed.$2.profile.competition &&
                                        (f.home.id ==
                                                indexed.$2.profile.team.id ||
                                            f.away.id ==
                                                indexed.$2.profile.team.id),
                                  )
                                  .take(1))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: LectorLiveBadge(state: f.temporal),
                            ),
                          hockeyPlayerMatrix(
                            context,
                            indexed.$2,
                            columnCount: columns,
                          ),
                        ],
                      ),
                      onTap: () =>
                          showHockeyPlayerActivity(context, indexed.$2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'L’historique conserve les matchs de la saison collectée ; les 3 derniers déterminent la forme actuelle. Faites défiler « Avant » pour explorer les matchs plus anciens. Un ? indique des contributions inconnues. Photos, présence et temps de glace ne sont pas renseignés.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Matchs du jour',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final c in _filteredCompetitions.where(
                (c) => matches.any((f) => f.competition == c.id),
              )) ...[
                LectorCompetitionHeader(
                  name: c.name,
                  count: matches.where((f) => f.competition == c.id).length,
                  logoUrl: c.logoUrl,
                ),
                for (final f in matches.where((f) => f.competition == c.id))
                  _fixtureCard(f),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _teamRadar(BuildContext context) {
    final top = HockeyTeamRadarRanker.rank(
      _filteredCompetitions,
    ).take(50).toList();
    final count = top.length,
        pages = (count / 10).ceil(),
        page = _page.clamp(0, pages == 0 ? 0 : pages - 1),
        start = page * 10,
        end = (start + 10).clamp(0, count);
    final teamIds = {for (final team in top) team.row.team.id.key};
    final radarMatches = _dayMatches
        .where(
          (f) =>
              (_league == null || f.competition.value == _league) &&
              (teamIds.contains(f.home.id.key) ||
                  teamIds.contains(f.away.id.key)),
        )
        .toList();
    final matchesByLeague = <String, List<SportFixture>>{};
    for (final fixture in radarMatches) {
      matchesByLeague
          .putIfAbsent(fixture.competition.key, () => [])
          .add(fixture);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Les équipes les plus en forme en club',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        if (_filteredCompetitions.any((c) => !c.formPhaseVerified))
          _notice(
            'NHL : le fournisseur ne distingue pas la phase des rencontres. Son historique n’est pas utilisé dans ce classement de forme.',
          ),
        LectorRadarRankingPanel(
          title: 'Équipes les plus chaudes',
          totalCount: count,
          emptyState: const Text(
            'Pas encore cinq résultats comparables par équipe pour ce filtre.',
          ),
          description: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Victoires sur 5 matchs, prolongation et tirs au but inclus. À égalité : 6ᵉ match, puis 7ᵉ, etc.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: LectorTeamFormHistoryLegend(),
                ),
              ],
            ),
          ),
          footer: count > 10
              ? LectorRadarPagination(
                  keyPrefix: 'hockey-team',
                  itemCount: count,
                  page: page,
                  pageSize: 10,
                  onPageChanged: (p) => setState(() => _page = p),
                )
              : null,
          children: [
            for (var i = start; i < end; i++)
              LectorRadarEntryCard(
                child: LectorRadarTeamRow(
                  rank: i + 1,
                  name: top[i].row.team.name,
                  logoUrl: top[i].row.team.logoUrl,
                  competitionName: top[i].competition.name,
                  metric: '${top[i].wins}/5',
                  streakLabel: top[i].streakLabel,
                  activity: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final f
                          in _dayMatches
                              .where(
                                (f) =>
                                    f.temporal.isLive &&
                                    f.competition == top[i].competition.id &&
                                    (f.home.id == top[i].row.team.id ||
                                        f.away.id == top[i].row.team.id),
                              )
                              .take(1))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: LectorLiveBadge(state: f.temporal),
                        ),
                      HockeyRadarFormStrip(
                        results: top[i].row.formHistory,
                        onMatchTap: (index) => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          builder: (_) => SafeArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: HockeyFormDetails(
                                team: top[i].row.team,
                                results: top[i].row.formHistory,
                                selectedIndex: index,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (radarMatches.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Matchs de ces équipes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 3),
          Text(
            'Les rencontres du jour des équipes du Top $count.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (final group in matchesByLeague.values) ...[
            LectorCompetitionHeader(
              name: group.first.competitionName,
              count: group.length,
              logoUrl: _competitions
                  .where((c) => c.id == group.first.competition)
                  .firstOrNull
                  ?.logoUrl,
            ),
            const SizedBox(height: 7),
            for (final f in group) _fixtureCard(f),
          ],
        ],
      ],
    );
  }

  void _showRules() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: _HockeyRules(),
      ),
    ),
  );
}

class _HockeyRules extends StatefulWidget {
  @override
  State<_HockeyRules> createState() => _HockeyRulesState();
}

class _HockeyRulesState extends State<_HockeyRules> {
  int _section = 1;
  @override
  Widget build(BuildContext context) {
    const module = HockeyModule.definition;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Premières règles à valider',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Ces exemples sont illustratifs. Les trois premières lectures peuvent être activées dans vos préférences hockey.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final (index, label) in ['Lectures', 'Scénarios'].indexed)
              ChoiceChip(
                key: ValueKey('hockey-section-${index + 1}'),
                label: Text(label),
                selected: _section == index + 1,
                onSelected: (_) => setState(() => _section = index + 1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_section == 1)
          for (final reading in module.readings) _readingCard(context, reading),
        if (_section == 2)
          for (final scenario in module.scenarios)
            LectorMatchCardFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenario.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(scenario.description),
                  for (final id in scenario.requiredReadingIds)
                    Text(
                      '• ${module.readings.firstWhere((r) => r.id == id).label}',
                    ),
                  const Text('Toutes requises pour la même équipe.'),
                ],
              ),
            ),
      ],
    );
  }

  Widget _readingCard(BuildContext context, SportReadingDefinition reading) =>
      ExpansionTile(
        key: ValueKey('hockey-reading-${reading.id}'),
        title: Text(reading.label),
        subtitle: Text(
          reading.implemented
              ? 'Règle initiale à valider'
              : 'À étudier avec les données',
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Text(reading.description),
          const SizedBox(height: 8),
          const Text(
            'Conditions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(reading.condition),
          const SizedBox(height: 8),
          const Text(
            'Exemple illustratif',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(reading.example),
        ],
      );
}
