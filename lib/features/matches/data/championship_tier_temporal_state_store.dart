import '../domain/structural_tiers/standings_snapshot_identity.dart';
import '../domain/structural_tiers/tier_models.dart';

abstract interface class ChampionshipTierTemporalStateStore {
  PreviousBoundaryState? read(ChampionshipTierTemporalLineageKey key);

  void write(
    ChampionshipTierTemporalLineageKey key,
    PreviousBoundaryState state,
  );

  void reset();
}

class InMemoryChampionshipTierTemporalStateStore
    implements ChampionshipTierTemporalStateStore {
  InMemoryChampionshipTierTemporalStateStore();

  final Map<String, PreviousBoundaryState> _states = {};

  @override
  PreviousBoundaryState? read(ChampionshipTierTemporalLineageKey key) {
    return _states[key.value];
  }

  @override
  void write(
    ChampionshipTierTemporalLineageKey key,
    PreviousBoundaryState state,
  ) {
    _states[key.value] = state;
  }

  @override
  void reset() {
    _states.clear();
  }
}
