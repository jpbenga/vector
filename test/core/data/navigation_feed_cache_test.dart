import 'dart:async';
import 'package:copilot/core/data/navigation_feed_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'preloading warms the next day and cancellation stops remaining work',
    (tester) async {
      final cache = NavigationFeedCache<int>();
      var secondCalls = 0;
      cache.preload([
        () async {
          await cache.read('next', () async => 7);
        },
        () async {
          secondCalls++;
          await cache.read('later', () async => 8);
        },
      ]);
      await tester.pump(const Duration(milliseconds: 600));
      expect(cache.peek('next'), 7);
      cache.cancelPreload();
      await tester.pump(const Duration(seconds: 1));
      expect(secondCalls, 0);
    },
  );

  test('preloading stays in the collected calendar window', () {
    final days = navigationFeedDays(
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 7),
    );
    expect(days.map((d) => d.day), [19, 18, 17]);
    expect(
      navigationFeedDays(DateTime(2026, 10, 21), DateTime(2026, 10, 7)),
      isEmpty,
    );
  });

  test(
    'warm navigation is synchronous while expired data revalidates silently',
    () async {
      var now = DateTime(2026, 10, 7);
      final cache = NavigationFeedCache<int>(clock: () => now);
      expect(await cache.read('day:1', () async => 7), 7);
      now = now.add(const Duration(minutes: 3));
      final refresh = Completer<int>();
      final warm = cache.read('day:1', () => refresh.future);
      expect(warm, isA<SynchronousFuture<int>>());
      var immediate = false;
      warm.then((value) {
        expect(value, 7);
        immediate = true;
      });
      expect(immediate, isTrue);
      refresh.complete(8);
      await Future<void>.delayed(Duration.zero);
      expect(cache.peek('day:1'), 8);
    },
  );
  test(
    'one request per key, bounded cache and failed refresh retains content',
    () async {
      var now = DateTime(2026, 10, 7);
      final cache = NavigationFeedCache<int>(capacity: 2, clock: () => now);
      var calls = 0;
      final pending = Completer<int>();
      Future<int> fetch() {
        calls++;
        return pending.future;
      }

      final first = cache.read('a', fetch), second = cache.read('a', fetch);
      pending.complete(1);
      await first;
      await second;
      expect(calls, 1);
      now = now.add(const Duration(minutes: 3));
      expect(await cache.read('a', () async => throw StateError('offline')), 1);
      await Future<void>.delayed(Duration.zero);
      expect(cache.peek('a'), 1);
      await cache.read('b', () async => 2);
      await cache.read('c', () async => 3);
      expect(cache.peek('a'), isNull);
      expect(await cache.read('c', () async => 4, isUsable: (_) => false), 4);
    },
  );
}
