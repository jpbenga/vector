import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/features/generator/data/generator_repository.dart';
import 'package:copilot/features/generator/domain/generator_context.dart';
import 'package:copilot/features/generator/presentation/lector_generator_page.dart';

class FakeGenerator implements GeneratorRepository {
  final requests = <Map<String, Object?>>[];
  @override
  Future<Map<String, dynamic>> request(Map<String, Object?> body) async {
    requests.add(body);
    if (body['action'] == 'prepare') {
      return {
        'preparation': {'matchCount': 3, 'radarCount': 2},
      };
    }
    return {
      'state': {
        'id': body['conversationId'],
        'revision': 1,
        'tickets': <Object>[],
        'pending': null,
        'messages': [
          {'role': 'user', 'text': body['message']},
          {'role': 'assistant', 'text': 'Quelle mise par composition ?'},
        ],
      },
    };
  }
}

class DelayedGenerator extends FakeGenerator {
  final chat = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> request(Map<String, Object?> body) {
    if (body['action'] == 'chat') {
      requests.add(body);
      return chat.future;
    }
    return super.request(body);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets(
    'mobile generator prepares without an AI turn and sends the effective explorer context',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeGenerator();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LectorGeneratorPage(
              date: DateTime(2026, 10, 8),
              scope: const IdentityScope.account('account'),
              repository: service,
              loadContext: () async => GeneratorContext(
                origin: 'explorer',
                preferences: {
                  'football': {
                    'readings': ['strong_home_team'],
                    'markets': ['matchResult'],
                    'competitions': ['61'],
                  },
                },
              ),
              onPreferences: () {},
              onOpenMatch: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Explorateur · configuration temporaire'),
        findsOneWidget,
      );
      expect(service.requests.where((r) => r['action'] == 'chat'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Prépare deux tickets');
      await tester.tap(find.byTooltip('Envoyer la demande'));
      await tester.pumpAndSettle();
      expect(service.requests.last['action'], 'chat');
      expect((service.requests.last['context'] as Map)['origin'], 'explorer');
      expect(find.text('Quelle mise par composition ?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('guest never calls the paid service', (tester) async {
    final service = FakeGenerator();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LectorGeneratorPage(
            date: DateTime(2026, 10, 8),
            scope: const IdentityScope.guest('guest'),
            repository: service,
            loadContext: () async =>
                GeneratorContext(origin: 'profile', preferences: {}),
            onPreferences: () {},
            onOpenMatch: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Un ticket');
    await tester.tap(find.byTooltip('Envoyer la demande'));
    await tester.pumpAndSettle();
    expect(service.requests, isEmpty);
    expect(
      find.textContaining('Connectez-vous à votre compte'),
      findsOneWidget,
    );
  });
  testWidgets(
    'a response from the previous account never appears under the new account',
    (tester) async {
      final service = DelayedGenerator();
      Widget screen(String account) => MaterialApp(
        home: Scaffold(
          body: LectorGeneratorPage(
            date: DateTime(2026, 10, 8),
            scope: IdentityScope.account(account),
            repository: service,
            loadContext: () async =>
                GeneratorContext(origin: 'profile', preferences: {}),
            onPreferences: () {},
            onOpenMatch: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(screen('generator-old-account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Un ticket');
      await tester.tap(find.byTooltip('Envoyer la demande'));
      await tester.pump();
      final oldId = service.requests.last['conversationId'];
      await tester.pumpWidget(screen('generator-new-account'));
      await tester.pumpAndSettle();
      service.chat.complete({
        'state': {
          'id': oldId,
          'revision': 1,
          'tickets': [],
          'pending': null,
          'messages': [
            {'role': 'assistant', 'text': 'private-old-account'},
          ],
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('private-old-account'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
