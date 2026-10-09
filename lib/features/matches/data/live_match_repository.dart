import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/live_match_state.dart';

abstract interface class LiveMatchRepository {
  Future<List<LiveMatchState>> load(Set<int> fixtureIds);
  void subscribe(
    Set<int> fixtureIds,
    void Function(LiveMatchState) onState,
    void Function() onReconnect,
  );
  Future<void> unsubscribe();
}

/// One channel and one batched initial read for all mounted match cards.
class SupabaseLiveMatchRepository implements LiveMatchRepository {
  SupabaseLiveMatchRepository(this.client);
  final SupabaseClient client;
  RealtimeChannel? _channel;
  String? _selection;
  int _generation = 0;
  final Map<int, Map<String, dynamic>> _radar = {};

  @override
  Future<List<LiveMatchState>> load(Set<int> fixtureIds) async {
    final ids = fixtureIds.toList();
    final result = <LiveMatchState>[];
    for (var offset = 0; offset < ids.length; offset += 500) {
      final chunk = ids.sublist(offset, (offset + 500).clamp(0, ids.length));
      final radarFuture = _loadRadar(chunk);
      final rows = await client.rpc<List<dynamic>>(
        'match_live_for_fixtures',
        params: {
          'p_ids': ids.sublist(offset, (offset + 500).clamp(0, ids.length)),
        },
      );
      await radarFuture;
      result.addAll(
        rows.whereType<Map<String, dynamic>>().map(
          (row) => LiveMatchState.fromJson({
            ...row,
            'radar_snapshot': _radar[(row['fixture_id'] as num).toInt()],
          }),
        ),
      );
    }
    return result;
  }

  Future<void> _loadRadar(List<int> ids) async {
    try {
      final snapshots = await client
          .rpc<List<dynamic>>(
            'form_radar_for_fixtures',
            params: {
              'p_sport': 'football',
              'p_ids': ids.map((id) => '$id').toList(),
            },
          )
          .timeout(const Duration(seconds: 2));
      for (final raw in snapshots.whereType<Map<String, dynamic>>()) {
        final id = int.tryParse('${raw['fixtureId']}');
        if (id != null && ids.contains(id)) _radar[id] = raw;
      }
    } on Object {
      /* Optional Radar must not interrupt score delivery. */
    }
  }

  @override
  void subscribe(
    Set<int> fixtureIds,
    void Function(LiveMatchState) onState,
    void Function() onReconnect,
  ) {
    final ids = fixtureIds.toList()..sort();
    final selection = ids.join(',');
    if (_selection == selection) return;
    _selection = selection;
    final old = _channel;
    if (old != null) unawaited(client.removeChannel(old));
    final channel = client.channel('lector-live-scores-${++_generation}');
    _channel = channel;
    // Supabase limits IN filters to 100 values. All filters share one socket;
    // viewers receive updates only for the cards they actually opened.
    for (var offset = 0; offset < ids.length; offset += 100) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'match_live_states',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.inFilter,
          column: 'fixture_id',
          value: ids.sublist(offset, (offset + 100).clamp(0, ids.length)),
        ),
        callback: (payload) {
          if (payload.newRecord['fixture_id'] is num) {
            onState(
              LiveMatchState.fromJson({
                ...payload.newRecord,
                'radar_snapshot':
                    _radar[(payload.newRecord['fixture_id'] as num).toInt()],
              }),
            );
          }
        },
      );
    }
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) onReconnect();
    });
  }

  @override
  Future<void> unsubscribe() async {
    final channel = _channel;
    _channel = null;
    _selection = null;
    if (channel != null) await client.removeChannel(channel);
  }
}
