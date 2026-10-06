import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../domain/sport.dart';
import '../domain/sport_fixture.dart';
import 'published_sport_feed_repository.dart';

abstract interface class SportLiveRepository {
  Future<List<SportFixture>> load(SportId sport, Set<String> fixtureIds);
}

/// The trusted score service supplies its time independently of the device.
abstract interface class SportLiveTimeSource {
  DateTime get scoreTime;
}

/// Public scores only. This transport never calls a sports provider or uses the
/// account JWT: anonymous and signed-in users receive the same factual results.
class SupabaseSportLiveRepository
    implements SportLiveRepository, SportLiveTimeSource {
  SupabaseSportLiveRepository({
    required this.projectUrl,
    required this.publicKey,
    this.client,
  });
  final Uri projectUrl;
  final String publicKey;
  final http.Client? client;
  Duration _serverOffset = Duration.zero;
  @override
  DateTime get scoreTime => DateTime.now().add(_serverOffset);
  @override
  Future<List<SportFixture>> load(SportId sport, Set<String> fixtureIds) async {
    if (fixtureIds.isEmpty) return [];
    if (fixtureIds.length > 500 ||
        fixtureIds.any((id) => !RegExp(r'^\d+$').hasMatch(id))) {
      throw const FormatException('Invalid score request');
    }
    final url = projectUrl
        .resolve('/rest/v1/sport_live_states')
        .replace(
          queryParameters: {
            'sport': 'eq.${sport.key}',
            'fixture_id': 'in.(${fixtureIds.join(',')})',
            'select':
                'sport,provider,fixture_id,competition_id,fixture_date,captured_at,payload',
            'limit': '500',
          },
        );
    final response = await (client?.get ?? http.get)(
      url,
      headers: {'apikey': publicKey},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Scores service unavailable');
    }
    final serverDate = response.headers['date'];
    if (serverDate != null) {
      try {
        final serverTime = DateFormat(
          "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
          'en_US',
        ).parseStrict(serverDate, true);
        _serverOffset = serverTime.difference(DateTime.now().toUtc());
      } on FormatException {
        // Retain the last trusted clock when a proxy omits a valid Date.
      }
    }
    final result = <SportFixture>[];
    final seen = <String>{};
    for (final raw in jsonDecode(response.body) as List) {
      final row = raw as Map<String, dynamic>;
      final payload = row['payload'] as Map<String, dynamic>;
      if (row['sport'] != sport.key ||
          row['provider'] != 'api-hockey' ||
          row['fixture_id'] != payload['id'] ||
          row['competition_id'] != payload['competitionId'] ||
          row['fixture_date'] != payload['calendarDate'] ||
          !fixtureIds.contains(row['fixture_id']) ||
          !seen.add(row['fixture_id'] as String)) {
        throw const FormatException('Mixed score identities');
      }
      final snapshot = SportPublicationCodec.decode({
        'schemaVersion': 1,
        'sport': sport.key,
        'provider': row['provider'],
        'competitionId': payload['competitionId'],
        'season': payload['season'],
        'capturedAt': row['captured_at'],
        'windowStart': payload['calendarDate'],
        'windowEnd': payload['calendarDate'],
        'items': [payload],
      }, sport);
      if (snapshot.capturedAt.isAfter(
        scoreTime.add(const Duration(seconds: 30)),
      )) {
        throw const FormatException('Future score collection');
      }
      result.add(snapshot.items.single);
    }
    return result;
  }
}

/// Immutable prematch fixtures and readings stay in the base publication. This
/// controller overlays only factual score/status fields, with identity and
/// timestamp checks; an outage never clears the last valid result.
class SportLiveController extends ChangeNotifier {
  SportLiveController({
    required this.sport,
    required this.repository,
    this.interval = const Duration(minutes: 1),
  });
  final SportId sport;
  final SportLiveRepository repository;
  final Duration interval;
  final Map<String, SportFixture> _base = {}, _states = {};
  Timer? _timer;
  bool _busy = false, _disposed = false;
  int _generation = 0;
  bool unavailable = false;
  DateTime? lastSuccess;
  DateTime get _scoreTime => repository is SportLiveTimeSource
      ? (repository as SportLiveTimeSource).scoreTime
      : DateTime.now();
  void watch(Iterable<SportFixture> fixtures) {
    _base.clear();
    for (final f in fixtures) {
      if (f.sport != sport) throw ArgumentError('Mixed live sport');
      _base[f.id.key] = f;
    }
    _generation++;
    _timer?.cancel();
    _timer = _base.isEmpty ? null : Timer.periodic(interval, (_) => refresh());
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_busy || _disposed || _base.isEmpty) return;
    _busy = true;
    final generation = _generation;
    try {
      final rows = await repository.load(
        sport,
        _base.values.map((f) => f.id.value).toSet(),
      );
      if (_disposed || generation != _generation) return;
      for (final state in rows) {
        final base = _base[state.id.key];
        final previous = _states[state.id.key] ?? base;
        if (base == null ||
            previous == null ||
            state.competition != base.competition ||
            state.season != base.season ||
            state.home.id != base.home.id ||
            state.away.id != base.away.id ||
            state.capturedAt == null ||
            state.capturedAt!.isAfter(
              _scoreTime.add(const Duration(seconds: 30)),
            ) ||
            (previous.capturedAt != null &&
                state.capturedAt!.isBefore(previous.capturedAt!)) ||
            (previous.status == SportFixtureStatus.finished &&
                [
                  SportFixtureStatus.scheduled,
                  SportFixtureStatus.live,
                ].contains(state.status))) {
          continue;
        }
        _states[state.id.key] = state;
      }
      unavailable = false;
      lastSuccess = DateTime.now();
      notifyListeners();
    } on Object {
      if (!_disposed && generation == _generation) {
        unavailable = true;
        notifyListeners();
      }
    } finally {
      _busy = false;
      // A date changed while the preceding request was in flight.
      if (!_disposed && generation != _generation) unawaited(refresh());
    }
  }

  SportFixture display(SportFixture base) {
    final current = _states[base.id.key];
    if (current == null ||
        current.competition != base.competition ||
        current.home.id != base.home.id ||
        current.away.id != base.away.id ||
        current.season != base.season ||
        (base.capturedAt != null &&
            current.capturedAt!.isBefore(base.capturedAt!))) {
      return base;
    }
    return SportFixture(
      id: base.id,
      competition: base.competition,
      competitionName: base.competitionName,
      season: base.season,
      home: base.home,
      away: base.away,
      startsAt: current.startsAt,
      calendarDate: current.calendarDate,
      status: current.status,
      providerStatus: current.providerStatus,
      period: current.period,
      clock: current.clock,
      capturedAt: current.capturedAt,
      scores: current.scores,
      homeForm: base.homeForm,
      awayForm: base.awayForm,
      headToHead: base.headToHead,
      matchEvents: base.matchEvents,
      matchEventsCapturedAt: base.matchEventsCapturedAt,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
