import 'package:copilot/features/matches/data/local_remote_favorites_sync.dart';
import 'package:copilot/features/onboarding/data/local_remote_profile_sync.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/tickets/data/local_remote_ticket_sync.dart';
import 'package:copilot/features/tickets/domain/saved_ticket.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase Lot 1B local/remote sync', () {
    test('keeps an answered local profile when the user signs in', () {
      final localProfile = DecisionProfile(
        onboardingVersion: '2.0',
        answers: const [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['fr-ligue-1'],
          ),
        ],
      );
      final remoteProfile = DecisionProfile(
        onboardingVersion: '2.0',
        answers: const [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['en-premier-league'],
          ),
        ],
      );

      final resolved = resolveSyncedDecisionProfile(
        localProfile: localProfile,
        remoteProfile: remoteProfile,
      );

      expect(resolved, localProfile);
    });

    test('uses the remote profile when local mode only has an empty shell', () {
      const localProfile = DecisionProfile(
        onboardingVersion: '2.0',
        answers: [],
      );
      final remoteProfile = DecisionProfile(
        onboardingVersion: '2.0',
        answers: const [
          OnboardingAnswer(
            questionId: 'markets',
            orderedOptionIds: ['match_result'],
          ),
        ],
      );

      final resolved = resolveSyncedDecisionProfile(
        localProfile: localProfile,
        remoteProfile: remoteProfile,
      );

      expect(resolved, remoteProfile);
    });

    test(
      'merges ticket strategies and keeps the most recently updated item',
      () {
        final older = DateTime.utc(2026, 8, 10, 10);
        final newer = DateTime.utc(2026, 8, 10, 11);
        final remoteSafe = _strategy(
          id: 'safe',
          name: 'SAFE remote',
          priority: 2,
          updatedAt: older,
        );
        final localSafe = _strategy(
          id: 'safe',
          name: 'SAFE local',
          priority: 1,
          updatedAt: newer,
        );
        final remoteFun = _strategy(
          id: 'fun',
          name: 'FUN',
          priority: 3,
          updatedAt: older,
        );

        final merged = mergeTicketStrategies(
          localStrategies: [localSafe],
          remoteStrategies: [remoteSafe, remoteFun],
        );

        expect(merged.map((strategy) => strategy.id), ['safe', 'fun']);
        expect(merged.first.name, 'SAFE local');
        expect(merged.first.priority, 1);
      },
    );

    test('merges saved tickets and keeps the most recently updated item', () {
      final createdAt = DateTime.utc(2026, 8, 10, 9);
      final older = createdAt.add(const Duration(minutes: 5));
      final newer = createdAt.add(const Duration(minutes: 10));
      final remoteTicket = _ticket(
        id: 'ticket-1',
        name: 'Remote',
        createdAt: createdAt,
        updatedAt: older,
      );
      final localTicket = _ticket(
        id: 'ticket-1',
        name: 'Local',
        createdAt: createdAt,
        updatedAt: newer,
      );
      final remoteOnly = _ticket(
        id: 'ticket-2',
        name: 'Remote only',
        createdAt: createdAt.add(const Duration(hours: 1)),
        updatedAt: older,
      );

      final merged = mergeSavedTickets(
        localTickets: [localTicket],
        remoteTickets: [remoteTicket, remoteOnly],
      );

      expect(merged.map((ticket) => ticket.id), ['ticket-2', 'ticket-1']);
      expect(merged.last.name, 'Local');
    });

    test('unions local and remote match favorites', () {
      final merged = mergeMatchFavoriteIds(
        localFavoriteIds: {'fixture-1', 'fixture-2'},
        remoteFavoriteIds: {'fixture-2', 'fixture-3'},
      );

      expect(merged, {'fixture-1', 'fixture-2', 'fixture-3'});
    });
  });
}

TicketStrategy _strategy({
  required String id,
  required String name,
  required int priority,
  required DateTime updatedAt,
}) {
  final createdAt = DateTime.utc(2026, 8, 10);
  return TicketStrategy(
    schemaVersion: TicketStrategy.currentSchemaVersion,
    id: id,
    userId: 'user-1',
    name: name,
    isActive: true,
    pickTypes: const [PickType.prudent],
    minimumIndividualOdds: 1.20,
    maximumIndividualOdds: 1.80,
    minimumSelections: 2,
    maximumSelections: 3,
    minimumTotalOdds: 2,
    maximumTotalOdds: 3,
    priority: priority,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

SavedTicket _ticket({
  required String id,
  required String name,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  return SavedTicket(
    schemaVersion: SavedTicket.currentSchemaVersion,
    id: id,
    source: SavedTicketSource.manual,
    status: SavedTicketStatus.saved,
    createdAt: createdAt,
    updatedAt: updatedAt,
    totalOdds: 1.42,
    name: name,
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
      ),
    ],
  );
}
