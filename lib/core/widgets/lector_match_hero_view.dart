import '../domain/lector_temporal_state.dart';
import 'lector_live_badge.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import 'lector_glass_card.dart';
import 'sports_asset_badge.dart';

class LectorMatchTeamData {
  const LectorMatchTeamData({required this.name, this.logoUrl, this.role});
  final String name;
  final String? logoUrl, role;
}

class LectorMatchHeroData {
  const LectorMatchHeroData({
    required this.competitionName,
    this.competitionLogoUrl,
    required this.dateLabel,
    required this.firstTeam,
    required this.secondTeam,
    required this.statusLabel,
    required this.isLive,
    required this.isFinished,
    this.scoreLabel,
    this.venueLabel = '',
    this.roundLabel,
    this.temporal,
    this.scoreSubtitle,
  });
  final String competitionName, dateLabel, statusLabel, venueLabel;
  final String? competitionLogoUrl, scoreLabel, roundLabel;
  final LectorMatchTeamData firstTeam, secondTeam;
  final bool isLive, isFinished;
  final LectorTemporalState? temporal;
  final String? scoreSubtitle;
}

const _matchCardStadiumBackgroundAsset =
    'assets/backgrounds/match-card-stadium-premium.png';

class LectorMatchHeroView extends StatelessWidget {
  const LectorMatchHeroView({
    required this.match,
    this.backgroundAsset = _matchCardStadiumBackgroundAsset,
    super.key,
  });

  final LectorMatchHeroData match;
  final String backgroundAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueLabel = match.venueLabel;
    final roundLabel = match.roundLabel;

    return LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      backgroundAsset: backgroundAsset,
      child: Column(
        children: [
          Row(
            children: [
              SportsAssetBadge(
                size: 34,
                imageUrl: match.competitionLogoUrl,
                fallbackLabel: match.competitionName,
                icon: Icons.emoji_events_outlined,
                contrastPlate: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.competitionName,
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
                          color: context.textColors.onImageMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 4,
                child: Text(
                  match.dateLabel,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.textColors.onImage,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _HeroTeamBlock(team: match.firstTeam, alignRight: false),
              ),
              const SizedBox(width: 8),
              _HeroStatusBlock(match: match),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroTeamBlock(team: match.secondTeam, alignRight: true),
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
                  color: context.textColors.onImageMuted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    venueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.textColors.onImageMuted,
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

  final LectorMatchTeamData team;
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
        if (team.role != null) ...[
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.textColors.onImage.withValues(alpha: .18),
                border: Border.all(
                  color: context.textColors.onImage.withValues(alpha: .4),
                ),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      team.role == 'Domicile'
                          ? Icons.home_outlined
                          : Icons.flight_takeoff_rounded,
                      size: 13,
                      color: context.textColors.onImage,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      team.role!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.textColors.onImage,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  final LectorMatchHeroData match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = match.scoreLabel;
    final isLive = match.isLive;
    final isFinished = match.isFinished;

    return SizedBox(
      width: isLive ? 138 : 94,
      child: Column(
        children: [
          if (isLive && match.temporal != null)
            FittedBox(
              child: LectorLiveBadge(state: match.temporal!, prominent: true),
            )
          else
            Text(
              match.statusLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.textColors.onImage,
                fontWeight: FontWeight.w900,
              ),
            ),
          const SizedBox(height: 5),
          if (score != null)
            Text(
              score,
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
          if (match.scoreSubtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              match.scoreSubtitle!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.textColors.onImageMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!isLive && !isFinished) ...[
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.textColors.onImage.withValues(alpha: 0.18),
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
                    color: context.textColors.onImage,
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
