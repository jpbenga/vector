import 'sport_publication_codec.dart';
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
    this.delivery,
    DateTime Function()? clock,
  }) : _cache = RetainedAsyncValue<SportFeedResult>(clock: clock),
       _navigation = NavigationFeedCache<SportFeedResult>(clock: clock);
  @override
  final SportId sport;
  final SportPublicationSource? source;
  final PublishedFeedDelivery? delivery;
  final NavigationFeedCache<SportFeedResult> _navigation;
  final _overviews = <String, Map<String, Object?>>{};
  final _remoteVersions = <String, DateTime>{};
  final _radarCache = RetainedAsyncValue<SportFeedResult>();
  final _decodedDays = Expando<SportFeedResult>();
  final RetainedAsyncValue<SportFeedResult> _cache;

  @override
  Future<SportFeedResult> load(DateTime selectedDate) => _navigation.read(
    'day:${PublishedFeedDelivery.dateKey(selectedDate)}',
    () => _loadDay(selectedDate),
  );

  @override
  SportFeedResult? peek(DateTime date, {bool radar = false}) => _navigation
      .peek(radar ? 'radar' : 'day:${PublishedFeedDelivery.dateKey(date)}');

  @override
  void cancelPrefetch() => _navigation.cancelPreload();

  @override
  void prefetch(DateTime date) {
    if (delivery == null) return;
    final days = navigationFeedDays(date, _navigation.clock());
    _navigation.preload([
      for (final day in days)
        () async {
          await load(day);
        },
      if (days.isNotEmpty)
        () async {
          await loadRadar(date);
        },
    ]);
  }

  Future<SportFeedResult> _loadDay(DateTime selectedDate) async {
    final remote = source;
    if (remote is ProgressiveSportPublicationSource) {
      final payload = await remote.readDay(sport, selectedDate);
      if (payload == null) {
        return const SportFeedResult.unavailable(
          SportFeedUnavailableReason.notPublished,
        );
      }
      final snapshot = SportPublicationCodec.decode(payload, sport);
      final key = PublishedFeedDelivery.dateKey(selectedDate);
      _remoteVersions.remove(key);
      _remoteVersions[key] = snapshot.capturedAt;
      while (_remoteVersions.length > 24) {
        _remoteVersions.remove(_remoteVersions.keys.first);
      }
      return SportFeedResult.available(snapshot);
    }
    final overview = await delivery?.loadDay(sport.key, selectedDate);
    if (overview != null) {
      final key = PublishedFeedDelivery.dateKey(selectedDate);
      _overviews.remove(key);
      _overviews[key] = overview;
      while (_overviews.length > 24) {
        _overviews.remove(_overviews.keys.first);
      }
      return _decodedDays[overview] ??= SportFeedResult.available(
        SportPublicationCodec.decode(
          Map<String, dynamic>.from(overview),
          sport,
        ),
      );
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
      () => _loadDay(selectedDate),
      force: true,
    );
  }

  @override
  Future<SportFeedResult> loadRadar(DateTime selectedDate) => _navigation.read(
    'radar',
    () => _loadRadar(selectedDate),
    ttl: const Duration(minutes: 10),
  );

  Future<SportFeedResult> _loadRadar(DateTime selectedDate) async {
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
      return SportFeedResult.available(
        SportPublicationCodec.decode(
          Map<String, dynamic>.from(parts.single),
          sport,
        ),
      );
    });
  }

  @override
  Future<SportFeedResult> loadMatch(
    DateTime selectedDate,
    String matchId,
  ) async {
    final remote = source;
    if (remote is ProgressiveSportPublicationSource) {
      if (!_remoteVersions.containsKey(
        PublishedFeedDelivery.dateKey(selectedDate),
      )) {
        await load(selectedDate);
      }
      final payload = await remote.readMatch(
        sport,
        matchId,
        _remoteVersions[PublishedFeedDelivery.dateKey(selectedDate)],
      );
      return payload == null
          ? const SportFeedResult.unavailable(
              SportFeedUnavailableReason.notPublished,
            )
          : SportFeedResult.available(
              SportPublicationCodec.decode(payload, sport),
            );
    }
    final overview = _overviews[PublishedFeedDelivery.dateKey(selectedDate)];
    final payload = overview == null
        ? null
        : await delivery?.detail(overview, matchId);
    return payload == null
        ? load(selectedDate)
        : SportFeedResult.available(
            SportPublicationCodec.decode(
              Map<String, dynamic>.from(payload),
              sport,
            ),
          );
  }

  Future<SportFeedResult> _readPublication() async {
    final payload = await source!.read(sport);
    if (payload == null) {
      return const SportFeedResult.unavailable(
        SportFeedUnavailableReason.notPublished,
      );
    }
    return SportFeedResult.available(
      SportPublicationCodec.decode(payload, sport),
    );
  }
}
