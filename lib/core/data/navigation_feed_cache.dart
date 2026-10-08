import 'dart:async';
import 'package:flutter/foundation.dart';

/// Retains decoded public feeds. Warm navigation never waits for revalidation.
/// Preferences are applied by the screen, never stored in this cache.
class NavigationFeedCache<T> {
  NavigationFeedCache({this.capacity = 24, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final int capacity;
  final DateTime Function() clock;
  final _values = <String, T>{};
  final _checked = <String, DateTime>{};
  final _pending = <String, Future<T>>{};
  int _preloadGeneration = 0;
  Timer? _preloadTimer;
  Completer<void>? _preloadWait;

  void cancelPreload() {
    _preloadGeneration++;
    _preloadTimer?.cancel();
    final waiting = _preloadWait;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  Future<void> _pause(Duration duration) {
    final wait = Completer<void>();
    _preloadWait = wait;
    _preloadTimer = Timer(duration, () {
      if (!wait.isCompleted) wait.complete();
    });
    return wait.future;
  }

  T? peek(String key) => _values[key];
  void invalidate(String key) => _checked.remove(key);

  Future<T> read(
    String key,
    Future<T> Function() fetch, {
    bool force = false,
    bool Function(T)? isUsable,
    Duration ttl = const Duration(minutes: 2),
  }) {
    final value = _values.remove(key);
    if (value != null && (isUsable?.call(value) ?? true)) {
      _values[key] = value;
      if (!force) {
        final checked = _checked[key];
        if (checked == null || clock().difference(checked) >= ttl) {
          unawaited(
            _fetch(key, fetch).then<void>((_) {}, onError: (Object _) {}),
          );
        }
        return SynchronousFuture(value);
      }
    }
    return _fetch(key, fetch);
  }

  Future<T> _fetch(String key, Future<T> Function() fetch) {
    return _pending[key] ??= Future<T>.sync(fetch)
        .then((value) {
          _values.remove(key);
          _values[key] = value;
          _checked[key] = clock();
          while (_values.length > capacity) {
            final oldest = _values.keys.first;
            _values.remove(oldest);
            _checked.remove(oldest);
          }
          return value;
        })
        .whenComplete(() {
          _pending.remove(key);
        });
  }

  /// One bounded queue per sport; changing the date reprioritises nearby days.
  void preload(List<Future<void> Function()> tasks) {
    cancelPreload();
    final generation = _preloadGeneration;
    unawaited(() async {
      await _pause(const Duration(milliseconds: 600));
      for (final task in tasks) {
        if (generation != _preloadGeneration) return;
        try {
          await task();
        } catch (_) {
          /* Foreground has its own retry UI. */
        }
        if (generation != _preloadGeneration) return;
        await _pause(const Duration(milliseconds: 40));
      }
    }());
  }
}

/// Local calendar arithmetic stays correct across daylight-saving boundaries.
List<DateTime> navigationFeedDays(DateTime selected, DateTime now) {
  final earliest = DateTime(now.year, now.month, now.day - 7);
  final latest = DateTime(now.year, now.month, now.day + 13);
  final anchor = DateTime(selected.year, selected.month, selected.day);
  if (anchor.isBefore(earliest) || anchor.isAfter(latest)) return const [];
  return [
    // Nearby past days are as useful as future ones. Cover the whole window
    // from any anchor, rather than making archives wait behind J+13 and Radar.
    for (final offset in [
      for (var distance = 1; distance <= 20; distance++) ...[
        distance,
        -distance,
      ],
    ])
      if (!DateTime(
            selected.year,
            selected.month,
            selected.day + offset,
          ).isBefore(earliest) &&
          !DateTime(
            selected.year,
            selected.month,
            selected.day + offset,
          ).isAfter(latest))
        DateTime(selected.year, selected.month, selected.day + offset),
  ];
}
