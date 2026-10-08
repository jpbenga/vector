import 'dart:async';
import 'package:copilot/core/data/read_recovery.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('temporary reads recover sequentially with progressive pauses', (
    tester,
  ) async {
    final recovery = ReadRecovery();
    var calls = 0;
    final result = recovery.read(() async {
      calls++;
      if (calls < 3) throw TimeoutException('transport');
      return 42;
    });
    await tester.pump();
    expect(calls, 1);
    expect(recovery.recovering, isTrue);
    await tester.pump(const Duration(milliseconds: 999));
    expect(calls, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 2));
    expect(await result, 42);
    expect(calls, 3);
    expect(recovery.exhausted, isFalse);
    recovery.dispose();
  });
  testWidgets(
    'ten failures end recovery; an empty successful response does not retry',
    (tester) async {
      final recovery = ReadRecovery();
      var calls = 0;
      final failure = recovery.read<int>(() async {
        calls++;
        throw TimeoutException('offline');
      });
      final checked = expectLater(failure, throwsA(isA<TimeoutException>()));
      await tester.pump();
      for (var i = 0; i < 9; i++) {
        await tester.pump(const Duration(seconds: 10));
      }
      await checked;
      expect(calls, 10);
      expect(recovery.exhausted, isTrue);
      await tester.pump(const Duration(minutes: 5));
      expect(calls, 10);
      expect(await recovery.read(() async => <String>[]), isEmpty);
      expect(recovery.exhausted, isFalse);
      recovery.dispose();
    },
  );
  testWidgets(
    'changing date cancels pending retries and ignores old responses',
    (tester) async {
      final recovery = ReadRecovery();
      final old = Completer<String>();
      final request = recovery.read(() => old.future);
      final cancelled = expectLater(request, throwsA(isA<ReadCancelled>()));
      expect(await recovery.read(() async => 'new day'), 'new day');
      await cancelled;
      old.completeError(TimeoutException('late old day'));
      await tester.pump(const Duration(minutes: 4));
      expect(recovery.exhausted, isFalse);
      expect(recovery.inProgress, isFalse);
      recovery.dispose();
    },
  );
  testWidgets('cache hits stay synchronous and invalid data fails once', (
    tester,
  ) async {
    final recovery = ReadRecovery();
    var delivered = false;
    recovery.read(() => SynchronousFuture(7)).then((value) => delivered = true);
    expect(delivered, isTrue);
    var calls = 0;
    await expectLater(
      recovery.read<int>(() async {
        calls++;
        throw const FormatException('invalid sport');
      }),
      throwsA(isA<FormatException>()),
    );
    expect(calls, 1);
    expect(recovery.exhausted, isFalse);
    recovery.dispose();
  });
  testWidgets('deadline ends a hung read and disposal cancels its timers', (
    tester,
  ) async {
    final recovery = ReadRecovery(maximumDuration: const Duration(seconds: 4));
    final pending = Completer<int>();
    final request = recovery.read(() => pending.future);
    final checked = expectLater(request, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 4));
    await checked;
    expect(recovery.exhausted, isTrue);
    expect(recovery.inProgress, isFalse);
    pending.complete(1);
    await tester.pump();
    expect(recovery.exhausted, isTrue);
    recovery.dispose();
  });
  testWidgets('returning to foreground resumes an exhausted read once', (
    tester,
  ) async {
    var resumes = 0;
    final recovery = ReadRecovery(
      maximumAttempts: 1,
      onConnectionReturn: () {
        resumes++;
      },
    );
    await expectLater(
      recovery.read<int>(() async => throw TimeoutException('offline')),
      throwsA(isA<TimeoutException>()),
    );
    recovery.setActive(false);
    recovery.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resumes, 0);
    recovery.setActive(true);
    await tester.pump();
    expect(resumes, 1);
    recovery.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resumes, 1);
    recovery.dispose();
  });
  testWidgets(
    'authoritative unavailable results are retried only when explicitly temporary',
    (tester) async {
      final recovery = ReadRecovery();
      var calls = 0;
      final result = recovery.read(
        () async => ++calls < 3 ? 'temporary' : 'available',
        retryValue: (v) => v == 'temporary',
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(await result, 'available');
      expect(calls, 3);
      recovery.dispose();
    },
  );
}
