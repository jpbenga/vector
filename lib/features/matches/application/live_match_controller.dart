import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/live_match_repository.dart';
import '../domain/live_match_state.dart';

/// Mounted cards share their subscription. Recover by reading persisted scores
/// after reconnect/resume; realtime delivery is never assumed to be lossless.
class LiveMatchController with WidgetsBindingObserver {
  LiveMatchController(
    this.repository, {
    this.refreshInterval = const Duration(minutes: 1),
    this.observeLifecycle = true,
  });
  final LiveMatchRepository repository;
  final Duration refreshInterval;
  final bool observeLifecycle;
  final Map<int, ValueNotifier<LiveMatchState?>> _values = {};
  final Map<int, int> _references = {};
  Timer? _timer;
  Timer? _debounce;
  bool _active = false;
  bool _foreground = true;
  bool _observing = false;
  bool _loading = false;
  bool _loadAgain = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _closing = Future.value();

  ValueListenable<LiveMatchState?> watch(int id) {
    _references[id] = (_references[id] ?? 0) + 1;
    final value = _values.putIfAbsent(id, () => ValueNotifier(null));
    if (!_active) _start();
    _queueRead();
    return value;
  }

  void unwatch(int id) {
    final remaining = (_references[id] ?? 0) - 1;
    if (remaining > 0) {
      _references[id] = remaining;
      return;
    }
    _references.remove(id);
    if (_references.isEmpty) _stop();
  }

  void _queueRead() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 100),
      () => unawaited(refresh()),
    );
  }

  void _start() {
    if (_disposed || _active || !_foreground) return;
    _active = true;
    final generation = ++_generation;
    if (observeLifecycle && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
    unawaited(
      _closing.then((_) {
        if (_disposed || !_active || generation != _generation) return;
        repository.subscribe(_references.keys.toSet(), _accept, _queueRead);
      }),
    );
  }

  void _accept(LiveMatchState incoming) {
    if (!_active || !_references.containsKey(incoming.fixtureId)) return;
    final value = _values[incoming.fixtureId]!;
    final old = value.value;
    if (old?.capturedAt != null &&
        (incoming.capturedAt == null ||
            incoming.capturedAt!.isBefore(old!.capturedAt!))) {
      return;
    }
    if (old?.isFinal == true && !incoming.isFinal) return;
    value.value = incoming;
  }

  Future<void> refresh() async {
    if (!_active || _disposed || _references.isEmpty) return;
    if (_loading) {
      _loadAgain = true;
      return;
    }
    _loading = true;
    final generation = _generation;
    final ids = _references.keys.toSet();
    try {
      await _closing;
      if (!_active || generation != _generation) return;
      repository.subscribe(ids, _accept, _queueRead);
      final rows = await repository.load(ids);
      if (generation != _generation) return;
      for (final row in rows) {
        _accept(row);
      }
      // Missing rows and network failures retain the last known score. Its
      // timestamp makes stale data visible without blocking the application.
    } on Object catch (error) {
      debugPrint('Actualisation des scores indisponible : $error');
    } finally {
      _loading = false;
      if (_loadAgain) {
        _loadAgain = false;
        _queueRead();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (_references.isNotEmpty) {
        _start();
        _queueRead();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _stop(removeObserver: false);
    }
  }

  void _stop({bool removeObserver = true}) {
    _active = false;
    _generation++;
    _timer?.cancel();
    _debounce?.cancel();
    if (_observing && removeObserver) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _closing = repository.unsubscribe();
  }

  Future<void> dispose() async {
    _disposed = true;
    _stop();
    await _closing;
    for (final value in _values.values) {
      value.dispose();
    }
    _values.clear();
    _references.clear();
  }
}
