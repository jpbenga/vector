import '../../../core/sports/domain/sport_competition_context.dart';

/// Display labels only; competition affiliation remains the provider's country.
String hockeyCountryLabel(SportCompetitionContext c) => switch (c.country) {
  'USA' || 'United States' => 'États-Unis',
  'Russia' => 'Russie',
  'Czech Republic' || 'Czech-Republic' || 'Czechia' => 'République tchèque',
  'Finland' => 'Finlande',
  'Sweden' => 'Suède',
  'Canada' => 'Canada',
  _ => c.country.isEmpty ? 'International' : c.country,
};
String? hockeyCountryFlag(SportCompetitionContext c) {
  if (c.countryFlagUrl?.isNotEmpty == true) return c.countryFlagUrl;
  // Compatible with publications captured before the country asset was included.
  final code =
      c.countryCode ??
      switch (c.country) {
        'USA' || 'United States' => 'us',
        'Russia' => 'ru',
        'Czech Republic' || 'Czech-Republic' || 'Czechia' => 'cz',
        'Finland' => 'fi',
        'Sweden' => 'se',
        'France' => 'fr',
        'Canada' => 'ca',
        _ => null,
      };
  return code == null
      ? null
      : 'https://media.api-sports.io/flags/${code.toLowerCase()}.svg';
}
