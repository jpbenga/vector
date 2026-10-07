import 'sport.dart';
import 'sport_fixture.dart';
import 'sport_policy.dart';
import 'sport_snapshot.dart';

enum SportFeedUnavailableReason {
  notConnected,
  notPublished,
  stale,
  outsideWindow,
}

/// Empty available snapshots and absent publications are distinct states.
/// Neither should prevent the application shell from being navigated.
class SportFeedResult {
  const SportFeedResult.available(SportSnapshot<SportFixture> publication)
    : snapshot = publication,
      unavailableReason = null;
  const SportFeedResult.unavailable(SportFeedUnavailableReason reason)
    : snapshot = null,
      unavailableReason = reason;
  final SportSnapshot<SportFixture>? snapshot;
  final SportFeedUnavailableReason? unavailableReason;
  bool get isAvailable => snapshot != null;
}

abstract interface class SportFeedRepository {
  SportId get sport;
  Future<SportFeedResult> load(DateTime selectedDate);
}

abstract interface class RefreshableSportFeedRepository
    implements SportFeedRepository {
  Future<SportFeedResult> refresh(DateTime selectedDate);
}

abstract interface class ProgressiveSportFeedRepository
    implements RefreshableSportFeedRepository {
  Future<SportFeedResult> loadRadar(DateTime selectedDate);
  Future<SportFeedResult> loadMatch(DateTime selectedDate, String matchId);
}

abstract interface class PreloadingSportFeedRepository
    implements SportFeedRepository {
  SportFeedResult? peek(DateTime date, {bool radar = false});
  void prefetch(DateTime date);
  void cancelPrefetch();
}

/// One shared boundary for every adapter. Freshness uses the real clock;
/// selecting J+13 does not age a snapshot by thirteen days.
class ValidatedSportFeedRepository
    implements ProgressiveSportFeedRepository, PreloadingSportFeedRepository {
  ValidatedSportFeedRepository({
    required this.delegate,
    required this.policy,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final SportFeedRepository delegate;
  final SportDataPolicy policy;
  final DateTime Function() clock;
  @override
  SportId get sport => delegate.sport;

  @override
  SportFeedResult? peek(DateTime date, {bool radar = false}) {
    final source = delegate;
    if (source is! PreloadingSportFeedRepository) return null;
    final cached = source.peek(date, radar: radar);
    if (cached == null) return null;
    final validated = _validate(cached, date);
    return validated.isAvailable ? validated : null;
  }

  @override
  void cancelPrefetch() {
    final source = delegate;
    if (source is PreloadingSportFeedRepository) source.cancelPrefetch();
  }

  @override
  void prefetch(DateTime date) {
    final source = delegate;
    if (source is PreloadingSportFeedRepository) source.prefetch(date);
  }

  @override
  Future<SportFeedResult> load(DateTime selectedDate) async {
    return _validate(await delegate.load(selectedDate), selectedDate);
  }

  @override
  Future<SportFeedResult> refresh(DateTime selectedDate) async {
    final source = delegate;
    return _validate(
      await (source is RefreshableSportFeedRepository
          ? source.refresh(selectedDate)
          : source.load(selectedDate)),
      selectedDate,
    );
  }

  @override
  Future<SportFeedResult> loadRadar(DateTime selectedDate) async {
    final source = delegate;
    return _validate(
      await (source is ProgressiveSportFeedRepository
          ? source.loadRadar(selectedDate)
          : source.load(selectedDate)),
      selectedDate,
    );
  }

  @override
  Future<SportFeedResult> loadMatch(
    DateTime selectedDate,
    String matchId,
  ) async {
    final source = delegate;
    return _validate(
      await (source is ProgressiveSportFeedRepository
          ? source.loadMatch(selectedDate, matchId)
          : source.load(selectedDate)),
      selectedDate,
    );
  }

  SportFeedResult _validate(SportFeedResult result, DateTime selectedDate) {
    final snapshot = result.snapshot;
    if (snapshot == null) return result;
    if (snapshot.sport != sport ||
        snapshot.items.any((fixture) => fixture.sport != sport)) {
      throw StateError('Adapter returned a publication for another sport.');
    }
    if (!snapshot.covers(selectedDate)) {
      return const SportFeedResult.unavailable(
        SportFeedUnavailableReason.outsideWindow,
      );
    }
    if (clock().toUtc().difference(snapshot.capturedAt.toUtc()) >
        policy.maximumSnapshotAge) {
      return const SportFeedResult.unavailable(
        SportFeedUnavailableReason.stale,
      );
    }
    return result;
  }
}
