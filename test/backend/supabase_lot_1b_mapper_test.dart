import 'package:flutter_test/flutter_test.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/tickets/data/supabase_saved_ticket_repository.dart';
import 'package:copilot/features/tickets/data/supabase_ticket_strategy_repository.dart';
import 'package:copilot/features/tickets/domain/saved_ticket.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';

void main() {
  group('Supabase Lot 1B mappers', () {
    test('maps TicketStrategy to snake_case rows and back', () {
      final createdAt = DateTime.utc(2026, 8, 10, 8, 30);
      final strategy = TicketStrategy(
        schemaVersion: TicketStrategy.currentSchemaVersion,
        id: 'safe-2',
        userId: 'local-user',
        name: 'Safe 2',
        isActive: true,
        pickTypes: const [PickType.prudent, PickType.normal],
        minimumIndividualOdds: 1.35,
        maximumIndividualOdds: 2.10,
        minimumSelections: 2,
        maximumSelections: 3,
        minimumTotalOdds: 2.80,
        maximumTotalOdds: 3.10,
        priority: 2,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      final row = ticketStrategyToSupabaseRow(strategy, userId: 'user-1');
      expect(row['user_id'], 'user-1');
      expect(row['schema_version'], 2);
      expect(row['pick_types'], ['prudent', 'normal']);
      expect(row['minimum_individual_odds'], 1.35);
      expect(row['maximum_total_odds'], 3.10);

      final restored = ticketStrategyFromSupabaseRow(row);
      expect(restored.userId, 'user-1');
      expect(restored.id, strategy.id);
      expect(restored.pickTypes, strategy.pickTypes);
      expect(restored.maximumTotalOdds, strategy.maximumTotalOdds);
    });

    test('maps SavedTicket and selections to normalized backend rows', () {
      final createdAt = DateTime.utc(2026, 8, 10, 9);
      final ticket = SavedTicket(
        schemaVersion: SavedTicket.currentSchemaVersion,
        id: 'ticket-1',
        source: SavedTicketSource.copilotModified,
        status: SavedTicketStatus.played,
        createdAt: createdAt,
        updatedAt: createdAt,
        totalOdds: 2.91,
        strategyId: 'strategy-1',
        strategyName: 'Picks normal',
        playedDeclaration: SavedTicketPlayDeclaration(
          bookmaker: 'Betclic',
          stake: 10,
          actualTotalOdds: 2.88,
          playedAt: createdAt,
        ),
        mainCombinedReadingId: 'open_match_confirmed',
        opportunityIds: const ['opp-1', 'opp-2'],
        modificationSummary: '1 marché remplacé',
        modificationDetails: const ['Marseille - Nice : BTTS -> 1X'],
        selections: const [
          SavedTicketSelection(
            id: 'selection-1',
            matchId: 'match-1',
            homeTeam: 'Arsenal',
            awayTeam: 'Tottenham',
            competitionName: 'Premier League',
            marketId: 'double_chance',
            marketLabel: 'Double chance',
            selectionId: '1x',
            selectionLabel: '1X',
            odds: 1.42,
            bookmakerName: 'Betclic',
            opportunityId: 'opp-1',
          ),
        ],
      );

      final ticketRow = savedTicketToSupabaseRow(ticket, userId: 'user-1');
      final selectionRows = savedTicketSelectionRows(ticket, userId: 'user-1');

      expect(ticketRow['source'], 'copilotModified');
      expect(ticketRow['status'], 'played');
      expect(ticketRow['played_bookmaker'], 'Betclic');
      expect(ticketRow['opportunity_ids'], ['opp-1', 'opp-2']);
      expect(selectionRows.single['position'], 0);
      expect(selectionRows.single['market_label'], 'Double chance');
      expect(selectionRows.single['match_id'], 'match-1');

      final restored = savedTicketFromSupabaseRows(
        ticketRow: ticketRow,
        selectionRows: selectionRows,
      );
      expect(restored.id, ticket.id);
      expect(restored.source, SavedTicketSource.copilotModified);
      expect(restored.status, SavedTicketStatus.played);
      expect(restored.playedDeclaration?.bookmaker, 'Betclic');
      expect(restored.selections.single.selectionLabel, '1X');
      expect(restored.modificationDetails, ticket.modificationDetails);
    });
  });
}
