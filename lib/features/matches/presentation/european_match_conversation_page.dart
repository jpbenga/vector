import 'package:flutter/material.dart';
import '../../../app/sports/generator_match_navigation.dart';
import '../../../core/identity/identity_scope.dart';
import '../../generator/domain/generator_context.dart';
import '../../generator/presentation/lector_generator_page.dart';
import '../domain/match_board_item.dart';

/// Navigation sends stable references; model tools read the canonical dossier.
class EuropeanMatchConversationPage extends StatelessWidget {
  const EuropeanMatchConversationPage({
    required this.match,
    required this.scope,
    this.compare = false,
    super.key,
  });
  final MatchBoardItem match;
  final IdentityScope scope;
  final bool compare;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Avec Lector')),
    body: LectorGeneratorPage(
      date: match.fixture.kickoff?.toLocal() ?? DateTime.now(),
      scope: scope,
      workspaceKey: 'european:${match.fixture.apiFootballFixtureId}',
      configurationKey: 'european-v1',
      initialPrompt:
          '${compare ? 'Compare les parcours' : 'Analyse les parcours'} de ${match.homeTeam.name} et ${match.awayTeam.name} avant leur confrontation, rencontre football:${match.fixture.apiFootballFixtureId}, le ${generatorDay(match.fixture.kickoff?.toLocal() ?? DateTime.now())}. Utilise le dossier européen publié, distingue les faits, les contradictions et les limites.',
      loadContext: () async => GeneratorContext(
        origin: 'explorer',
        preferences: const {
          'football': {'competitions': [], 'readings': [], 'markets': []},
        },
        fixtureFocus: {
          'sport': 'football',
          'fixtureId': '${match.fixture.apiFootballFixtureId}',
          'date': generatorDay(
            match.fixture.kickoff?.toLocal() ?? DateTime.now(),
          ),
        },
      ),
      onOpenMatch: (pick) => openGeneratorMatch(context, pick),
    ),
  );
}
