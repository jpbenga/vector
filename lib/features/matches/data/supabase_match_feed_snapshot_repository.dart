import 'dart:convert';

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
    final rows = await _client
        .from('match_feed_snapshots')
        .select('id,payload,as_of,window_start,window_end,snapshot_created_at')
        .lte('window_start', day)
        .gte('window_end', day)
        .order('as_of', ascending: false)
        .limit(100);

    return mergeMatchFeedSnapshotRows(rows);
  }

  @override
  Future<Map<String, Object?>?> loadLatest() async {
    final rows = await _client
        .from('match_feed_snapshots')
        .select('id,payload,as_of,window_start,window_end,snapshot_created_at')
        .order('as_of', ascending: false)
        .limit(100);

    return mergeMatchFeedSnapshotRows(rows);
  }
}

Map<String, Object?>? mergeMatchFeedSnapshotRows(Iterable<Object?> rows) {
  final payloads = rows
      .map(_payloadFromRow)
      .whereType<Map<String, Object?>>()
      .toList(growable: false);
  return mergeMatchFeedSnapshotPayloads(payloads);
}

Map<String, Object?>? mergeMatchFeedSnapshotPayloads(
  Iterable<Map<String, Object?>> payloads,
) {
  final candidates = payloads.toList(growable: false);
  if (candidates.isEmpty) {
    return null;
  }

  final selected = <_SnapshotSelection>[];
  final coveredLeagueIds = <int>{};

  for (final payload in candidates) {
    final payloadLeagueIds = _leagueIdsForPayload(payload);
    if (payloadLeagueIds.isEmpty) {
      if (selected.isEmpty) {
        selected.add(
          _SnapshotSelection(
            payload: payload,
            acceptedLeagueIds: const {},
            payloadLeagueIds: const {},
          ),
        );
      }
      continue;
    }

    final acceptedLeagueIds = payloadLeagueIds.difference(coveredLeagueIds);
    if (acceptedLeagueIds.isEmpty) {
      continue;
    }

    selected.add(
      _SnapshotSelection(
        payload: payload,
        acceptedLeagueIds: acceptedLeagueIds,
        payloadLeagueIds: payloadLeagueIds,
      ),
    );
    coveredLeagueIds.addAll(acceptedLeagueIds);
  }

  if (selected.isEmpty) {
    return null;
  }

  final firstPayload = selected.first.payload;
  final mergedRaw = <String, Object?>{};
  for (final key in const [
    'fixtures',
    'odds',
    'standings',
    'team_statistics',
    'recent_league_matches',
    'expected_goals',
    'predictions',
  ]) {
    mergedRaw[key] = _mergeRawEntries(key, selected);
  }

  return {
    'schema_version': firstPayload['schema_version'] ?? 1,
    'source': firstPayload['source'] ?? 'api-football',
    'captured_at':
        _maxString(selected.map((item) => item.payload['captured_at'])) ??
        firstPayload['captured_at'],
    'timezone': firstPayload['timezone'] ?? 'Europe/Paris',
    'window_start':
        _minString(selected.map((item) => item.payload['window_start'])) ??
        firstPayload['window_start'],
    'window_end':
        _maxString(selected.map((item) => item.payload['window_end'])) ??
        firstPayload['window_end'],
    'date_window': _mergedDateWindow(selected),
    'season_by_league': _mergedSeasonByLeague(selected),
    'bookmaker_priority': _firstListValue(
      selected.map((item) => item.payload['bookmaker_priority']),
    ),
    'raw': mergedRaw,
  };
}

Map<String, Object?>? _payloadFromRow(Object? row) {
  if (row is! Map) {
    return null;
  }
  final payload = row['payload'];
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

List<Object?> _mergeRawEntries(String key, List<_SnapshotSelection> selected) {
  final entries = <Object?>[];
  final seen = <String>{};

  for (final selection in selected) {
    final raw = _objectMap(selection.payload['raw']);
    final rawEntries = _objectList(raw?[key]);
    for (final entry in rawEntries) {
      if (!_shouldIncludeEntry(key, entry, selection)) {
        continue;
      }
      final uniqueKey = _rawEntryKey(key, entry);
      if (seen.add(uniqueKey)) {
        entries.add(entry);
      }
    }
  }

  return entries;
}

bool _shouldIncludeEntry(
  String key,
  Object? entry,
  _SnapshotSelection selection,
) {
  if (selection.acceptedLeagueIds.isEmpty) {
    return true;
  }
  final leagueId = _leagueIdFromRawEntry(key, entry);
  if (leagueId != null) {
    return selection.acceptedLeagueIds.contains(leagueId);
  }
  return selection.payloadLeagueIds
      .difference(selection.acceptedLeagueIds)
      .isEmpty;
}

String _rawEntryKey(String key, Object? entry) {
  final map = _objectMap(entry);
  if (map == null) {
    return '$key:${jsonEncode(entry)}';
  }

  final leagueId = _leagueIdFromRawEntry(key, entry);
  final fixtureId = _nestedNumber(map, const ['fixture', 'id']);
  final teamId = _nestedNumber(map, const ['team', 'id']);

  if (key == 'fixtures' && fixtureId != null) {
    return '$key:$fixtureId';
  }
  if (key == 'odds' && fixtureId != null) {
    return '$key:${leagueId ?? 'unknown'}:$fixtureId';
  }
  if (key == 'standings' && leagueId != null) {
    return '$key:$leagueId';
  }
  if (key == 'team_statistics' && leagueId != null && teamId != null) {
    return '$key:$leagueId:$teamId';
  }
  if (key == 'recent_league_matches' && leagueId != null && teamId != null) {
    return '$key:$leagueId:$teamId';
  }
  if (key == 'expected_goals' && teamId != null) {
    return '$key:${leagueId ?? 'unknown'}:$teamId';
  }

  return '$key:${jsonEncode(entry)}';
}

Set<int> _leagueIdsForPayload(Map<String, Object?> payload) {
  final ids = <int>{};
  final seasonByLeague = _objectMap(payload['season_by_league']);
  if (seasonByLeague != null) {
    for (final key in seasonByLeague.keys) {
      final parsed = int.tryParse(key);
      if (parsed != null) {
        ids.add(parsed);
      }
    }
  }

  final raw = _objectMap(payload['raw']);
  if (raw == null) {
    return ids;
  }

  for (final key in const [
    'fixtures',
    'odds',
    'standings',
    'team_statistics',
    'recent_league_matches',
  ]) {
    for (final entry in _objectList(raw[key])) {
      final leagueId = _leagueIdFromRawEntry(key, entry);
      if (leagueId != null) {
        ids.add(leagueId);
      }
    }
  }

  return ids;
}

int? _leagueIdFromRawEntry(String key, Object? entry) {
  final map = _objectMap(entry);
  if (map == null) {
    return null;
  }
  if (key == 'expected_goals') {
    return _numberValue(map['league_id']) ??
        _nestedNumber(map, const ['league', 'id']);
  }
  return _nestedNumber(map, const ['league', 'id']) ??
      _numberValue(map['league_id']);
}

Map<String, Object?> _mergedSeasonByLeague(List<_SnapshotSelection> selected) {
  final result = <String, Object?>{};
  for (final selection in selected.reversed) {
    final value = _objectMap(selection.payload['season_by_league']);
    if (value != null) {
      result.addAll(value);
    }
  }
  return result;
}

List<Object?> _mergedDateWindow(List<_SnapshotSelection> selected) {
  final values = <String>{};
  for (final selection in selected) {
    for (final value in _objectList(selection.payload['date_window'])) {
      if (value is String) {
        values.add(value);
      }
    }
  }
  final sorted = values.toList()..sort();
  return sorted;
}

List<Object?> _firstListValue(Iterable<Object?> values) {
  for (final value in values) {
    final list = _objectList(value);
    if (list.isNotEmpty) {
      return list;
    }
  }
  return const [];
}

String? _minString(Iterable<Object?> values) {
  final strings = values.whereType<String>().toList();
  if (strings.isEmpty) {
    return null;
  }
  strings.sort();
  return strings.first;
}

String? _maxString(Iterable<Object?> values) {
  final strings = values.whereType<String>().toList();
  if (strings.isEmpty) {
    return null;
  }
  strings.sort();
  return strings.last;
}

Map<String, Object?>? _objectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
  return null;
}

List<Object?> _objectList(Object? value) {
  if (value is List<Object?>) {
    return value;
  }
  if (value is List) {
    return value.cast<Object?>();
  }
  return const [];
}

int? _nestedNumber(Map<String, Object?> map, List<String> path) {
  Object? current = map;
  for (final segment in path) {
    final currentMap = _objectMap(current);
    if (currentMap == null) {
      return null;
    }
    current = currentMap[segment];
  }
  return _numberValue(current);
}

int? _numberValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class _SnapshotSelection {
  const _SnapshotSelection({
    required this.payload,
    required this.acceptedLeagueIds,
    required this.payloadLeagueIds,
  });

  final Map<String, Object?> payload;
  final Set<int> acceptedLeagueIds;
  final Set<int> payloadLeagueIds;
}
