import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
    this.assetBundle,
    this.factory = const MatchFeedRepositoryFactory(),
  });

  static const localSnapshotAsset =
      'assets/snapshots/focused_match_feed_latest.json';

  final AppConfig config;
  final SupabaseInitializer supabaseInitializer;
  final MatchFeedSnapshotRemoteDataSource? remoteDataSource;
  final AssetBundle? assetBundle;
  final MatchFeedRepositoryFactory factory;

  Future<MatchFeedRepository> load({DateTime? now}) async {
    final source = config.matchFeedSource.trim().toLowerCase();
    final effectiveNow = now ?? DateTime.now();

    return switch (source) {
      'demo' => factory.create(MatchDataSourceMode.demo),
      'snapshot' || 'local' || 'local_snapshot' => _loadLocalSnapshot(),
      'supabase' ||
      'remote' ||
      'api' => _loadRemoteWithLocalFallback(effectiveNow),
      'auto' || '' => _loadAuto(effectiveNow),
      _ => throw StateError(
        'Unknown MATCH_FEED_SOURCE "$source". '
        'Use "auto", "supabase", "snapshot" or "demo".',
      ),
    };
  }

  Future<MatchFeedRepository> _loadAuto(DateTime now) async {
    if (!config.isSupabaseConfigured) {
      return _loadLocalSnapshot();
    }

    return _loadRemoteWithLocalFallback(now);
  }

  Future<MatchFeedRepository> _loadRemoteWithLocalFallback(DateTime now) async {
    try {
      final remoteSnapshot = await _loadRemoteSnapshot(now);
      if (remoteSnapshot != null) {
        return factory.create(
          MatchDataSourceMode.snapshot,
          snapshot: remoteSnapshot,
        );
      }
    } on Object catch (error) {
      debugPrint('Remote match feed snapshot unavailable: $error');
    }

    return _loadLocalSnapshot();
  }

  Future<Map<String, Object?>?> _loadRemoteSnapshot(DateTime now) async {
    final injectedDataSource = remoteDataSource;
    if (injectedDataSource != null) {
      return await injectedDataSource.loadLatestForDate(now) ??
          await injectedDataSource.loadLatest();
    }

    final client = supabaseInitializer.client;
    if (client == null) {
      return null;
    }

    final repository = SupabaseMatchFeedSnapshotRepository(client);
    return await repository.loadLatestForDate(now) ??
        await repository.loadLatest();
  }

  Future<MatchFeedRepository> _loadLocalSnapshot() async {
    final snapshotText = await (assetBundle ?? rootBundle).loadString(
      localSnapshotAsset,
    );
    final snapshotJson = jsonDecode(snapshotText) as Map<String, dynamic>;

    return factory.create(
      MatchDataSourceMode.snapshot,
      snapshot: Map<String, Object?>.from(snapshotJson),
    );
  }
}
