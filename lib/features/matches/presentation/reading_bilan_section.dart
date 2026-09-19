import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../data/match_reading_bilan_repository.dart';

class ReadingBilanSection extends StatefulWidget {
  const ReadingBilanSection({this.repository, super.key});

  final MatchReadingBilanRepository? repository;

  @override
  State<ReadingBilanSection> createState() => _ReadingBilanSectionState();
}

class _ReliabilityHero extends StatelessWidget {
  const _ReliabilityHero({
    required this.rate,
    required this.evaluable,
    required this.confirmed,
  });

  final double? rate;
  final int evaluable;
  final int confirmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: [
          _RateRing(rate: rate, size: 78),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fiabilité observée',
                  style: TextStyle(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  evaluable == 0
                      ? 'En attente de premiers résultats vérifiables'
                      : '$evaluable résultats évaluables · $confirmed confirmés',
                  style: TextStyle(color: context.textColors.secondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lecture par lecture, sans scénarios ni nuances.',
                  style: TextStyle(color: context.brand.accent, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReliabilityMap extends StatelessWidget {
  const _ReliabilityMap({required this.summaries, required this.onTap});

  final List<MatchReadingBilanSummary> summaries;
  final ValueChanged<MatchReadingBilanSummary> onTap;

  @override
  Widget build(BuildContext context) {
    final maxVolume = summaries.fold<int>(
      1,
      (maximum, item) => math.max(maximum, item.evaluable),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.scatter_plot_rounded, color: context.brand.accent),
              const SizedBox(width: 8),
              Text(
                'Carte de fiabilité',
                style: TextStyle(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Touchez une pastille pour comprendre la règle et les résultats.',
            style: TextStyle(color: context.textColors.secondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (summaries.isEmpty)
            SizedBox(
              height: 170,
              child: Center(
                child: Text(
                  'Aucune lecture objectivement évaluée.',
                  style: TextStyle(color: context.textColors.secondary),
                ),
              ),
            )
          else
            SizedBox(
              height: 224,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const left = 28.0;
                  const right = 8.0;
                  const top = 8.0;
                  const bottom = 30.0;
                  final plotWidth = constraints.maxWidth - left - right;
                  final plotHeight = constraints.maxHeight - top - bottom;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ReliabilityMapPainter(
                            grid: context.surfaces.border,
                            text: context.textColors.secondary,
                          ),
                        ),
                      ),
                      for (final summary in summaries)
                        _BubblePosition(
                          summary: summary,
                          maxVolume: maxVolume,
                          left: left,
                          top: top,
                          plotWidth: plotWidth,
                          plotHeight: plotHeight,
                          onTap: () => onTap(summary),
                        ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                'Contredite',
                style: TextStyle(color: context.semantic.error, fontSize: 11),
              ),
              const Spacer(),
              Text(
                'Confirmée',
                style: TextStyle(color: context.semantic.success, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BubblePosition extends StatelessWidget {
  const _BubblePosition({
    required this.summary,
    required this.maxVolume,
    required this.left,
    required this.top,
    required this.plotWidth,
    required this.plotHeight,
    required this.onTap,
  });

  final MatchReadingBilanSummary summary;
  final int maxVolume;
  final double left;
  final double top;
  final double plotWidth;
  final double plotHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rate = summary.confirmationPercent ?? 0;
    final diameter = (34 + math.sqrt(summary.evaluable) * 7)
        .clamp(42, 68)
        .toDouble();
    final x = left + plotWidth * (rate / 100) - diameter / 2;
    final y =
        top + plotHeight * (1 - summary.evaluable / maxVolume) - diameter / 2;
    final color = rate >= 65
        ? context.semantic.success
        : rate >= 45
        ? context.semantic.warning
        : context.semantic.error;
    return Positioned(
      left: x.clamp(left - diameter / 2, left + plotWidth - diameter / 2),
      top: y.clamp(top - diameter / 2, top + plotHeight - diameter / 2),
      child: Semantics(
        button: true,
        label:
            '${summary.readingLabel}, ${rate.round()} %, ${summary.evaluable} résultats évaluables',
        child: Tooltip(
          message:
              '${summary.readingLabel}\n${rate.round()} % · ${summary.evaluable} résultats',
          child: Material(
            color: color.withValues(alpha: .16),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Container(
                key: ValueKey('bilan-reading-${summary.readingId}'),
                width: diameter,
                height: diameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(
                    _bubbleLabel(summary.readingLabel),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textColors.primary,
                      fontSize: diameter >= 58 ? 10 : 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _bubbleLabel(String value) {
  final words = value.split(' ').where((word) => word.isNotEmpty).toList();
  if (words.length <= 2) return value;
  return '${words.take(2).join(' ')}\n${words.skip(2).first}';
}

class _ReliabilityMapPainter extends CustomPainter {
  const _ReliabilityMapPainter({required this.grid, required this.text});

  final Color grid;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0;
    const top = 8.0;
    const right = 8.0;
    const bottom = 30.0;
    final paint = Paint()
      ..color = grid.withValues(alpha: .6)
      ..strokeWidth = 1;
    final plotWidth = size.width - left - right;
    final plotHeight = size.height - top - bottom;
    for (var index = 0; index <= 4; index += 1) {
      final x = left + plotWidth * index / 4;
      final y = top + plotHeight * index / 4;
      canvas.drawLine(Offset(x, top), Offset(x, top + plotHeight), paint);
      canvas.drawLine(Offset(left, y), Offset(left + plotWidth, y), paint);
    }
    canvas.drawLine(
      Offset(left, top + plotHeight),
      Offset(left + plotWidth, top + plotHeight),
      paint..strokeWidth = 1.5,
    );
    canvas.drawLine(Offset(left, top), Offset(left, top + plotHeight), paint);
    _paintText(canvas, 'Volume', const Offset(0, 95), text, rotate: true);
  }

  void _paintText(
    Canvas canvas,
    String value,
    Offset offset,
    Color color, {
    bool rotate = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (rotate) {
      canvas.save();
      canvas.translate(offset.dx + 10, offset.dy + painter.width / 2);
      canvas.rotate(-math.pi / 2);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
      return;
    }
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ReliabilityMapPainter oldDelegate) =>
      oldDelegate.grid != grid || oldDelegate.text != text;
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Material(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: context.surfaces.border),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: context.textColors.secondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadingReliabilitySheet extends StatefulWidget {
  const _ReadingReliabilitySheet({
    required this.repository,
    required this.summary,
    required this.since,
  });

  final MatchReadingBilanRepository repository;
  final MatchReadingBilanSummary summary;
  final DateTime since;

  @override
  State<_ReadingReliabilitySheet> createState() =>
      _ReadingReliabilitySheetState();
}

class _ReadingReliabilitySheetState extends State<_ReadingReliabilitySheet> {
  late final Future<List<MatchReadingBilanEntry>> _entries;
  bool _showMatches = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.repository.loadForReading(
      readingId: widget.summary.readingId,
      since: widget.since,
      offset: 0,
      limit: 80,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    return DraggableScrollableSheet(
      initialChildSize: .78,
      minChildSize: .48,
      maxChildSize: .95,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: context.surfaces.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: context.surfaces.border),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textColors.weak,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LECTURE · PERFORMANCE',
                        style: TextStyle(
                          color: context.brand.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.readingLabel,
                        style: TextStyle(
                          color: context.textColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _RateRing(rate: summary.confirmationPercent, size: 104),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.evaluable} résultats évaluables',
                        style: TextStyle(
                          color: context.textColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _VerdictMetric(
                        color: context.semantic.success,
                        label: '${summary.confirmed} confirmées',
                      ),
                      const SizedBox(height: 5),
                      _VerdictMetric(
                        color: context.semantic.error,
                        label: '${summary.contradicted} contredites',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<MatchReadingBilanEntry>>(
              future: _entries,
              builder: (context, snapshot) {
                final entries =
                    snapshot.data ?? const <MatchReadingBilanEntry>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EvaluationRuleCard(entries: entries),
                    const SizedBox(height: 16),
                    _Timeline(entries: entries),
                    const SizedBox(height: 18),
                    Text(
                      'Détails par contexte',
                      style: TextStyle(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ContextBar(
                      label: 'Global',
                      rate: summary.confirmationPercent,
                      count: summary.evaluable,
                    ),
                    if (summary.homeEvaluable > 0) ...[
                      const SizedBox(height: 9),
                      _ContextBar(
                        label: 'Domicile',
                        rate: summary.homeConfirmationRate,
                        count: summary.homeEvaluable,
                      ),
                    ],
                    if (summary.awayEvaluable > 0) ...[
                      const SizedBox(height: 9),
                      _ContextBar(
                        label: 'Extérieur',
                        rate: summary.awayConfirmationRate,
                        count: summary.awayEvaluable,
                      ),
                    ],
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: snapshot.hasData
                          ? () => setState(() => _showMatches = !_showMatches)
                          : null,
                      icon: Icon(
                        _showMatches
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      label: Text(
                        _showMatches
                            ? 'Masquer les matchs'
                            : 'Voir les ${math.min(summary.total, 80)} matchs',
                      ),
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 12),
                      const _InfoCard(
                        title: 'Historique indisponible',
                        message:
                            'La synthèse reste disponible, mais les matchs ne '
                            'peuvent pas être chargés.',
                      ),
                    ],
                    if (_showMatches && snapshot.hasData) ...[
                      const SizedBox(height: 12),
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ReadingVerdictCard(entry: entry),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RateRing extends StatelessWidget {
  const _RateRing({required this.rate, required this.size});

  final double? rate;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = rate == null ? 0.0 : (rate! / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: size >= 100 ? 9 : 7,
              backgroundColor: context.surfaces.surfaceHover,
              color: context.brand.accent,
            ),
          ),
          Text(
            rate == null ? '—' : '${rate!.round()}%',
            style: TextStyle(
              color: context.textColors.primary,
              fontSize: size >= 100 ? 25 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictMetric extends StatelessWidget {
  const _VerdictMetric({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: context.textColors.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _ReadingBilanSectionState extends State<ReadingBilanSection> {
  late Future<List<MatchReadingBilanSummary>> _summary;
  int _periodDays = 30;

  DateTime get _since => DateTime.now().subtract(Duration(days: _periodDays));

  MatchReadingBilanRepository get _repository =>
      widget.repository ??
      SupabaseMatchReadingBilanRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _summary = Future.sync(() => _repository.loadSummary(since: _since));
  }

  void _openReading(MatchReadingBilanSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _ReadingReliabilitySheet(
        repository: _repository,
        summary: summary,
        since: _since,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MatchReadingBilanSummary>>(
      future: _summary,
      builder: (context, snapshot) {
        final summaries = snapshot.data ?? const <MatchReadingBilanSummary>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Text(
              'Bilan Lector',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.textColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Les performances observées des lectures mesurables. '
              'Les scénarios et nuances sont analysés séparément.',
              style: TextStyle(color: context.textColors.secondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final days in [7, 30, 90])
                  ChoiceChip(
                    label: Text('$days jours'),
                    selected: _periodDays == days,
                    onSelected: (_) {
                      setState(() {
                        _periodDays = days;
                        _reload();
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              _InfoCard(
                title: 'Le bilan est indisponible',
                message: 'Impossible de charger les résultats pour le moment.',
                action: TextButton(
                  onPressed: () => setState(_reload),
                  child: const Text('Réessayer'),
                ),
              )
            else if (!snapshot.hasData)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (summaries.isEmpty)
              const _InfoCard(
                title: 'Aucune lecture évaluée pour cette période',
                message:
                    'Le bilan apparaîtra après la publication des annonces '
                    'et la récupération des résultats des matchs.',
              )
            else
              ..._content(context, summaries),
          ],
        );
      },
    );
  }

  List<Widget> _content(
    BuildContext context,
    List<MatchReadingBilanSummary> summaries,
  ) {
    final mapped = summaries.where((item) => item.evaluable > 0).toList();
    final evaluable = mapped.fold<int>(0, (sum, item) => sum + item.evaluable);
    final confirmed = mapped.fold<int>(0, (sum, item) => sum + item.confirmed);
    final rate = evaluable == 0 ? null : confirmed * 100 / evaluable;
    final awaiting = summaries.where((item) => item.evaluable == 0).length;
    final insufficient = mapped.where((item) => item.evaluable < 5).length;
    final best = mapped
        .where((item) => item.evaluable >= 5)
        .fold<MatchReadingBilanSummary?>(null, (best, item) {
          if (best == null ||
              (item.confirmationPercent ?? 0) >
                  (best.confirmationPercent ?? 0)) {
            return item;
          }
          return best;
        });
    if (summaries.isEmpty) {
      return const [
        _InfoCard(
          title: 'Aucune lecture publiée sur cette période',
          message:
              'La carte apparaîtra après la publication des annonces et la '
              'récupération des résultats finaux.',
        ),
      ];
    }
    return [
      _ReliabilityHero(rate: rate, evaluable: evaluable, confirmed: confirmed),
      const SizedBox(height: 14),
      _ReliabilityMap(summaries: mapped, onTap: _openReading),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (best != null)
            _InsightCard(
              icon: Icons.trending_up_rounded,
              title: best.readingLabel,
              value:
                  '${best.confirmationPercent!.round()} % · ${best.evaluable} résultats',
              color: context.semantic.success,
              onTap: () => _openReading(best),
            ),
          _InsightCard(
            icon: Icons.hourglass_bottom_rounded,
            title: insufficient > 0
                ? 'Données insuffisantes'
                : 'Lectures en attente',
            value: insufficient > 0
                ? '$insufficient lecture${insufficient > 1 ? 's' : ''} sous 5 résultats'
                : '$awaiting lecture${awaiting > 1 ? 's' : ''} à évaluer',
            color: context.semantic.warning,
          ),
        ],
      ),
      if (mapped.isEmpty) ...[
        const SizedBox(height: 14),
        const _InfoCard(
          title: 'Pas encore de résultat vérifiable',
          message:
              'Les lectures sont bien annoncées, mais une performance ne sera '
              'affichée qu’après le résultat final du match.',
        ),
      ],
    ];
  }
}

class _EvaluationRuleCard extends StatelessWidget {
  const _EvaluationRuleCard({required this.entries});
  final List<MatchReadingBilanEntry> entries;

  @override
  Widget build(BuildContext context) {
    final first = entries.isEmpty ? null : entries.first;
    final evidence = first?.evidence.isNotEmpty == true
        ? first!.evidence.first['label']?.toString()
        : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comment la lecture est évaluée',
            style: TextStyle(
              color: context.textColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _outcomeRuleText(first?.outcomeRule),
            style: TextStyle(color: context.textColors.secondary),
          ),
          if (evidence != null) ...[
            const SizedBox(height: 8),
            Text(
              'Signal avant match : $evidence',
              style: TextStyle(color: context.brand.accent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

String _outcomeRuleText(String? rule) => switch (rule) {
  'over_25' =>
    'Confirmée si le match compte au moins trois buts au score final.',
  'under_25' =>
    'Confirmée si le match compte au plus deux buts au score final.',
  'btts' => 'Confirmée si les deux équipes marquent.',
  'team_win' => 'Confirmée si l’équipe concernée remporte le match.',
  'team_not_lose' => 'Confirmée si l’équipe concernée gagne ou fait match nul.',
  'team_loss' => 'Confirmée si l’équipe concernée perd le match.',
  'team_scores' => 'Confirmée si l’équipe concernée marque.',
  'team_no_score' => 'Confirmée si l’équipe concernée ne marque pas.',
  'team_clean_sheet' =>
    'Confirmée si l’équipe concernée ne concède pas de but.',
  'team_concedes' => 'Confirmée si l’équipe concernée concède un but.',
  'first_half_scores' =>
    'Confirmée si l’équipe concernée marque en première période.',
  'first_half_concedes' =>
    'Confirmée si l’équipe concernée concède en première période.',
  'second_half_scores' =>
    'Confirmée si l’équipe concernée marque en seconde période.',
  'second_half_concedes' =>
    'Confirmée si l’équipe concernée concède en seconde période.',
  'player_decisive' => 'Confirmée si le joueur concerné est décisif.',
  _ =>
    'Cette lecture est un constat de contexte et ne reçoit pas de taux de confirmation.',
};

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});
  final List<MatchReadingBilanEntry> entries;

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]
      ..sort((first, second) => first.kickoffAt.compareTo(second.kickoffAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chronologie des résultats',
          style: TextStyle(
            color: context.textColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        if (sorted.isEmpty)
          Text(
            'Les matchs apparaîtront après leur évaluation.',
            style: TextStyle(color: context.textColors.secondary, fontSize: 12),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in sorted)
                Tooltip(
                  message:
                      '${entry.homeTeamName ?? 'Équipe A'} – ${entry.awayTeamName ?? 'Équipe B'}',
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: _timelineColor(context, entry.verdict),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          'Vert : confirmée · Rouge : contredite · Gris : non évaluable ou en attente',
          style: TextStyle(color: context.textColors.secondary, fontSize: 11),
        ),
      ],
    );
  }

  Color _timelineColor(BuildContext context, String? verdict) =>
      switch (verdict) {
        'confirmed' => context.semantic.success,
        'contradicted' => context.semantic.error,
        _ => context.textColors.weak,
      };
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({
    required this.label,
    required this.rate,
    required this.count,
  });
  final String label;
  final double? rate;
  final int count;

  @override
  Widget build(BuildContext context) {
    final progress = ((rate ?? 0) / 100).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(color: context.textColors.secondary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: context.brand.accent,
              backgroundColor: context.surfaces.surfaceHover,
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 58,
          child: Text(
            '${rate?.round() ?? '—'}% · $count',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: context.textColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class ReadingVerdictCard extends StatelessWidget {
  const ReadingVerdictCard({required this.entry, super.key});

  final MatchReadingBilanEntry entry;

  @override
  Widget build(BuildContext context) {
    final verdict = switch (entry.verdict) {
      'confirmed' => ('Confirmée', context.semantic.success),
      'contradicted' => ('Contredite', context.semantic.error),
      'not_evaluable' => ('Non évaluable', context.semantic.warning),
      'context_only' => ('Constat d’avant-match', context.textColors.secondary),
      'caution_confirmed' => ('Nuance pertinente', context.semantic.warning),
      'caution_not_confirmed' => (
        'Nuance non confirmée',
        context.textColors.secondary,
      ),
      _ => ('En attente', context.textColors.secondary),
    };
    final teams = entry.homeTeamName != null && entry.awayTeamName != null
        ? '${entry.homeTeamName} – ${entry.awayTeamName}'
        : 'Match ${entry.fixtureId}';
    final score = entry.hasResult
        ? '${entry.homeGoals}–${entry.awayGoals}'
        : 'Résultat attendu';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  teams,
                  style: TextStyle(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                score,
                style: TextStyle(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            entry.readingLabel,
            style: TextStyle(color: context.textColors.secondary),
          ),
          const SizedBox(height: 7),
          Text(
            verdict.$1,
            style: TextStyle(color: verdict.$2, fontWeight: FontWeight.w800),
          ),
          if (entry.explanation != null) ...[
            const SizedBox(height: 3),
            Text(
              entry.explanation!,
              style: TextStyle(
                color: context.textColors.secondary,
                fontSize: 12,
              ),
            ),
          ],
          if (entry.evidence.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Annonce : ${entry.evidence.first['label'] ?? entry.readingLabel}',
              style: TextStyle(
                color: context.textColors.secondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.message, this.action});
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.surfaces.backgroundSecondary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.surfaces.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.textColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(message, style: TextStyle(color: context.textColors.secondary)),
        ?action,
      ],
    ),
  );
}
