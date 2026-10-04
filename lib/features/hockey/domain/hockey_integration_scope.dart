/// Requested scope, matched against the API audit captured on 2026-10-04.
/// These are integration targets, not enabled collection jobs. Season, phase,
/// scoring rules and endpoint coverage must be verified when connecting them.
class HockeyCompetitionTarget {
  const HockeyCompetitionTarget(this.providerId, this.name, this.country);
  final int providerId;
  final String name;
  final String country;
}

abstract final class HockeyIntegrationScope {
  static const targets = [
    HockeyCompetitionTarget(57, 'NHL', 'USA'),
    HockeyCompetitionTarget(58, 'AHL', 'USA'),
    HockeyCompetitionTarget(35, 'KHL', 'Russia'),
    HockeyCompetitionTarget(10, 'Extraliga', 'Czech-Republic'),
    HockeyCompetitionTarget(18, 'Ligue Magnus', 'France'),
    HockeyCompetitionTarget(16, 'Liiga', 'Finland'),
    HockeyCompetitionTarget(47, 'SHL', 'Sweden'),
  ];
}
