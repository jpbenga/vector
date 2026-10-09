import '../domain/lector_temporal_state.dart';
import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'sports_asset_badge.dart';

/// Shared match surface. Analysis and score semantics belong to sport adapters.
class LectorMatchCardFrame extends StatelessWidget {
  const LectorMatchCardFrame({
    required this.child,
    this.onTap,
    this.temporal,
    super.key,
  });
  final Widget child;
  final LectorTemporalState? temporal;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: context.surfaces.surface.withValues(alpha: 0.72),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: context.surfaces.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        if (temporal?.isLive == true)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              key: const ValueKey('live-card-accent'),
              width: 3,
              color: temporal!.isStale(DateTime.now())
                  ? context.semantic.warning
                  : context.semantic.live,
            ),
          ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 12),
            child: child,
          ),
        ),
      ],
    ),
  );
}

class LectorTeamLine extends StatelessWidget {
  const LectorTeamLine({
    required this.name,
    this.logoUrl,
    this.score,
    this.isLive = false,
    this.role,
    super.key,
  });
  final String name;
  final String? logoUrl;
  final int? score;
  final bool isLive;
  final String? role;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SportsAssetBadge(
        size: 28,
        imageUrl: logoUrl,
        fallbackLabel: name,
        borderRadius: AppRadius.chip,
        padding: 1,
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (role != null)
              Text(
                role!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
      if (score != null) ...[
        const SizedBox(width: 8),
        LectorScore(value: score!, isLive: isLive),
      ],
    ],
  );
}

/// Scores keep their position and dimensions when a game becomes final.
class LectorScore extends StatelessWidget {
  const LectorScore({required this.value, this.isLive = false, super.key});
  final int value;
  final bool isLive;
  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('match-score-${isLive ? 'live' : 'neutral'}'),
    constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    decoration: isLive
        ? BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xff321b21)
                : const Color(0xfffae6e8),
            border: Border.all(
              color: context.semantic.live.withValues(alpha: .40),
            ),
            borderRadius: BorderRadius.circular(7),
          )
        : null,
    child: Text(
      '$value',
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
}

/// Complete match card layout. Modules provide content and actions; sizing,
/// participant rows, navigation placement and panel order are shared.
class LectorMatchCard extends StatelessWidget {
  const LectorMatchCard({
    required this.header,
    required this.teams,
    required this.onTap,
    this.insights,
    this.liveStatus,
    this.liveSummary,
    this.contextPanel,
    this.actionColor,
    this.actionLabel = 'Voir l’analyse',
    this.temporal,
    super.key,
  });
  final Widget header, teams;
  final VoidCallback onTap;
  final Widget? insights, liveStatus, liveSummary, contextPanel;
  final Color? actionColor;
  final String actionLabel;
  final LectorTemporalState? temporal;
  @override
  Widget build(BuildContext context) => LectorMatchCardFrame(
    onTap: onTap,
    temporal: temporal,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        ?liveStatus,
        const SizedBox(height: 9),
        Divider(height: 1, color: context.surfaces.border),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final action = IconButton.outlined(
              onPressed: onTap,
              tooltip: actionLabel,
              icon: Icon(
                Icons.chevron_right_rounded,
                color: actionColor ?? context.brand.accent,
              ),
              style: IconButton.styleFrom(
                side: BorderSide(color: context.surfaces.border),
                backgroundColor: context.surfaces.surfaceHover.withValues(
                  alpha: .4,
                ),
              ),
            );
            if (constraints.maxWidth < 680) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: teams),
                      const SizedBox(width: 8),
                      action,
                    ],
                  ),
                  if (insights != null) ...[
                    const SizedBox(height: 10),
                    insights!,
                  ],
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: 260, child: teams),
                if (insights != null) ...[
                  Container(
                    width: 1,
                    height: 84,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: context.surfaces.border,
                  ),
                  Expanded(child: insights!),
                ] else
                  const Spacer(),
                const SizedBox(width: 10),
                action,
              ],
            );
          },
        ),
        ?liveSummary,
        if (contextPanel != null) ...[
          const SizedBox(height: 10),
          Divider(height: 1, color: context.surfaces.border),
          const SizedBox(height: 10),
          contextPanel!,
        ],
      ],
    ),
  );
}

class LectorMatchTeams extends StatelessWidget {
  const LectorMatchTeams({
    required this.first,
    required this.second,
    this.odds,
    super.key,
  });
  final Widget first, second;
  final Widget? odds;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [first, const SizedBox(height: 10), second],
        ),
      ),
      if (odds != null) ...[const SizedBox(width: 10), odds!],
    ],
  );
}

class LectorMatchTimeHeader extends StatelessWidget {
  const LectorMatchTimeHeader({
    required this.timeLabel,
    this.trailing,
    super.key,
  });
  final String timeLabel;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.schedule_rounded, size: 17, color: context.brand.accent),
      const SizedBox(width: 6),
      Text(
        timeLabel,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.textColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
      const Spacer(),
      if (trailing != null) Flexible(child: trailing!),
    ],
  );
}
