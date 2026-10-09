import '../../../core/sports/data/sport_publication_codec.dart';
import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_module.dart';
import 'hockey_feed_readings.dart';
import 'hockey_module.dart';

/// Publication uses the same engine as the screen, never another set of rules.
/// Compute on the trusted collection host, before uploading the public compact.
Map<String, dynamic> withHockeyPublicationReadings(
  Map<String, dynamic> payload,
) {
  final snapshot = SportPublicationCodec.decode(payload, SportId.hockey);
  const engine = HockeyFeedReadings();
  final labels = {
    for (final r in HockeyModule.definition.readings) r.id: r.label,
  };
  final byId = {
    for (final fixture in snapshot.items) fixture.id.value: fixture,
  };
  return {
    ...payload,
    'readingRulesVersion': engine.engine.rulesVersion,
    'items': [
      for (final raw in payload['items'] as List)
        {
          ...raw as Map<String, dynamic>,
          'readings': [
            for (final r in engine.evaluate(byId[raw['id']]!, snapshot))
              if (r.status == SportReadingStatus.detected)
                {
                  'id': r.id,
                  'label': labels[r.id] ?? r.id,
                  'subject': 'hockey:${r.subject.value}',
                  'subject_team_id': r.subject.value,
                  'side': r.subject == byId[raw['id']]!.home.id
                      ? 'home'
                      : 'away',
                  'sample_size': r.sampleSize,
                  'explanation': r.explanation,
                  'evidence': [
                    for (final entry in r.evidence.entries)
                      {'label': entry.key, 'value': '${entry.value}'},
                  ],
                },
          ],
        },
    ],
  };
}
