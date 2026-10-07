import 'dart:convert';
import 'package:http/http.dart' as http;
import 'retained_async_value.dart';

/// Shared transport for prebuilt, public day and detail artifacts.
/// User preferences and live state are never stored in these publications.
class PublishedFeedDelivery {
  PublishedFeedDelivery({
    required this.projectUrl,
    required this.publicKey,
    this.hostedBaseUrl,
    http.Client? client,
    DateTime Function()? clock,
    Duration Function(DateTime)? localOffset,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now,
       _localOffset = localOffset ?? ((date) => date.timeZoneOffset);
  final Uri projectUrl;
  final String publicKey;
  final Uri? hostedBaseUrl;
  final http.Client _client;
  final DateTime Function() _clock;
  final Duration Function(DateTime) _localOffset;
  final _days = <String, RetainedAsyncValue<Map<String, Object?>?>>{};
  final _artifacts = <String, Future<Map<String, Object?>>>{};

  void invalidateDay(String sport, DateTime date) {
    _days['$sport:${dateKey(date)}']?.invalidate();
  }

  Future<Map<String, Object?>?> loadDay(String sport, DateTime date) {
    if (!RegExp(r'^[a-z]+$').hasMatch(sport)) {
      throw ArgumentError('Invalid sport');
    }
    // The batch publishes Paris calendar days. Other local calendars retain
    // the original full reader so midnight fixtures are never silently lost.
    if (_localOffset(date) != _parisOffset(date)) {
      return Future.value(null);
    }
    final day = dateKey(date), key = '$sport:$day';
    final cache =
        _days.remove(key) ??
        RetainedAsyncValue<Map<String, Object?>?>(clock: _clock);
    _days[key] = cache;
    while (_days.length > 24) {
      _days.remove(_days.keys.first);
    }
    return cache.read(() async {
      final base = hostedBaseUrl;
      final uri = base != null
          ? base.resolve('delivery/$sport/$day/manifest.json')
          : projectUrl
                .resolve('/rest/v1/sport_feed_delivery_heads')
                .replace(
                  queryParameters: {
                    'sport': 'eq.$sport',
                    'day': 'eq.$day',
                    'select': 'manifest',
                    'limit': '1',
                  },
                );
      final response = await _client
          .get(uri, headers: base == null ? {'apikey': publicKey} : {})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw StateError(
          'Calendar publication unavailable (${response.statusCode})',
        );
      }
      final decoded = jsonDecode(response.body);
      final manifest = base != null
          ? _map(decoded)
          : ((decoded as List).isEmpty
                ? <String, Object?>{}
                : _map(_map(decoded.first)['manifest']));
      if (manifest.isEmpty) return null;
      if (manifest['schemaVersion'] != 1 ||
          manifest['sport'] != sport ||
          manifest['day'] != day) {
        throw const FormatException('Invalid calendar manifest');
      }
      final payload = await loadArtifact(manifest['path'] as String);
      final delivery = _map(payload['delivery']);
      if (delivery['sport'] != sport || delivery['day'] != day) {
        throw const FormatException('Calendar artifact identity mismatch');
      }
      return payload;
    });
  }

  Future<Map<String, Object?>> loadArtifact(String path) {
    // References are relative, immutable keys; never forward keys to another host.
    if (!RegExp(
      r'^delivery/[a-z]+/[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+\.json$',
    ).hasMatch(path)) {
      throw const FormatException('Invalid publication artifact path');
    }
    final cached = _artifacts.remove(path);
    if (cached != null) {
      _artifacts[path] = cached;
      return cached;
    }
    final request = _fetchArtifact(path);
    _artifacts[path] = request;
    while (_artifacts.length > 12) {
      _artifacts.remove(_artifacts.keys.first);
    }
    return request;
  }

  Future<Map<String, Object?>> _fetchArtifact(String path) async {
    try {
      final uri =
          hostedBaseUrl?.resolve(path) ??
          projectUrl.resolve(
            '/storage/v1/object/public/lector-feed-delivery/$path',
          );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError(
          'Publication artifact unavailable (${response.statusCode})',
        );
      }
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid publication JSON');
      }
      return Map<String, Object?>.from(value);
    } catch (_) {
      _artifacts.remove(path);
      rethrow;
    }
  }

  Future<Map<String, Object?>?> detail(
    Map<String, Object?> overview,
    String matchId,
  ) async {
    final delivery = _map(overview['delivery']);
    final path = _map(delivery['detailPaths'])[matchId];
    if (path is String) return loadArtifact(path);
    final reference = _map(path);
    if (reference['path'] is! String || reference['context'] is! String) {
      return null;
    }
    final payloads = await Future.wait([
      loadArtifact(reference['context'] as String),
      loadArtifact(reference['path'] as String),
    ]);
    return _merge(payloads[0], payloads[1]);
  }

  Future<List<Map<String, Object?>>> radar(
    Map<String, Object?> overview,
  ) async {
    final paths =
        (_map(overview['delivery'])['radarPaths'] as List?)?.cast<String>() ??
        const <String>[];
    final result = <Map<String, Object?>>[];
    for (var start = 0; start < paths.length; start += 4) {
      result.addAll(
        await Future.wait(paths.skip(start).take(4).map(loadArtifact)),
      );
    }
    return result;
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';
}

Map<String, Object?> _map(Object? v) =>
    v is Map ? Map<String, Object?>.from(v) : {};

Map<String, Object?> _merge(
  Map<String, Object?> context,
  Map<String, Object?> fixture,
) => {
  ...context,
  for (final entry in fixture.entries)
    entry.key: entry.value is Map && context[entry.key] is Map
        ? _merge(_map(context[entry.key]), _map(entry.value))
        : entry.value,
};

Duration _parisOffset(DateTime date) {
  DateTime lastSunday(int month) {
    final last = DateTime.utc(date.year, month, 31);
    return last.subtract(Duration(days: last.weekday % 7));
  }

  final day = DateTime.utc(date.year, date.month, date.day);
  return Duration(
    hours: !day.isBefore(lastSunday(3)) && day.isBefore(lastSunday(10)) ? 2 : 1,
  );
}
