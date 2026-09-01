// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/deck/lector_deck.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/lector_brand_mark.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../opportunities/domain/opportunity.dart';
import '../../tickets/domain/ticket_draft.dart';
import '../../tickets/domain/saved_ticket.dart';
import '../../tickets/domain/ticket_strategy.dart';
import '../../tickets/presentation/ticket_builder_panel.dart';
import '../domain/match_board_item.dart';
import 'opportunity_decision_presenter.dart';
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

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  int _selectedFreeTab = 0;
  bool _isTicketPanelExpanded = false;

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
                      const SizedBox(height: 12),
                      _LectorScenarioCard(
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
        onOpenReadings: () => _showScenarioReadingsSheet(context, widget.match),
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
    final recommendedMarket =
        widget.opportunity?.recommendedMarket ??
        widget.match.thesis?.recommendedMarket;
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
    final surfaces = context.surfaces;
    final brand = context.brand;

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
    final textColors = context.textColors;
    final venueLabel = _venueValue(match.fixture.venue);

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
                backgroundColor: AppColors.transparent,
                padding: 1,
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
                        color: textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Journée 34',
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
                  color: textColors.secondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    venueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColors.secondary,
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
    final textColors = context.textColors;

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
            color: textColors.primary,
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
    final textColors = context.textColors;
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
                color: textColors.primary,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            )
          else
            Text(
              '-',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: textColors.primary,
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

class _LectorScenarioCard extends StatelessWidget {
  const _LectorScenarioCard({required this.match, this.opportunity});

  final MatchBoardItem match;
  final Opportunity? opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    final title = _scenarioTitle(match);
    final count = _scenarioReadingCount(match);
    final recommendedMarket = _scenarioRecommendedMarket(match, opportunity);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => _showScenarioReadingsSheet(context, match),
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: _LectorGlassCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
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
                  _ScenarioMiniDuel(match: match),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _scenarioSummary(match),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColors.secondary,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              Divider(height: 1, color: surfaces.border),
              const SizedBox(height: 7),
              Row(
                children: [
                  if (_hasScenarioRecommendedPick(recommendedMarket))
                    Expanded(
                      flex: 3,
                      child: _ScenarioRecommendedPick(
                        match: match,
                        recommendedMarket: recommendedMarket!,
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              _showScenarioReadingsSheet(context, match),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: brand.accent,
                          ),
                          label: Text(
                            'Voir les $count lectures',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: brand.accent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                          ),
                          iconAlignment: IconAlignment.end,
                        ),
                      ),
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

class _ScenarioRecommendedPick extends StatelessWidget {
  const _ScenarioRecommendedPick({
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
    final selection = recommendedMarket.selection;
    final label = _scenarioRecommendedPickLabel(match, recommendedMarket);

    if (label == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 64) {
          return Align(
            alignment: Alignment.centerLeft,
            child: _ScenarioOddsBadge(odds: selection.odds),
          );
        }

        if (constraints.maxWidth < 220) {
          return Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: brand.accent,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ScenarioOddsBadge(odds: selection.odds),
            ],
          );
        }

        return Row(
          children: [
            Icon(Icons.trending_up_rounded, color: brand.accent, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Pronostic envisagé · ',
                      style: TextStyle(color: textColors.secondary),
                    ),
                    TextSpan(
                      text: label,
                      style: TextStyle(color: brand.accent),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ScenarioOddsBadge(odds: selection.odds),
          ],
        );
      },
    );
  }
}

class _ScenarioOddsBadge extends StatelessWidget {
  const _ScenarioOddsBadge({required this.odds});

  final double odds;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: brand.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: brand.accent.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: SizedBox(
          width: 42,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                odds.toStringAsFixed(2),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: brand.accent,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenarioMiniDuel extends StatelessWidget {
  const _ScenarioMiniDuel({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final homePoints = match.analysis.homeStanding?.points;
    final awayPoints = match.analysis.awayStanding?.points;
    final brand = context.brand;
    final surfaces = context.surfaces;

    final total = (homePoints ?? 0) + (awayPoints ?? 0);
    final homeFlex = total <= 0
        ? 1
        : ((homePoints ?? 0) * 100).clamp(16, 84).toInt();
    final awayFlex = total <= 0
        ? 1
        : ((awayPoints ?? 0) * 100).clamp(16, 84).toInt();

    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SportsAssetBadge(
                size: 22,
                imageUrl: match.homeTeam.logoUrl,
                fallbackLabel: match.homeTeam.name,
                backgroundColor: AppColors.transparent,
                padding: 1,
              ),
              const SizedBox(width: 8),
              SportsAssetBadge(
                size: 22,
                imageUrl: match.awayTeam.logoUrl,
                fallbackLabel: match.awayTeam.name,
                backgroundColor: AppColors.transparent,
                padding: 1,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.indicator),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: homeFlex,
                    child: ColoredBox(color: brand.accent),
                  ),
                  Expanded(
                    flex: awayFlex,
                    child: ColoredBox(color: surfaces.border),
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
  });

  final MatchBoardItem match;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return switch (selectedIndex) {
      0 => _LectorQuickContextCard(match: match),
      1 => _LectorStandingContextCard(match: match),
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
    final surfaces = context.surfaces;
    final homeForm = _matchDetailLastFiveResults(
      match.analysis.homeStatistics?.form ?? match.analysis.homeStanding?.form,
    );
    final awayForm = _matchDetailLastFiveResults(
      match.analysis.awayStatistics?.form ?? match.analysis.awayStanding?.form,
    );

    return _LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CONTEXTE RAPIDE',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: textColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Les éléments clés à retenir en un coup d’œil.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _ContextComparisonRow(
            icon: Icons.bar_chart_rounded,
            label: 'CLASSEMENT',
            home: _TeamMetricSummary(
              logoUrl: match.homeTeam.logoUrl,
              fallbackLabel: match.homeTeam.name,
              value: _rankLabel(match.analysis.homeStanding),
              detail: _pointsLabel(match.analysis.homeStanding),
              accent: brand.accent,
              alignRight: false,
            ),
            center: _ContextDeltaPill(
              primary: _rankGapLabel(match),
              secondary: _pointsGapLabel(match),
            ),
            away: _TeamMetricSummary(
              logoUrl: match.awayTeam.logoUrl,
              fallbackLabel: match.awayTeam.name,
              value: _rankLabel(match.analysis.awayStanding),
              detail: _pointsLabel(match.analysis.awayStanding),
              accent: textColors.secondary,
              alignRight: true,
            ),
          ),
          Divider(height: 12, color: surfaces.border),
          _ContextComparisonRow(
            icon: Icons.monitor_heart_outlined,
            label: 'FORME · 5 DERNIERS MATCHS',
            home: _TeamFormSummary(results: homeForm),
            center: _ContextDeltaPill(
              primary: _formGapLabel(homeForm, awayForm),
              secondary: 'sur les 5 derniers matchs',
            ),
            away: _TeamFormSummary(results: awayForm, alignRight: true),
          ),
          Divider(height: 12, color: surfaces.border),
          _ContextComparisonRow(
            icon: Icons.home_outlined,
            label: 'DOMICILE / EXTÉRIEUR',
            home: _HomeAwaySummary(
              title: '${match.homeTeam.name} à domicile',
              wins: match.analysis.homeStatistics?.winsHome,
              draws: match.analysis.homeStatistics?.drawsHome,
              losses: match.analysis.homeStatistics?.lossesHome,
              played: match.analysis.homeStatistics?.playedHome,
            ),
            center: _ContextDeltaPill(
              primary: _homeAwayGapLabel(match),
              secondary: 'écart contextuel',
            ),
            away: _HomeAwaySummary(
              title: '${match.awayTeam.name} à l’extérieur',
              wins: match.analysis.awayStatistics?.winsAway,
              draws: match.analysis.awayStatistics?.drawsAway,
              losses: match.analysis.awayStatistics?.lossesAway,
              played: match.analysis.awayStatistics?.playedAway,
              alignRight: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: brand.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ces éléments contribuent à la lecture « ${_scenarioTitle(match)} »',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: textColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
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
    final brand = context.brand;
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
                style: TextStyle(color: brand.accent),
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
    final brand = context.brand;
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
                style: TextStyle(color: brand.accent),
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
    final brand = context.brand;
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
              color: brand.accent,
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

class _LectorStandingContextCard extends StatelessWidget {
  const _LectorStandingContextCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    final standings = _mobileStandingRows(match);

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
            'Position, points et dynamique dans le championnat.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: surfaces.border),
          const SizedBox(height: 10),
          _StandingMatchSummary(match: match),
          const SizedBox(height: 10),
          Divider(height: 1, color: surfaces.border),
          const SizedBox(height: 10),
          _StandingTableHeaderTitle(match: match),
          const SizedBox(height: 8),
          _MobileStandingTable(match: match, standings: standings),
          const SizedBox(height: 10),
          _StandingInsightStrip(match: match),
        ],
      ),
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
  const _MobileStandingTable({required this.match, required this.standings});

  final MatchBoardItem match;
  final List<TeamStandingSnapshot> standings;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaces.surfaceHover.withValues(alpha: 0.22),
          border: Border.all(color: surfaces.border),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 642,
            child: Column(
              children: [
                const _MobileStandingRow.header(),
                for (final standing in standings.take(10))
                  _MobileStandingRow(
                    standing: standing,
                    team: _standingTeam(match, standing),
                    highlight: _standingHighlight(match, standing),
                  ),
              ],
            ),
          ),
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
  }) : isHeader = false;

  const _MobileStandingRow.header()
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
    final brand = context.brand;
    final textColors = context.textColors;
    final surfaces = context.surfaces;
    final accent = switch (highlight) {
      _StandingHighlight.home => brand.accent,
      _StandingHighlight.away => context.opportunities.levelGap,
      _StandingHighlight.none => surfaces.border,
    };
    final rowColor = isHeader
        ? AppColors.transparent
        : highlight == _StandingHighlight.none
        ? AppColors.transparent
        : accent.withValues(alpha: 0.11);
    final borderColor = highlight == _StandingHighlight.none
        ? surfaces.border.withValues(alpha: 0.62)
        : accent.withValues(alpha: 0.82);
    final textColor = isHeader
        ? textColors.secondary
        : highlight == _StandingHighlight.none
        ? textColors.primary
        : textColors.primary;

    if (isHeader) {
      return _MobileStandingRowShell(
        backgroundColor: rowColor,
        borderColor: borderColor,
        child: Row(
          children: [
            _StandingTableCell(
              '#',
              width: 34,
              color: textColor,
              isHeader: true,
            ),
            _StandingTableCell(
              'Équipe',
              width: 164,
              color: textColor,
              isHeader: true,
              alignment: Alignment.centerLeft,
            ),
            _StandingTableCell(
              'J',
              width: 36,
              color: textColor,
              isHeader: true,
            ),
            _StandingTableCell(
              'V',
              width: 34,
              color: textColor,
              isHeader: true,
            ),
            _StandingTableCell(
              'N',
              width: 34,
              color: textColor,
              isHeader: true,
            ),
            _StandingTableCell(
              'D',
              width: 34,
              color: textColor,
              isHeader: true,
            ),
            _StandingTableCell(
              'BP',
              width: 42,
              color: textColor,
              isHeader: true,
            ),
            _StandingTableCell(
              'BC',
              width: 42,
              color: textColor,
              isHeader: true,
            ),
            _StandingTableCell(
              'Diff',
              width: 50,
              color: textColor,
              isHeader: true,
            ),
            _StandingTableCell(
              'Pts',
              width: 44,
              color: textColor,
              isHeader: true,
            ),
            _StandingTableCell(
              'Forme',
              width: 114,
              color: textColor,
              isHeader: true,
            ),
          ],
        ),
      );
    }

    final row = standing!;

    return _MobileStandingRowShell(
      backgroundColor: rowColor,
      borderColor: borderColor,
      child: Row(
        children: [
          _StandingTableCell(_intValue(row.rank), width: 34, color: textColor),
          SizedBox(
            width: 164,
            child: Row(
              children: [
                SportsAssetBadge(
                  size: 20,
                  imageUrl: team?.logoUrl,
                  fallbackLabel: row.teamName,
                  backgroundColor: AppColors.transparent,
                  padding: 1,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    row.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
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
          _StandingTableCell(
            _intValue(row.played),
            width: 36,
            color: textColor,
          ),
          _StandingTableCell(_intValue(row.wins), width: 34, color: textColor),
          _StandingTableCell(_intValue(row.draws), width: 34, color: textColor),
          _StandingTableCell(
            _intValue(row.losses),
            width: 34,
            color: textColor,
          ),
          _StandingTableCell(
            _intValue(row.goalsFor),
            width: 42,
            color: textColor,
          ),
          _StandingTableCell(
            _intValue(row.goalsAgainst),
            width: 42,
            color: textColor,
          ),
          _StandingTableCell(
            _signedValue(row.goalDiff),
            width: 50,
            color: _goalDiffColor(context, row.goalDiff),
          ),
          _StandingTableCell(
            _intValue(row.points),
            width: 44,
            color: textColor,
            bold: true,
          ),
          SizedBox(
            width: 114,
            child: Align(
              alignment: Alignment.centerRight,
              child: _StandingFormDots(
                results: _matchDetailLastFiveResults(row.form),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileStandingRowShell extends StatelessWidget {
  const _MobileStandingRowShell({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
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
      accent: context.brand.accent,
    );
    final awayCard = _LectorFormTeamCard(
      team: match.awayTeam,
      results: awayResults,
      stats: awayStats,
      accent: context.opportunities.levelGap,
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
    required this.accent,
    this.alignEnd = false,
  });

  final TeamInfo team;
  final List<String> results;
  final _FormWindowStats stats;
  final Color accent;
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
                      color: accent,
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
    final brand = context.brand;
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
              color: brand.accent,
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
                color: Colors.white,
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
                    color: context.brand.accent,
                  ),
                  const SizedBox(height: 8),
                  _LectorFormChartCard(
                    teamName: match.awayTeam.name,
                    results: awayResults,
                    color: context.opportunities.levelGap,
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
                    color: context.brand.accent,
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
                    color: context.opportunities.levelGap,
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
  });

  final List<int> values;
  final Color color;
  final Color gridColor;
  final Color textColor;

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
        Colors.white,
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
        textColor != oldDelegate.textColor;
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
          color: Colors.white,
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
            Positioned.fill(
              child: ColoredBox(
                color: surfaces.surface.withValues(alpha: 0.34),
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

void _showScenarioReadingsSheet(BuildContext context, MatchBoardItem match) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.transparent,
    barrierColor: context.surfaces.scrim.withValues(alpha: 0.56),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        minChildSize: 0.48,
        initialChildSize: 0.76,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return _ScenarioReadingsSheet(
            match: match,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _ScenarioReadingsSheet extends StatelessWidget {
  const _ScenarioReadingsSheet({
    required this.match,
    required this.scrollController,
  });

  final MatchBoardItem match;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;
    final count = _scenarioReadingCount(match);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(
          top: BorderSide(color: surfaces.border.withValues(alpha: 0.95)),
          left: BorderSide(color: surfaces.border.withValues(alpha: 0.72)),
          right: BorderSide(color: surfaces.border.withValues(alpha: 0.72)),
        ),
        boxShadow: [
          BoxShadow(
            color: surfaces.shadow.withValues(alpha: 0.38),
            blurRadius: 34,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 52,
            height: 5,
            decoration: BoxDecoration(
              color: textColors.secondary.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LES $count LECTURES',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColors.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _scenarioSheetIntro(match),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textColors.secondary,
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: textColors.primary,
                    size: 27,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              children: [
                _ScenarioSheetReadingCard(
                  index: 1,
                  icon: Icons.shield_outlined,
                  title: 'Écart de niveau structurel',
                  description: _scenarioStructuralDescription(match),
                  impactLabel: 'Impact élevé',
                  impactColor: context.opportunities.levelGap,
                  child: _ScenarioStandingEvidence(match: match),
                ),
                const SizedBox(height: 10),
                _ScenarioSheetReadingCard(
                  index: 2,
                  icon: Icons.trending_up_rounded,
                  title: 'Dynamique récente supérieure',
                  description: _scenarioFormDescription(match),
                  impactLabel: 'Impact élevé',
                  impactColor: context.opportunities.levelGap,
                  child: _ScenarioFormEvidence(match: match),
                ),
                const SizedBox(height: 10),
                _ScenarioSheetReadingCard(
                  index: 3,
                  icon: Icons.home_rounded,
                  title: 'Avantage domicile / faiblesse extérieure',
                  description: _scenarioHomeAwayDescription(match),
                  impactLabel: 'Impact moyen',
                  impactColor: context.semantic.warning,
                  child: _ScenarioHomeAwayEvidence(match: match),
                ),
                const SizedBox(height: 10),
                _ScenarioVigilanceCard(match: match),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showComingSoon(
                        context,
                        'Pont vers les preuves à brancher',
                      );
                    },
                    iconAlignment: IconAlignment.end,
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: context.brand.accent,
                      size: 20,
                    ),
                    label: Text(
                      'Voir les preuves dans les données',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: context.brand.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
        borderRadius: BorderRadius.circular(999),
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
                color: Colors.white,
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

class _ScenarioVigilanceCard extends StatelessWidget {
  const _ScenarioVigilanceCard({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final textColors = context.textColors;
    final color = context.opportunities.levelGap;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POINT DE VIGILANCE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _scenarioVigilanceText(match),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColors.secondary,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textColors.secondary,
              size: 22,
            ),
          ],
        ),
      ),
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
    return match.signals.first.title;
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
  final evidenceCount = match.thesis?.supportingEvidence.length ?? 0;
  if (evidenceCount > 0) {
    return evidenceCount.clamp(1, 3).toInt();
  }
  if (match.signals.isNotEmpty) {
    return match.signals.length.clamp(1, 3).toInt();
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
  final explicit =
      opportunity?.recommendedMarket ?? match.thesis?.recommendedMarket;
  if (_hasScenarioRecommendedPick(explicit)) {
    return explicit;
  }

  final primary = match.primaryMarket;
  if (!primary.odds.isFinite ||
      primary.odds <= 0 ||
      primary.id == 'market_unavailable') {
    return null;
  }

  for (final market in match.availableMarkets) {
    for (final selection in market.selections) {
      if (_sameMarketSelection(selection, primary)) {
        return RecommendedMarket(market: market, selection: selection);
      }
    }
  }

  return null;
}

bool _sameMarketSelection(MarketOdds left, MarketOdds right) {
  if (left.id == right.id) {
    return true;
  }

  final leftRaw = left.apiFootballValue?.trim().toLowerCase();
  final rightRaw = right.apiFootballValue?.trim().toLowerCase();
  return leftRaw != null &&
      leftRaw.isNotEmpty &&
      leftRaw == rightRaw &&
      left.odds == right.odds;
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

String _scenarioVigilanceText(MatchBoardItem match) {
  final limits = match.thesis?.limits ?? const <ThesisEvidence>[];
  if (limits.isNotEmpty) {
    return limits.first.label;
  }

  final awayGoals = match.analysis.awayRecentLeagueMatches
      .take(5)
      .where((recent) => recent.goalsFor != null)
      .fold<int>(0, (sum, recent) => sum + recent.goalsFor!);
  if (awayGoals > 0) {
    return '${match.awayTeam.name} reste capable de marquer ($awayGoals buts sur les 5 derniers matchs disponibles).';
  }

  return 'Cette lecture reste à confronter aux compositions et aux informations d’avant-match.';
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
  final rows = fullTable.take(10).toList();

  void addIfMissing(TeamStandingSnapshot? standing) {
    if (standing == null) {
      return;
    }
    final alreadyVisible = rows.any((row) => _sameStandingTeam(row, standing));
    if (!alreadyVisible) {
      rows.add(standing);
    }
  }

  addIfMissing(match.analysis.homeStanding);
  addIfMissing(match.analysis.awayStanding);
  rows.sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
  return rows;
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
  return value > 0 ? context.brand.accent : context.semantic.error;
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
    return context.brand.accent;
  }
  if (value == 'D' || value == 'N') {
    return Theme.of(context).colorScheme.outline;
  }
  if (value == 'L' || value == 'P') {
    return context.semantic.error;
  }
  return context.surfaces.border;
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
        _ColoredText('${stats.draws}N', color: semantic.warning),
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
    'D' => semantic.warning,
    'L' => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
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
    final recommendedMarket =
        widget.opportunity?.recommendedMarket ??
        widget.match.thesis?.recommendedMarket;
    final theses =
        widget.opportunity?.retainedTheses ??
        [if (widget.match.thesis != null) widget.match.thesis!];
    final compatibleMarkets = widget.opportunity?.compatibleMarkets ?? const [];
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
                          'Aucun marché recommandé actuellement.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOutOfProfile
                              ? 'Cette compétition n’est pas dans votre profil.\nActivez-la pour recevoir des marchés adaptés.'
                              : 'Lector n’a pas trouvé de marché assez aligné avec cette lecture.',
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
