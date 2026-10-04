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

  @override
  Future<List<LiveMatchState>> load(Set<int> fixtureIds) async {
    final ids = fixtureIds.toList();
    final result = <LiveMatchState>[];
    for (var offset = 0; offset < ids.length; offset += 500) {
      final rows = await client.rpc<List<dynamic>>(
        'match_live_for_fixtures',
        params: {
          'p_ids': ids.sublist(offset, (offset + 500).clamp(0, ids.length)),
        },
      );
      result.addAll(
        rows.whereType<Map<String, dynamic>>().map(LiveMatchState.fromJson),
      );
    }
    return result;
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
            onState(LiveMatchState.fromJson(payload.newRecord));
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
