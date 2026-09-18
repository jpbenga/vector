import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../data/match_reading_bilan_repository.dart';

class ReadingBilanSection extends StatefulWidget {
  const ReadingBilanSection({this.repository, super.key});

  final MatchReadingBilanRepository? repository;

  @override
  State<ReadingBilanSection> createState() => _ReadingBilanSectionState();
}

class _ReadingBilanSectionState extends State<ReadingBilanSection> {
  late Future<List<MatchReadingBilanSummary>> _summary;
  int _periodDays = 30;
  String? _selectedReadingId;
  String? _selectedVerdict;
  List<MatchReadingBilanEntry> _details = const [];
  bool _loadingDetails = false;
  bool _hasMoreDetails = true;
  bool _detailsFailed = false;
  int _detailRequestVersion = 0;

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

  void _selectReading(String readingId) {
    setState(() {
      _selectedReadingId = _selectedReadingId == readingId ? null : readingId;
      _selectedVerdict = null;
      _resetDetails();
    });
    if (_selectedReadingId != null) _loadNextPage();
  }

  void _selectVerdict(String? verdict) {
    setState(() {
      _selectedVerdict = verdict;
      _resetDetails();
    });
    _loadNextPage();
  }

  void _resetDetails() {
    _detailRequestVersion += 1;
    _details = const [];
    _loadingDetails = false;
    _hasMoreDetails = true;
    _detailsFailed = false;
  }

  Future<void> _loadNextPage() async {
    final readingId = _selectedReadingId;
    if (readingId == null || _loadingDetails || !_hasMoreDetails) return;
    final requestVersion = _detailRequestVersion;
    setState(() {
      _loadingDetails = true;
      _detailsFailed = false;
    });
    try {
      final page = await _repository.loadForReading(
        readingId: readingId,
        since: _since,
        verdict: _selectedVerdict,
        offset: _details.length,
        limit: 20,
      );
      if (!mounted || requestVersion != _detailRequestVersion) return;
      setState(() {
        _details = [..._details, ...page];
        _loadingDetails = false;
        _hasMoreDetails = page.length == 20;
      });
    } catch (_) {
      if (!mounted || requestVersion != _detailRequestVersion) return;
      setState(() {
        _loadingDetails = false;
        _detailsFailed = true;
      });
    }
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
              'Bilan des lectures',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.textColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Toutes les lectures annoncées, tous les championnats. '
              'Vos préférences ne changent pas ce bilan.',
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
                        _selectedReadingId = null;
                        _resetDetails();
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
    final confirmed = summaries.fold<int>(0, (sum, row) => sum + row.confirmed);
    final contradicted = summaries.fold<int>(
      0,
      (sum, row) => sum + row.contradicted,
    );
    final unevaluable = summaries.fold<int>(
      0,
      (sum, row) => sum + row.notEvaluable,
    );
    final contextOnly = summaries.fold<int>(
      0,
      (sum, row) => sum + row.contextOnly,
    );
    final pending = summaries.fold<int>(0, (sum, row) => sum + row.pending);
    final pertinentNuances = summaries.fold<int>(
      0,
      (sum, row) => sum + row.cautionConfirmed,
    );
    final unconfirmedNuances = summaries.fold<int>(
      0,
      (sum, row) => sum + row.cautionNotConfirmed,
    );
    final evaluable = confirmed + contradicted;
    final groups = [...summaries]
      ..sort((a, b) => a.readingLabel.compareTo(b.readingLabel));
    return [
      _InfoCard(
        title: '$evaluable résultats vérifiables',
        message: evaluable == 0
            ? 'Le taux sera affiché dès qu’une lecture mesurable aura un résultat.'
            : '${(100 * confirmed / evaluable).round()} % confirmées '
                  '($confirmed sur $evaluable). Ce taux ne mesure pas la rentabilité.',
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _CountPill('Confirmées', confirmed, context.semantic.success),
          _CountPill('Contredites', contradicted, context.semantic.error),
          _CountPill('Non évaluables', unevaluable, context.semantic.warning),
          _CountPill('Constats', contextOnly, context.textColors.secondary),
          _CountPill(
            'Nuances pertinentes',
            pertinentNuances,
            context.semantic.warning,
          ),
          _CountPill(
            'Nuances non confirmées',
            unconfirmedNuances,
            context.textColors.secondary,
          ),
          _CountPill('En attente', pending, context.textColors.secondary),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        'Par lecture',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: context.textColors.primary,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'Touchez une lecture pour voir les matchs et le critère appliqué.',
        style: TextStyle(color: context.textColors.secondary),
      ),
      const SizedBox(height: 12),
      for (final group in groups) ...[
        _ReadingGroupTile(
          summary: group,
          selected: _selectedReadingId == group.readingId,
          onTap: () => _selectReading(group.readingId),
        ),
        const SizedBox(height: 7),
        if (_selectedReadingId == group.readingId) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (value, label) in [
                (null, 'Tous'),
                ('confirmed', 'Confirmées'),
                ('contradicted', 'Contredites'),
                ('context_only', 'Constats'),
                ('not_evaluable', 'Non évaluables'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _selectedVerdict == value,
                  onSelected: (_) => _selectVerdict(value),
                ),
            ],
          ),
          const SizedBox(height: 9),
          for (final entry in _details)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: ReadingVerdictCard(entry: entry),
            ),
          if (_loadingDetails)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          if (_detailsFailed)
            TextButton(
              onPressed: _loadNextPage,
              child: const Text('Réessayer de charger les matchs'),
            ),
          if (!_loadingDetails && !_detailsFailed && _hasMoreDetails)
            TextButton(
              onPressed: _loadNextPage,
              child: const Text('Afficher 20 matchs de plus'),
            ),
          const SizedBox(height: 7),
        ],
      ],
    ];
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

class _ReadingGroupTile extends StatelessWidget {
  const _ReadingGroupTile({
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final MatchReadingBilanSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final confirmed = summary.confirmed;
    final evaluable = summary.evaluable;
    return Material(
      color: context.surfaces.backgroundSecondary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.readingLabel,
                      style: TextStyle(
                        color: context.textColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      evaluable > 0
                          ? '$confirmed confirmées sur $evaluable vérifiables · ${summary.total} annonces'
                          : '${summary.total} annonces · constats ou résultats en attente',
                      style: TextStyle(
                        color: context.textColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.keyboard_arrow_up : Icons.chevron_right,
                color: context.textColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(AppRadius.chip),
    ),
    child: Text(
      '$count $label',
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
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
