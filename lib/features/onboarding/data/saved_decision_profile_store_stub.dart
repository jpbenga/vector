import '../domain/decision_profile.dart';

class SavedDecisionProfileStore {
  const SavedDecisionProfileStore();

  Future<DecisionProfile?> load() async => null;

  Future<void> save(DecisionProfile profile) async {}
}
