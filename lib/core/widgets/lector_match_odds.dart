import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import 'lector_match_section_card.dart';

/// Factual quotes. Sport adapters supply the market and participant labels.
class LectorOddsMarket {
  const LectorOddsMarket({
    required this.label,
    required this.selections,
    this.bookmaker,
    this.recordedAt,
  });
  final String label;
  final List<({String label, double odds})> selections;
  final String? bookmaker;
  final DateTime? recordedAt;
}

class LectorMatchOdds extends StatelessWidget {
  const LectorMatchOdds({
    required this.markets,
    this.finished = false,
    super.key,
  });
  final List<LectorOddsMarket> markets;
  final bool finished;

  @override
  Widget build(BuildContext context) => LectorMatchSectionCard(
    title: finished ? 'Cotes avant-match' : 'Cotes disponibles',
    icon: Icons.stacked_line_chart_rounded,
    subtitle: finished
        ? 'Archive des cotes collectées avant le coup d’envoi.'
        : null,
    child: markets.isEmpty
        ? Text(
            finished
                ? 'Aucune cote d’avant-match archivée pour cette rencontre.'
                : 'Les cotes ne sont pas encore disponibles pour cette rencontre.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Market(market: markets.first),
              if (markets.length > 1) ...[
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    'Voir les autres marchés (${markets.length - 1})',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.brand.accent,
                    ),
                  ),
                  children: [
                    for (final market in markets.skip(1))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _Market(market: market),
                      ),
                  ],
                ),
              ],
            ],
          ),
  );
}

class _Market extends StatelessWidget {
  const _Market({required this.market});
  final LectorOddsMarket market;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        market.label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        [
          if (market.bookmaker?.isNotEmpty == true) market.bookmaker!,
          if (market.recordedAt != null)
            'Relevées le ${DateFormat('dd/MM · HH:mm').format(market.recordedAt!.toLocal())}',
          if (market.recordedAt == null) 'Date de relevé non renseignée',
        ].join(' · '),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.textColors.secondary),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = market.selections.length.clamp(1, 3);
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final selection in market.selections)
                SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaces.surfaceHover.withValues(
                        alpha: .42,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: context.surfaces.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          selection.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          selection.odds
                              .toStringAsFixed(2)
                              .replaceAll('.', ','),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: context.brand.accent,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
