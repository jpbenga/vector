import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/tickets/domain/saved_ticket.dart';
import 'package:copilot/features/tickets/domain/ticket_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TicketDraft', () {
    test('adds selections once and recalculates total odds', () {
      final first = TicketDraftSelection.fromMatchSelection(
        _match('a'),
        _market('doubleChance', 'Double chance', '1X', 1.42),
        _selection('1X', 1.42),
      )!;
      final second = TicketDraftSelection.fromMatchSelection(
        _match('b'),
        _market('bothTeamsScore', 'Les deux équipes marquent', 'Oui', 1.71),
        _selection('Oui', 1.71),
      )!;

      final draft = TicketDraft.empty.add(first).add(first).add(second);

      expect(draft.selectionCount, 2);
      expect(draft.totalOdds, 2.43);
    });

    test('toggles and removes selections by stable id', () {
      final selection = TicketDraftSelection.fromMatchSelection(
        _match('a'),
        _market('matchResult', 'Résultat du match', '1', 1.58),
        _selection('1', 1.58),
      )!;

      final added = TicketDraft.empty.toggle(selection);
      final removed = added.toggle(selection);

      expect(added.contains(selection.id), isTrue);
      expect(removed.isEmpty, isTrue);
      expect(added.remove(selection.id).isEmpty, isTrue);
    });

    test('prevents several selections from the same match', () {
      final match = _match('a');
      final home = TicketDraftSelection.fromMatchSelection(
        match,
        _market('matchResult', 'Résultat du match', '1', 1.58),
        _selection('1', 1.58),
      )!;
      final draw = TicketDraftSelection.fromMatchSelection(
        match,
        _market('matchResult', 'Résultat du match', 'N', 3.25),
        _selection('N', 3.25),
      )!;

      final draft = TicketDraft.empty.add(home).add(draw);

      expect(draft.selectionCount, 1);
      expect(draft.contains(home.id), isTrue);
      expect(draft.containsMatch(match.id), isTrue);
      expect(draft.containsAnotherSelectionForMatch(draw), isTrue);
      expect(draft.canToggle(draw), isFalse);
      expect(draft.totalOdds, 1.58);
    });

    test('creates a saved ticket snapshot and marks it as played', () {
      final selection = TicketDraftSelection.fromMatchSelection(
        _match('a'),
        _market('doubleChance', 'Double chance', '1X', 1.42),
        _selection('1X', 1.42),
      )!;
      final createdAt = DateTime.utc(2026, 8, 2, 18);
      final saved = SavedTicket.fromDraft(
        draft: TicketDraft.empty.add(selection),
        name: 'Ticket du soir',
        createdAt: createdAt,
        strategyId: 'safe',
        strategyName: 'SAFE',
        plannedStake: 10,
      );
      final played = saved.copyWith(
        status: SavedTicketStatus.played,
        playedDeclaration: SavedTicketPlayDeclaration(
          bookmaker: 'Betclic',
          stake: 10,
          actualTotalOdds: 1.42,
          playedAt: createdAt,
        ),
      );

      expect(saved.name, 'Ticket du soir');
      expect(saved.selectionCount, 1);
      expect(saved.totalOdds, 1.42);
      expect(saved.source, SavedTicketSource.manual);
      expect(saved.status, SavedTicketStatus.saved);
      expect(played.status, SavedTicketStatus.played);
      expect(played.playedDeclaration?.bookmaker, 'Betclic');
    });

    test('serializes saved tickets for local persistence', () {
      final selection = TicketDraftSelection.fromMatchSelection(
        _match('a'),
        _market('doubleChance', 'Double chance', '1X', 1.42),
        _selection('1X', 1.42),
      )!;
      final createdAt = DateTime.utc(2026, 8, 2, 18);
      final saved = SavedTicket.fromDraft(
        draft: TicketDraft.empty.add(selection),
        name: '',
        createdAt: createdAt,
      );

      final restored = SavedTicket.fromJson(saved.toJson());

      expect(restored.id, saved.id);
      expect(restored.name, 'Mon ticket');
      expect(restored.createdAt, createdAt);
      expect(restored.selections.single.competitionName, 'Ligue 1');
      expect(restored.selections.single.bookmakerName, 'Betclic');
    });
  });
}

MatchBoardItem _match(String id) {
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: id,
      competition: const CompetitionInfo(
        id: '61',
        name: 'Ligue 1',
        country: CountryInfo(code: 'FR', name: 'France'),
        season: 2026,
      ),
      homeTeam: TeamInfo(id: '$id-home', name: 'Home $id'),
      awayTeam: TeamInfo(id: '$id-away', name: 'Away $id'),
      kickoffLabel: '20:00',
      status: FixtureStatus.scheduled,
    ),
    primaryMarket: const MarketOdds(
      id: 'market_unavailable',
      label: 'Marché indisponible',
      odds: 0,
    ),
    availableMarkets: const [],
    compatibility: 0,
    signals: const [],
  );
}

MatchMarket _market(
  String id,
  String label,
  String selectionLabel,
  double odds,
) {
  return MatchMarket(
    id: id,
    label: label,
    selections: [_selection(selectionLabel, odds)],
    bookmakerName: 'Betclic',
  );
}

MarketOdds _selection(String label, double odds) {
  return MarketOdds(id: 'selection-$label', label: label, odds: odds);
}
