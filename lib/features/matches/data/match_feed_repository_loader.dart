import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../domain/match_board_item.dart';
import 'match_feed_repository.dart';
import 'supabase_match_feed_snapshot_repository.dart';

class MatchFeedRepositoryLoader {
  const MatchFeedRepositoryLoader({
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

  Future<MatchFeedRepository> load({DateTime? now}) async {
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
    try {
      final remoteSnapshot = await _loadCurrentRemoteSnapshot(now);
      if (remoteSnapshot != null) {
        final repository = factory.create(
          MatchDataSourceMode.snapshot,
          snapshot: remoteSnapshot,
        );
        final metadata = repository.snapshotMetadata;
        // The selected date can be in the J+1 to J+3 forecast window. Its
        // snapshot is legitimately captured today, so freshness must be
        // evaluated against the real current day, never against the selected
        // future day.
        if (metadata?.covers(now) != true || metadata!.isObsolete(clock())) {
          throw StateError(
            'Le snapshot Supabase reçu est absent, trop ancien ou ne couvre '
            'pas le ${_dateKey(now)}. Aucune donnée ancienne ne sera affichée '
            'à sa place.',
          );
        }
        return repository;
      }
    } on Object catch (error) {
      debugPrint('Remote match feed snapshot unavailable: $error');
      rethrow;
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
    final injectedDataSource = remoteDataSource;
    if (injectedDataSource != null) {
      return injectedDataSource.loadLatestForDate(date);
    }

    final client = supabaseInitializer.client;
    if (client == null) {
      throw StateError('Le client Supabase n’est pas initialisé.');
    }

    final repository = SupabaseMatchFeedSnapshotRepository(client);
    return repository.loadLatestForDate(date);
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
