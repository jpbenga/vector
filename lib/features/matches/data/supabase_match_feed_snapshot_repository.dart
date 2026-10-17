import 'dart:convert';
import '../../../core/data/published_feed_delivery.dart';
import 'match_feed_repository.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class MatchFeedSnapshotRemoteDataSource {
  Future<Map<String, Object?>?> loadLatestForDate(DateTime date);
}

class SupabaseMatchFeedSnapshotRepository
    implements MatchFeedSnapshotRemoteDataSource {
  SupabaseMatchFeedSnapshotRepository(
    this._client, {
    this.delivery,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final PublishedFeedDelivery? delivery;
  final DateTime Function() clock;
  final _delivered = <String, Map<String, Object?>>{};
  String? _radarSelection;
  Map<String, Object?>? _radarPayload;
  final _calendarOwners = <String, Map<String, String>>{};
  final _detailSources = <String, Future<Map<String, Object?>?>>{};

  Future<Map<String, Object?>?> loadDetails(
    DateTime date,
    String matchId,
  ) async {
    final sourceId =
        _calendarOwners[PublishedFeedDelivery.dateKey(date)]?[matchId];
    if (sourceId != null) {
      final cached = _detailSources[sourceId];
      if (cached != null) return cached;
      final request = _fetchPayloadChunk([
        sourceId,
      ]).then(mergeMatchFeedSnapshotRows);
      _detailSources[sourceId] = request;
      while (_detailSources.length > 12) {
        _detailSources.remove(_detailSources.keys.first);
      }
      try {
        return await request;
      } on Object {
        _detailSources.remove(sourceId);
        rethrow;
      }
    }
    final overview = _delivered[PublishedFeedDelivery.dateKey(date)];
    return overview == null ? null : delivery?.detail(overview, matchId);
  }

  Future<Map<String, Object?>?> loadRadar(DateTime date) async {
    if (_calendarOwners.containsKey(PublishedFeedDelivery.dateKey(date))) {
      return _loadProjection(date, section: 'radar');
    }
    final overview = _delivered[PublishedFeedDelivery.dateKey(date)];
    if (overview == null || delivery == null) return null;
    final descriptor = overview['delivery'];
    final signature = jsonEncode(
      descriptor is Map ? descriptor['radarPaths'] : null,
    );
    if (signature == _radarSelection && _radarPayload != null) {
      return _radarPayload;
    }
    final merged = mergeMatchFeedSnapshotPayloads(
      await delivery!.radar(overview),
    );
    if (merged != null) {
      _radarSelection = signature;
      _radarPayload = {
        ...merged,
        'radar_source_ids': [
          for (final path
              in (descriptor is Map
                  ? descriptor['radarPaths'] as List? ?? const []
                  : const []))
            if (path is String && path.split('/').length == 4)
              path.split('/')[2],
        ],
      };
    }
    return _radarPayload;
  }

  final _payloadRows = <String, Object?>{};
  String? _selection;
  Map<String, Object?>? _merged;
  final _pendingSelections = <String, Future<Map<String, Object?>?>>{};

  final SupabaseClient _client;

  void invalidate(DateTime date) {
    delivery?.invalidateDay('football', date);
    _delivered.remove(PublishedFeedDelivery.dateKey(date));
    _radarSelection = null;
    _radarPayload = null;
    _calendarOwners.remove(PublishedFeedDelivery.dateKey(date));
  }

  Future<Map<String, Object?>?> refreshForDate(DateTime date) {
    invalidate(date);
    // A manual refresh checks the authoritative public snapshots, not the
    // static demo manifest. It never calls a sporting provider or collector.
    return _withSessionRecovery(() => _loadLatestForDate(date));
  }

  @override
  Future<Map<String, Object?>?> loadLatestForDate(DateTime date) async {
    final overview = await loadPublishedForDate(date);
    if (overview != null) return overview;
    return _withSessionRecovery(() => _loadLatestForDate(date));
  }

  /// Background warming must never fall back to a full archive download.
  /// A missing publication remains unavailable, rather than an empty calendar.
  Future<Map<String, Object?>?> loadPublishedForDate(DateTime date) async {
    final key = PublishedFeedDelivery.dateKey(date);
    final today = _dateOnly(clock());
    final freshnessAt = _dateOnly(date).isBefore(today)
        ? DateTime(date.year, date.month, date.day, 23, 59, 59)
        : clock();
    final transport = delivery;
    if (transport != null) {
      Map<String, Object?>? overview;
      try {
        overview = await transport.loadDay('football', date);
      } on FormatException {
        rethrow;
      } on Object {
        // A delivery outage must not prevent the public snapshot fallback.
        _delivered.remove(key);
        return null;
      }
      if (overview != null) {
        final metadata = MatchFeedSnapshotMetadata.fromSnapshot(
          overview,
          matches: const [],
        );
        if (metadata.covers(date) && !metadata.isObsolete(freshnessAt)) {
          _calendarOwners.remove(key);
          _delivered.remove(key);
          _delivered[key] = overview;
          while (_delivered.length > 24) {
            _delivered.remove(_delivered.keys.first);
          }
          return overview;
        }
      }
    }
    _delivered.remove(key);
    return null;
  }

  Future<Map<String, Object?>?> _loadLatestForDate(DateTime date) async {
    if (delivery != null && !delivery!.supportsCalendar(date)) {
      return _loadLegacyForDate(date);
    }
    try {
      return await _loadProjection(date);
    } on PostgrestException catch (error) {
      // An older backend can still serve the existing reader during rollout.
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
      return _loadLegacyForDate(date);
    }
  }

  Future<Map<String, Object?>?> _loadProjection(
    DateTime date, {
    String section = 'calendar',
  }) async {
    final rows = await _client
        .rpc<Object?>(
          'read_football_calendar',
          params: {
            'p_day': PublishedFeedDelivery.dateKey(date),
            'p_section': section,
          },
        )
        .timeout(const Duration(seconds: 20));
    if (rows is! List) {
      throw const FormatException('Invalid football projection');
    }
    final merged = mergeMatchFeedSnapshotRows(rows);
    if (merged == null) return null;
    if (section == 'calendar') {
      final owners = <String, String>{};
      for (final row in rows.whereType<Map<Object?, Object?>>()) {
        final id = row['id']?.toString();
        final payload = row['payload'];
        final raw = payload is Map ? payload['raw'] : null;
        final fixtures = raw is Map ? raw['fixtures'] : null;
        if (id == null || fixtures is! List) continue;
        for (final fixture in fixtures.whereType<Map<Object?, Object?>>()) {
          final identity = fixture['fixture'];
          if (identity is Map && identity['id'] != null) {
            owners.putIfAbsent('api-fixture-${identity['id']}', () => id);
          }
        }
      }
      _calendarOwners[PublishedFeedDelivery.dateKey(date)] = owners;
      while (_calendarOwners.length > 24) {
        _calendarOwners.remove(_calendarOwners.keys.first);
      }
    }
    return {
      ...merged,
      'radar_source_ids': [
        for (final row in rows.whereType<Map<Object?, Object?>>())
          row['id'].toString(),
      ],
    };
  }

  Future<Map<String, Object?>?> _loadLegacyForDate(DateTime date) async {
    final day = _dateOnly(date).toIso8601String().split('T').first;
    var request = _client
        .from('match_feed_analysis_snapshots')
        .select('id,scope,league_ids')
        .lte('window_start', day)
        .gte('window_end', day);

    // A past calendar day must use the latest snapshot that was available at
    // the end of that day. Future days keep the latest available snapshot so
    // the Radar can clearly present the current state before kick-off.
    if (_dateOnly(date).isBefore(_dateOnly(clock()))) {
      final endOfDay = _dateOnly(
        date,
      ).add(const Duration(days: 1)).toUtc().toIso8601String();
      request = request.lte('as_of', endOfDay);
      final rows = await request.order('as_of', ascending: false).limit(500);
      return _loadSelectedPayloads(rows);
    }

    // A match list legitimately contains only competitions scheduled for the
    // selected date. Radar is broader: it compares club or national-team form
    // across every configured competition. Keep the date-covered rows first
    // for the fixture feed, then add the newest known snapshot of leagues that
    // have no fixture in this calendar window.
    final coveredRequest = request.order('as_of', ascending: false).limit(500);
    final latestRequest = _client
        .from('match_feed_analysis_snapshots')
        .select('id,scope,league_ids')
        .order('as_of', ascending: false)
        .limit(500);
    final pages = await Future.wait([coveredRequest, latestRequest]);
    return _loadSelectedPayloads([...pages[0], ...pages[1]]);
  }

  Future<T> _withSessionRecovery<T>(Future<T> Function() request) async {
    if (_client.auth.currentSession?.isExpired == true) {
      await _refreshOrClearSession();
    }

    try {
      return await request();
    } on PostgrestException catch (error) {
      if (!_isExpiredJwt(error)) {
        rethrow;
      }
      await _refreshOrClearSession();
      return request();
    }
  }

  Future<void> _refreshOrClearSession() async {
    if (_client.auth.currentSession == null) {
      return;
    }

    try {
      await _client.auth.refreshSession();
    } on Object {
      // A transient refresh failure must never sign out the account. The
      // application's public reader uses an independent anonymous client.
      rethrow;
    }
  }

  bool _isExpiredJwt(PostgrestException error) =>
      error.code == 'PGRST303' ||
      error.message.toLowerCase().contains('jwt expired');

  Future<Map<String, Object?>?> _loadSelectedPayloads(
    Iterable<Object?> metadataRows,
  ) async {
    final ids = selectMatchFeedSnapshotRowIds(metadataRows);
    if (ids.isEmpty) return null;
    final selection = ids.join(',');
    if (_selection == selection && _merged != null) return _merged;
    final existing = _pendingSelections[selection];
    if (existing != null) return existing;
    final request = _fetchSelectedPayloads(ids, selection);
    _pendingSelections[selection] = request;
    try {
      return await request;
    } finally {
      _pendingSelections.remove(selection);
    }
  }

  Future<Map<String, Object?>?> _fetchSelectedPayloads(
    List<String> ids,
    String selection,
  ) async {
    final missingIds = ids
        .where((id) => !_payloadRows.containsKey(id))
        .toList();
    const chunkSize = 5;
    const concurrentChunks = 3;
    final chunks = <List<String>>[
      for (var start = 0; start < missingIds.length; start += chunkSize)
        missingIds.skip(start).take(chunkSize).toList(growable: false),
    ];
    final rowsById = <String, Object?>{..._payloadRows};

    for (var start = 0; start < chunks.length; start += concurrentChunks) {
      final pages = await Future.wait(
        chunks.skip(start).take(concurrentChunks).map(_fetchPayloadChunk),
      );
      for (final page in pages) {
        for (final row in page) {
          final id = row['id']?.toString();
          if (id != null) {
            rowsById[id] = row;
          }
        }
      }
    }

    if (ids.any((id) => _payloadFromRow(rowsById[id]) == null)) {
      throw StateError('Incomplete snapshot payload response');
    }
    final payload = mergeMatchFeedSnapshotRows(ids.map((id) => rowsById[id]));
    final merged = payload == null
        ? null
        : {...payload, 'radar_source_ids': ids};
    _payloadRows.clear();
    // Retain only this selection, bounding memory independently of calendar use.
    _payloadRows.addEntries(ids.map((id) => MapEntry(id, rowsById[id])));
    _selection = selection;
    _merged = merged;
    return merged;
  }

  Future<List<Map<String, dynamic>>> _fetchPayloadChunk(
    List<String> ids,
  ) async {
    try {
      return await _client
          .from('match_feed_analysis_snapshots')
          .select('id,scope,league_ids,payload')
          .inFilter('id', ids)
          .timeout(const Duration(seconds: 30));
    } on PostgrestException catch (error) {
      // Splitting a timed-out SQL response lowers the work per statement;
      // retrying the same large response would repeat the server timeout.
      if (error.code != '57014' || ids.length == 1) rethrow;
      final rows = <Map<String, dynamic>>[];
      for (final id in ids) {
        rows.addAll(await _fetchPayloadChunk([id]));
      }
      return rows;
    }
  }
}

List<String> selectMatchFeedSnapshotRowIds(Iterable<Object?> rows) {
  final selected = <String>[];
  final coveredLeagueIds = <int>{};
  var selectedGlobal = false;

  for (final row in rows) {
    if (row is! Map) {
      continue;
    }
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) {
      continue;
    }

    if (row['scope'] == 'global') {
      if (!selectedGlobal) {
        selected.add(id);
        selectedGlobal = true;
      }
      continue;
    }

    final leagueIds = <int>{
      for (final value in (row['league_ids'] as List?) ?? const [])
        if (value is int) value,
    };
    if (leagueIds.isEmpty ||
        leagueIds.difference(coveredLeagueIds).isNotEmpty) {
      selected.add(id);
      coveredLeagueIds.addAll(leagueIds);
    }
  }

  return selected;
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
    // Kept only to merge an offline legacy snapshot. Remote production reads
    // the compact analysis table, where these collections are absent.
    'standings',
    'team_statistics',
    'recent_league_matches',
    'european_comparisons',
    'european_card_forms',
    'head_to_head',
    'player_form_radar',
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
    'computed': {'fixtures': _mergeComputedFixtures(selected)},
  };
}

List<Object?> _mergeComputedFixtures(List<_SnapshotSelection> selected) {
  final values = <Object?>[];
  final fixtureIds = <String>{};
  for (final selection in selected) {
    final computed = _objectMap(selection.payload['computed']);
    for (final value in _objectList(computed?['fixtures'])) {
      final entry = _objectMap(value);
      final fixtureId = entry?['fixture_id']?.toString();
      if (fixtureId != null && fixtureIds.add(fixtureId)) {
        values.add(entry);
      }
    }
  }
  return values;
}

Map<String, Object?>? _payloadFromRow(Object? row) {
  if (row is! Map) {
    return null;
  }
  final payload = row['payload'];
  if (payload is Map) {
    return {
      for (final entry in payload.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
      // Table metadata defines publication scope. Contextual standings can
      // describe other leagues without publishing their fixture calendars.
      if (row['scope'] != null) 'scope': row['scope'],
      if (row['league_ids'] is List) 'league_ids': row['league_ids'],
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
  if (key == 'european_comparisons' || key == 'european_card_forms') {
    return '$key:${map['fixtureId']}';
  }
  final fixtureId = _nestedNumber(map, const ['fixture', 'id']);
  final teamId = _nestedNumber(map, const ['team', 'id']);
  final playerId = _nestedNumber(map, const ['player', 'id']);

  if ((key == 'fixtures' || key == 'head_to_head') && fixtureId != null) {
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
  if (key == 'player_form_radar' &&
      leagueId != null &&
      teamId != null &&
      playerId != null) {
    return '$key:$leagueId:$teamId:$playerId';
  }
  if (key == 'expected_goals' && teamId != null) {
    return '$key:${leagueId ?? 'unknown'}:$teamId';
  }

  return '$key:${jsonEncode(entry)}';
}

Set<int> _leagueIdsForPayload(Map<String, Object?> payload) {
  final publishedLeagueIds = payload['league_ids'];
  if (publishedLeagueIds is List && publishedLeagueIds.isNotEmpty) {
    return publishedLeagueIds.whereType<int>().toSet();
  }
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
    'player_form_radar',
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
  if (map == null) return null;
  if (key == 'european_comparisons' || key == 'european_card_forms') {
    return _nestedNumber(map, const ['competition', 'id']);
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
