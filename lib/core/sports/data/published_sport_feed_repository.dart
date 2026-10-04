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

class PublishedSportFeedRepository implements SportFeedRepository {
  const PublishedSportFeedRepository({required this.sport, this.source});
  @override
  final SportId sport;
  final SportPublicationSource? source;

  @override
  Future<SportFeedResult> load(DateTime selectedDate) async {
    if (source == null) {
      return const SportFeedResult.unavailable(
        SportFeedUnavailableReason.notConnected,
      );
    }
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
    final seen = <String>{};
    final fixtures = (json['items'] as List).map((raw) {
      final item = raw as Map<String, dynamic>;
      final matchId = id(SportEntityKind.match, item['id']);
      if (!seen.add(matchId.key) ||
          item['competitionId'] != competitionId ||
          item['season'] != season) {
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
      return SportFixture(
        id: matchId,
        competition: id(SportEntityKind.competition, item['competitionId']),
        competitionName: text(item['competitionName']),
        season: text(item['season']),
        home: participant(item['home'] as Map<String, dynamic>),
        away: participant(item['away'] as Map<String, dynamic>),
        startsAt: date(item['startsAt']),
        calendarDate: date(item['calendarDate']),
        status: SportFixtureStatus.values.byName(text(item['status'])),
        providerStatus: text(item['providerStatus']),
        scores: scores,
      );
    }).toList();
    final snapshot = SportSnapshot<SportFixture>(
      sport: sport,
      schemaVersion: json['schemaVersion'] as int,
      capturedAt: date(json['capturedAt']),
      windowStart: date(json['windowStart']),
      windowEnd: date(json['windowEnd']),
      items: fixtures,
      sportOf: (f) => f.sport,
    );
    if (fixtures.any((f) => !snapshot.covers(f.calendarDate!))) {
      throw const FormatException('Fixture outside publication window');
    }
    return snapshot;
  }
}
