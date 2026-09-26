import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../matches/domain/match_board_item.dart';
import '../../matches/presentation/widgets/sports_asset_badge.dart';
import 'widgets/form_radar_event_timeline.dart';

Future<void> showPlayerFormRadarMatchDetail(
  BuildContext context, {
  required PlayerFormRadarProfile profile,
  required List<PlayerFormRadarMatchSnapshot> activity,
  required int initialFixtureId,
}) {
  final initialIndex = activity.indexWhere(
    (match) => match.fixtureId == initialFixtureId,
  );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.surfaces.background,
    builder: (context) => _PlayerFormRadarMatchDetailSheet(
      profile: profile,
      activity: activity,
      initialIndex: initialIndex < 0 ? activity.length - 1 : initialIndex,
    ),
  );
}

class _PlayerFormRadarMatchDetailSheet extends StatefulWidget {
  const _PlayerFormRadarMatchDetailSheet({
    required this.profile,
    required this.activity,
    required this.initialIndex,
  });

  final PlayerFormRadarProfile profile;
  final List<PlayerFormRadarMatchSnapshot> activity;
  final int initialIndex;

  @override
  State<_PlayerFormRadarMatchDetailSheet> createState() =>
      _PlayerFormRadarMatchDetailSheetState();
}

class _PlayerFormRadarMatchDetailSheetState
    extends State<_PlayerFormRadarMatchDetailSheet> {
  late int _selectedIndex = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final match = widget.activity[_selectedIndex];
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: .78,
        minChildSize: .48,
        maxChildSize: .94,
        expand: false,
        builder: (context, scrollController) => DecoratedBox(
          decoration: BoxDecoration(
            color: context.surfaces.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.card + 8),
            ),
            border: Border.all(color: context.surfaces.border),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.surfaces.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _PlayerHeader(profile: widget.profile),
              const SizedBox(height: 18),
              Text(
                'Forme récente',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              _InteractiveActivityTimeline(
                activity: widget.activity,
                selectedIndex: _selectedIndex,
                onSelect: (index) => setState(() => _selectedIndex = index),
              ),
              const SizedBox(height: 7),
              Center(
                child: Text(
                  'Match sélectionné',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.brand.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Divider(color: context.surfaces.border),
              const SizedBox(height: 13),
              _MatchContext(match: match, profile: widget.profile),
              const SizedBox(height: 16),
              _MatchContributionSummary(match: match),
              const SizedBox(height: 18),
              Divider(color: context.surfaces.border),
              const SizedBox(height: 14),
              _MatchActionTimeline(match: match),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.profile});
  final PlayerFormRadarProfile profile;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SportsAssetBadge(
        size: 54,
        imageUrl: profile.photoUrl,
        fallbackLabel: profile.playerName,
        borderRadius: 27,
        contrastPlate: true,
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.playerName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                SportsAssetBadge(
                  size: 18,
                  imageUrl: profile.teamLogoUrl,
                  fallbackLabel: profile.teamName,
                  borderRadius: 5,
                  contrastPlate: true,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    profile.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Fermer',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );
}

class _InteractiveActivityTimeline extends StatelessWidget {
  const _InteractiveActivityTimeline({
    required this.activity,
    required this.selectedIndex,
    required this.onSelect,
  });
  final List<PlayerFormRadarMatchSnapshot> activity;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final indexed in activity.indexed) ...[
          _ActivityTile(
            match: indexed.$2,
            selected: indexed.$1 == selectedIndex,
            onTap: () => onSelect(indexed.$1),
          ),
          if (indexed.$1 != activity.length - 1) const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.match,
    required this.selected,
    required this.onTap,
  });
  final PlayerFormRadarMatchSnapshot match;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Match du ${_dateLabel(match.playedAt)}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          color: _activityColor(context, match),
          border: Border.all(
            color: selected ? context.brand.accent : AppColors.transparent,
            width: selected ? 2 : 0,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: match.substitute
            ? Container(height: 4, color: context.semantic.warning)
            : null,
      ),
    ),
  );
}

class _MatchContext extends StatelessWidget {
  const _MatchContext({required this.match, required this.profile});
  final PlayerFormRadarMatchSnapshot match;
  final PlayerFormRadarProfile profile;

  @override
  Widget build(BuildContext context) {
    final hasTeams = match.homeTeamName != null && match.awayTeamName != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                [match.competitionName, match.round]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' · ')
                    .ifEmpty('Match analysé'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.textColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              _dateLabel(match.playedAt),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        if (hasTeams)
          _Scoreline(match: match)
        else
          Text(
            '${profile.teamName} · match terminé',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class _Scoreline extends StatelessWidget {
  const _Scoreline({required this.match});
  final PlayerFormRadarMatchSnapshot match;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ScoreTeam(
          name: match.homeTeamName!,
          logoUrl: match.homeTeamLogoUrl,
          alignEnd: true,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          match.homeGoals != null && match.awayGoals != null
              ? '${match.homeGoals} – ${match.awayGoals}'
              : '–',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Expanded(
        child: _ScoreTeam(
          name: match.awayTeamName!,
          logoUrl: match.awayTeamLogoUrl,
        ),
      ),
    ],
  );
}

class _ScoreTeam extends StatelessWidget {
  const _ScoreTeam({
    required this.name,
    required this.logoUrl,
    this.alignEnd = false,
  });
  final String name;
  final String? logoUrl;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: alignEnd
        ? MainAxisAlignment.end
        : MainAxisAlignment.start,
    children: [
      if (!alignEnd) ...[
        SportsAssetBadge(
          size: 29,
          imageUrl: logoUrl,
          fallbackLabel: name,
          borderRadius: 14,
          contrastPlate: true,
        ),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          name,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      if (alignEnd) ...[
        const SizedBox(width: 6),
        SportsAssetBadge(
          size: 29,
          imageUrl: logoUrl,
          fallbackLabel: name,
          borderRadius: 14,
          contrastPlate: true,
        ),
      ],
    ],
  );
}

class _MatchContributionSummary extends StatelessWidget {
  const _MatchContributionSummary({required this.match});
  final PlayerFormRadarMatchSnapshot match;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _SummaryMetric(
          icon: Icons.schedule_rounded,
          value: '${match.minutes}\u2032',
          label: 'Minutes jouées',
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _SummaryMetric(
          icon: Icons.sports_soccer_rounded,
          value: '${match.goals}',
          label: match.goals == 1 ? 'But' : 'Buts',
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _SummaryMetric(
          icon: Icons.assistant_rounded,
          value: '${match.assists}',
          label: match.assists == 1 ? 'Passe déc.' : 'Passes déc.',
        ),
      ),
    ],
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: context.brand.accent),
              const SizedBox(width: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.textColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MatchActionTimeline extends StatelessWidget {
  const _MatchActionTimeline({required this.match});
  final PlayerFormRadarMatchSnapshot match;

  @override
  Widget build(BuildContext context) {
    if (match.actions.isEmpty) {
      return Text(
        match.isDecisive
            ? 'Les contributions sont connues, mais leur minute n’est pas disponible dans ce snapshot.'
            : 'Aucune contribution décisive dans ce match.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.textColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chronologie des actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        FormRadarEventTimeline(
          events: [
            for (final action in match.actions)
              FormRadarTimelineEvent(
                minute: action.minute,
                kind: action.kind == PlayerFormRadarActionKind.goal
                    ? FormRadarTimelineEventKind.goal
                    : FormRadarTimelineEventKind.assist,
                label: action.kind == PlayerFormRadarActionKind.goal
                    ? 'But'
                    : 'Passe déc.',
              ),
          ],
          endMinute: match.minutes.clamp(1, 90),
        ),
      ],
    );
  }
}

Color _activityColor(BuildContext context, PlayerFormRadarMatchSnapshot match) {
  if (!match.appeared) return AppColors.transparent;
  if (match.isDecisive) {
    return context.semantic.success.withValues(
      alpha: match.contributions > 1 ? 1 : .60,
    );
  }
  if (match.substitute) return context.semantic.warning;
  return context.textColors.secondary.withValues(alpha: .25);
}

String _dateLabel(DateTime value) {
  const months = [
    'jan.',
    'fév.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
