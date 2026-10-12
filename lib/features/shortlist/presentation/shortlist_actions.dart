import '../../../core/widgets/lector_shortlist_icon.dart';
import 'package:flutter/material.dart';
import '../../../app/auth/lector_account_sheet.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/sports/domain/sport_fixture.dart';
import '../../matches/domain/match_board_item.dart';
import '../../generator/domain/generator_context.dart';
import '../application/shortlist_controller.dart';
import '../domain/shortlist.dart';
import 'shortlist_page.dart';

ShortlistFixture shortlistFootball(MatchBoardItem m) => ShortlistFixture({
  'sport': 'football',
  'fixtureId':
      (m.fixture.apiFootballFixtureId ?? m.id.replaceFirst('api-fixture-', ''))
          .toString(),
  'matchId': m.id,
  'home': m.homeTeam.name,
  'away': m.awayTeam.name,
  'homeLogo': m.homeTeam.logoUrl,
  'awayLogo': m.awayTeam.logoUrl,
  'competition': m.competition.name,
  'kickoff': m.fixture.kickoff?.toUtc().toIso8601String(),
  'status': switch (m.fixture.status) {
    FixtureStatus.scheduled => 'NS',
    FixtureStatus.finished => 'FT',
    FixtureStatus.live => 'live',
    FixtureStatus.postponed => 'postponed',
    FixtureStatus.cancelled => 'cancelled',
  },
  'date': generatorDay(m.fixture.kickoff?.toLocal() ?? DateTime.now()),
});
ShortlistFixture shortlistSport(SportFixture f) => ShortlistFixture({
  'sport': f.sport.key,
  'fixtureId': f.id.value,
  'matchId': f.id.key,
  'home': f.home.name,
  'away': f.away.name,
  'homeLogo': f.home.logoUrl,
  'awayLogo': f.away.logoUrl,
  'competition': f.competitionName,
  'kickoff': f.startsAt?.toUtc().toIso8601String(),
  'date': generatorDay(
    f.startsAt?.toLocal() ?? f.calendarDate ?? DateTime.now(),
  ),
  'status': f.status.name,
});
ShortlistController? shortlistController() =>
    getIt.isRegistered<ShortlistController>()
    ? getIt<ShortlistController>()
    : null;
void openShortlist(BuildContext context) {
  final controller = shortlistController();
  if (controller != null) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShortlistPage(controller: controller),
      ),
    );
  }
}

class ShortlistEntryButton extends StatelessWidget {
  const ShortlistEntryButton({this.compact = false, super.key});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final controller = shortlistController();
    if (controller == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final count = controller.items.length;
          final needed =
              (84 + (count == 0 ? 0 : 3 + '$count'.length * 7)) *
              (MediaQuery.textScalerOf(context).scale(12) / 12);
          final showLabel =
              !compact &&
              (!constraints.hasBoundedWidth || constraints.maxWidth >= needed);
          return Tooltip(
            message: 'Ma Shortlist : $count rencontres',
            child: TextButton(
              key: const ValueKey('open-shortlist'),
              onPressed: () => openShortlist(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LectorShortlistIcon(color: context.semantic.info, size: 21),
                  if (showLabel) ...[
                    const SizedBox(width: 4),
                    Text(
                      'Shortlist',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.semantic.info,
                      ),
                    ),
                  ],
                  if (count > 0) ...[
                    const SizedBox(width: 3),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.semantic.info,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ShortlistAddButton extends StatelessWidget {
  const ShortlistAddButton({required this.fixture, super.key});
  final ShortlistFixture fixture;
  @override
  Widget build(BuildContext context) {
    final controller = shortlistController();
    if (controller == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final present = controller.contains(fixture.key);
        return IconButton(
          key: ValueKey('shortlist-add:${fixture.key}'),
          tooltip: present
              ? 'Retirer de la Shortlist'
              : 'Ajouter à la Shortlist',
          icon: LectorShortlistIcon(
            selected: present,
            color: present
                ? context.brand.accent
                : context.textColors.secondary,
          ),
          onPressed: () async {
            if (controller.account == null) {
              await showLectorAccountSheet(context);
              return;
            }
            try {
              await controller.mutate(
                present ? 'remove' : 'add',
                fixture: fixture,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      controller.error ??
                          'Votre action n’a pas été enregistrée.',
                    ),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}
