import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/generator/data/generator_repository.dart';
import 'package:copilot/features/generator/presentation/generator_decisions.dart';
import 'package:copilot/features/generator/presentation/generator_ticket_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final originalPick = <String, dynamic>{
  'id': 'candidate',
  'home': 'Rosenborg',
  'away': 'Sandefjord',
  'selection': 'Rosenborg gagne',
  'odds': 1.4,
  'oddsAt': '2026-10-09T01:00:00Z',
  'kickoff': '2026-10-10T14:00:00Z',
  'bookmaker': 'Bookmaker initial',
  'competition': 'Eliteserien',
  'evidence': <Object>[],
  'warnings': <Object>[],
};
final saved = <String, dynamic>{
  'id': 'decision',
  'kind': 'selection',
  'source_id': 'candidate',
  'created_at': '2026-10-09T02:00:00Z',
  'followed_at': '2026-10-09T02:00:00Z',
  'saved_at': null,
  'played_at': null,
  'relevant': true,
  'result': {'status': 'pending', 'picks': <Object>[]},
  'snapshot': {
    'picks': [originalPick],
    'context': {'origin': 'profile'},
  },
};

class DecisionRepository implements GeneratorRepository {
  final calls = <Map<String, Object?>>[];
  final Map<String, dynamic> row = {...saved};
  @override
  Future<Map<String, dynamic>> request(Map<String, Object?> body) async {
    calls.add(body);
    if (body['action'] == 'decisions') {
      return {
        'decisions': [row],
      };
    }
    if (body['choice'] == 'played') row['played_at'] = '2026-10-09T03:00:00Z';
    return {'decision': row};
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets(
    'feedback and following are independent, never an implicit placed bet',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: GeneratorDecisionActions(
              onChoice: (choice) async {
                calls.add(choice);
                return {
                  'relevant': true,
                  if (choice == 'follow') 'followed_at': 'date',
                };
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pertinente'));
      await tester.pumpAndSettle();
      expect(find.text('Jugée pertinente'), findsOneWidget);
      expect(find.text('Suivre cette sélection'), findsOneWidget);
      await tester.tap(find.text('Suivre cette sélection'));
      await tester.pumpAndSettle();
      expect(calls, ['relevant', 'follow']);
      expect(find.text('Sélection suivie'), findsOneWidget);
      expect(find.text('J’ai placé ce pari'), findsNothing);
    },
  );
  testWidgets(
    'a narrow mobile preserves original quote and requires explicit placed confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = DecisionRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showGeneratorSavedDecision(
                  context,
                  row: saved,
                  repository: repo,
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('cote initiale ${generatorOdds(1.4)}'),
        findsOneWidget,
      );
      expect(find.textContaining('Bookmaker initial'), findsOneWidget);
      expect(repo.calls, isEmpty);
      await tester.ensureVisible(find.text('J’ai placé ce pari'));
      await tester.tap(find.text('J’ai placé ce pari'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('J’ai placé ce pari'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();
      expect(repo.calls.single['choice'], 'played');
      expect(find.text('Retirer ma déclaration'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Bilan separates reading confirmation from a followed market and isolates guests',
    (tester) async {
      final repo = DecisionRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: GeneratorBilanSection(
                scope: const IdentityScope.account('one'),
                readings: const Text('Lecture confirmée'),
                repository: repo,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      expect(find.text('Lecture confirmée'), findsOneWidget);
      await tester.tap(find.text('Mes suivis'));
      await tester.pumpAndSettle();
      expect(find.text('Lecture confirmée'), findsNothing);
      expect(find.textContaining('1 sélections suivies'), findsOneWidget);
      expect(find.textContaining('En attente'), findsOneWidget);
      expect(repo.calls.single['action'], 'decisions');
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: GeneratorFollowups(
              scope: const IdentityScope.guest('guest'),
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.calls.length, 1);
      expect(find.textContaining('Connectez-vous'), findsOneWidget);
      expect(find.text('Rosenborg — Sandefjord'), findsNothing);
    },
  );
  testWidgets(
    'ticket conservation is available without replacing the native card',
    (tester) async {
      var kept = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LectorTicketCard(
                ticket: {
                  'id': 'ticket',
                  'number': 1,
                  'stake': 50,
                  'totalOdds': 1.4,
                  'returnTotal': 70,
                  'picks': [originalPick],
                },
                onDetail: () {},
                onSelection: (_) {},
                onModify: () {},
                onAlternative: () {},
                onSave: () => kept = true,
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Enregistrer le ticket'));
      await tester.tap(find.text('Enregistrer le ticket'));
      expect(kept, true);
      expect(tester.takeException(), isNull);
    },
  );
}
