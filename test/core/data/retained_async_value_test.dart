import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:copilot/core/data/retained_async_value.dart';

void main() {
  test('deduplicates in-flight loads and reuses fresh public data', () async {
    var calls = 0;
    final cache = RetainedAsyncValue<int>();
    final completion = Completer<int>();
    Future<int> fetch() {
      calls++;
      return completion.future;
    }

    final first = cache.read(fetch);
    final second = cache.read(fetch);
    completion.complete(7);
    expect(await first, 7);
    expect(await second, 7);
    expect(await cache.read(fetch), 7);
    expect(calls, 1);
  });

  test(
    'temporary failure retains data, then retries and respects absence',
    () async {
      var now = DateTime(2026, 10, 7);
      final cache = RetainedAsyncValue<int?>(clock: () => now);
      expect(await cache.read(() async => 7), 7);
      now = now.add(const Duration(minutes: 3));
      expect(await cache.read(() async => throw StateError('offline')), 7);
      expect(await cache.read(() async => null), isNull);
      expect(await cache.read(() async => 9), isNull);
      now = now.add(const Duration(minutes: 3));
      expect(await cache.read(() async => 9), 9);
    },
  );

  test(
    'first failure stays a failure and independent caches stay isolated',
    () async {
      final first = RetainedAsyncValue<int>();
      final second = RetainedAsyncValue<int>();
      await expectLater(
        first.read(() async => throw StateError('offline')),
        throwsStateError,
      );
      expect(await first.read(() async => 1), 1);
      expect(await second.read(() async => 2), 2);
    },
  );
}
