import 'package:flutter/material.dart';

import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/lector_brand_mark.dart';
import '../../form_radar/presentation/form_radar_signal_panel.dart';
import '../../form_radar/presentation/widgets/form_radar_event_timeline.dart';
import '../../matches/presentation/widgets/lector_match_hero.dart';
import '../../matches/presentation/widgets/match_feed_card.dart';
import '../data/appearance_preview_fixture.dart';

enum AppearancePreviewKind {
  overview('Aperçu'),
  match('Match'),
  radar('Radar'),
  chat('Chat'),
  components('Composants');

  const AppearancePreviewKind(this.label);
  final String label;
}

class AppearancePreview extends StatelessWidget {
  const AppearancePreview({required this.kind, super.key});
  final AppearancePreviewKind kind;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: switch (kind) {
      AppearancePreviewKind.overview => [
        const LectorMatchHero(match: appearancePreviewMatch),
        const SizedBox(height: 12),
        const AppearanceReadingPreview(),
        const SizedBox(height: 12),
        FormRadarSignalPanel(entries: appearancePreviewPlayers),
      ],
      AppearancePreviewKind.match => [
        const LectorMatchHero(match: appearancePreviewMatch),
        const SizedBox(height: 12),
        IgnorePointer(
          child: MatchFeedCard(
            match: appearancePreviewMatch,
            radarEntries: const [],
            onTap: () {},
          ),
        ),
      ],
      AppearancePreviewKind.radar => [
        const _PreviewTitle(
          title: 'Joueurs en forme',
          subtitle: 'L’activité sur les trois derniers matchs.',
          icon: Icons.bar_chart_rounded,
        ),
        const SizedBox(height: 12),
        FormRadarSignalPanel(entries: appearancePreviewPlayers),
        const SizedBox(height: 12),
        const AppearancePreviewPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Déroulé du match'),
              FormRadarEventTimeline(
                events: [
                  FormRadarTimelineEvent(
                    minute: 23,
                    kind: FormRadarTimelineEventKind.goal,
                    label: 'But',
                  ),
                  FormRadarTimelineEvent(
                    minute: 68,
                    kind: FormRadarTimelineEventKind.assist,
                    label: 'Passe décisive',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      AppearancePreviewKind.chat => [const _ChatPreview()],
      AppearancePreviewKind.components => [const _ComponentsPreview()],
    },
  );
}

class AppearanceReadingPreview extends StatelessWidget {
  const AppearanceReadingPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final identity = context.opportunities.readingIdentityForId(
      'positive_streak',
    );
    final badge = identity.badgeFor(AppReadingBadgeVariant.soft);
    return AppearancePreviewPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badge.background,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(identity.icon, color: badge.iconColor, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LECTURE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: badge.foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Dynamique positive',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '4 victoires et 1 nul sur 5 matchs',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPreview extends StatelessWidget {
  const _ChatPreview();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _PreviewTitle(
        title: 'Une conversation avec Lector',
        subtitle: 'Exemple d’affichage des messages et des données.',
        icon: Icons.chat_bubble_outline_rounded,
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.brand.accent,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Text(
            'Quels joueurs sont en forme sur ce match ?',
            style: TextStyle(
              color: context.brand.onAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      AppearancePreviewPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                LectorBrandMark(size: 24),
                SizedBox(width: 8),
                Text('Lector'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Voici deux joueurs à explorer, avec leur activité récente.',
              style: TextStyle(color: context.textColors.secondary),
            ),
            const SizedBox(height: 12),
            FormRadarSignalPanel(entries: appearancePreviewPlayers),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const TextField(
        readOnly: true,
        canRequestFocus: false,
        decoration: InputDecoration(
          hintText: 'Votre question à Lector',
          suffixIcon: Icon(Icons.send_outlined),
        ),
      ),
    ],
  );
}

class _ComponentsPreview extends StatefulWidget {
  const _ComponentsPreview();

  @override
  State<_ComponentsPreview> createState() => _ComponentsPreviewState();
}

class _ComponentsPreviewState extends State<_ComponentsPreview> {
  bool _selected = true;

  @override
  Widget build(BuildContext context) => AppearancePreviewPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PreviewTitle(
          title: 'Les éléments du quotidien',
          subtitle: 'Texte, cotes, résultats, champs et boutons.',
          icon: Icons.widgets_outlined,
        ),
        const SizedBox(height: 16),
        const AppearanceReadingPreview(),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ResultChip(
              label: 'V · Victoire',
              background: context.semantic.success,
              foreground: context.semantic.onSuccess,
            ),
            _ResultChip(
              label: 'N · Nul',
              background: context.textColors.secondary,
              foreground: context.semantic.onNeutral,
            ),
            _ResultChip(
              label: 'D · Défaite',
              background: context.semantic.error,
              foreground: context.semantic.onError,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final odd in [('1', '2.10'), ('N', '3.40'), ('2', '3.20')])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: context.components.oddsBackground,
                  border: Border.all(color: context.components.oddsBorder),
                  borderRadius: BorderRadius.circular(AppRadius.odds),
                ),
                child: Text(
                  '${odd.$1}  ${odd.$2}',
                  style: TextStyle(
                    color: context.components.oddsText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const TextField(
          readOnly: true,
          canRequestFocus: false,
          decoration: InputDecoration(
            labelText: 'Rechercher une équipe',
            hintText: 'Nom de l’équipe',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'Suivre cette compétition',
                style: TextStyle(color: context.textColors.primary),
              ),
            ),
            Switch(
              value: _selected,
              onChanged: (value) => setState(() => _selected = value),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Activé'),
              selected: _selected,
              onSelected: (value) => setState(() => _selected = value),
            ),
            const Chip(label: Text('En attente')),
            FilledButton(
              onPressed: () => setState(() => _selected = !_selected),
              child: const Text('Essayer le bouton'),
            ),
            const OutlinedButton(onPressed: null, child: Text('Indisponible')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: context.semantic.info,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Une information utile reste lisible dans chaque thème.',
                style: TextStyle(color: context.textColors.secondary),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.label,
    required this.background,
    required this.foreground,
  });
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.chip),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );
}

class _PreviewTitle extends StatelessWidget {
  const _PreviewTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: context.brand.accent, size: 24),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textColors.secondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class AppearancePreviewPanel extends StatelessWidget {
  const AppearancePreviewPanel({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.surfaces.surface,
      border: Border.all(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: child,
  );
}
