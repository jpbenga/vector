import 'package:flutter/material.dart';

import '../../../core/sports/domain/sport_module.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_brand_mark.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import '../domain/hockey_module.dart';
import 'package:intl/intl.dart';
import '../../../core/sports/domain/sport_feed_repository.dart';
import '../../../core/sports/domain/sport_fixture.dart';
import '../../../core/sports/presentation/sport_fixture_card.dart';

/// A browsable preparation workspace, with no fabricated production fixtures.
class HockeyWorkspace extends StatefulWidget {
  const HockeyWorkspace({this.repository, this.initialDate, super.key});
  final SportFeedRepository? repository;
  final DateTime? initialDate;

  @override
  State<HockeyWorkspace> createState() => _HockeyWorkspaceState();
}

class _HockeyWorkspaceState extends State<HockeyWorkspace> {
  int _section = 0;
  late DateTime _date;
  SportFeedResult? _feed;
  bool _loading = false;
  bool _failed = false;
  int _request = 0;
  final _calendar = ScrollController(initialScrollOffset: 7 * 120);

  @override
  void dispose() {
    _calendar.dispose();
    super.dispose();
  }

  void _selectDate(DateTime date) {
    setState(() => _date = date);
    _load();
    if (_calendar.hasClients) {
      final now = widget.initialDate ?? DateTime.now();
      final offset =
          (DateTime.utc(
                date.year,
                date.month,
                date.day,
              ).difference(DateTime.utc(now.year, now.month, now.day)).inDays +
              7) *
          120.0;
      _calendar.animateTo(
        offset.clamp(0, _calendar.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    final generation = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result =
          await widget.repository?.load(_date) ??
          const SportFeedResult.unavailable(
            SportFeedUnavailableReason.notConnected,
          );
      if (!mounted || generation != _request) return;
      setState(() {
        _feed = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _request) return;
      setState(() {
        _feed = null;
        _failed = true;
        _loading = false;
      });
    }
  }

  Widget _matches(BuildContext context) {
    final publication = _feed?.snapshot;
    final matches =
        publication?.items.where((f) {
          final day = f.calendarDate ?? f.startsAt?.toLocal();
          return day != null &&
              day.year == _date.year &&
              day.month == _date.month &&
              day.day == _date.day;
        }).toList() ??
        <SportFixture>[];
    final today = widget.initialDate ?? DateTime.now();
    final days = List.generate(
      21,
      (index) => DateTime(today.year, today.month, today.day - 7 + index),
    );
    final reason = _feed?.unavailableReason;
    final message = _failed
        ? 'La source NHL est momentanément indisponible. Vous pouvez continuer à naviguer.'
        : switch (reason) {
            SportFeedUnavailableReason.stale =>
              'La collecte NHL doit être actualisée.',
            SportFeedUnavailableReason.outsideWindow =>
              'Cette date est hors de la fenêtre collectée.',
            SportFeedUnavailableReason.notPublished =>
              'La publication NHL est en préparation.',
            _ => 'Aucune rencontre hockey chargée',
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'NHL · Calendrier',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              key: const ValueKey('hockey-refresh'),
              tooltip: 'Relire la publication',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          controller: _calendar,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final day in days)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 112,
                    child: ChoiceChip(
                      showCheckmark: false,
                      key: ValueKey(
                        'hockey-day-${DateFormat('yyyy-MM-dd').format(day)}',
                      ),
                      label: Text(DateFormat('EEE dd/MM', 'fr').format(day)),
                      selected: day == _date,
                      onSelected: (_) => _selectDate(day),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              tooltip: 'Jour précédent',
              onPressed: _date.isAfter(days.first)
                  ? () => _selectDate(
                      DateTime(_date.year, _date.month, _date.day - 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                DateFormat('EEEE d MMMM yyyy', 'fr').format(_date),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Jour suivant',
              onPressed: _date.isBefore(days.last)
                  ? () => _selectDate(
                      DateTime(_date.year, _date.month, _date.day + 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading) const LinearProgressIndicator(),
        if (!_loading && publication == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(message),
            ),
          ),
        if (!_loading && publication != null) ...[
          Text(
            'Collecté le ${DateFormat('dd/MM à HH:mm').format(publication.capturedAt.toLocal())} · ${matches.length} rencontre(s)',
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucune rencontre NHL programmée pour ce jour.'),
              ),
            ),
          for (final fixture in matches)
            SportFixtureCard(
              fixture: fixture,
              order: HockeyModule.definition.participantOrder,
              statusLabel: switch (fixture.providerStatus) {
                'AOT' => 'Terminé · Prolongation',
                'AP' || 'APEN' => 'Terminé · Tirs au but',
                _ => null,
              },
              scoreLabels: const {
                'first': '1re période',
                'second': '2e période',
                'third': '3e période',
                'regulation': 'À 60 minutes',
                'overtime': 'Prolongation',
                'penalties': 'Tirs au but',
                'final': 'Score final',
                'current': 'Score en cours',
              },
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const module = HockeyModule.definition;
    return ListView(
      key: const ValueKey('hockey-workspace'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        LectorContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LectorBrandMark(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lector · ${module.sport.label}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Les mêmes principes d’analyse, adaptés au hockey.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: context.brand.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Première collecte NHL',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Calendrier et scores du fournisseur. Les lectures et '
                              'les scénarios hockey seront validés ensuite.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (index, label) in [
                      'Matchs',
                      'Lectures',
                      'Scénarios',
                    ].indexed)
                      ChoiceChip(
                        key: ValueKey('hockey-section-$index'),
                        label: Text(label),
                        selected: _section == index,
                        onSelected: (_) => setState(() => _section = index),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_section == 0) _matches(context),
                if (_section != 0) ...[
                  Text(
                    'Premières règles à valider',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ces exemples expliquent les règles proposées. '
                    'Ils ne décrivent pas des matchs réels.',
                  ),
                  const SizedBox(height: 12),
                ],
                if (_section == 1)
                  for (final reading in module.readings)
                    _readingCard(context, reading),
                if (_section == 2)
                  for (final scenario in module.scenarios)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scenario.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(scenario.description),
                            const SizedBox(height: 12),
                            for (final id in scenario.requiredReadingIds)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '• ${module.readings.firstWhere((r) => r.id == id).label}',
                                ),
                              ),
                            const Text('Toutes requises pour la même équipe.'),
                          ],
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _readingCard(BuildContext context, SportReadingDefinition reading) =>
      Card(
        child: ExpansionTile(
          key: ValueKey('hockey-reading-${reading.id}'),
          title: Text(reading.label),
          subtitle: Text(
            reading.implemented
                ? 'Règle initiale à valider'
                : 'À étudier avec les données',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reading.description),
            const SizedBox(height: 12),
            Text('Conditions', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(reading.condition),
            const SizedBox(height: 12),
            Text(
              'Exemple illustratif',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(reading.example),
          ],
        ),
      );
}
