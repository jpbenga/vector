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

/// One shared boundary for every adapter. Freshness uses the real clock;
/// selecting J+13 does not age a snapshot by thirteen days.
class ValidatedSportFeedRepository implements SportFeedRepository {
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
  Future<SportFeedResult> load(DateTime selectedDate) async {
    final result = await delegate.load(selectedDate);
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
