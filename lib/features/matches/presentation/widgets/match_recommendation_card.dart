import 'package:flutter/material.dart';

import '../../../../core/theme/app_components.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/match_board_item.dart';
import 'sports_asset_badge.dart';

class MatchRecommendationCard extends StatefulWidget {
  const MatchRecommendationCard({
    required this.match,
    required this.isSelected,
    required this.onToggleTicket,
    this.onOpenDetails,
    this.showCompetition = true,
    super.key,
  });

  final MatchBoardItem match;
  final bool isSelected;
  final VoidCallback onToggleTicket;
  final VoidCallback? onOpenDetails;
  final bool showCompetition;

  @override
  State<MatchRecommendationCard> createState() =>
      _MatchRecommendationCardState();
}

class _MatchRecommendationCardState extends State<MatchRecommendationCard> {
  bool _showsArguments = false;
  int? _expandedArgumentIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final match = widget.match;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(
            color: widget.isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: widget.onOpenDetails,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                child: Column(
                  children: [
                    _MatchMetaRow(
                      competition: match.competition.name,
                      kickoffLabel: match.fixture.kickoffLabel,
                      compatibility: match.compatibility,
                      pendingLabel: l10n.analysisPendingLabel,
                      showCompetition: widget.showCompetition,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _TeamsColumn(match: match)),
                        const SizedBox(width: 10),
                        _TicketIconButton(
                          isSelected: widget.isSelected,
                          onPressed: widget.onToggleTicket,
                          selectedTooltip: l10n.selectedForTicket,
                          addTooltip: l10n.addToTicket,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _DefaultMarketOddsBar(
                      market:
                          match.thesis?.recommendedMarket?.market ??
                          match.defaultMarket,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _MarketPill(
                            icon: Icons.psychology_alt_rounded,
                            label:
                                match.thesis?.title ??
                                (match.availableMarkets.isEmpty
                                    ? match.primaryMarket.label
                                    : l10n.availableMarketsCount(
                                        match.availableMarkets.length,
                                      )),
                          ),
                        ),
                        if (match.signals.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showsArguments = !_showsArguments;
                              });
                            },
                            icon: Icon(
                              _showsArguments
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                            ),
                            label: Text(l10n.whyButton(match.signals.length)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                        ],
                        if (widget.onOpenDetails != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (_showsArguments)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (final entry in match.signals.indexed)
                        _ArgumentTile(
                          argument: entry.$2,
                          isExpanded: _expandedArgumentIndex == entry.$1,
                          onTap: () {
                            setState(() {
                              _expandedArgumentIndex =
                                  _expandedArgumentIndex == entry.$1
                                  ? null
                                  : entry.$1;
                            });
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchMetaRow extends StatelessWidget {
  const _MatchMetaRow({
    required this.competition,
    required this.kickoffLabel,
    required this.compatibility,
    required this.pendingLabel,
    required this.showCompetition,
  });

  final String competition;
  final String kickoffLabel;
  final int compatibility;
  final String pendingLabel;
  final bool showCompetition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 15,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          kickoffLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (showCompetition) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              competition,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ] else
          const Spacer(),
        _CompatibilityBadge(value: compatibility, pendingLabel: pendingLabel),
      ],
    );
  }
}

class _TeamsColumn extends StatelessWidget {
  const _TeamsColumn({required this.match});

  final MatchBoardItem match;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TeamLine(team: match.homeTeam, isHome: true),
        const SizedBox(height: 6),
        _TeamLine(team: match.awayTeam, isHome: false),
      ],
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.team, required this.isHome});

  final TeamInfo team;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        SportsAssetBadge(
          size: 24,
          imageUrl: team.logoUrl,
          fallbackLabel: team.name,
          borderRadius: 4,
          backgroundColor: isHome
              ? colorScheme.primaryContainer
              : colorScheme.secondaryContainer,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DefaultMarketOddsBar extends StatelessWidget {
  const _DefaultMarketOddsBar({required this.market});

  final MatchMarket? market;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final defaultMarket = market;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: defaultMarket == null
            ? SizedBox(
                height: 38,
                child: Center(
                  child: Text(
                    l10n.marketOddsUnavailable,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  Row(
                    children: [
                      for (final entry
                          in defaultMarket.selections.take(3).indexed) ...[
                        if (entry.$1 > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _OutcomeOddTile(
                            label: _selectionLabelFor(
                              context,
                              defaultMarket,
                              entry.$2,
                              entry.$1,
                            ),
                            selection: entry.$2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (defaultMarket.bookmakerName != null) ...[
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        defaultMarket.bookmakerName!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  String _selectionLabelFor(
    BuildContext context,
    MatchMarket market,
    MarketOdds selection,
    int index,
  ) {
    final l10n = AppLocalizations.of(context);
    if (market.id != 'matchResult') {
      return selection.label;
    }

    return switch (index) {
      0 => l10n.homeOutcomeLabel,
      1 => l10n.drawOutcomeLabel,
      2 => l10n.awayOutcomeLabel,
      _ => selection.label,
    };
  }
}

class _OutcomeOddTile extends StatelessWidget {
  const _OutcomeOddTile({required this.label, required this.selection});

  final String label;
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
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              selection.odds.toStringAsFixed(2),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketIconButton extends StatelessWidget {
  const _TicketIconButton({
    required this.isSelected,
    required this.onPressed,
    required this.selectedTooltip,
    required this.addTooltip,
  });

  final bool isSelected;
  final VoidCallback onPressed;
  final String selectedTooltip;
  final String addTooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: isSelected ? selectedTooltip : addTooltip,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(isSelected ? Icons.check_rounded : Icons.add_rounded),
        style: IconButton.styleFrom(
          fixedSize: const Size.square(48),
          backgroundColor: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.secondaryContainer,
          foregroundColor: isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSecondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
    );
  }
}

class _MarketPill extends StatelessWidget {
  const _MarketPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.tight),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
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

class _CompatibilityBadge extends StatelessWidget {
  const _CompatibilityBadge({required this.value, required this.pendingLabel});

  final int value;
  final String pendingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semantic;
    final isPending = value <= 0;
    final color = isPending
        ? theme.colorScheme.onSurfaceVariant
        : value >= 90
        ? theme.colorScheme.primary
        : value >= 80
        ? semantic.success
        : semantic.warning;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          isPending ? pendingLabel : '$value%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ArgumentTile extends StatelessWidget {
  const _ArgumentTile({
    required this.argument,
    required this.isExpanded,
    required this.onTap,
  });

  final MatchSignal argument;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Material(
          type: MaterialType.transparency,
          child: ListTile(
            onTap: onTap,
            leading: Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              argument.title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(argument.summary),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.proofsLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                for (final proof in argument.proofs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $proof',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
