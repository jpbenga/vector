import '../../data/navigation_feed_cache.dart';
import '../../data/published_feed_delivery.dart';
import '../../data/retained_async_value.dart';
import '../../domain/lector_head_to_head_policy.dart';
import '../domain/sport_player_activity.dart';
import '../domain/sport_match_history.dart';
import '../domain/sport_competition_context.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/sport.dart';
import '../domain/sport_feed_repository.dart';
import '../domain/sport_fixture.dart';
import '../domain/sport_snapshot.dart';

abstract interface class SportPublicationSource {
  Future<Map<String, dynamic>?> read(SportId sport);
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
      throw StateError('Publication service unavailable');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

/// Public table reader uses the public project key explicitly, so an expired
/// account JWT cannot block access to public sport publications.
class SupabaseSportPublicationSource implements SportPublicationSource {
  SupabaseSportPublicationSource({
    required this.projectUrl,
    required this.publicKey,
  });
  final Uri projectUrl;
  final String publicKey;
  @override
  Future<Map<String, dynamic>?> read(SportId sport) async {
    final url = projectUrl
        .resolve('/rest/v1/sport_feed_publications')
        .replace(
          queryParameters: {
            'sport': 'eq.${sport.key}',
            'select': 'payload',
            'order': 'captured_at.desc',
            'limit': '1',
          },
        );
    final response = await http
        .get(url, headers: {'apikey': publicKey})
        .timeout(const Duration(seconds: 10));
    // Table may not be installed while the module is being prepared locally.
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError('Sport publication service unavailable');
    }
    final rows = jsonDecode(response.body) as List;
    return rows.isEmpty
        ? null
        : (rows.first as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
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
      for (final day in days.take(3))
        () async {
          await load(day);
        },
      if (days.isNotEmpty)
        () async {
          await loadRadar(date);
        },
      for (final day in days.skip(3))
        () async {
          await load(day);
        },
    ]);
  }

  Future<SportFeedResult> _loadDay(DateTime selectedDate) async {
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

abstract final class SportPublicationCodec {
  static SportSnapshot<SportFixture> decode(
    Map<String, dynamic> json,
    SportId sport,
  ) {
    if (json['schemaVersion'] != 1 || json['sport'] != sport.key) {
      throw const FormatException('Unsupported sport publication');
    }
    String text(dynamic value) {
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Missing publication text');
      }
      return value;
    }

    final provider = text(json['provider']);
    final competitionId = text(json['competitionId']);
    final season = text(json['season']);
    SportEntityId id(SportEntityKind kind, dynamic value) => SportEntityId(
      sport: sport,
      provider: provider,
      kind: kind,
      value: text(value),
    );
    DateTime date(dynamic value) => DateTime.parse(text(value));
    SportParticipant participant(Map<String, dynamic> value) =>
        SportParticipant(
          id: id(SportEntityKind.team, value['id']),
          name: text(value['name']),
          logoUrl: value['logoUrl'] as String?,
        );
    final capturedAt = date(json['capturedAt']);
    List<SportFormResult> form(
      dynamic raw, {
      DateTime? before,
      int? maximum = 5,
    }) {
      final results = ((raw as List?) ?? const []).map((value) {
        final r = value as Map<String, dynamic>;
        final scored = r['scored'] as int, conceded = r['conceded'] as int;
        final outcome = SportFormOutcome.values.byName(text(r['outcome']));
        if (scored < 0 ||
            conceded < 0 ||
            outcome !=
                (scored > conceded
                    ? SportFormOutcome.win
                    : scored < conceded
                    ? SportFormOutcome.loss
                    : SportFormOutcome.draw)) {
          throw const FormatException('Invalid form result');
        }
        return SportFormResult(
          matchId: id(SportEntityKind.match, r['id']),
          startsAt: date(r['startsAt']),
          opponent: text(r['opponent']),
          home: r['home'] as bool,
          scored: scored,
          conceded: conceded,
          outcome: outcome,
          providerStatus: text(r['providerStatus']),
        );
      }).toList();
      final cutoff = before ?? capturedAt;
      final ids = <String>{};
      DateTime? previous;
      for (final result in results) {
        if (!ids.add(result.matchId.key) ||
            !result.startsAt.isBefore(cutoff) ||
            (previous != null && result.startsAt.isBefore(previous))) {
          throw const FormatException('Invalid form chronology');
        }
        previous = result.startsAt;
      }
      if (maximum != null && results.length > maximum) {
        throw const FormatException('Invalid form window');
      }
      return results;
    }

    int count(dynamic n) {
      if (n is! int || n < 0) {
        throw const FormatException('Invalid hockey count');
      }
      return n;
    }

    SportVenueStandings? venue(dynamic raw, List<SportStandingTable> tables) {
      if (raw == null) return null;
      final v = raw as Map<String, dynamic>;
      final calculated = v['source'] == 'season-games';
      if (calculated &&
          !['reconciled', 'partial', 'unsupported'].contains(v['status'])) {
        throw const FormatException('Invalid calculated venue coverage');
      }
      List<SportVenueStandingRow> rows(dynamic rawRows) {
        final seen = <String>{};
        return (rawRows as List).map((value) {
          final r = value as Map<String, dynamic>,
              team = participant(r['team'] as Map<String, dynamic>);
          final played = count(r['played']),
              wins = count(r['wins']),
              losses = count(r['losses']);
          if (!seen.add(team.id.key) || wins + losses > played) {
            throw const FormatException('Invalid venue standings');
          }
          final points = r['points'] == null ? null : count(r['points']);
          final overtimeWins = r['overtimeWins'] == null
              ? null
              : count(r['overtimeWins']);
          final overtimeLosses = r['overtimeLosses'] == null
              ? null
              : count(r['overtimeLosses']);
          if (calculated &&
              (points == null ||
                  overtimeWins == null ||
                  overtimeLosses == null ||
                  wins + losses != played ||
                  overtimeWins > wins ||
                  overtimeLosses > losses ||
                  points > 3 * played ||
                  !tables.any(
                    (t) => t.rows.any((row) => row.team.id == team.id),
                  ))) {
            throw const FormatException('Invalid calculated venue row');
          }
          return SportVenueStandingRow(
            team: team,
            rank: count(r['rank']),
            played: played,
            wins: wins,
            losses: losses,
            goalsFor: count(r['goalsFor']),
            goalsAgainst: count(r['goalsAgainst']),
            points: points,
            overtimeWins: overtimeWins,
            overtimeLosses: overtimeLosses,
          );
        }).toList();
      }

      final at = date(v['collectedAt']);
      if (at.isAfter(capturedAt)) {
        throw const FormatException('Future venue collection');
      }
      final home = rows(v['home']), away = rows(v['away']);
      if (calculated && v['status'] == 'reconciled') {
        final unique = {
          for (final t in tables.where((t) => t.stage == v['phase']))
            for (final r in t.rows) r.team.id: r,
        };
        if (home.length != unique.length || away.length != unique.length) {
          throw const FormatException('Incomplete calculated venue standings');
        }
        for (final official in unique.values) {
          final h = home
              .where((r) => r.team.id == official.team.id)
              .firstOrNull;
          final a = away
              .where((r) => r.team.id == official.team.id)
              .firstOrNull;
          if (h == null ||
              a == null ||
              h.played + a.played != official.played ||
              h.points! + a.points! != official.points ||
              h.wins + a.wins - h.overtimeWins! - a.overtimeWins! !=
                  official.wins ||
              h.losses + a.losses - h.overtimeLosses! - a.overtimeLosses! !=
                  official.losses ||
              h.overtimeWins! + a.overtimeWins! != official.overtimeWins ||
              h.overtimeLosses! + a.overtimeLosses! !=
                  official.overtimeLosses ||
              (official.goalsFor != null &&
                  h.goalsFor + a.goalsFor != official.goalsFor) ||
              (official.goalsAgainst != null &&
                  h.goalsAgainst + a.goalsAgainst != official.goalsAgainst)) {
            throw const FormatException(
              'Calculated venue totals differ from official standings',
            );
          }
        }
      }
      return SportVenueStandings(
        collectedAt: at,
        home: home,
        away: away,
        source: v['source'] as String?,
        status: v['status'] as String?,
        phase: v['phase'] as String?,
        unavailableTeams: (v['unavailableTeams'] as List).map(text),
      );
    }

    SportStandingContext? standingContext(
      dynamic raw,
      List<SportStandingTable> tables,
      SportVenueStandings? venue,
    ) {
      if (raw == null) return null;
      final c = raw as Map<String, dynamic>;
      final phase = text(c['phase']), at = date(c['collectedAt']);
      final maximum = c['maximumPoints'] == null
          ? null
          : count(c['maximumPoints']);
      if (c['source'] != 'reconciled-season-games' ||
          at.isAfter(capturedAt) ||
          venue == null ||
          venue.phase != phase ||
          venue.collectedAt != at ||
          (maximum != null && maximum != 2 && maximum != 3)) {
        throw const FormatException('Invalid standing context');
      }
      if (maximum != null &&
          venue.status == 'reconciled' &&
          tables
              .where((t) => t.stage == phase)
              .any(
                (t) => t.rows.any(
                  (r) =>
                      r.points !=
                      r.wins * maximum +
                          (r.overtimeWins ?? 0) * 2 +
                          (r.overtimeLosses ?? 0),
                ),
              )) {
        throw const FormatException(
          'Standing barème disagrees with official points',
        );
      }
      final seen = <int>{};
      final groups = (c['groups'] as List).map((value) {
        final g = value as Map<String, dynamic>, index = count(g['tableIndex']);
        final parent = g['parentTableIndex'] == null
            ? null
            : count(g['parentTableIndex']);
        if (!seen.add(index) ||
            index >= tables.length ||
            tables[index].stage != phase ||
            (parent != null &&
                (parent >= tables.length ||
                    tables[parent].stage != phase ||
                    tables[parent].rows.length <= tables[index].rows.length ||
                    !tables[index].rows.every(
                      (r) => tables[parent].rows.any(
                        (p) => p.team.id == r.team.id,
                      ),
                    )))) {
          throw const FormatException('Invalid standing group hierarchy');
        }
        SportGroupResults? results(dynamic raw) {
          if (raw == null) return null;
          if (venue.status != 'reconciled' || maximum == null) {
            throw const FormatException('Unverified group comparison');
          }
          final r = raw as Map<String, dynamic>;
          final played = count(r['played']), points = count(r['points']);
          if (points > played * maximum ||
              played >
                  tables[index].rows.fold<int>(0, (n, r) => n + r.played)) {
            throw const FormatException('Invalid inter-group totals');
          }
          return SportGroupResults(
            played: played,
            points: points,
            goalsFor: count(r['goalsFor']),
            goalsAgainst: count(r['goalsAgainst']),
          );
        }

        final all = results(g['all']),
            home = results(g['home']),
            away = results(g['away']);
        if ((all == null || home == null || away == null)
            ? !(all == null && home == null && away == null)
            : home.played + away.played != all.played ||
                  home.points + away.points != all.points ||
                  home.goalsFor + away.goalsFor != all.goalsFor ||
                  home.goalsAgainst + away.goalsAgainst != all.goalsAgainst) {
          throw const FormatException('Inconsistent inter-group scopes');
        }
        return SportStandingGroupContext(
          tableIndex: index,
          kind: SportStandingGroupKind.values.byName(text(g['kind'])),
          parentTableIndex: parent,
          all: all,
          home: home,
          away: away,
        );
      }).toList();
      for (final group in groups.where((g) => g.all != null)) {
        final own = tables[group.tableIndex].rows.map((r) => r.team.id).toSet();
        if (groups.any(
          (peer) =>
              peer != group &&
              peer.kind == group.kind &&
              tables[peer.tableIndex].rows.any((r) => own.contains(r.team.id)),
        )) {
          throw const FormatException('Overlapping standing groups');
        }
      }
      final expected = tables.indexed
          .where((t) => t.$2.stage == phase && t.$2.rows.isNotEmpty)
          .map((t) => t.$1)
          .toSet();
      if (!seen.containsAll(expected) || seen.length != expected.length) {
        throw const FormatException('Incomplete standing context');
      }
      return SportStandingContext(
        phase: phase,
        collectedAt: at,
        maximumPoints: maximum,
        groups: groups,
      );
    }

    final competitions = ((json['competitions'] as List?) ?? const []).map((
      value,
    ) {
      final c = value as Map<String, dynamic>;
      final tables = (c['tables'] as List).map((value) {
        final t = value as Map<String, dynamic>;
        final teamIds = <String>{};
        final rows = (t['rows'] as List).map((value) {
          final r = value as Map<String, dynamic>;
          final team = participant(r['team'] as Map<String, dynamic>);
          if (!teamIds.add(team.id.key) ||
              [
                'rank',
                'played',
                'points',
                'wins',
                'overtimeWins',
                'losses',
                'overtimeLosses',
              ].any((key) => r[key] is! int || (r[key] as int) < 0)) {
            throw const FormatException('Invalid standing row');
          }
          final recent = form(r['form']);
          final history = r['formHistory'] == null
              ? recent
              : form(r['formHistory'], maximum: null);
          final tail = history
              .skip((history.length - 5).clamp(0, history.length))
              .toList();
          if (tail.length != recent.length ||
              List.generate(recent.length, (i) => i).any(
                (i) =>
                    tail[i].matchId != recent[i].matchId ||
                    tail[i].startsAt != recent[i].startsAt ||
                    tail[i].scored != recent[i].scored ||
                    tail[i].conceded != recent[i].conceded ||
                    tail[i].home != recent[i].home ||
                    tail[i].opponent != recent[i].opponent ||
                    tail[i].providerStatus != recent[i].providerStatus,
              )) {
            throw const FormatException('Inconsistent team form history');
          }
          return SportStandingRow(
            team: team,
            rank: r['rank'] as int,
            played: r['played'] as int,
            points: r['points'] as int,
            wins: r['wins'] as int,
            overtimeWins: r['overtimeWins'] as int,
            losses: r['losses'] as int,
            overtimeLosses: r['overtimeLosses'] as int,
            goalsFor: r['goalsFor'] == null ? null : count(r['goalsFor']),
            goalsAgainst: r['goalsAgainst'] == null
                ? null
                : count(r['goalsAgainst']),
            description: r['description'] as String?,
            form: recent,
            formHistory: history,
          );
        }).toList();
        return SportStandingTable(
          stage: text(t['stage']),
          group: text(t['group']),
          rows: rows,
        );
      }).toList();
      final venueData = venue(c['venueStandings'], tables);
      return SportCompetitionContext(
        id: id(SportEntityKind.competition, c['id']),
        name: text(c['name']),
        season: text(c['season']),
        country: text(c['country']),
        countryCode: c['countryCode'] as String?,
        countryFlagUrl: c['countryFlagUrl'] as String?,
        logoUrl: c['logoUrl'] as String?,
        formPhaseVerified: c['formPhaseVerified'] as bool,
        tables: tables,
        venueStandings: venueData,
        standingContext: standingContext(
          c['standingContext'],
          tables,
          venueData,
        ),
      );
    }).toList();
    final competitionSeasons = <String, String>{};
    for (final c in competitions) {
      if (competitionSeasons.containsKey(c.id.value)) {
        throw const FormatException('Duplicate competition');
      }
      competitionSeasons[c.id.value] = c.season;
    }
    SportMatchHistory? history(
      dynamic raw,
      Map<String, dynamic> fixture,
      DateTime cutoff,
    ) {
      if (raw == null) return null;
      final h = raw as Map<String, dynamic>, at = date(h['collectedAt']);
      if (at.isAfter(capturedAt)) {
        throw const FormatException('Future history collection');
      }
      final pair = {
        (fixture['home'] as Map)['id'],
        (fixture['away'] as Map)['id'],
      };
      final seen = <String>{};
      final lower = DateTime.utc(
        cutoff.year - 3,
        cutoff.month,
        cutoff.day,
        cutoff.hour,
        cutoff.minute,
        cutoff.second,
      );
      final meetings = (h['meetings'] as List).map((value) {
        final m = value as Map<String, dynamic>,
            home = participant(m['home'] as Map<String, dynamic>),
            away = participant(m['away'] as Map<String, dynamic>),
            start = date(m['startsAt']);
        if (!seen.add(text(m['id'])) ||
            m['id'] == fixture['id'] ||
            home.id == away.id ||
            !pair.contains(home.id.value) ||
            !pair.contains(away.id.value) ||
            !start.isBefore(cutoff) ||
            start.isBefore(lower) ||
            m['status'] != 'finished') {
          throw const FormatException('Invalid history identity or chronology');
        }
        final scores = (m['scores'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(
            SportScoreScope(k),
            SportScore(home: count((v as Map)['home']), away: count(v['away'])),
          ),
        );
        if (!scores.containsKey(SportScoreScope.finalResult)) {
          throw const FormatException('Historical game without final score');
        }
        final collected = m['eventsCollected'] as bool;
        final events = (m['events'] as List).map((value) {
          final e = value as Map<String, dynamic>,
              period = text(e['period']),
              minute = e['minute'] == null ? null : count(e['minute']),
              elapsed = e['elapsed'] == null ? null : count(e['elapsed']),
              team = text(e['teamId']);
          const offsets = {'P1': 0, 'P2': 20, 'P3': 40, 'OT': 60};
          if (!collected ||
              !pair.contains(team) ||
              !offsets.containsKey(period) ||
              (minute == null
                  ? elapsed != null
                  : elapsed != offsets[period]! + minute) ||
              (period != 'OT' && minute != null && minute > 20)) {
            throw const FormatException('Invalid hockey event clock');
          }
          return SportMatchEvent(
            period: period,
            minute: minute,
            elapsed: elapsed,
            teamId: team,
            type: text(e['type']),
            detail: e['detail'] as String,
            players: (e['players'] as List).map(text),
            assists: (e['assists'] as List).map(text),
          );
        }).toList();
        return SportHistoricalMatch(
          competitionPhase: m['competitionPhase'] as String?,
          competitionKind: LectorHeadToHeadPolicy.classifyHockey(
            name: text(m['competitionName']),
            competitionId: '${m['competitionId']}',
            playedAt: start,
            phase: m['competitionPhase'] as String?,
            declaredKind: m['competitionKind'] == null
                ? LectorMeetingKind.unknown
                : LectorMeetingKind.values.byName(text(m['competitionKind'])),
          ),
          fixture: SportFixture(
            id: id(SportEntityKind.match, m['id']),
            competition: id(SportEntityKind.competition, m['competitionId']),
            competitionName: text(m['competitionName']),
            season: text(m['season']),
            home: home,
            away: away,
            startsAt: start,
            status: SportFixtureStatus.finished,
            providerStatus: text(m['providerStatus']),
            scores: scores,
          ),
          eventsCollected: collected,
          eventDataIssue: m['eventDataIssue'] as String?,
          events: events,
        );
      }).toList();
      if (meetings.length > 24) {
        throw const FormatException('Invalid history window');
      }
      return SportMatchHistory(collectedAt: at, meetings: meetings);
    }

    final seen = <String>{};
    final fixtures = (json['items'] as List).map((raw) {
      final item = raw as Map<String, dynamic>;
      final matchId = id(SportEntityKind.match, item['id']);
      if (!seen.add(matchId.key) ||
          (competitions.isEmpty
              ? item['competitionId'] != competitionId ||
                    item['season'] != season
              : competitionSeasons[item['competitionId']] != item['season'])) {
        throw const FormatException(
          'Duplicate or mixed publication identities',
        );
      }
      final scores = (item['scores'] as Map<String, dynamic>).map((
        scope,
        rawScore,
      ) {
        final score = rawScore as Map<String, dynamic>;
        return MapEntry(
          SportScoreScope(scope),
          SportScore(home: score['home'] as int, away: score['away'] as int),
        );
      });
      final startsAt = date(item['startsAt']);
      final cutoff = startsAt.isBefore(capturedAt) ? startsAt : capturedAt;
      final homeForm = form(
        (item['recentForm'] as Map<String, dynamic>?)?['home'],
        before: cutoff,
      );
      final awayForm = form(
        (item['recentForm'] as Map<String, dynamic>?)?['away'],
        before: cutoff,
      );
      if ([...homeForm, ...awayForm].any((r) => r.matchId == matchId)) {
        throw const FormatException('Match leaks into own form');
      }
      final currentEvents = item['matchEvents'] as Map<String, dynamic>?;
      final eventRows = <SportMatchEvent>[];
      for (final raw in currentEvents?['events'] as List? ?? const []) {
        final e = raw as Map<String, dynamic>;
        final period = text(e['period']), team = text(e['teamId']);
        final minute = e['minute'] == null ? null : count(e['minute']);
        final elapsed = e['elapsed'] == null ? null : count(e['elapsed']);
        const offsets = {'P1': 0, 'P2': 20, 'P3': 40, 'OT': 60};
        if (![
              text((item['home'] as Map)['id']),
              text((item['away'] as Map)['id']),
            ].contains(team) ||
            !offsets.containsKey(period) ||
            (minute == null
                ? elapsed != null
                : elapsed != offsets[period]! + minute) ||
            (period != 'OT' && minute != null && minute > 20)) {
          throw const FormatException('Invalid selected match event');
        }
        eventRows.add(
          SportMatchEvent(
            period: period,
            minute: minute,
            elapsed: elapsed,
            teamId: team,
            type: text(e['type']),
            detail: e['detail'] as String,
            players: (e['players'] as List).map(text),
            assists: (e['assists'] as List).map(text),
          ),
        );
      }
      return SportFixture(
        id: matchId,
        competition: id(SportEntityKind.competition, item['competitionId']),
        competitionName: text(item['competitionName']),
        season: text(item['season']),
        home: participant(item['home'] as Map<String, dynamic>),
        away: participant(item['away'] as Map<String, dynamic>),
        startsAt: startsAt,
        calendarDate: date(item['calendarDate']),
        status: SportFixtureStatus.values.byName(text(item['status'])),
        providerStatus: text(item['providerStatus']),
        period: item['period'] as String?,
        clock: item['clock'] as String?,
        capturedAt: capturedAt,
        scores: scores,
        headToHead: history(item['headToHead'], item, cutoff),
        matchEvents: eventRows,
        matchEventsCapturedAt: currentEvents == null
            ? null
            : date(currentEvents['collectedAt']),
        homeForm: homeForm,
        awayForm: awayForm,
      );
    }).toList();
    final playerRadar = json['playerRadar'] as Map<String, dynamic>?;
    final coverage = ((playerRadar?['coverage'] as List?) ?? const []).map((
      raw,
    ) {
      final r = raw as Map<String, dynamic>;
      final competition = id(SportEntityKind.competition, r['competitionId']);
      if (!competitionSeasons.containsKey(competition.value)) {
        throw const FormatException('Unknown player radar competition');
      }
      return SportPlayerRadarCoverage(
        competition: competition,
        team: id(SportEntityKind.team, r['teamId']),
        status: text(r['status']),
        history: r['history'] == null
            ? null
            : List.unmodifiable(form(r['history'], maximum: null)),
      );
    }).toList();
    final playerIds = <String>{};
    final players = ((playerRadar?['profiles'] as List?) ?? const []).map((
      raw,
    ) {
      final p = raw as Map<String, dynamic>;
      final competition = id(SportEntityKind.competition, p['competitionId']);
      final team = participant(p['team'] as Map<String, dynamic>);
      final playerId = id(SportEntityKind.player, p['id']);
      final c = competitions.where((c) => c.id == competition).firstOrNull;
      if (!playerIds.add(playerId.key) ||
          c == null ||
          !c.formPhaseVerified ||
          p['season'] != c.season ||
          p['identitySource'] != 'event-name' ||
          !coverage.any(
            (r) =>
                r.competition == competition &&
                r.team == team.id &&
                r.status == 'complete',
          )) {
        throw const FormatException(
          'Invalid player radar identity or coverage',
        );
      }
      final rawActivity = p['activity'] as List;
      final results = form(rawActivity, maximum: null);
      if (results.length < 3) {
        throw const FormatException('Incomplete player activity');
      }
      final standing = c.tables
          .expand((t) => t.rows)
          .where((r) => r.team.id == team.id)
          .firstOrNull;
      if (standing == null ||
          standing.form.length < 3 ||
          results.skip(results.length - 3).indexed.any((r) {
            final expected = standing.form[standing.form.length - 3 + r.$1];
            return r.$2.matchId != expected.matchId ||
                r.$2.startsAt != expected.startsAt ||
                r.$2.home != expected.home ||
                r.$2.opponent != expected.opponent ||
                r.$2.scored != expected.scored ||
                r.$2.conceded != expected.conceded ||
                r.$2.providerStatus != expected.providerStatus;
          })) {
        throw const FormatException(
          'Player activity is not the last three team games',
        );
      }
      final teamHistory = coverage
          .where(
            (r) =>
                r.competition == competition &&
                r.team == team.id &&
                r.status == 'complete',
          )
          .first
          .history;
      bool sameResult(SportFormResult a, SportFormResult b) =>
          a.matchId == b.matchId &&
          a.startsAt == b.startsAt &&
          a.home == b.home &&
          a.opponent == b.opponent &&
          a.scored == b.scored &&
          a.conceded == b.conceded &&
          a.providerStatus == b.providerStatus;
      if ((results.length > 3 && teamHistory == null) ||
          (teamHistory != null &&
              (results.length != teamHistory.length ||
                  results.indexed.any(
                    (r) => !sameResult(r.$2, teamHistory[r.$1]),
                  )))) {
        throw const FormatException(
          'Player activity is not the collected team history',
        );
      }
      final activity = results.indexed.map((r) {
        final rawMatch = rawActivity[r.$1] as Map<String, dynamic>;
        final unknown =
            rawMatch['goals'] == null && rawMatch['assists'] == null;
        if ((rawMatch['goals'] == null) != (rawMatch['assists'] == null) ||
            (unknown && r.$1 >= results.length - 3)) {
          throw const FormatException('Incomplete recent player contributions');
        }
        final goals = unknown ? null : count(rawMatch['goals']);
        final assists = unknown ? null : count(rawMatch['assists']);
        if (!unknown &&
            (goals! > r.$2.scored ||
                assists! > r.$2.scored ||
                goals + assists > r.$2.scored)) {
          throw const FormatException('Impossible player contributions');
        }
        return SportPlayerMatchActivity(
          result: r.$2,
          goals: goals,
          assists: assists,
        );
      }).toList();
      return SportPlayerProfile(
        id: playerId,
        name: text(p['name']),
        competition: competition,
        season: text(p['season']),
        team: team,
        identitySource: text(p['identitySource']),
        activity: activity,
      );
    }).toList();
    final snapshot = SportSnapshot<SportFixture>(
      sport: sport,
      schemaVersion: json['schemaVersion'] as int,
      capturedAt: capturedAt,
      windowStart: date(json['windowStart']),
      windowEnd: date(json['windowEnd']),
      items: fixtures,
      competitions: competitions,
      players: players,
      playerRadarCoverage: coverage,
      sportOf: (f) => f.sport,
    );
    if (fixtures.any((f) => !snapshot.covers(f.calendarDate!))) {
      throw const FormatException('Fixture outside publication window');
    }
    return snapshot;
  }
}
