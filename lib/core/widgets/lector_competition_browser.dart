import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'sports_asset_badge.dart';

/// Identical country/competition navigation for every sport. Adapters supply
/// the already filtered match cards, counts and factual identity assets.
class LectorCompetitionGroup extends StatefulWidget {
  const LectorCompetitionGroup({
    required this.identity,
    required this.name,
    required this.countLabel,
    required this.children,
    this.logoUrl,
    this.isCountry = false,
    this.initiallyExpanded = false,
    this.forceExpanded = false,
    super.key,
  });
  final String identity, name, countLabel;
  final String? logoUrl;
  final bool isCountry, initiallyExpanded;

  /// Live sections keep all descendants visible without changing the user's
  /// manual expansion state for other sections.
  final bool forceExpanded;
  final List<Widget> children;
  @override
  State<LectorCompetitionGroup> createState() => _LectorCompetitionGroupState();
}

class _LectorCompetitionGroupState extends State<LectorCompetitionGroup> {
  late bool _expanded = widget.initiallyExpanded;
  late bool _hasExpanded = widget.initiallyExpanded;
  @override
  void didUpdateWidget(covariant LectorCompetitionGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
      _hasExpanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.surface.withValues(alpha: .58),
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.surfaces.border),
    ),
    child: Column(
      children: [
        Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: widget.forceExpanded
                ? null
                : () => setState(() {
                    _expanded = !_expanded;
                    _hasExpanded = _hasExpanded || _expanded;
                  }),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 8),
              child: Row(
                children: [
                  SportsAssetBadge(
                    size: widget.isCountry ? 26 : 24,
                    imageUrl: widget.logoUrl,
                    fallbackLabel: widget.name,
                    contrastPlate: true,
                    icon: widget.isCountry
                        ? Icons.flag_rounded
                        : Icons.emoji_events_rounded,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    widget.countLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.textColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!widget.forceExpanded) ...[
                    const SizedBox(width: AppSpacing.sm),
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: !widget.forceExpanded && !_hasExpanded
              ? const SizedBox(width: double.infinity)
              : widget.isCountry
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Column(children: widget.children),
                )
              : Column(children: widget.children),
          crossFadeState: widget.forceExpanded || _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    ),
  );
}

class LectorCompetitionHeader extends StatelessWidget {
  const LectorCompetitionHeader({
    required this.name,
    required this.count,
    this.logoUrl,
    this.flagUrl,
    this.country = '',
    super.key,
  });
  final String name, country;
  final String? logoUrl, flagUrl;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SportsAssetBadge(
        size: 30,
        imageUrl: flagUrl ?? logoUrl,
        fallbackLabel: country.isEmpty ? name : country,
        borderRadius: 5,
        contrastPlate: true,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          name,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Text(
        '$count match${count > 1 ? 's' : ''}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.textColors.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
