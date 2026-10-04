import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/sports_asset_badge.dart';
import '../domain/sport_fixture.dart';
import '../domain/sport_policy.dart';

/// Shared factual card. Sport modules supply participant order and score scopes;
/// no football markets, readings or provider payloads are embedded here.
class SportFixtureCard extends StatelessWidget {
  const SportFixtureCard({
    required this.fixture,
    required this.order,
    this.statusLabel,
    this.scoreLabels = const {},
    super.key,
  });
  final SportFixture fixture;
  final SportParticipantOrder order;
  final String? statusLabel;
  final Map<String, String> scoreLabels;

  @override
  Widget build(BuildContext context) {
    final (left, right) = fixture.displayedParticipants(order);
    final score =
        fixture.scoreFor(SportScoreScope.finalResult) ??
        fixture.scoreFor(const SportScoreScope('current'));
    final homeFirst = order == SportParticipantOrder.homeAway;
    final status = switch (fixture.status) {
      SportFixtureStatus.scheduled => 'À venir',
      SportFixtureStatus.live => 'En cours',
      SportFixtureStatus.finished => 'Terminé',
      SportFixtureStatus.postponed => 'Reporté',
      SportFixtureStatus.cancelled => 'Annulé',
      SportFixtureStatus.unknown => 'Statut à confirmer',
    };
    return Card(
      key: ValueKey('sport-fixture-${fixture.id.key}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _details(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${fixture.competitionName} · ${statusLabel ?? status}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (fixture.startsAt != null)
                    Text(
                      DateFormat('HH:mm').format(fixture.startsAt!.toLocal()),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _team(
                      context,
                      left,
                      homeFirst ? 'Domicile' : 'Extérieur',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      score == null
                          ? 'VS'
                          : '${homeFirst ? score.home : score.away} – ${homeFirst ? score.away : score.home}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Expanded(
                    child: _team(
                      context,
                      right,
                      homeFirst ? 'Extérieur' : 'Domicile',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Détail du match',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _team(BuildContext context, SportParticipant team, String role) =>
      Column(
        children: [
          SportsAssetBadge(
            size: 48,
            imageUrl: team.logoUrl,
            fallbackLabel: team.name,
            contrastPlate: true,
          ),
          const SizedBox(height: 8),
          Text(
            team.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(role, style: Theme.of(context).textTheme.labelSmall),
        ],
      );

  void _details(BuildContext context) {
    final homeFirst = order == SportParticipantOrder.homeAway;
    final (left, right) = fixture.displayedParticipants(order);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${left.name} — ${right.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('${fixture.competitionName} · Saison ${fixture.season}'),
              if (fixture.startsAt != null)
                Text(
                  DateFormat(
                    'dd/MM/yyyy · HH:mm',
                  ).format(fixture.startsAt!.toLocal()),
                ),
              const SizedBox(height: 16),
              for (final MapEntry(key: scope, value: label)
                  in scoreLabels.entries)
                if (fixture.scoreFor(SportScoreScope(scope)) case final score?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(label)),
                        Text(
                          '${homeFirst ? score.home : score.away} – ${homeFirst ? score.away : score.home}',
                        ),
                      ],
                    ),
                  ),
              if (fixture.scores.isEmpty)
                const Text('Les scores ne sont pas encore disponibles.'),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
