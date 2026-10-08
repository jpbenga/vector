import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'read_recovery_signals.dart';

/// Only for idempotent reads. One foreground request and one retry timer per
/// owner; changing scope cancels its retries and ignores its late responses.
class ReadRecovery extends ChangeNotifier with WidgetsBindingObserver {
  ReadRecovery({
    this.onConnectionReturn,
    this.maximumAttempts = 10,
    this.maximumDuration = const Duration(minutes: 3),
    this.delays = const [1, 2, 3, 5, 8, 10, 10, 10, 10],
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
    _stopConnectionListener = listenForConnectionReturn(_resume);
  }
  final VoidCallback? onConnectionReturn;
  final int maximumAttempts;
  final Duration maximumDuration;
  final List<int> delays;
  final DateTime Function() clock;
  late final VoidCallback _stopConnectionListener;
  Timer? _timer;
  Timer? _deadline;
  VoidCallback? _cancelPending;
  Completer<bool>? _pause;
  int _generation = 0;
  int attempt = 0;
  bool inProgress = false;
  bool exhausted = false;
  bool _disposed = false;
  bool _active = true;
  bool _foreground = true;
  DateTime? _lastResume;
  bool get recovering => inProgress && (attempt > 1 || _pause != null);

  Future<T> read<T>(
    Future<T> Function() fetch, {
    bool Function(T)? retryValue,
  }) {
    cancel();
    final generation = _generation;
    final startedAt = clock();
    exhausted = false;
    inProgress = true;
    attempt = 1;
    _notify();
    bool current() => !_disposed && generation == _generation;
    bool retryAllowed() =>
        attempt < maximumAttempts &&
        clock().difference(startedAt) < maximumDuration;
    late Future<T> Function() retry;
    Future<T> run() {
      if (!current()) return Future.error(const ReadCancelled());
      return Future<T>.sync(fetch).then(
        (value) {
          if (!current()) throw const ReadCancelled();
          if (retryValue?.call(value) == true) {
            if (retryAllowed()) return retry();
            exhausted = true;
          }
          inProgress = false;
          _notify();
          return value;
        },
        onError: (Object error, StackTrace stack) {
          if (!current()) throw const ReadCancelled();
          final transient = isTransientReadError(error);
          if (transient && retryAllowed()) return retry();
          exhausted = transient;
          inProgress = false;
          _notify();
          Error.throwWithStackTrace(error, stack);
        },
      );
    }

    retry = () async {
      final pause = Completer<bool>();
      _pause = pause;
      _notify();
      final delay = delays.isEmpty
          ? 1
          : delays[(attempt - 1).clamp(0, delays.length - 1)];
      _timer = Timer(Duration(seconds: delay), () => pause.complete(true));
      if (!await pause.future || !current()) throw const ReadCancelled();
      _pause = null;
      _timer = null;
      if (clock().difference(startedAt) >= maximumDuration) {
        exhausted = true;
        inProgress = false;
        _notify();
        throw TimeoutException('Read recovery time limit reached');
      }
      attempt++;
      _notify();
      return run();
    };
    final result = run();
    if (result is SynchronousFuture<T>) return result;
    final completed = Completer<T>();
    _cancelPending = () {
      if (!completed.isCompleted) {
        completed.completeError(const ReadCancelled());
      }
    };
    _deadline = Timer(maximumDuration, () {
      if (!current() || completed.isCompleted) return;
      completed.completeError(
        TimeoutException('Read recovery time limit reached'),
      );
      _cancelPending = null;
      cancel();
      exhausted = true;
      _notify();
    });
    result.then(
      (value) {
        if (completed.isCompleted) return;
        if (current()) {
          _deadline?.cancel();
          _deadline = null;
          _cancelPending = null;
        }
        completed.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (completed.isCompleted) return;
        if (current()) {
          _deadline?.cancel();
          _deadline = null;
          _cancelPending = null;
        }
        completed.completeError(error, stack);
      },
    );
    return completed.future;
  }

  void _notify() {
    // Synchronous cache hits must not setState inside their parent's build.
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  void cancel() {
    _generation++;
    _deadline?.cancel();
    _deadline = null;
    final cancelPending = _cancelPending;
    _cancelPending = null;
    cancelPending?.call();
    _timer?.cancel();
    _timer = null;
    final pause = _pause;
    _pause = null;
    if (pause != null && !pause.isCompleted) pause.complete(false);
    inProgress = false;
  }

  void _resume() {
    if (_disposed || !_active || !_foreground || inProgress || !exhausted) {
      return;
    }
    final now = clock();
    if (_lastResume != null &&
        now.difference(_lastResume!) < const Duration(seconds: 5)) {
      return;
    }
    _lastResume = now;
    exhausted = false;
    onConnectionReturn?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _resume();
    } else {
      _suspend();
    }
  }

  void setActive(bool active) {
    _active = active;
    if (active) {
      scheduleMicrotask(_resume);
    } else {
      _suspend();
    }
  }

  void _suspend() {
    if (!inProgress) return;
    cancel();
    exhausted = true;
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    _stopConnectionListener();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class ReadCancelled implements Exception {
  const ReadCancelled();
}

bool isTransientReadError(Object error) {
  if (error is ReadCancelled ||
      error is FormatException ||
      error is ArgumentError ||
      error is AuthException) {
    return false;
  }
  if (error is TimeoutException || error is http.ClientException) return true;
  if (error is PostgrestException) {
    return const {
      '408',
      '429',
      '500',
      '502',
      '503',
      '504',
      '57014',
      '53300',
      '08000',
      '08003',
      '08006',
      'PGRST000',
      'PGRST001',
      'PGRST002',
      'PGRST003',
    }.contains(error.code);
  }
  if (error is StateError) {
    return RegExp(
      r'\b(408|429|500|502|503|504)\b|timeout|timed out',
      caseSensitive: false,
    ).hasMatch(error.message.toString());
  }
  // Platform transport exceptions (e.g. SocketException) implement Exception.
  return error is Exception;
}
