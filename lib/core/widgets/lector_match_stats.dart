import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';

class LectorMatchStatistic {
  const LectorMatchStatistic({required this.label, this.first, this.second});
  final String label;
  final String? first, second;
  double? get firstNumber => _number(first);
  double? get secondNumber => _number(second);
  static double? _number(String? value) {
    final n = double.tryParse(value?.replaceAll('%', '') ?? '');
    return n != null && n.isFinite && n >= 0 ? n : null;
  }
}

class LectorMatchStatScope {
  const LectorMatchStatScope({required this.label, required this.rows});
  final String label;
  final List<LectorMatchStatistic> rows;
}

class LectorMatchPeriod {
  const LectorMatchPeriod(this.label, this.start, this.end);
  final String label;
  final double start, end;
}

enum LectorMatchEventKind {
  goal,
  warning,
  dismissal,
  substitution,
  review,
  other,
}

class LectorMatchEvent {
  const LectorMatchEvent({
    required this.clock,
    required this.label,
    this.detail,
    this.firstTeam,
    this.order,
    this.position,
    this.scoreLabel,
    this.kind = LectorMatchEventKind.other,
    this.icon = Icons.circle_outlined,
  });
  final String clock, label;
  final String? detail, scoreLabel;
  final bool? firstTeam;
  final int? order;
  // Sport adapter supplies a real elapsed position; unknown clocks stay unplotted.
  final double? position;
  final LectorMatchEventKind kind;
  final IconData icon;
}

/// Sport adapters supply facts, periods and participant order. No pre-match
/// readings, estimates or fabricated spatial data enter this shared layout.
class LectorMatchStats extends StatefulWidget {
  const LectorMatchStats({
    required this.firstTeam,
    required this.secondTeam,
    required this.rows,
    this.capturedAt,
    this.scoreLabel,
    this.clockLabel,
    this.currentPosition,
    this.isLive = false,
    this.isFinal = false,
    this.finalStatistics = false,
    this.sceneAsset,
    this.summary,
    this.events = const [],
    this.scopes = const [],
    this.periods = const [],
    this.primaryLabels = const [],
    this.eventsCapturedAt,
    super.key,
  });
  final String firstTeam, secondTeam;
  final String? scoreLabel, summary, sceneAsset, clockLabel;
  final double? currentPosition;
  final List<LectorMatchStatistic> rows;
  final List<LectorMatchEvent> events;
  final List<LectorMatchStatScope> scopes;
  final List<LectorMatchPeriod> periods;
  final List<String> primaryLabels;
  final DateTime? capturedAt, eventsCapturedAt;
  final bool isLive, isFinal, finalStatistics;

  @override
  State<LectorMatchStats> createState() => _LectorMatchStatsState();

  Widget _card(BuildContext context, Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.surfaces.surface,
      border: Border.all(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );

  Widget _build(BuildContext context) {
    final available = rows
        .where((r) => r.firstNumber != null || r.secondNumber != null)
        .toList();
    final main = primaryLabels.isEmpty
        ? available.take(4).toList()
        : available.where((r) => primaryLabels.contains(r.label)).toList();
    final ordered = [...events]
      ..sort((a, b) => (a.order ?? 1000000).compareTo(b.order ?? 1000000));
    final stale =
        isLive &&
        capturedAt != null &&
        DateTime.now().difference(capturedAt!) > const Duration(minutes: 3);
    Widget heading(String title) =>
        Text(title, style: Theme.of(context).textTheme.titleMedium);
    Widget teamNames() => Row(
      children: [
        Expanded(
          child: Text(
            firstTeam,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (sceneAsset != null && scoreLabel != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              scoreLabel!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        Expanded(
          child: Text(
            secondTeam,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
    Widget freshness() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (capturedAt != null)
          Text(
            '${isFinal && finalStatistics ? 'Statistiques finales' : 'Dernières statistiques reçues'} · ${DateFormat('dd/MM/yyyy · HH:mm').format(capturedAt!.toLocal())}',
            style: TextStyle(color: context.textColors.secondary, fontSize: 12),
          ),
        if (isFinal && available.isNotEmpty && !finalStatistics)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Dernière collecte disponible ; les statistiques finales ne sont pas encore confirmées.',
              style: TextStyle(
                color: context.textColors.secondary,
                fontSize: 12,
              ),
            ),
          ),
        if (stale)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Statistiques en attente d’actualisation',
              style: TextStyle(color: context.semantic.warning),
            ),
          ),
      ],
    );
    return Column(
      key: const ValueKey('current-match-stats'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sceneAsset != null && available.isNotEmpty) ...[
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('Statistiques du match'),
                const SizedBox(height: 12),
                teamNames(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 68,
                      child: _SceneValues(
                        rows: available.take(3).toList(),
                        first: true,
                      ),
                    ),
                    Expanded(
                      child: Image.asset(
                        sceneAsset!,
                        height: 130,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                    SizedBox(
                      width: 68,
                      child: _SceneValues(
                        rows: available.take(3).toList(),
                        first: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                freshness(),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        _card(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: heading(
                      isLive
                          ? 'À cet instant'
                          : isFinal
                          ? 'Chiffres du match'
                          : 'Données du match',
                    ),
                  ),
                  if (isLive && clockLabel != null)
                    Text(
                      clockLabel!,
                      style: TextStyle(
                        color: context.semantic.live,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (sceneAsset == null) ...[
                teamNames(),
                const SizedBox(height: 8),
              ],
              if (available.isEmpty) ...[
                if (scoreLabel != null)
                  Text(
                    scoreLabel!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                const SizedBox(height: 8),
                Text(
                  isFinal
                      ? 'Le fournisseur n’a pas transmis de statistiques pour cette rencontre.'
                      : 'Les statistiques de cette rencontre ne sont pas encore disponibles.',
                  style: TextStyle(color: context.textColors.secondary),
                ),
              ],
              if (available.isNotEmpty)
                _ScopedComparisons(
                  rows: main.isEmpty ? available.take(6).toList() : main,
                  scopes: scopes,
                ),
              if (sceneAsset == null) ...[
                const SizedBox(height: 8),
                freshness(),
              ],
            ],
          ),
        ),
        if (summary != null && !stale) ...[
          const SizedBox(height: 10),
          _card(
            context,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: context.brand.accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: context.brand.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLive ? 'Lecture du live' : 'Lecture du résultat',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 5),
                      Text(summary!),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (ordered.isNotEmpty) ...[
          const SizedBox(height: 10),
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('Fil du match'),
                if (eventsCapturedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Événements reçus le ${DateFormat('dd/MM/yyyy · HH:mm').format(eventsCapturedAt!.toLocal())}',
                      style: TextStyle(
                        color: context.textColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (periods.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _MatchTimeline(
                    events: ordered,
                    periods: periods,
                    currentPosition: isLive ? currentPosition : null,
                    clockLabel: clockLabel,
                  ),
                ],
                const SizedBox(height: 12),
                heading('Événements'),
                for (final event in ordered.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            event.clock,
                            style: TextStyle(
                              color: context.textColors.secondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(
                            event.icon,
                            size: 20,
                            color: _eventColor(context, event),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (event.detail?.isNotEmpty == true)
                                Text(
                                  event.detail!,
                                  style: TextStyle(
                                    color: context.textColors.secondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (event.scoreLabel != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              event.scoreLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (available.isNotEmpty) ...[
          const SizedBox(height: 10),
          _card(
            context,
            ExpansionTile(
              key: const ValueKey('match-statistics-details'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Statistiques détaillées'),
              leading: Icon(
                Icons.bar_chart_rounded,
                color: context.brand.accent,
              ),
              children: [
                teamNames(),
                const SizedBox(height: 8),
                for (final row in available) _RawStatistic(row: row),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// Only freshness changes with time; provider clock and facts never advance locally.
class _LectorMatchStatsState extends State<LectorMatchStats> {
  Timer? _freshness;
  void _schedule() {
    _freshness?.cancel();
    if (widget.isLive) {
      _freshness = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant LectorMatchStats old) {
    super.didUpdateWidget(old);
    if (old.isLive != widget.isLive) _schedule();
  }

  @override
  void dispose() {
    _freshness?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget._build(context);
}

class _SceneValues extends StatelessWidget {
  const _SceneValues({required this.rows, required this.first});
  final List<LectorMatchStatistic> rows;
  final bool first;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: first
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end,
    children: [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: first
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                (first ? row.first : row.second) ?? '—',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: first
                      ? context.brand.accent
                      : context.textColors.primary,
                ),
              ),
              Text(
                row.label,
                style: TextStyle(
                  fontSize: 11,
                  color: context.textColors.secondary,
                ),
                textAlign: first ? TextAlign.start : TextAlign.end,
              ),
            ],
          ),
        ),
    ],
  );
}

class _ScopedComparisons extends StatefulWidget {
  const _ScopedComparisons({required this.rows, required this.scopes});
  final List<LectorMatchStatistic> rows;
  final List<LectorMatchStatScope> scopes;
  @override
  State<_ScopedComparisons> createState() => _ScopedComparisonsState();
}

class _ScopedComparisonsState extends State<_ScopedComparisons> {
  String _scope = 'Match';
  @override
  Widget build(BuildContext context) {
    final scopes = [
      LectorMatchStatScope(label: 'Match', rows: widget.rows),
      ...widget.scopes,
    ];
    final active =
        scopes.where((s) => s.label == _scope).firstOrNull ?? scopes.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.scopes.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final scope in scopes)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(scope.label),
                      selected: active.label == scope.label,
                      onSelected: (_) => setState(() => _scope = scope.label),
                    ),
                  ),
              ],
            ),
          ),
        for (final row in active.rows.where(
          (r) => r.firstNumber != null || r.secondNumber != null,
        ))
          _StatisticComparison(row: row),
      ],
    );
  }
}

class _StatisticComparison extends StatelessWidget {
  const _StatisticComparison({required this.row});
  final LectorMatchStatistic row;
  @override
  Widget build(BuildContext context) {
    final a = row.firstNumber, b = row.secondNumber;
    final total = a != null && b != null ? a + b : 0.0;
    final share = total > 0 ? a! / total : .5;
    return Semantics(
      label:
          '${row.label}, ${row.first ?? 'indisponible'} contre ${row.second ?? 'indisponible'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    row.first ?? '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                Expanded(child: Text(row.label, textAlign: TextAlign.center)),
                SizedBox(
                  width: 48,
                  child: Text(
                    row.second ?? '—',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            if (a != null && b != null && total > 0) ...[
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: SizedBox(
                  height: 12,
                  child: LayoutBuilder(
                    builder: (context, c) => Semantics(
                      label:
                          'Part du total : ${(share * 100).round()} % pour la première équipe',
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 3,
                            left: 0,
                            right: 0,
                            height: 6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.indicator,
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ColoredBox(
                                      color: context.semantic.success,
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: share * c.maxWidth,
                                    child: ColoredBox(
                                      color: context.semantic.info,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: c.maxWidth / 2 - .5,
                            child: Container(
                              width: 1,
                              height: 12,
                              color: context.textColors.secondary,
                            ),
                          ),
                          Positioned(
                            top: 1,
                            left: (share * c.maxWidth - 5).clamp(
                              0,
                              c.maxWidth - 10,
                            ),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: context.textColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.surfaces.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RawStatistic extends StatelessWidget {
  const _RawStatistic({required this.row});
  final LectorMatchStatistic row;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(flex: 2, child: Text(row.label)),
        Expanded(
          child: Text(
            row.first ?? '—',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Text(
            row.second ?? '—',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

Color _eventColor(BuildContext context, LectorMatchEvent event) =>
    switch (event.kind) {
      LectorMatchEventKind.warning => context.semantic.warning,
      LectorMatchEventKind.dismissal => context.semantic.error,
      _ =>
        event.firstTeam == false ? context.semantic.info : context.brand.accent,
    };

class _MatchTimeline extends StatelessWidget {
  const _MatchTimeline({
    required this.events,
    required this.periods,
    this.currentPosition,
    this.clockLabel,
  });
  final List<LectorMatchEvent> events;
  final List<LectorMatchPeriod> periods;
  final double? currentPosition;
  final String? clockLabel;
  @override
  Widget build(BuildContext context) {
    final end = periods.last.end;
    if (end <= 0) return const SizedBox.shrink();
    final plotted = events
        .where(
          (e) => e.position != null && e.position! >= 0 && e.position! <= end,
        )
        .toList();
    // A lane for each close event preserves genuine simultaneity on small screens.
    return LayoutBuilder(
      builder: (context, c) {
        final laneEnds = <double>[];
        final positioned = <(LectorMatchEvent, int)>[];
        for (final event in plotted) {
          final x = event.position! / end * c.maxWidth;
          var lane = laneEnds.indexWhere((previous) => x - previous >= 36);
          if (lane < 0) {
            lane = laneEnds.length;
            laneEnds.add(x);
          } else {
            laneEnds[lane] = x;
          }
          positioned.add((event, lane));
        }
        final height = 66.0 + laneEnds.length * 42;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final period in periods)
                Positioned(
                  left: period.start / end * c.maxWidth,
                  width: (period.end - period.start) / end * c.maxWidth,
                  top: 0,
                  child: Text(
                    '${period.label}\n${period.start.toInt()}′ – ${period.end.toInt()}′',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textColors.secondary,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 42,
                height: 2,
                child: ColoredBox(color: context.surfaces.border),
              ),
              for (final period in periods.skip(1))
                Positioned(
                  left: period.start / end * c.maxWidth,
                  top: 38,
                  child: Container(
                    width: 1,
                    height: 12,
                    color: context.textColors.secondary,
                  ),
                ),
              if (currentPosition != null &&
                  currentPosition! >= 0 &&
                  currentPosition! <= end)
                Positioned(
                  left: (currentPosition! / end * c.maxWidth - 21).clamp(
                    0,
                    c.maxWidth - 42,
                  ),
                  top: 37,
                  width: 42,
                  child: Column(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: context.semantic.live,
                      ),
                      Text(
                        clockLabel ?? '${currentPosition!.toInt()}′',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.semantic.live,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final (event, lane) in positioned)
                Positioned(
                  left: (event.position! / end * c.maxWidth).clamp(
                    0,
                    c.maxWidth - 1,
                  ),
                  top: 44,
                  height: 22 + lane * 42.0,
                  width: 1,
                  child: ColoredBox(
                    color: _eventColor(context, event).withValues(alpha: .35),
                  ),
                ),
              for (final (event, lane) in positioned)
                Positioned(
                  left: (event.position! / end * c.maxWidth - 18).clamp(
                    0,
                    c.maxWidth - 36,
                  ),
                  top: 66 + lane * 42.0,
                  width: 36,
                  child: Tooltip(
                    message: '${event.clock} · ${event.label}',
                    child: Column(
                      children: [
                        Icon(
                          event.icon,
                          size: 17,
                          color: _eventColor(context, event),
                        ),
                        Text(
                          event.clock,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.textColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
