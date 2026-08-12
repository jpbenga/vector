import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class MatchFeedSnapshotRemoteDataSource {
  Future<Map<String, Object?>?> loadLatestForDate(DateTime date);

  Future<Map<String, Object?>?> loadLatest();
}

class SupabaseMatchFeedSnapshotRepository
    implements MatchFeedSnapshotRemoteDataSource {
  const SupabaseMatchFeedSnapshotRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, Object?>?> loadLatestForDate(DateTime date) async {
    final day = _dateOnly(date).toIso8601String().split('T').first;
    final row = await _client
        .from('match_feed_snapshots')
        .select('id,payload,as_of,window_start,window_end,snapshot_created_at')
        .lte('window_start', day)
        .gte('window_end', day)
        .order('as_of', ascending: false)
        .limit(1)
        .maybeSingle();

    return _payloadFromRow(row);
  }

  @override
  Future<Map<String, Object?>?> loadLatest() async {
    final row = await _client
        .from('match_feed_snapshots')
        .select('id,payload,as_of,window_start,window_end,snapshot_created_at')
        .order('as_of', ascending: false)
        .limit(1)
        .maybeSingle();

    return _payloadFromRow(row);
  }
}

Map<String, Object?>? _payloadFromRow(Map<String, dynamic>? row) {
  final payload = row?['payload'];
  if (payload is Map<String, Object?>) {
    return payload;
  }
  if (payload is Map) {
    return {
      for (final entry in payload.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
  return null;
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
