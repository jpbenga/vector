import '../../../core/data/navigation_feed_cache.dart';
import '../../../core/data/read_recovery.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/retained_async_value.dart';
import '../../../core/data/published_feed_delivery.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../domain/match_board_item.dart';
import 'match_feed_repository.dart';
import 'supabase_match_feed_snapshot_repository.dart';

class MatchFeedRepositoryLoader {
  MatchFeedRepositoryLoader({
    required this.config,
    required this.supabaseInitializer,
    this.remoteDataSource,
    this.factory = const MatchFeedRepositoryFactory(),
    this.clock = DateTime.now,
  });

  final AppConfig config;
  final SupabaseInitializer supabaseInitializer;
  final MatchFeedSnapshotRemoteDataSource? remoteDataSource;
  final MatchFeedRepositoryFactory factory;
  final DateTime Function() clock;

  MatchFeedSnapshotRemoteDataSource? _defaultDataSource;
  final _snapshots = <String, RetainedAsyncValue<Map<String, Object?>?>>{};
  final _parsed = Expando<MatchFeedRepository>();
  late final _navigation = NavigationFeedCache<MatchFeedRepository>(
    clock: clock,
  );
  MatchFeedRepository? _currentRepository;
  DateTime? _currentLoadedAt;

  Future<MatchFeedRepository> load({DateTime? now}) {
    final date = now ?? clock();
    return _navigation.read(
      'day:${_dateKey(date)}',
      () => _loadUncached(now: date),
      isUsable: (repository) => _usable(repository, date),
    );
  }

  bool _usable(MatchFeedRepository repository, DateTime date) {
    if (repository is EmptyMatchFeedRepository) {
      return !repository.temporaryFailure;
    }
    final today = DateTime(clock().year, clock().month, clock().day);
    final at = date.isBefore(today)
        ? DateTime(date.year, date.month, date.day, 23, 59, 59)
        : clock();
    final metadata = repository.snapshotMetadata;
    return metadata == null ||
        (metadata.covers(date) && !metadata.isObsolete(at));
  }

  void cancelPrefetch() => _navigation.cancelPreload();

  void prefetch(DateTime date) {
    if (remoteDataSource != null) return;
    final days = navigationFeedDays(date, clock());
    _navigation.preload([
      for (final day in days)
        () async {
          await _prefetchPublishedDay(day);
        },
      if (days.isNotEmpty)
        () async {
          final source = _defaultDataSource;
          if (source is SupabaseMatchFeedSnapshotRepository) {
            final payload = await source.loadRadar(date);
            if (payload != null) {
              await _navigation.read(
                _radarKey(date),
                () async => _parsed[payload] ??= factory.create(
                  MatchDataSourceMode.snapshot,
                  snapshot: payload,
                ),
                isUsable: (repository) => _usable(repository, date),
                ttl: const Duration(minutes: 10),
              );
            }
          }
        },
    ]);
  }

  Future<void> _prefetchPublishedDay(DateTime day) async {
    final source = _defaultDataSource ??= _publicSource();
    if (source is! SupabaseMatchFeedSnapshotRepository) return;
    final payload = await source.loadPublishedForDate(day);
    if (payload == null) return;
    await _navigation.read(
      'day:${_dateKey(day)}',
      () async => _parsed[payload] ??= factory.create(
        MatchDataSourceMode.snapshot,
        snapshot: payload,
      ),
      isUsable: (repository) => _usable(repository, day),
    );
  }

  Future<MatchFeedRepository> _loadUncached({DateTime? now}) async {
    final source = config.matchFeedSource.trim().toLowerCase();
    final effectiveNow = now ?? DateTime.now();

    return switch (source) {
      'demo' => factory.create(MatchDataSourceMode.demo),
      'supabase' || 'remote' || 'api' => _loadRemoteSnapshot(effectiveNow),
      'auto' || '' => _loadAuto(effectiveNow),
      _ => throw StateError(
        'Unknown MATCH_FEED_SOURCE "$source". '
        'Use "auto", "supabase" or "demo".',
      ),
    };
  }

  Future<MatchFeedRepository> _loadAuto(DateTime now) async {
    if (!config.isSupabaseConfigured) {
      throw StateError(
        'Supabase n’est pas configuré. Aucun snapshot local de secours '
        'n’est chargé.',
      );
    }

    return _loadRemoteSnapshot(now);
  }

  Future<MatchFeedRepository> _loadRemoteSnapshot(DateTime now) async {
    final today = DateTime(clock().year, clock().month, clock().day);
    final retained = _currentRepository;
    if (!now.isBefore(today) &&
        _currentLoadedAt != null &&
        clock().difference(_currentLoadedAt!) < const Duration(minutes: 2) &&
        retained?.snapshotMetadata?.covers(now) == true &&
        !retained!.snapshotMetadata!.isObsolete(clock())) {
      return retained;
    }
    try {
      final remoteSnapshot = await _loadCurrentRemoteSnapshot(now);
      if (remoteSnapshot != null) {
        final repository = _parsed[remoteSnapshot] ??= factory.create(
          MatchDataSourceMode.snapshot,
          snapshot: remoteSnapshot,
        );
        final metadata = repository.snapshotMetadata;
        // The selected date can be in the J+1 to J+13 calendar window. Its
        // snapshot is legitimately captured today, so freshness must be
        // evaluated against the real current day, never against the selected
        // future day.
        if (metadata?.covers(now) != true ||
            metadata!.isObsolete(
              now.isBefore(DateTime(clock().year, clock().month, clock().day))
                  ? DateTime(now.year, now.month, now.day, 23, 59, 59)
                  : clock(),
            )) {
          return EmptyMatchFeedRepository(
            date: now,
            reason:
                'Le snapshot Supabase reçu est absent, trop ancien ou ne couvre '
                'pas le ${_dateKey(now)}. Aucune donnée ancienne ne sera affichée '
                'à sa place.',
          );
        }
        if (!now.isBefore(DateTime(clock().year, clock().month, clock().day))) {
          _currentRepository = repository;
          _currentLoadedAt = clock();
        }
        return repository;
      }
      _currentRepository = null;
    } on Object catch (error) {
      debugPrint('Remote match feed snapshot unavailable: $error');
      final retained = _currentRepository;
      if (!now.isBefore(DateTime(clock().year, clock().month, clock().day)) &&
          retained?.snapshotMetadata?.covers(now) == true &&
          !retained!.snapshotMetadata!.isObsolete(clock())) {
        return retained;
      }
      if (!isTransientReadError(error)) rethrow;
      return EmptyMatchFeedRepository(
        date: now,
        reason: 'Le flux Supabase est momentanément indisponible.',
        temporaryFailure: true,
      );
    }

    return EmptyMatchFeedRepository(
      date: now,
      reason:
          'Supabase n’a publié aucun snapshot couvrant le ${_dateKey(now)}.',
    );
  }

  Future<Map<String, Object?>?> _loadCurrentRemoteSnapshot(
    DateTime date,
  ) async {
    final key = _dateKey(date);
    final cached =
        _snapshots.remove(key) ??
        RetainedAsyncValue<Map<String, Object?>?>(clock: clock);
    _snapshots[key] = cached;
    while (_snapshots.length > 24) {
      _snapshots.remove(_snapshots.keys.first);
    }
    final source = remoteDataSource ?? (_defaultDataSource ??= _publicSource());
    return cached.read(() => source.loadLatestForDate(date));
  }

  Future<MatchFeedRepository?> loadDetails(
    DateTime date,
    String matchId,
  ) async {
    final source = _defaultDataSource;
    if (source is! SupabaseMatchFeedSnapshotRepository) return null;
    final payload = await source.loadDetails(date, matchId);
    return payload == null
        ? null
        : factory.create(MatchDataSourceMode.snapshot, snapshot: payload);
  }

  Future<MatchFeedRepository> loadRadar(DateTime date) => _navigation.read(
    _radarKey(date),
    () => _loadRadarUncached(date),
    isUsable: (repository) => _usable(repository, date),
    ttl: const Duration(minutes: 10),
  );

  String _radarKey(DateTime date) =>
      date.isBefore(DateTime(clock().year, clock().month, clock().day))
      ? 'radar:${_dateKey(date)}'
      : 'radar:current';

  Future<MatchFeedRepository> _loadRadarUncached(DateTime date) async {
    final source = remoteDataSource ?? (_defaultDataSource ??= _publicSource());
    if (source is SupabaseMatchFeedSnapshotRepository) {
      await source.loadLatestForDate(date);
    }
    final payload = source is SupabaseMatchFeedSnapshotRepository
        ? await source.loadRadar(date)
        : null;
    return payload == null
        ? load(now: date)
        : (_parsed[payload] ??= factory.create(
            MatchDataSourceMode.snapshot,
            snapshot: payload,
          ));
  }

  MatchFeedSnapshotRemoteDataSource _publicSource() {
    if (supabaseInitializer.client == null) {
      throw StateError('Le client Supabase n’est pas initialisé.');
    }
    // Public publications must not depend on the signed-in account JWT.
    return SupabaseMatchFeedSnapshotRepository(
      SupabaseClient(config.supabaseUrl.toString(), config.supabaseAnonKey!),
      delivery: PublishedFeedDelivery(
        projectUrl: config.supabaseUrl!,
        publicKey: config.supabaseAnonKey!,
        hostedBaseUrl: config.feedDeliveryBaseUrl,
      ),
    );
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
