import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_components.dart';
import '../../../../core/widgets/lector_match_section_card.dart';
import '../../../../core/widgets/sports_asset_badge.dart';
import '../../data/match_reading_bilan_repository.dart';
import '../../domain/match_board_item.dart';
import '../../domain/reading_bilan_analysis.dart';
import 'reading_verdict_details.dart';

Future<void> showMatchReadingBilan(
  BuildContext context, {
  required List<MatchReadingBilanEntry> entries,
  MatchBoardItem? match,
  VoidCallback? onOpenMatch,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: context.surfaces.backgroundSecondary,
  constraints: const BoxConstraints(maxWidth: 720),
  shape: RoundedRectangleBorder(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    side: BorderSide(color: context.surfaces.border),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .92,
      child: MatchReadingBilanSheet(
        entries: entries,
        match: match,
        onClose: () => Navigator.pop(context),
        onOpenMatch: onOpenMatch == null
            ? null
            : () {
                Navigator.pop(context);
                onOpenMatch();
              },
      ),
    ),
  ),
);

class MatchReadingBilanSheet extends StatelessWidget {
  const MatchReadingBilanSheet({
    required this.entries,
    required this.onClose,
    this.match,
    this.onOpenMatch,
    super.key,
  });
  final List<MatchReadingBilanEntry> entries;
  final MatchBoardItem? match;
  final VoidCallback onClose;
  final VoidCallback? onOpenMatch;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final first = entries.first;
    final groups = <String, List<MatchReadingBilanEntry>>{};
    for (final entry in entries) {
      (groups[entry.verdict ?? 'pending'] ??= []).add(entry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('match-reading-bilan-scroll'),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            children: [
              Row(
                children: [
                  SportsAssetBadge(
                    imageUrl:
                        match?.fixture.competition.country.flagUrl ??
                        match?.fixture.competition.logoUrl,
                    fallbackLabel: bilanCompetitionName(
                      first.leagueId,
                      first.competitionName,
                    ),
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bilanCompetitionName(
                            first.leagueId,
                            first.competitionName,
                          ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy · HH:mm',
                          ).format(first.kickoffAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.textColors.secondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _Team(
                      name: first.homeTeamName ?? 'Équipe à domicile',
                      logo: match?.homeTeam.logoUrl,
                      place: 'Domicile',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Text(
                          'TERMINÉ',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.textColors.secondary),
                        ),
                        Text(
                          first.hasResult
                              ? '${first.homeGoals} – ${first.awayGoals}'
                              : '–',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _Team(
                      name: first.awayTeamName ?? 'Équipe à l’extérieur',
                      logo: match?.awayTeam.logoUrl,
                      place: 'Extérieur',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LectorMatchSectionCard(
                title: 'Bilan des lectures annoncées',
                icon: Icons.menu_book_rounded,
                subtitle: 'Lectures figées avant le coup d’envoi.',
                child: Text(
                  'Chaque résultat ci-dessous concerne l’équipe ou le match indiqué dans la lecture.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                  ),
                ),
              ),
              for (final group in groups.entries) ...[
                const SizedBox(height: 12),
                LectorMatchSectionCard(
                  title: '${_groupTitle(group.key)} · ${group.value.length}',
                  icon: group.key == 'confirmed'
                      ? Icons.check_circle_outline_rounded
                      : group.key == 'contradicted'
                      ? Icons.cancel_outlined
                      : Icons.info_outline_rounded,
                  child: Column(
                    children: [
                      for (final indexed in group.value.indexed) ...[
                        if (indexed.$1 > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Divider(
                              height: 1,
                              color: context.surfaces.border,
                            ),
                          ),
                        ReadingVerdictDetails(entry: indexed.$2),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: context.surfaces.backgroundSecondary,
            border: Border(top: BorderSide(color: context.surfaces.border)),
          ),
          child: FilledButton.icon(
            onPressed: onOpenMatch ?? onClose,
            icon: const Icon(Icons.bar_chart_rounded),
            label: Text(
              onOpenMatch == null
                  ? 'Revenir au match'
                  : 'Voir les données du match',
            ),
          ),
        ),
      ],
    );
  }
}

String _groupTitle(String verdict) => switch (verdict) {
  'confirmed' => 'Lectures confirmées',
  'contradicted' => 'Lectures contredites',
  'not_evaluable' => 'Lectures non évaluables',
  'context_only' => 'Constats sans règle de résultat',
  'caution_confirmed' || 'caution_not_confirmed' => 'Nuances',
  _ => 'Lectures en attente',
};

class _Team extends StatelessWidget {
  const _Team({required this.name, required this.place, this.logo});
  final String name, place;
  final String? logo;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SportsAssetBadge(imageUrl: logo, fallbackLabel: name, size: 44),
      const SizedBox(height: 6),
      Text(
        name,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      Text(
        place,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.textColors.secondary),
      ),
    ],
  );
}
