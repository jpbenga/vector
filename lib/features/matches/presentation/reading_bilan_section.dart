import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../data/match_reading_bilan_repository.dart';
import '../domain/reading_bilan_analysis.dart';

const _pageSize = 10;

enum _BilanSort { volume, confirmation, name }

class ReadingBilanSection extends StatefulWidget {
  const ReadingBilanSection({this.repository, super.key});
  final MatchReadingBilanRepository? repository;

  @override
  State<ReadingBilanSection> createState() => _ReadingBilanSectionState();
}

class _ReadingBilanSectionState extends State<ReadingBilanSection> {
  late Future<List<MatchReadingBilanSummary>> _breakdown;
  late DateTime _until;
  late DateTime _since;
  int _periodDays = 30;
  int? _leagueId;
  String? _subjectSide;
  String _search = '';
  bool _byLeague = false;
  _BilanSort _sort = _BilanSort.volume;
  int _page = 0;

  MatchReadingBilanRepository get _repository =>
      widget.repository ??
      SupabaseMatchReadingBilanRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _until = DateTime.now();
    _since = _until.subtract(Duration(days: _periodDays));
    _page = 0;
    _breakdown = Future.sync(
      () => _repository.loadBreakdown(
        since: _since,
        until: _until,
        subjectSide: _subjectSide,
      ),
    );
  }

  void _openReading(
    MatchReadingBilanSummary summary,
    List<MatchReadingBilanSummary> rows,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _ReadingResultsSheet(
        repository: _repository,
        summary: summary,
        rows: rows.where((row) => row.readingId == summary.readingId).toList(),
        since: _since,
        until: _until,
        leagueId: _leagueId,
        subjectSide: _subjectSide,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MatchReadingBilanSummary>>(
      future: _breakdown,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <MatchReadingBilanSummary>[];
        final leagues = <int, String>{
          for (final row in rows)
            if (row.leagueId != null)
              row.leagueId!: bilanCompetitionName(
                row.leagueId,
                row.competitionName,
              ),
          ?_leagueId: bilanCompetitionName(
            _leagueId,
            rows
                .where((row) => row.leagueId == _leagueId)
                .firstOrNull
                ?.competitionName,
          ),
        };
        final leagueItems = leagues.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        final scoped = rows
            .where((row) => _leagueId == null || row.leagueId == _leagueId)
            .toList();
        final total = combineBilanSummaries(scoped, id: 'all', label: 'Global');
        final grouped = <String, List<MatchReadingBilanSummary>>{};
        for (final row in scoped) {
          final key = _byLeague ? '${row.leagueId}' : row.readingId;
          grouped.putIfAbsent(key, () => []).add(row);
        }
        final summaries =
            [
                  for (final group in grouped.values)
                    combineBilanSummaries(
                      group,
                      id: _byLeague
                          ? '${group.first.leagueId}'
                          : group.first.readingId,
                      label: _byLeague
                          ? bilanCompetitionName(
                              group.first.leagueId,
                              group.first.competitionName,
                            )
                          : group.first.readingLabel,
                    ),
                ]
                .where(
                  (item) => item.readingLabel.toLowerCase().contains(
                    _search.toLowerCase(),
                  ),
                )
                .toList()
              ..sort((a, b) {
                final comparison = switch (_sort) {
                  _BilanSort.volume => b.evaluable.compareTo(a.evaluable),
                  _BilanSort.confirmation =>
                    (b.confirmationPercent ?? -1).compareTo(
                      a.confirmationPercent ?? -1,
                    ),
                  _BilanSort.name => a.readingLabel.compareTo(b.readingLabel),
                };
                return comparison != 0
                    ? comparison
                    : a.readingLabel.compareTo(b.readingLabel);
              });
        final lastPage = summaries.isEmpty
            ? 0
            : (summaries.length - 1) ~/ _pageSize;
        final page = _page.clamp(0, lastPage);
        final visible = summaries
            .skip(page * _pageSize)
            .take(_pageSize)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Text(
              'Bilan des lectures',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Comparez les lectures annoncées avant match avec les résultats, puis explorez par championnat et par contexte.',
              style: TextStyle(color: context.textColors.secondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final days in [7, 30, 90])
                  ChoiceChip(
                    label: Text('$days jours'),
                    selected: _periodDays == days,
                    onSelected: (_) => setState(() {
                      _periodDays = days;
                      _reload();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _FilterSelect<int>(
              label: 'Championnat',
              value: _leagueId,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Tous les championnats'),
                ),
                for (final league in leagueItems)
                  DropdownMenuItem(
                    value: league.key,
                    child: Text(league.value),
                  ),
              ],
              onChanged: (value) => setState(() {
                _leagueId = value;
                _page = 0;
              }),
            ),
            const SizedBox(height: 10),
            _FilterSelect<String>(
              label: 'Équipe concernée par la lecture',
              value: _subjectSide,
              items: const [
                DropdownMenuItem(
                  value: null,
                  child: Text('Tous les contextes'),
                ),
                DropdownMenuItem(value: 'home', child: Text('À domicile')),
                DropdownMenuItem(value: 'away', child: Text('À l’extérieur')),
                DropdownMenuItem(value: 'match', child: Text('Match entier')),
              ],
              onChanged: (value) => setState(() {
                _subjectSide = value;
                _reload();
              }),
            ),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              _InfoCard(
                title: 'Bilan indisponible',
                message: 'Impossible de charger les résultats pour le moment.',
                action: TextButton(
                  onPressed: () => setState(_reload),
                  child: const Text('Réessayer'),
                ),
              )
            else if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _Overview(summary: total),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Par lecture'),
                    selected: !_byLeague,
                    onSelected: (_) => setState(() {
                      _byLeague = false;
                      _page = 0;
                      _search = '';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Par championnat'),
                    selected: _byLeague,
                    onSelected: (_) => setState(() {
                      _byLeague = true;
                      _page = 0;
                      _search = '';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: ValueKey('bilan-search-$_byLeague'),
                decoration: InputDecoration(
                  hintText: _byLeague
                      ? 'Rechercher un championnat'
                      : 'Rechercher une lecture',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) => setState(() {
                  _search = value;
                  _page = 0;
                }),
              ),
              const SizedBox(height: 10),
              _FilterSelect<_BilanSort>(
                label: 'Trier',
                value: _sort,
                items: const [
                  DropdownMenuItem(
                    value: _BilanSort.volume,
                    child: Text('Nombre d’annonces évaluées'),
                  ),
                  DropdownMenuItem(
                    value: _BilanSort.confirmation,
                    child: Text('Taux de confirmation'),
                  ),
                  DropdownMenuItem(
                    value: _BilanSort.name,
                    child: Text('Ordre alphabétique'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _sort = value ?? _BilanSort.volume;
                  _page = 0;
                }),
              ),
              const SizedBox(height: 12),
              if (summaries.isEmpty)
                const _InfoCard(
                  title: 'Aucune annonce pour cette sélection',
                  message:
                      'Changez la période ou les filtres pour explorer les autres résultats.',
                )
              else ...[
                for (final summary in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SummaryCard(
                      summary: summary,
                      key: ValueKey(
                        'bilan-${_byLeague ? 'league' : 'reading'}-${summary.readingId}',
                      ),
                      onTap: () {
                        if (_byLeague) {
                          final group = grouped[summary.readingId]!;
                          setState(() {
                            _leagueId = group.first.leagueId;
                            _byLeague = false;
                            _page = 0;
                            _search = '';
                          });
                        } else {
                          _openReading(summary, scoped);
                        }
                      },
                    ),
                  ),
                _Pagination(
                  page: page,
                  total: summaries.length,
                  canNext: page < lastPage,
                  onPrevious: page == 0
                      ? null
                      : () => setState(() => _page = page - 1),
                  onNext: () => setState(() => _page = page + 1),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary});
  final MatchReadingBilanSummary summary;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirmation des lectures',
          style: TextStyle(
            color: context.textColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _percent(summary.confirmationPercent),
          style: TextStyle(
            color: context.textColors.primary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '${summary.confirmed} confirmées sur ${summary.evaluable} annonces évaluées',
          style: TextStyle(color: context.textColors.secondary),
        ),
        const SizedBox(height: 12),
        _Counts(summary: summary),
        const SizedBox(height: 10),
        Text(
          'Taux = confirmées ÷ (confirmées + contredites). Les annonces en attente, les données incomplètes et les constats sans règle sont exclus. Un match peut porter plusieurs lectures. Ce taux décrit les résultats passés.',
          style: TextStyle(color: context.textColors.secondary, fontSize: 12),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.onTap, super.key});
  final MatchReadingBilanSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.surfaces.backgroundSecondary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: context.surfaces.border),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.readingLabel,
                    style: TextStyle(
                      color: context.textColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _percent(summary.confirmationPercent),
                  style: TextStyle(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Icon(Icons.chevron_right, color: context.textColors.secondary),
              ],
            ),
            const SizedBox(height: 8),
            _ConfirmationBar(summary: summary),
            const SizedBox(height: 9),
            _Counts(summary: summary),
            if (summary.evaluable > 0 && summary.evaluable < 5) ...[
              const SizedBox(height: 8),
              Text(
                'Échantillon réduit : ${summary.evaluable} annonces évaluées',
                style: TextStyle(color: context.semantic.warning, fontSize: 12),
              ),
            ],
            if (summary.outcomeRules.length == 1) ...[
              const SizedBox(height: 8),
              Text(
                'Critère : ${bilanOutcomeRuleText(summary.outcomeRules.single)}',
                style: TextStyle(
                  color: context.textColors.secondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Counts extends StatelessWidget {
  const _Counts({required this.summary});
  final MatchReadingBilanSummary summary;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 6,
    children: [
      _Count(
        '${summary.confirmed} ${summary.confirmed == 1 ? 'confirmée' : 'confirmées'}',
        context.semantic.success,
      ),
      _Count(
        '${summary.contradicted} ${summary.contradicted == 1 ? 'contredite' : 'contredites'}',
        context.semantic.error,
      ),
      if (summary.pending > 0)
        _Count('${summary.pending} en attente', context.textColors.secondary),
      if (summary.notEvaluable > 0)
        _Count(
          '${summary.notEvaluable} ${summary.notEvaluable == 1 ? 'non évaluable' : 'non évaluables'}',
          context.semantic.warning,
        ),
      if (summary.contextOnly > 0)
        _Count(
          '${summary.contextOnly} sans règle de résultat',
          context.textColors.secondary,
        ),
    ],
  );
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
  );
}

class _ConfirmationBar extends StatelessWidget {
  const _ConfirmationBar({required this.summary});
  final MatchReadingBilanSummary summary;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: summary.evaluable == 0
        ? Container(height: 6, color: context.surfaces.surfaceHover)
        : Row(
            children: [
              if (summary.confirmed > 0)
                Expanded(
                  flex: summary.confirmed,
                  child: Container(height: 6, color: context.semantic.success),
                ),
              if (summary.contradicted > 0)
                Expanded(
                  flex: summary.contradicted,
                  child: Container(height: 6, color: context.semantic.error),
                ),
            ],
          ),
  );
}

class _ReadingResultsSheet extends StatefulWidget {
  const _ReadingResultsSheet({
    required this.repository,
    required this.summary,
    required this.rows,
    required this.since,
    required this.until,
    this.leagueId,
    this.subjectSide,
  });
  final MatchReadingBilanRepository repository;
  final MatchReadingBilanSummary summary;
  final List<MatchReadingBilanSummary> rows;
  final DateTime since;
  final DateTime until;
  final int? leagueId;
  final String? subjectSide;

  @override
  State<_ReadingResultsSheet> createState() => _ReadingResultsSheetState();
}

class _ReadingResultsSheetState extends State<_ReadingResultsSheet> {
  late Future<List<MatchReadingBilanEntry>> _entries;
  int _page = 0;
  String? _verdict;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _entries = Future.sync(
      () => widget.repository.loadForReading(
        readingId: widget.summary.readingId,
        since: widget.since,
        until: widget.until,
        leagueId: widget.leagueId,
        subjectSide: widget.subjectSide,
        verdict: _verdict,
        offset: _page * _pageSize,
        limit: _pageSize + 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .85,
    minChildSize: .5,
    maxChildSize: .95,
    builder: (context, controller) => Material(
      color: context.surfaces.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.summary.readingLabel,
                  style: TextStyle(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'LECTURE · RÉSULTATS',
            style: TextStyle(
              color: context.brand.accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _Overview(summary: widget.summary),
          const SizedBox(height: 14),
          _Panel(
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
                const SizedBox(height: 8),
                if (widget.summary.outcomeRules.isEmpty)
                  Text(
                    bilanOutcomeRuleText(null),
                    style: TextStyle(color: context.textColors.secondary),
                  )
                else
                  for (final rule in widget.summary.outcomeRules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Confirmée si : ${bilanOutcomeRuleText(rule)}',
                        style: TextStyle(color: context.textColors.secondary),
                      ),
                    ),
                if (widget.summary.contextOnly > 0)
                  Text(
                    'Les annonces sans règle sont présentées séparément et n’entrent pas dans le taux.',
                    style: TextStyle(
                      color: context.textColors.secondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text(
                'Comparer par championnat (${widget.rows.length})',
                style: TextStyle(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              iconColor: context.textColors.secondary,
              collapsedIconColor: context.textColors.secondary,
              tilePadding: EdgeInsets.zero,
              children: [
                for (final row in [
                  ...widget.rows,
                ]..sort((a, b) => b.evaluable.compareTo(a.evaluable)))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bilanCompetitionName(
                              row.leagueId,
                              row.competitionName,
                            ),
                            style: TextStyle(
                              color: context.textColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_percent(row.confirmationPercent)} · ${row.confirmed}/${row.evaluable} annonces confirmées',
                            style: TextStyle(
                              color: context.textColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _ConfirmationBar(summary: row),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Matchs associés',
            style: TextStyle(
              color: context.textColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Une ligne par lecture annoncée. Le verdict suit le critère figé avant le coup d’envoi.',
            style: TextStyle(color: context.textColors.secondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _FilterSelect<String>(
            label: 'Résultat de la lecture',
            value: _verdict,
            items: const [
              DropdownMenuItem(value: null, child: Text('Toutes les annonces')),
              DropdownMenuItem(value: 'confirmed', child: Text('Confirmées')),
              DropdownMenuItem(
                value: 'contradicted',
                child: Text('Contredites'),
              ),
              DropdownMenuItem(value: 'pending', child: Text('En attente')),
              DropdownMenuItem(
                value: 'not_evaluable',
                child: Text('Non évaluables'),
              ),
              DropdownMenuItem(
                value: 'context_only',
                child: Text('Sans règle de résultat'),
              ),
            ],
            onChanged: (value) => setState(() {
              _verdict = value;
              _page = 0;
              _reload();
            }),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<MatchReadingBilanEntry>>(
            future: _entries,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InfoCard(
                  title: 'Matchs indisponibles',
                  message: 'Impossible de charger cette page de résultats.',
                  action: TextButton(
                    onPressed: () => setState(_reload),
                    child: const Text('Réessayer'),
                  ),
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final entries = snapshot.data ?? [];
              final visible = entries.take(_pageSize).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (visible.isEmpty)
                    Text(
                      'Aucune annonce pour ce filtre.',
                      style: TextStyle(color: context.textColors.secondary),
                    ),
                  for (final entry in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ReadingVerdictCard(entry: entry),
                    ),
                  _Pagination(
                    page: _page,
                    canNext: entries.length > _pageSize,
                    onPrevious: _page == 0
                        ? null
                        : () => setState(() {
                            _page--;
                            _reload();
                          }),
                    onNext: () => setState(() {
                      _page++;
                      _reload();
                    }),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
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
      'context_only' => (
        'Sans règle de résultat',
        context.textColors.secondary,
      ),
      'caution_confirmed' => ('Nuance pertinente', context.semantic.warning),
      'caution_not_confirmed' => (
        'Nuance non confirmée',
        context.textColors.secondary,
      ),
      _ => ('En attente', context.textColors.secondary),
    };
    final teams =
        '${_teamName(entry.homeTeamName, 'Équipe à domicile')} – ${_teamName(entry.awayTeamName, 'Équipe à l’extérieur')}';
    final subject = switch (entry.subjectSide) {
      'home' =>
        '${_teamName(entry.homeTeamName, 'Équipe à domicile')} · domicile',
      'away' =>
        '${_teamName(entry.awayTeamName, 'Équipe à l’extérieur')} · extérieur',
      _ => 'Match entier',
    };
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bilanCompetitionName(entry.leagueId, entry.competitionName),
            style: TextStyle(color: context.textColors.secondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  teams,
                  style: TextStyle(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (entry.hasResult)
                Text(
                  '${entry.homeGoals} – ${entry.awayGoals}',
                  style: TextStyle(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat('dd/MM/yyyy · HH:mm').format(entry.kickoffAt.toLocal()),
            style: TextStyle(color: context.textColors.secondary, fontSize: 12),
          ),
          if (!entry.hasResult) ...[
            const SizedBox(height: 5),
            Text(
              'Score final non disponible',
              style: TextStyle(
                color: context.textColors.secondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            entry.readingLabel,
            style: TextStyle(
              color: context.textColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Concerne : $subject',
            style: TextStyle(color: context.textColors.secondary, fontSize: 12),
          ),
          const SizedBox(height: 7),
          Text(
            verdict.$1,
            style: TextStyle(color: verdict.$2, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Critère : ${bilanOutcomeRuleText(entry.outcomeRule)}',
            style: TextStyle(color: context.textColors.secondary, fontSize: 12),
          ),
          if (entry.explanation?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              entry.explanation!,
              style: TextStyle(
                color: context.textColors.secondary,
                fontSize: 12,
              ),
            ),
          ],
          if (entry.evidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Avant match : ${entry.evidence.first['label'] ?? entry.readingLabel}',
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

class _FilterSelect<T> extends StatelessWidget {
  const _FilterSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        isExpanded: true,
        value: value,
        items: items,
        onChanged: onChanged,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.textColors.primary),
      ),
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
    this.total,
  });
  final int page;
  final int? total;
  final bool canNext;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          total == null
              ? 'Page ${page + 1}'
              : '${page * _pageSize + 1}–${((page + 1) * _pageSize).clamp(0, total!)} sur $total',
          style: TextStyle(color: context.textColors.secondary),
        ),
      ),
      IconButton(
        tooltip: 'Page précédente',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Page suivante',
        onPressed: canNext ? onNext : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.surfaces.backgroundSecondary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.surfaces.border),
    ),
    child: child,
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.message, this.action});
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _Panel(
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

String _percent(double? rate) => rate == null ? '—' : '${rate.round()} %';
String _teamName(String? name, String fallback) =>
    name == null || name.trim().isEmpty ? fallback : name;
