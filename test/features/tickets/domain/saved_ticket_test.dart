import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/tickets/domain/generated_ticket.dart';
import 'package:copilot/features/tickets/domain/generated_ticket_pick.dart';
import 'package:copilot/features/tickets/domain/saved_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavedTicket', () {
    test('keeps a durable Copilot ticket snapshot', () {
      final savedAt = DateTime.utc(2026, 8, 5, 12);
      final ticket = GeneratedTicket(
        id: 'generated-1',
        strategyId: 'safe',
        strategyName: 'SAFE',
        picks: const [
          GeneratedTicketPick(
            opportunityId: 'opportunity-1',
            matchId: 'match-1',
            homeTeam: 'Arsenal',
            awayTeam: 'Tottenham',
            competitionName: 'Premier League',
            kickoffLabel: '16:00',
            marketId: 'doubleChance',
            marketLabel: 'Double chance',
            selectionId: 'home_or_draw',
            selectionLabel: '1X',
            odds: 1.42,
            pickType: PickType.prudent,
            thesisId: 'favorite_with_protection',
            opportunityProfileIds: ['solid_favorite'],
            engineScore: 5,
          ),
        ],
        totalOdds: 1.42,
        selectionCount: 1,
        generatedAt: savedAt,
        variantIndex: 0,
      );

      final saved = SavedTicket.fromGenerated(ticket: ticket, savedAt: savedAt);
      final restored = SavedTicket.fromJson(saved.toJson());

      expect(restored.source, SavedTicketSource.copilot);
      expect(restored.status, SavedTicketStatus.saved);
      expect(restored.strategyName, 'SAFE');
      expect(restored.opportunityIds, ['opportunity-1']);
      expect(restored.selections.single.matchLabel, 'Arsenal - Tottenham');
      expect(restored.selections.single.competitionName, 'Premier League');
    });

    test('persists modified ticket summary and detailed trace', () {
      final savedAt = DateTime.utc(2026, 8, 5, 12);
      final ticket = GeneratedTicket(
        id: 'generated-1',
        strategyId: 'safe',
        strategyName: 'SAFE',
        picks: const [
          GeneratedTicketPick(
            opportunityId: 'opportunity-1',
            matchId: 'match-1',
            homeTeam: 'Arsenal',
            awayTeam: 'Tottenham',
            competitionName: 'Premier League',
            kickoffLabel: '16:00',
            marketId: 'doubleChance',
            marketLabel: 'Double chance',
            selectionId: 'home_or_draw',
            selectionLabel: '1X',
            odds: 1.42,
            pickType: PickType.prudent,
            thesisId: 'favorite_with_protection',
            opportunityProfileIds: ['solid_favorite'],
            engineScore: 5,
          ),
        ],
        totalOdds: 1.42,
        selectionCount: 1,
        generatedAt: savedAt,
        variantIndex: 0,
      );

      final saved = SavedTicket.fromGenerated(
        ticket: ticket,
        savedAt: savedAt,
        source: SavedTicketSource.copilotModified,
        modificationSummary: '1 marché remplacé',
        modificationDetails: const [
          'Marché remplacé : Arsenal - Tottenham · 1X → 12',
        ],
      );
      final restored = SavedTicket.fromJson(saved.toJson());

      expect(restored.source, SavedTicketSource.copilotModified);
      expect(restored.modificationSummary, '1 marché remplacé');
      expect(restored.modificationDetails, [
        'Marché remplacé : Arsenal - Tottenham · 1X → 12',
      ]);
    });
  });
}
