import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/lector_brand_mark.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../../../core/widgets/sports_asset_badge.dart';
import '../domain/generator_context.dart';
import 'generator_formatters.dart';
import 'generator_selection_sheet.dart';
export 'generator_formatters.dart';
export 'generator_selection_sheet.dart' show GeneratorSelectionEvidence;

class GeneratorAvatar extends StatelessWidget {
  const GeneratorAvatar({this.size = 36, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * .18),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: context.surfaces.backgroundSecondary,
      border: Border.all(color: context.surfaces.border),
    ),
    child: LectorBrandMark(size: size * .64),
  );
}

class GeneratorMessageBubble extends StatelessWidget {
  const GeneratorMessageBubble({
    required this.text,
    this.user = false,
    this.at,
    super.key,
  });
  final String text;
  final bool user;
  final String? at;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!user) ...[const GeneratorAvatar(), const SizedBox(width: 8)],
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: user
                  ? context.brand.accent.withValues(alpha: .10)
                  : context.surfaces.surface,
              border: Border.all(
                color: user
                    ? context.brand.accent.withValues(alpha: .32)
                    : context.surfaces.border,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
                if (at != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      DateTime.tryParse(at!) == null
                          ? ''
                          : DateFormat(
                              'HH:mm',
                              'fr',
                            ).format(DateTime.parse(at!).toLocal()),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (user) const SizedBox(width: 2),
      ],
    ),
  );
}

class LectorTicketSummary extends StatelessWidget {
  const LectorTicketSummary({required this.ticket, super.key});
  final Map<String, dynamic> ticket;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      border: Border.all(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(AppRadius.input),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in [
          ('Mise', generatorMoney(ticket['stake'])),
          ('Cote totale', generatorOdds(ticket['totalOdds'])),
          ('Retour potentiel', generatorMoney(ticket['returnTotal'])),
        ].indexed) ...[
          if (item.$1 > 0)
            Container(
              width: 1,
              height: 42,
              color: context.surfaces.border,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$2.$1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.textColors.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.$2.$2,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: item.$1 == 2 ? context.brand.accent : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class LectorTicketCard extends StatelessWidget {
  const LectorTicketCard({
    required this.ticket,
    required this.onDetail,
    required this.onSelection,
    required this.onModify,
    required this.onAlternative,
    this.pending = false,
    this.enabled = true,
    super.key,
  });
  final Map<String, dynamic> ticket;
  final VoidCallback onDetail, onModify, onAlternative;
  final ValueChanged<int> onSelection;
  final bool pending, enabled;
  @override
  Widget build(BuildContext context) {
    final picks = generatorRows(ticket['picks']);
    final needsUpdate = picks.any((p) {
      final kickoff = DateTime.tryParse(p['kickoff']?.toString() ?? '');
      final odds = DateTime.tryParse(p['oddsAt']?.toString() ?? '');
      return kickoff == null ||
          !kickoff.isAfter(DateTime.now()) ||
          odds == null ||
          DateTime.now().difference(odds) > const Duration(hours: 48);
    });
    final sports = picks
        .map((p) => p['sport'] == 'hockey' ? 'Hockey' : 'Football')
        .toSet()
        .join(' + ');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.brand.accent.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GeneratorAvatar(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'TICKET ${ticket['number']}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (needsUpdate
                                        ? context.semantic.warning
                                        : Theme.of(
                                            context,
                                          ).colorScheme.secondary)
                                    .withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            needsUpdate
                                ? 'À actualiser'
                                : pending
                                ? 'Modification'
                                : 'Brouillon',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${picks.length} sélection${picks.length == 1 ? '' : 's'} · $sports',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LectorTicketSummary(ticket: ticket),
          const SizedBox(height: 4),
          for (final entry in picks.indexed) ...[
            if (entry.$1 > 0) const Divider(height: 1),
            LectorTicketSelectionRow(
              pick: entry.$2,
              onTap: () => onSelection(entry.$1),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDetail,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Voir le détail du ticket'),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final actionStyle = OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: Theme.of(context).textTheme.labelMedium,
              );
              final buttons = [
                OutlinedButton.icon(
                  style: actionStyle,
                  onPressed: enabled ? onModify : null,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'Modifier ce ticket',
                    textAlign: TextAlign.center,
                  ),
                ),
                OutlinedButton.icon(
                  style: actionStyle,
                  onPressed: enabled ? onAlternative : null,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Proposer un autre ticket',
                    textAlign: TextAlign.center,
                  ),
                ),
              ];
              return constraints.maxWidth >= 320
                  ? Row(
                      children: [
                        Expanded(child: buttons[0]),
                        const SizedBox(width: 8),
                        Expanded(child: buttons[1]),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buttons[0],
                        const SizedBox(height: 6),
                        buttons[1],
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class LectorTicketSelectionRow extends StatelessWidget {
  const LectorTicketSelectionRow({
    required this.pick,
    required this.onTap,
    super.key,
  });
  final Map<String, dynamic> pick;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final readings = generatorEvidence(pick, 'reading');
    final radar = generatorEvidence(pick, 'radar');
    final players = radar.where((e) => e['family'] == 'player').toList();
    final teamRadar = radar.where((e) => e['family'] != 'player').length;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Asset(
                  url: (pick['countryFlag']?.toString().isNotEmpty ?? false)
                      ? pick['countryFlag']?.toString()
                      : pick['competitionLogo']?.toString(),
                  size: 23,
                  icon: Icons.emoji_events_outlined,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${pick['competition']} · ${generatorKickoff(pick)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.textColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaces.surfaceHover,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    generatorOdds(pick['odds']),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final teams = Column(
                  children: [
                    LectorTeamLine(
                      name: pick['home']?.toString() ?? '',
                      logoUrl: pick['homeLogo']?.toString(),
                    ),
                    const SizedBox(height: 6),
                    LectorTeamLine(
                      name: pick['away']?.toString() ?? '',
                      logoUrl: pick['awayLogo']?.toString(),
                    ),
                  ],
                );
                final market = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pick['market']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pick['selection']?.toString() ?? '',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
                return constraints.maxWidth < 330
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          teams,
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: market),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: context.brand.accent,
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(flex: 3, child: teams),
                          Container(
                            width: 1,
                            height: 46,
                            color: context.surfaces.border,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          Expanded(flex: 2, child: market),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: context.brand.accent,
                          ),
                        ],
                      );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (readings.isNotEmpty)
                  _EvidenceChip(
                    label:
                        '${readings.length} lecture${readings.length == 1 ? '' : 's'}',
                    icon: Icons.menu_book_outlined,
                  ),
                if (teamRadar > 0)
                  _EvidenceChip(
                    label:
                        '$teamRadar signal${teamRadar == 1 ? '' : 's'} Radar',
                    icon: Icons.bar_chart_rounded,
                  ),
                if (players.isNotEmpty)
                  _EvidenceChip(
                    label:
                        '${players.length} joueur${players.length == 1 ? '' : 's'} Radar',
                    photo: players.first['photo']?.toString(),
                    icon: Icons.person_outline_rounded,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  const _EvidenceChip({required this.label, required this.icon, this.photo});
  final String label;
  final IconData icon;
  final String? photo;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (photo?.isNotEmpty ?? false)
          ClipOval(
            child: _Asset(url: photo, size: 20, icon: icon),
          )
        else
          Icon(icon, size: 16, color: context.brand.accent),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _Asset extends StatelessWidget {
  const _Asset({this.url, required this.size, required this.icon});
  final String? url;
  final double size;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SportsAssetBadge(
    size: size,
    imageUrl: url?.startsWith('https://') == true ? url : null,
    fallbackLabel: '',
    icon: icon,
    borderRadius: AppRadius.tight,
  );
}

Future<void> showGeneratorTicketDetail(
  BuildContext context,
  Map<String, dynamic> ticket, {
  int? selection,
  bool inTicket = true,
  required ValueChanged<Map<String, dynamic>> onOpenMatch,
  required ValueChanged<int> onReplace,
}) {
  final picks = generatorRows(ticket['picks']);
  if (selection != null && selection >= 0 && selection < picks.length) {
    return showGeneratorSelectionDetail(
      context,
      pick: picks[selection],
      inTicket: inTicket,
      onOpenMatch: () => onOpenMatch(picks[selection]),
      onReplace: () => onReplace(selection),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .86,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Row(
              children: [
                const GeneratorAvatar(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ticket ${ticket['number']} · détail',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer le détail',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LectorTicketSummary(ticket: ticket),
            const SizedBox(height: 8),
            Text(
              'Bénéfice net si toutes les sélections gagnent : ${generatorMoney(ticket['netProfit'])}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final entry in generatorRows(ticket['picks']).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LectorMatchCardFrame(
                  child: ExpansionTile(
                    key: ValueKey('${ticket['id']}-detail-${entry.$1}'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    initiallyExpanded:
                        selection == entry.$1 ||
                        (selection == null && entry.$1 == 0),
                    title: Text(
                      '${entry.$2['home']} — ${entry.$2['away']}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      '${entry.$2['selection']} · ${generatorOdds(entry.$2['odds'])}',
                    ),
                    children: [
                      GeneratorSelectionEvidence(pick: entry.$2),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              onOpenMatch(entry.$2);
                            },
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                            ),
                            label: const Text('Voir les données du match'),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              onReplace(entry.$1);
                            },
                            icon: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                            ),
                            label: const Text('Remplacer cette sélection'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Brouillon de composition. Le retour potentiel inclut la mise, sans garantie. Aucun pari n’est placé.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
