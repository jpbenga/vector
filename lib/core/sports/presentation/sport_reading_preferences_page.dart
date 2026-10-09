import 'package:flutter/material.dart';
import '../../widgets/lector_glass_card.dart';
import '../../widgets/lector_responsive_layout.dart';
import '../../widgets/sports_asset_badge.dart';
import '../domain/sport_module.dart';
import '../domain/sport_competition_context.dart';
import '../domain/sport_reading_preferences.dart';

enum SportPreferenceSection { all, competitions, readings, markets }

/// Shared preference editor; the sport module supplies its catalogue and rules.
class SportReadingPreferencesPage extends StatefulWidget {
  const SportReadingPreferencesPage({
    required this.module,
    required this.competitions,
    required this.initial,
    required this.onSave,
    this.section = SportPreferenceSection.all,
    super.key,
  });
  final SportModuleDefinition module;
  final List<SportCompetitionContext> competitions;
  final SportReadingPreferences initial;
  final Future<bool> Function(SportReadingPreferences) onSave;
  final SportPreferenceSection section;

  @override
  State<SportReadingPreferencesPage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<SportReadingPreferencesPage> {
  late final _competitions = {...widget.initial.competitionKeys};
  late final _readings = {...widget.initial.readingIds};
  late final _markets = {...widget.initial.marketIds};
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${switch (widget.section) {
          SportPreferenceSection.all => 'Mes préférences',
          SportPreferenceSection.competitions => 'Mes compétitions',
          SportPreferenceSection.readings => 'Mes lectures',
          SportPreferenceSection.markets => 'Mes marchés',
        }} · ${widget.module.sport.label}',
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LectorContent(
        maxWidth: 680,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Votre Lector ${widget.module.sport.label}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(switch (widget.section) {
              SportPreferenceSection.all =>
                'Choisissez vos compétitions et les lectures à rechercher. Aucun choix n’est activé automatiquement.',
              SportPreferenceSection.competitions =>
                'Ces compétitions alimentent « Pour moi ». Vos lectures actives restent visibles sur les autres rencontres dans « Tous » et « Radar ».',
              SportPreferenceSection.markets =>
                'Autorisez les marchés que le Générateur peut utiliser pour ce sport. Les cotes restent consultables dans les rencontres. Aucun marché n’est autorisé par défaut.',
              SportPreferenceSection.readings =>
                'Ces lectures concernent uniquement ${widget.module.sport.label.toLowerCase()}. Elles apparaissent sur les rencontres lorsque les données et leurs conditions le permettent.',
            }),
            if ([
              SportPreferenceSection.all,
              SportPreferenceSection.competitions,
            ].contains(widget.section)) ...[
              const SizedBox(height: 20),
              Text(
                'Mes compétitions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              LectorGlassCard(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    for (final c in widget.competitions)
                      CheckboxListTile(
                        key: ValueKey('preference-competition-${c.id.value}'),
                        title: Text(c.name),
                        subtitle: Text(c.country),
                        secondary: SportsAssetBadge(
                          size: 32,
                          imageUrl: c.logoUrl,
                          fallbackLabel: c.name,
                        ),
                        value: _competitions.contains(c.id.key),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() {
                                v == true
                                    ? _competitions.add(c.id.key)
                                    : _competitions.remove(c.id.key);
                              }),
                      ),
                  ],
                ),
              ),
            ],
            if ([
              SportPreferenceSection.all,
              SportPreferenceSection.readings,
            ].contains(widget.section)) ...[
              const SizedBox(height: 20),
              Text(
                'Mes lectures',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Une lecture activée ne s’affiche que si sa règle est vérifiée. '
                'Les données insuffisantes ne déclenchent aucune lecture.',
              ),
              const SizedBox(height: 8),
              for (final r in widget.module.readings.where(
                (r) => r.implemented,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LectorGlassCard(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: ValueKey('preference-reading-${r.id}'),
                          title: Text(r.label),
                          subtitle: Text(r.description),
                          value: _readings.contains(r.id),
                          onChanged: _saving
                              ? null
                              : (v) => setState(() {
                                  v
                                      ? _readings.add(r.id)
                                      : _readings.remove(r.id);
                                }),
                        ),
                        ExpansionTile(
                          title: const Text('Règle et exemple'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.condition),
                                  const SizedBox(height: 8),
                                  Text(r.example),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            if ([
                  SportPreferenceSection.all,
                  SportPreferenceSection.markets,
                ].contains(widget.section) &&
                widget.module.markets.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Mes marchés',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final m in widget.module.markets)
                LectorGlassCard(
                  padding: const EdgeInsets.all(4),
                  child: SwitchListTile(
                    key: ValueKey('preference-market-${m.id}'),
                    title: Text(m.label),
                    subtitle: Text(m.description),
                    value: _markets.contains(m.id),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() {
                            v ? _markets.add(m.id) : _markets.remove(m.id);
                          }),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              '${_competitions.length} compétition(s) · ${_readings.length} lecture(s) · ${_markets.length} marché(s)',
            ),
            const Text(
              'Sans compétition ou sans lecture choisie, « Pour moi » reste vide.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Vos préférences sont enregistrées dans ce navigateur. '
              'Elles ne sont pas encore synchronisées entre vos appareils.',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('save-sport-preferences'),
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? 'Enregistrement…' : 'Enregistrer mes préférences',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.onSave(
        SportReadingPreferences(
          sport: widget.module.sport,
          competitionKeys: _competitions,
          readingIds: _readings,
          marketIds: _markets,
        ),
      );
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context);
        return;
      }
      setState(
        () => _error =
            'Le compte a changé. Revenez aux préférences de votre compte actuel.',
      );
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Les préférences n’ont pas pu être enregistrées. Réessayez.',
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }
}
