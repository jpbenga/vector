import '../../generator/domain/generator_context.dart';

class ShortlistFixture {
  ShortlistFixture(this.json);
  final Map<String, dynamic> json;
  String get sport => json['sport'].toString();
  String get fixtureId => json['fixtureId'].toString();
  String get key => '$sport:$fixtureId';
  String get home => json['home']?.toString() ?? 'Équipe à confirmer';
  String get away => json['away']?.toString() ?? 'Équipe à confirmer';
  DateTime? get kickoff => DateTime.tryParse(json['kickoff']?.toString() ?? '');
  String get date =>
      json['date']?.toString() ??
      generatorDay(kickoff?.toLocal() ?? DateTime.now());
  bool get available => json['available'] != false && kickoff != null;
  String phase(DateTime now) {
    final status = json['status']?.toString().toLowerCase();
    if (!available) return 'unavailable';
    if ([
      'ft',
      'aet',
      'pen',
      'finished',
      'aot',
      'ap',
      'apen',
    ].contains(status)) {
      return 'finished';
    }
    if ([
      'pst',
      'canc',
      'postponed',
      'cancelled',
      'abd',
      'unknown',
    ].contains(status)) {
      return 'other';
    }
    if (['ns', 'scheduled'].contains(status) && kickoff!.isAfter(now)) {
      return 'upcoming';
    }
    if ([
          'live',
          '1h',
          '2h',
          'ht',
          'et',
          'bt',
          'p1',
          'p2',
          'p3',
          'ot',
          'in1',
          'in2',
          'pt',
          'p',
        ].contains(status) ||
        !kickoff!.isAfter(now)) {
      return 'live';
    }
    return 'other';
  }

  Map<String, dynamic> get navigation => {
    ...json,
    'matchId':
        json['matchId'] ??
        (sport == 'football'
            ? 'api-fixture-$fixtureId'
            : 'hockey:api-hockey:match:$fixtureId'),
  };
}

class ShortlistSession {
  ShortlistSession(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  int get revision => (json['revision'] as num).toInt();
  DateTime get expiresAt => DateTime.parse(json['expiresAt'].toString());
  DateTime get recoverableUntil =>
      DateTime.parse(json['recoverableUntil'].toString());
  bool active(DateTime now) => expiresAt.isAfter(now);
  List<ShortlistFixture> get items => generatorRows(json['items'])
      .map(
        (i) => ShortlistFixture({
          ...generatorMap(i['fixture']),
          'key': i['key'],
          'sport': i['sport'],
          'fixtureId': i['fixtureId'],
          'date': i['date'],
          'available': i['fixture'] != null,
        }),
      )
      .toList();
  Map<String, Object?> reference(Iterable<String> keys) => {
    'sessionId': id,
    'revision': revision,
    'keys': keys.toList(),
  };
}

class ShortlistSnapshot {
  ShortlistSnapshot(this.json);
  final Map<String, dynamic> json;
  DateTime get serverNow => DateTime.parse(json['serverNow'].toString());
  List<ShortlistSession> get sessions =>
      generatorRows(json['sessions']).map(ShortlistSession.new).toList();
  ShortlistSession? active(DateTime now) =>
      sessions.where((s) => s.active(now)).firstOrNull;
  List<ShortlistSession> recoverable(DateTime now) => sessions
      .where((s) => !s.active(now) && s.recoverableUntil.isAfter(now))
      .toList();
}
