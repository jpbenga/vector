// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/deck/lector_deck.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/lector_brand_mark.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';
import '../../opportunities/domain/opportunity.dart';
import '../../tickets/domain/ticket_draft.dart';
import '../../tickets/domain/saved_ticket.dart';
import '../../tickets/domain/ticket_strategy.dart';
import '../../tickets/presentation/ticket_builder_panel.dart';
import '../domain/football_reading.dart';
import '../domain/football_scenario.dart';
import '../domain/market_assessment.dart';
import '../domain/match_board_item.dart';
import '../domain/match_context_key_models.dart';
import '../domain/structural_tiers/tier_models.dart';
import '../data/match_reading_bilan_repository.dart';
import 'opportunity_decision_presenter.dart';
import 'reading_bilan_section.dart';
import 'widgets/sports_asset_badge.dart';

const _matchCardStadiumBackgroundAsset =
    'assets/backgrounds/match-card-stadium-premium.png';

class MatchDetailPage extends StatefulWidget {
  const MatchDetailPage({
    required this.match,
    this.opportunity,
    this.ticketDraftListenable,
    this.ticketStrategies = const [],
    this.onToggleTicket,
    this.onRemoveTicketSelection,
    this.onTicketSaved,
    this.onViewSavedTickets,
    this.onOpenTicketSelection,
    this.onOpenGenerator,
    this.selectedReadingIds = const [],
    this.selectedScenarioIds = const [],
    super.key,
  });

  final MatchBoardItem match;
  final Opportunity? opportunity;
  final ValueListenable<TicketDraft>? ticketDraftListenable;
  final List<TicketStrategy> ticketStrategies;
  final ValueChanged<TicketDraftSelection>? onToggleTicket;
  final ValueChanged<String>? onRemoveTicketSelection;
  final ValueChanged<SavedTicket>? onTicketSaved;
  final VoidCallback? onViewSavedTickets;
  final ValueChanged<TicketDraftSelection>? onOpenTicketSelection;
  final VoidCallback? onOpenGenerator;
  final List<String> selectedReadingIds;
  final List<String> selectedScenarioIds;

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  int _selectedFreeTab = 0;
  bool _isTicketPanelExpanded = false;
  late Future<List<MatchReadingBilanEntry>> _readingBilan;

  @override
  void initState() {
    super.initState();
    _readingBilan = _loadReadingBilan();
  }

  @override
  void didUpdateWidget(covariant MatchDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.fixture.apiFootballFixtureId !=
        widget.match.fixture.apiFootballFixtureId) {
      _readingBilan = _loadReadingBilan();
    }
  }

  Future<List<MatchReadingBilanEntry>> _loadReadingBilan() async {
    final fixtureId = widget.match.fixture.apiFootballFixtureId;
    if (fixtureId == null) return const [];
    try {
      return await SupabaseMatchReadingBilanRepository(
        Supabase.instance.client,
      ).loadForFixture(fixtureId);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaces.background,
      bottomNavigationBar: _buildTicketPanel(),
      body: Stack(
        children: [
          const _LectorMatchBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  sliver: SliverList.list(
                    children: [
                      _LectorMatchTopBar(
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 10),
                      _LectorMatchHero(match: widget.match),
                      FutureBuilder<List<MatchReadingBilanEntry>>(
                        future: _readingBilan,
                        builder: (context, snapshot) {
                          final entries =
                              snapshot.data ?? const <MatchReadingBilanEntry>[];
                          if (entries.isEmpty ||
                              !entries.any((entry) => entry.hasResult)) {
                            return const SizedBox.shrink();
                          }
                          final confirmed = entries
                              .where((entry) => entry.verdict == 'confirmed')
                              .length;
                          final contradicted = entries
                              .where((entry) => entry.verdict == 'contradicted')
                              .length;
                          final pertinentNuances = entries
                              .where(
                                (entry) => entry.verdict == 'caution_confirmed',
                              )
                              .length;
                          final result = entries.firstWhere(
                            (entry) => entry.hasResult,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              collapsedBackgroundColor:
                                  context.surfaces.backgroundSecondary,
                              backgroundColor:
                                  context.surfaces.backgroundSecondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              collapsedShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(
                                'Résultat ${result.homeGoals}–${result.awayGoals}',
                                style: TextStyle(
                                  color: context.textColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '$confirmed lectures confirmées · '
                                '$contradicted contredites · '
                                '$pertinentNuances nuances pertinentes · '
                                '${entries.length} annoncées',
                                style: TextStyle(
                                  color: context.textColors.secondary,
                                ),
                              ),
                              children: [
                                for (final entry in entries)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      0,
                                      10,
                                      8,
                                    ),
                                    child: ReadingVerdictCard(entry: entry),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _LectorSynthesisCard(
                        match: widget.match,
                        opportunity: widget.opportunity,
                      ),
                      const SizedBox(height: 12),
                      _LectorMatchTabBar(
                        selectedIndex: _selectedFreeTab,
                        onSelected: (index) {
                          setState(() => _selectedFreeTab = index);
                        },
                      ),
                      const SizedBox(height: 10),
                      _LectorFreeTabContent(
                        match: widget.match,
                        selectedIndex: _selectedFreeTab,
                        selectedReadingIds: widget.selectedReadingIds,
                        selectedScenarioIds: widget.selectedScenarioIds,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: _buildDeck(context),
          ),
        ],
      ),
    );
  }

  Widget? _buildTicketPanel() {
    final ticketDraftListenable = widget.ticketDraftListenable;
    if (ticketDraftListenable == null ||
        widget.onRemoveTicketSelection == null ||
        widget.onTicketSaved == null ||
        widget.onViewSavedTickets == null) {
      return null;
    }

    return ValueListenableBuilder<TicketDraft>(
      valueListenable: ticketDraftListenable,
      builder: (context, ticket, _) {
        if (ticket.isEmpty) {
          return const SizedBox.shrink();
        }

        return TicketBuilderPanel(
          ticket: ticket,
          strategies: widget.ticketStrategies,
          isExpanded: _isTicketPanelExpanded,
          onToggleExpanded: () {
            setState(() {
              _isTicketPanelExpanded = !_isTicketPanelExpanded;
            });
          },
          onRemoveSelection: (selectionId) {
            widget.onRemoveTicketSelection!(selectionId);
            if (ticket.selectionCount <= 1) {
              setState(() {
                _isTicketPanelExpanded = false;
              });
            }
          },
          onTicketSaved: widget.onTicketSaved!,
          onViewSavedTickets: widget.onViewSavedTickets!,
          onOpenSelection: widget.onOpenTicketSelection,
        );
      },
    );
  }

  Widget _buildDeck(BuildContext context) {
    final ticketDraftListenable = widget.ticketDraftListenable;
    if (ticketDraftListenable == null) {
      return _deckForTicket(TicketDraft.empty);
    }

    return ValueListenableBuilder<TicketDraft>(
      valueListenable: ticketDraftListenable,
      builder: (context, ticket, _) => _deckForTicket(ticket),
    );
  }

  Widget _deckForTicket(TicketDraft ticket) {
    final ticketSelection = _recommendedTicketSelection();
    final ticketState = _deckTicketState(ticket, ticketSelection);
    final canOpenCurrentTicket = ticket.isNotEmpty && _canShowTicketPanel;

    return LectorDeck(
      maxWidth: MediaQuery.sizeOf(context).width - 28,
      deckContext: LectorDeckContext(
        scope: LectorDeckScope.matchDetail,
        ticketState: ticketState,
      ),
      capabilities: LectorDeckCapabilities(
        onAddToTicket:
            ticketState == LectorDeckTicketState.canAdd &&
                ticketSelection != null &&
                widget.onToggleTicket != null
            ? () => widget.onToggleTicket!(ticketSelection)
            : null,
        onRemoveFromTicket:
            ticketState == LectorDeckTicketState.selected &&
                ticketSelection != null &&
                widget.onToggleTicket != null
            ? () {
                widget.onToggleTicket!(ticketSelection);
                setState(() {
                  _isTicketPanelExpanded = false;
                });
              }
            : null,
        onOpenCurrentTicket: canOpenCurrentTicket
            ? () {
                setState(() {
                  _isTicketPanelExpanded = true;
                });
              }
            : null,
        onOpenReadings: () => _showScenarioReadingsSheet(
          context,
          widget.match,
          opportunity: widget.opportunity,
        ),
        onOpenGenerator: widget.onOpenGenerator,
      ),
    );
  }

  bool get _canShowTicketPanel {
    return widget.ticketDraftListenable != null &&
        widget.onRemoveTicketSelection != null &&
        widget.onTicketSaved != null &&
        widget.onViewSavedTickets != null;
  }

  TicketDraftSelection? _recommendedTicketSelection() {
    if (widget.match.profileStatus == MatchProfileStatus.outOfProfile) {
      return null;
    }
    final recommendedMarket = _recommendedMarketForDetail(
      widget.match,
      widget.opportunity,
    );
    if (recommendedMarket == null) {
      return null;
    }
    return TicketDraftSelection.fromMatchSelection(
      widget.match,
      recommendedMarket.market,
      recommendedMarket.selection,
    );
  }

  LectorDeckTicketState _deckTicketState(
    TicketDraft ticket,
    TicketDraftSelection? ticketSelection,
  ) {
    if (ticketSelection == null || widget.onToggleTicket == null) {
      return LectorDeckTicketState.unavailable;
    }
    if (ticket.contains(ticketSelection.id)) {
      return LectorDeckTicketState.selected;
    }
    if (ticket.containsAnotherSelectionForMatch(ticketSelection)) {
      return LectorDeckTicketState.blockedByAnotherSelection;
    }
    return LectorDeckTicketState.canAdd;
  }
}

class _LectorMatchBackground extends StatelessWidget {
  const _LectorMatchBackground();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surfaces.shadow.withValues(alpha: 0.94),
            surfaces.background,
            surfaces.backgroundSecondary,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _LectorStadiumPainter(
          accent: brand.accent,
          border: surfaces.border,
          shadow: surfaces.shadow,
        ),
      ),
    );
  }
}

class _LectorStadiumPainter extends CustomPainter {
  const _LectorStadiumPainter({
    required this.accent,
    required this.border,
    required this.shadow,
  });

  final Color accent;
  final Color border;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.78),
        radius: 0.86,
        colors: [accent.withValues(alpha: 0.13), AppColors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);

    final standTop = size.height * 0.18;
    final standBottom = size.height * 0.38;
    final standPaint = Paint()..color = border.withValues(alpha: 0.22);
    final standPath = Path()
      ..moveTo(0, standTop + 44)
      ..quadraticBezierTo(
        size.width * 0.5,
        standTop - 12,
        size.width,
        standTop + 44,
      )
      ..lineTo(size.width, standBottom)
      ..quadraticBezierTo(size.width * 0.5, standBottom + 24, 0, standBottom)
      ..close();
    canvas.drawPath(standPath, standPaint);

    final linePaint = Paint()
      ..color = border.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final y = standTop + 46 + i * 18;
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * 0.5, y - 26, size.width, y);
      canvas.drawPath(path, linePaint);
    }

    final pitchTop = size.height * 0.36;
    final pitchPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.12),
          shadow.withValues(alpha: 0.18),
          AppColors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, pitchTop, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, pitchTop, size.width, size.height - pitchTop),
      pitchPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LectorStadiumPainter oldDelegate) {
    return accent != oldDelegate.accent ||
        border != oldDelegate.border ||
        shadow != oldDelegate.shadow;
  }
}

class _LectorMatchTopBar extends StatelessWidget {
  const _LectorMatchTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final textColors = context.textColors;

    return Row(
      children: [
        IconButton(
          tooltip: 'Retour',
          onPressed: onBack,
          icon: Icon(
            Icons.arrow_back_rounded,
            color: textColors.primary,
            size: 27,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => _showComingSoon(context, 'Alertes à brancher'),
          icon: Icon(
            Icons.notifications_none_rounded,
            color: textColors.primary,
            size: 24,
          ),
        ),
        IconButton(
          tooltip: 'Favori',
          onPressed: () => _showComingSoon(context, 'Favori à brancher'),
          icon: Icon(Icons.star_rounded, color: brand.accent, size: 28),
        ),
      ],
    );
  }
}

class _LectorDetailWordmark extends StatelessWidget {
  const _LectorDetailWordmark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LectorDetailMark(size: 38),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LECTOR SPORT',
              style: theme.textTheme.titleSmall?.copyWith(
                color: textColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            Text(
              'Read the Game.',
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LectorDetailMark extends StatelessWidget {
  const _LectorDetailMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return LectorBrandMark(size: size);
  }
}

class _LectorMatchHero extends StatelessWidget {
  const _LectorMatchHero({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final venueLabel = _venueValue(match.fixture.venue);
    final roundLabel = _fixtureRoundLabel(match.fixture.round);

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      backgroundAsset: _matchCardStadiumBackgroundAsset,
      child: Column(
        children: [
          Row(
            children: [
              SportsAssetBadge(
                size: 34,
                imageUrl: match.competition.logoUrl,
                fallbackLabel: match.competition.name,
                icon: Icons.emoji_events_outlined,
                contrastPlate: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.competition.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: context.textColors.onImage,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (roundLabel != null)
                      Text(
                        roundLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: brand.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _matchDateTimeLabel(match),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: brand.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _HeroTeamBlock(team: match.homeTeam, alignRight: false),
              ),
              const SizedBox(width: 8),
              _HeroStatusBlock(match: match),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroTeamBlock(team: match.awayTeam, alignRight: true),
              ),
            ],
          ),
          if (venueLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.stadium_outlined,
                  color: context.textColors.onImage.withValues(alpha: 0.72),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    venueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.textColors.onImage.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroTeamBlock extends StatelessWidget {
  const _HeroTeamBlock({required this.team, required this.alignRight});

  final TeamInfo team;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        SportsAssetBadge(
          size: 56,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          backgroundColor: AppColors.transparent,
          padding: 1,
        ),
        const SizedBox(height: 7),
        Text(
          team.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.titleMedium?.copyWith(
            color: context.textColors.onImage,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _HeroStatusBlock extends StatelessWidget {
  const _HeroStatusBlock({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final score = match.fixture.score;
    final isLive = match.fixture.status == FixtureStatus.live;
    final isFinished = match.fixture.status == FixtureStatus.finished;

    return SizedBox(
      width: 94,
      child: Column(
        children: [
          Text(
            isLive
                ? 'EN COURS'
                : isFinished
                ? 'TERMINÉ'
                : 'Avant-match',
            style: theme.textTheme.labelMedium?.copyWith(
              color: brand.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          if (score != null)
            Text(
              '${score.home} - ${score.away}',
              style: theme.textTheme.displaySmall?.copyWith(
                color: context.textColors.onImage,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            )
          else
            Text(
              '-',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: context.textColors.onImage,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          if (!isLive && !isFinished) ...[
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: brand.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Text(
                  'Avant-match',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: brand.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LectorSynthesisCard extends StatelessWidget {
  const _LectorSynthesisCard({required this.match, this.opportunity});

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    final scenarioRecommendedMarket = _scenarioRecommendedMarket(
      match,
      opportunity,
    );
    final showsScenarioPick = _hasScenarioRecommendedPick(
      scenarioRecommendedMarket,
    );
    final unpricedDirection =
        !showsScenarioPick && match.betRecommendations.length == 1
        ? match.betRecommendations.single
        : null;
    final hasClearDirection = showsScenarioPick || unpricedDirection != null;
    // A detail card must never turn several compatible markets into an
    // arbitrary team choice. When there is no single automatic candidate, it
    // says so explicitly instead of rendering both teams' generic markets.
    final title = hasClearDirection ? _scenarioTitle(match) : 'Match à suivre';
    final summary = hasClearDirection
        ? _scenarioSummary(match)
        : 'Les signaux du match ne permettent pas de mettre une équipe en avant.';
    final count = _scenarioReadingCount(match);

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: brand.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.odds),
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: brand.accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count lecture${count > 1 ? 's' : ''} convergent',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: brand.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => _showScenarioReadingsSheet(
                  context,
                  match,
                  opportunity: opportunity,
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: brand.accent,
                  side: BorderSide(color: brand.accent.withValues(alpha: 0.54)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                ),
                label: Text(
                  'Voir le détail',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: brand.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColors.secondary,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasClearDirection) ...[
            const SizedBox(height: 9),
            Divider(height: 1, color: surfaces.border),
            const SizedBox(height: 8),
            if (showsScenarioPick)
              _LectorCompactOpportunityPickRow(
                match: match,
                recommendedMarket: scenarioRecommendedMarket!,
              )
            else
              _LectorCompactUnpricedRecommendationRow(
                recommendation: unpricedDirection!,
              ),
            if (unpricedDirection != null) ...[
              const SizedBox(height: 7),
              Text(
                'Préconisation visible · ajout au ticket indisponible jusqu’à ce qu’une cote soit disponible.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColors.secondary,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LectorCompactUnpricedRecommendationRow extends StatelessWidget {
  const _LectorCompactUnpricedRecommendationRow({required this.recommendation});

  final BetRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    final warning = context.semantic.warning;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.bar_chart_rounded, color: brand.accent, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                recommendation.selectionLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Cote indisponible',
              style: theme.textTheme.labelSmall?.copyWith(
                color: warning,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LectorCompactOpportunityPickRow extends StatelessWidget {
  const _LectorCompactOpportunityPickRow({
    required this.match,
    required this.recommendedMarket,
  });

  final MatchBoardItem match;
  final RecommendedMarket recommendedMarket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    final label = _scenarioRecommendedPickLabel(match, recommendedMarket);

    if (label == null) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.bar_chart_rounded, color: brand.accent, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.clip,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              recommendedMarket.selection.odds.toStringAsFixed(2),
              style: theme.textTheme.labelLarge?.copyWith(
                color: brand.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LectorMatchTabBar extends StatelessWidget {
  const _LectorMatchTabBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = ['Contexte', 'Classement', 'Forme', 'Infos'];

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            for (var index = 0; index < _tabs.length; index++)
              Expanded(
                child: _LectorMatchTab(
                  label: _tabs[index],
                  isSelected: selectedIndex == index,
                  onPressed: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LectorMatchTab extends StatelessWidget {
  const _LectorMatchTab({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected ? brand.accent : textColors.primary,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 3,
            width: isSelected ? 58 : 0,
            decoration: BoxDecoration(
              color: brand.accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _LectorFreeTabContent extends StatelessWidget {
  const _LectorFreeTabContent({
    required this.match,
    required this.selectedIndex,
    required this.selectedReadingIds,
    required this.selectedScenarioIds,
  });

  final MatchBoardItem match;
  final int selectedIndex;
  final List<String> selectedReadingIds;
  final List<String> selectedScenarioIds;

  @override
  Widget build(BuildContext context) {
    return switch (selectedIndex) {
      0 => _LectorQuickContextCard(match: match),
      1 => _LectorStandingContextCard(
        match: match,
        selectedReadingIds: selectedReadingIds,
        selectedScenarioIds: selectedScenarioIds,
      ),
      2 => _LectorFormContextCard(match: match),
      _ => _LectorInfoContextCard(match: match),
    };
  }
}

class _LectorQuickContextCard extends StatelessWidget {
  const _LectorQuickContextCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final keys = match.analysis.contextKeys;
    final serverContextReadings = _quickContextReadingsFor(match);
    final decisivePlayerGroups = _decisivePlayerGroupsFor(match);
    final vigilanceReadings = _contextVigilanceReadingsFor(match);
    final quickFactCount = keys.length + serverContextReadings.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: brand.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: brand.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Clés du match',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: textColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: textColors.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ce qui caractérise cette rencontre avant le coup d’envoi.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (quickFactCount > 0) ...[
                const SizedBox(width: 8),
                _ContextKeyCount(count: quickFactCount),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (quickFactCount == 0 && decisivePlayerGroups.isEmpty)
            const _ContextKeyEmptyState()
          else ...[
            for (var index = 0; index < keys.length; index += 1) ...[
              _MatchContextKeyCard(match: match, contextKey: keys[index]),
              if (index != keys.length - 1) const SizedBox(height: 9),
            ],
            for (final reading in serverContextReadings) ...[
              if (keys.isNotEmpty || reading != serverContextReadings.first)
                const SizedBox(height: 9),
              _ServerComputedContextCard(match: match, reading: reading),
            ],
            if (decisivePlayerGroups.isNotEmpty) ...[
              const SizedBox(height: 18),
              _DecisivePlayersContextSection(groups: decisivePlayerGroups),
            ],
            if (vigilanceReadings.isNotEmpty) ...[
              const SizedBox(height: 18),
              _ContextVigilanceSection(
                match: match,
                readings: vigilanceReadings,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ContextKeyCount extends StatelessWidget {
  const _ContextKeyCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: brand.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: brand.accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          count == 1 ? '1 clé' : '$count clés',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: brand.accent,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ContextKeyEmptyState extends StatelessWidget {
  const _ContextKeyEmptyState();

  @override
  Widget build(BuildContext context) {
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.forum_outlined, color: textColors.secondary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Peu d’éléments différenciants ressortent avant cette rencontre.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<MatchComputedReading> _quickContextReadingsFor(MatchBoardItem match) {
  const excludedIds = {
    'standout_decisive_player',
    'key_player_unavailable',
    'match_shot_profile',
    'match_corner_profile',
    'match_card_profile',
    'high_total_corners_profile',
    'high_total_cards_profile',
    'second_half_cards_profile',
    'high_card_rate',
    'low_card_rate',
    'high_shot_volume',
    'low_shot_volume',
    'high_shots_on_target',
    'low_shot_accuracy',
    'high_shots_conceded',
    'high_shots_on_target_conceded',
    'high_corner_creation',
    'high_corners_conceded',
  };
  return match.analysis.computedReadings
      .where(
        (reading) =>
            !excludedIds.contains(reading.id) &&
            !reading.isContradiction &&
            reading.playerName == null &&
            reading.evidenceLabel.trim().isNotEmpty,
      )
      .take(3)
      .toList(growable: false);
}

List<MatchComputedReading> _contextVigilanceReadingsFor(MatchBoardItem match) =>
    match.analysis.computedReadings
        .where(
          (reading) =>
              reading.isContradiction || reading.id == 'key_player_unavailable',
        )
        .take(3)
        .toList(growable: false);

class _ServerComputedContextCard extends StatelessWidget {
  const _ServerComputedContextCard({
    required this.match,
    required this.reading,
  });

  final MatchBoardItem match;
  final MatchComputedReading reading;

  @override
  Widget build(BuildContext context) {
    final accent = context.brand.accent;
    final surfaces = context.surfaces;
    final team = _teamForSubject(match, reading.subjectTeamId);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (team != null) ...[
              SportsAssetBadge(
                size: 38,
                imageUrl: team.logoUrl,
                fallbackLabel: team.name,
                borderRadius: 19,
                backgroundColor: AppColors.transparent,
                contrastPlate: true,
              ),
            ] else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: SizedBox.square(
                  dimension: 38,
                  child: Icon(
                    _quickContextIcon(reading.id),
                    size: 20,
                    color: accent,
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _quickContextTitle(reading.id, team?.name),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reading.evidenceLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textColors.secondary,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
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

IconData _quickContextIcon(String readingId) => switch (readingId) {
  'ranking_superiority' ||
  'ranking_inferiority' ||
  'structural_level_gap' => Icons.bar_chart_rounded,
  'positive_streak' ||
  'negative_streak' ||
  'improving_form' ||
  'declining_form' ||
  'form_advantage' => Icons.trending_up_rounded,
  'strong_home_team' ||
  'weak_home_team' ||
  'strong_away_team' ||
  'weak_away_team' ||
  'venue_strength' => Icons.home_outlined,
  'prolific_attack' ||
  'attack_in_form' ||
  'scoring_difficulty' => Icons.bolt_rounded,
  'fragile_defense' || 'defensive_underperformance' => Icons.shield_outlined,
  _ => Icons.auto_awesome_rounded,
};

String _quickContextTitle(String readingId, String? teamName) {
  final team = teamName == null ? '' : ' pour $teamName';
  return switch (readingId) {
    'ranking_superiority' => 'Avantage au classement$team',
    'ranking_inferiority' => 'Retard au classement$team',
    'structural_level_gap' => 'Écart de niveau structurel$team',
    'positive_streak' => 'Dynamique positive$team',
    'negative_streak' => 'Dynamique négative$team',
    'improving_form' => 'Forme en hausse$team',
    'declining_form' => 'Forme en baisse$team',
    'form_advantage' => 'Avantage de forme$team',
    'strong_home_team' => 'Solide à domicile$team',
    'weak_home_team' => 'Fragile à domicile$team',
    'strong_away_team' => 'Solide à l’extérieur$team',
    'weak_away_team' => 'Fragile à l’extérieur$team',
    'venue_strength' => 'Avantage du lieu$team',
    'prolific_attack' => 'Attaque prolifique$team',
    'attack_in_form' => 'Attaque en forme$team',
    'scoring_difficulty' => 'Difficulté à marquer$team',
    'fragile_defense' => 'Défense fragile$team',
    'defensive_underperformance' => 'Défense en difficulté$team',
    _ => 'Fait marquant$team',
  };
}

class _DecisivePlayerGroup {
  const _DecisivePlayerGroup({required this.team, required this.readings});

  final TeamInfo team;
  final List<MatchComputedReading> readings;
}

List<_DecisivePlayerGroup> _decisivePlayerGroupsFor(MatchBoardItem match) {
  final readingsByTeam = <String, List<MatchComputedReading>>{};
  for (final reading in match.analysis.computedReadings) {
    final recent = _computedMap(_computedMap(reading.evidenceValue)['recent']);
    if (reading.id != 'standout_decisive_player' ||
        reading.isContradiction ||
        reading.playerName == null ||
        (_computedInt(recent['matches_considered']) ?? 0) < 3 ||
        (_computedInt(recent['minutes']) ?? 0) <= 0) {
      continue;
    }
    readingsByTeam.putIfAbsent(reading.subjectTeamId, () => []).add(reading);
  }

  final groups = <_DecisivePlayerGroup>[];
  for (final team in [match.homeTeam, match.awayTeam]) {
    final readings = readingsByTeam[team.id];
    if (readings == null || readings.isEmpty) continue;
    readings.sort(
      (left, right) => _playerRank(left).compareTo(_playerRank(right)),
    );
    groups.add(_DecisivePlayerGroup(team: team, readings: readings));
  }
  return List.unmodifiable(groups);
}

int _playerRank(MatchComputedReading reading) {
  final recent = _computedMap(_computedMap(reading.evidenceValue)['recent']);
  return _computedInt(recent['player_rank']) ?? 999;
}

class _DecisivePlayersContextSection extends StatelessWidget {
  const _DecisivePlayersContextSection({required this.groups});

  final List<_DecisivePlayerGroup> groups;

  @override
  Widget build(BuildContext context) {
    final count = groups.fold<int>(
      0,
      (total, group) => total + group.readings.length,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Joueurs décisifs à surveiller · $count',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Profils calculés sur les trois derniers matchs terminés.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        for (final indexed in groups.indexed) ...[
          _DecisivePlayerTeamCard(group: indexed.$2),
          if (indexed.$1 < groups.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _ContextVigilanceSection extends StatelessWidget {
  const _ContextVigilanceSection({required this.match, required this.readings});

  final MatchBoardItem match;
  final List<MatchComputedReading> readings;

  @override
  Widget build(BuildContext context) {
    final warning = context.semantic.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Points de vigilance',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: warning,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (final indexed in readings.indexed) ...[
          _ContextVigilanceCard(match: match, reading: indexed.$2),
          if (indexed.$1 < readings.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ContextVigilanceCard extends StatelessWidget {
  const _ContextVigilanceCard({required this.match, required this.reading});

  final MatchBoardItem match;
  final MatchComputedReading reading;

  @override
  Widget build(BuildContext context) {
    final warning = context.semantic.warning;
    final team = _teamForSubject(match, reading.subjectTeamId);
    final title = reading.id == 'key_player_unavailable'
        ? '${reading.playerName ?? 'Joueur important'} absent'
        : _quickContextTitle(reading.id, team?.name);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: warning.withValues(alpha: 0.66)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SportsAssetBadge(
              size: 36,
              imageUrl: reading.playerPhotoUrl ?? team?.logoUrl,
              fallbackLabel: reading.playerName ?? team?.name ?? title,
              borderRadius: 18,
              backgroundColor: AppColors.transparent,
              contrastPlate: true,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: warning,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reading.evidenceLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textColors.secondary,
                      fontWeight: FontWeight.w600,
                      height: 1.22,
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

class _DecisivePlayerTeamCard extends StatelessWidget {
  const _DecisivePlayerTeamCard({required this.group});

  final _DecisivePlayerGroup group;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SportsAssetBadge(
                  size: 31,
                  imageUrl: group.team.logoUrl,
                  fallbackLabel: group.team.name,
                  borderRadius: 16,
                  backgroundColor: AppColors.transparent,
                  contrastPlate: true,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.team.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final indexed in group.readings.indexed) ...[
              _DecisivePlayerRow(reading: indexed.$2),
              if (indexed.$1 < group.readings.length - 1)
                Divider(
                  height: 17,
                  color: context.surfaces.border.withValues(alpha: 0.72),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DecisivePlayerRow extends StatelessWidget {
  const _DecisivePlayerRow({required this.reading});

  final MatchComputedReading reading;

  @override
  Widget build(BuildContext context) {
    final value = _computedMap(reading.evidenceValue);
    final recent = _computedMap(value['recent']);
    final isSuperSub = value['is_super_sub'] == true;
    final profile = _displayProfile(value['profile_label']);
    final name = reading.playerName ?? 'Joueur à surveiller';
    final details = _playerContributionLine(recent, isSuperSub: isSuperSub);
    final rate = _computedDouble(recent['contributions_per_90']);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SportsAssetBadge(
          size: 40,
          imageUrl: reading.playerPhotoUrl,
          fallbackLabel: name,
          borderRadius: 20,
          backgroundColor: AppColors.transparent,
          contrastPlate: true,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _DecisiveProfileChip(label: profile),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                details,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textColors.secondary,
                  fontWeight: FontWeight.w600,
                  height: 1.22,
                ),
              ),
              if (rate != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${rate.toStringAsFixed(2).replaceAll('.', ',')} action${rate == 1 ? '' : 's'} décisive${rate == 1 ? '' : 's'} / 90 min',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.brand.accent,
                    fontWeight: FontWeight.w900,
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

class _DecisiveProfileChip extends StatelessWidget {
  const _DecisiveProfileChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.brand.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String _displayProfile(Object? value) {
  final raw = value?.toString().trim().toLowerCase();
  return switch (raw) {
    'buteur' => 'Buteur',
    'passeur' => 'Passeur',
    'décisif' => 'Décisif',
    'buteur · super-sub' => 'Buteur · super-sub',
    'passeur · super-sub' => 'Passeur · super-sub',
    'décisif · super-sub' => 'Décisif · super-sub',
    _ => 'Joueur décisif',
  };
}

String _playerContributionLine(
  Map<String, Object?> recent, {
  required bool isSuperSub,
}) {
  final appearances = _computedInt(recent['appearances']) ?? 0;
  final substitutions = _computedInt(recent['substitute_appearances']) ?? 0;
  final contributingMatches =
      _computedInt(recent['matches_with_contribution']) ?? 0;
  final goals = _computedInt(recent['goals']) ?? 0;
  final assists = _computedInt(recent['assists']) ?? 0;
  final minutes = _computedInt(recent['minutes']) ?? 0;
  final contributionParts = <String>[
    if (goals > 0) '$goals but${goals == 1 ? '' : 's'}',
    if (assists > 0) '$assists passe${assists == 1 ? '' : 's'}',
  ];
  final contribution = contributionParts.isEmpty
      ? '$contributingMatches match${contributingMatches == 1 ? '' : 's'} décisif${contributingMatches == 1 ? '' : 's'}'
      : contributionParts.join(', ');
  if (isSuperSub) {
    return '$substitutions entrée${substitutions == 1 ? '' : 's'} en jeu · '
        'décisif sur $contributingMatches/3 matchs · $contribution · $minutes min';
  }
  return '$appearances matchs · $contribution · $minutes min';
}

Map<String, Object?> _computedMap(Object? value) => value is Map
    ? {for (final entry in value.entries) entry.key.toString(): entry.value}
    : const {};

int? _computedInt(Object? value) => switch (value) {
  int value => value,
  num value => value.toInt(),
  String value => int.tryParse(value),
  _ => null,
};

double? _computedDouble(Object? value) => switch (value) {
  num value => value.toDouble(),
  String value => double.tryParse(value),
  _ => null,
};

class _MatchContextKeyCard extends StatelessWidget {
  const _MatchContextKeyCard({required this.match, required this.contextKey});

  final MatchBoardItem match;
  final MatchContextKey contextKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      decoration: BoxDecoration(
        color: surfaces.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: surfaces.border),
        boxShadow: [
          BoxShadow(
            color: surfaces.shadow.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: brand.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: brand.accent.withValues(alpha: 0.32)),
            ),
            child: Icon(
              _iconFor(contextKey.family),
              color: brand.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _familyLabel(contextKey.family),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: brand.accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _conclusionFor(contextKey),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: textColors.primary,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 10),
                _factsFor(contextKey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _familyLabel(MatchContextKeyFamily family) {
    return switch (family) {
      MatchContextKeyFamily.hierarchy => 'HIÉRARCHIE',
      MatchContextKeyFamily.structure => 'STRUCTURE',
      MatchContextKeyFamily.form => 'FORME',
      MatchContextKeyFamily.venue => 'DOMICILE / EXTÉRIEUR',
      MatchContextKeyFamily.attack => 'ATTAQUE',
      MatchContextKeyFamily.defense => 'DÉFENSE',
      MatchContextKeyFamily.opposition => 'OPPOSITION',
    };
  }

  String _conclusionFor(MatchContextKey key) {
    final high = _highlightNames(key, ChampionshipContextZoneSide.high);
    final low = _highlightNames(key, ChampionshipContextZoneSide.low);
    final facts = key.facts;
    return switch (key.semanticScope) {
      'championship_positioning' ||
      'official_positioning' => _hierarchyConclusion(high, low, facts),
      'championship_structure' => 'Écart structurel entre les deux équipes',
      'recent_form' =>
        high.isNotEmpty
            ? '$high dans une dynamique remarquable'
            : '$low dans une dynamique récente en retrait',
      'offensive_production' =>
        high.isNotEmpty
            ? '$high se distingue offensivement'
            : '$low parmi les attaques les moins productives',
      'defensive_exposure' =>
        high.isNotEmpty
            ? '$high parmi les défenses les plus exposées'
            : '$low se distingue défensivement',
      'attack_against_exposed_defense' =>
        '${_teamName(facts['attackTeamId'])} face à une défense adverse exposée',
      _ => 'Fait contextuel remarquable',
    };
  }

  String _hierarchyConclusion(
    String high,
    String low,
    Map<String, Object?> facts,
  ) {
    final homeRank = facts['homeRank'];
    final awayRank = facts['awayRank'];
    if (high.isNotEmpty && homeRank == 1 && high == match.homeTeam.name) {
      return '${match.homeTeam.name} en tête du championnat';
    }
    if (high.isNotEmpty && awayRank == 1 && high == match.awayTeam.name) {
      return '${match.awayTeam.name} en tête du championnat';
    }
    if (high.isNotEmpty) {
      return '$high se distingue au classement';
    }
    if (low.isNotEmpty) {
      return '$low occupe une position basse au classement';
    }
    return 'Écart de position dans le championnat';
  }

  Widget _factsFor(MatchContextKey key) {
    return switch (key.semanticScope) {
      'championship_positioning' ||
      'official_positioning' => _HierarchyFacts(match: match, contextKey: key),
      'championship_structure' => _StructureFacts(contextKey: key),
      'recent_form' => _FormFacts(match: match, contextKey: key),
      'offensive_production' => _RateFacts(
        match: match,
        contextKey: key,
        factName: 'goalsForPerGame',
        label: 'buts marqués / match',
      ),
      'defensive_exposure' => _RateFacts(
        match: match,
        contextKey: key,
        factName: 'goalsAgainstPerGame',
        label: 'buts encaissés / match',
      ),
      'attack_against_exposed_defense' => _OppositionFacts(
        match: match,
        contextKey: key,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  String _highlightNames(
    MatchContextKey key,
    ChampionshipContextZoneSide direction,
  ) {
    return key.highlights
        .where((highlight) => highlight.direction == direction)
        .map((highlight) => _teamName(highlight.teamId))
        .join(' et ');
  }

  String _teamName(Object? teamId) {
    if (teamId == match.homeTeam.apiFootballTeamId) return match.homeTeam.name;
    if (teamId == match.awayTeam.apiFootballTeamId) return match.awayTeam.name;
    return 'Équipe';
  }

  IconData _iconFor(MatchContextKeyFamily family) {
    return switch (family) {
      MatchContextKeyFamily.hierarchy => Icons.bar_chart_rounded,
      MatchContextKeyFamily.structure => Icons.account_tree_outlined,
      MatchContextKeyFamily.form => Icons.monitor_heart_outlined,
      MatchContextKeyFamily.venue => Icons.home_outlined,
      MatchContextKeyFamily.attack => Icons.bolt_rounded,
      MatchContextKeyFamily.defense => Icons.shield_outlined,
      MatchContextKeyFamily.opposition => Icons.compare_arrows_rounded,
    };
  }
}

class _HierarchyFacts extends StatelessWidget {
  const _HierarchyFacts({required this.match, required this.contextKey});

  final MatchBoardItem match;
  final MatchContextKey contextKey;

  @override
  Widget build(BuildContext context) {
    final facts = contextKey.facts;
    return Row(
      children: [
        Expanded(
          child: _ContextKeyFactPanel(
            teamName: match.homeTeam.name,
            primary: _ordinal(_contextInt(facts['homeRank'])),
            secondary: _contextPointsLabel(_contextInt(facts['homePoints'])),
            emphasis: _contextKeyTeamColor(context, contextKey, match.homeTeam),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _ContextKeyFactPanel(
            teamName: match.awayTeam.name,
            primary: _ordinal(_contextInt(facts['awayRank'])),
            secondary: _contextPointsLabel(_contextInt(facts['awayPoints'])),
            emphasis: _contextKeyTeamColor(context, contextKey, match.awayTeam),
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _StructureFacts extends StatelessWidget {
  const _StructureFacts({required this.contextKey});

  final MatchContextKey contextKey;

  @override
  Widget build(BuildContext context) {
    final facts = contextKey.facts;
    final textColors = context.textColors;
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _contextTierLabel(facts['homeTier']),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 18, color: brand.accent),
            Expanded(
              child: Text(
                _contextTierLabel(facts['awayTier']),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_contextInt(facts['boundaryCount']) ?? '—'} frontière(s) confirmée(s)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: textColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FormFacts extends StatelessWidget {
  const _FormFacts({required this.match, required this.contextKey});

  final MatchBoardItem match;
  final MatchContextKey contextKey;

  @override
  Widget build(BuildContext context) {
    final facts = contextKey.facts;
    return Row(
      children: [
        Expanded(
          child: _ContextKeyFormPanel(
            teamName: match.homeTeam.name,
            form: _contextString(facts['homeForm']),
            points: _contextInt(facts['homePoints']),
            alignEnd: false,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _ContextKeyFormPanel(
            teamName: match.awayTeam.name,
            form: _contextString(facts['awayForm']),
            points: _contextInt(facts['awayPoints']),
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _RateFacts extends StatelessWidget {
  const _RateFacts({
    required this.match,
    required this.contextKey,
    required this.factName,
    required this.label,
  });

  final MatchBoardItem match;
  final MatchContextKey contextKey;
  final String factName;
  final String label;

  @override
  Widget build(BuildContext context) {
    final facts = contextKey.facts;
    return Row(
      children: [
        Expanded(
          child: _ContextKeyFactPanel(
            teamName: match.homeTeam.name,
            primary: _rate(_contextDouble(facts['home$factName'])),
            secondary: label,
            emphasis: _contextKeyTeamColor(context, contextKey, match.homeTeam),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _ContextKeyFactPanel(
            teamName: match.awayTeam.name,
            primary: _rate(_contextDouble(facts['away$factName'])),
            secondary: label,
            emphasis: _contextKeyTeamColor(context, contextKey, match.awayTeam),
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _OppositionFacts extends StatelessWidget {
  const _OppositionFacts({required this.match, required this.contextKey});

  final MatchBoardItem match;
  final MatchContextKey contextKey;

  @override
  Widget build(BuildContext context) {
    final facts = contextKey.facts;
    return Row(
      children: [
        Expanded(
          child: _ContextKeyFactPanel(
            teamName: _contextKeyTeamName(match, facts['attackTeamId']),
            primary: _rate(_contextDouble(facts['goalsForPerGame'])),
            secondary: 'buts marqués / match',
            emphasis: context.semantic.success,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _ContextKeyFactPanel(
            teamName: _contextKeyTeamName(match, facts['defenseTeamId']),
            primary: _rate(_contextDouble(facts['goalsAgainstPerGame'])),
            secondary: 'buts encaissés / match',
            emphasis: context.semantic.error,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _ContextKeyFactPanel extends StatelessWidget {
  const _ContextKeyFactPanel({
    required this.teamName,
    required this.primary,
    required this.secondary,
    this.emphasis,
    this.alignEnd = false,
  });

  final String teamName;
  final String primary;
  final String secondary;
  final Color? emphasis;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final textColors = context.textColors;
    final alignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppRadius.tight),
      ),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            primary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: emphasis ?? textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            secondary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextKeyFormPanel extends StatelessWidget {
  const _ContextKeyFormPanel({
    required this.teamName,
    required this.form,
    required this.points,
    required this.alignEnd,
  });

  final String? teamName;
  final String? form;
  final int? points;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final normalized = (form ?? '').toUpperCase().split('');
    final textColors = context.textColors;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppRadius.tight),
      ),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            teamName ?? 'Équipe',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
            children: [
              for (final result in normalized)
                _ContextKeyFormResult(result: result),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            points == null ? '—' : '$points/15',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextKeyFormResult extends StatelessWidget {
  const _ContextKeyFormResult({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _formDotColor(context, result).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: _formDotColor(context, result).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        _formDotLabel(result),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _formDotColor(context, result),
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

int? _contextInt(Object? value) => value is num ? value.toInt() : null;

double? _contextDouble(Object? value) => value is num ? value.toDouble() : null;

String? _contextString(Object? value) => value is String ? value : null;

String _rate(double? value) => value == null ? '—' : value.toStringAsFixed(2);

String _contextPointsLabel(int? points) => points == null ? '—' : '$points pts';

String _ordinal(int? rank) {
  if (rank == null) return '—';
  return rank == 1 ? '1er' : '${rank}e';
}

String _contextTierLabel(Object? value) {
  final code = _contextString(value);
  for (final tier in TierLabel.values) {
    if (tier.code == code) {
      return _tierDisplayLabel(tier);
    }
  }
  return 'Tier indisponible';
}

String _contextKeyTeamName(MatchBoardItem match, Object? teamId) {
  if (teamId == match.homeTeam.apiFootballTeamId) return match.homeTeam.name;
  if (teamId == match.awayTeam.apiFootballTeamId) return match.awayTeam.name;
  return 'Équipe';
}

Color? _contextKeyTeamColor(
  BuildContext context,
  MatchContextKey key,
  TeamInfo team,
) {
  final teamId = team.apiFootballTeamId;
  if (teamId == null) return null;
  final direction = key.highlights
      .where((highlight) => highlight.teamId == teamId)
      .map((highlight) => highlight.direction)
      .firstOrNull;
  if (direction == null) return null;
  return switch (key.family) {
    MatchContextKeyFamily.attack =>
      direction == ChampionshipContextZoneSide.high
          ? context.semantic.success
          : context.semantic.error,
    MatchContextKeyFamily.defense =>
      direction == ChampionshipContextZoneSide.low
          ? context.semantic.success
          : context.semantic.error,
    _ => context.brand.accent,
  };
}

class _ContextComparisonRow extends StatelessWidget {
  const _ContextComparisonRow({
    required this.icon,
    required this.label,
    required this.home,
    required this.center,
    required this.away,
  });

  final IconData icon;
  final String label;
  final Widget home;
  final Widget center;
  final Widget away;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: brand.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: home),
              const SizedBox(width: 8),
              SizedBox(width: 82, child: center),
              const SizedBox(width: 8),
              Expanded(child: away),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamMetricSummary extends StatelessWidget {
  const _TeamMetricSummary({
    required this.logoUrl,
    required this.fallbackLabel,
    required this.value,
    required this.detail,
    required this.accent,
    required this.alignRight,
  });

  final String? logoUrl;
  final String fallbackLabel;
  final String value;
  final String detail;
  final Color accent;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;

    return Row(
      mainAxisAlignment: alignRight
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!alignRight) ...[
          SportsAssetBadge(
            size: 28,
            imageUrl: logoUrl,
            fallbackLabel: fallbackLabel,
            backgroundColor: AppColors.transparent,
            padding: 1,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: alignRight
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        if (alignRight) ...[
          const SizedBox(width: 8),
          SportsAssetBadge(
            size: 28,
            imageUrl: logoUrl,
            fallbackLabel: fallbackLabel,
            backgroundColor: AppColors.transparent,
            padding: 1,
          ),
        ],
      ],
    );
  }
}

class _TeamFormSummary extends StatelessWidget {
  const _TeamFormSummary({required this.results, this.alignRight = false});

  final List<String> results;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final points = _formPoints(results);

    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        _FormDots(results: results),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$points',
                style: TextStyle(
                  color: _formPerformanceColor(context, results),
                ),
              ),
              const TextSpan(text: ' / 15 pts'),
            ],
          ),
          style: theme.textTheme.labelMedium?.copyWith(
            color: textColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HomeAwaySummary extends StatelessWidget {
  const _HomeAwaySummary({
    required this.title,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.played,
    this.alignRight = false,
  });

  final String title;
  final int? wins;
  final int? draws;
  final int? losses;
  final int? played;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final winCount = wins;
    final drawCount = draws;
    final lossCount = losses;
    final playedCount = played;
    final percent = _winPercentLabel(winCount, playedCount);

    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${winCount ?? '-'} V',
                style: TextStyle(color: context.semantic.success),
              ),
              TextSpan(
                text: '  ${drawCount ?? '-'} N',
                style: TextStyle(color: textColors.secondary),
              ),
              TextSpan(
                text: '  ${lossCount ?? '-'} D',
                style: TextStyle(color: context.semantic.error),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          percent,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ContextDeltaPill extends StatelessWidget {
  const _ContextDeltaPill({required this.primary, required this.secondary});

  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppRadius.odds),
        border: Border.all(color: surfaces.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            primary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: _contextDeltaColor(context, primary),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            secondary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LectorStandingContextCard extends StatefulWidget {
  const _LectorStandingContextCard({
    required this.match,
    this.selectedReadingIds = const [],
    this.selectedScenarioIds = const [],
  });

  final MatchBoardItem match;
  final List<String> selectedReadingIds;
  final List<String> selectedScenarioIds;

  @override
  State<_LectorStandingContextCard> createState() =>
      _LectorStandingContextCardState();
}

class _LectorStandingContextCardState
    extends State<_LectorStandingContextCard> {
  ChampionshipStandingView _selectedView = ChampionshipStandingView.general;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final match = widget.match;
    final views = _standingViews(
      match,
      selectedReadingIds: widget.selectedReadingIds,
      selectedScenarioIds: widget.selectedScenarioIds,
    );
    if (views.isEmpty) {
      return _LectorGlassCard(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: brand.accent, size: 22),
                const SizedBox(width: 8),
                Text(
                  'CLASSEMENT',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Position, points et dynamique dans le championnat.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: textColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _LectorInfoRow(
              icon: Icons.info_outline_rounded,
              label: 'Classement indisponible',
              trailing: const [TextSpan(text: 'Snapshot incomplet')],
            ),
          ],
        ),
      );
    }
    final selectedView = views.any((item) => item.view == _selectedView)
        ? _selectedView
        : ChampionshipStandingView.general;
    final selectedDefinition = views.firstWhere(
      (item) => item.view == selectedView,
    );
    final standings = match.analysis.standingsFor(selectedView);

    if (standings.isEmpty) {
      return _LectorInfoCard(
        title: 'Classement',
        rows: [
          _LectorInfoRow(
            icon: Icons.info_outline_rounded,
            label: 'Classement indisponible',
            trailing: const [TextSpan(text: 'Snapshot incomplet')],
          ),
        ],
      );
    }

    final tierSnapshot = selectedView == ChampionshipStandingView.general
        ? match.analysis.championshipTierSnapshot
        : null;
    final hasTierSnapshot = tierSnapshot?.teamAssignments.isNotEmpty == true;
    final tiersAreProvisional =
        hasTierSnapshot && tierSnapshot!.status != TierSystemStatus.mature;
    final hasOfficialZones =
        selectedView == ChampionshipStandingView.general &&
        standings.any((standing) => _officialStandingZone(standing) != null);
    final officialZones = _officialStandingLegendItems(standings);

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: brand.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CLASSEMENT',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            selectedDefinition.description,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _StandingViewSelector(
            views: views,
            selectedView: selectedView,
            onSelected: (view) => setState(() => _selectedView = view),
          ),
          const SizedBox(height: 10),
          if (selectedView == ChampionshipStandingView.general) ...[
            _StandingUnifiedLegend(
              officialZones: officialZones,
              tiers: hasTierSnapshot
                  ? tierSnapshot?.tierPresence.toList() ?? const []
                  : const [],
              hasTierSnapshot: hasTierSnapshot,
              hasOfficialZones: hasOfficialZones,
              tiersAreProvisional: tiersAreProvisional,
            ),
            const SizedBox(height: 10),
          ],
          _MobileStandingTable(
            match: match,
            standings: standings,
            tierSnapshot: hasTierSnapshot ? tierSnapshot : null,
            showOfficialZones: selectedView == ChampionshipStandingView.general,
            lastColumnLabel:
                selectedView == ChampionshipStandingView.expectedGoals
                ? 'xG'
                : 'Pts',
          ),
        ],
      ),
    );
  }
}

class _StandingViewDefinition {
  const _StandingViewDefinition({
    required this.view,
    required this.label,
    required this.description,
    this.sourceId,
    this.isPersonalized = false,
  });

  final ChampionshipStandingView view;
  final String label;
  final String description;
  final String? sourceId;
  final bool isPersonalized;
}

List<_StandingViewDefinition> _standingViews(
  MatchBoardItem match, {
  required List<String> selectedReadingIds,
  required List<String> selectedScenarioIds,
}) {
  final result = <ChampionshipStandingView, _StandingViewDefinition>{};

  void add(
    ChampionshipStandingView view, {
    String? sourceId,
    bool personalized = false,
  }) {
    if (match.analysis.standingsFor(view).isEmpty || result.containsKey(view)) {
      return;
    }
    final base = _standingViewDefinition(view);
    result[view] = _StandingViewDefinition(
      view: view,
      label: base.label,
      description: base.description,
      sourceId: sourceId,
      isPersonalized: personalized,
    );
  }

  add(ChampionshipStandingView.general);
  for (final readingId in selectedReadingIds) {
    final view = _standingViewForReading(readingId);
    if (view != null) add(view, sourceId: readingId, personalized: true);
  }
  for (final scenarioId in selectedScenarioIds) {
    final scenario = FootballScenarioCatalog.byId(scenarioId);
    if (scenario == null) continue;
    for (final requirement in scenario.requirements) {
      if (requirement.readingId == 'venue_strength') {
        add(
          ChampionshipStandingView.home,
          sourceId: scenarioId,
          personalized: true,
        );
        add(
          ChampionshipStandingView.away,
          sourceId: scenarioId,
          personalized: true,
        );
        continue;
      }
      final view = _standingViewForReading(requirement.readingId);
      if (view != null) add(view, sourceId: scenarioId, personalized: true);
    }
  }
  for (final view in const [
    ChampionshipStandingView.home,
    ChampionshipStandingView.away,
    ChampionshipStandingView.form,
    ChampionshipStandingView.firstLeg,
    ChampionshipStandingView.secondLeg,
    ChampionshipStandingView.firstHalf,
    ChampionshipStandingView.secondHalf,
  ]) {
    add(view);
  }
  return result.values.toList(growable: false);
}

ChampionshipStandingView? _standingViewForReading(String readingId) {
  return switch (readingId) {
    'strong_home_team' || 'weak_home_team' => ChampionshipStandingView.home,
    'strong_away_team' || 'weak_away_team' => ChampionshipStandingView.away,
    'home_away_advantage' => ChampionshipStandingView.home,
    'away_home_advantage' => ChampionshipStandingView.away,
    'positive_streak' ||
    'negative_streak' ||
    'improving_form' ||
    'declining_form' ||
    'form_advantage' => ChampionshipStandingView.form,
    'prolific_attack' ||
    'scoring_difficulty' ||
    'high_shots_on_target' => ChampionshipStandingView.attack,
    'high_xg_creation' ||
    'low_xg_creation' => ChampionshipStandingView.expectedGoals,
    'solid_defense' ||
    'fragile_defense' ||
    'high_xg_conceded' ||
    'high_shots_on_target_conceded' => ChampionshipStandingView.defense,
    'ranking_superiority' ||
    'ranking_inferiority' ||
    'structural_level_gap' => ChampionshipStandingView.general,
    'frequent_first_half_scoring' ||
    'frequent_first_half_conceding' => ChampionshipStandingView.firstHalf,
    'frequent_second_half_scoring' ||
    'frequent_second_half_conceding' => ChampionshipStandingView.secondHalf,
    _ => null,
  };
}

_StandingViewDefinition _standingViewDefinition(ChampionshipStandingView view) {
  return switch (view) {
    ChampionshipStandingView.general => const _StandingViewDefinition(
      view: ChampionshipStandingView.general,
      label: 'Général',
      description: 'Position, points, Tiers Lector et enjeux officiels.',
    ),
    ChampionshipStandingView.home => const _StandingViewDefinition(
      view: ChampionshipStandingView.home,
      label: 'Domicile',
      description: 'Classement calculé uniquement sur les matchs à domicile.',
    ),
    ChampionshipStandingView.away => const _StandingViewDefinition(
      view: ChampionshipStandingView.away,
      label: 'Extérieur',
      description: 'Classement calculé uniquement sur les déplacements.',
    ),
    ChampionshipStandingView.form => const _StandingViewDefinition(
      view: ChampionshipStandingView.form,
      label: 'Forme',
      description: 'Classement sur la forme récente disponible.',
    ),
    ChampionshipStandingView.firstLeg => const _StandingViewDefinition(
      view: ChampionshipStandingView.firstLeg,
      label: 'Aller',
      description: 'Classement des premières confrontations de la saison.',
    ),
    ChampionshipStandingView.secondLeg => const _StandingViewDefinition(
      view: ChampionshipStandingView.secondLeg,
      label: 'Retour',
      description: 'Classement des secondes confrontations de la saison.',
    ),
    ChampionshipStandingView.firstHalf => const _StandingViewDefinition(
      view: ChampionshipStandingView.firstHalf,
      label: '1re MT',
      description: 'Classement reconstruit avec les scores à la pause.',
    ),
    ChampionshipStandingView.secondHalf => const _StandingViewDefinition(
      view: ChampionshipStandingView.secondHalf,
      label: '2e MT',
      description: 'Classement reconstruit avec les buts après la pause.',
    ),
    ChampionshipStandingView.attack => const _StandingViewDefinition(
      view: ChampionshipStandingView.attack,
      label: 'Attaque',
      description: 'Classement des attaques selon les buts marqués.',
    ),
    ChampionshipStandingView.defense => const _StandingViewDefinition(
      view: ChampionshipStandingView.defense,
      label: 'Défense',
      description: 'Classement des défenses selon les buts encaissés.',
    ),
    ChampionshipStandingView.expectedGoals => const _StandingViewDefinition(
      view: ChampionshipStandingView.expectedGoals,
      label: 'xG offensif',
      description: 'Classement selon la moyenne d’xG offensif disponible.',
    ),
  };
}

class _StandingViewSelector extends StatelessWidget {
  const _StandingViewSelector({
    required this.views,
    required this.selectedView,
    required this.onSelected,
  });

  final List<_StandingViewDefinition> views;
  final ChampionshipStandingView selectedView;
  final ValueChanged<ChampionshipStandingView> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in views) ...[
            _StandingViewChip(
              definition: item,
              isSelected: item.view == selectedView,
              onPressed: () => onSelected(item.view),
            ),
            if (item != views.last) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _StandingViewChip extends StatelessWidget {
  const _StandingViewChip({
    required this.definition,
    required this.isSelected,
    required this.onPressed,
  });

  final _StandingViewDefinition definition;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sourceId = definition.sourceId;
    final color = sourceId == null
        ? context.brand.accent
        : FootballScenarioCatalog.byId(sourceId) != null
        ? context.opportunities.scenarioIdentityForProfileId(sourceId).color
        : context.opportunities.readingIdentityForId(sourceId).color;
    return Semantics(
      label: definition.isPersonalized
          ? '${definition.label}, suggéré par vos préférences'
          : definition.label,
      button: true,
      selected: isSelected,
      child: OutlinedButton(
        key: ValueKey('standing-view-${definition.view.name}'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected ? color : context.textColors.secondary,
          backgroundColor: isSelected
              ? color.withValues(alpha: 0.13)
              : AppColors.transparent,
          side: BorderSide(
            color: definition.isPersonalized || isSelected
                ? color.withValues(alpha: 0.78)
                : context.surfaces.border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          visualDensity: VisualDensity.compact,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (definition.isPersonalized) ...[
              Icon(Icons.auto_awesome_rounded, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            Text(
              definition.label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingUnifiedLegend extends StatelessWidget {
  const _StandingUnifiedLegend({
    required this.officialZones,
    required this.tiers,
    required this.hasTierSnapshot,
    required this.hasOfficialZones,
    required this.tiersAreProvisional,
  });

  final List<_OfficialStandingLegendItem> officialZones;
  final List<TierLabel> tiers;
  final bool hasTierSnapshot;
  final bool hasOfficialZones;
  final bool tiersAreProvisional;

  @override
  Widget build(BuildContext context) {
    final orderedTiers = [...tiers]
      ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lecture du classement',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            _StandingLegendSection(
              icon: Icons.emoji_events_outlined,
              title: 'Enjeux officiels',
              emptyLabel: hasOfficialZones
                  ? null
                  : 'Aucune zone officielle disponible.',
              children: [
                for (final zone in officialZones)
                  _OfficialStandingLegendChip(zone: zone),
              ],
            ),
            const SizedBox(height: 9),
            Divider(height: 1, color: context.surfaces.border),
            const SizedBox(height: 9),
            _StandingLegendSection(
              icon: Icons.bar_chart_rounded,
              title: tiersAreProvisional
                  ? 'Tiers Lector · provisoires'
                  : 'Tiers Lector',
              emptyLabel: hasTierSnapshot
                  ? null
                  : 'Tiers non calculables pour ce classement.',
              children: [
                for (final tier in orderedTiers)
                  _TierLegendItem(
                    color: _tierBandColor(context, tier),
                    label: _tierLegendLabel(tier),
                  ),
              ],
            ),
            if (hasTierSnapshot || hasOfficialZones) ...[
              const SizedBox(height: 9),
              Text(
                'Numéro coloré : enjeu officiel · bande T1–T5 : Tier Lector',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (tiersAreProvisional) ...[
              const SizedBox(height: 7),
              Text(
                'Échantillon encore court : les tiers sont affichés, mais '
                'restent exclus des décisions automatiques.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.semantic.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StandingLegendSection extends StatelessWidget {
  const _StandingLegendSection({
    required this.icon,
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String? emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: context.brand.accent),
            const SizedBox(width: 7),
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        if (emptyLabel != null)
          Text(
            emptyLabel!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.textColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Wrap(spacing: 12, runSpacing: 8, children: children),
      ],
    );
  }
}

class _StandingMatchSummary extends StatelessWidget {
  const _StandingMatchSummary({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _StandingTeamSummary(
            team: match.homeTeam,
            standing: match.analysis.homeStanding,
            alignRight: false,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: _ContextDeltaPill(
            primary: _rankGapLabel(match),
            secondary: _pointsGapLabel(match),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StandingTeamSummary(
            team: match.awayTeam,
            standing: match.analysis.awayStanding,
            alignRight: true,
          ),
        ),
      ],
    );
  }
}

class _StandingTeamSummary extends StatelessWidget {
  const _StandingTeamSummary({
    required this.team,
    required this.standing,
    required this.alignRight,
  });

  final TeamInfo team;
  final TeamStandingSnapshot? standing;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return Row(
      textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
      children: [
        SportsAssetBadge(
          size: 32,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          backgroundColor: AppColors.transparent,
          padding: 1,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: alignRight
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: alignRight ? TextAlign.right : TextAlign.left,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 1),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _rankLabel(standing),
                      style: TextStyle(color: brand.accent),
                    ),
                    TextSpan(
                      text: ' · ${_pointsLabel(standing)}',
                      style: TextStyle(color: textColors.primary),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: alignRight ? TextAlign.right : TextAlign.left,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              _StandingRecordLine(standing: standing, alignRight: alignRight),
            ],
          ),
        ),
      ],
    );
  }
}

class _StandingRecordLine extends StatelessWidget {
  const _StandingRecordLine({required this.standing, required this.alignRight});

  final TeamStandingSnapshot? standing;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'V',
            style: TextStyle(color: brand.accent),
          ),
          TextSpan(
            text: ' · ',
            style: TextStyle(color: textColors.secondary),
          ),
          TextSpan(
            text: 'N',
            style: TextStyle(color: textColors.secondary),
          ),
          TextSpan(
            text: ' · ',
            style: TextStyle(color: textColors.secondary),
          ),
          TextSpan(
            text: 'D',
            style: TextStyle(color: context.semantic.error),
          ),
          TextSpan(
            text:
                '\n${standing?.wins ?? '-'} · ${standing?.draws ?? '-'} · ${standing?.losses ?? '-'}',
            style: TextStyle(color: textColors.primary),
          ),
        ],
      ),
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: theme.textTheme.labelSmall?.copyWith(
        height: 1.25,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StandingTableHeaderTitle extends StatelessWidget {
  const _StandingTableHeaderTitle({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return Row(
      children: [
        Icon(Icons.emoji_events_outlined, color: brand.accent, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'TOP 10 - ${match.competition.name.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileStandingTable extends StatelessWidget {
  const _MobileStandingTable({
    required this.match,
    required this.standings,
    required this.tierSnapshot,
    this.showOfficialZones = true,
    this.lastColumnLabel = 'Pts',
  });

  final MatchBoardItem match;
  final List<TeamStandingSnapshot> standings;
  final ChampionshipTierSnapshot? tierSnapshot;
  final bool showOfficialZones;
  final String lastColumnLabel;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final groups = _standingTierGroups(standings, tierSnapshot);
    final hasTierBands = groups.any((group) => group.tier != null);
    final leadingWidth = hasTierBands ? _standingTierBandWidth : 0.0;
    return ClipRRect(
      key: const ValueKey('mobile-standing-table'),
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaces.surfaceHover.withValues(alpha: 0.22),
          border: Border.all(color: surfaces.border),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: Column(
                children: [
                  _MobileStandingRow.header(
                    lastColumnLabel: lastColumnLabel,
                    leadingWidth: leadingWidth,
                  ),
                  for (final entry in groups.indexed)
                    _StandingTierGroupSection(
                      match: match,
                      group: entry.$2,
                      showOfficialZones: showOfficialZones,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

const _standingTierBandWidth = 24.0;
const _standingRowHorizontalPadding = 2.0;

class _StandingTierGroupData {
  const _StandingTierGroupData({required this.tier, required this.rows});

  final TierLabel? tier;
  final List<TeamStandingSnapshot> rows;
}

List<_StandingTierGroupData> _standingTierGroups(
  List<TeamStandingSnapshot> standings,
  ChampionshipTierSnapshot? snapshot,
) {
  final groups = <_StandingTierGroupData>[];
  for (final standing in standings) {
    final tier = snapshot?.assignmentForTeam(standing.teamId)?.assignedTier;
    if (groups.isEmpty || groups.last.tier != tier) {
      groups.add(_StandingTierGroupData(tier: tier, rows: [standing]));
    } else {
      groups.last.rows.add(standing);
    }
  }
  return groups;
}

class _StandingTierGroupSection extends StatelessWidget {
  const _StandingTierGroupSection({
    required this.match,
    required this.group,
    required this.showOfficialZones,
  });

  final MatchBoardItem match;
  final _StandingTierGroupData group;
  final bool showOfficialZones;

  @override
  Widget build(BuildContext context) {
    final tier = group.tier;
    final tierColor = tier == null ? null : _tierBandColor(context, tier);
    final tierCode = tier == null ? null : _tierCode(tier);
    final tierSemanticLabel = tier == null ? null : _tierDisplayLabel(tier);
    final rows = Column(
      children: [
        for (final standing in group.rows)
          _MobileStandingRow(
            standing: standing,
            team: _standingTeam(match, standing),
            highlight: _standingHighlight(match, standing),
            tierLabel: tierSemanticLabel,
            officialZone: showOfficialZones
                ? _officialStandingZone(standing)
                : null,
          ),
      ],
    );

    // Without a tier snapshot there is no reason to reserve a left rail.
    // When a tier exists, overlay the compact rail so it is sized by the
    // actual rows rather than increasing the group's height.
    if (group.tier == null) {
      return rows;
    }
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: _standingTierBandWidth),
          child: rows,
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _standingTierBandWidth,
          child: _StandingTierBand(color: tierColor, label: tierCode),
        ),
      ],
    );
  }
}

class _StandingTierBand extends StatelessWidget {
  const _StandingTierBand({required this.color, required this.label});

  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final borderColor = context.surfaces.border;
    return Container(
      width: _standingTierBandWidth,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color ?? borderColor, width: 5),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.7)),
        ),
      ),
      alignment: Alignment.center,
      child: label == null
          ? const SizedBox.shrink()
          : Text(
              label!,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class _MobileStandingRow extends StatelessWidget {
  const _MobileStandingRow({
    required this.standing,
    required this.team,
    required this.highlight,
    required this.tierLabel,
    required this.officialZone,
    this.lastColumnLabel = 'Pts',
    this.leadingWidth = 0,
  }) : isHeader = false;

  const _MobileStandingRow.header({
    this.lastColumnLabel = 'Pts',
    this.leadingWidth = 0,
  }) : standing = null,
       team = null,
       highlight = _StandingHighlight.none,
       tierLabel = null,
       officialZone = null,
       isHeader = true;

  final TeamStandingSnapshot? standing;
  final TeamInfo? team;
  final _StandingHighlight highlight;
  final String? tierLabel;
  final _OfficialStandingZone? officialZone;
  final bool isHeader;
  final String lastColumnLabel;
  final double leadingWidth;

  @override
  Widget build(BuildContext context) {
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    final rowColor = AppColors.transparent;
    final borderColor = surfaces.border;
    final textColor = isHeader ? textColors.secondary : textColors.primary;
    final officialColor = officialZone?.color(context);
    final rankColor = isHeader ? textColor : officialColor ?? textColor;
    final highlightColor = switch (highlight) {
      _StandingHighlight.home => context.brand.accent,
      _StandingHighlight.away => context.strategies.violetStyle.color,
      _StandingHighlight.none => null,
    };

    if (isHeader) {
      return _MobileStandingRowShell(
        backgroundColor: rowColor,
        borderColor: borderColor,
        tierRailColor: null,
        highlightColor: null,
        child: _StandingTableCells.header(
          color: textColor,
          lastColumnLabel: lastColumnLabel,
          leadingWidth: leadingWidth,
        ),
      );
    }

    final row = standing!;
    return _MobileStandingRowShell(
      backgroundColor: rowColor,
      borderColor: borderColor,
      tierRailColor: null,
      highlightColor: highlightColor,
      child: Row(
        children: [
          _StandingRankCell(
            rank: _intValue(row.rank),
            width: 20,
            color: rankColor,
            tierLabel: tierLabel,
            officialZone: officialZone,
          ),
          Expanded(
            child: _StandingTeamCell(
              team: team,
              teamId: row.teamId,
              teamName: row.teamName,
              highlight: highlight,
              textColor: textColor,
            ),
          ),
          _StandingTableCell(
            _intValue(row.played),
            width: 23,
            color: textColor,
          ),
          _StandingTableCell(_intValue(row.wins), width: 22, color: textColor),
          _StandingTableCell(_intValue(row.draws), width: 22, color: textColor),
          _StandingTableCell(
            _intValue(row.losses),
            width: 22,
            color: textColor,
          ),
          _StandingTableCell(
            _intValue(row.goalsFor),
            width: 25,
            color: textColor,
          ),
          _StandingTableCell(
            _intValue(row.goalsAgainst),
            width: 25,
            color: textColor,
          ),
          _StandingTableCell(
            _signedValue(row.goalDiff),
            width: 31,
            color: _goalDiffColor(context, row.goalDiff),
          ),
          _StandingTableCell(
            row.metricValue == null
                ? _intValue(row.points)
                : row.metricValue!.toStringAsFixed(2),
            width: 28,
            color: textColor,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _StandingRankCell extends StatelessWidget {
  const _StandingRankCell({
    required this.rank,
    required this.width,
    required this.color,
    required this.tierLabel,
    required this.officialZone,
  });

  final String rank;
  final double width;
  final Color color;
  final String? tierLabel;
  final _OfficialStandingZone? officialZone;

  @override
  Widget build(BuildContext context) {
    final officialLabel = officialZone?.label;
    return Semantics(
      excludeSemantics: true,
      label: [
        'Position $rank',
        ...tierLabel == null ? const <String>[] : [tierLabel],
        ...officialLabel == null ? const <String>[] : [officialLabel],
      ].join(', '),
      child: SizedBox(
        width: width,
        child: Text(
          rank,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StandingTeamCell extends StatelessWidget {
  const _StandingTeamCell({
    required this.team,
    required this.teamId,
    required this.teamName,
    required this.highlight,
    required this.textColor,
  });

  final TeamInfo? team;
  final int teamId;
  final String teamName;
  final _StandingHighlight highlight;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final highlightColor = switch (highlight) {
      _StandingHighlight.home => context.brand.accent,
      _StandingHighlight.away => context.strategies.violetStyle.color,
      _StandingHighlight.none => null,
    };
    final content = Row(
      children: [
        SportsAssetBadge(
          size: 18,
          imageUrl:
              team?.logoUrl ??
              'https://media.api-sports.io/football/teams/$teamId.png',
          fallbackLabel: teamName,
          backgroundColor: AppColors.transparent,
          padding: 1,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: highlight == _StandingHighlight.none
                  ? FontWeight.w700
                  : FontWeight.w900,
            ),
          ),
        ),
        if (highlightColor != null)
          _StandingMatchSidePill(
            label: highlight == _StandingHighlight.home ? 'DOM.' : 'EXT.',
            color: highlightColor,
          ),
      ],
    );

    return content;
  }
}

class _StandingMatchSidePill extends StatelessWidget {
  const _StandingMatchSidePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StandingTableCells extends StatelessWidget {
  const _StandingTableCells.header({
    required this.color,
    this.lastColumnLabel = 'Pts',
    this.leadingWidth = 0,
  });

  final Color color;
  final String lastColumnLabel;
  final double leadingWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: leadingWidth),
        _StandingTableCell('#', width: 20, color: color, isHeader: true),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Équipe',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        _StandingTableCell('J', width: 23, color: color, isHeader: true),
        _StandingTableCell('V', width: 22, color: color, isHeader: true),
        _StandingTableCell('N', width: 22, color: color, isHeader: true),
        _StandingTableCell('D', width: 22, color: color, isHeader: true),
        _StandingTableCell('BP', width: 25, color: color, isHeader: true),
        _StandingTableCell('BC', width: 25, color: color, isHeader: true),
        _StandingTableCell('Diff', width: 31, color: color, isHeader: true),
        _StandingTableCell(
          lastColumnLabel,
          width: 28,
          color: color,
          isHeader: true,
        ),
      ],
    );
  }
}

class _TierLegendItem extends StatelessWidget {
  const _TierLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OfficialStandingZone {
  const _OfficialStandingZone({required this.label, required this.kind});

  final String label;
  final _OfficialStandingZoneKind kind;

  Color color(BuildContext context) {
    return switch (kind) {
      _OfficialStandingZoneKind.championsLeague =>
        context.strategies.violetStyle.color,
      _OfficialStandingZoneKind.europaLeague =>
        context.strategies.amberStyle.color,
      _OfficialStandingZoneKind.conferenceLeague =>
        context.strategies.blueStyle.color,
      _OfficialStandingZoneKind.promotion =>
        context.strategies.greenStyle.color,
      _OfficialStandingZoneKind.relegation => context.semantic.error,
      _OfficialStandingZoneKind.playoff => context.semantic.warning,
      _OfficialStandingZoneKind.other => context.semantic.info,
    };
  }
}

enum _OfficialStandingZoneKind {
  championsLeague,
  europaLeague,
  conferenceLeague,
  promotion,
  relegation,
  playoff,
  other,
}

_OfficialStandingZone? _officialStandingZone(TeamStandingSnapshot standing) {
  final description = standing.description?.trim();
  if (description == null || description.isEmpty) {
    return null;
  }
  final normalized = description.toLowerCase();
  final kind = normalized.contains('champions league')
      ? _OfficialStandingZoneKind.championsLeague
      : normalized.contains('europa league')
      ? _OfficialStandingZoneKind.europaLeague
      : normalized.contains('conference league')
      ? _OfficialStandingZoneKind.conferenceLeague
      : normalized.contains('relegation')
      ? normalized.contains('playoff')
            ? _OfficialStandingZoneKind.playoff
            : _OfficialStandingZoneKind.relegation
      : normalized.contains('promotion')
      ? _OfficialStandingZoneKind.promotion
      : normalized.contains('playoff')
      ? _OfficialStandingZoneKind.playoff
      : _OfficialStandingZoneKind.other;
  return _OfficialStandingZone(label: description, kind: kind);
}

class _OfficialStandingLegendItem {
  const _OfficialStandingLegendItem({required this.zone, required this.ranks});

  final _OfficialStandingZone zone;
  final List<int> ranks;

  String get rankLabel => _standingRankRangeLabel(ranks);
}

List<_OfficialStandingLegendItem> _officialStandingLegendItems(
  List<TeamStandingSnapshot> standings,
) {
  final zonesByLabel = <String, _OfficialStandingLegendItem>{};
  for (final standing in standings) {
    final zone = _officialStandingZone(standing);
    final rank = standing.rank;
    if (zone == null || rank == null) {
      continue;
    }
    final existing = zonesByLabel[zone.label];
    if (existing == null) {
      zonesByLabel[zone.label] = _OfficialStandingLegendItem(
        zone: zone,
        ranks: [rank],
      );
    } else {
      existing.ranks.add(rank);
    }
  }
  final zones = zonesByLabel.values.toList()
    ..sort((a, b) => a.ranks.first.compareTo(b.ranks.first));
  return zones;
}

String _standingRankRangeLabel(List<int> ranks) {
  final ordered = [...ranks]..sort();
  if (ordered.length == 1) {
    return ordered.single.toString();
  }
  final contiguous = ordered.last - ordered.first + 1 == ordered.length;
  return contiguous ? '${ordered.first}–${ordered.last}' : ordered.join(', ');
}

class _OfficialStandingLegendChip extends StatelessWidget {
  const _OfficialStandingLegendChip({required this.zone});

  final _OfficialStandingLegendItem zone;

  @override
  Widget build(BuildContext context) {
    final color = zone.zone.color(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.tight),
            border: Border.all(color: color),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              zone.rankLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 154),
          child: Text(
            zone.zone.label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.textColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

Color _tierBandColor(BuildContext context, TierLabel tier) {
  final progress = (tier.ordinal - 1) / 4;
  return Color.lerp(
        context.brand.accent,
        context.strategies.violetStyle.color,
        progress,
      ) ??
      context.brand.accent;
}

String _tierCode(TierLabel tier) => 'T${tier.ordinal}';

String _tierLegendLabel(TierLabel tier) {
  return switch (tier) {
    TierLabel.tier1Podium => 'T1 · Podium',
    TierLabel.tier2UpperChampionship => 'T2 · Haut de tableau',
    TierLabel.tier3MiddleChampionship => 'T3 · Milieu de tableau',
    TierLabel.tier4LowerChampionship => 'T4 · Bas de tableau',
    TierLabel.tier5Relegation => 'T5 · Relégation',
  };
}

String _tierDisplayLabel(TierLabel tier) {
  return switch (tier) {
    TierLabel.tier1Podium => 'Tier 1 - Podium',
    TierLabel.tier2UpperChampionship => 'Tier 2 - Haut de tableau',
    TierLabel.tier3MiddleChampionship => 'Tier 3 - Milieu de tableau',
    TierLabel.tier4LowerChampionship => 'Tier 4 - Bas de tableau',
    TierLabel.tier5Relegation => 'Tier 5 - Relégation',
  };
}

class _MobileStandingRowShell extends StatelessWidget {
  const _MobileStandingRowShell({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    required this.tierRailColor,
    required this.highlightColor,
    this.isTierBoundary = false,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final Color? tierRailColor;
  final Color? highlightColor;
  final bool isTierBoundary;

  @override
  Widget build(BuildContext context) {
    final highlight = highlightColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight == null
            ? backgroundColor
            : highlight.withValues(alpha: 0.055),
        border: Border(
          left: highlight != null
              ? BorderSide(color: highlight, width: 2)
              : tierRailColor == null
              ? BorderSide.none
              : BorderSide(color: tierRailColor!, width: 3),
          top: highlight != null
              ? BorderSide(color: highlight, width: 2)
              : isTierBoundary
              ? BorderSide(color: tierRailColor ?? borderColor, width: 2)
              : BorderSide.none,
          right: highlight == null
              ? BorderSide.none
              : BorderSide(color: highlight, width: 2),
          bottom: highlight != null
              ? BorderSide(color: highlight, width: 2)
              : BorderSide(color: borderColor.withValues(alpha: 0.7)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _standingRowHorizontalPadding,
          vertical: 5,
        ),
        child: child,
      ),
    );
  }
}

class _StandingTableCell extends StatelessWidget {
  const _StandingTableCell(
    this.value, {
    required this.width,
    required this.color,
    this.isHeader = false,
    this.bold = false,
    this.alignment = Alignment.center,
  });

  final String value;
  final double width;
  final Color color;
  final bool isHeader;
  final bool bold;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Align(
        alignment: alignment,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: isHeader || bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StandingFormDots extends StatelessWidget {
  const _StandingFormDots({required this.results});

  final List<String> results;

  @override
  Widget build(BuildContext context) {
    final values = results.isEmpty ? const ['-', '-', '-', '-', '-'] : results;
    final textColors = context.textColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final result in values.take(5)) ...[
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _formDotColor(context, result),
              borderRadius: BorderRadius.circular(AppRadius.tight),
            ),
            child: Text(
              _standingFormDotLabel(result),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 3),
        ],
      ],
    );
  }
}

class _StandingInsightStrip extends StatelessWidget {
  const _StandingInsightStrip({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 430;
    final children = [
      _StandingInsightItem(
        icon: Icons.emoji_events_rounded,
        title: 'Course au titre',
        text: _titleRaceText(match),
      ),
      _StandingInsightItem(
        icon: Icons.trending_up_rounded,
        title: 'Dynamique générale',
        text: _standingDynamicText(match),
      ),
      _StandingInsightItem(
        icon: Icons.info_outline_rounded,
        title: 'Lecture Lector',
        text: _standingReadingText(match),
      ),
    ];

    if (compact) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Expanded(child: children[index]),
          if (index < children.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _StandingInsightItem extends StatelessWidget {
  const _StandingInsightItem({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(AppRadius.odds),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: brand.accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppRadius.tight),
            ),
            child: Icon(icon, color: brand.accent, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColors.secondary,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
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

class _LectorFormContextCard extends StatelessWidget {
  const _LectorFormContextCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final homeMatches = match.analysis.homeRecentLeagueMatches.take(5).toList();
    final awayMatches = match.analysis.awayRecentLeagueMatches.take(5).toList();
    final homeResults = _lectorFormResults(
      recentMatches: homeMatches,
      fallbackForm:
          match.analysis.homeStatistics?.form ??
          match.analysis.homeStanding?.form,
    );
    final awayResults = _lectorFormResults(
      recentMatches: awayMatches,
      fallbackForm:
          match.analysis.awayStatistics?.form ??
          match.analysis.awayStanding?.form,
    );
    final homeStats = _FormWindowStats.from(
      recentMatches: homeMatches,
      fallbackResults: homeResults,
    );
    final awayStats = _FormWindowStats.from(
      recentMatches: awayMatches,
      fallbackResults: awayResults,
    );

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LectorFormHeading(),
          const SizedBox(height: 12),
          _LectorFormDuelSummary(
            match: match,
            homeResults: homeResults,
            awayResults: awayResults,
            homeStats: homeStats,
            awayStats: awayStats,
          ),
          const SizedBox(height: 14),
          _LectorFormEvolutionSection(
            match: match,
            homeResults: homeResults,
            awayResults: awayResults,
          ),
          const SizedBox(height: 14),
          _LectorRecentFormSection(
            match: match,
            homeMatches: homeMatches,
            awayMatches: awayMatches,
            homeResults: homeResults,
            awayResults: awayResults,
          ),
          const SizedBox(height: 12),
          _LectorFormTakeaway(
            text: _lectorFormTakeawayText(
              match: match,
              homeStats: homeStats,
              awayStats: awayStats,
            ),
          ),
        ],
      ),
    );
  }
}

class _LectorFormHeading extends StatelessWidget {
  const _LectorFormHeading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.trending_up_rounded, color: brand.accent, size: 23),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FORME RÉCENTE',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Les 5 derniers résultats disponibles.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColors.secondary,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LectorFormDuelSummary extends StatelessWidget {
  const _LectorFormDuelSummary({
    required this.match,
    required this.homeResults,
    required this.awayResults,
    required this.homeStats,
    required this.awayStats,
  });

  final MatchBoardItem match;
  final List<String> homeResults;
  final List<String> awayResults;
  final _FormWindowStats homeStats;
  final _FormWindowStats awayStats;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final homeCard = _LectorFormTeamCard(
      team: match.homeTeam,
      results: homeResults,
      stats: homeStats,
    );
    final awayCard = _LectorFormTeamCard(
      team: match.awayTeam,
      results: awayResults,
      stats: awayStats,
      alignEnd: true,
    );
    final delta = _LectorFormDeltaPill(
      homeStats: homeStats,
      awayStats: awayStats,
    );

    if (compact) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: homeCard),
              const SizedBox(width: 10),
              delta,
            ],
          ),
          const SizedBox(height: 10),
          awayCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: homeCard),
        const SizedBox(width: 10),
        delta,
        const SizedBox(width: 10),
        Expanded(child: awayCard),
      ],
    );
  }
}

class _LectorFormTeamCard extends StatelessWidget {
  const _LectorFormTeamCard({
    required this.team,
    required this.results,
    required this.stats,
    this.alignEnd = false,
  });

  final TeamInfo team;
  final List<String> results;
  final _FormWindowStats stats;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.78)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: alignEnd
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: alignEnd
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (!alignEnd) ...[
                  SportsAssetBadge(
                    size: 27,
                    imageUrl: team.logoUrl,
                    fallbackLabel: team.name,
                    backgroundColor: AppColors.transparent,
                    padding: 1,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (alignEnd) ...[
                  const SizedBox(width: 8),
                  SportsAssetBadge(
                    size: 27,
                    imageUrl: team.logoUrl,
                    fallbackLabel: team.name,
                    backgroundColor: AppColors.transparent,
                    padding: 1,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 9),
            _LectorFormDotsRow(results: results, alignEnd: alignEnd),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: stats.hasResults ? '${stats.points}' : '-',
                    style: TextStyle(
                      color: _formPerformanceColor(context, results),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: ' / 15 pts',
                    style: TextStyle(
                      color: textColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _LectorFormDeltaPill extends StatelessWidget {
  const _LectorFormDeltaPill({
    required this.homeStats,
    required this.awayStats,
  });

  final _FormWindowStats homeStats;
  final _FormWindowStats awayStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;
    final gap = homeStats.hasResults && awayStats.hasResults
        ? (homeStats.points - awayStats.points).abs()
        : null;

    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            gap == null ? 'Écart' : '+$gap pts',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: gap == null || gap == 0
                  ? textColors.secondary
                  : context.semantic.success,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'forme',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LectorFormDotsRow extends StatelessWidget {
  const _LectorFormDotsRow({required this.results, this.alignEnd = false});

  final List<String> results;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final values = results.isEmpty ? const ['-', '-', '-', '-', '-'] : results;

    return Wrap(
      alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
      spacing: 5,
      runSpacing: 4,
      children: [
        for (final result in values.take(5))
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _formDotColor(context, result),
            ),
            child: Text(
              _lectorFormResultLabel(result),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _LectorFormEvolutionSection extends StatelessWidget {
  const _LectorFormEvolutionSection({
    required this.match,
    required this.homeResults,
    required this.awayResults,
  });

  final MatchBoardItem match;
  final List<String> homeResults;
  final List<String> awayResults;

  @override
  Widget build(BuildContext context) {
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LectorSubsectionTitle(
          icon: Icons.show_chart_rounded,
          title: 'ÉVOLUTION SUR LES 5 DERNIERS MATCHS',
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 390;
            if (stack) {
              return Column(
                children: [
                  _LectorFormChartCard(
                    teamName: match.homeTeam.name,
                    results: homeResults,
                    color: _formPerformanceColor(context, homeResults),
                  ),
                  const SizedBox(height: 8),
                  _LectorFormChartCard(
                    teamName: match.awayTeam.name,
                    results: awayResults,
                    color: _formPerformanceColor(context, awayResults),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _LectorFormChartCard(
                    teamName: match.homeTeam.name,
                    results: homeResults,
                    color: _formPerformanceColor(context, homeResults),
                  ),
                ),
                Container(
                  width: 1,
                  height: 92,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: surfaces.border,
                ),
                Expanded(
                  child: _LectorFormChartCard(
                    teamName: match.awayTeam.name,
                    results: awayResults,
                    color: _formPerformanceColor(context, awayResults),
                  ),
                ),
              ],
            );
          },
        ),
        if (homeResults.isEmpty || awayResults.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Certaines séries sont incomplètes dans le snapshot actuel.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

class _LectorSubsectionTitle extends StatelessWidget {
  const _LectorSubsectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return Row(
      children: [
        Icon(icon, color: brand.accent, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _LectorFormChartCard extends StatelessWidget {
  const _LectorFormChartCard({
    required this.teamName,
    required this.results,
    required this.color,
  });

  final String teamName;
  final List<String> results;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 78,
          width: double.infinity,
          child: CustomPaint(
            painter: _LectorFormChartPainter(
              values: _formChartValues(results),
              color: color,
              gridColor: context.surfaces.border,
              textColor: textColors.secondary,
              pointTextColor: textColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _LectorFormChartPainter extends CustomPainter {
  const _LectorFormChartPainter({
    required this.values,
    required this.color,
    required this.gridColor,
    required this.textColor,
    required this.pointTextColor,
  });

  final List<int> values;
  final Color color;
  final Color gridColor;
  final Color textColor;
  final Color pointTextColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(24, 8, size.width - 28, size.height - 24);
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.72)
      ..strokeWidth = 1;
    for (final yValue in [0, 2, 4]) {
      final y = chart.bottom - (yValue / 4) * chart.height;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _paintChartText(canvas, '$yValue', Offset(2, y - 7), textColor);
    }

    final axisPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.82)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chart.left, chart.top),
      Offset(chart.left, chart.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      axisPaint,
    );

    final displayValues = values.isEmpty
        ? const [0, 0, 0, 0, 0]
        : values.take(5).toList();
    final step = displayValues.length <= 1
        ? 0.0
        : chart.width / (displayValues.length - 1);
    final points = <Offset>[
      for (var index = 0; index < displayValues.length; index++)
        Offset(
          chart.left + step * index,
          chart.bottom - (displayValues[index] / 4) * chart.height,
        ),
    ];

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..color = color;
    for (var index = 0; index < points.length; index++) {
      canvas.drawCircle(points[index], 4.2, dotPaint);
      _paintChartText(
        canvas,
        '${displayValues[index]}',
        Offset(points[index].dx - 4, points[index].dy - 19),
        pointTextColor,
        weight: FontWeight.w900,
      );
      _paintChartText(
        canvas,
        'J-${displayValues.length - index}',
        Offset(points[index].dx - 10, chart.bottom + 5),
        textColor,
      );
    }
  }

  void _paintChartText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    FontWeight weight = FontWeight.w700,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LectorFormChartPainter oldDelegate) {
    return values != oldDelegate.values ||
        color != oldDelegate.color ||
        gridColor != oldDelegate.gridColor ||
        textColor != oldDelegate.textColor ||
        pointTextColor != oldDelegate.pointTextColor;
  }
}

class _LectorRecentFormSection extends StatelessWidget {
  const _LectorRecentFormSection({
    required this.match,
    required this.homeMatches,
    required this.awayMatches,
    required this.homeResults,
    required this.awayResults,
  });

  final MatchBoardItem match;
  final List<TeamRecentMatchSnapshot> homeMatches;
  final List<TeamRecentMatchSnapshot> awayMatches;
  final List<String> homeResults;
  final List<String> awayResults;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LectorSubsectionTitle(
          icon: Icons.calendar_month_rounded,
          title: 'DERNIERS MATCHS',
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 390;
            if (stack) {
              return Column(
                children: [
                  _LectorCompactRecentFormList(
                    teamName: match.homeTeam.name,
                    matches: homeMatches,
                    fallbackResults: homeResults,
                  ),
                  const SizedBox(height: 8),
                  _LectorCompactRecentFormList(
                    teamName: match.awayTeam.name,
                    matches: awayMatches,
                    fallbackResults: awayResults,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LectorCompactRecentFormList(
                    teamName: match.homeTeam.name,
                    matches: homeMatches,
                    fallbackResults: homeResults,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LectorCompactRecentFormList(
                    teamName: match.awayTeam.name,
                    matches: awayMatches,
                    fallbackResults: awayResults,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LectorCompactRecentFormList extends StatelessWidget {
  const _LectorCompactRecentFormList({
    required this.teamName,
    required this.matches,
    required this.fallbackResults,
  });

  final String teamName;
  final List<TeamRecentMatchSnapshot> matches;
  final List<String> fallbackResults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: textColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: surfaces.surfaceHover.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: surfaces.border.withValues(alpha: 0.75)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Column(
              children: [
                if (matches.isNotEmpty)
                  for (var index = 0; index < matches.take(5).length; index++)
                    _LectorCompactRecentFormRow(
                      match: matches[index],
                      showDivider: index < matches.take(5).length - 1,
                    )
                else
                  for (
                    var index = 0;
                    index < fallbackResults.take(5).length;
                    index++
                  )
                    _LectorFallbackFormRow(
                      result: fallbackResults[index],
                      index: index,
                      showDivider: index < fallbackResults.take(5).length - 1,
                    ),
                if (matches.isEmpty && fallbackResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(9),
                    child: Text(
                      'Résultats indisponibles.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textColors.secondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LectorCompactRecentFormRow extends StatelessWidget {
  const _LectorCompactRecentFormRow({
    required this.match,
    required this.showDivider,
  });

  final TeamRecentMatchSnapshot match;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: surfaces.border.withValues(alpha: 0.62),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                match.venue == RecentMatchVenue.home ? 'Dom.' : 'Ext.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.secondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SportsAssetBadge(
              size: 19,
              imageUrl: match.opponentLogoUrl,
              fallbackLabel: match.opponentName,
              backgroundColor: AppColors.transparent,
              padding: 1,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                match.opponentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _recentScoreLabel(match),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 5),
            _LectorTinyResultBadge(result: match.result),
          ],
        ),
      ),
    );
  }
}

class _LectorFallbackFormRow extends StatelessWidget {
  const _LectorFallbackFormRow({
    required this.result,
    required this.index,
    required this.showDivider,
  });

  final String result;
  final int index;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final textColors = context.textColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: surfaces.border.withValues(alpha: 0.62),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Match J-${5 - index}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _LectorTinyResultBadge(result: result),
          ],
        ),
      ),
    );
  }
}

class _LectorTinyResultBadge extends StatelessWidget {
  const _LectorTinyResultBadge({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    final color = _formDotColor(context, result);

    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Text(
        _lectorFormResultLabel(result),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.textColors.primary,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LectorFormTakeaway extends StatelessWidget {
  const _LectorFormTakeaway({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;
    final accent = context.opportunities.levelGap;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 19, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'À RETENIR',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColors.secondary,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
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

class _LectorInfoContextCard extends StatelessWidget {
  const _LectorInfoContextCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    return _LectorInfoCard(
      title: 'Infos',
      rows: [
        _LectorInfoRow(
          icon: Icons.stadium_outlined,
          label: 'Stade',
          trailing: [TextSpan(text: _venueValue(match.fixture.venue))],
        ),
        _LectorInfoRow(
          icon: Icons.schedule_rounded,
          label: 'Horaire',
          trailing: [TextSpan(text: _matchDateTimeLabel(match))],
        ),
      ],
    );
  }
}

class _LectorInfoCard extends StatelessWidget {
  const _LectorInfoCard({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index < rows.length - 1)
              Divider(height: 16, color: surfaces.border),
          ],
        ],
      ),
    );
  }
}

class _LectorInfoRow extends StatelessWidget {
  const _LectorInfoRow({
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final List<TextSpan>? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return Row(
      children: [
        Icon(icon, color: brand.accent, size: 23),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: trailing,
              style: theme.textTheme.titleSmall?.copyWith(
                color: brand.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _FormDots extends StatelessWidget {
  const _FormDots({required this.results});

  final List<String> results;

  @override
  Widget build(BuildContext context) {
    final values = results.isEmpty ? const ['-', '-', '-', '-', '-'] : results;
    final textColors = context.textColors;

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 5,
      runSpacing: 4,
      children: [
        for (final result in values.take(5))
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _formDotColor(context, result),
            ),
            child: Text(
              _formDotLabel(result),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _LectorRecentMatchesCard extends StatelessWidget {
  const _LectorRecentMatchesCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final rows = _recentRows(match).take(3).toList();
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final surfaces = context.surfaces;

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Derniers matchs',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              'Les derniers matchs seront affichés dès que les données sont disponibles.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColors.secondary,
              ),
            )
          else
            for (var index = 0; index < rows.length; index++) ...[
              _RecentMatchLine(row: rows[index]),
              if (index < rows.length - 1)
                Divider(height: 14, color: surfaces.border),
            ],
        ],
      ),
    );
  }
}

class _RecentMatchLine extends StatelessWidget {
  const _RecentMatchLine({required this.row});

  final _RecentMatchUiRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;

    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            row.meta,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SportsAssetBadge(
          size: 23,
          imageUrl: row.teamLogoUrl,
          fallbackLabel: row.teamName,
          backgroundColor: AppColors.transparent,
          padding: 1,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            row.teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          row.score,
          style: theme.textTheme.titleSmall?.copyWith(
            color: textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            row.opponentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: theme.textTheme.titleSmall?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SportsAssetBadge(
          size: 23,
          imageUrl: row.opponentLogoUrl,
          fallbackLabel: row.opponentName,
          backgroundColor: AppColors.transparent,
          padding: 1,
        ),
      ],
    );
  }
}

class _LectorFollowCard extends StatelessWidget {
  const _LectorFollowCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    final brand = context.brand;

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suivre',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _FollowActionRow(
            icon: Icons.notifications_none_rounded,
            label: 'Alerte coup d’envoi',
            onTap: () => _showComingSoon(context, 'Alerte à brancher'),
          ),
          Divider(height: 12, color: surfaces.border),
          _FollowActionRow(
            icon: Icons.star_border_rounded,
            label: 'Favori',
            trailing: Icon(Icons.star_rounded, color: brand.accent, size: 25),
            onTap: () => _showComingSoon(context, 'Favori à brancher'),
          ),
          Divider(height: 12, color: surfaces.border),
          _FollowActionRow(
            icon: Icons.groups_2_outlined,
            label: 'Composition disponible',
            onTap: () => _showComingSoon(context, 'Compositions à brancher'),
          ),
        ],
      ),
    );
  }
}

class _FollowActionRow extends StatelessWidget {
  const _FollowActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: brand.accent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: textColors.primary,
                  size: 23,
                ),
          ],
        ),
      ),
    );
  }
}

class _LectorGlassCard extends StatelessWidget {
  const _LectorGlassCard({
    required this.child,
    required this.padding,
    this.backgroundAsset,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? backgroundAsset;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final radius = BorderRadius.circular(AppRadius.control);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: surfaces.shadow.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: surfaces.border.withValues(alpha: 0.92)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: surfaces.surface.withValues(alpha: 0.72)),
          ),
          if (backgroundAsset != null) ...[
            Positioned.fill(
              child: Image.asset(
                backgroundAsset!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      surfaces.shadow.withValues(alpha: 0.18),
                      surfaces.shadow.withValues(alpha: 0.52),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _RecentMatchUiRow {
  const _RecentMatchUiRow({
    required this.meta,
    required this.teamName,
    required this.opponentName,
    required this.score,
    this.teamLogoUrl,
    this.opponentLogoUrl,
  });

  final String meta;
  final String teamName;
  final String opponentName;
  final String score;
  final String? teamLogoUrl;
  final String? opponentLogoUrl;
}

void _showComingSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void _showScenarioReadingsSheet(
  BuildContext context,
  MatchBoardItem match, {
  Opportunity? opportunity,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.transparent,
    barrierColor: context.surfaces.scrim.withValues(alpha: 0.56),
    builder: (context) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: _ScenarioReadingsSheet(match: match, opportunity: opportunity),
      );
    },
  );
}

class _ScenarioReadingsSheet extends StatefulWidget {
  const _ScenarioReadingsSheet({
    required this.match,
    required this.opportunity,
  });

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  State<_ScenarioReadingsSheet> createState() => _ScenarioReadingsSheetState();
}

class _ScenarioReadingsSheetState extends State<_ScenarioReadingsSheet> {
  late final _ScenarioSheetContent _content;

  @override
  void initState() {
    super.initState();
    _content = _scenarioSheetContentFor(widget.match, widget.opportunity);
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            color: surfaces.shadow.withValues(alpha: 0.38),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.textColors.secondary.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            child: _ScenarioSheetOverviewHeader(
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              children: [
                if (_content.scenarios.isNotEmpty) ...[
                  _ScenarioSheetSectionHeading(
                    title: _content.scenarios.length == 1
                        ? 'Scénario retenu'
                        : 'Scénarios retenus',
                    color: _scenarioAccent(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final scenario in _content.scenarios) ...[
                    _ScenarioOverviewCard(
                      match: widget.match,
                      scenario: scenario,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
                if (_content.independentReadings.isNotEmpty) ...[
                  _ScenarioSheetSectionHeading(
                    title: 'Autres lectures du match',
                    subtitle:
                        'Lectures actives qui ne composent pas les scénarios ci-dessus',
                    color: context.brand.accent,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final group in _content.independentReadingGroups) ...[
                    _ScenarioTeamReadingsCard(
                      key: ValueKey(
                        'scenario-independent-${group.subjectTeamId ?? 'match'}',
                      ),
                      match: widget.match,
                      group: group,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
                if (_content.vigilances.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _ScenarioSheetSectionHeading(
                    title: _content.vigilances.length == 1
                        ? 'Point de vigilance'
                        : 'Points de vigilance',
                    color: context.semantic.warning,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final vigilance in _content.vigilances) ...[
                    _ScenarioVigilanceCard(
                      key: ValueKey(
                        'scenario-vigilance-${vigilance.readingId ?? vigilance.title}',
                      ),
                      match: widget.match,
                      item: vigilance,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
                if (_content.limits.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _ScenarioLimitsSection(limits: _content.limits),
                ],
                if (_content.isEmpty)
                  _ScenarioNoReadingsCard(match: widget.match),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioSheetOverviewHeader extends StatelessWidget {
  const _ScenarioSheetOverviewHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.brand.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.odds),
            border: Border.all(
              color: context.brand.accent.withValues(alpha: 0.42),
            ),
          ),
          child: SizedBox.square(
            dimension: 42,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: context.brand.accent,
              size: 23,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ANALYSE LECTOR',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.brand.accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pourquoi ce match est proposé',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Fermer',
          onPressed: onClose,
          icon: Icon(
            Icons.close_rounded,
            color: context.textColors.primary,
            size: 24,
          ),
        ),
      ],
    );
  }
}

class _ScenarioSheetSectionHeading extends StatelessWidget {
  const _ScenarioSheetSectionHeading({
    required this.title,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: subtitle == null ? 23 : 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScenarioOverviewCard extends StatelessWidget {
  const _ScenarioOverviewCard({required this.match, required this.scenario});

  final MatchBoardItem match;
  final _ScenarioReading scenario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _scenarioAccent(context);
    final identity = context.opportunities.scenarioIdentityForProfileId(
      _scenarioProfileId(scenario.id),
    );
    final featuredTeam = _teamForScenario(match, scenario);
    final subjectLabel = featuredTeam == null
        ? 'Lecture sur la rencontre'
        : 'Équipe mise en avant';
    final summary = scenario.summary?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: accent.withValues(alpha: 0.82)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: SizedBox.square(
                    dimension: 34,
                    child: Icon(identity.icon, color: accent, size: 20),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    scenario.title.toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (featuredTeam != null) ...[
              Row(
                children: [
                  SportsAssetBadge(
                    size: 54,
                    imageUrl: featuredTeam.logoUrl,
                    fallbackLabel: featuredTeam.name,
                    borderRadius: 27,
                    backgroundColor: AppColors.transparent,
                    contrastPlate: true,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          featuredTeam.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: context.textColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _ScenarioImpactPill(
                          label: subjectLabel,
                          color: context.brand.accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (summary != null && summary.isNotEmpty)
              Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.textColors.primary,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (scenario.supports.isNotEmpty) ...[
              Divider(height: 22, color: accent.withValues(alpha: 0.34)),
              Text(
                'Lectures qui composent ce scénario · ${scenario.supports.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              for (final indexed in scenario.supports.indexed) ...[
                _ScenarioCompositionRow(item: indexed.$2, accent: accent),
                if (indexed.$1 < scenario.supports.length - 1)
                  Divider(
                    height: 15,
                    color: context.surfaces.border.withValues(alpha: 0.72),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioCompositionRow extends StatelessWidget {
  const _ScenarioCompositionRow({required this.item, required this.accent});

  final _ScenarioEvidenceDetail item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final identity = item.readingId == null
        ? null
        : context.opportunities.readingIdentityForId(item.readingId!);
    final color = identity?.color ?? context.brand.accent;
    final description = item.description?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: SizedBox.square(
            dimension: 30,
            child: Icon(
              identity?.icon ?? Icons.check_circle_outline_rounded,
              color: color,
              size: 17,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (description != null && description.isNotEmpty)
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScenarioTeamReadingsCard extends StatelessWidget {
  const _ScenarioTeamReadingsCard({
    required this.match,
    required this.group,
    super.key,
  });

  final MatchBoardItem match;
  final _ScenarioReadingGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final team = _teamForSubject(match, group.subjectTeamId);
    final title = team?.name ?? 'La rencontre';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (team != null) ...[
              SportsAssetBadge(
                size: 46,
                imageUrl: team.logoUrl,
                fallbackLabel: team.name,
                borderRadius: 23,
                backgroundColor: AppColors.transparent,
                contrastPlate: true,
              ),
              const SizedBox(width: AppSpacing.sm),
            ] else ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.brand.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: SizedBox.square(
                  dimension: 42,
                  child: Icon(
                    Icons.sports_soccer_rounded,
                    color: context.brand.accent,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final indexed in group.readings.indexed) ...[
                    _ScenarioIndependentReadingRow(reading: indexed.$2),
                    if (indexed.$1 < group.readings.length - 1)
                      Divider(
                        height: 14,
                        color: context.surfaces.border.withValues(alpha: 0.72),
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

class _ScenarioIndependentReadingRow extends StatelessWidget {
  const _ScenarioIndependentReadingRow({required this.reading});

  final _ScenarioReading reading;

  @override
  Widget build(BuildContext context) {
    final identity = context.opportunities.readingIdentityForId(reading.id);
    final summary = reading.summary?.trim();
    final fallback = reading.supports.firstOrNull?.description?.trim();
    final description = summary?.isNotEmpty == true ? summary : fallback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (reading.supports.firstOrNull?.playerPhotoUrl
                case final photo?) ...[
              SportsAssetBadge(
                size: 27,
                imageUrl: photo,
                fallbackLabel:
                    reading.supports.firstOrNull?.playerName ?? reading.title,
                borderRadius: 14,
                backgroundColor: AppColors.transparent,
                contrastPlate: true,
              ),
              const SizedBox(width: 7),
            ] else ...[
              Icon(identity.icon, color: identity.color, size: 17),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                reading.supports.firstOrNull?.playerName != null &&
                        reading.id == 'standout_decisive_player'
                    ? '${reading.supports.first.playerName} à surveiller'
                    : reading.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: identity.color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _ScenarioVigilanceCard extends StatelessWidget {
  const _ScenarioVigilanceCard({
    required this.match,
    required this.item,
    super.key,
  });

  final MatchBoardItem match;
  final _ScenarioEvidenceDetail item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = context.semantic.warning;
    final team = _teamForEvidence(match, item);
    final description = item.description?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (team != null)
              SportsAssetBadge(
                size: 44,
                imageUrl: team.logoUrl,
                fallbackLabel: team.name,
                borderRadius: 22,
                backgroundColor: AppColors.transparent,
                contrastPlate: true,
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: SizedBox.square(
                  dimension: 42,
                  child: Icon(Icons.warning_amber_rounded, color: color),
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textColors.primary,
                        height: 1.28,
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

class _ScenarioReadingHeader extends StatelessWidget {
  const _ScenarioReadingHeader({required this.reading, required this.onClose});

  final _ScenarioReading reading;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = context.opportunities.readingIdentityForId(reading.id);
    final badge = context.opportunities.badgeFor(
      reading.id,
      variant: AppReadingBadgeVariant.soft,
    );
    final accent = badge.foreground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.odds),
                border: Border.all(color: accent.withValues(alpha: 0.46)),
              ),
              child: SizedBox.square(
                dimension: 42,
                child: Icon(identity.icon, color: accent, size: 23),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LECTURE LECTOR',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reading.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      height: 1.12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Fermer',
              onPressed: onClose,
              icon: Icon(
                Icons.close_rounded,
                color: context.textColors.primary,
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _ScenarioReadingMeta(reading: reading, accent: accent),
        if (reading.summary != null) ...[
          const SizedBox(height: AppSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: accent, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reading.summary!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ScenarioReadingMeta extends StatelessWidget {
  const _ScenarioReadingMeta({required this.reading, required this.accent});

  final _ScenarioReading reading;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 5,
      children: [
        _ScenarioImpactPill(label: reading.category, color: accent),
        if (reading.strength != null)
          _ScenarioImpactPill(
            label: _scenarioReadingStrengthLabel(reading.strength!),
            color: accent,
          ),
      ],
    );
  }
}

class _ScenarioEvidenceSection extends StatelessWidget {
  const _ScenarioEvidenceSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.color,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<_ScenarioEvidenceDetail> items;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScenarioEvidenceSectionHeader(
              icon: icon,
              title: title,
              subtitle: subtitle,
              color: color,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final indexed in items.indexed) ...[
              _ScenarioEvidenceRow(
                item: indexed.$2,
                color: color,
                icon: Icons.arrow_upward_rounded,
                useReadingIdentity: true,
              ),
              if (indexed.$1 < items.length - 1) const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioCounterEvidenceSection extends StatelessWidget {
  const _ScenarioCounterEvidenceSection({
    required this.resistances,
    required this.contradictions,
  });

  final List<_ScenarioEvidenceDetail> resistances;
  final List<_ScenarioEvidenceDetail> contradictions;

  @override
  Widget build(BuildContext context) {
    final contradictionColor = Theme.of(context).colorScheme.error;
    final count = resistances.length + contradictions.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: contradictionColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: contradictionColor.withValues(alpha: 0.58)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScenarioEvidenceSectionHeader(
              icon: Icons.shield_outlined,
              title: 'Points de vigilance',
              subtitle:
                  '$count ${count == 1 ? 'élément à considérer' : 'éléments à considérer'}',
              color: contradictionColor,
            ),
            if (resistances.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _ScenarioEvidenceSubsection(
                title: 'À nuancer (${resistances.length})',
                items: resistances,
                color: context.semantic.warning,
                icon: Icons.balance_rounded,
              ),
            ],
            if (resistances.isNotEmpty && contradictions.isNotEmpty)
              Divider(
                height: 18,
                color: context.surfaces.border.withValues(alpha: 0.78),
              ),
            if (contradictions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _ScenarioEvidenceSubsection(
                title: 'Signaux contraires (${contradictions.length})',
                items: contradictions,
                color: contradictionColor,
                icon: Icons.south_east_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioEvidenceSubsection extends StatelessWidget {
  const _ScenarioEvidenceSubsection({
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  });

  final String title;
  final List<_ScenarioEvidenceDetail> items;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        for (final indexed in items.indexed) ...[
          _ScenarioEvidenceRow(item: indexed.$2, color: color, icon: icon),
          if (indexed.$1 < items.length - 1) const SizedBox(height: 7),
        ],
      ],
    );
  }
}

class _ScenarioEmptyEvidenceLine extends StatelessWidget {
  const _ScenarioEmptyEvidenceLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: context.textColors.secondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioNoCounterEvidenceCard extends StatelessWidget {
  const _ScenarioNoCounterEvidenceCard();

  @override
  Widget build(BuildContext context) {
    final color = context.textColors.secondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: SizedBox.square(
                dimension: 30,
                child: Icon(
                  Icons.verified_user_outlined,
                  color: color,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aucun signal contraire détecté',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Aucune résistance explicite dans les données analysées.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textColors.secondary,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
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

class _ScenarioEvidenceRow extends StatelessWidget {
  const _ScenarioEvidenceRow({
    required this.item,
    required this.color,
    required this.icon,
    this.useReadingIdentity = false,
  });

  final _ScenarioEvidenceDetail item;
  final Color color;
  final IconData icon;
  final bool useReadingIdentity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = item.title;
    final description = item.description;
    final strengthLabel = item.strengthLabel;
    final contextLabel = item.contextLabel;
    final readingId = item.readingId;
    final readingIdentity = readingId == null
        ? null
        : context.opportunities.readingIdentityForId(readingId);
    final itemColor = useReadingIdentity && readingIdentity != null
        ? readingIdentity.color
        : color;
    final itemIcon = useReadingIdentity && readingIdentity != null
        ? readingIdentity.icon
        : icon;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.surfaces.surface.withValues(alpha: 0.68),
          border: Border.all(color: context.surfaces.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 3, height: 74, color: itemColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: itemColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: SizedBox.square(
                        dimension: 28,
                        child: Icon(itemIcon, color: itemColor, size: 16),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: context.textColors.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (strengthLabel != null) ...[
                                const SizedBox(width: 8),
                                _ScenarioImpactPill(
                                  label: strengthLabel,
                                  color: itemColor,
                                ),
                              ],
                            ],
                          ),
                          if (contextLabel != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              contextLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: itemColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          if (description != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.textColors.secondary,
                                fontSize: 11,
                                height: 1.28,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioLimitsSection extends StatelessWidget {
  const _ScenarioLimitsSection({required this.limits});

  final List<ThesisEvidence> limits;

  @override
  Widget build(BuildContext context) {
    final color = context.semantic.warning;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScenarioEvidenceSectionHeader(
              icon: Icons.info_outline_rounded,
              title: 'Limites de la lecture (${limits.length})',
              subtitle: 'Informations à considérer',
              color: color,
            ),
            const SizedBox(height: 8),
            for (final indexed in limits.indexed) ...[
              _ScenarioLimitRow(index: indexed.$1 + 1, limit: indexed.$2),
              if (indexed.$1 < limits.length - 1)
                Divider(
                  height: 16,
                  color: context.surfaces.border.withValues(alpha: 0.78),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioLimitRow extends StatelessWidget {
  const _ScenarioLimitRow({required this.index, required this.limit});

  final int index;
  final ThesisEvidence limit;

  @override
  Widget build(BuildContext context) {
    final color = context.semantic.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index.',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            limit.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.primary,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScenarioEvidenceSectionHeader extends StatelessWidget {
  const _ScenarioEvidenceSectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScenarioSheetReadingCard extends StatelessWidget {
  const _ScenarioSheetReadingCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.description,
    required this.impactLabel,
    required this.impactColor,
    required this.child,
  });

  final int index;
  final IconData icon;
  final String title;
  final String description;
  final String impactLabel;
  final Color impactColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final surfaces = context.surfaces;
    final textColors = context.textColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surfaceHover.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.92)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 27,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: brand.accent.withValues(alpha: 0.82),
                    ),
                  ),
                  child: Text(
                    '$index',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: brand.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Icon(icon, color: brand.accent, size: 27),
              ],
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: textColors.primary,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ScenarioImpactPill(
                        label: impactLabel,
                        color: impactColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColors.secondary,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioImpactPill extends StatelessWidget {
  const _ScenarioImpactPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ScenarioArgumentEvidence extends StatelessWidget {
  const _ScenarioArgumentEvidence({required this.argument});

  final CopilotArgument argument;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final items = argument.evidence.isEmpty
        ? [ThesisEvidence(label: argument.id, tone: ThesisEvidenceTone.neutral)]
        : argument.evidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final evidence in items.take(3)) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: _scenarioToneColor(context, evidence.tone),
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  evidence.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColors.primary,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _ScenarioNoReadingsCard extends StatelessWidget {
  const _ScenarioNoReadingsCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(
          color: context.surfaces.border.withValues(alpha: 0.92),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Text(
          match.signals.isEmpty
              ? 'Aucune lecture moteur détaillée disponible pour cette rencontre.'
              : match.signals.first.summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: textColors.secondary,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _ScenarioStandingEvidence extends StatelessWidget {
  const _ScenarioStandingEvidence({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScenarioStandingTeam(
            team: match.homeTeam,
            standing: match.analysis.homeStanding,
          ),
        ),
        const SizedBox(width: 8),
        _ScenarioCentralMetric(
          primary: _rankGapLabel(match),
          secondary: _pointsGapLabel(match),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScenarioStandingTeam(
            team: match.awayTeam,
            standing: match.analysis.awayStanding,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _ScenarioStandingTeam extends StatelessWidget {
  const _ScenarioStandingTeam({
    required this.team,
    required this.standing,
    this.alignEnd = false,
  });

  final TeamInfo team;
  final TeamStandingSnapshot? standing;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final brand = context.brand;

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        SportsAssetBadge(
          size: 31,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          backgroundColor: AppColors.transparent,
          padding: 1,
        ),
        const SizedBox(height: 5),
        Text(
          _rankLabel(standing),
          style: theme.textTheme.titleSmall?.copyWith(
            color: textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          _pointsLabel(standing),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: brand.accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ScenarioCentralMetric extends StatelessWidget {
  const _ScenarioCentralMetric({
    required this.primary,
    required this.secondary,
    this.icon,
  });

  final String primary;
  final String secondary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;
    final brand = context.brand;

    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: surfaces.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.84)),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, color: brand.accent, size: 18),
            const SizedBox(height: 3),
          ],
          Text(
            primary,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: brand.accent,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            secondary,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioFormEvidence extends StatelessWidget {
  const _ScenarioFormEvidence({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final homeResults = _lectorFormResults(
      recentMatches: match.analysis.homeRecentLeagueMatches.take(5).toList(),
      fallbackForm:
          match.analysis.homeStatistics?.form ??
          match.analysis.homeStanding?.form,
    );
    final awayResults = _lectorFormResults(
      recentMatches: match.analysis.awayRecentLeagueMatches.take(5).toList(),
      fallbackForm:
          match.analysis.awayStatistics?.form ??
          match.analysis.awayStanding?.form,
    );

    return Row(
      children: [
        Expanded(
          child: _ScenarioFormSide(
            team: match.homeTeam,
            results: homeResults,
            color: context.brand.accent,
          ),
        ),
        const SizedBox(width: 8),
        _ScenarioCentralMetric(
          primary: _formGapLabel(homeResults, awayResults),
          secondary: 'sur les 5 derniers matchs',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScenarioFormSide(
            team: match.awayTeam,
            results: awayResults,
            color: context.opportunities.levelGap,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _ScenarioFormSide extends StatelessWidget {
  const _ScenarioFormSide({
    required this.team,
    required this.results,
    required this.color,
    this.alignEnd = false,
  });

  final TeamInfo team;
  final List<String> results;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final points = _formPoints(results);

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            SportsAssetBadge(
              size: 28,
              imageUrl: team.logoUrl,
              fallbackLabel: team.name,
              backgroundColor: AppColors.transparent,
              padding: 1,
            ),
          ],
        ),
        const SizedBox(height: 7),
        _ScenarioFormDots(results: results, alignEnd: alignEnd),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: results.isEmpty ? '-' : '$points',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
              TextSpan(
                text: ' / 15 pts',
                style: TextStyle(
                  color: textColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }
}

class _ScenarioFormDots extends StatelessWidget {
  const _ScenarioFormDots({required this.results, this.alignEnd = false});

  final List<String> results;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final values = results.isEmpty ? const ['-', '-', '-', '-', '-'] : results;

    return Wrap(
      alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final result in values.take(5))
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _formDotColor(context, result),
            ),
            child: Text(
              _lectorFormResultLabel(result),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.primary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _ScenarioHomeAwayEvidence extends StatelessWidget {
  const _ScenarioHomeAwayEvidence({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final homeStats = match.analysis.homeStatistics;
    final awayStats = match.analysis.awayStatistics;

    return Row(
      children: [
        Expanded(
          child: _ScenarioHomeAwaySide(
            title: '${match.homeTeam.name} à domicile',
            wins: homeStats?.winsHome,
            draws: homeStats?.drawsHome,
            losses: homeStats?.lossesHome,
            played: homeStats?.playedHome,
          ),
        ),
        const SizedBox(width: 8),
        _ScenarioCentralMetric(
          primary: _homeAwayGapLabel(match),
          secondary: 'dom. / ext.',
          icon: Icons.bar_chart_rounded,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScenarioHomeAwaySide(
            title: '${match.awayTeam.name} à l’extérieur',
            wins: awayStats?.winsAway,
            draws: awayStats?.drawsAway,
            losses: awayStats?.lossesAway,
            played: awayStats?.playedAway,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _ScenarioHomeAwaySide extends StatelessWidget {
  const _ScenarioHomeAwaySide({
    required this.title,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.played,
    this.alignEnd = false,
  });

  final String title;
  final int? wins;
  final int? draws;
  final int? losses;
  final int? played;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;
    final semantic = context.semantic;

    TextSpan metric(String value, Color color) {
      return TextSpan(
        text: value,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      );
    }

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColors.secondary,
            fontSize: 10,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              metric('${_intValue(wins)} V', semantic.success),
              TextSpan(
                text: '  ',
                style: TextStyle(color: textColors.secondary),
              ),
              metric('${_intValue(draws)} N', textColors.secondary),
              TextSpan(
                text: '  ',
                style: TextStyle(color: textColors.secondary),
              ),
              metric('${_intValue(losses)} D', semantic.error),
            ],
          ),
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          _winPercentLabel(wins, played),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.brand.accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ScenarioVigilanceSection extends StatelessWidget {
  const _ScenarioVigilanceSection({
    required this.arguments,
    required this.limits,
  });

  final List<CopilotArgument> arguments;
  final List<ThesisEvidence> limits;

  @override
  Widget build(BuildContext context) {
    final color = context.semantic.warning;
    final hasVigilance = arguments.isNotEmpty || limits.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: color.withValues(alpha: 0.54)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScenarioEvidenceSectionHeader(
              icon: Icons.warning_amber_rounded,
              title: 'Ce qui la contredit ou la tempère',
              subtitle: hasVigilance
                  ? 'Points à prendre en compte'
                  : 'Aucun élément contradictoire explicite disponible',
              color: color,
            ),
            if (hasVigilance) ...[
              const SizedBox(height: 10),
              for (final argument in arguments) ...[
                _ScenarioVigilanceLine(
                  label: _scenarioArgumentDescription(argument),
                  icon: _scenarioArgumentIcon(argument),
                ),
                const SizedBox(height: 8),
              ],
              for (final limit in limits) ...[
                _ScenarioVigilanceLine(
                  label: limit.label,
                  icon: Icons.remove_circle_outline_rounded,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioVigilanceLine extends StatelessWidget {
  const _ScenarioVigilanceLine({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.semantic.warning, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.primary,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScenarioReadingLine extends StatelessWidget {
  const _ScenarioReadingLine({
    required this.index,
    required this.label,
    required this.color,
  });

  final int? index;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColors = context.textColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: index == null
              ? Icon(Icons.shield_outlined, color: color, size: 14)
              : Text(
                  '$index',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColors.primary,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

String _matchDateTimeLabel(MatchBoardItem match) {
  final label = match.fixture.kickoffLabel.trim();
  return label.isEmpty ? 'Aujourd’hui' : 'Aujourd’hui · $label';
}

String _venueValue(FixtureVenue? venue) {
  if (venue == null) {
    return 'Stade à confirmer';
  }
  final name = venue.name?.trim();
  final city = venue.city?.trim();
  return [
    if (name != null && name.isNotEmpty) name,
    if (city != null && city.isNotEmpty) city,
  ].join(' · ');
}

String _rankLabel(TeamStandingSnapshot? standing) {
  final rank = standing?.rank;
  if (rank == null) {
    return '-';
  }
  return '${rank}e';
}

String _standingSummary(TeamStandingSnapshot? standing) {
  if (standing == null) {
    return 'Donnée indisponible';
  }
  final rank = standing.rank == null ? '-' : '${standing.rank}e';
  final points = standing.points == null ? '-' : '${standing.points} pts';
  return '$rank · $points';
}

String _firstSignalTitle(MatchBoardItem match) {
  if (match.signals.isNotEmpty) {
    final signal = match.signals.first;
    return switch (signal.id) {
      'ranking_superiority' => 'Écart au classement',
      'structural_level_gap' => 'Écart de niveau structurel',
      'balanced_hierarchy' => 'Hiérarchie proche',
      _ => signal.title,
    };
  }
  return 'Lecture disponible';
}

String _scenarioTitle(MatchBoardItem match) {
  final title = match.thesis?.title.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  return _firstSignalTitle(match);
}

String _scenarioSummary(MatchBoardItem match) {
  final summary = match.thesis?.summary.trim();
  if (summary != null && summary.isNotEmpty) {
    return summary;
  }
  if (match.signals.isNotEmpty && match.signals.first.summary.isNotEmpty) {
    return match.signals.first.summary;
  }
  return 'Les premiers éléments disponibles donnent une lecture rapide de cette rencontre.';
}

int _scenarioReadingCount(MatchBoardItem match) {
  final arguments = _scenarioArguments(match);
  if (arguments.isNotEmpty) {
    return arguments.length.clamp(1, 6).toInt();
  }
  return 1;
}

bool _hasScenarioRecommendedPick(RecommendedMarket? recommendedMarket) {
  final selection = recommendedMarket?.selection;
  if (selection == null) {
    return false;
  }

  return selection.odds.isFinite && selection.odds > 0;
}

RecommendedMarket? _scenarioRecommendedMarket(
  MatchBoardItem match,
  Opportunity? opportunity,
) {
  return _recommendedMarketForDetail(match, opportunity);
}

/// Production matches carry personalized [BetCandidate]s. The Opportunity
/// fallback only keeps historic/detail fixtures renderable while no candidate
/// data exists; it never overrides an ambiguous or rejected candidate set.
RecommendedMarket? _recommendedMarketForDetail(
  MatchBoardItem match,
  Opportunity? opportunity,
) {
  final fromCandidate = match.recommendedMarketFor(match.suggestedBetCandidate);
  if (_hasScenarioRecommendedPick(fromCandidate)) {
    return fromCandidate;
  }
  if (match.betCandidates.isNotEmpty ||
      opportunity?.isAutomaticallyUsable != true) {
    return null;
  }
  final fromOpportunity = opportunity?.recommendedMarket;
  return _hasScenarioRecommendedPick(fromOpportunity) ? fromOpportunity : null;
}

String? _fixtureRoundLabel(String? rawRound) {
  final round = rawRound?.trim();
  if (round == null || round.isEmpty) {
    return null;
  }

  final match = RegExp(
    r'^(?:regular\s+season\s*-\s*)?(\d+)$',
    caseSensitive: false,
  ).firstMatch(round);
  final number = match?.group(1);
  return number == null ? null : 'Journée $number';
}

String? _scenarioRecommendedPickLabel(
  MatchBoardItem match,
  RecommendedMarket recommendedMarket,
) {
  final market = recommendedMarket.market;
  final selection = recommendedMarket.selection;
  final rawValue = selection.apiFootballValue?.trim().toLowerCase();
  final label = selection.label.trim();
  final normalizedLabel = label.toLowerCase();

  if (market.id == 'matchResult') {
    if (_matchesSelection(rawValue, normalizedLabel, const [
      'home',
      'domicile',
      '1',
    ])) {
      return '${match.homeTeam.name} gagne';
    }
    if (_matchesSelection(rawValue, normalizedLabel, const [
      'draw',
      'nul',
      'x',
    ])) {
      return 'Match nul';
    }
    if (_matchesSelection(rawValue, normalizedLabel, const [
      'away',
      'extérieur',
      'exterieur',
      '2',
    ])) {
      return '${match.awayTeam.name} gagne';
    }
  }

  if (market.id == 'doubleChance') {
    if (_matchesSelection(rawValue, normalizedLabel, const [
      'home/draw',
      'home or draw',
      '1x',
    ])) {
      return '${match.homeTeam.name} ou nul';
    }
    if (_matchesSelection(rawValue, normalizedLabel, const [
      'home/away',
      'home or away',
      '12',
    ])) {
      return '${match.homeTeam.name} ou ${match.awayTeam.name}';
    }
    if (_matchesSelection(rawValue, normalizedLabel, const [
      'draw/away',
      'draw or away',
      'x2',
    ])) {
      return '${match.awayTeam.name} ou nul';
    }
  }

  if (market.id == 'bothTeamsScore') {
    if (_matchesSelection(rawValue, normalizedLabel, const ['yes', 'oui'])) {
      return 'Les deux équipes marquent';
    }
    if (_matchesSelection(rawValue, normalizedLabel, const ['no', 'non'])) {
      return 'Les deux équipes ne marquent pas';
    }
  }

  if (label.isNotEmpty) {
    return label;
  }

  final marketLabel = market.label.trim();
  return marketLabel.isEmpty ? null : marketLabel;
}

bool _matchesSelection(
  String? rawValue,
  String normalizedLabel,
  List<String> expectedValues,
) {
  for (final expected in expectedValues) {
    if (rawValue == expected || normalizedLabel == expected) {
      return true;
    }
  }
  return false;
}

List<ThesisEvidence> _scenarioEvidenceItems(MatchBoardItem match) {
  final thesisEvidence = match.thesis?.supportingEvidence ?? const [];
  if (thesisEvidence.isNotEmpty) {
    return thesisEvidence.take(3).toList();
  }
  if (match.signals.isNotEmpty) {
    return [
      for (final signal in match.signals.take(3))
        ThesisEvidence(label: signal.summary, tone: ThesisEvidenceTone.neutral),
    ];
  }
  return const [
    ThesisEvidence(
      label: 'Les données principales de la rencontre sont disponibles.',
      tone: ThesisEvidenceTone.neutral,
    ),
  ];
}

class _ScenarioSheetContent {
  const _ScenarioSheetContent({
    required this.scenarios,
    required this.independentReadings,
    required this.vigilances,
    required this.limits,
  });

  final List<_ScenarioReading> scenarios;
  final List<_ScenarioReading> independentReadings;
  final List<_ScenarioEvidenceDetail> vigilances;
  final List<ThesisEvidence> limits;

  bool get isEmpty =>
      scenarios.isEmpty &&
      independentReadings.isEmpty &&
      vigilances.isEmpty &&
      limits.isEmpty;

  List<_ScenarioReadingGroup> get independentReadingGroups {
    final groups = <String?, List<_ScenarioReading>>{};
    for (final reading in independentReadings) {
      groups.putIfAbsent(reading.subjectTeamId, () => []).add(reading);
    }
    return [
      for (final entry in groups.entries)
        _ScenarioReadingGroup(
          subjectTeamId: entry.key,
          readings: List.unmodifiable(entry.value),
        ),
    ];
  }
}

class _ScenarioReadingGroup {
  const _ScenarioReadingGroup({
    required this.subjectTeamId,
    required this.readings,
  });

  final String? subjectTeamId;
  final List<_ScenarioReading> readings;
}

_ScenarioSheetContent _scenarioSheetContentFor(
  MatchBoardItem match,
  Opportunity? opportunity,
) {
  final readings = _scenarioReadingsFor(match, opportunity);
  final scenarios = readings
      .where((reading) => reading.isScenario)
      .toList(growable: false);
  final scenarioReadingIds = {
    for (final scenario in scenarios)
      for (final support in scenario.supports)
        if (support.readingId != null) support.readingId!,
  };
  final otherReadings = readings
      .where(
        (reading) =>
            !reading.isScenario && !scenarioReadingIds.contains(reading.id),
      )
      .toList(growable: false);
  final featuredTeamIds = scenarios
      .map((scenario) => _teamForScenario(match, scenario)?.id)
      .whereType<String>()
      .toSet();
  final independentReadings = <_ScenarioReading>[];
  final directVigilances = <_ScenarioEvidenceDetail>[];
  for (final reading in otherReadings) {
    if (_isVigilanceForSelectedScenario(reading, featuredTeamIds)) {
      directVigilances.add(
        _scenarioEvidenceDetailForIndependentReading(reading),
      );
    } else {
      independentReadings.add(reading);
    }
  }
  final vigilanceCandidates = <_ScenarioEvidenceDetail>[
    for (final scenario in scenarios) ...scenario.resistances,
    for (final scenario in scenarios) ...scenario.contradictions,
    ...directVigilances,
  ];
  final vigilanceKeys = <String>{};
  final vigilances = [
    for (final item in vigilanceCandidates)
      if (vigilanceKeys.add(_scenarioEvidenceKey(item))) item,
  ];
  final limits = <ThesisEvidence>[
    for (final scenario in scenarios) ...scenario.limits,
  ];
  return _ScenarioSheetContent(
    scenarios: scenarios,
    independentReadings: independentReadings,
    vigilances: List.unmodifiable(vigilances),
    limits: List.unmodifiable(limits),
  );
}

bool _isVigilanceForSelectedScenario(
  _ScenarioReading reading,
  Set<String> featuredTeamIds,
) {
  if (featuredTeamIds.isEmpty) return false;
  final subjectTeamId = reading.subjectTeamId;
  if (subjectTeamId != null && !featuredTeamIds.contains(subjectTeamId)) {
    return true;
  }
  return subjectTeamId != null &&
      featuredTeamIds.contains(subjectTeamId) &&
      _isNegativeReadingForSubject(reading.id);
}

bool _isNegativeReadingForSubject(String readingId) {
  return switch (readingId) {
    'ranking_inferiority' ||
    'negative_streak' ||
    'declining_form' ||
    'weak_home_team' ||
    'weak_away_team' ||
    'scoring_difficulty' ||
    'fragile_defense' ||
    'low_xg_creation' ||
    'offensive_underperformance' ||
    'high_xg_conceded' ||
    'defensive_underperformance' ||
    'frequent_first_half_conceding' ||
    'frequent_second_half_conceding' ||
    'important_player_absent' => true,
    _ => false,
  };
}

_ScenarioEvidenceDetail _scenarioEvidenceDetailForIndependentReading(
  _ScenarioReading reading,
) {
  final player = reading.supports
      .where((item) => item.playerName != null || item.playerPhotoUrl != null)
      .firstOrNull;
  return _ScenarioEvidenceDetail(
    title: reading.title,
    description: reading.summary ?? reading.supports.firstOrNull?.description,
    readingId: reading.id,
    subjectTeamId: reading.subjectTeamId,
    playerName: player?.playerName,
    playerPhotoUrl: player?.playerPhotoUrl,
  );
}

String _scenarioEvidenceKey(_ScenarioEvidenceDetail item) =>
    '${item.readingId ?? item.title}:${item.subjectTeamId ?? ''}';

Color _scenarioAccent(BuildContext context) =>
    context.opportunities.scenarioIdentityForProfileId('ranking_gap').color;

String _scenarioProfileId(String id) {
  if (id.startsWith('scenario:')) {
    return id.split(':').elementAtOrNull(1) ?? id;
  }
  return id;
}

TeamInfo? _teamForSubject(MatchBoardItem match, String? subjectTeamId) {
  if (subjectTeamId == match.homeTeam.id) return match.homeTeam;
  if (subjectTeamId == match.awayTeam.id) return match.awayTeam;
  return null;
}

TeamInfo? _teamForScenario(MatchBoardItem match, _ScenarioReading scenario) {
  final explicit = _teamForSubject(match, scenario.subjectTeamId);
  if (explicit != null) return explicit;
  for (final item in scenario.supports) {
    final team = _teamForSubject(match, item.subjectTeamId);
    if (team != null) return team;
    final namedTeam =
        _teamNamedIn(match, item.title) ??
        _teamNamedIn(match, item.description ?? '');
    if (namedTeam != null) return namedTeam;
  }
  return _teamNamedIn(match, scenario.title) ??
      _teamNamedIn(match, scenario.summary ?? '');
}

TeamInfo? _teamForEvidence(
  MatchBoardItem match,
  _ScenarioEvidenceDetail item,
) =>
    _teamForSubject(match, item.subjectTeamId) ??
    _teamNamedIn(match, item.title) ??
    _teamNamedIn(match, item.description ?? '');

TeamInfo? _teamNamedIn(MatchBoardItem match, String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains(match.homeTeam.name.toLowerCase())) {
    return match.homeTeam;
  }
  if (normalized.contains(match.awayTeam.name.toLowerCase())) {
    return match.awayTeam;
  }
  return null;
}

class _ScenarioReading {
  const _ScenarioReading({
    required this.id,
    required this.title,
    required this.category,
    required this.supports,
    required this.resistances,
    required this.contradictions,
    required this.limits,
    this.summary,
    this.strength,
    this.subjectTeamId,
    this.isScenario = false,
  });

  final String id;
  final String title;
  final String category;
  final String? summary;
  final ReadingStrength? strength;
  final String? subjectTeamId;
  final bool isScenario;
  final List<_ScenarioEvidenceDetail> supports;
  final List<_ScenarioEvidenceDetail> resistances;
  final List<_ScenarioEvidenceDetail> contradictions;
  final List<ThesisEvidence> limits;
}

class _ScenarioEvidenceDetail {
  const _ScenarioEvidenceDetail({
    required this.title,
    this.description,
    this.strengthLabel,
    this.contextLabel,
    this.readingId,
    this.subjectTeamId,
    this.playerName,
    this.playerPhotoUrl,
  });

  factory _ScenarioEvidenceDetail.fromAssessment(
    ThesisEvidenceAssessment item,
  ) {
    final reading = item.reading;
    if (reading == null) {
      return _ScenarioEvidenceDetail(title: item.label);
    }
    return _ScenarioEvidenceDetail(
      title:
          reading.id == 'standout_decisive_player' && reading.playerName != null
          ? '${reading.playerName} à surveiller'
          : FootballReadingCopyCatalog.titleFor(
              reading.toCopilotArgument(subjectName: ''),
            ),
      description: _scenarioAssessmentDescription(item),
      strengthLabel: _scenarioReadingStrengthLabel(reading.strength),
      readingId: reading.id,
      subjectTeamId: reading.subjectTeamId,
      playerName: reading.playerName,
      playerPhotoUrl: reading.playerPhotoUrl,
      contextLabel: switch (reading.competitionScope) {
        ReadingCompetitionScope.domestic =>
          'Championnat national · ${reading.sourceCompetitionName ?? 'source nationale'}',
        ReadingCompetitionScope.tournament =>
          'Compétition européenne · ${reading.sourceCompetitionName ?? 'tournoi'}',
        ReadingCompetitionScope.combined => 'Lecture croisée',
        ReadingCompetitionScope.matchCompetition => null,
      },
    );
  }

  final String title;
  final String? description;
  final String? strengthLabel;
  final String? contextLabel;
  final String? readingId;
  final String? subjectTeamId;
  final String? playerName;
  final String? playerPhotoUrl;
}

List<_ScenarioReading> _scenarioReadingsFor(
  MatchBoardItem match,
  Opportunity? opportunity,
) {
  final readings = <_ScenarioReading>[];
  final signalsById = <String, MatchSignal>{
    for (final signal in match.signals) signal.id: signal,
    if (opportunity != null)
      for (final signal in opportunity.detectedSignals) signal.id: signal,
  };
  final availableSignals = signalsById.values.toList(growable: false);

  // An opportunity represents the precise scenario selected by the user.
  // Its thesis assessments also contain other possible analyses of the same
  // match, including market context. They must not leak into this detail
  // sheet as if they were sporting evidence for the selected thesis.
  if (opportunity != null) {
    if (opportunity.supportingReadings.isEmpty &&
        opportunity.contradictoryReadings.isEmpty) {
      final selectedAssessment = opportunity.thesisAssessments
          .where(
            (assessment) =>
                assessment.id == opportunity.primaryThesis.id &&
                assessment.isSupported,
          )
          .firstOrNull;
      if (selectedAssessment != null) {
        readings.add(_scenarioReadingFromAssessment(match, selectedAssessment));
      } else {
        readings.add(_scenarioReadingFromOpportunity(match, opportunity));
      }
    } else {
      readings.add(_scenarioReadingFromOpportunity(match, opportunity));
    }
  } else {
    final directSignalsById = {
      for (final signal in availableSignals)
        if (_isDirectReadingSignal(signal)) signal.id: signal,
    };
    for (final scenarioSignal in availableSignals.where(_isScenarioSignal)) {
      readings.add(
        _scenarioReadingFromScenarioSignal(
          scenarioSignal,
          directSignalsById: directSignalsById,
        ),
      );
    }
  }

  // A match may match more than one selected scenario. The primary
  // opportunity above remains the richest source for its own scenario; the
  // remaining scenario signals are rendered in the same vertical sheet.
  final directSignalsById = {
    for (final signal in availableSignals)
      if (_isDirectReadingSignal(signal)) signal.id: signal,
  };
  final renderedScenarioIds = readings
      .where((reading) => reading.isScenario)
      .map((reading) => _scenarioProfileId(reading.id))
      .toSet();
  for (final scenarioSignal in availableSignals.where(_isScenarioSignal)) {
    final scenarioId = _scenarioProfileId(scenarioSignal.id);
    if (!renderedScenarioIds.add(scenarioId)) continue;
    readings.add(
      _scenarioReadingFromScenarioSignal(
        scenarioSignal,
        directSignalsById: directSignalsById,
      ),
    );
  }

  // Direct readings remain visible after scenarios, but the sheet content
  // builder removes the ones already used by a scenario to avoid duplication.
  final selectedSignals = availableSignals
      .where(_isDirectReadingSignal)
      .toList(growable: false);
  readings.addAll(
    selectedSignals.map(
      (signal) => _scenarioReadingForDirectSignal(match, signal),
    ),
  );
  if (readings.isNotEmpty) {
    return List.unmodifiable(readings);
  }

  return const [];
}

bool _isScenarioSignal(MatchSignal signal) => signal.id.startsWith('scenario:');

bool _isDirectReadingSignal(MatchSignal signal) =>
    ReadingPreferenceCatalog.contains(signal.id);

_ScenarioReading _scenarioReadingForDirectSignal(
  MatchBoardItem match,
  MatchSignal signal,
) {
  final argument = _scenarioArgumentForSignal(signal);
  return _ScenarioReading(
    id: signal.id,
    title: signal.title,
    category: _scenarioFamilyLabel(argument.family),
    summary: signal.summary.trim().isEmpty ? null : signal.summary.trim(),
    supports: [_scenarioEvidenceDetailForArgument(argument)],
    resistances: const [],
    contradictions: const [],
    limits: const [],
    subjectTeamId: _subjectTeamIdForSignal(match, signal),
  );
}

_ScenarioReading _scenarioReadingFromScenarioSignal(
  MatchSignal signal, {
  required Map<String, MatchSignal> directSignalsById,
}) {
  final scenarioId = _scenarioProfileId(signal.id);
  final supports = [
    for (final id in signal.proofs)
      if (directSignalsById[id] case final directSignal?)
        _scenarioEvidenceDetailForSignal(directSignal)
      else
        _ScenarioEvidenceDetail(title: id, readingId: id),
  ];
  return _ScenarioReading(
    id: scenarioId,
    title: signal.title,
    category: 'Scénario',
    summary: signal.summary.trim().isEmpty ? null : signal.summary.trim(),
    supports: List.unmodifiable(supports),
    resistances: const [],
    contradictions: const [],
    limits: const [],
    subjectTeamId: signal.subjectTeamId ?? _scenarioSubjectTeamId(signal.id),
    isScenario: true,
  );
}

String? _scenarioSubjectTeamId(String id) {
  final parts = id.split(':');
  return parts.length >= 3 ? parts[2] : null;
}

_ScenarioEvidenceDetail _scenarioEvidenceDetailForSignal(MatchSignal signal) {
  final argument = _scenarioArgumentForSignal(signal);
  return _ScenarioEvidenceDetail(
    title: FootballReadingCopyCatalog.titleFor(argument),
    description: signal.proofs
        .where((proof) => proof.trim().isNotEmpty)
        .join(' '),
    strengthLabel: 'Modéré',
    readingId: signal.id,
    subjectTeamId: signal.subjectTeamId,
  );
}

String? _subjectTeamIdForSignal(MatchBoardItem match, MatchSignal signal) =>
    signal.subjectTeamId ?? _teamNamedIn(match, signal.title)?.id;

bool _isDirectReadingArgument(CopilotArgument argument) {
  return ReadingPreferenceCatalog.contains(
    FootballReadingCopyCatalog.readingIdFor(argument),
  );
}

_ScenarioEvidenceDetail _scenarioEvidenceDetailForArgument(
  CopilotArgument argument,
) {
  final subjectTeamId = argument.parameters['subjectTeamId'];
  return _ScenarioEvidenceDetail(
    title: FootballReadingCopyCatalog.titleFor(argument),
    description: argument.evidence
        .map((evidence) => evidence.label.trim())
        .where((label) => label.isNotEmpty)
        .join(' '),
    strengthLabel: argument.severity == CopilotArgumentSeverity.strong
        ? 'Fort'
        : 'Modéré',
    readingId: FootballReadingCopyCatalog.readingIdFor(argument),
    subjectTeamId: subjectTeamId is String ? subjectTeamId : null,
  );
}

bool _isResistanceToReading(String targetId, CopilotArgument argument) {
  if (!_isDirectReadingArgument(argument) ||
      argument.family == CopilotArgumentFamily.contradiction) {
    return false;
  }
  final readingId = FootballReadingCopyCatalog.readingIdFor(argument);
  return _counterReadingIdsFor(targetId).contains(readingId);
}

Set<String> _counterReadingIdsFor(String readingId) {
  return switch (readingId) {
    'positive_streak' ||
    'improving_form' => {'negative_streak', 'declining_form'},
    'negative_streak' ||
    'declining_form' => {'positive_streak', 'improving_form'},
    'strong_home_team' ||
    'strong_away_team' => {'weak_home_team', 'weak_away_team'},
    'weak_home_team' ||
    'weak_away_team' => {'strong_home_team', 'strong_away_team'},
    'prolific_attack' => {'scoring_difficulty', 'solid_defense'},
    'scoring_difficulty' => {'prolific_attack', 'fragile_defense'},
    'solid_defense' ||
    'frequent_clean_sheet' => {'prolific_attack', 'fragile_defense'},
    'fragile_defense' => {'solid_defense', 'frequent_clean_sheet'},
    'frequent_over_25' => {
      'frequent_under_25',
      'solid_defense',
      'scoring_difficulty',
    },
    'frequent_under_25' => {
      'frequent_over_25',
      'prolific_attack',
      'fragile_defense',
    },
    'frequent_btts' => {'frequent_clean_sheet', 'solid_defense'},
    _ => const {},
  };
}

_ScenarioReading _scenarioReadingFromOpportunity(
  MatchBoardItem match,
  Opportunity opportunity,
) {
  final thesis = opportunity.primaryThesis;
  return _ScenarioReading(
    id: thesis.id,
    title: thesis.title,
    category: _scenarioFamilyLabel(
      thesis.arguments.isEmpty ? null : thesis.arguments.first.family,
    ),
    summary: thesis.summary,
    supports: [
      for (final reading in opportunity.supportingReadings)
        _scenarioEvidenceDetailForReading(reading),
    ],
    resistances: [
      for (final reading in opportunity.resistanceReadings)
        _scenarioEvidenceDetailForReading(reading),
    ],
    contradictions: [
      for (final reading in opportunity.contradictoryReadings)
        _scenarioEvidenceDetailForReading(reading),
    ],
    limits: thesis.limits,
    subjectTeamId: opportunity.supportingReadings
        .map((reading) => reading.subjectTeamId)
        .firstOrNull,
    isScenario: true,
  );
}

_ScenarioEvidenceDetail _scenarioEvidenceDetailForReading(
  FootballReading reading,
) {
  return _ScenarioEvidenceDetail.fromAssessment(
    ThesisEvidenceAssessment(
      relation: ThesisEvidenceRelation.additionalSupport,
      family: CopilotArgumentFamily.performance,
      label: reading.id,
      reading: reading,
    ),
  );
}

_ScenarioReading _scenarioReadingFromAssessment(
  MatchBoardItem match,
  ThesisAssessment assessment,
) {
  final primaryReading = assessment.evidence
      .map((item) => item.reading)
      .whereType<FootballReading>()
      .firstOrNull;
  final teamName = switch (assessment.subjectSide) {
    ReadingSubjectSide.home => match.homeTeam.name,
    ReadingSubjectSide.away => match.awayTeam.name,
    ReadingSubjectSide.match => null,
  };
  final thesisSummary = assessment.id == match.thesis?.id
      ? match.thesis?.summary.trim()
      : null;
  final summary = thesisSummary != null && thesisSummary.isNotEmpty
      ? thesisSummary
      : primaryReading == null
      ? null
      : _scenarioReadingSummary(primaryReading, teamName);

  return _ScenarioReading(
    id: assessment.id,
    title: teamName == null || teamName.isEmpty
        ? assessment.title
        : '${assessment.title} pour $teamName',
    category: _scenarioFamilyLabel(
      assessment.evidence.isEmpty ? null : assessment.evidence.first.family,
    ),
    summary: summary,
    strength: primaryReading?.strength,
    supports: assessment.evidence
        .where(
          (item) =>
              item.relation == ThesisEvidenceRelation.coreSupport ||
              item.relation == ThesisEvidenceRelation.additionalSupport,
        )
        .map(_ScenarioEvidenceDetail.fromAssessment)
        .toList(growable: false),
    resistances: assessment.resistances
        .map(_ScenarioEvidenceDetail.fromAssessment)
        .toList(growable: false),
    contradictions: assessment.contradictions
        .map(_ScenarioEvidenceDetail.fromAssessment)
        .toList(growable: false),
    limits: assessment.id == match.thesis?.id
        ? match.thesis?.limits ?? const []
        : const [],
    subjectTeamId: primaryReading?.subjectTeamId,
    isScenario: true,
  );
}

int _initialScenarioReadingIndex(
  List<_ScenarioReading> readings,
  String? thesisId,
) {
  final index = readings.indexWhere((reading) => reading.id == thesisId);
  return index < 0 ? 0 : index;
}

String _scenarioAssessmentTitle(ThesisEvidenceAssessment item) {
  final reading = item.reading;
  if (reading == null) {
    return item.label;
  }
  return FootballReadingCopyCatalog.titleFor(
    reading.toCopilotArgument(subjectName: ''),
  );
}

String? _scenarioAssessmentDescription(ThesisEvidenceAssessment item) {
  final reading = item.reading;
  if (reading == null) {
    return null;
  }
  final evidence = reading.evidence.firstOrNull;
  final factual = FootballReadingCopyCatalog.factualLineFor(
    reading.toCopilotArgument(subjectName: ''),
  );
  if (factual != null && factual.isNotEmpty) {
    return factual;
  }
  if (evidence != null && evidence.label.trim().isNotEmpty) {
    return evidence.label;
  }
  return item.label;
}

String _scenarioReadingSummary(FootballReading reading, String? subjectName) {
  final factual = FootballReadingCopyCatalog.factualLineFor(
    reading.toCopilotArgument(subjectName: subjectName),
  );
  if (factual != null && factual.isNotEmpty) {
    return factual;
  }
  final evidence = reading.evidence.firstOrNull;
  if (evidence != null && evidence.label.trim().isNotEmpty) {
    return evidence.label;
  }
  return FootballReadingCopyCatalog.summaryFor(
    reading.toCopilotArgument(subjectName: subjectName),
  );
}

String _scenarioFamilyLabel(CopilotArgumentFamily? family) {
  return switch (family) {
    CopilotArgumentFamily.hierarchy => 'Classement',
    CopilotArgumentFamily.performance => 'Performance',
    CopilotArgumentFamily.defense => 'Défense',
    CopilotArgumentFamily.attack => 'Attaque',
    CopilotArgumentFamily.form => 'Forme',
    CopilotArgumentFamily.rhythm => 'Rythme',
    CopilotArgumentFamily.market => 'Marché',
    CopilotArgumentFamily.contradiction => 'Vigilance',
    null => 'Lecture Lector',
  };
}

String _scenarioReadingStrengthLabel(ReadingStrength strength) {
  return switch (strength) {
    ReadingStrength.strong => 'Fort',
    ReadingStrength.moderate => 'Modéré',
    ReadingStrength.weak => 'Faible',
  };
}

List<CopilotArgument> _scenarioArguments(MatchBoardItem match) {
  final arguments = match.thesis?.arguments ?? const <CopilotArgument>[];
  if (arguments.isNotEmpty) {
    return arguments.take(6).toList(growable: false);
  }

  final evidence = match.thesis?.supportingEvidence ?? const <ThesisEvidence>[];
  if (evidence.isNotEmpty) {
    return [
      for (final indexed in evidence.take(6).indexed)
        CopilotArgument(
          id: '${match.fixture.id}_thesis_evidence_${indexed.$1}',
          type: CopilotArgumentType.openMatch,
          family: CopilotArgumentFamily.performance,
          severity: CopilotArgumentSeverity.moderate,
          subjectName: 'La rencontre',
          parameters: const {},
          evidence: [indexed.$2],
          evidenceAction: CopilotEvidenceAction.results,
        ),
    ];
  }

  return [
    for (final signal in match.signals.take(6))
      _scenarioArgumentForSignal(signal),
  ];
}

CopilotArgument _scenarioArgumentForSignal(MatchSignal signal) {
  final evidence = [
    for (final proof in signal.proofs)
      if (proof.trim().isNotEmpty)
        ThesisEvidence(label: proof.trim(), tone: ThesisEvidenceTone.neutral),
  ];
  final fallbackLabel = signal.summary.trim().isNotEmpty
      ? signal.summary.trim()
      : signal.title.trim();

  return CopilotArgument(
    id: 'signal:${signal.id}',
    type: _scenarioArgumentTypeForSignal(signal.id),
    family: _scenarioArgumentFamilyForSignal(signal.id),
    severity: CopilotArgumentSeverity.moderate,
    subjectName: signal.title.trim().isEmpty
        ? 'La rencontre'
        : signal.title.trim(),
    parameters: {
      'readingId': signal.id,
      if (signal.subjectTeamId != null) 'subjectTeamId': signal.subjectTeamId!,
    },
    evidence: evidence.isNotEmpty
        ? evidence.take(3).toList(growable: false)
        : [
            ThesisEvidence(
              label: fallbackLabel.isEmpty ? signal.id : fallbackLabel,
              tone: ThesisEvidenceTone.neutral,
            ),
          ],
    evidenceAction: _scenarioEvidenceActionForSignal(signal.id),
  );
}

CopilotArgumentType _scenarioArgumentTypeForSignal(String signalId) {
  return switch (signalId) {
    'ranking_superiority' ||
    'structural_level_gap' ||
    'balanced_hierarchy' => CopilotArgumentType.rankingGap,
    'positive_streak' ||
    'improving_form' => CopilotArgumentType.strongRecentForm,
    'negative_streak' || 'declining_form' => CopilotArgumentType.weakRecentForm,
    'prolific_attack' ||
    'high_xg_creation' ||
    'offensive_underperformance' ||
    'offensive_overperformance' ||
    'frequent_first_half_scoring' ||
    'frequent_second_half_scoring' => CopilotArgumentType.strongAttack,
    'fragile_defense' ||
    'high_xg_conceded' ||
    'defensive_underperformance' ||
    'frequent_first_half_conceding' ||
    'frequent_second_half_conceding' => CopilotArgumentType.fragileDefense,
    'solid_defense' ||
    'frequent_clean_sheet' ||
    'defensive_overperformance' => CopilotArgumentType.closedMatch,
    'open_match_profile' || 'frequent_over_25' => CopilotArgumentType.openMatch,
    'closed_match_profile' ||
    'frequent_under_25' => CopilotArgumentType.closedMatch,
    _ => CopilotArgumentType.openMatch,
  };
}

CopilotArgumentFamily _scenarioArgumentFamilyForSignal(String signalId) {
  return switch (signalId) {
    'ranking_superiority' ||
    'structural_level_gap' ||
    'balanced_hierarchy' => CopilotArgumentFamily.hierarchy,
    'positive_streak' ||
    'negative_streak' ||
    'improving_form' ||
    'declining_form' => CopilotArgumentFamily.form,
    'prolific_attack' ||
    'scoring_difficulty' ||
    'high_xg_creation' ||
    'low_xg_creation' ||
    'offensive_underperformance' ||
    'offensive_overperformance' ||
    'frequent_first_half_scoring' ||
    'frequent_second_half_scoring' => CopilotArgumentFamily.attack,
    'solid_defense' ||
    'fragile_defense' ||
    'frequent_clean_sheet' ||
    'high_xg_conceded' ||
    'defensive_overperformance' ||
    'defensive_underperformance' ||
    'frequent_first_half_conceding' ||
    'frequent_second_half_conceding' => CopilotArgumentFamily.defense,
    'open_match_profile' ||
    'frequent_over_25' ||
    'closed_match_profile' ||
    'frequent_under_25' => CopilotArgumentFamily.rhythm,
    'post_match_xg_rejected' ||
    'misleading_result' ||
    'conflicting_signals' => CopilotArgumentFamily.contradiction,
    _ => CopilotArgumentFamily.performance,
  };
}

CopilotEvidenceAction _scenarioEvidenceActionForSignal(String signalId) {
  return switch (signalId) {
    'ranking_superiority' ||
    'structural_level_gap' ||
    'balanced_hierarchy' => CopilotEvidenceAction.standings,
    'positive_streak' ||
    'negative_streak' ||
    'improving_form' ||
    'declining_form' => CopilotEvidenceAction.form,
    'prolific_attack' ||
    'scoring_difficulty' ||
    'high_xg_creation' ||
    'low_xg_creation' ||
    'offensive_underperformance' ||
    'offensive_overperformance' ||
    'frequent_first_half_scoring' ||
    'frequent_second_half_scoring' => CopilotEvidenceAction.offensiveStats,
    'solid_defense' ||
    'fragile_defense' ||
    'frequent_clean_sheet' ||
    'high_xg_conceded' ||
    'defensive_overperformance' ||
    'defensive_underperformance' ||
    'frequent_first_half_conceding' ||
    'frequent_second_half_conceding' => CopilotEvidenceAction.defensiveStats,
    'open_match_profile' ||
    'frequent_over_25' ||
    'closed_match_profile' ||
    'frequent_under_25' => CopilotEvidenceAction.rhythm,
    _ => CopilotEvidenceAction.results,
  };
}

String _scenarioArgumentTitle(CopilotArgument argument) {
  final subject = argument.subjectName.trim();
  final family = _scenarioArgumentFamilyLabel(argument.family);
  if (subject.isEmpty || subject == 'La rencontre') {
    return family;
  }
  return '$subject - $family';
}

String _scenarioArgumentDescription(CopilotArgument argument) {
  final evidence = argument.evidence;
  if (evidence.isNotEmpty && evidence.first.label.trim().isNotEmpty) {
    return evidence.first.label;
  }
  return argument.id;
}

String _scenarioArgumentImpactLabel(CopilotArgument argument) {
  if (argument.family == CopilotArgumentFamily.contradiction) {
    return 'Vigilance';
  }
  return argument.severity == CopilotArgumentSeverity.strong
      ? 'Signal fort'
      : 'Signal modéré';
}

Color _scenarioArgumentImpactColor(
  BuildContext context,
  CopilotArgument argument,
) {
  if (argument.family == CopilotArgumentFamily.contradiction) {
    return context.semantic.warning;
  }
  if (argument.family == CopilotArgumentFamily.hierarchy) {
    return context.opportunities.levelGap;
  }
  return context.brand.accent;
}

IconData _scenarioArgumentIcon(CopilotArgument argument) {
  return switch (argument.family) {
    CopilotArgumentFamily.hierarchy => Icons.leaderboard_rounded,
    CopilotArgumentFamily.form => Icons.trending_up_rounded,
    CopilotArgumentFamily.performance => Icons.query_stats_rounded,
    CopilotArgumentFamily.attack => Icons.sports_soccer_rounded,
    CopilotArgumentFamily.defense => Icons.shield_outlined,
    CopilotArgumentFamily.rhythm => Icons.speed_rounded,
    CopilotArgumentFamily.contradiction => Icons.warning_amber_rounded,
    CopilotArgumentFamily.market => Icons.tune_rounded,
  };
}

String _scenarioArgumentFamilyLabel(CopilotArgumentFamily family) {
  return switch (family) {
    CopilotArgumentFamily.hierarchy => 'Hiérarchie',
    CopilotArgumentFamily.form => 'Forme',
    CopilotArgumentFamily.performance => 'Contexte',
    CopilotArgumentFamily.attack => 'Attaque',
    CopilotArgumentFamily.defense => 'Défense',
    CopilotArgumentFamily.rhythm => 'Rythme',
    CopilotArgumentFamily.contradiction => 'Point de vigilance',
    CopilotArgumentFamily.market => 'Marché',
  };
}

Color _scenarioToneColor(BuildContext context, ThesisEvidenceTone tone) {
  return switch (tone) {
    ThesisEvidenceTone.positive => context.semantic.success,
    ThesisEvidenceTone.warning => context.semantic.warning,
    ThesisEvidenceTone.negative => context.semantic.error,
    ThesisEvidenceTone.neutral => context.brand.accent,
  };
}

String _scenarioSheetIntro(MatchBoardItem match) {
  final leader = _standingLeader(match);
  final teamName = leader?.name ?? match.homeTeam.name;
  return 'Pourquoi Lector anticipe une lecture « ${_scenarioTitle(match)} » autour de $teamName.';
}

String _scenarioStructuralDescription(MatchBoardItem match) {
  final leader = _standingLeader(match);
  if (leader == null) {
    return 'Les indicateurs structurels donnent un premier repère sur le rapport de force.';
  }
  return '${leader.name} possède un avantage visible sur les indicateurs structurels.';
}

TeamInfo? _standingLeader(MatchBoardItem match) {
  final home = match.analysis.homeStanding;
  final away = match.analysis.awayStanding;
  if (home == null || away == null) {
    return null;
  }
  final homePoints = home.points;
  final awayPoints = away.points;
  if (homePoints != null && awayPoints != null && homePoints != awayPoints) {
    return homePoints > awayPoints ? match.homeTeam : match.awayTeam;
  }
  final homeRank = home.rank;
  final awayRank = away.rank;
  if (homeRank != null && awayRank != null && homeRank != awayRank) {
    return homeRank < awayRank ? match.homeTeam : match.awayTeam;
  }
  return null;
}

String _scenarioFormDescription(MatchBoardItem match) {
  final homeResults = _lectorFormResults(
    recentMatches: match.analysis.homeRecentLeagueMatches.take(5).toList(),
    fallbackForm:
        match.analysis.homeStatistics?.form ??
        match.analysis.homeStanding?.form,
  );
  final awayResults = _lectorFormResults(
    recentMatches: match.analysis.awayRecentLeagueMatches.take(5).toList(),
    fallbackForm:
        match.analysis.awayStatistics?.form ??
        match.analysis.awayStanding?.form,
  );
  if (homeResults.isEmpty || awayResults.isEmpty) {
    return 'La dynamique récente sera précisée quand les séries des deux équipes seront complètes.';
  }
  final homePoints = _formPoints(homeResults);
  final awayPoints = _formPoints(awayResults);
  if (homePoints == awayPoints) {
    return 'Les deux équipes arrivent avec une dynamique récente comparable.';
  }
  final leader = homePoints > awayPoints
      ? match.homeTeam.name
      : match.awayTeam.name;
  return '$leader arrive avec une meilleure forme sur les 5 derniers matchs.';
}

String _scenarioHomeAwayDescription(MatchBoardItem match) {
  final homeRate = _winRate(
    match.analysis.homeStatistics?.winsHome,
    match.analysis.homeStatistics?.playedHome,
  );
  final awayRate = _winRate(
    match.analysis.awayStatistics?.winsAway,
    match.analysis.awayStatistics?.playedAway,
  );
  if (homeRate == null || awayRate == null) {
    return 'Le contexte domicile / extérieur sera précisé quand les splits seront complets.';
  }
  if (homeRate > awayRate) {
    return '${match.homeTeam.name} est plus solide à domicile que ${match.awayTeam.name} à l’extérieur.';
  }
  if (awayRate > homeRate) {
    return '${match.awayTeam.name} voyage mieux que le rendement domicile adverse ne le suggère.';
  }
  return 'Le rendement domicile / extérieur reste équilibré sur les données disponibles.';
}

String _pointsLabel(TeamStandingSnapshot? standing) {
  final points = standing?.points;
  if (points == null) {
    return 'pts à confirmer';
  }
  return '$points pts';
}

String _rankGapLabel(MatchBoardItem match) {
  final home = match.analysis.homeStanding?.rank;
  final away = match.analysis.awayStanding?.rank;
  if (home == null || away == null) {
    return 'écart à confirmer';
  }
  final gap = (home - away).abs();
  if (gap == 0) {
    return 'même rang';
  }
  return '+$gap place${gap > 1 ? 's' : ''}';
}

String _pointsGapLabel(MatchBoardItem match) {
  final home = match.analysis.homeStanding?.points;
  final away = match.analysis.awayStanding?.points;
  if (home == null || away == null) {
    return 'points à confirmer';
  }
  final gap = (home - away).abs();
  if (gap == 0) {
    return 'même total';
  }
  return '+$gap pts';
}

int _formPoints(List<String> results) {
  var total = 0;
  for (final result in results.take(5)) {
    final value = result.toUpperCase();
    if (value == 'W' || value == 'V') {
      total += 3;
    } else if (value == 'D' || value == 'N') {
      total += 1;
    }
  }
  return total;
}

List<String> _lectorFormResults({
  required List<TeamRecentMatchSnapshot> recentMatches,
  required String? fallbackForm,
}) {
  final fromRecent = recentMatches
      .map((match) => _normalizeResult(match.result))
      .whereType<String>()
      .take(5)
      .toList(growable: false);
  if (fromRecent.isNotEmpty) {
    return fromRecent;
  }
  return _matchDetailLastFiveResults(fallbackForm);
}

List<int> _formChartValues(List<String> results) {
  return results
      .take(5)
      .map((result) {
        return switch (_normalizeResult(result)) {
          'W' => 3,
          'D' => 1,
          'L' => 0,
          _ => 0,
        };
      })
      .toList(growable: false);
}

String _recentScoreLabel(TeamRecentMatchSnapshot match) {
  if (match.goalsFor == null || match.goalsAgainst == null) {
    return '-';
  }
  return '${match.goalsFor}-${match.goalsAgainst}';
}

String _lectorFormResultLabel(String result) {
  return switch (_normalizeResult(result)) {
    'W' => 'V',
    'D' => 'N',
    'L' => 'D',
    _ => '-',
  };
}

String _lectorFormTakeawayText({
  required MatchBoardItem match,
  required _FormWindowStats homeStats,
  required _FormWindowStats awayStats,
}) {
  if (!homeStats.hasResults || !awayStats.hasResults) {
    return 'La forme récente sera plus parlante dès que les deux séries seront complètes.';
  }

  if (homeStats.points == awayStats.points) {
    return '${match.homeTeam.name} et ${match.awayTeam.name} arrivent avec une dynamique récente comparable.';
  }

  final strongerName = homeStats.points > awayStats.points
      ? match.homeTeam.name
      : match.awayTeam.name;
  final weakerName = homeStats.points > awayStats.points
      ? match.awayTeam.name
      : match.homeTeam.name;
  final strongerStats = homeStats.points > awayStats.points
      ? homeStats
      : awayStats;
  final weakerStats = homeStats.points > awayStats.points
      ? awayStats
      : homeStats;
  final gap = (strongerStats.points - weakerStats.points).abs();
  final irregularNote = weakerStats.losses >= 2
      ? ', tandis que $weakerName reste plus irrégulier'
      : ' devant $weakerName';

  return '$strongerName affiche la meilleure dynamique récente avec $gap pt${gap > 1 ? 's' : ''} d’avance sur les 5 derniers matchs$irregularNote.';
}

String _formGapLabel(List<String> homeResults, List<String> awayResults) {
  final gap = (_formPoints(homeResults) - _formPoints(awayResults)).abs();
  if (homeResults.isEmpty && awayResults.isEmpty) {
    return 'forme à confirmer';
  }
  if (gap == 0) {
    return 'forme proche';
  }
  return '+$gap pts';
}

String _homeAwayGapLabel(MatchBoardItem match) {
  final homeRate = _winRate(
    match.analysis.homeStatistics?.winsHome,
    match.analysis.homeStatistics?.playedHome,
  );
  final awayRate = _winRate(
    match.analysis.awayStatistics?.winsAway,
    match.analysis.awayStatistics?.playedAway,
  );
  if (homeRate == null || awayRate == null) {
    return 'à confirmer';
  }
  final gap = ((homeRate - awayRate).abs() * 100).round();
  if (gap < 10) {
    return 'écart faible';
  }
  if (gap < 25) {
    return 'écart visible';
  }
  return 'écart marqué';
}

double? _winRate(int? wins, int? played) {
  if (wins == null || played == null || played <= 0) {
    return null;
  }
  return wins / played;
}

String _winPercentLabel(int? wins, int? played) {
  final rate = _winRate(wins, played);
  if (rate == null) {
    return 'rendement à confirmer';
  }
  return '${(rate * 100).round()}% de victoires';
}

List<TeamStandingSnapshot> _mobileStandingRows(MatchBoardItem match) {
  final fullTable = [...match.analysis.leagueStandings];
  if (fullTable.isEmpty) {
    final fallback = [
      if (match.analysis.homeStanding != null) match.analysis.homeStanding!,
      if (match.analysis.awayStanding != null) match.analysis.awayStanding!,
    ];
    fallback.sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
    return fallback;
  }

  fullTable.sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
  return fullTable;
}

TeamInfo? _standingTeam(MatchBoardItem match, TeamStandingSnapshot standing) {
  if (_isHomeStanding(match, standing)) {
    return match.homeTeam;
  }
  if (_isAwayStanding(match, standing)) {
    return match.awayTeam;
  }
  return null;
}

_StandingHighlight _standingHighlight(
  MatchBoardItem match,
  TeamStandingSnapshot standing,
) {
  if (_isHomeStanding(match, standing)) {
    return _StandingHighlight.home;
  }
  if (_isAwayStanding(match, standing)) {
    return _StandingHighlight.away;
  }
  return _StandingHighlight.none;
}

bool _isHomeStanding(MatchBoardItem match, TeamStandingSnapshot standing) {
  return standing.teamId == match.homeTeam.apiFootballTeamId ||
      standing.teamName == match.homeTeam.name;
}

bool _isAwayStanding(MatchBoardItem match, TeamStandingSnapshot standing) {
  return standing.teamId == match.awayTeam.apiFootballTeamId ||
      standing.teamName == match.awayTeam.name;
}

bool _sameStandingTeam(TeamStandingSnapshot a, TeamStandingSnapshot b) {
  return a.teamId == b.teamId || a.teamName == b.teamName;
}

String _intValue(int? value) => value?.toString() ?? '-';

String _signedValue(int? value) {
  if (value == null) {
    return '-';
  }
  return value > 0 ? '+$value' : '$value';
}

Color _goalDiffColor(BuildContext context, int? value) {
  if (value == null || value == 0) {
    return context.textColors.secondary;
  }
  return value > 0 ? context.semantic.success : context.semantic.error;
}

String _standingFormDotLabel(String result) {
  final value = result.toUpperCase();
  return switch (value) {
    'W' => 'V',
    'D' => 'N',
    'L' => 'D',
    '-' => '-',
    _ => value.characters.take(1).toString(),
  };
}

String _titleRaceText(MatchBoardItem match) {
  final home = match.analysis.homeStanding;
  if (home?.rank == 1 && home?.points != null) {
    return '${match.homeTeam.name} en tête avec ${home!.points} pts.';
  }
  final away = match.analysis.awayStanding;
  if (away?.rank == 1 && away?.points != null) {
    return '${match.awayTeam.name} en tête avec ${away!.points} pts.';
  }
  return 'Les positions situent le contexte de la rencontre.';
}

String _standingDynamicText(MatchBoardItem match) {
  final homeRank = match.analysis.homeStanding?.rank;
  final awayRank = match.analysis.awayStanding?.rank;
  if (homeRank == null || awayRank == null) {
    return 'Dynamique de championnat à confirmer.';
  }
  final leader = homeRank < awayRank
      ? match.homeTeam.name
      : match.awayTeam.name;
  final chasing = homeRank < awayRank
      ? match.awayTeam.name
      : match.homeTeam.name;
  return '$leader est devant, $chasing doit combler l’écart.';
}

String _standingReadingText(MatchBoardItem match) {
  final rankGap = _rankGapLabel(match);
  final pointsGap = _pointsGapLabel(match);
  return '$rankGap et $pointsGap nourrissent la lecture « ${_scenarioTitle(match)} ».';
}

Color _formDotColor(BuildContext context, String result) {
  final value = result.toUpperCase();
  if (value == 'W' || value == 'V') {
    return context.semantic.success;
  }
  if (value == 'D' || value == 'N') {
    return context.textColors.secondary;
  }
  if (value == 'L' || value == 'P') {
    return context.semantic.error;
  }
  return context.surfaces.border;
}

Color _formPerformanceColor(BuildContext context, List<String> results) {
  if (results.isEmpty) {
    return context.textColors.secondary;
  }
  final points = _formPoints(results);
  final maximum = results.length * 3;
  if (points * 3 >= maximum * 2) {
    return context.semantic.success;
  }
  if (points * 3 <= maximum) {
    return context.semantic.error;
  }
  return context.textColors.secondary;
}

Color _contextDeltaColor(BuildContext context, String value) {
  final normalized = value.trim();
  if (normalized.startsWith('+') && normalized != '+0 pts') {
    return context.semantic.success;
  }
  return context.textColors.secondary;
}

String _formDotLabel(String result) {
  final value = result.toUpperCase();
  return switch (value) {
    'W' => 'V',
    'D' => 'N',
    'L' => 'P',
    '-' => '-',
    _ => value.characters.take(1).toString(),
  };
}

List<_RecentMatchUiRow> _recentRows(MatchBoardItem match) {
  final homeRows = match.analysis.homeRecentLeagueMatches.map((recent) {
    final score = recent.goalsFor == null || recent.goalsAgainst == null
        ? recent.result
        : '${recent.goalsFor} - ${recent.goalsAgainst}';
    return _RecentMatchUiRow(
      meta: recent.venue == RecentMatchVenue.home ? 'Dom.' : 'Ext.',
      teamName: match.homeTeam.name,
      teamLogoUrl: match.homeTeam.logoUrl,
      opponentName: recent.opponentName,
      opponentLogoUrl: recent.opponentLogoUrl,
      score: score,
    );
  });

  final awayRows = match.analysis.awayRecentLeagueMatches.map((recent) {
    final score = recent.goalsFor == null || recent.goalsAgainst == null
        ? recent.result
        : '${recent.goalsFor} - ${recent.goalsAgainst}';
    return _RecentMatchUiRow(
      meta: recent.venue == RecentMatchVenue.home ? 'Dom.' : 'Ext.',
      teamName: match.awayTeam.name,
      teamLogoUrl: match.awayTeam.logoUrl,
      opponentName: recent.opponentName,
      opponentLogoUrl: recent.opponentLogoUrl,
      score: score,
    );
  });

  return [...homeRows, ...awayRows];
}

class _MatchDetailCloseAction extends StatelessWidget {
  const _MatchDetailCloseAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 430) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: IconButton(
          tooltip: 'Toutes les rencontres',
          onPressed: onPressed,
          icon: const Icon(Icons.list_rounded),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.list_rounded, size: 18),
        label: const Text('Toutes les rencontres'),
      ),
    );
  }
}

class _ProfileStatusBand extends StatelessWidget {
  const _ProfileStatusBand({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cette compétition n’est pas activée dans votre profil.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Vous consultez ici toutes les rencontres disponibles.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ajout de ${match.competition.name} au profil à brancher.',
                    ),
                  ),
                );
              },
              child: Text('Ajouter ${match.competition.name} à mon profil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchDetailHeader extends StatelessWidget {
  const _MatchDetailHeader({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final homeStanding = match.analysis.homeStanding;
    final awayStanding = match.analysis.awayStanding;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  match.fixture.kickoffLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    match.competition.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (match.profileStatus == MatchProfileStatus.outOfProfile)
                  _HeaderStatusPill(label: 'Hors profil'),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 640;
                return Row(
                  children: [
                    Expanded(
                      child: _MatchHeaderTeam(
                        team: match.homeTeam,
                        standing: homeStanding,
                        alignment: CrossAxisAlignment.center,
                        isCompact: true,
                      ),
                    ),
                    SizedBox(width: isCompact ? 8 : 18),
                    _ScoreSeparator(isCompact: isCompact),
                    SizedBox(width: isCompact ? 8 : 18),
                    Expanded(
                      child: _MatchHeaderTeam(
                        team: match.awayTeam,
                        standing: awayStanding,
                        alignment: CrossAxisAlignment.center,
                        isCompact: true,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (match.fixture.venue != null) ...[
              const SizedBox(height: 16),
              _VenueLine(venue: match.fixture.venue!),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderStatusPill extends StatelessWidget {
  const _HeaderStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchHeaderTeam extends StatelessWidget {
  const _MatchHeaderTeam({
    required this.team,
    required this.standing,
    required this.alignment,
    this.isCompact = false,
  });

  final TeamInfo team;
  final TeamStandingSnapshot? standing;
  final CrossAxisAlignment alignment;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = standing?.rank;
    final points = standing?.points;
    final meta = [
      if (rank != null) '${rank}e',
      if (points != null) '$points pts',
    ].join(' · ');

    return Column(
      crossAxisAlignment: alignment,
      children: [
        SportsAssetBadge(
          size: isCompact ? 54 : 74,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          borderRadius: 8,
        ),
        const SizedBox(height: 12),
        Text(
          team.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignment == CrossAxisAlignment.end
              ? TextAlign.right
              : alignment == CrossAxisAlignment.center
              ? TextAlign.center
              : TextAlign.left,
          style:
              (isCompact
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            meta,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _ScoreSeparator extends StatelessWidget {
  const _ScoreSeparator({this.isCompact = false});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final style = isCompact
        ? Theme.of(context).textTheme.headlineSmall
        : Theme.of(context).textTheme.headlineMedium;

    return Text(
      '–',
      style: style?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _VenueLine extends StatelessWidget {
  const _VenueLine({required this.venue});

  final FixtureVenue venue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final city = venue.city;
    final name = venue.name;
    final value = [
      if (name != null && name.isNotEmpty) name,
      if (city != null && city.isNotEmpty) city,
    ].join(' · ');

    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Icon(Icons.location_on_rounded, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          l10n.venueLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _CopilotReadingSection extends StatefulWidget {
  const _CopilotReadingSection({
    required this.match,
    required this.opportunity,
  });

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  State<_CopilotReadingSection> createState() => _CopilotReadingSectionState();
}

class _CopilotReadingSectionState extends State<_CopilotReadingSection> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final theses =
        widget.opportunity?.retainedTheses ??
        [if (widget.match.thesis != null) widget.match.thesis!];
    final title = OpportunityDecisionPresenter.opportunityTitleFromTheses(
      theses,
    );
    final argumentCount = widget.opportunity?.argumentCount ?? 0;
    final vigilanceCount = widget.opportunity?.contradictionCount ?? 0;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollapsibleHeader(
            icon: Icons.auto_awesome_rounded,
            title: l10n.copilotReadingTitle,
            summary: theses.isEmpty
                ? 'Aucune lecture combinée'
                : '$title · $argumentCount argument${argumentCount > 1 ? 's' : ''} · $vigilanceCount vigilance${vigilanceCount > 1 ? 's' : ''}',
            isOpen: _isOpen,
            onPressed: () {
              setState(() {
                _isOpen = !_isOpen;
              });
            },
          ),
          if (_isOpen) ...[
            const SizedBox(height: 12),
            if (theses.isNotEmpty) ...[
              _ReadingTitlePill(label: title, thesisId: theses.first.id),
              const SizedBox(height: 10),
            ],
            theses.isEmpty
                ? widget.match.signals.isEmpty
                      ? Text(
                          l10n.noCopilotSignalsMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Column(
                          children: [
                            for (final signal in widget.match.signals)
                              _CopilotSignalTile(signal: signal),
                          ],
                        )
                : Text(
                    _compactReadingText(theses),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            if (widget.opportunity != null) ...[
              const SizedBox(height: 10),
              _ReadingValidationSummary(opportunity: widget.opportunity!),
            ],
          ],
        ],
      ),
    );
  }

  String _compactReadingText(List<MatchThesis> theses) {
    final primary = theses.first;
    final title = primary.title.toLowerCase();
    if (title.contains('ouvert')) {
      return 'Plusieurs indicateurs offensifs et défensifs convergent vers un scénario avec des espaces et des buts.';
    }
    if (title.contains('fermé')) {
      return 'Plusieurs indicateurs convergent vers un scénario plus contrôlé et moins ouvert.';
    }
    if (title.contains('favori')) {
      return 'Les signaux disponibles convergent vers une équipe mieux placée pour maîtriser la rencontre.';
    }
    if (title.contains('outsider')) {
      return 'La lecture signale un outsider plus crédible que sa cote ou son statut ne le suggère.';
    }

    return primary.summary;
  }
}

class _CollapsibleHeader extends StatelessWidget {
  const _CollapsibleHeader({
    required this.icon,
    required this.title,
    required this.summary,
    required this.isOpen,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String summary;
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.input),
      onTap: onPressed,
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(width: 10),
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
                const SizedBox(height: 2),
                Text(
                  summary,
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
          Icon(
            isOpen
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: colorScheme.onSurface,
          ),
        ],
      ),
    );
  }
}

class _ReadingTitlePill extends StatelessWidget {
  const _ReadingTitlePill({required this.label, required this.thesisId});

  final String label;
  final String thesisId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = context.opportunities.badgeFor(
      thesisId,
      variant: AppReadingBadgeVariant.combined,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: badge.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: badge.foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ReadingValidationSummary extends StatelessWidget {
  const _ReadingValidationSummary({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final arguments = opportunity.argumentCount;
    final contradictions = opportunity.contradictionCount;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hub_rounded, color: colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Lecture combinée validée par $arguments argument${arguments > 1 ? 's' : ''} convergent${arguments > 1 ? 's' : ''}'
                ' et $contradictions point${contradictions > 1 ? 's' : ''} de vigilance.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopilotArgumentsSection extends StatefulWidget {
  const _CopilotArgumentsSection({
    required this.match,
    required this.opportunity,
  });

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  State<_CopilotArgumentsSection> createState() =>
      _CopilotArgumentsSectionState();
}

class _CopilotArgumentsSectionState extends State<_CopilotArgumentsSection> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final allArguments =
        widget.opportunity?.copilotArguments ??
        widget.match.thesis?.arguments ??
        const [];
    final positiveArguments =
        widget.opportunity?.positiveArguments ??
        allArguments
            .where(
              (argument) =>
                  argument.family != CopilotArgumentFamily.contradiction,
            )
            .toList();
    final contradictions =
        widget.opportunity?.contradictions ??
        allArguments
            .where(
              (argument) =>
                  argument.family == CopilotArgumentFamily.contradiction,
            )
            .toList();
    final evidence =
        widget.opportunity?.statisticalEvidence ??
        widget.match.thesis?.supportingEvidence ??
        const [];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final argumentCount = positiveArguments.length;
    final vigilanceCount = contradictions.length;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollapsibleHeader(
            icon: Icons.fact_check_outlined,
            title: 'Lectures simples retenues',
            summary:
                '$argumentCount lecture${argumentCount > 1 ? 's' : ''} · $vigilanceCount vigilance${vigilanceCount > 1 ? 's' : ''}',
            isOpen: _isOpen,
            onPressed: () {
              setState(() {
                _isOpen = !_isOpen;
              });
            },
          ),
          if (_isOpen) ...[
            const SizedBox(height: 12),
            if (positiveArguments.isNotEmpty || contradictions.isNotEmpty) ...[
              _CopilotArgumentGroup(
                title: 'Lectures retenues',
                emptyMessage:
                    'Aucune lecture simple détaillée n’est disponible pour cette lecture combinée.',
                arguments: positiveArguments,
                match: widget.match,
              ),
              const SizedBox(height: 14),
              _CopilotArgumentGroup(
                title: 'Points de vigilance',
                emptyMessage: 'Aucun point de vigilance détecté.',
                arguments: contradictions,
                match: widget.match,
                isVigilance: true,
              ),
            ] else if (evidence.isNotEmpty)
              _EvidenceGroup(title: 'Preuves disponibles', evidence: evidence)
            else
              Text(
                'Aucune lecture simple détaillée n’est disponible pour cette lecture combinée.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CopilotArgumentGroup extends StatelessWidget {
  const _CopilotArgumentGroup({
    required this.title,
    required this.emptyMessage,
    required this.arguments,
    required this.match,
    this.isVigilance = false,
  });

  final String title;
  final String emptyMessage;
  final List<CopilotArgument> arguments;
  final MatchBoardItem match;
  final bool isVigilance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groupedArguments = _groupArguments(arguments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (arguments.isEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                emptyMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              for (final group in groupedArguments.indexed) ...[
                _GroupedCopilotArgumentCard(
                  group: group.$2,
                  match: match,
                  isVigilance: isVigilance,
                ),
                if (group.$1 < groupedArguments.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }

  List<_ArgumentPresentationGroup> _groupArguments(
    List<CopilotArgument> arguments,
  ) {
    final groupsByKey = <String, List<CopilotArgument>>{};
    for (final argument in arguments) {
      final key =
          '${FootballReadingCopyCatalog.readingIdFor(argument)}_${argument.subjectName}';
      groupsByKey.putIfAbsent(key, () => []).add(argument);
    }

    return [
      for (final entry in groupsByKey.entries)
        _ArgumentPresentationGroup(arguments: entry.value),
    ];
  }
}

class _ArgumentPresentationGroup {
  const _ArgumentPresentationGroup({required this.arguments});

  final List<CopilotArgument> arguments;

  CopilotArgument get primary => arguments.first;
}

class _GroupedCopilotArgumentCard extends StatelessWidget {
  const _GroupedCopilotArgumentCard({
    required this.group,
    required this.match,
    required this.isVigilance,
  });

  final _ArgumentPresentationGroup group;
  final MatchBoardItem match;
  final bool isVigilance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = group.primary;
    final presenter = CopilotArgumentPresenter(primary);
    final readingId = FootballReadingCopyCatalog.readingIdFor(primary);
    final badge = context.opportunities.badgeFor(
      isVigilance ? 'contradiction' : readingId,
      variant: isVigilance
          ? AppReadingBadgeVariant.soft
          : AppReadingBadgeVariant.simple,
    );
    final color = badge.foreground;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: badge.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _argumentGroupIcon(primary),
                  color: badge.iconColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    presenter.headline,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final argument in group.arguments.indexed) ...[
              _ArgumentEvidenceLine(
                argument: argument.$2,
                match: match,
                color: color,
              ),
              if (argument.$1 < group.arguments.length - 1)
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  IconData _argumentGroupIcon(CopilotArgument argument) {
    return switch (argument.family) {
      CopilotArgumentFamily.hierarchy => Icons.bar_chart_rounded,
      CopilotArgumentFamily.performance => Icons.home_work_outlined,
      CopilotArgumentFamily.defense => Icons.shield_outlined,
      CopilotArgumentFamily.attack => Icons.trending_up_rounded,
      CopilotArgumentFamily.form => Icons.show_chart_rounded,
      CopilotArgumentFamily.rhythm => Icons.auto_graph_rounded,
      CopilotArgumentFamily.market => Icons.track_changes_rounded,
      CopilotArgumentFamily.contradiction => Icons.warning_amber_rounded,
    };
  }
}

class _ArgumentEvidenceLine extends StatelessWidget {
  const _ArgumentEvidenceLine({
    required this.argument,
    required this.match,
    required this.color,
  });

  final CopilotArgument argument;
  final MatchBoardItem match;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presenter = CopilotArgumentPresenter(argument);
    final showSummary =
        argument.evidence.isEmpty ||
        !FootballReadingCopyCatalog.hasStructuredEvidence(argument);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline_rounded, color: color, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displaySubjectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              if (showSummary)
                Text(
                  _displaySummary(presenter.summary),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              for (final evidence in argument.evidence)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _displayText(
                      FootballReadingCopyCatalog.evidenceLineFor(
                        argument,
                        evidence,
                      ),
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String get _displaySubjectName {
    final subject = argument.subjectName;
    if (subject == match.homeTeam.id ||
        subject == match.homeTeam.apiFootballTeamId?.toString() ||
        subject == 'api-team-${match.homeTeam.apiFootballTeamId}') {
      return match.homeTeam.name;
    }
    if (subject == match.awayTeam.id ||
        subject == match.awayTeam.apiFootballTeamId?.toString() ||
        subject == 'api-team-${match.awayTeam.apiFootballTeamId}') {
      return match.awayTeam.name;
    }
    if (subject == match.id) {
      return 'La rencontre';
    }
    return subject;
  }

  String _displaySummary(String summary) {
    return _displayText(summary);
  }

  String _displayText(String text) {
    return text
        .replaceAll(match.homeTeam.id, match.homeTeam.name)
        .replaceAll(
          'api-team-${match.homeTeam.apiFootballTeamId}',
          match.homeTeam.name,
        )
        .replaceAll(match.awayTeam.id, match.awayTeam.name)
        .replaceAll(
          'api-team-${match.awayTeam.apiFootballTeamId}',
          match.awayTeam.name,
        )
        .replaceAll(match.id, 'la rencontre');
  }
}

class _ThesisReading extends StatelessWidget {
  const _ThesisReading({required this.thesis});

  final MatchThesis thesis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final arguments = thesis.arguments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (arguments.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final spacing = isWide ? 14.0 : 10.0;
              final width = isWide
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: spacing,
                runSpacing: 14,
                children: [
                  for (final argument in arguments)
                    SizedBox(
                      width: width,
                      child: _CopilotArgumentCard(argument: argument),
                    ),
                ],
              );
            },
          )
        else ...[
          Text(
            thesis.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            thesis.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (thesis.supportingEvidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            _EvidenceGroup(
              title: 'Preuves disponibles',
              evidence: thesis.supportingEvidence,
            ),
          ],
        ],
        if (thesis.limits.isNotEmpty) ...[
          const SizedBox(height: 14),
          _CompactEvidenceLine(evidence: thesis.limits.first),
        ] else if (thesis.profileReasons.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ProfileFitNotice(reasonCount: thesis.profileReasons.length),
        ],
      ],
    );
  }
}

class _CompactEvidenceLine extends StatelessWidget {
  const _CompactEvidenceLine({required this.evidence});

  final ThesisEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            evidence.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileFitNotice extends StatelessWidget {
  const _ProfileFitNotice({required this.reasonCount});

  final int reasonCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, color: colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reasonCount > 1
                    ? 'Cette lecture recoupe plusieurs priorités de votre profil.'
                    : 'Cette lecture recoupe une priorité de votre profil.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopilotArgumentCard extends StatefulWidget {
  const _CopilotArgumentCard({required this.argument});

  final CopilotArgument argument;

  @override
  State<_CopilotArgumentCard> createState() => _CopilotArgumentCardState();
}

class _CopilotArgumentCardState extends State<_CopilotArgumentCard> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final argument = widget.argument;
    final presenter = CopilotArgumentPresenter(argument);
    final readingId = FootballReadingCopyCatalog.readingIdFor(argument);
    final badge = context.opportunities.badgeFor(
      argument.family == CopilotArgumentFamily.contradiction
          ? 'contradiction'
          : readingId,
      variant: AppReadingBadgeVariant.simple,
    );

    return Material(
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _isOpen = !_isOpen;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: badge.background,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: badge.border),
                    ),
                    child: SizedBox.square(
                      dimension: 42,
                      child: Icon(
                        _argumentIcon(argument),
                        color: badge.iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          presenter.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          presenter.summary,
                          maxLines: _isOpen ? null : 3,
                          overflow: _isOpen ? null : TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      presenter.actionLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.arrow_forward_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
              if (_isOpen && argument.evidence.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: 12),
                for (final evidence in argument.evidence)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _EvidenceRow(evidence: evidence),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _argumentIcon(CopilotArgument argument) {
    return switch (argument.family) {
      CopilotArgumentFamily.hierarchy => Icons.emoji_events_outlined,
      CopilotArgumentFamily.performance => Icons.trending_down_rounded,
      CopilotArgumentFamily.defense => Icons.shield_outlined,
      CopilotArgumentFamily.attack => Icons.trending_up_rounded,
      CopilotArgumentFamily.form => Icons.show_chart_rounded,
      CopilotArgumentFamily.rhythm => Icons.speed_rounded,
      CopilotArgumentFamily.market => Icons.stacked_line_chart_rounded,
      CopilotArgumentFamily.contradiction => Icons.warning_amber_rounded,
    };
  }
}

class _RecommendedMarketPanel extends StatelessWidget {
  const _RecommendedMarketPanel({
    required this.match,
    required this.recommendedMarket,
    required this.rationale,
    required this.ticketDraftListenable,
    required this.onToggleTicket,
  });

  final MatchBoardItem match;
  final RecommendedMarket recommendedMarket;
  final String rationale;
  final ValueListenable<TicketDraft>? ticketDraftListenable;
  final ValueChanged<TicketDraftSelection>? onToggleTicket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final components = context.components;
    final bookmaker = recommendedMarket.market.bookmakerName;
    final ticketSelection = TicketDraftSelection.fromMatchSelection(
      match,
      recommendedMarket.market,
      recommendedMarket.selection,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: components.oddsBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: components.oddsText),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marché proposé',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: components.oddsText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${recommendedMarket.market.label} · ${recommendedMarket.selection.label}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (bookmaker != null && bookmaker.isNotEmpty)
                        Text(
                          bookmaker,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  recommendedMarket.selection.odds.toStringAsFixed(2),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: components.oddsText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (ticketSelection != null &&
                    ticketDraftListenable != null &&
                    onToggleTicket != null) ...[
                  const SizedBox(width: 10),
                  ValueListenableBuilder<TicketDraft>(
                    valueListenable: ticketDraftListenable!,
                    builder: (context, ticket, _) {
                      final isSelected = ticket.contains(ticketSelection.id);
                      final isBlockedByMatch = ticket
                          .containsAnotherSelectionForMatch(ticketSelection);
                      final canToggle = isSelected || !isBlockedByMatch;
                      return IconButton.filled(
                        tooltip: isSelected
                            ? 'Retirer du ticket'
                            : isBlockedByMatch
                            ? 'Ce match est déjà dans Mon ticket'
                            : 'Ajouter au ticket',
                        onPressed: canToggle
                            ? () => onToggleTicket!(ticketSelection)
                            : null,
                        icon: Icon(
                          isSelected
                              ? Icons.check_rounded
                              : isBlockedByMatch
                              ? Icons.block_rounded
                              : Icons.add_rounded,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.18)
                              : isBlockedByMatch
                              ? colorScheme.surfaceContainerHighest
                              : colorScheme.primary,
                          foregroundColor: isSelected
                              ? colorScheme.primary
                              : isBlockedByMatch
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onPrimary,
                          side: BorderSide(
                            color: isBlockedByMatch
                                ? colorScheme.outlineVariant
                                : colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
            Divider(height: 22, color: colorScheme.outlineVariant),
            Text(
              'Pourquoi ce marché ?',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              rationale,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceGroup extends StatelessWidget {
  const _EvidenceGroup({required this.title, required this.evidence});

  final String title;
  final List<ThesisEvidence> evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in evidence)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _EvidenceRow(evidence: item),
          ),
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.evidence});

  final ThesisEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFor(context, evidence.tone);
    final icon = switch (evidence.tone) {
      ThesisEvidenceTone.positive => Icons.check_rounded,
      ThesisEvidenceTone.warning => Icons.priority_high_rounded,
      ThesisEvidenceTone.negative => Icons.close_rounded,
      ThesisEvidenceTone.neutral => Icons.info_outline_rounded,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.tight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            evidence.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Color _colorFor(BuildContext context, ThesisEvidenceTone tone) {
    final colorScheme = Theme.of(context).colorScheme;

    return switch (tone) {
      ThesisEvidenceTone.positive => colorScheme.primary,
      ThesisEvidenceTone.warning => context.semantic.warning,
      ThesisEvidenceTone.negative => colorScheme.error,
      ThesisEvidenceTone.neutral => colorScheme.onSurfaceVariant,
    };
  }
}

class _CopilotSignalTile extends StatelessWidget {
  const _CopilotSignalTile({required this.signal});

  final MatchSignal signal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(44, 0, 12, 12),
      leading: Icon(Icons.insights_rounded, color: colorScheme.primary),
      title: Text(
        signal.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(signal.summary),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final proof in signal.proofs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $proof',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalysisSection extends StatefulWidget {
  const _AnalysisSection({required this.match, required this.opportunity});

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  State<_AnalysisSection> createState() => _AnalysisSectionState();
}

class _AnalysisSectionState extends State<_AnalysisSection> {
  _AnalysisTab _selectedTab = _AnalysisTab.standings;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final match = widget.match;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollapsibleHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Vérifier les données',
            summary: match.analysis.hasAnalysisData
                ? 'Données snapshot disponibles'
                : 'Snapshot incomplet',
            isOpen: _isExpanded,
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            Text(
              'Championnat uniquement · Amicaux et coupes exclus',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in _AnalysisTab.values) ...[
                    _AnalysisTabButton(
                      label: tab.label,
                      isSelected: _selectedTab == tab,
                      onPressed: () {
                        setState(() {
                          _selectedTab = tab;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!match.analysis.hasAnalysisData)
              Text(
                'Aucune donnée de classement, forme ou statistiques d’équipe disponible pour ce match.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              switch (_selectedTab) {
                _AnalysisTab.standings => _StandingsPanel(match: match),
                _AnalysisTab.form => _FormComparisonPanel(match: match),
                _AnalysisTab.homeAway => _HomeAwayPanel(match: match),
                _AnalysisTab.attackDefense => _AttackDefensePanel(
                  match: match,
                  opportunity: widget.opportunity,
                ),
                _AnalysisTab.series => _SeriesPanel(match: match),
              },
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Source des données : API-Football',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _AnalysisTab {
  standings('Classement'),
  form('Forme (5 matchs)'),
  homeAway('Domicile / Extérieur'),
  attackDefense('Attaque / Défense'),
  series('Séries');

  const _AnalysisTab(this.label);

  final String label;
}

class _AnalysisTabButton extends StatelessWidget {
  const _AnalysisTabButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected
            ? colorScheme.primary.withValues(alpha: 0.13)
            : colorScheme.surfaceContainerHigh,
        foregroundColor: isSelected
            ? colorScheme.primary
            : colorScheme.onSurface,
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AnalysisPlaceholder extends StatelessWidget {
  const _AnalysisPlaceholder({required this.tab});

  final _AnalysisTab tab;

  String get _message {
    return switch (tab) {
      _AnalysisTab.form =>
        'La forme récente sera affichée dès que le snapshot contient les derniers matchs de championnat.',
      _AnalysisTab.standings =>
        'Le classement sera affiché dès que le snapshot contient la table de cette ligue.',
      _AnalysisTab.homeAway =>
        'Les splits domicile/extérieur seront affichés dès que les statistiques d’équipe sont disponibles.',
      _AnalysisTab.attackDefense =>
        'Les indicateurs attaque/défense seront affichés dès que les statistiques d’équipe sont disponibles.',
      _ =>
        '${tab.label} sera alimenté dès que ces données sont présentes dans le snapshot.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            _message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormComparisonPanel extends StatelessWidget {
  const _FormComparisonPanel({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final homeResults = _lastFiveResults(
      match.analysis.homeStatistics,
      match.analysis.homeStanding,
    );
    final awayResults = _lastFiveResults(
      match.analysis.awayStatistics,
      match.analysis.awayStanding,
    );
    final homeWindow = _FormWindowStats.from(
      recentMatches: match.analysis.homeRecentLeagueMatches,
      fallbackResults: homeResults,
    );
    final awayWindow = _FormWindowStats.from(
      recentMatches: match.analysis.awayRecentLeagueMatches,
      fallbackResults: awayResults,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _VerificationInsightLine(
              text: 'Championnat uniquement · Amicaux et coupes exclus',
            ),
            const SizedBox(height: 16),
            _TeamFormTableBlock(
              team: match.homeTeam,
              statistics: match.analysis.homeStatistics,
              standing: match.analysis.homeStanding,
              recentMatches: match.analysis.homeRecentLeagueMatches,
            ),
            Divider(height: 24, color: colorScheme.outlineVariant),
            _TeamFormTableBlock(
              team: match.awayTeam,
              statistics: match.analysis.awayStatistics,
              standing: match.analysis.awayStanding,
              recentMatches: match.analysis.awayRecentLeagueMatches,
            ),
            const SizedBox(height: 12),
            _FormSynthesisCard(
              text: _formComparisonText(
                match.homeTeam.name,
                match.awayTeam.name,
                homeWindow,
                awayWindow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _lastFiveResults(
    TeamStatisticsSnapshot? statistics,
    TeamStandingSnapshot? standing,
  ) {
    return _matchDetailLastFiveResults(statistics?.form ?? standing?.form);
  }

  String _formComparisonText(
    String homeName,
    String awayName,
    _FormWindowStats home,
    _FormWindowStats away,
  ) {
    if (!home.hasResults || !away.hasResults) {
      return 'Donnée insuffisante pour produire une comparaison de forme fiable.';
    }

    if (home.points == away.points) {
      return 'Sur les 5 derniers matchs de championnat, les deux équipes présentent une dynamique récente comparable.';
    }

    final strongerName = home.points > away.points ? homeName : awayName;
    final weakerName = home.points > away.points ? awayName : homeName;
    final stronger = home.points > away.points ? home : away;
    final weaker = home.points > away.points ? away : home;
    final defensiveNote =
        stronger.goalsAgainstTotal != null &&
            weaker.goalsAgainstTotal != null &&
            stronger.goalsAgainstTotal! < weaker.goalsAgainstTotal!
        ? ' et encaisse moins de buts'
        : '';

    return 'Sur les 5 derniers matchs de championnat, $strongerName est plus régulier$defensiveNote, tandis que $weakerName présente une dynamique plus instable.';
  }
}

class _TeamFormTableBlock extends StatelessWidget {
  const _TeamFormTableBlock({
    required this.team,
    required this.statistics,
    required this.standing,
    required this.recentMatches,
  });

  final TeamInfo team;
  final TeamStatisticsSnapshot? statistics;
  final TeamStandingSnapshot? standing;
  final List<TeamRecentMatchSnapshot> recentMatches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fallbackResults = _matchDetailLastFiveResults(
      statistics?.form ?? standing?.form,
    );
    final stats = _FormWindowStats.from(
      recentMatches: recentMatches,
      fallbackResults: fallbackResults,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SportsAssetBadge(
              size: 30,
              imageUrl: team.logoUrl,
              fallbackLabel: team.name,
              borderRadius: AppRadius.tight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '5 derniers matchs de championnat',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (!stats.hasResults)
          Text(
            'Forme récente indisponible dans le snapshot actuel.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          _RecentFormTable(matches: recentMatches),
          const SizedBox(height: 10),
          _FormSummaryBar(stats: stats),
          if (recentMatches.isEmpty) ...[
            const SizedBox(height: 8),
            const _VerificationInsightLine(
              text:
                  'Le snapshot fournit seulement la série brute pour cette équipe ; le détail match par match n’est pas disponible.',
            ),
          ],
        ],
      ],
    );
  }
}

class _RecentFormTable extends StatelessWidget {
  const _RecentFormTable({required this.matches});

  final List<TeamRecentMatchSnapshot> matches;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Column(
          children: [
            const _RecentFormHeader(),
            if (matches.isEmpty)
              const _RecentFormUnavailableRow()
            else
              for (var index = 0; index < matches.length; index++)
                _RecentFormRow(
                  match: matches[index],
                  showDivider: index < matches.length - 1,
                ),
          ],
        ),
      ),
    );
  }
}

class _RecentFormHeader extends StatelessWidget {
  const _RecentFormHeader();

  @override
  Widget build(BuildContext context) {
    return _RecentFormTableLine(
      opponent: const Text('Adversaire'),
      venue: const Text('Lieu'),
      score: const Text('Score'),
      result: const Text('Résultat'),
      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );
  }
}

class _RecentFormUnavailableRow extends StatelessWidget {
  const _RecentFormUnavailableRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _RecentFormTableLine(
      opponent: Text(
        'Détail match par match indisponible.',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      venue: const Text('—'),
      score: const Text('—'),
      result: const Text('—'),
    );
  }
}

class _RecentFormRow extends StatelessWidget {
  const _RecentFormRow({required this.match, required this.showDivider});

  final TeamRecentMatchSnapshot match;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.62),
                ),
              )
            : null,
      ),
      child: _RecentFormTableLine(
        opponent: Row(
          children: [
            SportsAssetBadge(
              size: 26,
              imageUrl: match.opponentLogoUrl,
              fallbackLabel: match.opponentName,
              borderRadius: AppRadius.tight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                match.opponentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        venue: _VenueBadge(venue: match.venue),
        score: Text(
          _scoreLabel(match),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        result: Align(
          alignment: Alignment.centerRight,
          child: _FormResultBadge(result: match.result),
        ),
      ),
    );
  }

  String _scoreLabel(TeamRecentMatchSnapshot match) {
    if (match.goalsFor == null || match.goalsAgainst == null) {
      return '—';
    }
    return '${match.goalsFor}-${match.goalsAgainst}';
  }
}

class _RecentFormTableLine extends StatelessWidget {
  const _RecentFormTableLine({
    required this.opponent,
    required this.venue,
    required this.score,
    required this.result,
    this.textColor,
    this.fontWeight,
  });

  final Widget opponent;
  final Widget venue;
  final Widget score;
  final Widget result;
  final Color? textColor;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: textColor, fontWeight: fontWeight);

    Widget styled(Widget child) {
      return DefaultTextStyle.merge(
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: child,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 7, child: styled(opponent)),
          SizedBox(width: 44, child: Center(child: styled(venue))),
          SizedBox(width: 68, child: Center(child: styled(score))),
          SizedBox(width: 58, child: styled(result)),
        ],
      ),
    );
  }
}

class _VenueBadge extends StatelessWidget {
  const _VenueBadge({required this.venue});

  final RecentMatchVenue venue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = venue == RecentMatchVenue.home
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final label = venue == RecentMatchVenue.home ? 'D' : 'E';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.62)),
      ),
      child: SizedBox.square(
        dimension: 26,
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSummaryBar extends StatelessWidget {
  const _FormSummaryBar({required this.stats});

  final _FormWindowStats stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              _InlineFormBalance(stats: stats),
              if (stats.goalsForTotal != null) ...[
                _SummarySeparator(),
                _InlineSummaryText(
                  label: 'Buts marqués',
                  value:
                      '${stats.goalsForTotal} (${stats.goalsForAverage!.toStringAsFixed(2)}/m)',
                ),
              ],
              if (stats.goalsAgainstTotal != null) ...[
                _SummarySeparator(),
                _InlineSummaryText(
                  label: 'Buts encaissés',
                  value:
                      '${stats.goalsAgainstTotal} (${stats.goalsAgainstAverage!.toStringAsFixed(2)}/m)',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineFormBalance extends StatelessWidget {
  const _InlineFormBalance({required this.stats});

  final _FormWindowStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semantic;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Bilan : ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
        _ColoredText('${stats.wins}V', color: semantic.success),
        _MutedDot(),
        _ColoredText('${stats.draws}N', color: context.textColors.secondary),
        _MutedDot(),
        _ColoredText('${stats.losses}D', color: theme.colorScheme.error),
      ],
    );
  }
}

class _InlineSummaryText extends StatelessWidget {
  const _InlineSummaryText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text.rich(
      TextSpan(
        text: '$label : ',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColoredText extends StatelessWidget {
  const _ColoredText(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _MutedDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SummarySeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _FormSynthesisCard extends StatelessWidget {
  const _FormSynthesisCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormWindowStats {
  const _FormWindowStats({
    required this.wins,
    required this.draws,
    required this.losses,
    required this.matchCount,
    this.goalsForTotal,
    this.goalsAgainstTotal,
  });

  factory _FormWindowStats.from({
    required List<TeamRecentMatchSnapshot> recentMatches,
    required List<String> fallbackResults,
  }) {
    final normalizedResults = recentMatches.isNotEmpty
        ? recentMatches
              .map((match) => _normalizeResult(match.result))
              .whereType<String>()
              .toList(growable: false)
        : fallbackResults;
    final scoredMatches = recentMatches.where(
      (match) => match.goalsFor != null && match.goalsAgainst != null,
    );
    final goalsFor = scoredMatches.isEmpty
        ? null
        : scoredMatches.fold<int>(0, (sum, match) => sum + match.goalsFor!);
    final goalsAgainst = scoredMatches.isEmpty
        ? null
        : scoredMatches.fold<int>(0, (sum, match) => sum + match.goalsAgainst!);

    return _FormWindowStats(
      wins: normalizedResults.where((result) => result == 'W').length,
      draws: normalizedResults.where((result) => result == 'D').length,
      losses: normalizedResults.where((result) => result == 'L').length,
      matchCount: normalizedResults.length,
      goalsForTotal: goalsFor,
      goalsAgainstTotal: goalsAgainst,
    );
  }

  final int wins;
  final int draws;
  final int losses;
  final int matchCount;
  final int? goalsForTotal;
  final int? goalsAgainstTotal;

  bool get hasResults => matchCount > 0;
  int get points => (wins * 3) + draws;
  double? get goalsForAverage => goalsForTotal == null || matchCount == 0
      ? null
      : goalsForTotal! / matchCount;
  double? get goalsAgainstAverage =>
      goalsAgainstTotal == null || matchCount == 0
      ? null
      : goalsAgainstTotal! / matchCount;
}

String? _normalizeResult(String result) {
  return switch (result.trim().toUpperCase()) {
    'W' || 'V' => 'W',
    'D' || 'N' => 'D',
    'L' || 'P' => 'L',
    _ => null,
  };
}

String _formResultLabel(String result) {
  return switch (_normalizeResult(result)) {
    'W' => 'V',
    'D' => 'N',
    'L' => 'D',
    _ => '—',
  };
}

Color _formResultColor(BuildContext context, String result) {
  final semantic = context.semantic;
  return switch (_normalizeResult(result)) {
    'W' => semantic.success,
    'D' => context.textColors.secondary,
    'L' => semantic.error,
    _ => context.textColors.secondary,
  };
}

class _FormResultBadge extends StatelessWidget {
  const _FormResultBadge({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _formResultColor(context, result);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.tight),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: SizedBox.square(
        dimension: 30,
        child: Center(
          child: Text(
            _formResultLabel(result),
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _StandingsPanel extends StatelessWidget {
  const _StandingsPanel({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final standings = _standingsRows();

    if (standings.isEmpty) {
      return const _AnalysisPlaceholder(tab: _AnalysisTab.standings);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${match.competition.name} · Saison en cours',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const _VerificationInsightLine(
                text: 'Championnat uniquement · Amicaux et coupes exclus',
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 560),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        const _StandingCompactRow.header(),
                        for (final standing in standings)
                          _StandingCompactRow(
                            standing: standing,
                            team: _teamForStanding(standing),
                            highlight: _highlightForStanding(standing),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _StandingGapCard(match: match),
            ],
          ),
        ),
      ),
    );
  }

  List<TeamStandingSnapshot> _standingsRows() {
    final fullTable = match.analysis.leagueStandings;
    if (fullTable.isNotEmpty) {
      return fullTable;
    }

    final fallback = [
      if (match.analysis.homeStanding != null) match.analysis.homeStanding!,
      if (match.analysis.awayStanding != null) match.analysis.awayStanding!,
    ];
    fallback.sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
    return fallback;
  }

  TeamInfo? _teamForStanding(TeamStandingSnapshot standing) {
    if (_isHomeStanding(standing)) {
      return match.homeTeam;
    }
    if (_isAwayStanding(standing)) {
      return match.awayTeam;
    }
    return null;
  }

  _StandingHighlight _highlightForStanding(TeamStandingSnapshot standing) {
    if (_isHomeStanding(standing)) {
      return _StandingHighlight.home;
    }
    if (_isAwayStanding(standing)) {
      return _StandingHighlight.away;
    }
    return _StandingHighlight.none;
  }

  bool _isHomeStanding(TeamStandingSnapshot standing) {
    return standing.teamId == match.homeTeam.apiFootballTeamId ||
        standing.teamName == match.homeTeam.name;
  }

  bool _isAwayStanding(TeamStandingSnapshot standing) {
    return standing.teamId == match.awayTeam.apiFootballTeamId ||
        standing.teamName == match.awayTeam.name;
  }
}

enum _StandingHighlight { none, home, away }

class _StandingGapCard extends StatelessWidget {
  const _StandingGapCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final home = match.analysis.homeStanding;
    final away = match.analysis.awayStanding;

    if (home == null || away == null) {
      return const _VerificationInsightLine(
        text: 'Donnée de classement indisponible pour une des deux équipes.',
      );
    }

    final rankGap = _gap(home.rank, away.rank);
    final pointsGap = _gap(home.points, away.points);
    final goalDiffGap = _gap(home.goalDiff, away.goalDiff);
    final leader = _leaderName(match, home.points, away.points);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Écart entre les deux équipes',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _GapMetric(label: 'Places d’écart', value: rankGap),
                _GapMetric(label: 'Points d’écart', value: pointsGap),
                _GapMetric(label: 'Différence de buts', value: goalDiffGap),
              ],
            ),
            const SizedBox(height: 10),
            _VerificationInsightLine(
              text: leader == null
                  ? 'Les deux équipes sont proches au classement disponible.'
                  : '$leader possède actuellement ${pointsGap ?? 0} point(s) d’avance sur l’autre équipe.',
            ),
          ],
        ),
      ),
    );
  }

  int? _gap(int? a, int? b) {
    if (a == null || b == null) {
      return null;
    }
    return (a - b).abs();
  }

  String? _leaderName(MatchBoardItem match, int? homePoints, int? awayPoints) {
    if (homePoints == null || awayPoints == null || homePoints == awayPoints) {
      return null;
    }
    return homePoints > awayPoints ? match.homeTeam.name : match.awayTeam.name;
  }
}

class _GapMetric extends StatelessWidget {
  const _GapMetric({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 128,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value?.toString() ?? '—',
            style: theme.textTheme.titleLarge?.copyWith(
              color: context.semantic.warning,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationInsightLine extends StatelessWidget {
  const _VerificationInsightLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StandingCompactRow extends StatelessWidget {
  const _StandingCompactRow({
    required this.standing,
    required this.team,
    required this.highlight,
  }) : isHeader = false;

  const _StandingCompactRow.header()
    : standing = null,
      team = null,
      highlight = _StandingHighlight.none,
      isHeader = true;

  final TeamStandingSnapshot? standing;
  final TeamInfo? team;
  final _StandingHighlight highlight;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semantic;
    final accent = switch (highlight) {
      _StandingHighlight.home => colorScheme.primary,
      _StandingHighlight.away => semantic.warning,
      _StandingHighlight.none => colorScheme.outlineVariant,
    };
    final textColor = isHeader
        ? colorScheme.onSurfaceVariant
        : highlight == _StandingHighlight.none
        ? colorScheme.onSurface
        : accent;
    final rowBackground = isHeader
        ? AppColors.transparent
        : highlight == _StandingHighlight.none
        ? AppColors.transparent
        : accent.withValues(alpha: 0.10);
    final borderColor = isHeader
        ? colorScheme.outlineVariant
        : highlight == _StandingHighlight.none
        ? colorScheme.outlineVariant.withValues(alpha: 0.55)
        : accent.withValues(alpha: 0.75);

    if (isHeader) {
      return _StandingRowShell(
        borderColor: borderColor,
        backgroundColor: rowBackground,
        child: Row(
          children: [
            _StandingCell('#', width: 34, color: textColor, isHeader: true),
            _StandingCell(
              'Équipe',
              width: 190,
              color: textColor,
              isHeader: true,
              alignment: Alignment.centerLeft,
            ),
            _StandingCell('MJ', width: 48, color: textColor, isHeader: true),
            _StandingCell('Pts', width: 52, color: textColor, isHeader: true),
            _StandingCell('Diff', width: 56, color: textColor, isHeader: true),
            _StandingCell(
              'Buts pour',
              width: 74,
              color: textColor,
              isHeader: true,
            ),
            _StandingCell(
              'Buts contre',
              width: 86,
              color: textColor,
              isHeader: true,
            ),
          ],
        ),
      );
    }

    final standing = this.standing!;

    return _StandingRowShell(
      borderColor: borderColor,
      backgroundColor: rowBackground,
      child: Row(
        children: [
          _StandingCell(
            _value(standing.rank),
            width: 34,
            color: textColor,
            isHeader: false,
          ),
          SizedBox(
            width: 190,
            child: Row(
              children: [
                if (team != null) ...[
                  SportsAssetBadge(
                    size: 24,
                    imageUrl: team!.logoUrl,
                    fallbackLabel: team!.name,
                    borderRadius: 5,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    standing.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor,
                      fontWeight: highlight == _StandingHighlight.none
                          ? FontWeight.w700
                          : FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _StandingCell(_value(standing.played), width: 48, color: textColor),
          _StandingCell(_value(standing.points), width: 52, color: textColor),
          _StandingCell(
            _signed(standing.goalDiff),
            width: 56,
            color: textColor,
          ),
          _StandingCell(_value(standing.goalsFor), width: 74, color: textColor),
          _StandingCell(
            _value(standing.goalsAgainst),
            width: 86,
            color: textColor,
          ),
        ],
      ),
    );
  }

  static String _value(int? value) => value?.toString() ?? '–';

  static String _signed(int? value) {
    if (value == null) {
      return '–';
    }
    return value > 0 ? '+$value' : '$value';
  }
}

class _StandingRowShell extends StatelessWidget {
  const _StandingRowShell({
    required this.child,
    required this.borderColor,
    required this.backgroundColor,
  });

  final Widget child;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: child,
      ),
    );
  }
}

class _StandingCell extends StatelessWidget {
  const _StandingCell(
    this.value, {
    required this.width,
    required this.color,
    this.isHeader = false,
    this.alignment = Alignment.center,
  });

  final String value;
  final double width;
  final Color color;
  final bool isHeader;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Align(
        alignment: alignment,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (isHeader
                      ? theme.textTheme.labelSmall
                      : theme.textTheme.bodySmall)
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _HomeAwayPanel extends StatelessWidget {
  const _HomeAwayPanel({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final homeStats = match.analysis.homeStatistics;
    final awayStats = match.analysis.awayStatistics;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SplitTeamBlock(
              team: match.homeTeam,
              emphasizedColumn: _SplitColumn.home,
              values: _SplitTableValues.from(homeStats),
            ),
            Divider(height: 24, color: colorScheme.outlineVariant),
            _SplitTeamBlock(
              team: match.awayTeam,
              emphasizedColumn: _SplitColumn.away,
              values: _SplitTableValues.from(awayStats),
            ),
            const SizedBox(height: 12),
            _VerificationInsightLine(
              text: _homeAwayText(match, homeStats, awayStats),
            ),
          ],
        ),
      ),
    );
  }

  String _homeAwayText(
    MatchBoardItem match,
    TeamStatisticsSnapshot? homeStats,
    TeamStatisticsSnapshot? awayStats,
  ) {
    final homePoints = _pointsPerMatch(
      homeStats?.winsHome,
      homeStats?.drawsHome,
      homeStats?.playedHome,
    );
    final awayPoints = _pointsPerMatch(
      awayStats?.winsAway,
      awayStats?.drawsAway,
      awayStats?.playedAway,
    );

    if (homePoints == null || awayPoints == null) {
      return 'Stats domicile/extérieur indisponibles pour produire une comparaison fiable.';
    }

    if (homePoints == awayPoints) {
      return 'Les splits disponibles montrent un rendement domicile/extérieur comparable.';
    }

    return homePoints > awayPoints
        ? '${match.homeTeam.name} présente un meilleur rendement à domicile que ${match.awayTeam.name} à l’extérieur.'
        : '${match.awayTeam.name} voyage mieux que le rendement domicile de ${match.homeTeam.name}.';
  }
}

enum _SplitColumn { home, away }

class _SplitTableValues {
  const _SplitTableValues({
    required this.home,
    required this.away,
    required this.homePointsPerMatch,
    required this.awayPointsPerMatch,
  });

  factory _SplitTableValues.from(TeamStatisticsSnapshot? stats) {
    return _SplitTableValues(
      home: _SplitSideValues(
        played: stats?.playedHome,
        wins: stats?.winsHome,
        draws: stats?.drawsHome,
        losses: stats?.lossesHome,
        goalsFor: stats?.goalsForHome,
        goalsAgainst: stats?.goalsAgainstHome,
        goalsForAverage: stats?.goalsForAverageHome,
        goalsAgainstAverage: stats?.goalsAgainstAverageHome,
        cleanSheets: stats?.cleanSheetsHome,
        failedToScore: stats?.failedToScoreHome,
      ),
      away: _SplitSideValues(
        played: stats?.playedAway,
        wins: stats?.winsAway,
        draws: stats?.drawsAway,
        losses: stats?.lossesAway,
        goalsFor: stats?.goalsForAway,
        goalsAgainst: stats?.goalsAgainstAway,
        goalsForAverage: stats?.goalsForAverageAway,
        goalsAgainstAverage: stats?.goalsAgainstAverageAway,
        cleanSheets: stats?.cleanSheetsAway,
        failedToScore: stats?.failedToScoreAway,
      ),
      homePointsPerMatch: _pointsPerMatch(
        stats?.winsHome,
        stats?.drawsHome,
        stats?.playedHome,
      ),
      awayPointsPerMatch: _pointsPerMatch(
        stats?.winsAway,
        stats?.drawsAway,
        stats?.playedAway,
      ),
    );
  }

  final _SplitSideValues home;
  final _SplitSideValues away;
  final double? homePointsPerMatch;
  final double? awayPointsPerMatch;

  bool get isEmpty => home.isEmpty && away.isEmpty;
}

class _SplitSideValues {
  const _SplitSideValues({
    this.played,
    this.wins,
    this.draws,
    this.losses,
    this.goalsFor,
    this.goalsAgainst,
    this.goalsForAverage,
    this.goalsAgainstAverage,
    this.cleanSheets,
    this.failedToScore,
  });

  final int? played;
  final int? wins;
  final int? draws;
  final int? losses;
  final int? goalsFor;
  final int? goalsAgainst;
  final double? goalsForAverage;
  final double? goalsAgainstAverage;
  final int? cleanSheets;
  final int? failedToScore;

  bool get isEmpty =>
      played == null &&
      wins == null &&
      draws == null &&
      losses == null &&
      goalsFor == null &&
      goalsAgainst == null &&
      goalsForAverage == null &&
      goalsAgainstAverage == null &&
      cleanSheets == null &&
      failedToScore == null;
}

class _SplitTeamBlock extends StatelessWidget {
  const _SplitTeamBlock({
    required this.team,
    required this.emphasizedColumn,
    required this.values,
  });

  final TeamInfo team;
  final _SplitColumn emphasizedColumn;
  final _SplitTableValues values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SportsAssetBadge(
              size: 26,
              imageUrl: team.logoUrl,
              fallbackLabel: team.name,
              borderRadius: AppRadius.tight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                team.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (values.isEmpty)
          Text(
            'Stats domicile/extérieur indisponibles dans le snapshot actuel.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          _SplitTable(values: values, emphasizedColumn: emphasizedColumn),
      ],
    );
  }
}

class _SplitTable extends StatelessWidget {
  const _SplitTable({required this.values, required this.emphasizedColumn});

  final _SplitTableValues values;
  final _SplitColumn emphasizedColumn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            _SplitTableRow.header(emphasizedColumn: emphasizedColumn),
            _SplitTableRow(
              label: 'MJ',
              home: _value(values.home.played),
              away: _value(values.away.played),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'V / N / D',
              home: _record(values.home),
              away: _record(values.away),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Points / match',
              home: _decimal(values.homePointsPerMatch),
              away: _decimal(values.awayPointsPerMatch),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Buts pour',
              home: _value(values.home.goalsFor),
              away: _value(values.away.goalsFor),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Buts contre',
              home: _value(values.home.goalsAgainst),
              away: _value(values.away.goalsAgainst),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Buts / match',
              home: _decimal(values.home.goalsForAverage),
              away: _decimal(values.away.goalsForAverage),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Buts c. / match',
              home: _decimal(values.home.goalsAgainstAverage),
              away: _decimal(values.away.goalsAgainstAverage),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Clean sheets',
              home: _value(values.home.cleanSheets),
              away: _value(values.away.cleanSheets),
              emphasizedColumn: emphasizedColumn,
            ),
            _SplitTableRow(
              label: 'Sans marquer',
              home: _value(values.home.failedToScore),
              away: _value(values.away.failedToScore),
              emphasizedColumn: emphasizedColumn,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  static String _value(int? value) => value?.toString() ?? '—';

  static String _decimal(double? value) => value?.toStringAsFixed(2) ?? '—';

  static String _record(_SplitSideValues values) {
    if (values.wins == null || values.draws == null || values.losses == null) {
      return '—';
    }
    return '${values.wins} / ${values.draws} / ${values.losses}';
  }
}

class _SplitTableRow extends StatelessWidget {
  const _SplitTableRow({
    required this.label,
    required this.home,
    required this.away,
    required this.emphasizedColumn,
    this.isLast = false,
  }) : isHeader = false;

  const _SplitTableRow.header({required this.emphasizedColumn})
    : label = '',
      home = 'À domicile',
      away = 'À l’extérieur',
      isLast = false,
      isHeader = true;

  final String label;
  final String home;
  final String away;
  final _SplitColumn emphasizedColumn;
  final bool isLast;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isHeader ? 4 : 7),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _SplitValueCell(
              value: home,
              isHeader: isHeader,
              isEmphasized: emphasizedColumn == _SplitColumn.home,
            ),
            _SplitValueCell(
              value: away,
              isHeader: isHeader,
              isEmphasized: emphasizedColumn == _SplitColumn.away,
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitValueCell extends StatelessWidget {
  const _SplitValueCell({
    required this.value,
    required this.isHeader,
    required this.isEmphasized,
  });

  final String value;
  final bool isHeader;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      flex: 3,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style:
            (isHeader ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
                ?.copyWith(
                  color: isEmphasized
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: isEmphasized || isHeader
                      ? FontWeight.w900
                      : FontWeight.w700,
                ),
      ),
    );
  }
}

class _AttackDefensePanel extends StatelessWidget {
  const _AttackDefensePanel({required this.match, required this.opportunity});

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = _rows();

    if (rows.isEmpty) {
      return const _AnalysisPlaceholder(tab: _AnalysisTab.attackDefense);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 48,
                horizontalMargin: 8,
                columnSpacing: 24,
                columns: [
                  const DataColumn(label: Text('Statistique')),
                  DataColumn(label: Text(match.homeTeam.name)),
                  DataColumn(label: Text(match.awayTeam.name)),
                  const DataColumn(label: Text('Avantage')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      color: WidgetStatePropertyAll(
                        row.highlight
                            ? colorScheme.primary.withValues(alpha: 0.08)
                            : AppColors.transparent,
                      ),
                      cells: [
                        DataCell(Text(row.label)),
                        DataCell(Text(row.home)),
                        DataCell(Text(row.away)),
                        DataCell(Text(row.advantage)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _VerificationInsightLine(text: _attackDefenseText(rows)),
          ],
        ),
      ),
    );
  }

  List<_ComparisonRow> _rows() {
    final homeStats = match.analysis.homeStatistics;
    final awayStats = match.analysis.awayStatistics;
    final homeXg = match.analysis.homeExpectedGoals;
    final awayXg = match.analysis.awayExpectedGoals;
    final highlightedKinds = _highlightedKinds();

    return [
      ?_comparison(
        label: 'Buts marqués / match',
        home: homeStats?.goalsForAverageTotal,
        away: awayStats?.goalsForAverageTotal,
        highIsBetter: true,
        highlight: highlightedKinds.contains(_VerificationKind.attack),
      ),
      ?_comparison(
        label: 'Buts encaissés / match',
        home: homeStats?.goalsAgainstAverageTotal,
        away: awayStats?.goalsAgainstAverageTotal,
        highIsBetter: false,
        highlight: highlightedKinds.contains(_VerificationKind.defense),
      ),
      ?_comparison(
        label: 'xG',
        home: homeXg?.seasonXgForAverage ?? homeXg?.rollingXgFor5,
        away: awayXg?.seasonXgForAverage ?? awayXg?.rollingXgFor5,
        highIsBetter: true,
        highlight: highlightedKinds.contains(_VerificationKind.xg),
      ),
      ?_comparison(
        label: 'xGA',
        home: homeXg?.seasonXgAgainstAverage ?? homeXg?.rollingXgAgainst5,
        away: awayXg?.seasonXgAgainstAverage ?? awayXg?.rollingXgAgainst5,
        highIsBetter: false,
        highlight: highlightedKinds.contains(_VerificationKind.xg),
      ),
      ?_comparisonInt(
        label: 'Clean sheets',
        home: homeStats?.cleanSheetsTotal,
        away: awayStats?.cleanSheetsTotal,
        highIsBetter: true,
        highlight: highlightedKinds.contains(_VerificationKind.defense),
      ),
      ?_comparisonInt(
        label: 'Sans marquer',
        home: homeStats?.failedToScoreTotal,
        away: awayStats?.failedToScoreTotal,
        highIsBetter: false,
        highlight: highlightedKinds.contains(_VerificationKind.attack),
      ),
    ];
  }

  Set<_VerificationKind> _highlightedKinds() {
    final arguments =
        opportunity?.positiveArguments ?? match.thesis?.arguments ?? const [];
    return {
      for (final argument in arguments)
        switch (argument.family) {
          CopilotArgumentFamily.attack => _VerificationKind.attack,
          CopilotArgumentFamily.defense => _VerificationKind.defense,
          CopilotArgumentFamily.rhythm => _VerificationKind.attack,
          _ => _VerificationKind.other,
        },
    };
  }

  _ComparisonRow? _comparison({
    required String label,
    required double? home,
    required double? away,
    required bool highIsBetter,
    required bool highlight,
  }) {
    if (home == null || away == null) {
      return null;
    }
    final advantage = _advantage(home, away, highIsBetter);
    return _ComparisonRow(
      label: label,
      home: home.toStringAsFixed(2),
      away: away.toStringAsFixed(2),
      advantage: advantage,
      highlight: highlight,
    );
  }

  _ComparisonRow? _comparisonInt({
    required String label,
    required int? home,
    required int? away,
    required bool highIsBetter,
    required bool highlight,
  }) {
    if (home == null || away == null) {
      return null;
    }
    final advantage = _advantage(
      home.toDouble(),
      away.toDouble(),
      highIsBetter,
    );
    return _ComparisonRow(
      label: label,
      home: '$home',
      away: '$away',
      advantage: advantage,
      highlight: highlight,
    );
  }

  String _advantage(double home, double away, bool highIsBetter) {
    if (home == away) {
      return 'Égal';
    }
    final homeBetter = highIsBetter ? home > away : home < away;
    return homeBetter ? match.homeTeam.name : match.awayTeam.name;
  }

  String _attackDefenseText(List<_ComparisonRow> rows) {
    final highlighted = rows.where((row) => row.highlight).length;
    if (highlighted > 0) {
      return '$highlighted donnée(s) de ce tableau ont contribué à la lecture affichée plus haut.';
    }
    return 'Ces métriques permettent de contrôler le lien entre volume offensif, solidité défensive et lecture combinée.';
  }
}

enum _VerificationKind { attack, defense, xg, other }

class _ComparisonRow {
  const _ComparisonRow({
    required this.label,
    required this.home,
    required this.away,
    required this.advantage,
    required this.highlight,
  });

  final String label;
  final String home;
  final String away;
  final String advantage;
  final bool highlight;
}

class _SeriesPanel extends StatelessWidget {
  const _SeriesPanel({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TeamSeriesBlock(
              team: match.homeTeam,
              statistics: match.analysis.homeStatistics,
              standing: match.analysis.homeStanding,
            ),
            Divider(height: 24, color: colorScheme.outlineVariant),
            _TeamSeriesBlock(
              team: match.awayTeam,
              statistics: match.analysis.awayStatistics,
              standing: match.analysis.awayStanding,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSeriesBlock extends StatelessWidget {
  const _TeamSeriesBlock({
    required this.team,
    required this.statistics,
    required this.standing,
  });

  final TeamInfo team;
  final TeamStatisticsSnapshot? statistics;
  final TeamStandingSnapshot? standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final results = _matchDetailLastFiveResults(
      statistics?.form ?? standing?.form,
    );
    final series = _seriesFrom(results);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SportsAssetBadge(
              size: 26,
              imageUrl: team.logoUrl,
              fallbackLabel: team.name,
              borderRadius: AppRadius.tight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                team.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (series.isEmpty)
          Text(
            'Séries indisponibles dans le snapshot actuel.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            children: [
              for (final item in series)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _SeriesLine(text: item),
                ),
            ],
          ),
      ],
    );
  }

  List<String> _seriesFrom(List<String> results) {
    if (results.isEmpty) {
      return const [];
    }

    final wins = results.where((result) => result == 'W').length;
    final draws = results.where((result) => result == 'D').length;
    final losses = results.where((result) => result == 'L').length;
    final series = <String>[
      '$wins victoire(s) sur ${results.length} derniers résultats disponibles',
      '$draws nul(s) sur ${results.length}',
      '$losses défaite(s) sur ${results.length}',
    ];

    final first = results.first;
    final currentRun = results.takeWhile((result) => result == first).length;
    if (currentRun >= 2) {
      final label = switch (first) {
        'W' => 'victoires consécutives',
        'D' => 'nuls consécutifs',
        _ => 'défaites consécutives',
      };
      series.add('$currentRun $label');
    }

    return series;
  }
}

class _SeriesLine extends StatelessWidget {
  const _SeriesLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: theme.colorScheme.primary,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

double? _pointsPerMatch(int? wins, int? draws, int? played) {
  if (wins == null || draws == null || played == null || played == 0) {
    return null;
  }

  return ((wins * 3) + draws) / played;
}

List<String> _matchDetailLastFiveResults(String? form) {
  if (form == null) {
    return const [];
  }

  return form
      .trim()
      .toUpperCase()
      .split('')
      .where((result) => result == 'W' || result == 'D' || result == 'L')
      .take(5)
      .toList(growable: false);
}

class _MarketsSection extends StatefulWidget {
  const _MarketsSection({
    required this.match,
    required this.opportunity,
    required this.markets,
    required this.ticketDraftListenable,
    required this.onToggleTicket,
  });

  final MatchBoardItem match;
  final Opportunity? opportunity;
  final List<MatchMarket> markets;
  final ValueListenable<TicketDraft>? ticketDraftListenable;
  final ValueChanged<TicketDraftSelection>? onToggleTicket;

  @override
  State<_MarketsSection> createState() => _MarketsSectionState();
}

class _MarketsSectionState extends State<_MarketsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recommendedMarket = _recommendedMarketForDetail(
      widget.match,
      widget.opportunity,
    );
    final theses =
        widget.opportunity?.retainedTheses ??
        [if (widget.match.thesis != null) widget.match.thesis!];
    final compatibleMarkets = [
      for (final candidate in widget.match.betCandidates)
        if (widget.match.recommendedMarketFor(candidate) case final market?)
          OpportunityMarketCompatibility(
            thesisId:
                candidate.supportingScenarioIds.firstOrNull ??
                candidate.supportingThesisIds.firstOrNull ??
                'market_assessment',
            market: market.market,
            selection: market.selection,
            isRecommended: candidate == widget.match.suggestedBetCandidate,
          ),
    ];
    final isOutOfProfile =
        widget.match.profileStatus == MatchProfileStatus.outOfProfile;
    final summary = recommendedMarket == null || isOutOfProfile
        ? 'Aucun marché'
        : '${recommendedMarket.market.label} · ${recommendedMarket.selection.label}';

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollapsibleHeader(
            icon: Icons.track_changes_rounded,
            title: 'Marchés et cotes',
            summary: summary,
            isOpen: _isExpanded,
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 14),
            if (isOutOfProfile || recommendedMarket == null)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Text(
                          'Aucun pari clair à proposer',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOutOfProfile
                              ? 'Cette compétition n’est pas dans votre profil.\nActivez-la pour recevoir des marchés adaptés.'
                              : 'Les signaux disponibles ne permettent pas de dégager un marché suffisamment net pour votre configuration.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isOutOfProfile) ...[
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Ajout de ${widget.match.competition.name} au profil à brancher.',
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Ajouter ${widget.match.competition.name} à mon profil',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (!isOutOfProfile && recommendedMarket != null)
              _RecommendedMarketPanel(
                match: widget.match,
                recommendedMarket: recommendedMarket,
                rationale: OpportunityDecisionPresenter.marketRationale(
                  recommendedMarket: recommendedMarket,
                  theses: theses,
                ),
                ticketDraftListenable: widget.ticketDraftListenable,
                onToggleTicket: widget.onToggleTicket,
              ),
            if (compatibleMarkets.isNotEmpty) ...[
              const SizedBox(height: 16),
              _CompatibleMarketsWrap(markets: compatibleMarkets),
            ],
            if (widget.markets.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: colorScheme.outlineVariant),
              const SizedBox(height: 14),
              Text(
                'Cotes disponibles',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tous les marchés normalisés présents dans le snapshot.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _RawApiMarketsDisclosure(markets: widget.markets),
            ],
          ],
        ],
      ),
    );
  }
}

class _CompatibleMarketsWrap extends StatelessWidget {
  const _CompatibleMarketsWrap({required this.markets});

  final List<OpportunityMarketCompatibility> markets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final otherMarkets = markets.where((item) => !item.isRecommended).toList();

    if (otherMarkets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Autres marchés compatibles',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in otherMarkets.take(6))
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.market.label} · ${item.selection.label}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.selection.odds.toStringAsFixed(2),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RawApiMarketsDisclosure extends StatefulWidget {
  const _RawApiMarketsDisclosure({required this.markets});

  final List<MatchMarket> markets;

  @override
  State<_RawApiMarketsDisclosure> createState() =>
      _RawApiMarketsDisclosureState();
}

class _RawApiMarketsDisclosureState extends State<_RawApiMarketsDisclosure> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectionCount = widget.markets.fold<int>(
      0,
      (total, market) => total + market.selections.length,
    );

    return Material(
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _isOpen = !_isOpen;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dataset_outlined, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cotes API disponibles',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.markets.length} marché(s) · $selectionCount cote(s) · API-Football',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (_isOpen) ...[
                const SizedBox(height: 14),
                for (final market in widget.markets)
                  _MarketPanel(market: market),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketPanel extends StatefulWidget {
  const _MarketPanel({required this.market});

  final MatchMarket market;

  @override
  State<_MarketPanel> createState() => _MarketPanelState();
}

class _MarketPanelState extends State<_MarketPanel> {
  static const _visibleSelectionLimit = 6;

  bool _isOpen = false;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final market = widget.market;
    final visibleSelections = _isExpanded
        ? market.selections
        : market.selections.take(_visibleSelectionLimit).toList();
    final hiddenCount = market.selections.length - visibleSelections.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: () {
            setState(() {
              _isOpen = !_isOpen;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        market.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (market.bookmakerName != null)
                      Text(
                        market.bookmakerName!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      _isOpen
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (!_isOpen) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${market.selections.length} cote(s) disponible(s)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_isOpen) ...[
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      for (final row in _selectionRows(visibleSelections))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SelectionOddPill(selection: row.first),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: row.length > 1
                                    ? _SelectionOddPill(selection: row[1])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (market.selections.length > _visibleSelectionLimit)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        icon: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _isExpanded
                              ? l10n.showLessMarketsButton
                              : l10n.showMoreMarketsButton(hiddenCount),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<List<MarketOdds>> _selectionRows(List<MarketOdds> selections) {
    final rows = <List<MarketOdds>>[];

    for (var index = 0; index < selections.length; index += 2) {
      rows.add(
        selections.sublist(
          index,
          index + 2 > selections.length ? selections.length : index + 2,
        ),
      );
    }

    return rows;
  }
}

class _SelectionOddPill extends StatelessWidget {
  const _SelectionOddPill({required this.selection});

  final MarketOdds selection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.tight),
      ),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selection.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                selection.odds.toStringAsFixed(2),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
