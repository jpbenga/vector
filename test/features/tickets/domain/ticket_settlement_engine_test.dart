import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/tickets/domain/saved_ticket.dart';
import 'package:copilot/features/tickets/domain/ticket_settlement_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = TicketSettlementEngine();
  final checkedAt = DateTime.utc(2026, 8, 12, 18);

  test('settles a played ticket as won when all selections are correct', () {
    final tickets = engine.settleTickets(
      tickets: [
        _ticket(
          selections: [
            _selection(
              matchId: 'match-1',
              marketId: 'matchResult',
              selectionId: 'matchResult:home',
              selectionLabel: '1',
            ),
            _selection(
              id: 'selection-2',
              matchId: 'match-2',
              marketId: 'bothTeamsScore',
              selectionId: 'bothTeamsScore:yes',
              selectionLabel: 'Oui',
            ),
          ],
        ),
      ],
      matches: [
        _match(id: 'match-1', score: const FixtureScore(home: 2, away: 0)),
        _match(id: 'match-2', score: const FixtureScore(home: 1, away: 1)),
      ],
      checkedAt: checkedAt,
    );

    expect(tickets.single.status, SavedTicketStatus.won);
    expect(tickets.single.updatedAt, checkedAt);
  });

  test('settles a played ticket as lost as soon as one selection is false', () {
    final tickets = engine.settleTickets(
      tickets: [
        _ticket(
          selections: [
            _selection(
              matchId: 'match-1',
              marketId: 'doubleChance',
              selectionId: 'doubleChance:home:draw',
              selectionLabel: '1X',
            ),
            _selection(
              id: 'selection-2',
              matchId: 'match-2',
              marketId: 'goalsTotal',
              selectionId: 'goalsTotal:over:2.50',
              selectionLabel: '+2.5 buts',
            ),
          ],
        ),
      ],
      matches: [
        _match(id: 'match-1', score: const FixtureScore(home: 0, away: 1)),
        _match(id: 'match-2', status: FixtureStatus.scheduled),
      ],
      checkedAt: checkedAt,
    );

    expect(tickets.single.status, SavedTicketStatus.lost);
  });

  test('keeps a played ticket pending while finished results are missing', () {
    final ticket = _ticket(
      selections: [
        _selection(
          matchId: 'match-1',
          marketId: 'matchResult',
          selectionId: 'matchResult:home',
          selectionLabel: '1',
        ),
      ],
    );
    final originalTickets = [ticket];
    final tickets = engine.settleTickets(
      tickets: originalTickets,
      matches: [_match(id: 'match-1', status: FixtureStatus.live)],
      checkedAt: checkedAt,
    );

    expect(identical(tickets, originalTickets), isTrue);
    expect(tickets.single.status, SavedTicketStatus.played);
    expect(tickets.single.updatedAt, ticket.updatedAt);
  });

  test('keeps unsupported markets pending instead of forcing a status', () {
    final ticket = _ticket(
      selections: [
        _selection(
          matchId: 'match-1',
          marketId: 'goalscorer',
          selectionId: 'player-42',
          selectionLabel: 'Buteur',
        ),
      ],
    );
    final originalTickets = [ticket];
    final tickets = engine.settleTickets(
      tickets: originalTickets,
      matches: [
        _match(id: 'match-1', score: const FixtureScore(home: 3, away: 1)),
      ],
      checkedAt: checkedAt,
    );

    expect(identical(tickets, originalTickets), isTrue);
    expect(tickets.single.status, SavedTicketStatus.played);
    expect(tickets.single.updatedAt, ticket.updatedAt);
  });

  test('does not touch saved or already terminal tickets', () {
    final saved = _ticket(status: SavedTicketStatus.saved);
    final won = _ticket(id: 'won', status: SavedTicketStatus.won);
    final originalTickets = [saved, won];
    final tickets = engine.settleTickets(
      tickets: originalTickets,
      matches: [
        _match(id: 'match-1', score: const FixtureScore(home: 1, away: 0)),
      ],
      checkedAt: checkedAt,
    );

    expect(identical(tickets, originalTickets), isTrue);
    expect(tickets[0].status, SavedTicketStatus.saved);
    expect(tickets[1].status, SavedTicketStatus.won);
  });
}

SavedTicket _ticket({
  String id = 'ticket-1',
  SavedTicketStatus status = SavedTicketStatus.played,
  List<SavedTicketSelection>? selections,
}) {
  final createdAt = DateTime.utc(2026, 8, 12, 12);
  return SavedTicket(
    schemaVersion: SavedTicket.currentSchemaVersion,
    id: id,
    source: SavedTicketSource.manual,
    status: status,
    createdAt: createdAt,
    updatedAt: createdAt,
    totalOdds: 2,
    selections:
        selections ??
        [
          _selection(
            matchId: 'match-1',
            marketId: 'matchResult',
            selectionId: 'matchResult:home',
            selectionLabel: '1',
          ),
        ],
    playedDeclaration: status == SavedTicketStatus.played
        ? SavedTicketPlayDeclaration(
            bookmaker: 'Betclic',
            stake: 10,
            actualTotalOdds: 2,
            playedAt: createdAt,
          )
        : null,
  );
}

SavedTicketSelection _selection({
  String id = 'selection-1',
  required String matchId,
  required String marketId,
  required String selectionId,
  required String selectionLabel,
}) {
  return SavedTicketSelection(
    id: id,
    matchId: matchId,
    homeTeam: 'Home',
    awayTeam: 'Away',
    competitionName: 'League',
    marketId: marketId,
    marketLabel: marketId,
    selectionId: selectionId,
    selectionLabel: selectionLabel,
    odds: 1.5,
  );
}

MatchBoardItem _match({
  required String id,
  FixtureStatus status = FixtureStatus.finished,
  FixtureScore? score,
}) {
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: id,
      competition: const CompetitionInfo(
        id: 'league',
        name: 'League',
        country: CountryInfo(code: 'FR', name: 'France'),
        season: 2026,
      ),
      homeTeam: const TeamInfo(id: 'home', name: 'Home'),
      awayTeam: const TeamInfo(id: 'away', name: 'Away'),
      kickoffLabel: '20:00',
      status: status,
      score: score,
    ),
    primaryMarket: const MarketOdds(
      id: 'market_unavailable',
      label: 'Marché indisponible',
      odds: 0,
    ),
    compatibility: 0,
    signals: const [],
  );
}
