import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_components.dart';
import '../../../../core/theme/competition_card_theme.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/sports_asset_badge.dart';
import '../../domain/match_board_item.dart';
import 'match_feed_card.dart';

/// Presentation of existing readings; no new ranking or predictive metric.
class EuropeanEveningBriefing extends StatelessWidget {
  const EuropeanEveningBriefing({
    required this.matches,
    required this.date,
    required this.showReadings,
    required this.onOpenMatch,
    super.key,
  });
  final List<MatchBoardItem> matches;
  final DateTime date;
  final bool showReadings;
  final ValueChanged<MatchBoardItem> onOpenMatch;
  List<MatchBoardItem> get champions =>
      matches.where((m) => m.competition.apiFootballLeagueId == 2).toList();
  @override
  Widget build(BuildContext context) {
    final items = champions;
    if (items.isEmpty) return const SizedBox.shrink();
    final palette = CompetitionCardTheme(
      context,
      CompetitionCardIdentity.champions,
    );
    final readingIds = {
      for (final m in items)
        m.id: publishedMatchCardReadings(m).map((r) => r.id).toSet(),
    };
    int count(Set<String> ids) =>
        readingIds.values.where((v) => v.intersection(ids).isNotEmpty).length;
    final stats = [
      (
        label: 'Dynamique',
        value: count({
          'positive_streak',
          'winning_streak',
          'improving_form',
          'form_advantage',
          'recent_form_advantage',
          'strong_recent_form',
        }),
        color: context.brand.accent,
        icon: Icons.show_chart_rounded,
      ),
      (
        label: 'Profils de buts',
        value: count({
          'open_match',
          'offensive_match',
          'closed_match',
          'defensive_match',
          'prolific_attack',
          'fragile_defense',
          'frequent_btts',
          'frequent_over_25',
        }),
        color: context.semantic.info,
        icon: Icons.sports_soccer_rounded,
      ),
      (
        label: 'Équilibre',
        value: count({'balanced_hierarchy', 'balanced_match'}),
        color: context.features.generatorAccent,
        icon: Icons.balance_rounded,
      ),
      (
        label: 'Vigilances',
        value: count({
          'contradiction',
          'conflicting_signals',
          'insufficient_data',
          'misleading_result',
          'avoid_match',
        }),
        color: context.semantic.warning,
        icon: Icons.info_outline_rounded,
      ),
    ];
    void open() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EuropeanEveningPage(
          matches: items,
          date: date,
          showReadings: showReadings,
          onOpenMatch: onOpenMatch,
        ),
      ),
    );
    return Material(
      key: const ValueKey('champions-evening-briefing'),
      color: palette.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: palette.light ? .08 : .38,
                child: Image.asset(
                  CompetitionCardIdentity.champions.backgroundAsset!,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        palette.title,
                        BlendMode.srcIn,
                      ),
                      child: SportsAssetBadge(
                        size: 28,
                        imageUrl: items.first.competition.logoUrl,
                        fallbackLabel: 'Ligue des champions',
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LIGUE DES CHAMPIONS',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: .7,
                              fontWeight: FontWeight.w700,
                              color: palette.title,
                            ),
                          ),
                          Text(
                            '${items.length} match${items.length > 1 ? 's' : ''} · ${DateFormat('dd/MM').format(date)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Briefing de la soirée',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Les rencontres de la journée et leurs lectures disponibles.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textColors.secondary,
                  ),
                ),
                if (showReadings) ...[
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, box) => Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final stat in stats)
                          SizedBox(
                            width:
                                (box.maxWidth - (box.maxWidth < 320 ? 6 : 18)) /
                                (box.maxWidth < 320 ? 2 : 4),
                            child: Tooltip(
                              message:
                                  '${stat.value} rencontre(s) avec une lecture ${stat.label.toLowerCase()} déjà détectée dans votre périmètre.',
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: palette.background.withValues(
                                    alpha: .8,
                                  ),
                                  border: Border.all(
                                    color: stat.color.withValues(alpha: .22),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.control,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            stat.icon,
                                            size: 14,
                                            color: stat.color,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${stat.value}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        stat.label,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: stat.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('open-champions-evening'),
                  onPressed: open,
                  icon: const Icon(Icons.emoji_events_outlined, size: 16),
                  label: const Text(
                    'Explorer la soirée Champions League',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EuropeanEveningPage extends StatelessWidget {
  const _EuropeanEveningPage({
    required this.matches,
    required this.date,
    required this.showReadings,
    required this.onOpenMatch,
  });
  final List<MatchBoardItem> matches;
  final DateTime date;
  final bool showReadings;
  final ValueChanged<MatchBoardItem> onOpenMatch;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Soirée Champions League',
        style: TextStyle(fontSize: 17),
      ),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                '${matches.length} rencontres · ${DateFormat('dd/MM').format(date)}',
              ),
              const SizedBox(height: 12),
              for (final match in matches) ...[
                MatchFeedCard(
                  match: match,
                  showReadings: showReadings,
                  onTap: () => onOpenMatch(match),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
