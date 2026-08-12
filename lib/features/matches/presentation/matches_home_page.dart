import 'package:flutter/material.dart';

import '../../../app/auth/auth_menu_button.dart';
import '../../../app/theme/theme_variant_menu_button.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../onboarding/domain/compiled_decision_profile.dart';
import '../../onboarding/domain/decision_profile.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';
import '../../onboarding/domain/profile_compiler.dart';
import '../../opportunities/domain/opportunity.dart';
import '../../tickets/data/saved_ticket_store.dart';
import '../../tickets/domain/saved_ticket.dart';
import '../../tickets/domain/ticket_settlement_engine.dart';
import '../../tickets/domain/ticket_draft.dart';
import '../../tickets/domain/ticket_strategy.dart';
import '../../tickets/presentation/ticket_builder_panel.dart';
import '../../tickets/presentation/ticket_generator_page.dart';
import '../data/match_feed_repository.dart';
import '../data/match_feed_repository_loader.dart';
import '../data/saved_match_favorites_store.dart';
import '../domain/match_board_item.dart';
import 'match_detail_page.dart';
import 'opportunity_decision_presenter.dart';
import 'widgets/copilot_calendar.dart';
import 'widgets/sports_asset_badge.dart';

class MatchesHomePage extends StatefulWidget {
  const MatchesHomePage({
    required this.profile,
    required this.onEditProfile,
    required this.ticketStrategies,
    this.repositoryOverride,
    super.key,
  });

  final DecisionProfile profile;
  final VoidCallback onEditProfile;
  final List<TicketStrategy> ticketStrategies;
  final MatchFeedRepository? repositoryOverride;

  @override
  State<MatchesHomePage> createState() => _MatchesHomePageState();
}

class _MatchesHomePageState extends State<MatchesHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Future<MatchFeedRepository> _repository;
  final SavedTicketStore _savedTicketStore = const SavedTicketStore();
  final TicketSettlementEngine _ticketSettlementEngine =
      const TicketSettlementEngine();
  final ValueNotifier<TicketDraft> _ticketDraftNotifier = ValueNotifier(
    TicketDraft.empty,
  );
  TicketDraft _ticketDraft = TicketDraft.empty;
  List<SavedTicket> _savedTickets = const [];
  List<Opportunity> _latestOpportunities = const [];
  List<MatchBoardItem> _latestAnalyzedMatches = const [];
  bool _isTicketPanelExpanded = false;
  bool _isSettlingSavedTickets = false;
  String? _lastTicketSettlementSignature;
  int _manualTicketsOpenRequest = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repository = widget.repositoryOverride == null
        ? _loadRepository()
        : Future.value(widget.repositoryOverride);
    _loadSavedTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ticketDraftNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          const ThemeVariantMenuButton(),
          const AuthMenuButton(showGuestLabel: true),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: widget.onEditProfile,
            icon: const Icon(Icons.tune_rounded),
            label: Text(l10n.profileSettingsButton),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.forMeTab),
            const Tab(text: 'Générateur'),
            Tab(text: l10n.allMatchesTab),
          ],
        ),
      ),
      body: FutureBuilder<MatchFeedRepository>(
        future: _repository,
        builder: (context, snapshot) {
          final repository = snapshot.data;

          if (snapshot.hasError) {
            return _RepositoryLoadError(error: snapshot.error);
          }

          if (repository == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Chargement du snapshot des rencontres...'),
                ],
              ),
            );
          }

          final compiledProfile = const ProfileCompiler().compile(
            widget.profile,
          );
          final opportunities = repository.opportunitiesFor(widget.profile);
          final allMatches = repository.allMatches();
          final snapshotMetadata = repository.snapshotMetadata;
          final analyzedAllMatches = [
            for (final match in allMatches)
              repository.analyzeFor(widget.profile, match),
          ];
          _latestOpportunities = opportunities;
          _latestAnalyzedMatches = analyzedAllMatches;
          _scheduleSavedTicketSettlement(analyzedAllMatches);
          void openAnalyzedMatch(MatchBoardItem match) {
            _openMatchDetails(repository.analyzeFor(widget.profile, match));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _MatchList(
                profile: widget.profile,
                compiledProfile: compiledProfile,
                opportunities: opportunities,
                snapshotMetadata: snapshotMetadata,
                ticketDraft: _ticketDraft,
                onToggleTicket: _toggleTicketSelection,
                onOpenOpportunity: (opportunity) {
                  _openOpportunityDetails(opportunity);
                },
                onSeeAllMatches: () => _tabController.animateTo(2),
                onEditProfile: widget.onEditProfile,
              ),
              TicketGeneratorPage(
                profile: compiledProfile,
                opportunities: opportunities,
                strategies: widget.ticketStrategies,
                savedTickets: _savedTickets,
                manualTicketsOpenRequest: _manualTicketsOpenRequest,
                onEditStrategies: widget.onEditProfile,
                onOpenOpportunity: (opportunity) {
                  _openOpportunityDetails(opportunity);
                },
                onSaveTicket: _upsertSavedTicket,
                onDeleteSavedTicket: _deleteSavedTicket,
              ),
              _ChampionshipsByCountryView(
                matches: analyzedAllMatches,
                snapshotMetadata: snapshotMetadata,
                compiledProfile: compiledProfile,
                ticketDraft: _ticketDraft,
                onToggleTicket: _toggleTicketSelection,
                onOpenMatch: openAnalyzedMatch,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _ticketDraft.isEmpty
          ? null
          : TicketBuilderPanel(
              ticket: _ticketDraft,
              strategies: widget.ticketStrategies,
              isExpanded: _isTicketPanelExpanded,
              onToggleExpanded: () {
                setState(() {
                  _isTicketPanelExpanded = !_isTicketPanelExpanded;
                });
              },
              onRemoveSelection: _removeTicketSelection,
              onTicketSaved: _upsertSavedTicket,
              onViewSavedTickets: _openTicketsTab,
              onOpenSelection: _openTicketSelectionDetails,
            ),
    );
  }

  void _toggleTicketSelection(TicketDraftSelection selection) {
    if (!_ticketDraft.canToggle(selection)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce match est déjà présent dans Mon ticket.'),
        ),
      );
      return;
    }

    setState(() {
      _ticketDraft = _ticketDraft.toggle(selection);
      _ticketDraftNotifier.value = _ticketDraft;
      if (_ticketDraft.isEmpty) {
        _isTicketPanelExpanded = false;
      }
    });
  }

  void _removeTicketSelection(String selectionId) {
    setState(() {
      _ticketDraft = _ticketDraft.remove(selectionId);
      _ticketDraftNotifier.value = _ticketDraft;
      if (_ticketDraft.isEmpty) {
        _isTicketPanelExpanded = false;
      }
    });
  }

  Future<void> _loadSavedTickets() async {
    final tickets = await _savedTicketStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _savedTickets = tickets;
    });
  }

  void _scheduleSavedTicketSettlement(List<MatchBoardItem> matches) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _settleSavedTickets(matches);
    });
  }

  Future<void> _settleSavedTickets(List<MatchBoardItem> matches) async {
    if (_isSettlingSavedTickets || _savedTickets.isEmpty || matches.isEmpty) {
      return;
    }

    final signature = _ticketSettlementSignature(_savedTickets, matches);
    if (signature == _lastTicketSettlementSignature) {
      return;
    }
    _lastTicketSettlementSignature = signature;
    _isSettlingSavedTickets = true;

    final settledTickets = _ticketSettlementEngine.settleTickets(
      tickets: _savedTickets,
      matches: matches,
    );
    if (identical(settledTickets, _savedTickets)) {
      _isSettlingSavedTickets = false;
      return;
    }

    if (!mounted) {
      _isSettlingSavedTickets = false;
      return;
    }

    setState(() {
      _savedTickets = settledTickets;
    });
    try {
      await _savedTicketStore.saveAll(settledTickets);
    } finally {
      _isSettlingSavedTickets = false;
    }
  }

  void _upsertSavedTicket(SavedTicket ticket) {
    setState(() {
      final index = _savedTickets.indexWhere(
        (savedTicket) => savedTicket.id == ticket.id,
      );
      if (index == -1) {
        _savedTickets = [ticket, ..._savedTickets];
      } else {
        final updatedTickets = [..._savedTickets];
        updatedTickets[index] = ticket;
        _savedTickets = updatedTickets;
      }
      _ticketDraft = TicketDraft.empty;
      _ticketDraftNotifier.value = _ticketDraft;
      _isTicketPanelExpanded = false;
    });
    _savedTicketStore.upsert(ticket);
  }

  void _deleteSavedTicket(String ticketId) {
    setState(() {
      _savedTickets = [
        for (final ticket in _savedTickets)
          if (ticket.id != ticketId) ticket,
      ];
    });
    _savedTicketStore.delete(ticketId);
  }

  String _ticketSettlementSignature(
    List<SavedTicket> tickets,
    List<MatchBoardItem> matches,
  ) {
    final playedTickets = [
      for (final ticket in tickets)
        if (ticket.status == SavedTicketStatus.played)
          [
            ticket.id,
            ticket.updatedAt.toUtc().toIso8601String(),
            for (final selection in ticket.selections) selection.matchId,
          ].join(':'),
    ]..sort();
    final relevantMatchIds = {
      for (final ticket in tickets)
        if (ticket.status == SavedTicketStatus.played)
          for (final selection in ticket.selections) selection.matchId,
    };
    final matchStates = [
      for (final match in matches)
        if (relevantMatchIds.contains(match.id) ||
            (match.fixture.apiFootballFixtureId != null &&
                relevantMatchIds.contains(
                  match.fixture.apiFootballFixtureId.toString(),
                )))
          [
            match.id,
            match.fixture.status.name,
            match.fixture.score?.home,
            match.fixture.score?.away,
          ].join(':'),
    ]..sort();

    return [...playedTickets, ...matchStates].join('|');
  }

  void _openTicketsTab() {
    setState(() {
      _isTicketPanelExpanded = false;
      _manualTicketsOpenRequest += 1;
    });
    _tabController.animateTo(1);
  }

  void _openMatchDetails(MatchBoardItem match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MatchDetailPage(
          match: match,
          ticketDraftListenable: _ticketDraftNotifier,
          ticketStrategies: widget.ticketStrategies,
          onToggleTicket: _toggleTicketSelection,
          onRemoveTicketSelection: _removeTicketSelection,
          onTicketSaved: _upsertSavedTicket,
          onOpenTicketSelection: _openTicketSelectionDetails,
          onViewSavedTickets: () {
            Navigator.of(context).maybePop();
            _openTicketsTab();
          },
        ),
      ),
    );
  }

  void _openOpportunityDetails(Opportunity opportunity) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MatchDetailPage(
          match: opportunity.toMatchBoardItem(),
          opportunity: opportunity,
          ticketDraftListenable: _ticketDraftNotifier,
          ticketStrategies: widget.ticketStrategies,
          onToggleTicket: _toggleTicketSelection,
          onRemoveTicketSelection: _removeTicketSelection,
          onTicketSaved: _upsertSavedTicket,
          onOpenTicketSelection: _openTicketSelectionDetails,
          onViewSavedTickets: () {
            Navigator.of(context).maybePop();
            _openTicketsTab();
          },
        ),
      ),
    );
  }

  void _openTicketSelectionDetails(TicketDraftSelection selection) {
    for (final opportunity in _latestOpportunities) {
      if (opportunity.matchId == selection.matchId) {
        _openOpportunityDetails(opportunity);
        return;
      }
    }

    for (final match in _latestAnalyzedMatches) {
      if (match.id == selection.matchId) {
        _openMatchDetails(match);
        return;
      }
    }

    _openMatchDetails(_matchFromTicketSelection(selection));
  }

  MatchBoardItem _matchFromTicketSelection(TicketDraftSelection selection) {
    final odds = MarketOdds(
      id: selection.selectionId,
      label: selection.selectionLabel,
      odds: selection.odds,
      bookmakerName: selection.bookmakerName,
    );
    final market = MatchMarket(
      id: selection.marketId,
      label: selection.marketLabel,
      selections: [odds],
      bookmakerName: selection.bookmakerName,
    );

    return MatchBoardItem(
      fixture: NormalizedFixture(
        id: selection.matchId,
        competition: CompetitionInfo(
          id: 'ticket-${selection.competitionName ?? 'competition'}',
          name: selection.competitionName ?? 'Compétition',
          country: const CountryInfo(code: 'ticket', name: 'Mon ticket'),
          season: DateTime.now().year,
        ),
        homeTeam: TeamInfo(
          id: '${selection.matchId}-home',
          name: selection.homeTeam,
          logoUrl: selection.homeLogoUrl,
        ),
        awayTeam: TeamInfo(
          id: '${selection.matchId}-away',
          name: selection.awayTeam,
          logoUrl: selection.awayLogoUrl,
        ),
        kickoffLabel: 'Depuis Mon ticket',
        status: FixtureStatus.scheduled,
      ),
      primaryMarket: odds,
      availableMarkets: [market],
      compatibility: 0,
      signals: const [],
    );
  }

  Future<MatchFeedRepository> _loadRepository() async {
    return getIt<MatchFeedRepositoryLoader>().load();
  }
}

class _RepositoryLoadError extends StatelessWidget {
  const _RepositoryLoadError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: colorScheme.error),
                const SizedBox(height: 10),
                Text(
                  'Impossible de charger les rencontres',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error?.toString() ?? 'Erreur inconnue.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _MatchStatusFilter { all, live, scheduled, finished, postponed, cancelled }

enum _OddsAvailabilityFilter { all, withOdds, withoutOdds }

enum _CopilotInfoFilter {
  all,
  withReading,
  withRecommendedMarket,
  matchingProfile,
}

class _AllMatchesFilters {
  const _AllMatchesFilters({
    this.countryCodes = const {},
    this.competitionIds = const {},
    this.marketIds = const {},
    this.oddsAvailability = _OddsAvailabilityFilter.all,
    this.copilotInfo = _CopilotInfoFilter.all,
    this.favoritesOnly = false,
  });

  final Set<String> countryCodes;
  final Set<String> competitionIds;
  final Set<String> marketIds;
  final _OddsAvailabilityFilter oddsAvailability;
  final _CopilotInfoFilter copilotInfo;
  final bool favoritesOnly;

  static const empty = _AllMatchesFilters();

  int get activeCount {
    return countryCodes.length +
        competitionIds.length +
        marketIds.length +
        (oddsAvailability == _OddsAvailabilityFilter.all ? 0 : 1) +
        (copilotInfo == _CopilotInfoFilter.all ? 0 : 1) +
        (favoritesOnly ? 1 : 0);
  }

  bool get isEmpty => activeCount == 0;

  _AllMatchesFilters copyWith({
    Set<String>? countryCodes,
    Set<String>? competitionIds,
    Set<String>? marketIds,
    _OddsAvailabilityFilter? oddsAvailability,
    _CopilotInfoFilter? copilotInfo,
    bool? favoritesOnly,
  }) {
    return _AllMatchesFilters(
      countryCodes: countryCodes ?? this.countryCodes,
      competitionIds: competitionIds ?? this.competitionIds,
      marketIds: marketIds ?? this.marketIds,
      oddsAvailability: oddsAvailability ?? this.oddsAvailability,
      copilotInfo: copilotInfo ?? this.copilotInfo,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }
}

class _DisplayedMarketOption {
  const _DisplayedMarketOption({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.emptyLabel,
    this.isPlayerMarket = false,
  });

  final String id;
  final String label;
  final String shortLabel;
  final String emptyLabel;
  final bool isPlayerMarket;
}

class _BookmakerOption {
  const _BookmakerOption({
    required this.key,
    required this.label,
    required this.bookmakerId,
  });

  final String key;
  final String label;
  final int? bookmakerId;

  int get rank {
    return switch (bookmakerId) {
      16 => 0,
      8 => 1,
      4 => 2,
      3 => 3,
      11 => 4,
      6 => 5,
      _ => 99,
    };
  }
}

class _AllMatchesFilterResult {
  const _AllMatchesFilterResult({
    required this.filters,
    required this.displayedMarketId,
    required this.selectedBookmakerKey,
    required this.statusFilter,
  });

  final _AllMatchesFilters filters;
  final String displayedMarketId;
  final String? selectedBookmakerKey;
  final _MatchStatusFilter statusFilter;
}

class _AllMatchesCompactHeader extends StatelessWidget {
  const _AllMatchesCompactHeader({
    required this.activeFilterCount,
    required this.isSearching,
    required this.searchController,
    required this.query,
    required this.onSearchVisibilityChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onOpenFilters,
  });

  final int activeFilterCount;
  final bool isSearching;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<bool> onSearchVisibilityChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.sports_soccer_rounded, size: 36),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Football',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
            _RoundHeaderButton(
              tooltip: isSearching ? 'Fermer la recherche' : 'Rechercher',
              icon: isSearching ? Icons.close_rounded : Icons.search_rounded,
              onPressed: () => onSearchVisibilityChanged(!isSearching),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RoundHeaderButton(
              tooltip: 'Filtres',
              icon: Icons.tune_rounded,
              badge: activeFilterCount,
              onPressed: onOpenFilters,
            ),
          ],
        ),
        if (isSearching) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: searchController,
            autofocus: true,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
              hintText: 'Rechercher une équipe, une compétition ou un pays',
            ),
          ),
        ],
      ],
    );
  }
}

class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badge = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.outlined(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            fixedSize: const Size.square(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -4,
            top: -6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                child: Text(
                  '$badge',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.action});

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        ...?action == null ? null : [action!],
      ],
    );
  }
}

class _FavoriteCompetitionsSection extends StatelessWidget {
  const _FavoriteCompetitionsSection({
    required this.competitions,
    required this.expandedCompetitionIds,
    required this.favoriteIds,
    required this.displayedMarket,
    required this.selectedBookmaker,
    required this.ticketDraft,
    required this.onEdit,
    required this.onToggleCompetition,
    required this.onToggleFavorite,
    required this.onToggleTicket,
    required this.onOpenMatch,
  });

  final List<_CompetitionBucket> competitions;
  final Set<String> expandedCompetitionIds;
  final Set<String> favoriteIds;
  final _DisplayedMarketOption displayedMarket;
  final _BookmakerOption? selectedBookmaker;
  final TicketDraft ticketDraft;
  final VoidCallback? onEdit;
  final ValueChanged<String> onToggleCompetition;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<TicketDraftSelection> onToggleTicket;
  final ValueChanged<MatchBoardItem> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.star_rounded,
          title: 'Mes compétitions',
          action: TextButton(onPressed: onEdit, child: const Text('Modifier')),
        ),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: competitions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Aucune compétition suivie disponible pour cette date.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final competition in competitions) ...[
                      _FavoriteCompetitionLine(
                        key: ValueKey(
                          'favorite-competition-${competition.competition.id}',
                        ),
                        competition: competition,
                        isExpanded: expandedCompetitionIds.contains(
                          competition.competition.id,
                        ),
                        onTap: () =>
                            onToggleCompetition(competition.competition.id),
                      ),
                      if (expandedCompetitionIds.contains(
                        competition.competition.id,
                      ))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          child: Column(
                            children: [
                              for (final match in competition.matches)
                                _AllMatchRow(
                                  match: match,
                                  favoriteIds: favoriteIds,
                                  displayedMarket: displayedMarket,
                                  selectedBookmaker: selectedBookmaker,
                                  ticketDraft: ticketDraft,
                                  onToggleFavorite: onToggleFavorite,
                                  onToggleTicket: onToggleTicket,
                                  onOpenMatch: () => onOpenMatch(match),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _FavoriteCompetitionLine extends StatelessWidget {
  const _FavoriteCompetitionLine({
    required this.competition,
    required this.isExpanded,
    required this.onTap,
    super.key,
  });

  final _CompetitionBucket competition;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final country = competition.competition.country;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              SportsAssetBadge(
                size: 30,
                imageUrl: country.flagUrl,
                fallbackLabel: country.name,
                borderRadius: AppRadius.chip,
                backgroundColor: AppColors.transparent,
                padding: 0,
                icon: Icons.flag_rounded,
              ),
              const SizedBox(width: AppSpacing.sm),
              SportsAssetBadge(
                size: 30,
                imageUrl: competition.competition.logoUrl,
                fallbackLabel: competition.competition.name,
                backgroundColor: AppColors.transparent,
                padding: 0,
                icon: Icons.emoji_events_rounded,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  competition.competition.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${competition.matches.length} match${competition.matches.length > 1 ? 's' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChampionshipsByCountryView extends StatefulWidget {
  const _ChampionshipsByCountryView({
    required this.matches,
    required this.snapshotMetadata,
    required this.compiledProfile,
    required this.ticketDraft,
    required this.onToggleTicket,
    required this.onOpenMatch,
  });

  final List<MatchBoardItem> matches;
  final MatchFeedSnapshotMetadata? snapshotMetadata;
  final CompiledDecisionProfile compiledProfile;
  final TicketDraft ticketDraft;
  final ValueChanged<TicketDraftSelection> onToggleTicket;
  final ValueChanged<MatchBoardItem> onOpenMatch;

  @override
  State<_ChampionshipsByCountryView> createState() =>
      _ChampionshipsByCountryViewState();
}

class _ChampionshipsByCountryViewState
    extends State<_ChampionshipsByCountryView> {
  _MatchStatusFilter _statusFilter = _MatchStatusFilter.all;
  _AllMatchesFilters _filters = _AllMatchesFilters.empty;
  String _displayedMarketId = 'matchResult';
  String? _selectedBookmakerKey;
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedFavoriteCompetitionIds = {};
  final Set<String> _expandedCountryIds = {};
  final Set<String> _expandedCompetitionIds = {};
  final Set<String> _favoriteIds = {};
  final SavedMatchFavoritesStore _favoriteStore =
      const SavedMatchFavoritesStore();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = _today();
    final effectiveDate = _selectedDate ?? today;
    final filteredMatches = _filteredMatches(widget.matches, effectiveDate);
    final marketOptions = _displayedMarketOptions(widget.matches);
    final selectedMarket = marketOptions.firstWhere(
      (option) => option.id == _displayedMarketId,
      orElse: () => marketOptions.first,
    );
    final bookmakerOptions = _bookmakerOptions(
      widget.matches,
      selectedMarket.id,
    );
    final selectedBookmaker = _selectedBookmaker(
      bookmakerOptions,
      selectedMarket.id,
    );
    final groups = _groupByCountry(filteredMatches);
    final favoriteCompetitions = _profileCompetitions(groups);

    return RefreshIndicator(
      onRefresh: _refreshCurrentDate,
      child: ListView(
        key: const PageStorageKey<String>('all-matches-explorer'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AllMatchesCompactHeader(
                    activeFilterCount: _activeFilterCount,
                    isSearching: _isSearchVisible,
                    searchController: _searchController,
                    query: _searchController.text,
                    onSearchVisibilityChanged: (isVisible) {
                      setState(() {
                        _isSearchVisible = isVisible;
                      });
                    },
                    onSearchChanged: (_) => setState(() {}),
                    onClearSearch: () {
                      setState(() {
                        _searchController.clear();
                      });
                    },
                    onOpenFilters: () => _openFilters(widget.matches),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CopilotCalendar(
                    selectedDate: effectiveDate,
                    visibleWindowDays: 7,
                    onDateSelected: (date) {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    onChooseDate: _chooseDate,
                  ),
                  _SnapshotFreshnessLine(
                    metadata: widget.snapshotMetadata,
                    selectedDate: effectiveDate,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FavoriteCompetitionsSection(
                    competitions: favoriteCompetitions,
                    expandedCompetitionIds: _expandedFavoriteCompetitionIds,
                    favoriteIds: _favoriteIds,
                    displayedMarket: selectedMarket,
                    selectedBookmaker: selectedBookmaker,
                    ticketDraft: widget.ticketDraft,
                    onEdit: widget.compiledProfile.isCompleted ? () {} : null,
                    onToggleCompetition: (competitionId) {
                      setState(() {
                        _toggleSetItem(
                          _expandedFavoriteCompetitionIds,
                          competitionId,
                        );
                      });
                    },
                    onToggleFavorite: _toggleFavorite,
                    onToggleTicket: widget.onToggleTicket,
                    onOpenMatch: widget.onOpenMatch,
                  ),
                  if (filteredMatches.isEmpty) ...[
                    const SizedBox(height: 16),
                    _EmptyMatchState(
                      title: _emptyTitle(l10n),
                      subtitle: _emptySubtitle(l10n),
                      primaryActionLabel: _searchController.text.trim().isEmpty
                          ? 'Réinitialiser les filtres'
                          : 'Effacer la recherche',
                      onPrimaryAction: _searchController.text.trim().isEmpty
                          ? _resetFilters
                          : () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                    ),
                  ],
                  if (groups.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _SectionTitle(
                      icon: Icons.public_rounded,
                      title: 'Toutes les compétitions',
                    ),
                  ],
                  for (final group in groups) ...[
                    const SizedBox(height: 12),
                    _CountryMatchesPanel(
                      group: group,
                      isExpanded: _expandedCountryIds.contains(
                        group.country.code,
                      ),
                      favoriteIds: _favoriteIds,
                      expandedCompetitionIds: _expandedCompetitionIds,
                      onToggleExpanded: () {
                        setState(() {
                          _toggleSetItem(
                            _expandedCountryIds,
                            group.country.code,
                          );
                        });
                      },
                      onToggleCompetition: (competitionId) {
                        setState(() {
                          _toggleSetItem(
                            _expandedCompetitionIds,
                            competitionId,
                          );
                        });
                      },
                      onToggleFavorite: _toggleFavorite,
                      onOpenMatch: widget.onOpenMatch,
                      displayedMarket: selectedMarket,
                      selectedBookmaker: selectedBookmaker,
                      ticketDraft: widget.ticketDraft,
                      onToggleTicket: widget.onToggleTicket,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<MatchBoardItem> _filteredMatches(
    List<MatchBoardItem> matches,
    DateTime? selectedDate,
  ) {
    final query = _normalizedText(_searchController.text);
    return matches.where((match) {
      final kickoff = match.fixture.kickoff;
      if (selectedDate != null && kickoff != null) {
        final localKickoff = kickoff.toLocal();
        if (!_isSameDay(localKickoff, selectedDate)) {
          return false;
        }
      }

      final matchesStatus = switch (_statusFilter) {
        _MatchStatusFilter.all => true,
        _MatchStatusFilter.live => match.fixture.status == FixtureStatus.live,
        _MatchStatusFilter.scheduled =>
          match.fixture.status == FixtureStatus.scheduled,
        _MatchStatusFilter.finished =>
          match.fixture.status == FixtureStatus.finished,
        _MatchStatusFilter.postponed =>
          match.fixture.status == FixtureStatus.postponed,
        _MatchStatusFilter.cancelled =>
          match.fixture.status == FixtureStatus.cancelled,
      };

      if (!matchesStatus) {
        return false;
      }

      if (_filters.countryCodes.isNotEmpty &&
          !_filters.countryCodes.contains(match.competition.country.code)) {
        return false;
      }

      if (_filters.competitionIds.isNotEmpty &&
          !_filters.competitionIds.contains(match.competition.id)) {
        return false;
      }

      if (_filters.marketIds.isNotEmpty &&
          !match.availableMarkets.any(
            (market) => _filters.marketIds.contains(market.id),
          )) {
        return false;
      }

      if (_filters.oddsAvailability == _OddsAvailabilityFilter.withOdds &&
          match.availableMarkets.isEmpty) {
        return false;
      }

      if (_filters.oddsAvailability == _OddsAvailabilityFilter.withoutOdds &&
          match.availableMarkets.isNotEmpty) {
        return false;
      }

      if (_filters.copilotInfo == _CopilotInfoFilter.withReading &&
          !_hasCopilotReading(match)) {
        return false;
      }

      if (_filters.copilotInfo == _CopilotInfoFilter.withRecommendedMarket &&
          match.thesis?.hasRecommendedMarket != true) {
        return false;
      }

      if (_filters.copilotInfo == _CopilotInfoFilter.matchingProfile &&
          match.profileStatus != MatchProfileStatus.inProfile) {
        return false;
      }

      if (_filters.favoritesOnly && !_isFavoriteScope(match)) {
        return false;
      }

      if (query.isNotEmpty && !_matchesQuery(match, query)) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) => _dateKey(a) == _dateKey(b);

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  List<_CountryGroup> _groupByCountry(List<MatchBoardItem> matches) {
    final byCountry = <String, _CountryGroupBuilder>{};

    for (final match in matches) {
      final country = match.competition.country;
      final countryGroup = byCountry.putIfAbsent(
        country.code,
        () => _CountryGroupBuilder(country: country),
      );
      final bucket = countryGroup.competitions.putIfAbsent(
        match.competition.id,
        () => _CompetitionBucket(
          country: country.name,
          competition: match.competition,
          matches: <MatchBoardItem>[],
        ),
      );
      bucket.matches.add(match);
    }

    final groups = [
      for (final countryEntry in byCountry.entries)
        _CountryGroup(
          country: countryEntry.value.country,
          competitions: countryEntry.value.competitions.values.toList()
            ..forEach(
              (competition) => competition.matches.sort(
                (a, b) =>
                    a.fixture.kickoffLabel.compareTo(b.fixture.kickoffLabel),
              ),
            )
            ..sort(_compareCompetitions),
        ),
    ];
    groups.sort(_compareCountries);
    return groups;
  }

  List<_CompetitionBucket> _profileCompetitions(List<_CountryGroup> groups) {
    final enabled = widget.compiledProfile.competitions.values
        .where((competition) => competition.enabled)
        .toList();
    if (enabled.isEmpty) {
      return const [];
    }

    final enabledIds = {
      for (final competition in enabled) competition.id,
      for (final competition in enabled)
        competition.apiFootballLeagueId.toString(),
    };
    final enabledLeagueIds = {
      for (final competition in enabled) competition.apiFootballLeagueId,
    };
    final result = <_CompetitionBucket>[];

    for (final group in groups) {
      for (final competition in group.competitions) {
        final leagueId = competition.competition.apiFootballLeagueId;
        if (enabledIds.contains(competition.competition.id) ||
            (leagueId != null && enabledLeagueIds.contains(leagueId))) {
          result.add(competition);
        }
      }
    }

    result.sort(_compareCompetitions);
    return result;
  }

  int _compareCountries(_CountryGroup a, _CountryGroup b) {
    return a.country.name.compareTo(b.country.name);
  }

  int _compareCompetitions(_CompetitionBucket a, _CompetitionBucket b) {
    final aRank = _competitionCatalogRank(a.competition);
    final bRank = _competitionCatalogRank(b.competition);
    if (aRank != bRank) {
      return aRank.compareTo(bRank);
    }
    return a.competition.name.compareTo(b.competition.name);
  }

  int _competitionCatalogRank(CompetitionInfo competition) {
    final leagueId = competition.apiFootballLeagueId;
    final rank = CompetitionCatalog.values.indexWhere(
      (catalogCompetition) =>
          catalogCompetition.id == competition.id ||
          (leagueId != null &&
              catalogCompetition.apiFootballLeagueId == leagueId),
    );
    return rank == -1 ? 100000 : rank;
  }

  int get _activeFilterCount {
    return _filters.activeCount +
        (_statusFilter == _MatchStatusFilter.all ? 0 : 1) +
        (_displayedMarketId == 'matchResult' ? 0 : 1) +
        (_selectedBookmakerKey == null ? 0 : 1);
  }

  List<_DisplayedMarketOption> _displayedMarketOptions(
    List<MatchBoardItem> matches,
  ) {
    return const [
      _DisplayedMarketOption(
        id: 'matchResult',
        label: 'Résultat du match (1N2)',
        shortLabel: '1N2',
        emptyLabel: 'Cotes indisponibles',
      ),
      _DisplayedMarketOption(
        id: 'doubleChance',
        label: 'Double chance',
        shortLabel: 'Double chance',
        emptyLabel: 'Cotes indisponibles',
      ),
      _DisplayedMarketOption(
        id: 'goalsTotal',
        label: 'Plus/Moins 2,5 buts',
        shortLabel: '+/- 2,5',
        emptyLabel: 'Cotes indisponibles',
      ),
      _DisplayedMarketOption(
        id: 'bothTeamsScore',
        label: 'Les deux équipes marquent',
        shortLabel: 'BTTS',
        emptyLabel: 'Cotes indisponibles',
      ),
      _DisplayedMarketOption(
        id: 'teamTotalHome',
        label: 'Équipe domicile marque',
        shortLabel: 'Domicile',
        emptyLabel: 'Cotes indisponibles',
      ),
      _DisplayedMarketOption(
        id: 'teamTotalAway',
        label: 'Équipe extérieure marque',
        shortLabel: 'Extérieur',
        emptyLabel: 'Cotes indisponibles',
      ),
      _DisplayedMarketOption(
        id: 'firstHalfGoal',
        label: 'But en première mi-temps',
        shortLabel: '1re MT',
        emptyLabel: 'Cotes indisponibles',
      ),
      _DisplayedMarketOption(
        id: 'playerAnytimeScorer',
        label: 'Buteur',
        shortLabel: 'Buteur',
        emptyLabel: 'Buteurs indisponibles',
        isPlayerMarket: true,
      ),
    ];
  }

  List<_BookmakerOption> _bookmakerOptions(
    List<MatchBoardItem> matches,
    String marketId,
  ) {
    final byKey = <String, _BookmakerOption>{};
    for (final match in matches) {
      for (final market in match.availableMarkets) {
        if (market.id != marketId) {
          continue;
        }
        final key = _bookmakerKey(market);
        byKey[key] = _BookmakerOption(
          key: key,
          label: market.bookmakerName ?? 'Bookmaker inconnu',
          bookmakerId: market.bookmakerId,
        );
      }
    }

    final options = byKey.values.toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    return options;
  }

  _BookmakerOption? _selectedBookmaker(
    List<_BookmakerOption> options,
    String marketId,
  ) {
    if (options.isEmpty) {
      return null;
    }

    final selectedKey = _selectedBookmakerKey;
    if (selectedKey != null) {
      for (final option in options) {
        if (option.key == selectedKey) {
          return option;
        }
      }
    }

    return options.first;
  }

  String _bookmakerKey(MatchMarket market) {
    final id = market.bookmakerId;
    if (id != null) {
      return 'id:$id';
    }
    return 'name:${market.bookmakerName ?? 'unknown'}';
  }

  bool _matchesQuery(MatchBoardItem match, String query) {
    return _normalizedText(match.homeTeam.name).contains(query) ||
        _normalizedText(match.awayTeam.name).contains(query) ||
        _normalizedText(match.competition.name).contains(query) ||
        _normalizedText(match.competition.country.name).contains(query);
  }

  String _normalizedText(String value) {
    return value
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('ç', 'c')
        .trim();
  }

  bool _hasCopilotReading(MatchBoardItem match) {
    final thesis = match.thesis;
    if (thesis == null) {
      return match.signals.isNotEmpty;
    }

    return thesis.status != MatchThesisStatus.notRecommended ||
        thesis.arguments.isNotEmpty ||
        thesis.supportingEvidence.isNotEmpty;
  }

  bool _isFavoriteScope(MatchBoardItem match) {
    return _favoriteIds.contains(_favoriteKey('match', match.id)) ||
        _favoriteIds.contains(
          _favoriteKey('country', match.competition.country.code),
        ) ||
        _favoriteIds.contains(
          _favoriteKey('competition', match.competition.id),
        ) ||
        _favoriteIds.contains(_favoriteKey('team', match.homeTeam.id)) ||
        _favoriteIds.contains(_favoriteKey('team', match.awayTeam.id));
  }

  String _favoriteKey(String scope, String id) => '$scope:$id';

  void _toggleSetItem(Set<String> values, String value) {
    if (values.contains(value)) {
      values.remove(value);
    } else {
      values.add(value);
    }
  }

  Future<void> _loadFavorites() async {
    final saved = await _favoriteStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteIds
        ..clear()
        ..addAll(saved);
    });
  }

  void _toggleFavorite(String favoriteId) {
    setState(() {
      _toggleSetItem(_favoriteIds, favoriteId);
    });
    _favoriteStore.save(_favoriteIds);
  }

  Future<void> _refreshCurrentDate() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _chooseDate() async {
    final initialDate = _selectedDate ?? _today();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 1),
      lastDate: DateTime(initialDate.year + 1),
    );
    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(selected.year, selected.month, selected.day);
    });
  }

  void _resetFilters() {
    setState(() {
      _filters = _AllMatchesFilters.empty;
      _statusFilter = _MatchStatusFilter.all;
    });
  }

  String _emptyTitle(AppLocalizations l10n) {
    if (_searchController.text.trim().isNotEmpty) {
      return 'Aucun résultat de recherche';
    }
    if (!_filters.isEmpty || _statusFilter != _MatchStatusFilter.all) {
      return l10n.noMatchesForFiltersTitle;
    }
    return 'Aucune rencontre à cette date';
  }

  String _emptySubtitle(AppLocalizations l10n) {
    if (_searchController.text.trim().isNotEmpty) {
      return 'Essayez une autre équipe, compétition ou pays.';
    }
    if (!_filters.isEmpty || _statusFilter != _MatchStatusFilter.all) {
      return l10n.noMatchesForFiltersSubtitle;
    }
    return 'Choisissez une autre date ou revenez à aujourd’hui.';
  }

  Future<void> _openFilters(List<MatchBoardItem> matches) async {
    final marketOptions = _displayedMarketOptions(matches);
    final selectedMarket = marketOptions.firstWhere(
      (option) => option.id == _displayedMarketId,
      orElse: () => marketOptions.first,
    );
    final bookmakerOptions = _bookmakerOptions(matches, selectedMarket.id);
    final selectedBookmaker = _selectedBookmaker(
      bookmakerOptions,
      selectedMarket.id,
    );
    final result = await showModalBottomSheet<_AllMatchesFilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _AllMatchesFilterSheet(
          matches: matches,
          filters: _filters,
          marketOptions: marketOptions,
          selectedMarketId: selectedMarket.id,
          bookmakerOptions: bookmakerOptions,
          selectedBookmakerKey: selectedBookmaker?.key,
          selectedStatusFilter: _statusFilter,
          favoriteIds: _favoriteIds,
          onReset: () => Navigator.of(context).pop(
            const _AllMatchesFilterResult(
              filters: _AllMatchesFilters.empty,
              displayedMarketId: 'matchResult',
              selectedBookmakerKey: null,
              statusFilter: _MatchStatusFilter.all,
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _filters = result.filters;
      _displayedMarketId = result.displayedMarketId;
      _selectedBookmakerKey = result.selectedBookmakerKey;
      _statusFilter = result.statusFilter;
    });
  }
}

class _EmptyMatchState extends StatelessWidget {
  const _EmptyMatchState({
    required this.title,
    required this.subtitle,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  final String title;
  final String subtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 36,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (primaryActionLabel != null && onPrimaryAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onPrimaryAction,
                child: Text(primaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SnapshotFreshnessLine extends StatelessWidget {
  const _SnapshotFreshnessLine({
    required this.metadata,
    required this.selectedDate,
  });

  final MatchFeedSnapshotMetadata? metadata;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final snapshot = metadata;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }

    final state = _SnapshotFreshnessState.from(snapshot, selectedDate);
    final colorScheme = Theme.of(context).colorScheme;
    final color = state.isWarning
        ? context.semantic.warning
        : context.brand.accent;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: color.withValues(alpha: 0.42)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(state.icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  state.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapshotFreshnessState {
  const _SnapshotFreshnessState({
    required this.label,
    required this.icon,
    required this.isWarning,
  });

  factory _SnapshotFreshnessState.from(
    MatchFeedSnapshotMetadata metadata,
    DateTime selectedDate,
  ) {
    final selectedLabel = _formatShortDate(selectedDate);
    final window = _formatWindow(metadata);
    final updatedAt = _formatCapturedAt(metadata.capturedAt);

    if (metadata.isEmpty) {
      return _SnapshotFreshnessState(
        label: 'Snapshot vide · $updatedAt$window',
        icon: Icons.event_busy_rounded,
        isWarning: true,
      );
    }

    if (!metadata.covers(selectedDate)) {
      return _SnapshotFreshnessState(
        label: 'Aucune donnée snapshot pour le $selectedLabel$window',
        icon: Icons.date_range_rounded,
        isWarning: true,
      );
    }

    if (metadata.isObsolete(DateTime.now())) {
      return _SnapshotFreshnessState(
        label: 'Snapshot obsolète · $updatedAt$window',
        icon: Icons.update_disabled_rounded,
        isWarning: true,
      );
    }

    return _SnapshotFreshnessState(
      label: 'Mis à jour $updatedAt$window',
      icon: Icons.refresh_rounded,
      isWarning: false,
    );
  }

  final String label;
  final IconData icon;
  final bool isWarning;
}

String _formatCapturedAt(DateTime? capturedAt) {
  if (capturedAt == null) {
    return 'date inconnue';
  }
  final local = capturedAt.toLocal();
  final today = DateTime.now();
  final datePrefix =
      local.year == today.year &&
          local.month == today.month &&
          local.day == today.day
      ? 'aujourd’hui'
      : 'le ${_formatShortDate(local)}';
  return '$datePrefix à ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _formatWindow(MatchFeedSnapshotMetadata metadata) {
  final start = metadata.windowStart;
  final end = metadata.windowEnd;
  if (start == null || end == null) {
    return '';
  }
  return ' · fenêtre ${_formatShortDate(start)}-${_formatShortDate(end)}';
}

String _formatShortDate(DateTime date) {
  final local = date.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _CountryMatchesPanel extends StatelessWidget {
  const _CountryMatchesPanel({
    required this.group,
    required this.isExpanded,
    required this.favoriteIds,
    required this.expandedCompetitionIds,
    required this.displayedMarket,
    required this.selectedBookmaker,
    required this.ticketDraft,
    required this.onToggleExpanded,
    required this.onToggleCompetition,
    required this.onToggleFavorite,
    required this.onToggleTicket,
    required this.onOpenMatch,
  });

  final _CountryGroup group;
  final bool isExpanded;
  final Set<String> favoriteIds;
  final Set<String> expandedCompetitionIds;
  final _DisplayedMarketOption displayedMarket;
  final _BookmakerOption? selectedBookmaker;
  final TicketDraft ticketDraft;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onToggleCompetition;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<TicketDraftSelection> onToggleTicket;
  final ValueChanged<MatchBoardItem> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = group.country.name == 'World'
        ? 'Europe'
        : group.country.name;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          children: [
            Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: onToggleExpanded,
                borderRadius: BorderRadius.circular(AppRadius.input),
                child: Row(
                  children: [
                    SportsAssetBadge(
                      size: 32,
                      imageUrl: group.country.flagUrl,
                      fallbackLabel: displayName,
                      borderRadius: AppRadius.chip,
                      backgroundColor: AppColors.transparent,
                      padding: 0,
                      icon: Icons.flag_rounded,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${group.competitions.length} compétition(s) · ${group.matchCount} match(s)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isExpanded
                          ? 'Réduire le pays'
                          : 'Développer le pays',
                      onPressed: onToggleExpanded,
                      icon: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.chevron_right_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppSpacing.md),
              for (final competition in group.competitions)
                _CompetitionMatchSection(
                  key: ValueKey(competition.competition.id),
                  competition: competition,
                  isExpanded: expandedCompetitionIds.contains(
                    competition.competition.id,
                  ),
                  favoriteIds: favoriteIds,
                  displayedMarket: displayedMarket,
                  selectedBookmaker: selectedBookmaker,
                  ticketDraft: ticketDraft,
                  onToggleExpanded: () =>
                      onToggleCompetition(competition.competition.id),
                  onToggleFavorite: onToggleFavorite,
                  onToggleTicket: onToggleTicket,
                  onOpenMatch: onOpenMatch,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompetitionMatchSection extends StatelessWidget {
  const _CompetitionMatchSection({
    required this.competition,
    required this.isExpanded,
    required this.favoriteIds,
    required this.displayedMarket,
    required this.selectedBookmaker,
    required this.ticketDraft,
    required this.onToggleExpanded,
    required this.onToggleFavorite,
    required this.onToggleTicket,
    required this.onOpenMatch,
    super.key,
  });

  final _CompetitionBucket competition;
  final bool isExpanded;
  final Set<String> favoriteIds;
  final _DisplayedMarketOption displayedMarket;
  final _BookmakerOption? selectedBookmaker;
  final TicketDraft ticketDraft;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<TicketDraftSelection> onToggleTicket;
  final ValueChanged<MatchBoardItem> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final favoriteId = 'competition:${competition.competition.id}';
    final isFavorite = favoriteIds.contains(favoriteId);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.input),
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    SportsAssetBadge(
                      size: 38,
                      imageUrl: competition.competition.logoUrl,
                      fallbackLabel: competition.competition.name,
                      borderRadius: AppRadius.input,
                      backgroundColor: AppColors.transparent,
                      padding: 0,
                      icon: Icons.emoji_events_rounded,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            competition.competition.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${competition.matches.length} match(s) · ${competition.matchCountWithOdds} avec cotes',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isFavorite
                          ? 'Retirer cette compétition des favoris'
                          : 'Ajouter cette compétition aux favoris',
                      onPressed: () => onToggleFavorite(favoriteId),
                      icon: Icon(
                        isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: isFavorite
                            ? context.components.favorite
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: AppSpacing.xs),
            for (final match in competition.matches)
              _AllMatchRow(
                match: match,
                favoriteIds: favoriteIds,
                displayedMarket: displayedMarket,
                selectedBookmaker: selectedBookmaker,
                ticketDraft: ticketDraft,
                onToggleFavorite: onToggleFavorite,
                onToggleTicket: onToggleTicket,
                onOpenMatch: () => onOpenMatch(match),
              ),
          ],
        ],
      ),
    );
  }
}

class _AllMatchRow extends StatelessWidget {
  const _AllMatchRow({
    required this.match,
    required this.favoriteIds,
    required this.displayedMarket,
    required this.selectedBookmaker,
    required this.ticketDraft,
    required this.onToggleFavorite,
    required this.onToggleTicket,
    required this.onOpenMatch,
  });

  final MatchBoardItem match;
  final Set<String> favoriteIds;
  final _DisplayedMarketOption displayedMarket;
  final _BookmakerOption? selectedBookmaker;
  final TicketDraft ticketDraft;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<TicketDraftSelection> onToggleTicket;
  final VoidCallback onOpenMatch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final favoriteId = 'match:${match.id}';
    final isFavorite = favoriteIds.contains(favoriteId);
    final market = _marketForDisplay(match);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpenMatch,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;
                if (!isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FavoriteIconButton(
                            isFavorite: isFavorite,
                            tooltip: isFavorite
                                ? 'Retirer cette rencontre des favoris'
                                : 'Ajouter cette rencontre aux favoris',
                            onPressed: () => onToggleFavorite(favoriteId),
                          ),
                          SizedBox(
                            width: 58,
                            child: _FixtureStatusBlock(match: match),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _AllMatchTeams(match: match)),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _DisplayedMarketOddsRow(
                        option: displayedMarket,
                        market: market,
                        match: match,
                        ticketDraft: ticketDraft,
                        onToggleTicket: onToggleTicket,
                      ),
                      const SizedBox(height: 8),
                      _CopilotSecondaryLine(match: match),
                    ],
                  );
                }

                return Row(
                  children: [
                    _FavoriteIconButton(
                      isFavorite: isFavorite,
                      tooltip: isFavorite
                          ? 'Retirer cette rencontre des favoris'
                          : 'Ajouter cette rencontre aux favoris',
                      onPressed: () => onToggleFavorite(favoriteId),
                    ),
                    SizedBox(
                      width: 74,
                      child: _FixtureStatusBlock(match: match),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: _AllMatchTeams(match: match)),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _DisplayedMarketOddsRow(
                        option: displayedMarket,
                        market: market,
                        match: match,
                        ticketDraft: ticketDraft,
                        onToggleTicket: onToggleTicket,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: _CopilotSecondaryLine(match: match),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  MatchMarket? _marketForDisplay(MatchBoardItem match) {
    for (final market in match.availableMarkets) {
      if (market.id != displayedMarket.id) {
        continue;
      }

      final bookmaker = selectedBookmaker;
      if (bookmaker == null || _bookmakerKey(market) == bookmaker.key) {
        return market;
      }
    }
    return null;
  }

  String _bookmakerKey(MatchMarket market) {
    final id = market.bookmakerId;
    if (id != null) {
      return 'id:$id';
    }
    return 'name:${market.bookmakerName ?? 'unknown'}';
  }
}

class _FavoriteIconButton extends StatelessWidget {
  const _FavoriteIconButton({
    required this.isFavorite,
    required this.tooltip,
    required this.onPressed,
  });

  final bool isFavorite;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(isFavorite ? Icons.star_rounded : Icons.star_border_rounded),
      color: isFavorite
          ? context.components.favorite
          : Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

class _FixtureStatusBlock extends StatelessWidget {
  const _FixtureStatusBlock({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semantic;
    final score = match.fixture.score;
    final status = match.fixture.status;
    final statusColor = switch (status) {
      FixtureStatus.live => semantic.live,
      FixtureStatus.finished => colorScheme.onSurfaceVariant,
      FixtureStatus.postponed || FixtureStatus.cancelled => colorScheme.error,
      FixtureStatus.scheduled => colorScheme.onSurface,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _statusLabel(match),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (score != null) ...[
          const SizedBox(height: 4),
          Text(
            '${score.home}-${score.away}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }

  String _statusLabel(MatchBoardItem match) {
    return switch (match.fixture.status) {
      FixtureStatus.scheduled =>
        match.fixture.kickoffLabel.isEmpty
            ? 'À confirmer'
            : match.fixture.kickoffLabel,
      FixtureStatus.live =>
        match.fixture.kickoffLabel.isEmpty
            ? 'Live'
            : match.fixture.kickoffLabel,
      FixtureStatus.finished => 'Terminé',
      FixtureStatus.postponed => 'Reporté',
      FixtureStatus.cancelled => 'Annulé',
    };
  }
}

class _DisplayedMarketOddsRow extends StatelessWidget {
  const _DisplayedMarketOddsRow({
    required this.option,
    required this.market,
    required this.match,
    required this.ticketDraft,
    required this.onToggleTicket,
  });

  final _DisplayedMarketOption option;
  final MatchMarket? market;
  final MatchBoardItem match;
  final TicketDraft ticketDraft;
  final ValueChanged<TicketDraftSelection> onToggleTicket;

  @override
  Widget build(BuildContext context) {
    if (option.isPlayerMarket) {
      return _PlayerMarketShortcut(match: match, isAvailable: market != null);
    }

    if (market == null) {
      return _UnavailableMarketRow(label: option.emptyLabel);
    }

    final columns = _columnsFor(option, market);
    if (columns.isEmpty) {
      return _UnavailableMarketRow(label: option.emptyLabel);
    }

    return Row(
      children: [
        for (final column in columns) ...[
          if (column != columns.first) const SizedBox(width: 8),
          Expanded(
            child: _OddColumn(
              column: column,
              match: match,
              market: market,
              ticketDraft: ticketDraft,
              onToggleTicket: onToggleTicket,
            ),
          ),
        ],
      ],
    );
  }

  List<_OddColumnData> _columnsFor(
    _DisplayedMarketOption option,
    MatchMarket? market,
  ) {
    final selections = market?.selections ?? const <MarketOdds>[];
    return switch (option.id) {
      'matchResult' => [
        _OddColumnData(
          label: '1',
          selection: _selectionByValue(selections, 'home'),
        ),
        _OddColumnData(
          label: 'N',
          selection: _selectionByValue(selections, 'draw'),
        ),
        _OddColumnData(
          label: '2',
          selection: _selectionByValue(selections, 'away'),
        ),
      ],
      'doubleChance' => [
        _OddColumnData(
          label: '1X',
          selection: _selectionByValue(selections, 'home/draw'),
        ),
        _OddColumnData(
          label: '12',
          selection: _selectionByValue(selections, 'home/away'),
        ),
        _OddColumnData(
          label: 'X2',
          selection: _selectionByValue(selections, 'draw/away'),
        ),
      ],
      'goalsTotal' => _overUnderColumns(selections, line: '2.5'),
      'bothTeamsScore' => [
        _OddColumnData(
          label: 'Oui',
          selection: _selectionByValue(selections, 'yes'),
        ),
        _OddColumnData(
          label: 'Non',
          selection: _selectionByValue(selections, 'no'),
        ),
      ],
      'teamTotalHome' => _overUnderColumns(selections, line: '0.5'),
      'teamTotalAway' => _overUnderColumns(selections, line: '0.5'),
      'firstHalfGoal' => [
        _OddColumnData(label: 'Oui', selection: null),
        _OddColumnData(label: 'Non', selection: null),
      ],
      _ => const [],
    };
  }

  List<_OddColumnData> _overUnderColumns(
    List<MarketOdds> selections, {
    required String line,
  }) {
    final over = _selectionByValue(selections, 'over $line');
    final under = _selectionByValue(selections, 'under $line');
    return [
      _OddColumnData(label: '+ $line', selection: over),
      _OddColumnData(label: '- $line', selection: under),
    ];
  }

  MarketOdds? _selectionByValue(List<MarketOdds> selections, String value) {
    final normalized = value.toLowerCase();
    for (final selection in selections) {
      if (selection.apiFootballValue?.toLowerCase() == normalized ||
          selection.label.toLowerCase() == normalized) {
        return selection;
      }
    }
    return null;
  }
}

class _OddColumnData {
  const _OddColumnData({required this.label, required this.selection});

  final String label;
  final MarketOdds? selection;
}

class _OddColumn extends StatelessWidget {
  const _OddColumn({
    required this.column,
    required this.match,
    required this.market,
    required this.ticketDraft,
    required this.onToggleTicket,
  });

  final _OddColumnData column;
  final MatchBoardItem match;
  final MatchMarket? market;
  final TicketDraft ticketDraft;
  final ValueChanged<TicketDraftSelection> onToggleTicket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selection = column.selection;
    final ticketSelection = selection == null || market == null
        ? null
        : TicketDraftSelection.fromMatchSelection(match, market!, selection);
    final isSelected =
        ticketSelection != null && ticketDraft.contains(ticketSelection.id);
    final isBlockedByMatch =
        ticketSelection != null &&
        ticketDraft.containsAnotherSelectionForMatch(ticketSelection);
    final canAdd = ticketSelection != null && (isSelected || !isBlockedByMatch);
    final tooltip = selection == null
        ? 'Cote indisponible'
        : isBlockedByMatch
        ? 'Ce match est déjà dans Mon ticket'
        : isSelected
        ? 'Retirer du ticket'
        : 'Ajouter au ticket';

    return Tooltip(
      message: tooltip,
      child: Material(
        color: context.components.oddsBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.odds),
          side: BorderSide(
            color: isSelected
                ? colorScheme.primary
                : context.components.oddsBorder,
          ),
        ),
        child: InkWell(
          onTap: canAdd ? () => onToggleTicket(ticketSelection) : null,
          borderRadius: BorderRadius.circular(AppRadius.odds),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      column.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selection == null
                          ? '—'
                          : selection.odds.toStringAsFixed(2),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: selection == null
                            ? colorScheme.onSurfaceVariant
                            : context.components.oddsText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (ticketSelection != null)
                  Positioned(
                    right: -4,
                    top: -5,
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : isBlockedByMatch
                          ? Icons.block_rounded
                          : Icons.add_circle_outline_rounded,
                      size: 17,
                      color: isBlockedByMatch
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailableMarketRow extends StatelessWidget {
  const _UnavailableMarketRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PlayerMarketShortcut extends StatelessWidget {
  const _PlayerMarketShortcut({required this.match, required this.isAvailable});

  final MatchBoardItem match;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return _UnavailableMarketRow(
      label: isAvailable ? 'Voir les buteurs >' : 'Cotes indisponibles',
    );
  }
}

class _CopilotSecondaryLine extends StatelessWidget {
  const _CopilotSecondaryLine({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final thesis = match.thesis;
    final count = thesis?.arguments.length ?? match.signals.length;
    final hasMarket = thesis?.hasRecommendedMarket == true;
    final inProfile = match.profileStatus == MatchProfileStatus.inProfile;
    final label = hasMarket
        ? 'Marché recommandé'
        : count > 0
        ? '$count argument${count > 1 ? 's' : ''}'
        : inProfile
        ? 'Correspond au profil'
        : 'Lecture indisponible';
    final icon = hasMarket
        ? Icons.auto_graph_rounded
        : count > 0
        ? Icons.insights_rounded
        : inProfile
        ? Icons.person_search_rounded
        : Icons.remove_circle_outline_rounded;

    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AllMatchTeams extends StatelessWidget {
  const _AllMatchTeams({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(child: _AllMatchTeamLine(team: match.homeTeam)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'vs',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(child: _AllMatchTeamLine(team: match.awayTeam, reverse: true)),
      ],
    );
  }
}

class _AllMatchTeamLine extends StatelessWidget {
  const _AllMatchTeamLine({required this.team, this.reverse = false});

  final TeamInfo team;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final logo = SportsAssetBadge(
      size: 30,
      imageUrl: team.logoUrl,
      fallbackLabel: team.name,
      borderRadius: 5,
    );
    final name = Expanded(
      child: Tooltip(
        message: team.name,
        child: Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: reverse ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    return Row(
      children: reverse
          ? [name, const SizedBox(width: 10), logo]
          : [logo, const SizedBox(width: 10), name],
    );
  }
}

class _AllMatchesFilterSheet extends StatefulWidget {
  const _AllMatchesFilterSheet({
    required this.matches,
    required this.filters,
    required this.marketOptions,
    required this.selectedMarketId,
    required this.bookmakerOptions,
    required this.selectedBookmakerKey,
    required this.selectedStatusFilter,
    required this.favoriteIds,
    required this.onReset,
  });

  final List<MatchBoardItem> matches;
  final _AllMatchesFilters filters;
  final List<_DisplayedMarketOption> marketOptions;
  final String selectedMarketId;
  final List<_BookmakerOption> bookmakerOptions;
  final String? selectedBookmakerKey;
  final _MatchStatusFilter selectedStatusFilter;
  final Set<String> favoriteIds;
  final VoidCallback onReset;

  @override
  State<_AllMatchesFilterSheet> createState() => _AllMatchesFilterSheetState();
}

class _AllMatchesFilterSheetState extends State<_AllMatchesFilterSheet> {
  late _AllMatchesFilters _draft;
  late String _selectedMarketId;
  late String? _selectedBookmakerKey;
  late _MatchStatusFilter _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    _draft = widget.filters;
    _selectedMarketId = widget.selectedMarketId;
    _selectedBookmakerKey = widget.selectedBookmakerKey;
    _selectedStatusFilter = widget.selectedStatusFilter;
  }

  @override
  Widget build(BuildContext context) {
    final countries = _countries(widget.matches);
    final competitions = _competitions(widget.matches, _draft.countryCodes);
    final markets = _markets(widget.matches);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.94,
        minChildSize: 0.40,
        builder: (context, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtres',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _draft = _AllMatchesFilters.empty;
                        _selectedMarketId = 'matchResult';
                        _selectedBookmakerKey = null;
                        _selectedStatusFilter = _MatchStatusFilter.all;
                      });
                      widget.onReset();
                    },
                    child: const Text('Réinitialiser'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FilterSection(
                title: 'Marché affiché',
                children: [
                  for (final market in widget.marketOptions)
                    _ChoiceChip<String>(
                      label: market.shortLabel,
                      value: market.id,
                      groupValue: _selectedMarketId,
                      onSelected: (value) => setState(() {
                        _selectedMarketId = value;
                        _selectedBookmakerKey = null;
                      }),
                    ),
                ],
              ),
              _FilterSection(
                title: 'Bookmaker',
                children: [
                  for (final bookmaker in _bookmakersForSelectedMarket())
                    _ChoiceChip<String>(
                      label: bookmaker.label,
                      value: bookmaker.key,
                      groupValue:
                          _selectedBookmakerKey ?? widget.selectedBookmakerKey,
                      onSelected: (value) => setState(() {
                        _selectedBookmakerKey = value;
                      }),
                    ),
                ],
              ),
              _FilterSection(
                title: 'État',
                children: [
                  _ChoiceChip<_MatchStatusFilter>(
                    label: 'Tous',
                    value: _MatchStatusFilter.all,
                    groupValue: _selectedStatusFilter,
                    onSelected: (value) => setState(() {
                      _selectedStatusFilter = value;
                    }),
                  ),
                  _ChoiceChip<_MatchStatusFilter>(
                    label: 'Live',
                    value: _MatchStatusFilter.live,
                    groupValue: _selectedStatusFilter,
                    onSelected: (value) => setState(() {
                      _selectedStatusFilter = value;
                    }),
                  ),
                  _ChoiceChip<_MatchStatusFilter>(
                    label: 'À venir',
                    value: _MatchStatusFilter.scheduled,
                    groupValue: _selectedStatusFilter,
                    onSelected: (value) => setState(() {
                      _selectedStatusFilter = value;
                    }),
                  ),
                  _ChoiceChip<_MatchStatusFilter>(
                    label: 'Résultats',
                    value: _MatchStatusFilter.finished,
                    groupValue: _selectedStatusFilter,
                    onSelected: (value) => setState(() {
                      _selectedStatusFilter = value;
                    }),
                  ),
                ],
              ),
              _FilterSection(
                title: 'Pays',
                children: [
                  for (final country in countries)
                    FilterChip(
                      label: Text(country.name),
                      selected: _draft.countryCodes.contains(country.code),
                      onSelected: (_) {
                        final updatedCountries = {..._draft.countryCodes};
                        _toggleValue(updatedCountries, country.code);
                        final allowedCompetitionIds = _competitions(
                          widget.matches,
                          updatedCountries,
                        ).map((competition) => competition.id).toSet();
                        setState(() {
                          _draft = _draft.copyWith(
                            countryCodes: updatedCountries,
                            competitionIds: {
                              for (final id in _draft.competitionIds)
                                if (allowedCompetitionIds.contains(id)) id,
                            },
                          );
                        });
                      },
                    ),
                ],
              ),
              _FilterSection(
                title: 'Compétitions',
                children: [
                  for (final competition in competitions)
                    FilterChip(
                      label: Text(competition.name),
                      selected: _draft.competitionIds.contains(competition.id),
                      onSelected: (_) {
                        final updated = {..._draft.competitionIds};
                        _toggleValue(updated, competition.id);
                        setState(() {
                          _draft = _draft.copyWith(competitionIds: updated);
                        });
                      },
                    ),
                ],
              ),
              _FilterSection(
                title: 'Disponibilité des cotes',
                children: [
                  _ChoiceChip<_OddsAvailabilityFilter>(
                    label: 'Tous les matchs',
                    value: _OddsAvailabilityFilter.all,
                    groupValue: _draft.oddsAvailability,
                    onSelected: (value) => setState(() {
                      _draft = _draft.copyWith(oddsAvailability: value);
                    }),
                  ),
                  _ChoiceChip<_OddsAvailabilityFilter>(
                    label: 'Avec cotes',
                    value: _OddsAvailabilityFilter.withOdds,
                    groupValue: _draft.oddsAvailability,
                    onSelected: (value) => setState(() {
                      _draft = _draft.copyWith(oddsAvailability: value);
                    }),
                  ),
                  _ChoiceChip<_OddsAvailabilityFilter>(
                    label: 'Sans cotes',
                    value: _OddsAvailabilityFilter.withoutOdds,
                    groupValue: _draft.oddsAvailability,
                    onSelected: (value) => setState(() {
                      _draft = _draft.copyWith(oddsAvailability: value);
                    }),
                  ),
                ],
              ),
              _FilterSection(
                title: 'Marchés disponibles',
                children: [
                  for (final market in markets)
                    FilterChip(
                      label: Text(_marketLabel(market)),
                      selected: _draft.marketIds.contains(market),
                      onSelected: (_) {
                        final updated = {..._draft.marketIds};
                        _toggleValue(updated, market);
                        setState(() {
                          _draft = _draft.copyWith(marketIds: updated);
                        });
                      },
                    ),
                ],
              ),
              _FilterSection(
                title: 'Informations Copilot',
                children: [
                  _ChoiceChip<_CopilotInfoFilter>(
                    label: 'Tous les matchs',
                    value: _CopilotInfoFilter.all,
                    groupValue: _draft.copilotInfo,
                    onSelected: (value) => setState(() {
                      _draft = _draft.copyWith(copilotInfo: value);
                    }),
                  ),
                  _ChoiceChip<_CopilotInfoFilter>(
                    label: 'Avec lecture Copilot',
                    value: _CopilotInfoFilter.withReading,
                    groupValue: _draft.copilotInfo,
                    onSelected: (value) => setState(() {
                      _draft = _draft.copyWith(copilotInfo: value);
                    }),
                  ),
                  _ChoiceChip<_CopilotInfoFilter>(
                    label: 'Marché recommandé',
                    value: _CopilotInfoFilter.withRecommendedMarket,
                    groupValue: _draft.copilotInfo,
                    onSelected: (value) => setState(() {
                      _draft = _draft.copyWith(copilotInfo: value);
                    }),
                  ),
                  _ChoiceChip<_CopilotInfoFilter>(
                    label: 'Correspond au profil',
                    value: _CopilotInfoFilter.matchingProfile,
                    groupValue: _draft.copilotInfo,
                    onSelected: (value) => setState(() {
                      _draft = _draft.copyWith(copilotInfo: value);
                    }),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Favoris uniquement'),
                subtitle: Text(
                  widget.favoriteIds.isEmpty
                      ? 'Aucun favori enregistré pour le moment.'
                      : '${widget.favoriteIds.length} favori(s) enregistré(s).',
                ),
                value: _draft.favoritesOnly,
                onChanged: (value) {
                  setState(() {
                    _draft = _draft.copyWith(favoritesOnly: value);
                  });
                },
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _AllMatchesFilterResult(
                    filters: _draft,
                    displayedMarketId: _selectedMarketId,
                    selectedBookmakerKey: _effectiveBookmakerKey(),
                    statusFilter: _selectedStatusFilter,
                  ),
                ),
                child: Text(
                  _activeCount == 0
                      ? 'Appliquer'
                      : 'Appliquer $_activeCount filtre(s)',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ces filtres n’influencent pas “Pour moi” ni le générateur.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int get _activeCount {
    return _draft.activeCount +
        (_selectedMarketId == 'matchResult' ? 0 : 1) +
        (_selectedStatusFilter == _MatchStatusFilter.all ? 0 : 1) +
        (_selectedBookmakerKey == null ? 0 : 1);
  }

  List<_BookmakerOption> _bookmakersForSelectedMarket() {
    final byKey = <String, _BookmakerOption>{};
    for (final match in widget.matches) {
      for (final market in match.availableMarkets) {
        if (market.id != _selectedMarketId) {
          continue;
        }
        final key = _bookmakerKey(market);
        byKey[key] = _BookmakerOption(
          key: key,
          label: market.bookmakerName ?? 'Bookmaker inconnu',
          bookmakerId: market.bookmakerId,
        );
      }
    }

    final options = byKey.values.toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    if (options.isEmpty) {
      return widget.bookmakerOptions;
    }
    return options;
  }

  String? _effectiveBookmakerKey() {
    final options = _bookmakersForSelectedMarket();
    if (options.isEmpty) {
      return null;
    }

    final selected = _selectedBookmakerKey;
    if (selected != null && options.any((option) => option.key == selected)) {
      return selected;
    }

    return options.first.key;
  }

  String _bookmakerKey(MatchMarket market) {
    final id = market.bookmakerId;
    if (id != null) {
      return 'id:$id';
    }
    return 'name:${market.bookmakerName ?? 'unknown'}';
  }

  List<CountryInfo> _countries(List<MatchBoardItem> matches) {
    final byCode = <String, CountryInfo>{};
    for (final match in matches) {
      byCode[match.competition.country.code] = match.competition.country;
    }
    return byCode.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<CompetitionInfo> _competitions(
    List<MatchBoardItem> matches,
    Set<String> countryCodes,
  ) {
    final byId = <String, CompetitionInfo>{};
    for (final match in matches) {
      if (countryCodes.isNotEmpty &&
          !countryCodes.contains(match.competition.country.code)) {
        continue;
      }
      byId[match.competition.id] = match.competition;
    }
    return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<String> _markets(List<MatchBoardItem> matches) {
    final ids = <String>{};
    for (final match in matches) {
      ids.addAll(match.availableMarkets.map((market) => market.id));
    }
    return ids.toList()..sort();
  }

  void _toggleValue(Set<String> values, String value) {
    if (values.contains(value)) {
      values.remove(value);
    } else {
      values.add(value);
    }
  }

  String _marketLabel(String id) {
    return switch (id) {
      'matchResult' => 'Résultat du match',
      'doubleChance' => 'Double chance',
      'overUnderGoals' => 'Plus/Moins buts',
      'bothTeamsScore' => 'Les deux équipes marquent',
      'firstHalfGoal' => 'But 1re mi-temps',
      'playerAnytimeScorer' => 'Buteur',
      _ => id,
    };
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _ChoiceChip<T> extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final T value;
  final T? groupValue;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: value == groupValue,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _CountryGroupBuilder {
  _CountryGroupBuilder({required this.country});

  final CountryInfo country;
  final Map<String, _CompetitionBucket> competitions = {};
}

class _CountryGroup {
  const _CountryGroup({required this.country, required this.competitions});

  final CountryInfo country;
  final List<_CompetitionBucket> competitions;

  int get matchCount => competitions.fold(
    0,
    (count, competition) => count + competition.matches.length,
  );
}

class _CompetitionBucket {
  const _CompetitionBucket({
    required this.country,
    required this.competition,
    required this.matches,
  });

  final String country;
  final CompetitionInfo competition;
  final List<MatchBoardItem> matches;

  int get matchCountWithOdds =>
      matches.where((match) => match.availableMarkets.isNotEmpty).length;
}

class _ForMeFilters {
  const _ForMeFilters({
    this.includeWithRecommendedMarket = true,
    this.includeWithoutRecommendedMarket = true,
    this.profileIds = const {},
    this.competitionIds = const {},
  });

  final bool includeWithRecommendedMarket;
  final bool includeWithoutRecommendedMarket;
  final Set<String> profileIds;
  final Set<String> competitionIds;

  static const empty = _ForMeFilters();

  int get activeCount {
    return (includeWithRecommendedMarket ? 0 : 1) +
        (includeWithoutRecommendedMarket ? 0 : 1) +
        profileIds.length +
        competitionIds.length;
  }

  bool get isEmpty => activeCount == 0;

  _ForMeFilters copyWith({
    bool? includeWithRecommendedMarket,
    bool? includeWithoutRecommendedMarket,
    Set<String>? profileIds,
    Set<String>? competitionIds,
  }) {
    return _ForMeFilters(
      includeWithRecommendedMarket:
          includeWithRecommendedMarket ?? this.includeWithRecommendedMarket,
      includeWithoutRecommendedMarket:
          includeWithoutRecommendedMarket ??
          this.includeWithoutRecommendedMarket,
      profileIds: profileIds ?? this.profileIds,
      competitionIds: competitionIds ?? this.competitionIds,
    );
  }
}

enum _ForMeSortOrder {
  readingStrength('Lecture Copilot'),
  kickoff('Heure'),
  recommendedOdds('Cote');

  const _ForMeSortOrder(this.label);

  final String label;
}

class _MatchList extends StatefulWidget {
  const _MatchList({
    required this.profile,
    required this.compiledProfile,
    required this.opportunities,
    required this.snapshotMetadata,
    required this.ticketDraft,
    required this.onToggleTicket,
    required this.onOpenOpportunity,
    required this.onSeeAllMatches,
    required this.onEditProfile,
  });

  final DecisionProfile profile;
  final CompiledDecisionProfile compiledProfile;
  final List<Opportunity> opportunities;
  final MatchFeedSnapshotMetadata? snapshotMetadata;
  final TicketDraft ticketDraft;
  final ValueChanged<TicketDraftSelection> onToggleTicket;
  final ValueChanged<Opportunity> onOpenOpportunity;
  final VoidCallback onSeeAllMatches;
  final VoidCallback onEditProfile;

  @override
  State<_MatchList> createState() => _MatchListState();
}

class _MatchListState extends State<_MatchList> {
  DateTime? _selectedDate;
  _ForMeFilters _filters = _ForMeFilters.empty;
  _ForMeSortOrder _sortOrder = _ForMeSortOrder.readingStrength;

  @override
  Widget build(BuildContext context) {
    final today = _today();
    final selectedDate = _selectedDate ?? today;
    final datedOpportunities = widget.opportunities
        .where((opportunity) => _isOpportunityOnDate(opportunity, selectedDate))
        .toList();
    final filteredOpportunities = _applyFilters(datedOpportunities);
    final orderedOpportunities = [...filteredOpportunities]
      ..sort(_compareOpportunities);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: orderedOpportunities.isEmpty
                ? widget.opportunities.isEmpty
                      ? _ForMeEmptyDashboard(
                          profile: widget.profile,
                          compiledProfile: widget.compiledProfile,
                          snapshotMetadata: widget.snapshotMetadata,
                          selectedDate: selectedDate,
                          onSeeAllMatches: widget.onSeeAllMatches,
                          onEditProfile: widget.onEditProfile,
                        )
                      : _ForMeRecommendationsDashboard(
                          opportunities: const [],
                          totalForDate: datedOpportunities.length,
                          filters: _filters,
                          selectedDate: selectedDate,
                          snapshotMetadata: widget.snapshotMetadata,
                          sortOrder: _sortOrder,
                          ticketDraft: widget.ticketDraft,
                          onToggleTicket: widget.onToggleTicket,
                          onOpenOpportunity: widget.onOpenOpportunity,
                          onSeeAllMatches: widget.onSeeAllMatches,
                          onDateSelected: (date) {
                            setState(() {
                              _selectedDate = date;
                            });
                          },
                          onChooseDate: _chooseDate,
                          onSortChanged: (sortOrder) {
                            setState(() {
                              _sortOrder = sortOrder;
                            });
                          },
                          onOpenFilters: () => _openFilters(datedOpportunities),
                          onResetFilters: () {
                            setState(() {
                              _filters = _ForMeFilters.empty;
                            });
                          },
                        )
                : _ForMeRecommendationsDashboard(
                    opportunities: orderedOpportunities,
                    totalForDate: datedOpportunities.length,
                    filters: _filters,
                    selectedDate: selectedDate,
                    snapshotMetadata: widget.snapshotMetadata,
                    sortOrder: _sortOrder,
                    ticketDraft: widget.ticketDraft,
                    onToggleTicket: widget.onToggleTicket,
                    onOpenOpportunity: widget.onOpenOpportunity,
                    onSeeAllMatches: widget.onSeeAllMatches,
                    onDateSelected: (date) {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    onChooseDate: _chooseDate,
                    onSortChanged: (sortOrder) {
                      setState(() {
                        _sortOrder = sortOrder;
                      });
                    },
                    onOpenFilters: () => _openFilters(datedOpportunities),
                    onResetFilters: () {
                      setState(() {
                        _filters = _ForMeFilters.empty;
                      });
                    },
                  ),
          ),
        ),
      ],
    );
  }

  int _compareOpportunities(Opportunity a, Opportunity b) {
    return switch (_sortOrder) {
      _ForMeSortOrder.readingStrength => _compareByReadingStrength(a, b),
      _ForMeSortOrder.kickoff => _compareByKickoff(a, b),
      _ForMeSortOrder.recommendedOdds => _compareByRecommendedOdds(a, b),
    };
  }

  int _compareByReadingStrength(Opportunity a, Opportunity b) {
    final readingComparison = _readingStrength(
      b,
    ).compareTo(_readingStrength(a));
    if (readingComparison != 0) {
      return readingComparison;
    }

    final engineComparison = b.engineScore.compareTo(a.engineScore);
    if (engineComparison != 0) {
      return engineComparison;
    }

    return _compareByKickoff(a, b);
  }

  int _compareByKickoff(Opportunity a, Opportunity b) {
    final aKickoff = a.kickoff;
    final bKickoff = b.kickoff;
    if (aKickoff != null && bKickoff != null) {
      final kickoffComparison = aKickoff.compareTo(bKickoff);
      if (kickoffComparison != 0) {
        return kickoffComparison;
      }
    } else if (aKickoff != null) {
      return -1;
    } else if (bKickoff != null) {
      return 1;
    }

    return a.homeTeam.name.compareTo(b.homeTeam.name);
  }

  int _compareByRecommendedOdds(Opportunity a, Opportunity b) {
    final aOdds = a.recommendedMarket?.selection.odds;
    final bOdds = b.recommendedMarket?.selection.odds;
    if (aOdds != null && bOdds != null) {
      final oddsComparison = bOdds.compareTo(aOdds);
      if (oddsComparison != 0) {
        return oddsComparison;
      }
    } else if (aOdds != null) {
      return -1;
    } else if (bOdds != null) {
      return 1;
    }

    return _compareByReadingStrength(a, b);
  }

  int _readingStrength(Opportunity opportunity) {
    return opportunity.argumentCount - opportunity.contradictionCount;
  }

  List<Opportunity> _applyFilters(List<Opportunity> opportunities) {
    return opportunities.where((opportunity) {
      if (opportunity.hasRecommendedMarket &&
          !_filters.includeWithRecommendedMarket) {
        return false;
      }
      if (!opportunity.hasRecommendedMarket &&
          !_filters.includeWithoutRecommendedMarket) {
        return false;
      }
      if (_filters.profileIds.isNotEmpty &&
          !opportunity.opportunityProfileIds.any(
            _filters.profileIds.contains,
          )) {
        return false;
      }
      if (_filters.competitionIds.isNotEmpty &&
          !_filters.competitionIds.contains(opportunity.competition.id)) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _isOpportunityOnDate(Opportunity opportunity, DateTime selectedDate) {
    final kickoff = opportunity.kickoff?.toLocal();
    if (kickoff == null) {
      return _isSameDay(selectedDate, _today());
    }

    return _isSameDay(kickoff, selectedDate);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _chooseDate() async {
    final initialDate = _selectedDate ?? _today();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 1),
      lastDate: DateTime(initialDate.year + 1),
    );
    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(selected.year, selected.month, selected.day);
    });
  }

  Future<void> _openFilters(List<Opportunity> opportunitiesForDate) async {
    final updatedFilters = await showModalBottomSheet<_ForMeFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _ForMeFiltersSheet(
          initialFilters: _filters,
          opportunities: opportunitiesForDate,
        );
      },
    );

    if (updatedFilters == null || !mounted) {
      return;
    }

    setState(() {
      _filters = updatedFilters;
    });
  }
}

class _ForMeRecommendationsDashboard extends StatelessWidget {
  const _ForMeRecommendationsDashboard({
    required this.opportunities,
    required this.totalForDate,
    required this.filters,
    required this.selectedDate,
    required this.snapshotMetadata,
    required this.sortOrder,
    required this.ticketDraft,
    required this.onToggleTicket,
    required this.onOpenOpportunity,
    required this.onSeeAllMatches,
    required this.onDateSelected,
    required this.onChooseDate,
    required this.onSortChanged,
    required this.onOpenFilters,
    required this.onResetFilters,
  });

  final List<Opportunity> opportunities;
  final int totalForDate;
  final _ForMeFilters filters;
  final DateTime selectedDate;
  final MatchFeedSnapshotMetadata? snapshotMetadata;
  final _ForMeSortOrder sortOrder;
  final TicketDraft ticketDraft;
  final ValueChanged<TicketDraftSelection> onToggleTicket;
  final ValueChanged<Opportunity> onOpenOpportunity;
  final VoidCallback onSeeAllMatches;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onChooseDate;
  final ValueChanged<_ForMeSortOrder> onSortChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ForMeSimpleHeader(),
        const SizedBox(height: 18),
        CopilotCalendar(
          selectedDate: selectedDate,
          visibleWindowDays: 7,
          onDateSelected: onDateSelected,
          onChooseDate: onChooseDate,
        ),
        _SnapshotFreshnessLine(
          metadata: snapshotMetadata,
          selectedDate: selectedDate,
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final title = _ForMeSectionHeading(
              opportunityCount: opportunities.length,
            );
            final actions = Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.end,
              children: [
                _ForMeSortButton(
                  sortOrder: sortOrder,
                  onChanged: onSortChanged,
                ),
                _ForMeDisplayButton(
                  activeFilterCount: filters.activeCount,
                  onPressed: onOpenFilters,
                ),
              ],
            );

            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: AppSpacing.sm),
                  actions,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.md),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (opportunities.isEmpty)
          _EmptyMatchState(
            title: totalForDate == 0
                ? 'Aucune lecture combinée ce jour'
                : 'Aucune lecture combinée pour cet affichage',
            subtitle: totalForDate == 0
                ? 'Naviguez vers un autre jour pour consulter les lectures combinées disponibles.'
                : 'Ajustez les profils ou les options d’affichage pour retrouver des lectures.',
            primaryActionLabel: filters.isEmpty
                ? 'Toutes les rencontres'
                : 'Réinitialiser',
            onPrimaryAction: filters.isEmpty ? onSeeAllMatches : onResetFilters,
          )
        else
          for (final opportunity in opportunities)
            Builder(
              builder: (context) {
                final ticketSelection = TicketDraftSelection.fromOpportunity(
                  opportunity,
                );
                final canToggle =
                    ticketSelection != null &&
                    ticketDraft.canToggle(ticketSelection);
                return _ForMeOpportunityRow(
                  opportunity: opportunity,
                  isSelected:
                      ticketSelection != null &&
                      ticketDraft.contains(ticketSelection.id),
                  onToggleTicket: !canToggle
                      ? null
                      : () => onToggleTicket(ticketSelection),
                  onOpenOpportunity: () => onOpenOpportunity(opportunity),
                );
              },
            ),
      ],
    );
  }
}

class _ForMeSimpleHeader extends StatelessWidget {
  const _ForMeSimpleHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pour moi',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Des lectures combinées sélectionnées selon votre profil.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ForMeSectionHeading extends StatelessWidget {
  const _ForMeSectionHeading({required this.opportunityCount});

  final int opportunityCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Mes lectures combinées',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '$opportunityCount lecture(s) combinée(s) trouvée(s)',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ForMeDisplayButton extends StatelessWidget {
  const _ForMeDisplayButton({
    required this.activeFilterCount,
    required this.onPressed,
  });

  final int activeFilterCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Affichage'),
        ),
        if (activeFilterCount > 0)
          Positioned(
            right: -7,
            top: -7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Text(
                  '$activeFilterCount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ForMeSortButton extends StatelessWidget {
  const _ForMeSortButton({required this.sortOrder, required this.onChanged});

  final _ForMeSortOrder sortOrder;
  final ValueChanged<_ForMeSortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopupMenuButton<_ForMeSortOrder>(
      tooltip: 'Trier',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in _ForMeSortOrder.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == sortOrder
                      ? Icons.check_rounded
                      : Icons.sort_rounded,
                  size: 18,
                  color: option == sortOrder
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(option.label),
              ],
            ),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort_rounded, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 8),
              Text(
                'Trier',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForMeFiltersSheet extends StatefulWidget {
  const _ForMeFiltersSheet({
    required this.initialFilters,
    required this.opportunities,
  });

  final _ForMeFilters initialFilters;
  final List<Opportunity> opportunities;

  @override
  State<_ForMeFiltersSheet> createState() => _ForMeFiltersSheetState();
}

class _ForMeFiltersSheetState extends State<_ForMeFiltersSheet> {
  late _ForMeFilters _draft = widget.initialFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileCounts = _profileCounts(widget.opportunities);
    final competitionCounts = _competitionCounts(widget.opportunities);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Affichage',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!_draft.isEmpty)
                    Text(
                      '${_draft.activeCount} filtre(s)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _ForMeFilterSectionTitle(label: 'Affichage'),
                    _ForMeCheckboxTile(
                      label: 'Lectures avec marché recommandé',
                      value: _draft.includeWithRecommendedMarket,
                      onChanged: (value) {
                        setState(() {
                          _draft = _draft.copyWith(
                            includeWithRecommendedMarket: value,
                          );
                        });
                      },
                    ),
                    _ForMeCheckboxTile(
                      label: 'Lectures sans marché',
                      value: _draft.includeWithoutRecommendedMarket,
                      onChanged: (value) {
                        setState(() {
                          _draft = _draft.copyWith(
                            includeWithoutRecommendedMarket: value,
                          );
                        });
                      },
                    ),
                    const _ForMeSheetDivider(),
                    _ForMeFilterSectionTitle(label: 'Profils'),
                    for (final definition in OpportunityProfileCatalog.values)
                      _ForMeCheckboxTile(
                        label: definition.label,
                        count: profileCounts[definition.id] ?? 0,
                        value: _draft.profileIds.contains(definition.id),
                        onChanged: (value) {
                          setState(() {
                            final next = {..._draft.profileIds};
                            if (value) {
                              next.add(definition.id);
                            } else {
                              next.remove(definition.id);
                            }
                            _draft = _draft.copyWith(profileIds: next);
                          });
                        },
                      ),
                    const _ForMeSheetDivider(),
                    _ForMeFilterSectionTitle(label: 'Compétitions'),
                    _ForMeCheckboxTile(
                      label: 'Toutes',
                      value: _draft.competitionIds.isEmpty,
                      onChanged: (value) {
                        if (!value) {
                          return;
                        }
                        setState(() {
                          _draft = _draft.copyWith(competitionIds: const {});
                        });
                      },
                    ),
                    for (final entry in competitionCounts.entries)
                      _ForMeCheckboxTile(
                        label: entry.value.name,
                        count: entry.value.count,
                        value: _draft.competitionIds.contains(entry.key),
                        onChanged: (value) {
                          setState(() {
                            final next = {..._draft.competitionIds};
                            if (value) {
                              next.add(entry.key);
                            } else {
                              next.remove(entry.key);
                            }
                            _draft = _draft.copyWith(competitionIds: next);
                          });
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _draft = _ForMeFilters.empty;
                        });
                      },
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: const Text('Appliquer'),
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

  Map<String, int> _profileCounts(List<Opportunity> opportunities) {
    final counts = <String, int>{};
    for (final opportunity in opportunities) {
      for (final profileId in opportunity.opportunityProfileIds) {
        counts.update(profileId, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  Map<String, _ForMeCompetitionFilterOption> _competitionCounts(
    List<Opportunity> opportunities,
  ) {
    final counts = <String, _ForMeCompetitionFilterOption>{};
    for (final opportunity in opportunities) {
      final competition = opportunity.competition;
      final current = counts[competition.id];
      counts[competition.id] = _ForMeCompetitionFilterOption(
        name: competition.name,
        count: (current?.count ?? 0) + 1,
      );
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));
    return Map.fromEntries(entries);
  }
}

class _ForMeCompetitionFilterOption {
  const _ForMeCompetitionFilterOption({
    required this.name,
    required this.count,
  });

  final String name;
  final int count;
}

class _ForMeFilterSectionTitle extends StatelessWidget {
  const _ForMeFilterSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ForMeCheckboxTile extends StatelessWidget {
  const _ForMeCheckboxTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.count,
  });

  final String label;
  final int? count;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: (next) => onChanged(next ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (count != null)
            Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _ForMeSheetDivider extends StatelessWidget {
  const _ForMeSheetDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

class _ForMeEmptyDashboard extends StatelessWidget {
  const _ForMeEmptyDashboard({
    required this.profile,
    required this.compiledProfile,
    required this.snapshotMetadata,
    required this.selectedDate,
    required this.onSeeAllMatches,
    required this.onEditProfile,
  });

  final DecisionProfile profile;
  final CompiledDecisionProfile compiledProfile;
  final MatchFeedSnapshotMetadata? snapshotMetadata;
  final DateTime selectedDate;
  final VoidCallback onSeeAllMatches;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    if (!compiledProfile.isCompleted) {
      return _ForMeIncompleteProfileDashboard(onEditProfile: onEditProfile);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SnapshotFreshnessLine(
          metadata: snapshotMetadata,
          selectedDate: selectedDate,
        ),
        if (snapshotMetadata != null) const SizedBox(height: 16),
        _ForMeEmptyHero(
          onSeeAllMatches: onSeeAllMatches,
          onEditProfile: onEditProfile,
        ),
        const SizedBox(height: 24),
        Text(
          'Vos préférences en un coup d’œil',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        _ProfilePreferenceGrid(profile: profile),
        const SizedBox(height: 24),
        const _NotificationBanner(
          title: 'Restez informé',
          subtitle:
              'Activez les notifications pour être alerté dès qu’un match correspondant à votre profil est détecté.',
          buttonLabel: 'Activer les notifications',
        ),
        const SizedBox(height: 24),
        const _ForMeFootnote(
          text:
              'Le moteur analyse en permanence les rencontres disponibles pour vous proposer uniquement les plus pertinentes selon votre façon de parier.',
        ),
      ],
    );
  }
}

class _ForMeIncompleteProfileDashboard extends StatelessWidget {
  const _ForMeIncompleteProfileDashboard({required this.onEditProfile});

  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _DashboardCard(
      padding: const EdgeInsets.all(26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoundIcon(
            icon: Icons.tune_rounded,
            color: colorScheme.primary,
            size: 64,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configurez vos préférences',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Configurez vos préférences pour permettre à Copilot de rechercher les situations qui vous intéressent.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onEditProfile,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Configurer mon profil'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ForMeHeroCard extends StatelessWidget {
  const _ForMeHeroCard({
    required this.matchCount,
    required this.topCount,
    required this.watchCount,
    required this.otherCount,
    required this.onSeeAllMatches,
  });

  final int matchCount;
  final int topCount;
  final int watchCount;
  final int otherCount;
  final VoidCallback onSeeAllMatches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _DashboardCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final summary = Row(
                children: [
                  _RoundIcon(
                    icon: Icons.track_changes_rounded,
                    color: colorScheme.primary,
                    size: 58,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vos rencontres du jour',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$matchCount lecture(s) combinée(s) correspondent à vos profils.\nMises à jour en continu.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final metrics = Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _HeroMetric(label: 'Lectures fortes', value: topCount),
                  _MetricDivider(),
                  _HeroMetric(
                    label: 'À surveiller',
                    value: watchCount,
                    color: context.semantic.warning,
                  ),
                  _MetricDivider(),
                  _HeroMetric(
                    label: 'Autres',
                    value: otherCount,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  IconButton(
                    onPressed: onSeeAllMatches,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              );

              if (!isWide) {
                return Column(
                  children: [summary, const SizedBox(height: 22), metrics],
                );
              }

              return Row(
                children: [
                  Expanded(child: summary),
                  SizedBox(
                    height: 82,
                    child: VerticalDivider(color: colorScheme.outlineVariant),
                  ),
                  Expanded(child: metrics),
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;
              final width = isWide
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _HeroInfoTile(
                      icon: Icons.emoji_events_outlined,
                      title: 'Des lectures combinées intéressantes',
                      subtitle:
                          '$topCount lecture(s) combinée(s) présentent des signaux forts selon votre profil.',
                      actionLabel: 'Voir les matchs',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: const _HeroInfoTile(
                      icon: Icons.track_changes_rounded,
                      title: 'Marchés adaptés',
                      subtitle:
                          'Les marchés proposés sont compatibles avec vos préférences.',
                      actionLabel: 'Découvrir',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: const _HeroInfoTile(
                      icon: Icons.show_chart_rounded,
                      title: 'Données à jour',
                      subtitle:
                          'Formes, classements et cotes viennent du snapshot API-Football.',
                      actionLabel: 'Voir les sources',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ForMeEmptyHero extends StatelessWidget {
  const _ForMeEmptyHero({
    required this.onSeeAllMatches,
    required this.onEditProfile,
  });

  final VoidCallback onSeeAllMatches;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _DashboardCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoundIcon(
                icon: Icons.check_rounded,
                color: colorScheme.primary,
                size: 78,
                outlined: true,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aucune situation détectée',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune situation correspondant à votre profil n’a été détectée pour le moment.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;
              final width = isWide
                  ? (constraints.maxWidth - 2) / 3
                  : constraints.maxWidth;
              return Wrap(
                children: [
                  SizedBox(
                    width: width,
                    child: const _EmptyReasonTile(
                      icon: Icons.emoji_events_outlined,
                      title: 'Peu de lectures combinées aujourd’hui',
                      subtitle:
                          'Les profils de lecture sélectionnés peuvent être rares selon le calendrier.',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: const _EmptyReasonTile(
                      icon: Icons.track_changes_rounded,
                      title: 'Marchés non disponibles',
                      subtitle:
                          'Les lectures sans marché restent affichées dès qu’une lecture sportive correspond au profil.',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: const _EmptyReasonTile(
                      icon: Icons.sync_rounded,
                      title: 'Données en cours de mise à jour',
                      subtitle:
                          'Les données sont actualisées en continu. Revenez dans quelques minutes.',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  _RoundIcon(icon: Icons.lightbulb_outline_rounded),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vous pouvez aussi :',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InlineAction(
                          label: 'Voir toutes les rencontres disponibles',
                          onPressed: onSeeAllMatches,
                        ),
                        const SizedBox(height: 8),
                        _InlineAction(
                          label: 'Ajuster vos préférences',
                          onPressed: onEditProfile,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForMeOpportunityRow extends StatelessWidget {
  const _ForMeOpportunityRow({
    required this.opportunity,
    required this.isSelected,
    required this.onToggleTicket,
    required this.onOpenOpportunity,
  });

  final Opportunity opportunity;
  final bool isSelected;
  final VoidCallback? onToggleTicket;
  final VoidCallback onOpenOpportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.70)
        : colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onOpenOpportunity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 20, 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 430;
                final isCompact = constraints.maxWidth < 620;
                final left = _ForMeMatchPanel(opportunity: opportunity);
                final right = _ForMeRecommendationPanel(
                  opportunity: opportunity,
                  isSelected: isSelected,
                  onToggleTicket: onToggleTicket,
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      left,
                      const SizedBox(height: AppSpacing.md),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.70,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      right,
                    ],
                  );
                }

                if (isCompact) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: left),
                      const SizedBox(width: 14),
                      Container(
                        width: 1,
                        height: 196,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.70,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(flex: 10, child: right),
                    ],
                  );
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 12, child: left),
                      const SizedBox(width: 22),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.72,
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(flex: 11, child: right),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ForMeMatchPanel extends StatelessWidget {
  const _ForMeMatchPanel({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final score = opportunity.fixture.score;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ForMeCompetitionLine(opportunity: opportunity),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                children: [
                  _ForMeTeamLine(team: opportunity.homeTeam),
                  const SizedBox(height: 13),
                  _ForMeTeamLine(team: opportunity.awayTeam),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: score == null
                  ? Text(
                      'vs',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Column(
                      children: [
                        Text(
                          '${score.home}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${score.away}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ForMeReadingLine(opportunity: opportunity),
      ],
    );
  }
}

class _ForMeCompetitionLine extends StatelessWidget {
  const _ForMeCompetitionLine({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = opportunity.fixture.status;
    final isLive = status == FixtureStatus.live;
    final timeLabel = opportunity.fixture.kickoffLabel;

    return Row(
      children: [
        SportsAssetBadge(
          size: 26,
          imageUrl: opportunity.competition.logoUrl,
          fallbackLabel: opportunity.competition.name,
          borderRadius: 5,
          icon: Icons.emoji_events_rounded,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            opportunity.competition.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (isLive) ...[
          const SizedBox(width: 10),
          const _ForMeLiveBadge(),
          const SizedBox(width: 9),
          Text(
            timeLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ] else if (timeLabel.isNotEmpty) ...[
          const SizedBox(width: 10),
          SizedBox(
            height: 16,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            timeLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _ForMeLiveBadge extends StatelessWidget {
  const _ForMeLiveBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.components.liveBadgeBackground,
        borderRadius: BorderRadius.circular(AppRadius.indicator),
        border: Border.all(color: context.components.liveBadgeText),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          'LIVE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.components.liveBadgeText,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ForMeTeamLine extends StatelessWidget {
  const _ForMeTeamLine({required this.team});

  final TeamInfo team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SportsAssetBadge(
          size: 42,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          borderRadius: 7,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ForMeReadingLine extends StatelessWidget {
  const _ForMeReadingLine({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.auto_awesome_rounded, color: colorScheme.primary, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lecture Copilot',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              _ForMeReadingCounters(opportunity: opportunity),
            ],
          ),
        ),
      ],
    );
  }
}

class _ForMeReadingCounters extends StatelessWidget {
  const _ForMeReadingCounters({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final arguments = opportunity.argumentCount;
    final contradictions = opportunity.contradictionCount;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          '$arguments argument${arguments > 1 ? 's' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '$contradictions contradiction${contradictions > 1 ? 's' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: contradictions == 0
                ? colorScheme.onSurfaceVariant
                : context.semantic.warning,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ForMeRecommendationPanel extends StatelessWidget {
  const _ForMeRecommendationPanel({
    required this.opportunity,
    required this.isSelected,
    required this.onToggleTicket,
  });

  final Opportunity opportunity;
  final bool isSelected;
  final VoidCallback? onToggleTicket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recommendedMarket = opportunity.recommendedMarket;
    final argumentsCount = opportunity.argumentCount;
    final contradictionsCount = opportunity.contradictionCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ForMeProfileBadge(opportunity: opportunity)),
            const SizedBox(width: 8),
            _ForMeTicketAddButton(
              isSelected: isSelected,
              isEnabled: onToggleTicket != null,
              disabledTooltip: recommendedMarket == null
                  ? 'Marché indisponible'
                  : 'Ce match est déjà dans Mon ticket',
              onPressed: onToggleTicket,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Marché recommandé',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        _ForMeRecommendedMarketBox(recommendedMarket: recommendedMarket),
        const SizedBox(height: 14),
        _ForMeReadingSummaryRow(
          argumentsCount: argumentsCount,
          contradictionsCount: contradictionsCount,
        ),
      ],
    );
  }
}

class _ForMeReadingSummaryRow extends StatelessWidget {
  const _ForMeReadingSummaryRow({
    required this.argumentsCount,
    required this.contradictionsCount,
  });

  final int argumentsCount;
  final int contradictionsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.content_paste_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                '$argumentsCount argument${argumentsCount > 1 ? 's' : ''}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$contradictionsCount contradiction${contradictionsCount > 1 ? 's' : ''}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: contradictionsCount == 0
                      ? colorScheme.onSurfaceVariant
                      : context.semantic.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: colorScheme.onSurface,
          size: 28,
        ),
      ],
    );
  }
}

class _ForMeTicketAddButton extends StatelessWidget {
  const _ForMeTicketAddButton({
    required this.isSelected,
    required this.isEnabled,
    required this.disabledTooltip,
    required this.onPressed,
  });

  final bool isSelected;
  final bool isEnabled;
  final String disabledTooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isSelected) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_rounded, size: 17),
        label: const Text('Ajouté'),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.18),
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return IconButton.filled(
      onPressed: isEnabled ? onPressed : null,
      tooltip: isEnabled ? 'Ajouter au ticket' : disabledTooltip,
      icon: const Icon(Icons.add_rounded),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: colorScheme.surfaceContainerHighest,
        disabledForegroundColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),
    );
  }
}

class _ForMeProfileBadge extends StatelessWidget {
  const _ForMeProfileBadge({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thesis = opportunity.primaryThesis;
    final profileId = OpportunityProfileCatalog.profileIdForThesis(thesis.id);
    final label =
        OpportunityProfileCatalog.byId(profileId ?? '')?.label ??
        OpportunityDecisionPresenter.opportunityTitleFromTheses([thesis]);
    final badge = context.opportunities.badgeFor(
      thesis.id,
      variant: AppReadingBadgeVariant.combined,
    );
    final isSolidFavorite = thesis.id == 'solid_favorite';

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: badge.background,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: badge.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: badge.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isSolidFavorite) ...[
                const SizedBox(width: 7),
                Icon(
                  Icons.star_border_rounded,
                  color: badge.iconColor,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ForMeRecommendedMarketBox extends StatelessWidget {
  const _ForMeRecommendedMarketBox({required this.recommendedMarket});

  final RecommendedMarket? recommendedMarket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = recommendedMarket?.selection;
    final market = recommendedMarket?.market;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(AppRadius.odds),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
        child: selected == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aucun marché recommandé',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lecture conservée sans sélection ajoutable.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recommendedSelectionLabel(market, selected),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected.odds.toStringAsFixed(2),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: context.components.oddsText,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    market?.bookmakerName ??
                        selected.bookmakerName ??
                        'Bookmaker',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _recommendedSelectionLabel(MatchMarket? market, MarketOdds selected) {
    final marketLabel = market?.label ?? '';
    if (marketLabel.toLowerCase().contains('double chance')) {
      return '${selected.label} (Double chance)';
    }
    if (marketLabel.toLowerCase().contains('both') ||
        marketLabel.toLowerCase().contains('deux équipes')) {
      return 'BTTS (${selected.label})';
    }
    if (marketLabel.toLowerCase().contains('résultat') ||
        marketLabel.toLowerCase().contains('1 n 2')) {
      return '${selected.label} (Victoire domicile)';
    }
    return selected.label;
  }
}

// ignore: unused_element
class _OpportunitySignals extends StatelessWidget {
  const _OpportunitySignals({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileIds = opportunity.opportunityProfileIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SportsAssetBadge(
              size: 30,
              imageUrl: opportunity.competition.logoUrl,
              fallbackLabel: opportunity.competition.name,
              borderRadius: 5,
              icon: Icons.emoji_events_rounded,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                opportunity.competition.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${profileIds.length} profil(s) · ${opportunity.detectedSignals.length} signal(aux)',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final profileId in profileIds.take(4))
              _OpportunityProfileChip(profileId: profileId),
          ],
        ),
        const SizedBox(height: 8),
        _OpportunitySummary(opportunity: opportunity),
      ],
    );
  }
}

class _OpportunityProfileChip extends StatelessWidget {
  const _OpportunityProfileChip({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) {
    final definition = OpportunityProfileCatalog.byId(profileId);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.tight),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          definition?.label ?? profileId,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _OpportunitySummary extends StatelessWidget {
  const _OpportunitySummary({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      opportunity.primaryThesis.summary,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    );
  }
}

// ignore: unused_element
class _RecommendationMarket extends StatelessWidget {
  const _RecommendationMarket({required this.recommendedMarket});

  final RecommendedMarket? recommendedMarket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = recommendedMarket?.selection;
    final market = recommendedMarket?.market;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: selected == null
            ? Text(
                'Lecture détectée — aucun marché correspondant à vos préférences.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              )
            : Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.tight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        selected.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          market?.label ?? 'Marché',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selected.odds.toStringAsFixed(2),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: selected.odds >= 1.70
                                ? context.semantic.warning
                                : colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (market?.bookmakerName != null)
                    Text(
                      market!.bookmakerName!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    this.color,
    this.size = 56,
    this.outlined = false,
  });

  final IconData icon;
  final Color? color;
  final double size;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: outlined ? 0.04 : 0.13),
        shape: BoxShape.circle,
        border: outlined ? Border.all(color: effectiveColor, width: 4) : null,
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, color: effectiveColor, size: size * 0.48),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value, this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: effectiveColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: VerticalDivider(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _HeroInfoTile extends StatelessWidget {
  const _HeroInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundIcon(icon: icon, size: 38),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InlineAction(label: actionLabel, onPressed: () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReasonTile extends StatelessWidget {
  const _EmptyReasonTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundIcon(icon: icon, size: 46),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ProfileGlanceCard extends StatelessWidget {
  const _ProfileGlanceCard({required this.profile});

  final DecisionProfile profile;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'En un coup d’œil',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          _ProfilePreferenceGrid(profile: profile),
        ],
      ),
    );
  }
}

class _ProfilePreferenceGrid extends StatelessWidget {
  const _ProfilePreferenceGrid({required this.profile});

  final DecisionProfile profile;

  @override
  Widget build(BuildContext context) {
    final items = [
      _PreferenceMetric(
        icon: Icons.public_rounded,
        title: 'Compétitions',
        value: '${_answerCount(profile, 'competitions')} suivies',
      ),
      _PreferenceMetric(
        icon: Icons.track_changes_rounded,
        title: 'Marchés favoris',
        value: '${_answerCount(profile, 'markets')} sélectionnés',
        color: context.opportunities.levelGap,
      ),
      _PreferenceMetric(
        icon: Icons.join_inner_rounded,
        title: 'Profils recherchés',
        value: '${_answerCount(profile, 'opportunity_profiles')} activés',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 580;
        final width = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _PreferenceMetricTile(item: item),
              ),
          ],
        );
      },
    );
  }

  static int _answerCount(DecisionProfile profile, String questionId) {
    for (final answer in profile.answers) {
      if (answer.questionId == questionId) {
        return answer.orderedOptionIds.length;
      }
    }
    if (questionId == 'opportunity_profiles') {
      for (final answer in profile.answers) {
        if (answer.questionId == 'match_types') {
          return answer.orderedOptionIds.length;
        }
      }
    }
    return 0;
  }
}

class _PreferenceMetric {
  const _PreferenceMetric({
    required this.icon,
    required this.title,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? color;
}

class _PreferenceMetricTile extends StatelessWidget {
  const _PreferenceMetricTile({required this.item});

  final _PreferenceMetric item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.color ?? theme.colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _RoundIcon(icon: item.icon, color: color, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.ticketCount});

  final int ticketCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Votre activité',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Cette semaine',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: _ActivityMetric(value: 0, label: 'matchs consultés'),
              ),
              _MetricDivider(),
              const Expanded(
                child: _ActivityMetric(value: 0, label: 'marchés suivis'),
              ),
              _MetricDivider(),
              Expanded(
                child: _ActivityMetric(
                  value: ticketCount,
                  label: 'tickets créés',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InlineAction(label: 'Voir mon historique', onPressed: () {}),
        ],
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _DashboardCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoundIcon(
                icon: Icons.notifications_none_rounded,
                color: context.semantic.warning,
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(onPressed: () {}, child: Text(buttonLabel)),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton(onPressed: () {}, child: Text(buttonLabel)),
            ],
          );
        },
      ),
    );
  }
}

class _ForMeFootnote extends StatelessWidget {
  const _ForMeFootnote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.indicator),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _DashboardDivider extends StatelessWidget {
  const _DashboardDivider({required this.isVertical});

  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    if (!isVertical) {
      return Divider(height: 24, color: color);
    }

    return SizedBox(height: 72, child: VerticalDivider(color: color));
  }
}
