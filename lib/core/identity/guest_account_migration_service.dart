import '../../features/matches/data/saved_match_favorites_store.dart';
import '../../features/onboarding/data/saved_decision_profile_store.dart';
import '../../features/tickets/data/saved_ticket_store.dart';
import '../../features/tickets/data/saved_ticket_strategy_store.dart';
import 'identity_scope.dart';

class GuestAccountMigrationService {
  const GuestAccountMigrationService({
    this.profileStore = const SavedDecisionProfileStore(),
    this.ticketStrategyStore = const SavedTicketStrategyStore(),
    this.favoriteStore = const SavedMatchFavoritesStore(),
    this.ticketStore = const SavedTicketStore(),
  });

  final SavedDecisionProfileStore profileStore;
  final SavedTicketStrategyStore ticketStrategyStore;
  final SavedMatchFavoritesStore favoriteStore;
  final SavedTicketStore ticketStore;

  Future<void> migrateGuestToNewAccount({
    required IdentityScope guestScope,
    required IdentityScope accountScope,
  }) async {
    if (!guestScope.isGuest) {
      throw ArgumentError.value(guestScope, 'guestScope', 'Must be guest.');
    }
    if (!accountScope.isAccount) {
      throw ArgumentError.value(
        accountScope,
        'accountScope',
        'Must be account.',
      );
    }

    final profile = await profileStore.load(scope: guestScope);
    final strategies = await ticketStrategyStore.load(scope: guestScope);
    final favoriteIds = await favoriteStore.load(scope: guestScope);
    final tickets = await ticketStore.load(scope: guestScope);

    if (profile != null) {
      await profileStore.save(scope: accountScope, profile: profile);
    }
    await ticketStrategyStore.save(scope: accountScope, strategies: strategies);
    await favoriteStore.save(scope: accountScope, favoriteIds: favoriteIds);
    await ticketStore.saveAll(scope: accountScope, tickets: tickets);
  }
}
