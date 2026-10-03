import '../../../core/theme/app_theme_controller.dart';

enum AppearanceThemeFamily {
  all('Tous'),
  light('Clairs'),
  dark('Sombres'),
  colorful('Colorés');

  const AppearanceThemeFamily(this.label);
  final String label;

  bool includes(AppThemeVariant variant) => switch (this) {
    all => true,
    light => variant.isLight,
    dark => !variant.isLight,
    colorful =>
      variant != AppThemeVariant.vectorDark &&
          variant != AppThemeVariant.vectorLight &&
          variant != AppThemeVariant.quietLight,
  };
}

extension AppearanceThemeDescription on AppThemeVariant {
  String get appearanceLabel => switch (this) {
    AppThemeVariant.vectorDark => 'Lector Dark',
    AppThemeVariant.vectorLight => 'Lector Light',
    AppThemeVariant.gold => 'Lector Gold',
    AppThemeVariant.aurora => 'Lector Aurora',
    _ => label,
  };

  String get appearanceDescription => switch (this) {
    AppThemeVariant.vectorDark => 'L’identité Lector, sombre',
    AppThemeVariant.vectorLight => 'L’identité Lector, claire',
    AppThemeVariant.gold => 'Des accents chaleureux',
    AppThemeVariant.aurora => 'Une ambiance lumineuse',
    AppThemeVariant.dracula => 'Violet et contrasté',
    AppThemeVariant.tokyoNight => 'Une nuit aux accents bleus',
    AppThemeVariant.catppuccinMocha => 'Des couleurs douces, sombres',
    AppThemeVariant.catppuccinLatte => 'Des couleurs douces, claires',
    AppThemeVariant.solarizedLight => 'Une lumière chaleureuse',
    AppThemeVariant.quietLight => 'Clair et discret',
  };
}
