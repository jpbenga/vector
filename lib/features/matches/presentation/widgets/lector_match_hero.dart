import '../../../../core/widgets/lector_live_badge.dart';
import '../../domain/live_match_state.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_components.dart';
import '../../../../core/theme/app_radius.dart';
import '../../domain/match_board_item.dart';
import 'lector_glass_card.dart';
import 'sports_asset_badge.dart';

const _matchCardStadiumBackgroundAsset =
    'assets/backgrounds/match-card-stadium-premium.png';

class LectorMatchHero extends StatelessWidget {
  const LectorMatchHero({required this.match, this.state, super.key});

  final MatchBoardItem match;
  final LiveMatchState? state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueLabel = _venueValue(match.fixture.venue);
    final roundLabel = _fixtureRoundLabel(match.fixture.round);

    return LectorGlassCard(
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
                flex: 5,
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
                  _matchDateTimeLabel(match),
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
                child: _HeroTeamBlock(team: match.homeTeam, alignRight: false),
              ),
              const SizedBox(width: 8),
              _HeroStatusBlock(match: match, state: state),
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
          alignRight ? 'Extérieur' : 'Domicile',
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.textColors.onImageMuted,
          ),
        ),
        const SizedBox(height: 4),
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
  const _HeroStatusBlock({required this.match, this.state});

  final MatchBoardItem match;
  final LiveMatchState? state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = match.fixture.score;
    final isLive = match.fixture.status == FixtureStatus.live;
    final isFinished = match.fixture.status == FixtureStatus.finished;

    return SizedBox(
      width: isLive ? 138 : 94,
      child: Column(
        children: [
          if (isLive && state != null)
            FittedBox(
              child: LectorLiveBadge(state: state!.temporal, prominent: true),
            )
          else
            Text(
              isLive
                  ? 'EN COURS'
                  : isFinished
                  ? 'TERMINÉ'
                  : 'Avant-match',
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.textColors.onImage,
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
          if (state?.halftimeLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              state!.halftimeLabel!,
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
