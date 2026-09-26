import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../matches/domain/match_board_item.dart';
import '../../matches/presentation/widgets/sports_asset_badge.dart';
import '../domain/team_form_radar.dart';
import 'widgets/form_radar_event_timeline.dart';

Future<void> showTeamFormRadarMatchDetail(
  BuildContext context, {
  required TeamFormRadarProfile profile,
  required int initialIndex,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.surfaces.background,
  builder: (_) =>
      _TeamRadarMatchSheet(profile: profile, initialIndex: initialIndex),
);

class _TeamRadarMatchSheet extends StatefulWidget {
  const _TeamRadarMatchSheet({
    required this.profile,
    required this.initialIndex,
  });
  final TeamFormRadarProfile profile;
  final int initialIndex;
  @override
  State<_TeamRadarMatchSheet> createState() => _TeamRadarMatchSheetState();
}

class _TeamRadarMatchSheetState extends State<_TeamRadarMatchSheet> {
  late int _index = widget.initialIndex;
  @override
  Widget build(BuildContext context) {
    final match = widget.profile.activity[_index];
    final points =
        match.result.toUpperCase() == 'W' || match.result.toUpperCase() == 'V'
        ? 3
        : match.result.toUpperCase() == 'D' || match.result.toUpperCase() == 'N'
        ? 1
        : 0;
    final result = points == 3
        ? 'Victoire'
        : points == 1
        ? 'Match nul'
        : 'Défaite';
    final stats = match.statistics;
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: .82,
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
                    borderRadius: BorderRadius.circular(AppRadius.indicator),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SportsAssetBadge(
                    size: 52,
                    imageUrl: widget.profile.logoUrl,
                    fallbackLabel: widget.profile.teamName,
                    borderRadius: 26,
                    contrastPlate: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.profile.teamName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: context.textColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          widget.profile.leagueName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.textColors.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Forme récente',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in widget.profile.activity.indexed) ...[
                      _TeamCell(
                        result: item.$2.result,
                        selected: item.$1 == _index,
                        onTap: () => setState(() => _index = item.$1),
                      ),
                      if (item.$1 != widget.profile.activity.length - 1)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: context.surfaces.border),
              const SizedBox(height: 12),
              Text(
                '${widget.profile.leagueName} · ${_date(match.playedAt)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.textColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _Score(
                team: widget.profile.teamName,
                teamLogo: widget.profile.logoUrl,
                opponent: match.opponentName,
                opponentLogo: match.opponentLogoUrl,
                goalsFor: match.goalsFor,
                goalsAgainst: match.goalsAgainst,
                home: match.venue == RecentMatchVenue.home,
              ),
              const SizedBox(height: 14),
              Divider(color: context.surfaces.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Résultat',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$result · +$points pts',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: points == 3
                          ? context.semantic.success
                          : context.textColors.secondary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (stats != null) ...[
                const SizedBox(height: 18),
                Text(
                  'Statistiques du match',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                _Stats(stats: stats),
              ],
              if (match.events.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Événements clés',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                FormRadarEventTimeline(
                  events: [
                    for (final event in match.events)
                      FormRadarTimelineEvent(
                        minute: event.minute,
                        kind: FormRadarTimelineEventKind.goal,
                        label: event.playerName ?? event.teamName ?? 'But',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamCell extends StatelessWidget {
  const _TeamCell({
    required this.result,
    required this.selected,
    required this.onTap,
  });
  final String result;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.tight),
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: result.toUpperCase() == 'W' || result.toUpperCase() == 'V'
            ? context.semantic.success
            : result.toUpperCase() == 'D' || result.toUpperCase() == 'N'
            ? context.textColors.secondary.withValues(alpha: .25)
            : context.semantic.error,
        border: Border.all(
          color: selected ? context.brand.accent : AppColors.transparent,
          width: selected ? 2 : 0,
        ),
        borderRadius: BorderRadius.circular(AppRadius.tight),
      ),
    ),
  );
}

class _Score extends StatelessWidget {
  const _Score({
    required this.team,
    required this.teamLogo,
    required this.opponent,
    required this.opponentLogo,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.home,
  });
  final String team, opponent;
  final String? teamLogo, opponentLogo;
  final int? goalsFor, goalsAgainst;
  final bool home;
  @override
  Widget build(BuildContext context) {
    final first = home ? team : opponent;
    final second = home ? opponent : team;
    final firstLogo = home ? teamLogo : opponentLogo;
    final secondLogo = home ? opponentLogo : teamLogo;
    final firstGoals = home ? goalsFor : goalsAgainst;
    final secondGoals = home ? goalsAgainst : goalsFor;
    return Row(
      children: [
        Expanded(
          child: _Label(name: first, logo: firstLogo, end: true),
        ),
        Text(
          firstGoals != null && secondGoals != null
              ? '$firstGoals – $secondGoals'
              : '–',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Expanded(
          child: _Label(name: second, logo: secondLogo),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.name, required this.logo, this.end = false});
  final String name;
  final String? logo;
  final bool end;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
    children: [
      if (!end) ...[
        SportsAssetBadge(
          size: 28,
          imageUrl: logo,
          fallbackLabel: name,
          borderRadius: 14,
          contrastPlate: true,
        ),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          name,
          textAlign: end ? TextAlign.end : TextAlign.start,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      if (end) ...[
        const SizedBox(width: 6),
        SportsAssetBadge(
          size: 28,
          imageUrl: logo,
          fallbackLabel: name,
          borderRadius: 14,
          contrastPlate: true,
        ),
      ],
    ],
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});
  final TeamRecentMatchStatisticsSnapshot stats;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _stat(context, stats.shotsFor, 'Tirs', stats.shotsAgainst),
      _stat(
        context,
        stats.shotsOnTargetFor,
        'Tirs cadrés',
        stats.shotsOnTargetAgainst,
      ),
      _stat(context, stats.expectedGoalsFor, 'xG', stats.expectedGoalsAgainst),
      _stat(
        context,
        stats.possessionFor,
        'Possession',
        stats.possessionAgainst,
        percent: true,
      ),
    ],
  );
  Widget _stat(
    BuildContext context,
    double? first,
    String name,
    double? second, {
    bool percent = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            _value(first, percent),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.textColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            _value(second, percent),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
  String _value(double? value, bool percent) => value == null
      ? '—'
      : '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(2).replaceAll('.', ',')}${percent ? ' %' : ''}';
}

String _date(DateTime? value) {
  if (value == null) return 'Match terminé';
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
