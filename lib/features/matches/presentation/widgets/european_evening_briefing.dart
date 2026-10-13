import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_components.dart';
import '../../../../core/theme/competition_card_theme.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/sports_asset_badge.dart';
import '../../domain/match_board_item.dart';
import 'match_feed_card.dart';

/// Only competitions present in the selected day's feed are included.
/// Counts and reading labels come from the existing published match cards.
class EuropeanEveningBriefing extends StatefulWidget {
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
  @override
  State<EuropeanEveningBriefing> createState() =>
      _EuropeanEveningBriefingState();
}

class _EuropeanEveningBriefingState extends State<EuropeanEveningBriefing> {
  final _controller = PageController();
  int _page = 0;
  final _heights = <int, double>{};
  static const _priority = [2, 3, 848];
  List<int> get _competitions => _priority
      .where(
        (id) =>
            widget.matches.any((m) => m.competition.apiFootballLeagueId == id),
      )
      .toList();

  @override
  void didUpdateWidget(covariant EuropeanEveningBriefing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = _priority
        .where(
          (id) => oldWidget.matches.any(
            (m) => m.competition.apiFootballLeagueId == id,
          ),
        )
        .join(',');
    if (oldWidget.date != widget.date || oldIds != _competitions.join(',')) {
      _page = 0;
      _heights.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = _competitions;
    if (ids.isEmpty) return const SizedBox.shrink();
    Widget card(int id) => _BriefingCard(
      matches: widget.matches
          .where((m) => m.competition.apiFootballLeagueId == id)
          .toList(),
      date: widget.date,
      showReadings: widget.showReadings,
      onOpenMatch: widget.onOpenMatch,
    );
    if (ids.length == 1) return card(ids.single);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: _heights[ids[_page]] ?? 200 * scale.clamp(1.0, 3.0),
            child: PageView(
              key: ValueKey('european-briefings-${widget.date}'),
              controller: _controller,
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                for (final id in ids)
                  OverflowBox(
                    minHeight: 0,
                    maxHeight: double.infinity,
                    alignment: Alignment.topCenter,
                    child: _BriefingHeight(
                      onHeight: (height) {
                        if (mounted && _heights[id] != height) {
                          setState(() => _heights[id] = height);
                        }
                      },
                      child: card(id),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Briefing précédent',
              onPressed: _page > 0 ? () => _go(_page - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Flexible(
              child: Text(
                'Briefing ${_page + 1} / ${ids.length}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: context.textColors.secondary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Briefing suivant',
              onPressed: _page < ids.length - 1 ? () => _go(_page + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _BriefingCard extends StatelessWidget {
  const _BriefingCard({
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
  Widget build(BuildContext context) {
    final competition = matches.first.competition;
    final identity = switch (competition.apiFootballLeagueId) {
      2 => CompetitionCardIdentity.champions,
      3 => CompetitionCardIdentity.europa,
      _ => CompetitionCardIdentity.conference,
    };
    final palette = CompetitionCardTheme(context, identity);
    final withReadings = matches
        .where((m) => publishedMatchCardReadings(m).isNotEmpty)
        .length;
    return Material(
      key: ValueKey(
        'european-evening-briefing-${competition.apiFootballLeagueId}',
      ),
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
                opacity: palette.light ? .08 : .28,
                child: Image.asset(
                  identity.backgroundAsset!,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SportsAssetBadge(
                        size: 28,
                        imageUrl: competition.logoUrl,
                        contrastPlate: true,
                        fallbackLabel: competition.name,
                        backgroundColor: AppColors.transparent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          competition.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: palette.title,
                          ),
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
                    '${matches.length} match${matches.length > 1 ? 's' : ''} · ${DateFormat('dd/MM').format(date)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    showReadings
                        ? withReadings == 0
                              ? 'Aucune lecture de votre profil pour ces rencontres.'
                              : '$withReadings rencontre${withReadings > 1 ? 's' : ''} avec des lectures Lector.'
                        : 'Découvrez les rencontres de cette compétition.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: ValueKey(
                      'open-european-evening-${competition.apiFootballLeagueId}',
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _EuropeanEveningPage(
                          matches: matches,
                          date: date,
                          showReadings: showReadings,
                          onOpenMatch: onOpenMatch,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.emoji_events_outlined, size: 16),
                    label: const Text(
                      'Explorer la soirée',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
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
      title: Text(
        matches.first.competition.name,
        style: const TextStyle(fontSize: 17),
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

class _BriefingHeight extends SingleChildRenderObjectWidget {
  const _BriefingHeight({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _BriefingHeightBox(onHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _BriefingHeightBox renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _BriefingHeightBox extends RenderProxyBox {
  _BriefingHeightBox(this.onHeight);
  ValueChanged<double> onHeight;
  double? _previous;
  @override
  void performLayout() {
    super.performLayout();
    if (_previous == size.height) return;
    _previous = size.height;
    final height = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
