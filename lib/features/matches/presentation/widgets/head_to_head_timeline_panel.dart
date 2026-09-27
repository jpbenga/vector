import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_components.dart';
import '../../../../core/theme/app_radius.dart';
import '../../domain/match_board_item.dart';
import 'sports_asset_badge.dart';

/// A factual TAT view. It deliberately draws events on two team lanes instead
/// of inventing a minute-by-minute domination curve that the provider does
/// not supply.
class HeadToHeadTimelinePanel extends StatefulWidget {
  const HeadToHeadTimelinePanel({required this.match, super.key});

  final MatchBoardItem match;

  @override
  State<HeadToHeadTimelinePanel> createState() =>
      _HeadToHeadTimelinePanelState();
}

class _HeadToHeadTimelinePanelState extends State<HeadToHeadTimelinePanel> {
  _HeadToHeadScope _scope = _HeadToHeadScope.competition;
  String? _selectedMeetingKey;

  List<HeadToHeadFixtureSnapshot> get _allMeetings =>
      [...widget.match.analysis.headToHeadMatches]
        ..sort((left, right) => left.playedAt.compareTo(right.playedAt));

  List<HeadToHeadFixtureSnapshot> get _meetings {
    final competitionId = widget.match.fixture.competition.apiFootballLeagueId;
    final homeTeamId = widget.match.fixture.homeTeam.apiFootballTeamId;
    return switch (_scope) {
      _HeadToHeadScope.competition =>
        _allMeetings
            .where((meeting) => meeting.competitionId == competitionId)
            .toList(growable: false),
      _HeadToHeadScope.all => _allMeetings,
      _HeadToHeadScope.home =>
        _allMeetings
            .where((meeting) => meeting.homeTeamId == homeTeamId)
            .toList(growable: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    final meetings = _meetings;
    final selected = _selected(meetings);
    final theme = Theme.of(context);
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: context.brand.accent),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tête à tête',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'La mémoire visuelle de leurs confrontations.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.info_outline_rounded,
                color: context.textColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ScopeSelector(
            scope: _scope,
            competitionCount: _allMeetings
                .where(
                  (meeting) =>
                      meeting.competitionId ==
                      widget.match.fixture.competition.apiFootballLeagueId,
                )
                .length,
            allCount: _allMeetings.length,
            homeCount: _allMeetings
                .where(
                  (meeting) =>
                      meeting.homeTeamId ==
                      widget.match.fixture.homeTeam.apiFootballTeamId,
                )
                .length,
            onChanged: (value) => setState(() {
              _scope = value;
              _selectedMeetingKey = null;
            }),
          ),
          const SizedBox(height: 14),
          if (meetings.isEmpty)
            const _EmptyTimeline()
          else ...[
            _DuelSummary(match: widget.match, meetings: meetings),
            const SizedBox(height: 17),
            Row(
              children: [
                Icon(Icons.graphic_eq_rounded, color: context.brand.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confrontations récentes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: context.textColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Chaque carte résume le scénario réel d’un match.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.textColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Plus ancien →',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.textColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 145,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meetings.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final meeting = meetings[index];
                  return _MeetingCard(
                    meeting: meeting,
                    firstTeamId:
                        widget.match.fixture.homeTeam.apiFootballTeamId,
                    selected: _meetingKey(meeting) == _meetingKey(selected),
                    onTap: () => setState(
                      () => _selectedMeetingKey = _meetingKey(meeting),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _SelectedMatchDetail(
              meeting: selected,
              firstTeamId: widget.match.fixture.homeTeam.apiFootballTeamId,
              firstTeamName: widget.match.fixture.homeTeam.name,
              secondTeamName: widget.match.fixture.awayTeam.name,
              firstTeamLogoUrl: widget.match.fixture.homeTeam.logoUrl,
              secondTeamLogoUrl: widget.match.fixture.awayTeam.logoUrl,
            ),
          ],
        ],
      ),
    );
  }

  HeadToHeadFixtureSnapshot _selected(
    List<HeadToHeadFixtureSnapshot> meetings,
  ) {
    return meetings.firstWhere(
      (meeting) => _meetingKey(meeting) == _selectedMeetingKey,
      orElse: () => meetings.last,
    );
  }

  String _meetingKey(HeadToHeadFixtureSnapshot meeting) =>
      meeting.fixtureId?.toString() ??
      '${meeting.playedAt.toIso8601String()}-${meeting.homeTeamId}-${meeting.awayTeamId}';
}

enum _HeadToHeadScope { competition, all, home }

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({
    required this.scope,
    required this.competitionCount,
    required this.allCount,
    required this.homeCount,
    required this.onChanged,
  });

  final _HeadToHeadScope scope;
  final int competitionCount;
  final int allCount;
  final int homeCount;
  final ValueChanged<_HeadToHeadScope> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _chip(
          context,
          _HeadToHeadScope.competition,
          'Championnat ($competitionCount)',
        ),
        const SizedBox(width: 8),
        _chip(context, _HeadToHeadScope.all, 'Toutes compétitions ($allCount)'),
        const SizedBox(width: 8),
        _chip(context, _HeadToHeadScope.home, 'À domicile ($homeCount)'),
      ],
    ),
  );

  Widget _chip(BuildContext context, _HeadToHeadScope value, String label) {
    final selected = scope == value;
    return OutlinedButton(
      onPressed: () => onChanged(value),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected
            ? context.brand.accent
            : context.textColors.secondary,
        backgroundColor: selected
            ? context.brand.accent.withValues(alpha: .10)
            : null,
        side: BorderSide(
          color: selected ? context.brand.accent : context.surfaces.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _DuelSummary extends StatelessWidget {
  const _DuelSummary({required this.match, required this.meetings});
  final MatchBoardItem match;
  final List<HeadToHeadFixtureSnapshot> meetings;

  @override
  Widget build(BuildContext context) {
    final firstId = match.fixture.homeTeam.apiFootballTeamId;
    final secondId = match.fixture.awayTeam.apiFootballTeamId;
    final firstWins = meetings
        .where((item) => _resultFor(firstId, item) > 0)
        .length;
    final secondWins = meetings
        .where((item) => _resultFor(secondId, item) > 0)
        .length;
    final draws = meetings.length - firstWins - secondWins;
    final firstGoals = meetings.fold(
      0,
      (total, item) => total + _goalsFor(firstId, item),
    );
    final secondGoals = meetings.fold(
      0,
      (total, item) => total + _goalsFor(secondId, item),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${meetings.length} confrontation${meetings.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SummarySide(
                  logoUrl: match.fixture.homeTeam.logoUrl,
                  name: match.fixture.homeTeam.name,
                  value: '$firstWins V',
                  goals: '$firstGoals buts',
                  color: firstWins > secondWins
                      ? context.semantic.success
                      : context.textColors.primary,
                  start: true,
                ),
                _SummaryMiddle(
                  draws: draws,
                  goalsPerMatch: (firstGoals + secondGoals) / meetings.length,
                ),
                _SummarySide(
                  logoUrl: match.fixture.awayTeam.logoUrl,
                  name: match.fixture.awayTeam.name,
                  value: '$secondWins V',
                  goals: '$secondGoals buts',
                  color: secondWins > firstWins
                      ? context.semantic.success
                      : context.semantic.error,
                  start: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySide extends StatelessWidget {
  const _SummarySide({
    required this.logoUrl,
    required this.name,
    required this.value,
    required this.goals,
    required this.color,
    required this.start,
  });
  final String? logoUrl;
  final String name;
  final String value;
  final String goals;
  final Color color;
  final bool start;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: start
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        SportsAssetBadge(
          size: 34,
          imageUrl: logoUrl,
          fallbackLabel: name,
          contrastPlate: true,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          goals,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _SummaryMiddle extends StatelessWidget {
  const _SummaryMiddle({required this.draws, required this.goalsPerMatch});
  final int draws;
  final double goalsPerMatch;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$draws N',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '${goalsPerMatch.toStringAsFixed(1).replaceAll('.', ',')} buts/match',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    required this.meeting,
    required this.firstTeamId,
    required this.selected,
    required this.onTap,
  });
  final HeadToHeadFixtureSnapshot meeting;
  final int? firstTeamId;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Container(
        width: 142,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: context.surfaces.surfaceHover.withValues(alpha: .26),
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(
            color: selected ? context.brand.accent : context.surfaces.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '${meeting.homeGoals} – ${meeting.awayGoals}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            _FactualTimeline(
              meeting: meeting,
              firstTeamId: firstTeamId,
              compact: true,
            ),
            const Spacer(),
            Text(
              _monthYear(meeting.playedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              meeting.competitionName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SelectedMatchDetail extends StatelessWidget {
  const _SelectedMatchDetail({
    required this.meeting,
    required this.firstTeamId,
    required this.firstTeamName,
    required this.secondTeamName,
    required this.firstTeamLogoUrl,
    required this.secondTeamLogoUrl,
  });
  final HeadToHeadFixtureSnapshot meeting;
  final int? firstTeamId;
  final String firstTeamName;
  final String secondTeamName;
  final String? firstTeamLogoUrl;
  final String? secondTeamLogoUrl;
  @override
  Widget build(BuildContext context) {
    final firstIsHome = meeting.homeTeamId == firstTeamId;
    final leftName = firstIsHome ? meeting.homeTeamName : meeting.awayTeamName;
    final rightName = firstIsHome ? meeting.awayTeamName : meeting.homeTeamName;
    final leftScore = firstIsHome ? meeting.homeGoals : meeting.awayGoals;
    final rightScore = firstIsHome ? meeting.awayGoals : meeting.homeGoals;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaces.surfaceHover.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _TeamName(logoUrl: firstTeamLogoUrl, name: leftName),
                ),
                SizedBox(
                  width: 118,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$leftScore – $rightScore',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: context.textColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '${_fullDate(meeting.playedAt)} · ${meeting.competitionName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.textColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _TeamName(
                    logoUrl: secondTeamLogoUrl,
                    name: rightName,
                    end: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Déroulé du match',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Les faits marquants, dans leur ordre réel.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _FactualTimeline(meeting: meeting, firstTeamId: firstTeamId),
            const SizedBox(height: 14),
            _CollectiveStats(meeting: meeting, firstTeamId: firstTeamId),
          ],
        ),
      ),
    );
  }
}

class _TeamName extends StatelessWidget {
  const _TeamName({
    required this.logoUrl,
    required this.name,
    this.end = false,
  });
  final String? logoUrl;
  final String name;
  final bool end;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final showBadge = constraints.maxWidth >= 72;
      return Row(
        mainAxisAlignment: end
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!end && showBadge)
            SportsAssetBadge(
              size: 30,
              imageUrl: logoUrl,
              fallbackLabel: name,
              contrastPlate: true,
            ),
          if (!end && showBadge) const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              textAlign: end ? TextAlign.end : TextAlign.start,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (end && showBadge) const SizedBox(width: 6),
          if (end && showBadge)
            SportsAssetBadge(
              size: 30,
              imageUrl: logoUrl,
              fallbackLabel: name,
              contrastPlate: true,
            ),
        ],
      );
    },
  );
}

class _FactualTimeline extends StatelessWidget {
  const _FactualTimeline({
    required this.meeting,
    required this.firstTeamId,
    this.compact = false,
  });
  final HeadToHeadFixtureSnapshot meeting;
  final int? firstTeamId;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final events = meeting.events.where(_isKeyEvent).toList()
      ..sort((a, b) => a.minute.compareTo(b.minute));
    final firstName = meeting.homeTeamId == firstTeamId
        ? meeting.homeTeamName
        : meeting.awayTeamName;
    final secondName = meeting.homeTeamId == firstTeamId
        ? meeting.awayTeamName
        : meeting.homeTeamName;
    final height = compact ? 46.0 : 182.0;
    if (events.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            compact
                ? 'Détails indisponibles'
                : 'Événements indisponibles pour cette confrontation.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final top = compact ? 9.0 : 56.0;
          final bottom = compact ? 28.0 : 126.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (!compact)
                Positioned(
                  left: 0,
                  top: top - 18,
                  child: Text(
                    firstName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              if (!compact)
                Positioned(
                  left: 0,
                  top: bottom + 7,
                  child: Text(
                    secondName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              Positioned(
                left: compact ? 0 : 72,
                right: 0,
                top: top,
                child: Container(height: 1.5, color: context.brand.accent),
              ),
              Positioned(
                left: compact ? 0 : 72,
                right: 0,
                top: bottom,
                child: Container(
                  height: 1.5,
                  color: context.semantic.error.withValues(alpha: .7),
                ),
              ),
              for (final minute in const [0, 15, 30, 45, 60, 75, 90])
                Positioned(
                  left:
                      (compact ? 0 : 72) +
                      (width - (compact ? 0 : 72)) * minute / 90 -
                      .5,
                  top: top - 4,
                  child: Container(
                    width: 1,
                    height: bottom - top + 8,
                    color: context.surfaces.border.withValues(alpha: .55),
                  ),
                ),
              for (final event in events)
                _EventOnLane(
                  event: event,
                  firstTeamId: firstTeamId,
                  left:
                      (compact ? 0 : 72) +
                      (width - (compact ? 0 : 72)) *
                          event.minute.clamp(0, 90) /
                          90,
                  top: top,
                  bottom: bottom,
                  compact: compact,
                ),
              if (!compact)
                Positioned(
                  left: 72,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final minute in const [0, 15, 30, 45, 60, 75, 90])
                        Text(
                          "$minute'",
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: context.textColors.secondary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EventOnLane extends StatelessWidget {
  const _EventOnLane({
    required this.event,
    required this.firstTeamId,
    required this.left,
    required this.top,
    required this.bottom,
    required this.compact,
  });
  final HeadToHeadMatchEventSnapshot event;
  final int? firstTeamId;
  final double left;
  final double top;
  final double bottom;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final isFirst = event.teamId == firstTeamId;
    final color = event.type.toLowerCase() == 'card'
        ? context.semantic.error
        : isFirst
        ? context.brand.accent
        : context.semantic.error;
    final icon = event.type.toLowerCase() == 'card'
        ? Icons.rectangle_rounded
        : event.type.toLowerCase() == 'var'
        ? Icons.videocam_rounded
        : Icons.sports_soccer_rounded;
    final label = event.playerName == null
        ? "${event.minute}'"
        : "${event.playerName} · ${event.minute}'";
    return Positioned(
      left: math.max(0, left - (compact ? 5 : 30)),
      top: isFirst
          ? (compact ? top - 8 : top - 43)
          : (compact ? bottom - 6 : bottom + 5),
      child: SizedBox(
        width: compact ? 11 : 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact)
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            Icon(icon, size: compact ? 10 : 17, color: color),
          ],
        ),
      ),
    );
  }
}

class _CollectiveStats extends StatelessWidget {
  const _CollectiveStats({required this.meeting, required this.firstTeamId});
  final HeadToHeadFixtureSnapshot meeting;
  final int? firstTeamId;
  @override
  Widget build(BuildContext context) {
    final first = meeting.homeTeamId == firstTeamId
        ? meeting.homeStatistics
        : meeting.awayStatistics;
    final second = meeting.homeTeamId == firstTeamId
        ? meeting.awayStatistics
        : meeting.homeStatistics;
    if (first == null && second == null) {
      return Text(
        'Statistiques indisponibles pour cette confrontation.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.textColors.secondary,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bilan collectif',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.textColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        for (final row in [
          ('Tirs', first?.totalShots, second?.totalShots),
          ('Tirs cadrés', first?.shotsOnGoal, second?.shotsOnGoal),
          ('xG', first?.expectedGoals, second?.expectedGoals),
        ])
          if (row.$2 != null || row.$3 != null)
            _StatRow(label: row.$1, first: row.$2, second: row.$3),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.first,
    required this.second,
  });

  final String label;
  final double? first;
  final double? second;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(first ?? 0, second ?? 0);
    final firstFraction = maxValue == 0 ? 0.0 : (first ?? 0) / maxValue;
    final secondFraction = maxValue == 0 ? 0.0 : (second ?? 0) / maxValue;
    final valueStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: context.textColors.primary,
      fontWeight: FontWeight.w900,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              _number(first),
              textAlign: TextAlign.center,
              style: valueStyle,
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: firstFraction,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.brand.accent,
                    borderRadius: BorderRadius.circular(AppRadius.indicator),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FractionallySizedBox(
              widthFactor: secondFraction,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: context.semantic.error.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(AppRadius.indicator),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              _number(second),
              textAlign: TextAlign.center,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }

  String _number(double? value) => value == null
      ? '—'
      : value % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(1).replaceAll('.', ',');
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.surfaceHover.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(AppRadius.input),
      border: Border.all(color: context.surfaces.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        'Aucune confrontation n’est disponible dans le snapshot actuel.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.textColors.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.surface.withValues(alpha: .64),
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.surfaces.border),
    ),
    child: Padding(padding: const EdgeInsets.all(13), child: child),
  );
}

bool _isKeyEvent(HeadToHeadMatchEventSnapshot event) {
  final type = event.type.toLowerCase();
  final detail = event.detail.toLowerCase();
  return type == 'goal' ||
      type == 'var' ||
      (type == 'card' &&
          (detail.contains('red') || detail.contains('yellow red')));
}

int _goalsFor(int? teamId, HeadToHeadFixtureSnapshot meeting) =>
    teamId == meeting.homeTeamId
    ? meeting.homeGoals
    : teamId == meeting.awayTeamId
    ? meeting.awayGoals
    : 0;
int _resultFor(int? teamId, HeadToHeadFixtureSnapshot meeting) =>
    _goalsFor(teamId, meeting).compareTo(
      teamId == meeting.homeTeamId ? meeting.awayGoals : meeting.homeGoals,
    );
String _monthYear(DateTime date) {
  const months = [
    'janv.',
    'févr.',
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
  return '${months[date.month - 1]} ${date.year}';
}

String _fullDate(DateTime date) => '${date.day} ${_monthYear(date)}';
