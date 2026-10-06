import '../../../core/sports/domain/sport_competition_context.dart';
import 'hockey_standing_tiers.dart';

/// Compatibility facade. Display and readings share the Lector partition.
class HockeyTierPreview {
  static Map<String, int> classify(SportStandingTable table) =>
      HockeyStandingTiers.classify(table).tiers;
}
