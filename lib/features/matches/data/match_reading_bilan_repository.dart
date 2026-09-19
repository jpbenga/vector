import 'package:supabase_flutter/supabase_flutter.dart';

class MatchReadingBilanEntry {
  const MatchReadingBilanEntry({
    required this.announcementId,
    required this.fixtureId,
    required this.kickoffAt,
    required this.readingId,
    required this.readingLabel,
    required this.verdict,
    required this.explanation,
    required this.announcementKind,
    this.subjectSide = 'match',
    required this.homeTeamName,
    required this.awayTeamName,
    this.homeGoals,
    this.awayGoals,
    this.outcomeRule,
    this.parentAnnouncementKey,
    this.evidence = const [],
    this.requiredReadingIds = const [],
  });

  factory MatchReadingBilanEntry.fromJson(Map<String, dynamic> row) {
    return MatchReadingBilanEntry(
      announcementId: row['announcement_id']?.toString() ?? '',
      fixtureId: (row['fixture_id'] as num?)?.toInt() ?? 0,
      kickoffAt:
          DateTime.tryParse(row['kickoff_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readingId: row['reading_id']?.toString() ?? '',
      readingLabel: row['reading_label']?.toString() ?? '',
      verdict: row['verdict']?.toString(),
      explanation: row['explanation']?.toString(),
      announcementKind: row['announcement_kind']?.toString() ?? 'reading',
      subjectSide: row['subject_side']?.toString() ?? 'match',
      homeTeamName: row['home_team_name']?.toString(),
      awayTeamName: row['away_team_name']?.toString(),
      homeGoals: (row['home_goals'] as num?)?.toInt(),
      awayGoals: (row['away_goals'] as num?)?.toInt(),
      outcomeRule: row['outcome_rule']?.toString(),
      parentAnnouncementKey: row['parent_announcement_key']?.toString(),
      evidence: row['evidence'] is List
          ? List<Map<String, Object?>>.unmodifiable(
              (row['evidence'] as List).whereType<Map<dynamic, dynamic>>().map(
                (item) =>
                    item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
          : const [],
      requiredReadingIds: row['required_reading_ids'] is List
          ? List<String>.unmodifiable(
              (row['required_reading_ids'] as List).map((id) => id.toString()),
            )
          : const [],
    );
  }

  final String announcementId;
  final int fixtureId;
  final DateTime kickoffAt;
  final String readingId;
  final String readingLabel;
  final String? verdict;
  final String? explanation;
  final String announcementKind;
  final String subjectSide;
  final String? homeTeamName;
  final String? awayTeamName;
  final int? homeGoals;
  final int? awayGoals;
  final String? outcomeRule;
  final String? parentAnnouncementKey;
  final List<Map<String, Object?>> evidence;
  final List<String> requiredReadingIds;

  bool get isEvaluable =>
      verdict == 'confirmed' ||
      verdict == 'contradicted' ||
      verdict == 'caution_confirmed' ||
      verdict == 'caution_not_confirmed';
  bool get hasResult => homeGoals != null && awayGoals != null;
  bool get isScenario => announcementKind == 'scenario';
}

class MatchReadingBilanSummary {
  const MatchReadingBilanSummary({
    required this.readingId,
    required this.readingLabel,
    required this.total,
    required this.confirmed,
    required this.contradicted,
    required this.notEvaluable,
    required this.contextOnly,
    this.evaluableOverride,
    this.confirmationRate,
    this.homeEvaluable = 0,
    this.homeConfirmed = 0,
    this.homeConfirmationRate,
    this.awayEvaluable = 0,
    this.awayConfirmed = 0,
    this.awayConfirmationRate,
    this.cautionConfirmed = 0,
    this.cautionNotConfirmed = 0,
    required this.pending,
  });

  factory MatchReadingBilanSummary.fromJson(Map<String, dynamic> row) =>
      MatchReadingBilanSummary(
        readingId: row['reading_id']?.toString() ?? '',
        readingLabel: row['reading_label']?.toString() ?? '',
        total: _integer(row['total']) ?? 0,
        confirmed: _integer(row['confirmed']) ?? 0,
        contradicted: _integer(row['contradicted']) ?? 0,
        notEvaluable: _integer(row['not_evaluable']) ?? 0,
        contextOnly: _integer(row['context_only']) ?? 0,
        evaluableOverride: _integer(row['evaluable']),
        confirmationRate: _decimal(row['confirmation_rate']),
        homeEvaluable: _integer(row['home_evaluable']) ?? 0,
        homeConfirmed: _integer(row['home_confirmed']) ?? 0,
        homeConfirmationRate: _decimal(row['home_confirmation_rate']),
        awayEvaluable: _integer(row['away_evaluable']) ?? 0,
        awayConfirmed: _integer(row['away_confirmed']) ?? 0,
        awayConfirmationRate: _decimal(row['away_confirmation_rate']),
        cautionConfirmed: _integer(row['caution_confirmed']) ?? 0,
        cautionNotConfirmed: _integer(row['caution_not_confirmed']) ?? 0,
        pending: _integer(row['pending']) ?? 0,
      );

  final String readingId;
  final String readingLabel;
  final int total;
  final int confirmed;
  final int contradicted;
  final int notEvaluable;
  final int contextOnly;
  final int? evaluableOverride;
  final double? confirmationRate;
  final int homeEvaluable;
  final int homeConfirmed;
  final double? homeConfirmationRate;
  final int awayEvaluable;
  final int awayConfirmed;
  final double? awayConfirmationRate;
  final int cautionConfirmed;
  final int cautionNotConfirmed;
  final int pending;

  int get evaluable => evaluableOverride ?? confirmed + contradicted;

  double? get confirmationPercent =>
      confirmationRate ?? (evaluable == 0 ? null : confirmed * 100 / evaluable);
}

int? _integer(Object? value) => switch (value) {
  int value => value,
  num value => value.toInt(),
  String value => int.tryParse(value),
  _ => null,
};

double? _decimal(Object? value) => switch (value) {
  num value => value.toDouble(),
  String value => double.tryParse(value),
  _ => null,
};

abstract interface class MatchReadingBilanRepository {
  Future<List<MatchReadingBilanSummary>> loadSummary({required DateTime since});
  Future<List<MatchReadingBilanEntry>> loadForReading({
    required String readingId,
    required DateTime since,
    String? verdict,
    required int offset,
    required int limit,
  });
  Future<List<MatchReadingBilanEntry>> loadForFixture(int fixtureId);
}

class SupabaseMatchReadingBilanRepository
    implements MatchReadingBilanRepository {
  const SupabaseMatchReadingBilanRepository(this.client);

  final SupabaseClient client;

  static const _columns =
      'announcement_id,fixture_id,kickoff_at,reading_id,reading_label,'
      'verdict,explanation,home_team_name,away_team_name,home_goals,'
      'away_goals,outcome_rule,evidence,announcement_kind,required_reading_ids,'
      'parent_announcement_key,subject_side';

  @override
  Future<List<MatchReadingBilanSummary>> loadSummary({
    required DateTime since,
  }) async {
    final rows = await client.rpc<List<dynamic>>(
      'match_reading_bilan_reading_summary',
      params: {
        'p_since': since.toUtc().toIso8601String(),
        'p_until': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(MatchReadingBilanSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<MatchReadingBilanEntry>> loadForReading({
    required String readingId,
    required DateTime since,
    String? verdict,
    required int offset,
    required int limit,
  }) async {
    var query = client
        .from('match_reading_bilan')
        .select(_columns)
        .eq('reading_id', readingId)
        .gte('kickoff_at', since.toUtc().toIso8601String())
        .lte('kickoff_at', DateTime.now().toUtc().toIso8601String());
    if (verdict != null) query = query.eq('verdict', verdict);
    final rows = await query
        .order('kickoff_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(MatchReadingBilanEntry.fromJson).toList(growable: false);
  }

  @override
  Future<List<MatchReadingBilanEntry>> loadForFixture(int fixtureId) async {
    final rows = await client
        .from('match_reading_bilan')
        .select(_columns)
        .eq('fixture_id', fixtureId)
        .order('reading_label');
    return rows.map(MatchReadingBilanEntry.fromJson).toList(growable: false);
  }
}
