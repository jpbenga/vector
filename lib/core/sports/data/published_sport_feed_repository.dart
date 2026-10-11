import 'sport_publication_codec.dart';
import 'dart:async';
import '../domain/sport_snapshot.dart';
import '../domain/sport_fixture.dart';
export 'sport_publication_codec.dart' show SportPublicationCodec;
import '../../data/navigation_feed_cache.dart';
import '../../data/published_feed_delivery.dart';
import '../../data/retained_async_value.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/sport_feed_repository.dart';
import '../domain/sport.dart';

abstract interface class SportPublicationSource {
  Future<Map<String, dynamic>?> read(SportId sport);
}

abstract interface class ProgressiveSportPublicationSource
    implements SportPublicationSource {
  Future<Map<String, dynamic>?> readDay(SportId sport, DateTime day);
  Future<Map<String, dynamic>?> readMatch(
    SportId sport,
    String matchId,
    DateTime? capturedAt,
  );
}

/// Public compact transport. Provider authentication is never done by Flutter.
class HttpSportPublicationSource implements SportPublicationSource {
  HttpSportPublicationSource(this.baseUrl);
  final Uri baseUrl;

  @override
  Future<Map<String, dynamic>?> read(SportId sport) async {
    final response = await http
        .get(baseUrl.resolve('sports/${Uri.encodeComponent(sport.key)}/feed'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 204 || response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError(
        'Publication service unavailable (${response.statusCode})',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

/// Public table reader uses the public project key explicitly, so an expired
/// account JWT cannot block access to public sport publications.
class SupabaseSportPublicationSource
    implements ProgressiveSportPublicationSource {
  SupabaseSportPublicationSource({
    required this.projectUrl,
    required this.publicKey,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final Uri projectUrl;
  final String publicKey;
  final http.Client _client;
  @override
  Future<Map<String, dynamic>?> read(SportId sport) => _read(sport, 'radar');

  @override
  Future<Map<String, dynamic>?> readDay(SportId sport, DateTime day) =>
      _read(sport, 'day', day: day);

  @override
  Future<Map<String, dynamic>?> readMatch(
    SportId sport,
    String matchId,
    DateTime? capturedAt,
  ) => _read(sport, 'match', matchId: matchId, capturedAt: capturedAt);

  Future<Map<String, dynamic>?> _read(
    SportId sport,
    String section, {
    DateTime? day,
    String? matchId,
    DateTime? capturedAt,
  }) async {
    final response = await _client
        .post(
          projectUrl.resolve('/rest/v1/rpc/read_sport_feed'),
          headers: {'apikey': publicKey, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'p_sport': sport.key,
            'p_section': section,
            'p_day': day == null ? null : PublishedFeedDelivery.dateKey(day),
            'p_match': matchId,
            'p_captured_at': capturedAt?.toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError(
        'Sport publication service unavailable (${response.statusCode})',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>?;
  }
}

class PublishedSportFeedRepository
    implements ProgressiveSportFeedRepository, PreloadingSportFeedRepository {
  PublishedSportFeedRepository({
    required this.sport,
    this.source,
    this.completeSource,
    this.delivery,
    this.maximumDeliveryAge = const Duration(hours: 36),
    DateTime Function()? clock,
  }) : _cache = RetainedAsyncValue<SportFeedResult>(clock: clock),
       _details = NavigationFeedCache<SportFeedResult>(
         capacity: 12,
         clock: clock,
       ),
       _navigation = NavigationFeedCache<SportFeedResult>(clock: clock);
  @override
  final SportId sport;
  final SportPublicationSource? source;

  /// Verified full CDN snapshot: warmed after first paint, shared across days
  /// and details. The progressive server source remains authoritative.
  final SportPublicationSource? completeSource;
  final PublishedFeedDelivery? delivery;
  final Duration maximumDeliveryAge;
  final NavigationFeedCache<SportFeedResult> _navigation;
  final NavigationFeedCache<SportFeedResult> _details;
  final _remoteChecks = <String, DateTime>{};
  final _remoteQueue = <String, Future<void> Function()>{};
  bool _remoteActive = false;
  SportFeedResult? _radarDelivery;
  SportFeedResult? _completePublication;
  Map<String, Object?>? _radarDetailIndex;
  DateTime? _serverVersion;
  final _overviews = <String, Map<String, Object?>>{};
  final _radarCache = RetainedAsyncValue<SportFeedResult>();
  final _decodedDays = Expando<SportFeedResult>();
  final RetainedAsyncValue<SportFeedResult> _cache;

  @override
  Future<SportFeedResult> load(DateTime selectedDate) => _navigation
      .read(
        'day:${PublishedFeedDelivery.dateKey(selectedDate)}',
        () => _loadDay(selectedDate),
        isUsable: (result) => result.isAvailable,
      )
      .then((result) {
        if (result.isAvailable) {
          _revalidate(
            'day:${PublishedFeedDelivery.dateKey(selectedDate)}',
            () => _readRemoteDay(selectedDate),
          );
        }
        return result;
      });

  @override
  SportFeedResult? peek(DateTime date, {bool radar = false}) => _navigation
      .peek(radar ? 'radar' : 'day:${PublishedFeedDelivery.dateKey(date)}');

  @override
  void cancelPrefetch() => _navigation.cancelPreload();

  @override
  void prefetch(DateTime date) {
    if (delivery == null && source is! ProgressiveSportPublicationSource) {
      return;
    }
    final days = navigationFeedDays(date, _navigation.clock());
    _navigation.preload([
      // One shared Radar publication warms every date using references to the
      // same decoded fixtures and standings, rather than 20 copies of them.
      () async {
        final result = await loadRadar(date);
        if (_radarDelivery != null) _warmDays(result, date);
      },
      for (final day in (delivery == null ? days : days.take(4)))
        () async {
          await _navigation.read(
            'day:${PublishedFeedDelivery.dateKey(day)}',
            () => _loadDay(day),
          );
        },
    ]);
  }

  Future<SportFeedResult> _loadDay(DateTime selectedDate) async {
    final existing = peek(selectedDate);
    if (delivery != null &&
        existing?.snapshot != null &&
        _deliveryIsCurrent(existing!.snapshot!.capturedAt)) {
      return existing;
    }
    final full = _radarDelivery?.snapshot;
    if (full != null &&
        full.covers(selectedDate) &&
        _deliveryIsCurrent(full.capturedAt)) {
      return _project(full, selectedDate: selectedDate);
    }
    Map<String, Object?>? overview;
    try {
      overview = await delivery?.loadDay(sport.key, selectedDate);
    } on FormatException {
      rethrow;
    } on Object {
      if (source == null) rethrow;
      // A CDN failure falls back to the public reader, never to an empty day.
    }
    if (overview != null) {
      final decoded = _decodedDays[overview] ??= SportFeedResult.available(
        SportPublicationCodec.decode(
          Map<String, dynamic>.from(overview),
          sport,
        ),
      );
      if (_deliveryIsCurrent(decoded.snapshot!.capturedAt)) {
        final key = PublishedFeedDelivery.dateKey(selectedDate);
        _overviews.remove(key);
        _overviews[key] = overview;
        while (_overviews.length > 24) {
          _overviews.remove(_overviews.keys.first);
        }
        return decoded;
      }
    }
    final remote = source;
    if (completeSource != null) {
      final complete = await _cache.read(_readCompletePublication);
      if (complete.snapshot != null &&
          complete.snapshot!.covers(selectedDate) &&
          _deliveryIsCurrent(complete.snapshot!.capturedAt)) {
        return _project(complete.snapshot!, selectedDate: selectedDate);
      }
    }
    if (remote is ProgressiveSportPublicationSource) {
      return _readRemoteDay(selectedDate);
    }
    if (source == null) {
      return const SportFeedResult.unavailable(
        SportFeedUnavailableReason.notConnected,
      );
    }
    return _cache.read(_readPublication);
  }

  @override
  Future<SportFeedResult> refresh(DateTime selectedDate) {
    _cache.invalidate();
    _radarCache.invalidate();
    delivery?.invalidateDay(sport.key, selectedDate);
    _navigation.invalidate('radar');
    return _navigation.read(
      'day:${PublishedFeedDelivery.dateKey(selectedDate)}',
      () => source is ProgressiveSportPublicationSource
          ? _readRemoteDay(selectedDate)
          : _loadDay(selectedDate),
      force: true,
    );
  }

  @override
  Future<SportFeedResult> loadRadar(DateTime selectedDate) => _navigation
      .read(
        'radar',
        () => _loadRadar(selectedDate),
        ttl: const Duration(minutes: 10),
        isUsable: (result) => result.isAvailable,
      )
      .then((result) {
        _revalidate('radar', _readPublication);
        return result;
      });

  Future<SportFeedResult> _loadRadar(DateTime selectedDate) async {
    if (_radarDelivery != null &&
        _deliveryIsCurrent(_radarDelivery!.snapshot!.capturedAt)) {
      return _radarDelivery!;
    }
    if (completeSource != null) {
      final complete = await _cache.read(_readCompletePublication);
      if (complete.snapshot != null &&
          _deliveryIsCurrent(complete.snapshot!.capturedAt)) {
        _radarDelivery = complete;
        _warmDays(complete, selectedDate);
        return complete;
      }
      return _readPublication();
    }
    final key = PublishedFeedDelivery.dateKey(selectedDate);
    if (delivery != null && !_overviews.containsKey(key)) {
      await load(selectedDate);
    }
    final overview = _overviews[key];
    if (overview == null || delivery == null) {
      return _cache.read(_readPublication);
    }
    return _radarCache.read(() async {
      final parts = await delivery!.radar(overview);
      if (parts.length != 1) {
        throw const FormatException('Non-atomic sport publication');
      }
      final result = SportFeedResult.available(
        SportPublicationCodec.decode(
          Map<String, dynamic>.from(parts.single),
          sport,
        ),
      );
      if (!_deliveryIsCurrent(result.snapshot!.capturedAt)) {
        return _readPublication();
      }
      _radarDelivery = result;
      final index = parts.single['delivery_part'];
      if (index is Map) {
        _radarDetailIndex = {
          'capturedAt': parts.single['capturedAt'],
          'delivery': {'detailPaths': index['detailPaths']},
        };
      }
      _warmDays(result, selectedDate);
      return result;
    });
  }

  @override
  Future<SportFeedResult> loadMatch(
    DateTime selectedDate,
    String matchId,
  ) async {
    final day = await load(selectedDate);
    final version = day.snapshot?.capturedAt;
    final key = 'match:${version?.toIso8601String()}:$matchId';
    final result = await _details.read(
      key,
      () => _loadMatch(selectedDate, matchId, version),
      isUsable: (result) => result.isAvailable,
    );
    _revalidate(key, () => _readRemoteMatch(matchId, version), cache: _details);
    return result;
  }

  Future<SportFeedResult> _loadMatch(
    DateTime selectedDate,
    String matchId,
    DateTime? version,
  ) async {
    final retained = _details.peek(
      'match:${version?.toIso8601String()}:$matchId',
    );
    if (retained?.isAvailable == true) return retained!;
    final full = _completePublication?.snapshot;
    if (full != null &&
        full.capturedAt == version &&
        full.items.any((match) => match.id.value == matchId)) {
      return _project(full, matchId: matchId);
    }
    // The broad Radar is an overview. Event logs and H2H must still come
    // from the exact-version detail artifact, even for a prewarmed day.
    final overview =
        _overviews[PublishedFeedDelivery.dateKey(selectedDate)] ??
        _radarDetailIndex;
    if (overview != null &&
        DateTime.tryParse(overview['capturedAt']?.toString() ?? '') ==
            version) {
      final payload = await delivery?.detail(overview, matchId);
      if (payload != null) {
        return SportFeedResult.available(
          SportPublicationCodec.decode(
            Map<String, dynamic>.from(payload),
            sport,
          ),
        );
      }
    }
    final remote = source;
    if (remote is ProgressiveSportPublicationSource) {
      return _readRemoteMatch(matchId, version);
    }
    return load(selectedDate);
  }

  bool _deliveryIsCurrent(DateTime version) =>
      _navigation.clock().toUtc().difference(version.toUtc()) <=
          maximumDeliveryAge &&
      (_serverVersion == null || !version.isBefore(_serverVersion!));

  void _rememberVersion(DateTime version) {
    if (_serverVersion == null || version.isAfter(_serverVersion!)) {
      _serverVersion = version;
      _radarCache.invalidate();
    }
  }

  Future<SportFeedResult> _readRemoteDay(DateTime day) async {
    _remoteChecks['day:${PublishedFeedDelivery.dateKey(day)}'] = _navigation
        .clock();
    final remote = source as ProgressiveSportPublicationSource;
    final result = _decode(await remote.readDay(sport, day));
    if (result.snapshot != null) {
      _rememberVersion(result.snapshot!.capturedAt);
    }
    return result;
  }

  Future<SportFeedResult> _readRemoteMatch(
    String matchId,
    DateTime? version,
  ) async {
    _remoteChecks['match:${version?.toIso8601String()}:$matchId'] = _navigation
        .clock();
    return _decode(
      await (source as ProgressiveSportPublicationSource).readMatch(
        sport,
        matchId,
        version,
      ),
    );
  }

  SportFeedResult _decode(Map<String, dynamic>? payload) => payload == null
      ? const SportFeedResult.unavailable(
          SportFeedUnavailableReason.notPublished,
        )
      : SportFeedResult.available(SportPublicationCodec.decode(payload, sport));

  /// Only the foreground view revalidates remotely; preloading immutable
  /// files cannot flood the database. Public results never use account JWTs.
  void _revalidate(
    String key,
    Future<SportFeedResult> Function() read, {
    NavigationFeedCache<SportFeedResult>? cache,
  }) {
    if (delivery == null || source is! ProgressiveSportPublicationSource) {
      return;
    }
    final now = _navigation.clock(), checked = _remoteChecks[key];
    if (checked != null &&
        now.difference(checked) < const Duration(minutes: 2)) {
      return;
    }
    _remoteChecks.remove(key);
    _remoteChecks[key] = now;
    while (_remoteChecks.length > 40) {
      _remoteChecks.remove(_remoteChecks.keys.first);
    }
    final target = cache ?? _navigation;
    _remoteQueue[key] = () => read().then<void>(
      (result) {
        final snapshot = result.snapshot, previous = target.peek(key)?.snapshot;
        if (snapshot != null &&
            (previous == null ||
                !snapshot.capturedAt.isBefore(previous.capturedAt))) {
          target.seed(key, result);
        }
      },
      onError: (Object _) {
        /* Keep the validated publication; retry after TTL. */
      },
    );
    // Revalidation is deliberately serial: rapid date/tab changes must not
    // launch a burst of expensive database projections behind the fast UI.
    while (_remoteQueue.length > 4) {
      final skipped = _remoteQueue.keys.first;
      _remoteQueue.remove(skipped);
      _remoteChecks.remove(skipped);
    }
    _drainRemote();
  }

  void _drainRemote() {
    if (_remoteActive || _remoteQueue.isEmpty) return;
    final key = _remoteQueue.keys.last;
    final next = _remoteQueue.remove(key)!;
    _remoteActive = true;
    unawaited(
      next().whenComplete(() {
        _remoteActive = false;
        _drainRemote();
      }),
    );
  }

  SportFeedResult _project(
    SportSnapshot<SportFixture> full, {
    DateTime? selectedDate,
    String? matchId,
  }) {
    final matches = full.items.where((match) {
      if (matchId != null) return match.id.value == matchId;
      final day = match.startsAt?.toLocal();
      if (day == null) return false;
      return day.year == selectedDate!.year &&
          day.month == selectedDate.month &&
          day.day == selectedDate.day;
    }).toList();
    final teams = {
      for (final match in matches) ...[match.home.id.key, match.away.id.key],
    };
    return SportFeedResult.available(
      SportSnapshot<SportFixture>(
        sport: full.sport,
        schemaVersion: full.schemaVersion,
        capturedAt: full.capturedAt,
        windowStart: full.windowStart,
        windowEnd: full.windowEnd,
        items: matches,
        sportOf: (match) => match.sport,
        competitions: full.competitions,
        players: full.players.where(
          (player) => teams.contains(player.team.id.key),
        ),
        playerRadarCoverage: full.playerRadarCoverage.where(
          (coverage) => teams.contains(coverage.team.key),
        ),
      ),
    );
  }

  void _warmDays(SportFeedResult result, DateTime date) {
    final full = result.snapshot;
    if (full == null) return;
    for (final day in [
      date,
      ...navigationFeedDays(date, _navigation.clock()),
    ]) {
      if (!full.covers(day)) continue;
      final key = 'day:${PublishedFeedDelivery.dateKey(day)}';
      final previous = _navigation.peek(key)?.snapshot;
      if (previous == null || previous.capturedAt.isBefore(full.capturedAt)) {
        _navigation.seed(key, _project(full, selectedDate: day));
      }
    }
  }

  Future<SportFeedResult> _readPublication() async {
    _remoteChecks['radar'] = _navigation.clock();
    final payload = await source!.read(sport);
    if (payload == null) {
      return const SportFeedResult.unavailable(
        SportFeedUnavailableReason.notPublished,
      );
    }
    final result = SportFeedResult.available(
      SportPublicationCodec.decode(payload, sport),
    );
    _rememberVersion(result.snapshot!.capturedAt);
    return result;
  }

  Future<SportFeedResult> _readCompletePublication() async {
    final result = _decode(await completeSource!.read(sport));
    if (result.snapshot != null &&
        _deliveryIsCurrent(result.snapshot!.capturedAt)) {
      _completePublication = result;
    }
    return result;
  }
}
