import '../../../core/identity/identity_scope.dart';
import '../domain/decision_profile.dart';

class SavedDecisionProfileStore {
  const SavedDecisionProfileStore();

  Future<DecisionProfile?> load({required IdentityScope scope}) async => null;

  Future<void> save({
    required IdentityScope scope,
    required DecisionProfile profile,
  }) async {}
}
