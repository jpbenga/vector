import 'package:copilot/core/domain/compact_match_data.dart';
// Isolated UI validation entry point. Archived public snapshots only.
// No auth, database writes, live subscription, model or provider collection.
import 'dart:convert';
import 'package:copilot/core/theme/app_colors.dart';
import 'package:copilot/core/theme/app_components.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_calendar.dart';
import 'package:copilot/core/widgets/lector_compact_workspace_header.dart';
import 'package:copilot/core/widgets/lector_compact_match_card.dart';
import 'package:copilot/core/widgets/lector_geometric_navigation.dart';
import 'package:copilot/core/widgets/lector_shortlist_icon.dart';
import 'package:copilot/core/widgets/lector_workspace_header.dart';
import 'package:copilot/core/widgets/lector_workspace_navigation.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/compact_football_match_adapter.dart';
import 'package:copilot/features/matches/presentation/match_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<List<MatchBoardItem>> loadCompactPreviewMatches() async {
  final matches = <MatchBoardItem>[];
  for (final name in ['league', 'champions']) {
    final json =
        jsonDecode(
              await rootBundle.loadString('assets/design_preview/$name.json'),
            )
            as Map<String, dynamic>;
    matches.add(
      SnapshotMatchFeedRepository(snapshot: json).allMatches().single,
    );
  }
  return matches;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  final matches = await loadCompactPreviewMatches();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CopilotTheme.dark,
      home: CompactMatchesPreviewPage(matches: matches),
    ),
  );
}

class CompactMatchesPreviewPage extends StatefulWidget {
  const CompactMatchesPreviewPage({
    required this.matches,
    this.initialSection = LectorWorkspaceSection.forMe,
    super.key,
  });
  final List<MatchBoardItem> matches;
  final LectorWorkspaceSection initialSection;
  @override
  State<CompactMatchesPreviewPage> createState() =>
      _CompactMatchesPreviewPageState();
}

class _CompactMatchesPreviewPageState extends State<CompactMatchesPreviewPage> {
  late LectorWorkspaceSection _section = widget.initialSection;
  final _saved = <String>{};
  DateTime _date = DateTime(2026, 10, 13);
  void _info(String title, String body) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
  void _open(MatchBoardItem match) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => MatchDetailPage(match: match)),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? AppCompetitionColors.background
        : context.surfaces.background,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 544),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            children: [
              LectorCompactWorkspaceHeader(
                sportSelector: TextButton.icon(
                  onPressed: () => _info(
                    'Aperçu football',
                    'Ces deux cartes utilisent des publications football archivées. Le sélecteur multisport sera raccordé dans l’application après validation.',
                  ),
                  icon: Icon(
                    Icons.sports_soccer_rounded,
                    size: 18,
                    color: context.semantic.info,
                  ),
                  label: const Text(
                    'Football',
                    maxLines: 1,
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
                shortlistCount: _saved.length,
                onOpenShortlist: () => _info(
                  'Sélection de l’aperçu',
                  _saved.isEmpty
                      ? 'Aucune rencontre sélectionnée dans cet aperçu.'
                      : widget.matches
                            .where((m) => _saved.contains(m.id))
                            .map(
                              (m) => '${m.homeTeam.name} – ${m.awayTeam.name}',
                            )
                            .join('\n'),
                ),
                identity: LectorIdentityButton(
                  tooltip: 'À propos de l’aperçu',
                  onPressed: () => _info(
                    'Prévisualisation',
                    'Les sélections restent uniquement en mémoire. Votre compte et votre Shortlist réelle ne sont pas modifiés.',
                  ),
                ),
                onOpenSettings: () => _info(
                  'Présentation à valider',
                  'Cet aperçu permet de valider les proportions avant l’intégration dans Tous et Pour moi.',
                ),
              ),
              const SizedBox(height: 6),
              CopilotCalendar(
                selectedDate: _date,
                visibleWindowDays:
                    MediaQuery.textScalerOf(context).scale(12) > 16 ? 5 : 7,
                onDateSelected: (date) => setState(() => _date = date),
              ),
              const SizedBox(height: 10),
              LectorGeometricNavigation(
                selected: _section,
                onChanged: (section) => setState(() => _section = section),
              ),
              const SizedBox(height: 16),
              Text(
                _section == LectorWorkspaceSection.all
                    ? 'Tous les matchs'
                    : _section == LectorWorkspaceSection.forMe
                    ? 'Pour moi'
                    : 'Aperçu ${switch (_section) {
                        LectorWorkspaceSection.radar => 'Radar',
                        LectorWorkspaceSection.generator => 'Générateur',
                        _ => 'Bilan',
                      }}',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cartes à valider · données archivées du 9–10 octobre',
                style: TextStyle(
                  fontSize: 10.5,
                  color: context.textColors.secondary,
                ),
              ),
              const SizedBox(height: 14),
              if (_section == LectorWorkspaceSection.all ||
                  _section == LectorWorkspaceSection.forMe)
                for (final match in widget.matches) ...[
                  LectorCompactMatchCard(
                    data: compactFootballMatch(
                      match: match,
                      showReadings: true,
                      competitionFormScope:
                          match.competition.apiFootballLeagueId == 39
                          ? MatchFormScope.championship
                          : MatchFormScope.competition,
                    ),
                    onOpen: () => _open(match),
                    preparationAction: IconButton(
                      key: ValueKey('preview-shortlist:${match.id}'),
                      tooltip: _saved.contains(match.id)
                          ? 'Retirer de la sélection'
                          : 'Ajouter à la sélection',
                      onPressed: () => setState(
                        () => _saved.contains(match.id)
                            ? _saved.remove(match.id)
                            : _saved.add(match.id),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: LectorShortlistIcon(
                        selected: _saved.contains(match.id),
                        color: _saved.contains(match.id)
                            ? context.brand.accent
                            : context.textColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ]
              else
                Text(
                  'Cette rubrique conserve son fonctionnement actuel. Cet aperçu porte sur les nouvelles cartes de rencontres.',
                  style: TextStyle(color: context.textColors.secondary),
                ),
              const SizedBox(height: 4),
              Text(
                'Les cotes et statuts ci-dessus décrivent les publications archivées, pas une actualisation en direct.',
                style: TextStyle(
                  fontSize: 10,
                  color: context.textColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
