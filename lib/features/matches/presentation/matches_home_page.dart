import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/deck/lector_deck.dart';
import '../../../core/auth/supabase_auth_controller.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/debug/runtime_personalization_diagnostic.dart';
import '../../../core/identity/identity_controller.dart';
import '../../../core/identity/identity_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../../core/widgets/google_brand_icon.dart';
import '../../../core/widgets/lector_brand_mark.dart';
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
import '../../tickets/domain/ticket_generator.dart';
import '../../tickets/domain/ticket_strategy.dart';
import '../../tickets/presentation/ticket_builder_panel.dart';
import '../../tickets/presentation/ticket_generator_page.dart';
import '../../tickets/presentation/ticket_history_page.dart';
import '../data/match_feed_repository.dart';
import '../data/match_feed_repository_loader.dart';
import '../data/saved_match_favorites_store.dart';
import '../domain/match_board_item.dart';
import 'lector_preferences_sheet.dart';
import 'lector_space_page.dart';
import 'match_detail_page.dart';
import 'opportunity_decision_presenter.dart';
import 'widgets/copilot_calendar.dart';
import 'widgets/sports_asset_badge.dart';

class MatchesHomePage extends StatefulWidget {
  const MatchesHomePage({
    required this.profile,
    required this.identityScope,
    required this.onEditProfile,
    required this.ticketStrategies,
    this.onProfileChanged,
    this.onTicketStrategiesChanged,
    this.repositoryOverride,
    super.key,
  });

  final DecisionProfile profile;
  final IdentityScope identityScope;
  final VoidCallback onEditProfile;
  final ProfilePreferenceSaver? onProfileChanged;
  final TicketStrategyPreferenceSaver? onTicketStrategiesChanged;
  final List<TicketStrategy> ticketStrategies;
  final MatchFeedRepository? repositoryOverride;

  @override
  State<MatchesHomePage> createState() => _MatchesHomePageState();
}

class _MatchesHomePageState extends State<MatchesHomePage> {
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
  String? _lastPersonalizationTraceSignature;
  bool _hasTracedMatchesLoaded = false;
  DateTime _selectedScoresDate = _todayDate();
  bool _hasUserSelectedScoresDate = false;
  _ScoresRedesignMode _scoresMode = _ScoresRedesignMode.forMe;

  @override
  void initState() {
    super.initState();
    _repository = widget.repositoryOverride == null
        ? _loadRepository()
        : Future.value(widget.repositoryOverride);
    _loadSavedTickets();
  }

  @override
  void didUpdateWidget(covariant MatchesHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identityScope != widget.identityScope) {
      _ticketDraft = TicketDraft.empty;
      _ticketDraftNotifier.value = TicketDraft.empty;
      _savedTickets = const [];
      _isTicketPanelExpanded = false;
      _lastTicketSettlementSignature = null;
      _loadSavedTickets();
    }
  }

  @override
  void dispose() {
    _ticketDraftNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          final personalizedMatches = repository.personalizedFor(
            widget.profile,
          );
          final allMatches = repository.allMatches();
          final snapshotMetadata = repository.snapshotMetadata;
          final analyzedAllMatches = [
            for (final match in allMatches)
              repository.analyzeFor(widget.profile, match),
          ];
          final ticketGenerationResult = const TicketGenerator().generate(
            matches: personalizedMatches,
            strategies: widget.ticketStrategies,
            profile: compiledProfile,
          );
          final effectiveSelectedDate = _resolvedScoresDate(
            selectedDate: _selectedScoresDate,
            matches: analyzedAllMatches,
            metadata: snapshotMetadata,
            allowAutomaticFallback: !_hasUserSelectedScoresDate,
          );
          _tracePersonalization(
            profile: widget.profile,
            compiledProfile: compiledProfile,
            allMatches: analyzedAllMatches,
            personalizedMatches: personalizedMatches,
            selectedDate: effectiveSelectedDate,
          );
          if (!_hasTracedMatchesLoaded) {
            _hasTracedMatchesLoaded = true;
            RuntimePersonalizationDiagnostic.instance.recordLifecycle(
              'matches loaded',
              fields: {
                'scope': widget.identityScope.stableKey,
                'matchCount': analyzedAllMatches.length,
                'snapshotSource': snapshotMetadata?.source,
              },
            );
          }
          _latestOpportunities = opportunities;
          _latestAnalyzedMatches = analyzedAllMatches;
          _scheduleSavedTicketSettlement(analyzedAllMatches);
          void openAnalyzedMatch(MatchBoardItem match) {
            final opportunity = opportunities
                .where((item) => item.matchId == match.id)
                .firstOrNull;
            if (opportunity != null) {
              _openOpportunityDetails(
                opportunity,
                match: repository.analyzeFor(widget.profile, match),
              );
              return;
            }
            _openMatchDetails(repository.analyzeFor(widget.profile, match));
          }

          return _ScoresRedesignHome(
            profile: widget.profile,
            identityScope: widget.identityScope,
            matches: analyzedAllMatches,
            personalizedMatches: personalizedMatches,
            opportunities: opportunities,
            snapshotMetadata: snapshotMetadata,
            selectedDate: effectiveSelectedDate,
            mode: _scoresMode,
            onModeChanged: (mode) {
              setState(() {
                _scoresMode = mode;
              });
            },
            onDateSelected: (date) {
              setState(() {
                _selectedScoresDate = _dateOnly(date);
                _hasUserSelectedScoresDate = true;
              });
            },
            onChooseDate: _chooseScoresDate,
            onOpenMatch: openAnalyzedMatch,
            onOpenOpportunity: _openOpportunityDetails,
            onOpenProfile: () => _showAccountSheet(context),
            onOpenTheme: _openLectorSpace,
            hasGeneratorResults: ticketGenerationResult.tickets.isNotEmpty,
            hasSavedTickets: _savedTickets.isNotEmpty,
            hasActiveStrategies: widget.ticketStrategies.any(
              (strategy) => strategy.isActive,
            ),
            onOpenTicketHistory: _openTicketHistorySheet,
            onRecalculateTickets: _refreshTicketProposals,
            onOpenStrategies: _openTicketStrategies,
            generator: TicketGeneratorPage(
              profile: compiledProfile,
              matches: personalizedMatches,
              opportunities: opportunities,
              strategies: widget.ticketStrategies,
              savedTickets: _savedTickets,
              onEditProfile: _openLectorSpace,
              onEditStrategies: _openTicketStrategies,
              onCreateManualTicket: _startManualTicketFromGenerator,
              onOpenOpportunity: _openOpportunityDetails,
              onSaveTicket: _upsertSavedTicket,
              onDeleteSavedTicket: _deleteSavedTicket,
            ),
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

  Future<void> _chooseScoresDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedScoresDate,
      firstDate: DateTime(_selectedScoresDate.year - 1),
      lastDate: DateTime(_selectedScoresDate.year + 1),
    );
    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedScoresDate = _dateOnly(selected);
      _hasUserSelectedScoresDate = true;
    });
  }

  void _tracePersonalization({
    required DecisionProfile profile,
    required CompiledDecisionProfile compiledProfile,
    required List<MatchBoardItem> allMatches,
    required List<MatchBoardItem> personalizedMatches,
    required DateTime selectedDate,
  }) {
    final diagnostic = RuntimePersonalizationDiagnostic.instance;
    if (!diagnostic.isEnabled) return;

    final matchesOnDate = allMatches
        .where(
          (match) => _isSameCalendarDay(
            lectorLocalCalendarDateForFixture(match.fixture) ?? _todayDate(),
            selectedDate,
          ),
        )
        .toList(growable: false);
    final includedIds = personalizedMatches
        .where(
          (match) => _isSameCalendarDay(
            lectorLocalCalendarDateForFixture(match.fixture) ?? _todayDate(),
            selectedDate,
          ),
        )
        .map((match) => match.id)
        .toSet();
    final traceMatches = [
      for (final match in matchesOnDate)
        {
          'matchId': match.id,
          'competitionId': match.competition.id,
          'attentionMatches': match.profileRelevance.readingMatches,
          'scenarioMatches': match.profileRelevance.thesisMatches,
          'marketMatches': match.profileRelevance.marketMatches,
          'included': includedIds.contains(match.id),
        },
    ];
    final profileHash = diagnostic.hashFor(jsonEncode(profile.toJson()));
    final intelligenceHash = diagnostic.hashFor(
      jsonEncode([
        for (final match in allMatches)
          [
            match.id,
            match.analysis.contextKeys.length,
            match.profileRelevance.readingMatches,
            match.profileRelevance.thesisMatches,
            match.profileRelevance.marketMatches,
          ],
      ]),
    );
    final signature = [
      profileHash,
      intelligenceHash,
      selectedDate.toIso8601String(),
      includedIds.length,
    ].join(':');
    if (signature == _lastPersonalizationTraceSignature) return;
    _lastPersonalizationTraceSignature = signature;
    diagnostic.recordForMe(
      selectedDate: selectedDate,
      profileHash: profileHash,
      matchIntelligenceHash: intelligenceHash,
      matchesOnDate: matchesOnDate.length,
      matchesInFollowedCompetitions: matchesOnDate
          .where(
            (match) =>
                compiledProfile.isCompetitionEnabled(match.competition.id),
          )
          .length,
      matchesMatchingAttention: matchesOnDate
          .where((match) => match.profileRelevance.readingMatches > 0)
          .length,
      matchesMatchingScenarios: matchesOnDate
          .where((match) => match.profileRelevance.thesisMatches > 0)
          .length,
      matchesMatchingMarkets: matchesOnDate
          .where((match) => match.profileRelevance.marketMatches > 0)
          .length,
      matches: traceMatches,
    );
    diagnostic.recordLifecycle('personalization executed');
  }

  void _showAccountSheet(BuildContext context) {
    final controller = getIt.isRegistered<SupabaseAuthController>()
        ? getIt<SupabaseAuthController>()
        : null;
    final identityController = getIt.isRegistered<IdentityController>()
        ? getIt<IdentityController>()
        : null;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: context.surfaces.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
            child: _HeaderAccountSheet(
              controller: controller,
              identityController: identityController,
            ),
          ),
        );
      },
    );
  }

  void _openLectorSpace() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LectorSpacePage(
          profile: widget.profile,
          ticketStrategies: widget.ticketStrategies,
          onProfileChanged: widget.onProfileChanged ?? (_) async {},
          onTicketStrategiesChanged:
              widget.onTicketStrategiesChanged ?? (_) async {},
        ),
      ),
    );
  }

  void _openTicketHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: TicketHistoryPage(
            savedTickets: _savedTickets,
            onTicketChanged: _upsertSavedTicket,
            onTicketDeleted: _deleteSavedTicket,
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  void _refreshTicketProposals() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Les propositions sont recalculées à partir des données disponibles.',
        ),
      ),
    );
    setState(() {});
  }

  void _openTicketStrategies() {
    showTicketBuilderPreferencesSheet(
      context: context,
      strategies: widget.ticketStrategies,
      onTicketStrategiesChanged:
          widget.onTicketStrategiesChanged ?? (_) async {},
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
    final scope = widget.identityScope;
    final tickets = await _savedTicketStore.load(scope: scope);
    if (!mounted) {
      return;
    }
    if (widget.identityScope != scope) {
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
      await _savedTicketStore.saveAll(
        scope: widget.identityScope,
        tickets: settledTickets,
      );
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
    _savedTicketStore.upsert(scope: widget.identityScope, ticket: ticket);
  }

  void _deleteSavedTicket(String ticketId) {
    setState(() {
      _savedTickets = [
        for (final ticket in _savedTickets)
          if (ticket.id != ticketId) ticket,
      ];
    });
    _savedTicketStore.delete(scope: widget.identityScope, ticketId: ticketId);
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
      _scoresMode = _ScoresRedesignMode.generator;
    });
  }

  void _startManualTicketFromGenerator() {
    setState(() {
      _scoresMode = _ScoresRedesignMode.all;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Choisissez des sélections depuis les matchs pour créer votre ticket.',
        ),
      ),
    );
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
          onOpenGenerator: () {
            Navigator.of(context).maybePop();
            _openTicketsTab();
          },
        ),
      ),
    );
  }

  void _openOpportunityDetails(
    Opportunity opportunity, {
    MatchBoardItem? match,
  }) {
    final analyzedMatch =
        match ??
        _latestAnalyzedMatches
            .where((item) => item.id == opportunity.matchId)
            .firstOrNull ??
        opportunity.toMatchBoardItem();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MatchDetailPage(
          match: analyzedMatch,
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
          onOpenGenerator: () {
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

enum _ScoresRedesignMode { forMe, all, generator }

LectorDeckScope _deckScopeForMode(_ScoresRedesignMode mode) {
  return switch (mode) {
    _ScoresRedesignMode.forMe => LectorDeckScope.forMe,
    _ScoresRedesignMode.all => LectorDeckScope.all,
    _ScoresRedesignMode.generator => LectorDeckScope.generator,
  };
}

DateTime _todayDate() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _dateOnly(DateTime date) {
  return lectorLocalCalendarDate(date);
}

String _initialsForUser(User? user) {
  return _initialsForName(_displayNameForUser(user) ?? user?.email ?? 'LS');
}

String? _displayNameForUser(User? user) {
  final metadata = user?.userMetadata;
  for (final key in ['full_name', 'name', 'display_name']) {
    final value = metadata?[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String _initialsForName(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+|@'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
  if (parts.isNotEmpty) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return 'LS';
}

bool _hasGoogleIdentity(User? user) {
  if (user == null) {
    return false;
  }
  final provider = user.appMetadata['provider']?.toString().toLowerCase();
  if (provider == 'google') {
    return true;
  }
  return user.identities?.any(
        (identity) => identity.provider.toLowerCase() == 'google',
      ) ??
      false;
}

String? _validateCredentials(String email, String password) {
  if (!_looksLikeEmail(email)) {
    return 'Saisissez une adresse e-mail valide.';
  }
  if (password.length < 6) {
    return 'Le mot de passe doit contenir au moins 6 caractères.';
  }
  return null;
}

bool _looksLikeEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

String _friendlyAuthError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login') ||
        message.contains('invalid credentials') ||
        message.contains('email not confirmed') ||
        message.contains('password')) {
      return 'Adresse e-mail ou mot de passe incorrect.';
    }
    if (message.contains('user not found') || message.contains('not found')) {
      return 'Aucun compte ne correspond à cette adresse e-mail.';
    }
    if (message.contains('email')) {
      return 'Vérifiez votre adresse e-mail puis réessayez.';
    }
    if (message.contains('network') || message.contains('timeout')) {
      return 'La connexion réseau semble indisponible. Réessayez dans un instant.';
    }
  }
  if (error is StateError) {
    return 'Connexion indisponible dans cet environnement. Réessayez plus tard.';
  }
  return 'Connexion impossible pour le moment. Réessayez dans un instant.';
}

DateTime _resolvedScoresDate({
  required DateTime selectedDate,
  required List<MatchBoardItem> matches,
  required MatchFeedSnapshotMetadata? metadata,
  required bool allowAutomaticFallback,
}) {
  final selectedDay = _dateOnly(selectedDate);
  final hasMatchOnSelectedDate = matches.any((match) {
    final fixtureDay = lectorLocalCalendarDateForFixture(match.fixture);
    return fixtureDay != null && _isSameCalendarDay(fixtureDay, selectedDay);
  });
  if (hasMatchOnSelectedDate) {
    return selectedDay;
  }

  if (!allowAutomaticFallback) {
    return selectedDay;
  }

  for (final match in [...matches]..sort(_ScoresRedesignHome._compareMatches)) {
    final fixtureDay = lectorLocalCalendarDateForFixture(match.fixture);
    if (fixtureDay != null) {
      return fixtureDay;
    }
  }

  final coversSelectedDate = metadata?.covers(selectedDay) ?? false;
  if (coversSelectedDate) {
    return selectedDay;
  }

  final windowStart = metadata?.windowStart;
  if (windowStart != null) {
    return _dateOnly(windowStart);
  }

  return selectedDay;
}

bool _isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ScoresRedesignHome extends StatefulWidget {
  const _ScoresRedesignHome({
    required this.profile,
    required this.identityScope,
    required this.matches,
    required this.personalizedMatches,
    required this.opportunities,
    required this.snapshotMetadata,
    required this.selectedDate,
    required this.mode,
    required this.onModeChanged,
    required this.onDateSelected,
    required this.onChooseDate,
    required this.onOpenMatch,
    required this.onOpenOpportunity,
    required this.onOpenProfile,
    required this.onOpenTheme,
    required this.hasGeneratorResults,
    required this.hasSavedTickets,
    required this.hasActiveStrategies,
    required this.onOpenTicketHistory,
    required this.onRecalculateTickets,
    required this.onOpenStrategies,
    required this.generator,
  });

  final DecisionProfile profile;
  final IdentityScope identityScope;
  final List<MatchBoardItem> matches;
  final List<MatchBoardItem> personalizedMatches;
  final List<Opportunity> opportunities;
  final MatchFeedSnapshotMetadata? snapshotMetadata;
  final DateTime selectedDate;
  final _ScoresRedesignMode mode;
  final ValueChanged<_ScoresRedesignMode> onModeChanged;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onChooseDate;
  final ValueChanged<MatchBoardItem> onOpenMatch;
  final ValueChanged<Opportunity> onOpenOpportunity;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenTheme;
  final bool hasGeneratorResults;
  final bool hasSavedTickets;
  final bool hasActiveStrategies;
  final VoidCallback onOpenTicketHistory;
  final VoidCallback onRecalculateTickets;
  final VoidCallback onOpenStrategies;
  final Widget generator;

  @override
  State<_ScoresRedesignHome> createState() => _ScoresRedesignHomeState();

  static bool _hasReadableSignal(MatchBoardItem match) {
    return match.thesis != null || match.signals.isNotEmpty;
  }

  static int _compareMatches(MatchBoardItem a, MatchBoardItem b) {
    final aKickoff = a.fixture.kickoff;
    final bKickoff = b.fixture.kickoff;
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
}

class _ScoresRedesignHomeState extends State<_ScoresRedesignHome> {
  bool _areAllStoriesVisible = false;
  String? _selectedForMeReadingId;

  @override
  void didUpdateWidget(covariant _ScoresRedesignHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        !_isSameCalendarDay(oldWidget.selectedDate, widget.selectedDate)) {
      _areAllStoriesVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleMatches = _matchesForModeAndDate();
    final allStoryMatches = _storyMatches(visibleMatches);
    final readingFilters = _readingFilters(allStoryMatches);
    final activeReadingId =
        readingFilters
            .where((filter) => filter.id == _selectedForMeReadingId)
            .isNotEmpty
        ? _selectedForMeReadingId
        : null;
    final filteredStoryMatches = activeReadingId == null
        ? allStoryMatches
        : allStoryMatches
              .where(
                (match) => _matchReadingIds(match).contains(activeReadingId),
              )
              .toList(growable: false);
    final storyMatches = _areAllStoriesVisible
        ? filteredStoryMatches
        : filteredStoryMatches.take(3).toList(growable: false);
    final competitionGroups = _competitionGroups(visibleMatches);
    final showsGenerator = widget.mode == _ScoresRedesignMode.generator;
    final listTitle = switch (widget.mode) {
      _ScoresRedesignMode.forMe => 'Ma sélection',
      _ScoresRedesignMode.all => 'Tous les matchs',
      _ScoresRedesignMode.generator => 'Générateur',
    };
    final listSubtitle = switch (widget.mode) {
      _ScoresRedesignMode.forMe =>
        'Modifiez vos championnats ou vos scénarios depuis Mon espace.',
      _ScoresRedesignMode.all => 'Essayez un autre jour ou un autre mode.',
      _ScoresRedesignMode.generator =>
        'Configurez vos sélections depuis les paramètres Lector.',
    };
    final showsStories = widget.mode == _ScoresRedesignMode.forMe;
    final hasMoreStories = filteredStoryMatches.length > 3;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {},
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ScoresRedesignHeader(
                            onOpenProfile: widget.onOpenProfile,
                            onOpenTheme: widget.onOpenTheme,
                          ),
                          const SizedBox(height: 6),
                          CopilotCalendar(
                            selectedDate: widget.selectedDate,
                            visibleWindowDays: 7,
                            onDateSelected: widget.onDateSelected,
                            onChooseDate: widget.onChooseDate,
                          ),
                          _SnapshotFreshnessLine(
                            metadata: widget.snapshotMetadata,
                            selectedDate: widget.selectedDate,
                          ),
                          const SizedBox(height: 6),
                          _ScoresModeControl(
                            selected: widget.mode,
                            onChanged: widget.onModeChanged,
                          ),
                          const SizedBox(height: 14),
                          if (showsGenerator)
                            SizedBox(
                              height: _generatorViewportHeight(context),
                              child: widget.generator,
                            )
                          else ...[
                            if (showsStories) ...[
                              _ForMeReadingFilterBar(
                                filters: readingFilters,
                                selectedReadingId: activeReadingId,
                                totalMatchCount: _uniqueMatchCount(
                                  allStoryMatches,
                                ),
                                onSelected: (readingId) {
                                  setState(() {
                                    _selectedForMeReadingId = readingId;
                                    _areAllStoriesVisible = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 18),
                              _TodayStoriesSection(
                                matches: storyMatches,
                                totalMatchCount: filteredStoryMatches.length,
                                selectedReadingId: activeReadingId,
                                onOpenMatch: _openStoryMatch,
                                onSeeAll: hasMoreStories
                                    ? _toggleStoryMatchesVisibility
                                    : null,
                                seeAllLabel: _areAllStoriesVisible
                                    ? 'Réduire'
                                    : 'Voir tout (${filteredStoryMatches.length})',
                              ),
                            ] else
                              _AllMatchesDenseSection(
                                title: listTitle,
                                emptySubtitle: listSubtitle,
                                initiallyExpanded: false,
                                groups: competitionGroups,
                                onOpenMatch: widget.onOpenMatch,
                              ),
                          ],
                          const SizedBox(height: 96),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
          child: LectorDeck(
            maxWidth: MediaQuery.sizeOf(context).width - 28,
            deckContext: LectorDeckContext(
              scope: _deckScopeForMode(widget.mode),
              selectedDate: widget.selectedDate,
              hasGeneratorResults: widget.hasGeneratorResults,
              hasSavedTickets: widget.hasSavedTickets,
              hasActiveStrategies: widget.hasActiveStrategies,
            ),
            capabilities: LectorDeckCapabilities(
              onOpenForMe: widget.mode == _ScoresRedesignMode.forMe
                  ? null
                  : () => widget.onModeChanged(_ScoresRedesignMode.forMe),
              onOpenAll: widget.mode == _ScoresRedesignMode.all
                  ? null
                  : () => widget.onModeChanged(_ScoresRedesignMode.all),
              onOpenGenerator: widget.mode == _ScoresRedesignMode.generator
                  ? null
                  : () => widget.onModeChanged(_ScoresRedesignMode.generator),
              onGoToday: () => widget.onDateSelected(_todayDate()),
              onOpenTicketHistory: widget.onOpenTicketHistory,
              onRecalculate: widget.onRecalculateTickets,
              onOpenStrategies: widget.onOpenStrategies,
            ),
          ),
        ),
        if (RuntimePersonalizationDiagnostic.instance.isEnabled)
          Positioned(
            right: 14,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: _RuntimePersonalizationDiagnosticButton(),
          ),
      ],
    );
  }

  void _toggleStoryMatchesVisibility() {
    setState(() {
      _areAllStoriesVisible = !_areAllStoriesVisible;
    });
  }

  void _openStoryMatch(MatchBoardItem match) {
    final opportunity = widget.opportunities
        .where((item) => item.matchId == match.id)
        .firstOrNull;
    if (opportunity != null) {
      widget.onOpenOpportunity(opportunity);
      return;
    }
    widget.onOpenMatch(match);
  }

  List<MatchBoardItem> _matchesForModeAndDate() {
    final dateMatches = _matchesForDate(widget.matches);
    final source = switch (widget.mode) {
      _ScoresRedesignMode.forMe => _matchesForDate(_forMeMatches()),
      _ScoresRedesignMode.all => dateMatches,
      _ScoresRedesignMode.generator => const <MatchBoardItem>[],
    };

    final uniqueByMatchId = <String, MatchBoardItem>{
      for (final match in source) match.id: match,
    };
    return uniqueByMatchId.values.toList(growable: false)
      ..sort(_ScoresRedesignHome._compareMatches);
  }

  double _generatorViewportHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return (height - safeBottom - 176).clamp(440.0, 760.0);
  }

  List<MatchBoardItem> _matchesForDate(List<MatchBoardItem> source) {
    return source.where((match) {
      final fixtureDay = lectorLocalCalendarDateForFixture(match.fixture);
      if (fixtureDay == null) {
        return _isSameCalendarDay(widget.selectedDate, _todayDate());
      }
      return _isSameCalendarDay(fixtureDay, widget.selectedDate);
    }).toList();
  }

  List<MatchBoardItem> _forMeMatches() {
    // The repository has already applied the profile to this list. Filtering
    // again here can hide valid readings when their ids evolve independently
    // from the presentation catalog.
    return widget.personalizedMatches;
  }

  int _uniqueMatchCount(Iterable<MatchBoardItem> matches) {
    return matches.map((match) => match.id).toSet().length;
  }

  bool _matchesSelectedCompetition(MatchBoardItem match) {
    final selectedIds = _selectedCompetitionIds;
    if (selectedIds.isEmpty) {
      return false;
    }

    final apiLeagueId = match.competition.apiFootballLeagueId?.toString();
    return selectedIds.contains(match.competition.id) ||
        (apiLeagueId != null && selectedIds.contains(apiLeagueId));
  }

  Set<String> get _selectedCompetitionIds {
    return {
      for (final id in widget.profile.optionIdsFor('competitions'))
        if (RuntimeCompetitionCatalog.resolveId(id) != null)
          RuntimeCompetitionCatalog.resolveId(id)!,
    };
  }

  Set<String> get _selectedReadingIds {
    return widget.profile.optionIdsFor('opportunity_profiles').toSet();
  }

  List<MatchBoardItem> _storyMatches(List<MatchBoardItem> source) {
    final candidates =
        source.where(_ScoresRedesignHome._hasReadableSignal).toList()
          ..sort((a, b) {
            final scoreComparison = _profileRelevanceCount(
              b,
            ).compareTo(_profileRelevanceCount(a));
            if (scoreComparison != 0) {
              return scoreComparison;
            }
            return _ScoresRedesignHome._compareMatches(a, b);
          });

    return candidates;
  }

  List<_ForMeReadingFilter> _readingFilters(List<MatchBoardItem> matches) {
    final filtersById = <String, _ForMeReadingFilterBuilder>{};
    for (final match in matches) {
      for (final reading in _profileReadings(match)) {
        filtersById
            .putIfAbsent(
              reading.id,
              () => _ForMeReadingFilterBuilder(
                id: reading.id,
                label: reading.label,
              ),
            )
            .matchIds
            .add(match.id);
      }
    }

    final filters = [for (final builder in filtersById.values) builder.build()]
      ..sort((a, b) {
        final countComparison = b.matchCount.compareTo(a.matchCount);
        return countComparison != 0
            ? countComparison
            : a.label.compareTo(b.label);
      });
    return filters;
  }

  List<_ForMeReading> _profileReadings(MatchBoardItem match) {
    final selectedProfileIds = _selectedReadingIds;
    final readingsById = <String, _ForMeReading>{};

    void add(String runtimeId) {
      final category = _ForMeReadingCategory.fromRuntimeId(
        runtimeId,
        selectedProfileIds: selectedProfileIds,
      );
      if (category == null || readingsById.containsKey(category.id)) {
        return;
      }
      readingsById[category.id] = _ForMeReading(
        id: category.id,
        label: category.label,
      );
    }

    final thesis = match.thesis;
    if (thesis != null) {
      add(thesis.id);
      for (final argument in thesis.arguments) {
        final readingId = FootballReadingCopyCatalog.readingIdFor(argument);
        add(readingId);
      }
    }
    for (final signal in match.signals) {
      add(signal.id);
    }

    return readingsById.values.toList(growable: false);
  }

  Set<String> _matchReadingIds(MatchBoardItem match) {
    return _profileReadings(match).map((reading) => reading.id).toSet();
  }

  int _profileRelevanceCount(MatchBoardItem match) {
    if (match.profileRelevance.isRelevant) {
      return match.profileRelevance.total;
    }

    final readingCount = _profileReadings(match).length;
    final opportunityBonus = match.thesis?.hasRecommendedMarket == true ? 1 : 0;
    return readingCount + opportunityBonus;
  }

  List<_ScoresCompetitionGroup> _competitionGroups(
    List<MatchBoardItem> source,
  ) {
    final byCompetition = <String, _ScoresCompetitionGroupBuilder>{};
    for (final match in source) {
      final id = match.competition.id;
      byCompetition.putIfAbsent(
        id,
        () => _ScoresCompetitionGroupBuilder(match.competition),
      );
      byCompetition[id]!.matches.add(match);
    }

    final groups = [for (final builder in byCompetition.values) builder.build()]
      ..sort((a, b) {
        final aSelected = _matchesSelectedCompetition(a.matches.first);
        final bSelected = _matchesSelectedCompetition(b.matches.first);
        if (aSelected != bSelected) {
          return aSelected ? -1 : 1;
        }
        return a.competition.name.compareTo(b.competition.name);
      });

    return groups;
  }
}

class _RuntimePersonalizationDiagnosticButton extends StatelessWidget {
  const _RuntimePersonalizationDiagnosticButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: IconButton.filledTonal(
        key: const ValueKey('runtime-personalization-diagnostic'),
        tooltip: 'Diagnostic Pour moi (dev)',
        icon: const Icon(Icons.bug_report_outlined),
        onPressed: () => _showDiagnostic(context),
      ),
    );
  }

  Future<void> _showDiagnostic(BuildContext context) async {
    final report = RuntimePersonalizationDiagnostic.instance.report();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Diagnostic runtime — Pour moi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: report));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Diagnostic copié.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copier diagnostic'),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.surfaces.shadow.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        report,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
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

class _ForMeReading {
  const _ForMeReading({required this.id, required this.label});

  final String id;
  final String label;
}

class _ForMeReadingFilter {
  const _ForMeReadingFilter({
    required this.id,
    required this.label,
    required this.matchCount,
  });

  final String id;
  final String label;
  final int matchCount;
}

class _ForMeReadingFilterBuilder {
  _ForMeReadingFilterBuilder({required this.id, required this.label});

  final String id;
  final String label;
  final Set<String> matchIds = <String>{};

  _ForMeReadingFilter build() {
    return _ForMeReadingFilter(
      id: id,
      label: label,
      matchCount: matchIds.length,
    );
  }
}

/// Presentation categories stay aligned with saved preference ids. Runtime
/// readings carry a subject team in their copy, so they must never be used as
/// a filter identity or a filter label.
class _ForMeReadingCategory {
  const _ForMeReadingCategory({required this.id, required this.label});

  final String id;
  final String label;

  static _ForMeReadingCategory? fromRuntimeId(
    String runtimeId, {
    required Set<String> selectedProfileIds,
  }) {
    final candidates = <String>{
      ...?_preferredProfileIds[runtimeId],
      ...OpportunityProfileCatalog.profileIdsForReading(runtimeId),
      ...OpportunityProfileCatalog.profileIdsForThesis(runtimeId),
    };
    if (candidates.isEmpty) {
      return null;
    }

    final selected = selectedProfileIds.isEmpty
        ? candidates
        : candidates.where(selectedProfileIds.contains).toSet();
    if (selected.isEmpty) {
      return null;
    }

    final id = _orderedProfileIds
        .where(selected.contains)
        .cast<String?>()
        .firstOrNull;
    if (id == null) {
      return null;
    }
    return _categoriesByProfileId[id];
  }

  static const _orderedProfileIds = [
    'ranking_gap',
    'positive_series',
    'negative_series',
    'fragile_defense',
    'prolific_attack',
    'offensive_match',
    'defensive_match',
    'solid_favorite',
    'struggling_team',
    'credible_outsider',
  ];

  static const _categoriesByProfileId = {
    'ranking_gap': _ForMeReadingCategory(
      id: 'ranking_gap',
      label: 'Avantage classement',
    ),
    'positive_series': _ForMeReadingCategory(
      id: 'positive_series',
      label: 'Forme',
    ),
    'negative_series': _ForMeReadingCategory(
      id: 'negative_series',
      label: 'Dynamique négative',
    ),
    'fragile_defense': _ForMeReadingCategory(
      id: 'fragile_defense',
      label: 'Défense fragile',
    ),
    'prolific_attack': _ForMeReadingCategory(
      id: 'prolific_attack',
      label: 'Attaque efficace',
    ),
    'offensive_match': _ForMeReadingCategory(
      id: 'offensive_match',
      label: 'Match ouvert',
    ),
    'defensive_match': _ForMeReadingCategory(
      id: 'defensive_match',
      label: 'Match fermé',
    ),
    'solid_favorite': _ForMeReadingCategory(
      id: 'solid_favorite',
      label: 'Domination attendue',
    ),
    'struggling_team': _ForMeReadingCategory(
      id: 'struggling_team',
      label: 'Équipe en difficulté',
    ),
    'credible_outsider': _ForMeReadingCategory(
      id: 'credible_outsider',
      label: 'Outsider crédible',
    ),
  };

  static const _preferredProfileIds = <String, List<String>>{
    'structural_level_gap': ['ranking_gap'],
    'positive_streak': ['positive_series'],
    'improving_form': ['positive_series'],
    'negative_streak': ['negative_series'],
    'declining_form': ['negative_series'],
    'fragile_defense': ['fragile_defense'],
    'high_xg_conceded': ['fragile_defense'],
    'defensive_underperformance': ['fragile_defense'],
    'prolific_attack': ['prolific_attack'],
    'high_xg_creation': ['prolific_attack'],
    'attack_in_form': ['prolific_attack'],
    'open_match_profile': ['offensive_match'],
    'frequent_over_25': ['offensive_match'],
    'frequent_btts': ['offensive_match'],
    'closed_match_profile': ['defensive_match'],
    'frequent_under_25': ['defensive_match'],
    'expected_domination': ['solid_favorite'],
    'solid_favorite': ['solid_favorite'],
    'controlled_favorite': ['solid_favorite'],
    'team_in_serious_difficulty': ['struggling_team'],
    'credible_outsider': ['credible_outsider'],
  };
}

String _readingLabelForId(String id, {required String fallback}) {
  return switch (id) {
    'ranking_gap' || 'structural_level_gap' => 'Avantage classement',
    'ranking_superiority' => 'Écart au classement',
    'balanced_hierarchy' => 'Hiérarchie équilibrée',
    'positive_streak' || 'improving_form' || 'form_advantage' => 'Forme',
    'negative_streak' || 'declining_form' => 'Dynamique négative',
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

class _ScoresRedesignHeader extends StatelessWidget {
  const _ScoresRedesignHeader({
    required this.onOpenProfile,
    required this.onOpenTheme,
  });

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenTheme;

  @override
  Widget build(BuildContext context) {
    final controller = getIt.isRegistered<SupabaseAuthController>()
        ? getIt<SupabaseAuthController>()
        : null;

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const LectorBrandMark(size: 34),
            const Spacer(),
            const _HeaderThemeToggleButton(),
            const SizedBox(width: AppSpacing.xs),
            controller == null
                ? _HeaderIdentityButton(
                    icon: Icons.person_outline_rounded,
                    tooltip: 'Connexion',
                    onPressed: onOpenProfile,
                  )
                : ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      return _HeaderIdentityButton(
                        label: controller.isSignedIn
                            ? _initialsForUser(controller.user)
                            : null,
                        icon: controller.isSignedIn
                            ? null
                            : Icons.person_outline_rounded,
                        tooltip: controller.isSignedIn ? 'Compte' : 'Connexion',
                        onPressed: onOpenProfile,
                      );
                    },
                  ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              tooltip: 'Paramètres',
              onPressed: onOpenTheme,
              icon: const Icon(Icons.settings_outlined, size: 25),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderThemeToggleButton extends StatelessWidget {
  const _HeaderThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeVariant>(
      valueListenable: appThemeController,
      builder: (context, variant, _) {
        final isLight = variant == AppThemeVariant.vectorLight;
        return IconButton(
          tooltip: isLight ? 'Passer en thème sombre' : 'Passer en thème clair',
          onPressed: appThemeController.toggleBrightness,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Icon(
              isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              key: ValueKey(isLight),
              size: 24,
            ),
          ),
        );
      },
    );
  }
}

class _HeaderIdentityButton extends StatelessWidget {
  const _HeaderIdentityButton({
    this.label,
    this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.surfaces.backgroundSecondary.withValues(alpha: 0.64),
            border: Border.all(
              color: context.brand.accent.withValues(alpha: 0.72),
            ),
          ),
          child: label == null
              ? Icon(
                  icon ?? Icons.person_outline_rounded,
                  color: context.brand.accent,
                  size: 22,
                )
              : Text(
                  label!,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}

class _HeaderAccountSheet extends StatelessWidget {
  const _HeaderAccountSheet({
    required this.controller,
    required this.identityController,
  });

  final SupabaseAuthController? controller;
  final IdentityController? identityController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller ?? Listenable.merge([]),
      builder: (context, _) {
        if (controller?.isSignedIn ?? false) {
          return _ConnectedAccountSheet(
            controller: controller!,
            identityController: identityController,
          );
        }
        return _DisconnectedAuthSheet(
          controller: controller,
          identityController: identityController,
        );
      },
    );
  }
}

class _DisconnectedAuthSheet extends StatefulWidget {
  const _DisconnectedAuthSheet({
    required this.controller,
    required this.identityController,
  });

  final SupabaseAuthController? controller;
  final IdentityController? identityController;

  @override
  State<_DisconnectedAuthSheet> createState() => _DisconnectedAuthSheetState();
}

class _DisconnectedAuthSheetState extends State<_DisconnectedAuthSheet> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isCreatingAccount = false;
  String? _errorMessage;

  bool get _isConfigured => widget.controller?.isConfigured ?? false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleCredentialInputChanged);
    _passwordController.addListener(_handleCredentialInputChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleCredentialInputChanged);
    _passwordController.removeListener(_handleCredentialInputChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleCredentialInputChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetTopBar(onClose: () => Navigator.of(context).pop()),
            const SizedBox(height: AppSpacing.xs),
            const _LoginVisualIdentity(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _isCreatingAccount ? 'Créer un compte' : 'Se connecter',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Accédez à votre compte Lector\net synchronisez vos données.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AuthTextField(
              controller: _emailController,
              icon: Icons.mail_outline_rounded,
              hintText: 'Adresse e-mail',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              enabled: !_isLoading,
              onChanged: (_) => _clearError(),
            ),
            const SizedBox(height: AppSpacing.sm),
            _AuthTextField(
              controller: _passwordController,
              icon: Icons.lock_outline_rounded,
              hintText: 'Mot de passe',
              obscureText: !_isPasswordVisible,
              autofillHints: const [AutofillHints.password],
              enabled: !_isLoading,
              onChanged: (_) => _clearError(),
              suffix: IconButton(
                tooltip: _isPasswordVisible
                    ? 'Masquer le mot de passe'
                    : 'Afficher le mot de passe',
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      }),
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _AuthInlineMessage(message: _errorMessage!),
            ],
            if (!_isCreatingAccount) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),
            ] else
              const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _canSubmit ? _submitPasswordAuth : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              child: _isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isCreatingAccount ? 'Créer le compte' : 'Se connecter',
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _AuthDivider(),
            const SizedBox(height: AppSpacing.md),
            _GoogleAuthButton(
              enabled: _isConfigured && !_isLoading,
              onPressed: _signInWithGoogle,
            ),
            const SizedBox(height: AppSpacing.md),
            _AuthModeSwitch(
              isCreatingAccount: _isCreatingAccount,
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                      _isCreatingAccount = !_isCreatingAccount;
                      _errorMessage = null;
                    }),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit {
    return _isConfigured &&
        !_isLoading &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _submitPasswordAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final validationError = _validateCredentials(email, password);
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    await _runAuthAction(
      () {
        final controller = widget.controller!;
        if (_isCreatingAccount) {
          return widget.identityController?.signUpWithPassword(
                email: email,
                password: password,
              ) ??
              controller.signUpWithPassword(email: email, password: password);
        }
        return widget.identityController?.signInWithPassword(
              email: email,
              password: password,
            ) ??
            controller.signInWithPassword(email: email, password: password);
      },
      successMessageWhenStillSignedOut: _isCreatingAccount
          ? 'Compte créé. Vérifiez votre e-mail si une confirmation est demandée.'
          : null,
    );
  }

  Future<void> _signInWithGoogle() async {
    await _runAuthAction(
      () =>
          widget.identityController?.signInWithGoogle() ??
          widget.controller!.signInWithGoogle(),
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!_isConfigured) {
      setState(() {
        _errorMessage =
            'Connexion indisponible dans cet environnement. Réessayez plus tard.';
      });
      return;
    }
    if (!_looksLikeEmail(email)) {
      setState(() {
        _errorMessage =
            'Saisissez une adresse e-mail valide pour réinitialiser le mot de passe.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.controller!.resetPasswordForEmail(email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si ce compte existe, un e-mail de réinitialisation a été envoyé.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runAuthAction(
    Future<void> Function() action, {
    String? successMessageWhenStillSignedOut,
  }) async {
    if (!_isConfigured || _isLoading) {
      setState(() {
        _errorMessage =
            'Connexion indisponible dans cet environnement. Réessayez plus tard.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action();
      if (mounted) {
        if (successMessageWhenStillSignedOut != null &&
            !(widget.controller?.isSignedIn ?? false)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMessageWhenStillSignedOut)),
          );
          return;
        }
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _ConnectedAccountSheet extends StatelessWidget {
  const _ConnectedAccountSheet({
    required this.controller,
    required this.identityController,
  });

  final SupabaseAuthController controller;
  final IdentityController? identityController;

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    final name = _displayNameForUser(user);
    final email = user?.email;
    final identityLabel = name ?? email ?? 'Compte Lector';
    final isGoogleAccount = _hasGoogleIdentity(user);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetTopBar(onClose: () => Navigator.of(context).pop()),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: _HeaderIdentityButton(
                label: _initialsForName(identityLabel),
                tooltip: 'Compte',
                onPressed: () {},
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              name ?? 'Compte Lector',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (email != null) ...[
              const SizedBox(height: 2),
              Text(
                email,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textColors.secondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.surfaces.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: context.surfaces.border),
              ),
              child: Column(
                children: [
                  _HeaderAccountRow(
                    icon: Icons.person_outline_rounded,
                    title: 'Mon profil',
                    subtitle: 'Voir et modifier mes informations',
                    onTap: () => _showUnavailable(
                      context,
                      'Aucun écran de profil détaillé n’est encore relié.',
                    ),
                  ),
                  Divider(height: 1, color: context.surfaces.border),
                  _HeaderAccountRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Sécurité',
                    subtitle: 'Mot de passe et connexions',
                    onTap: () => _showUnavailable(
                      context,
                      'Aucun écran de sécurité n’est encore relié.',
                    ),
                  ),
                  Divider(height: 1, color: context.surfaces.border),
                  _HeaderAccountRow(
                    icon: Icons.devices_outlined,
                    title: 'Appareils connectés',
                    subtitle: 'Gérer vos sessions actives',
                    onTap: () => _showUnavailable(
                      context,
                      'Aucun écran de sessions actives n’est encore relié.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isGoogleAccount) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  await (identityController?.signOut() ??
                      controller.signOutFromGoogle());
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: context.textColors.primary,
                  side: BorderSide(color: context.surfaces.border),
                ),
                icon: const GoogleBrandIcon(size: 19),
                label: const Text('Se déconnecter de Google'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton.icon(
              onPressed: () async {
                await (identityController?.signOut() ?? controller.signOut());
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: context.semantic.error,
                side: BorderSide(color: context.semantic.error),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Se déconnecter de Lector'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Vos préférences et informations seront conservées sur cet appareil.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SheetTopBar extends StatelessWidget {
  const _SheetTopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.textColors.secondary.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: const SizedBox(width: 34, height: 4),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Fermer',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginVisualIdentity extends StatelessWidget {
  const _LoginVisualIdentity();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 122,
        height: 74,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 8,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.brand.accent.withValues(alpha: 0.10),
                  border: Border.all(
                    color: context.brand.accent.withValues(alpha: 0.62),
                  ),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: context.brand.accent,
                  size: 31,
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 8,
              child: Container(
                width: 58,
                height: 54,
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: context.surfaces.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.odds),
                  border: Border.all(color: context.surfaces.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LectorBrandMark(size: 18),
                    const SizedBox(height: 4),
                    _AuthVisualLine(width: 28),
                    const SizedBox(height: 3),
                    _AuthVisualLine(width: 20),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 8,
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.brand.accent,
                ),
                child: Icon(
                  Icons.sync_rounded,
                  color: context.brand.onAccent,
                  size: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthVisualLine extends StatelessWidget {
  const _AuthVisualLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.textColors.secondary.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: SizedBox(width: width, height: 3),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.icon,
    required this.hintText,
    required this.enabled,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onChanged,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final bool enabled;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      obscureText: obscureText,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}

class _AuthInlineMessage extends StatelessWidget {
  const _AuthInlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.semantic.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.odds),
        border: Border.all(
          color: context.semantic.error.withValues(alpha: 0.62),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: context.semantic.error,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.semantic.error,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: context.surfaces.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            'ou',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.surfaces.border)),
      ],
    );
  }
}

class _GoogleAuthButton extends StatelessWidget {
  const _GoogleAuthButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: context.textColors.primary,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GoogleBrandIcon(size: 19),
          SizedBox(width: AppSpacing.sm),
          Text('Continuer avec Google'),
        ],
      ),
    );
  }
}

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({
    required this.isCreatingAccount,
    required this.onPressed,
  });

  final bool isCreatingAccount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          isCreatingAccount ? 'Déjà un compte ? ' : 'Pas encore de compte ? ',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textColors.secondary),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(isCreatingAccount ? 'Se connecter' : 'Créer un compte'),
        ),
      ],
    );
  }
}

class _HeaderAccountRow extends StatelessWidget {
  const _HeaderAccountRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.odds),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.surfaces.backgroundSecondary,
                border: Border.all(color: context.surfaces.border),
              ),
              child: Icon(icon, color: context.textColors.primary, size: 19),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.textColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoresModeControl extends StatelessWidget {
  const _ScoresModeControl({required this.selected, required this.onChanged});

  final _ScoresRedesignMode selected;
  final ValueChanged<_ScoresRedesignMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: [
          _ScoresModeTab(
            icon: Icons.person_outline_rounded,
            label: 'Pour moi',
            isSelected: selected == _ScoresRedesignMode.forMe,
            onTap: () => onChanged(_ScoresRedesignMode.forMe),
          ),
          _ModeDivider(),
          _ScoresModeTab(
            icon: Icons.format_list_bulleted_rounded,
            label: 'Tous',
            isSelected: selected == _ScoresRedesignMode.all,
            onTap: () => onChanged(_ScoresRedesignMode.all),
          ),
          _ModeDivider(),
          _ScoresModeTab(
            icon: Icons.auto_awesome_rounded,
            label: 'Générateur',
            isSelected: selected == _ScoresRedesignMode.generator,
            onTap: () => onChanged(_ScoresRedesignMode.generator),
          ),
        ],
      ),
    );
  }
}

class _ModeDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: VerticalDivider(color: context.surfaces.border),
    );
  }
}

class _ScoresModeTab extends StatelessWidget {
  const _ScoresModeTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? context.brand.accent
        : context.textColors.secondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SizedBox(
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.brand.accent,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: const SizedBox(height: 3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForMeReadingFilterBar extends StatelessWidget {
  const _ForMeReadingFilterBar({
    required this.filters,
    required this.selectedReadingId,
    required this.totalMatchCount,
    required this.onSelected,
  });

  final List<_ForMeReadingFilter> filters;
  final String? selectedReadingId;
  final int totalMatchCount;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _ForMeReadingFilterTile(
            label: 'Tout',
            count: totalMatchCount,
            icon: Icons.grid_view_rounded,
            isSelected: selectedReadingId == null,
            onTap: () => onSelected(null),
          ),
          for (final filter in filters) ...[
            const SizedBox(width: AppSpacing.xs),
            _ForMeReadingFilterTile(
              label: filter.label,
              count: filter.matchCount,
              icon: context.opportunities.readingIdentityForId(filter.id).icon,
              readingId: filter.id,
              isSelected: filter.id == selectedReadingId,
              onTap: () => onSelected(filter.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ForMeReadingFilterTile extends StatelessWidget {
  const _ForMeReadingFilterTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.readingId,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String? readingId;

  @override
  Widget build(BuildContext context) {
    final readingId = this.readingId;
    final badge = readingId == null
        ? null
        : context.opportunities.badgeFor(
            readingId,
            variant: AppReadingBadgeVariant.soft,
          );
    final accent = isSelected
        ? context.brand.accent
        : (badge?.foreground ?? context.textColors.secondary);
    final background = isSelected
        ? context.brand.accent.withValues(alpha: 0.12)
        : context.surfaces.surface.withValues(alpha: 0.64);

    return SizedBox(
      key: readingId == null
          ? const ValueKey('for-me-filter-all')
          : ValueKey('for-me-filter-$readingId'),
      width: 94,
      child: Material(
        color: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isSelected ? context.brand.accent : context.surfaces.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: accent, size: 20),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '($count)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.textColors.secondary,
                      fontWeight: FontWeight.w700,
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
}

class _TodayStoriesSection extends StatelessWidget {
  const _TodayStoriesSection({
    required this.matches,
    required this.totalMatchCount,
    required this.selectedReadingId,
    required this.onOpenMatch,
    required this.onSeeAll,
    required this.seeAllLabel,
  });

  final List<MatchBoardItem> matches;
  final int totalMatchCount;
  final String? selectedReadingId;
  final ValueChanged<MatchBoardItem> onOpenMatch;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showsSeeAll = onSeeAll != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.my_location_rounded,
              color: context.brand.accent,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'À suivre aujourd’hui',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    matches.isEmpty
                        ? 'Aucune rencontre ne correspond à cette lecture'
                        : totalMatchCount > matches.length
                        ? 'Les rencontres les plus pertinentes pour votre profil'
                        : 'Rencontres correspondant à vos lectures',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.textColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (showsSeeAll)
              TextButton(onPressed: onSeeAll, child: Text(seeAllLabel)),
          ],
        ),
        const SizedBox(height: 10),
        if (matches.isEmpty)
          _ScoresEmptyPanel(
            title: 'Rien de vraiment lisible',
            subtitle:
                'Lector ne force pas une lecture quand les signaux sont faibles.',
          )
        else
          for (var index = 0; index < matches.length; index++) ...[
            _TodayStoryCard(
              rank: index + 1,
              match: matches[index],
              onTap: () => onOpenMatch(matches[index]),
            ),
            if (index != matches.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _TodayStoryCard extends StatelessWidget {
  const _TodayStoryCard({
    required this.rank,
    required this.match,
    required this.onTap,
  });

  final int rank;
  final MatchBoardItem match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thesisId = match.thesis?.id ?? match.signals.firstOrNull?.id ?? '';
    final hasOpportunity = match.thesis?.hasRecommendedMarket == true;
    final readingCount = _convergentReadingCount(match);
    final tags = _representativeReadingTags(match);

    return Material(
      color: context.surfaces.surface.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: context.surfaces.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 11, 8, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StoryRankMeta(rank: rank, match: match),
              const SizedBox(width: 10),
              SizedBox(width: 112, child: _StoryTeams(match: match)),
              Container(
                width: 1,
                height: 76,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: context.surfaces.border,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StoryRelevanceLabel(
                      readingCount: readingCount,
                      hasOpportunity: hasOpportunity,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _StoryReadingTags(tags: tags),
                    if (_storySummary(match).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _storySummary(match),
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
                ),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                onPressed: onTap,
                tooltip: 'Voir l’analyse',
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: thesisId.isEmpty
                      ? context.textColors.secondary
                      : context.opportunities
                            .badgeFor(
                              thesisId,
                              variant: AppReadingBadgeVariant.soft,
                            )
                            .foreground,
                ),
                style: IconButton.styleFrom(
                  side: BorderSide(color: context.surfaces.border),
                  backgroundColor: context.surfaces.surfaceHover.withValues(
                    alpha: 0.4,
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

class _StoryRelevanceLabel extends StatelessWidget {
  const _StoryRelevanceLabel({
    required this.readingCount,
    required this.hasOpportunity,
  });

  final int readingCount;
  final bool hasOpportunity;

  @override
  Widget build(BuildContext context) {
    final countLabel = readingCount == 1
        ? '1 lecture'
        : '$readingCount lectures';
    final label = hasOpportunity ? '$countLabel · opportunité' : countLabel;
    final color = hasOpportunity
        ? context.opportunities.levelGap
        : context.brand.accent;

    return Row(
      children: [
        Icon(
          hasOpportunity ? Icons.auto_awesome_rounded : Icons.bar_chart_rounded,
          color: color,
          size: 17,
        ),
        const SizedBox(width: 5),
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
      ],
    );
  }
}

class _StoryReadingTags extends StatelessWidget {
  const _StoryReadingTags({required this.tags});

  final List<_ForMeReading> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: [
        for (final tag in tags.take(3))
          _StoryScenarioPill(
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

List<_ForMeReading> _representativeReadingTags(MatchBoardItem match) {
  final readingsById = <String, _ForMeReading>{};
  void add(String id, String label) {
    if (id.isNotEmpty && !readingsById.containsKey(id)) {
      readingsById[id] = _ForMeReading(id: id, label: label);
    }
  }

  final thesis = match.thesis;
  if (thesis != null) {
    for (final argument in thesis.arguments) {
      final id = FootballReadingCopyCatalog.readingIdFor(argument);
      add(id, FootballReadingCopyCatalog.titleFor(argument));
    }
    add(thesis.id, _readingLabelForId(thesis.id, fallback: thesis.title));
  }
  for (final signal in match.signals) {
    add(signal.id, _readingLabelForId(signal.id, fallback: signal.title));
  }
  return readingsById.values.toList(growable: false);
}

String _storySummary(MatchBoardItem match) {
  final thesisSummary = match.thesis?.summary.trim();
  if (thesisSummary != null && thesisSummary.isNotEmpty) {
    return thesisSummary;
  }
  for (final signal in match.signals) {
    final summary = signal.summary.trim();
    if (summary.isNotEmpty) {
      return summary;
    }
  }
  return '';
}

class _StoryRankMeta extends StatelessWidget {
  const _StoryRankMeta({required this.rank, required this.match});

  final int rank;
  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.surfaces.backgroundSecondary,
            shape: BoxShape.circle,
            border: Border.all(color: context.surfaces.border),
          ),
          child: SizedBox.square(
            dimension: 26,
            child: Center(
              child: Text(
                '$rank',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _competitionShortLabel(match.competition.name),
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _fixtureTime(match.fixture),
          style: theme.textTheme.labelMedium?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StoryTeams extends StatelessWidget {
  const _StoryTeams({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StoryTeamLine(team: match.homeTeam),
        const SizedBox(height: 6),
        _StoryTeamLine(team: match.awayTeam),
      ],
    );
  }
}

class _StoryTeamLine extends StatelessWidget {
  const _StoryTeamLine({required this.team});

  final TeamInfo team;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SportsAssetBadge(
          size: 21,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          borderRadius: AppRadius.chip,
          padding: 1,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _StoryScenarioPill extends StatelessWidget {
  const _StoryScenarioPill({
    required this.label,
    required this.style,
    required this.icon,
  });

  final String label;
  final AppReadingBadgeStyle style;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: style.iconColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: style.foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllMatchesDenseSection extends StatelessWidget {
  const _AllMatchesDenseSection({
    required this.title,
    required this.emptySubtitle,
    required this.initiallyExpanded,
    required this.groups,
    required this.onOpenMatch,
  });

  final String title;
  final String emptySubtitle;
  final bool initiallyExpanded;
  final List<_ScoresCompetitionGroup> groups;
  final ValueChanged<MatchBoardItem> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.format_list_bulleted_rounded,
              color: context.brand.accent,
              size: 21,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Filtres'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          _ScoresEmptyPanel(title: 'Aucune rencontre', subtitle: emptySubtitle)
        else
          for (final group in groups) ...[
            _DenseCompetitionSection(
              group: group,
              initiallyExpanded: initiallyExpanded,
              onOpenMatch: onOpenMatch,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _DenseCompetitionSection extends StatefulWidget {
  const _DenseCompetitionSection({
    required this.group,
    required this.initiallyExpanded,
    required this.onOpenMatch,
  });

  final _ScoresCompetitionGroup group;
  final bool initiallyExpanded;
  final ValueChanged<MatchBoardItem> onOpenMatch;

  @override
  State<_DenseCompetitionSection> createState() =>
      _DenseCompetitionSectionState();
}

class _DenseCompetitionSectionState extends State<_DenseCompetitionSection> {
  late bool _isExpanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant _DenseCompetitionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.competition.id != widget.group.competition.id ||
        oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _isExpanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        children: [
          Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 10, 8),
                child: Row(
                  children: [
                    SportsAssetBadge(
                      size: 24,
                      imageUrl: widget.group.competition.logoUrl,
                      fallbackLabel: widget.group.competition.name,
                      backgroundColor: AppColors.transparent,
                      icon: Icons.emoji_events_rounded,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.group.competition.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${widget.group.matches.length} match${widget.group.matches.length > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                for (
                  var index = 0;
                  index < widget.group.matches.length;
                  index++
                ) ...[
                  Divider(height: 1, color: context.surfaces.border),
                  _DenseMatchRow(
                    match: widget.group.matches[index],
                    onTap: () =>
                        widget.onOpenMatch(widget.group.matches[index]),
                  ),
                ],
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _DenseMatchRow extends StatelessWidget {
  const _DenseMatchRow({required this.match, required this.onTap});

  final MatchBoardItem match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = _compactReadingLabel(match);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fixtureTime(match.fixture),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: context.brand.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _statusLabel(match.fixture.status),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: context.surfaces.border),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    _DenseTeamLine(team: match.homeTeam),
                    const SizedBox(height: AppSpacing.xs),
                    _DenseTeamLine(team: match.awayTeam),
                  ],
                ),
              ),
              if (reading != null) ...[
                const SizedBox(width: 6),
                _CompactReadingBadge(label: reading),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: context.textColors.secondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DenseTeamLine extends StatelessWidget {
  const _DenseTeamLine({required this.team});

  final TeamInfo team;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SportsAssetBadge(
          size: 20,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          borderRadius: AppRadius.chip,
          padding: 1,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _CompactReadingBadge extends StatelessWidget {
  const _CompactReadingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.brand.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: context.brand.accent.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar_rounded, size: 13, color: context.brand.accent),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 66),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.brand.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoresEmptyPanel extends StatelessWidget {
  const _ScoresEmptyPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: context.textColors.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textColors.secondary,
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

class _ScoresCompetitionGroupBuilder {
  _ScoresCompetitionGroupBuilder(this.competition);

  final CompetitionInfo competition;
  final List<MatchBoardItem> matches = [];

  _ScoresCompetitionGroup build() {
    return _ScoresCompetitionGroup(
      competition: competition,
      matches: [...matches]..sort(_ScoresRedesignHome._compareMatches),
    );
  }
}

class _ScoresCompetitionGroup {
  const _ScoresCompetitionGroup({
    required this.competition,
    required this.matches,
  });

  final CompetitionInfo competition;
  final List<MatchBoardItem> matches;
}

String _readingTitle(MatchBoardItem match) {
  final title = match.thesis?.title.trim();
  if (title != null && title.isNotEmpty) {
    return _freeReadingCopy(title);
  }
  final signal = match.signals.isEmpty ? null : match.signals.first.title;
  if (signal != null && signal.trim().isNotEmpty) {
    return _freeReadingCopy(signal);
  }
  return 'Match à suivre';
}

String? _compactReadingLabel(MatchBoardItem match) {
  if (match.thesis == null && match.signals.isEmpty) {
    return null;
  }
  final title = _readingTitle(match).toLowerCase();
  if (title.contains('ouvert')) {
    return 'Ouvert';
  }
  if (title.contains('domination') || title.contains('favori')) {
    return 'Domination';
  }
  if (title.contains('contrôle') || title.contains('controle')) {
    return 'Contrôle';
  }
  if (title.contains('fermé') || title.contains('ferme')) {
    return 'Fermé';
  }
  return 'Lecture';
}

int _convergentReadingCount(MatchBoardItem match) {
  final thesis = match.thesis;
  if (thesis != null) {
    final supportingArguments = thesis.arguments.where((argument) {
      return argument.family != CopilotArgumentFamily.market &&
          argument.family != CopilotArgumentFamily.contradiction;
    }).length;
    if (supportingArguments > 0) {
      return supportingArguments;
    }
    if (thesis.supportingEvidence.isNotEmpty) {
      return thesis.supportingEvidence.length;
    }
  }
  return match.signals.length;
}

String _freeReadingCopy(String value) {
  return value
      .replaceAll('Marché recommandé', 'Lecture recommandée')
      .replaceAll('marché recommandé', 'lecture recommandée')
      .replaceAll('Cote', 'Signal')
      .replaceAll('cote', 'signal');
}

String _competitionShortLabel(String competitionName) {
  final lower = competitionName.toLowerCase();
  if (lower.contains('premier')) {
    return 'PL';
  }
  if (lower.contains('liga')) {
    return 'LALIGA';
  }
  if (lower.contains('champions')) {
    return 'UCL';
  }
  if (lower.contains('bundes')) {
    return 'BUNDES';
  }
  if (lower.contains('ligue 1')) {
    return 'L1';
  }
  return competitionName.length <= 6
      ? competitionName.toUpperCase()
      : competitionName.substring(0, 3).toUpperCase();
}

String _fixtureTime(NormalizedFixture fixture) {
  final kickoff = fixture.kickoff?.toLocal();
  if (kickoff != null) {
    return '${kickoff.hour.toString().padLeft(2, '0')}:${kickoff.minute.toString().padLeft(2, '0')}';
  }
  return fixture.kickoffLabel;
}

String _statusLabel(FixtureStatus status) {
  return switch (status) {
    FixtureStatus.scheduled => 'À venir',
    FixtureStatus.live => 'En cours',
    FixtureStatus.finished => 'Terminé',
    FixtureStatus.postponed => 'Reporté',
    FixtureStatus.cancelled => 'Annulé',
  };
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
    required this.identityScope,
    required this.ticketDraft,
    required this.onToggleTicket,
    required this.onOpenMatch,
  });

  final List<MatchBoardItem> matches;
  final MatchFeedSnapshotMetadata? snapshotMetadata;
  final CompiledDecisionProfile compiledProfile;
  final IdentityScope identityScope;
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
  void didUpdateWidget(covariant _ChampionshipsByCountryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identityScope != widget.identityScope) {
      _favoriteIds.clear();
      _loadFavorites();
    }
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
    final scope = widget.identityScope;
    final saved = await _favoriteStore.load(scope: scope);
    if (!mounted) {
      return;
    }
    if (widget.identityScope != scope) {
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
    _favoriteStore.save(scope: widget.identityScope, favoriteIds: _favoriteIds);
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
                title: 'Informations Lector',
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
                    label: 'Avec lecture Lector',
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
  readingStrength('Lecture Lector'),
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
                  'Configurez vos préférences pour permettre à Lector de rechercher les situations qui vous intéressent.',
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
                'Lecture Lector',
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
