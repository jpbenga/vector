import '../../widgets/lector_live_badge.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_components.dart';
import '../../widgets/lector_match_card.dart';
import '../domain/sport_fixture.dart';
import '../domain/sport_policy.dart';

/// Adapter for published sport facts. The complete card and its navigation
/// action are the same widgets as football; this class owns no detail view.
class SportFixtureCard extends StatelessWidget {
  const SportFixtureCard({
    required this.fixture,
    required this.order,
    required this.onTap,
    this.statusLabel,
    this.contextPanel,
    this.insights,
    this.readingCount,
    super.key,
  });
  final SportFixture fixture;
  final SportParticipantOrder order;
  final VoidCallback onTap;
  final String? statusLabel;
  final Widget? contextPanel;
  final Widget? insights;
  final int? readingCount;
  @override
  Widget build(BuildContext context) {
    final (first, second) = fixture.displayedParticipants(order);
    final score =
        fixture.scoreFor(SportScoreScope.finalResult) ??
        fixture.scoreFor(const SportScoreScope('current'));
    final homeFirst = order == SportParticipantOrder.homeAway;
    final status =
        statusLabel ??
        switch (fixture.status) {
          SportFixtureStatus.scheduled => 'À venir',
          SportFixtureStatus.live => 'En direct',
          SportFixtureStatus.finished => 'Terminé',
          SportFixtureStatus.postponed => 'Reporté',
          SportFixtureStatus.cancelled => 'Annulé',
          SportFixtureStatus.unknown => 'Statut à confirmer',
        };
    Widget team(SportParticipant p, int? points, String role) => LectorTeamLine(
      name: p.name,
      logoUrl: p.logoUrl,
      score: points,
      role: role,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LectorMatchCard(
        key: ValueKey('sport-fixture-${fixture.id.key}'),
        onTap: onTap,
        temporal: fixture.temporal,
        actionLabel: fixture.temporal.isLive
            ? 'Suivre le match'
            : 'Voir l’analyse',
        header: fixture.temporal.isLive
            ? Align(
                alignment: Alignment.centerLeft,
                child: LectorLiveBadge(state: fixture.temporal),
              )
            : LectorMatchTimeHeader(
                timeLabel: fixture.startsAt == null
                    ? 'Horaire à confirmer'
                    : DateFormat('HH:mm').format(fixture.startsAt!.toLocal()),
                trailing: Text(
                  readingCount == null
                      ? status
                      : '$readingCount lecture${readingCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fixture.status == SportFixtureStatus.live
                        ? context.semantic.error
                        : context.textColors.secondary,
                  ),
                ),
              ),
        teams: LectorMatchTeams(
          first: team(
            first,
            homeFirst ? score?.home : score?.away,
            homeFirst ? 'Domicile' : 'Extérieur',
          ),
          second: team(
            second,
            homeFirst ? score?.away : score?.home,
            homeFirst ? 'Extérieur' : 'Domicile',
          ),
        ),
        contextPanel: contextPanel,
        insights: insights,
      ),
    );
  }
}
