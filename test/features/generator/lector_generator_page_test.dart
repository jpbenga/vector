import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/generator/presentation/generator_ticket_card.dart';
import 'package:copilot/features/generator/presentation/generator_analysis.dart';
import 'package:copilot/features/generator/presentation/generator_compositions.dart';
import 'package:copilot/features/generator/presentation/generator_selection_sheet.dart';
import 'package:copilot/features/generator/data/generator_voice.dart';
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
  testWidgets('analysis stages and verified shortlist fit a 320px mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scope = {
      'date': '2026-10-09',
      'view': 'profile',
      'sports': ['football'],
      'matchCount': 41,
    };
    Map<String, dynamic>? inspected;
    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                GeneratorAnalysisProgress(
                  phase: 'Réflexion en cours…',
                  progress: {
                    'context': scope,
                    'steps': [
                      {
                        'phase': 'sources',
                        'detail': 'Consultation des publications Lector',
                      },
                      {
                        'phase': 'details',
                        'detail':
                            'Examen des lectures et marchés de 5 rencontres',
                      },
                    ],
                    'summary':
                        'Comparaison des arguments et des contradictions.',
                  },
                ),
                GeneratorAnalysisResult(
                  analysis: {
                    'context': scope,
                    'selections': [
                      {
                        'candidate': {
                          'competition': 'Eliteserien',
                          'home': 'Bodo/Glimt',
                          'away': 'Kristiansund BK',
                          'selection': 'Bodo/Glimt gagne',
                          'odds': 1.04,
                        },
                        'reason':
                            'Les victoires consécutives à domicile soutiennent le marché.',
                        'vigilance': 'Cette cote apporte peu au retour.',
                      },
                    ],
                    'limitations': [
                      'Aucune probabilité indépendante n’est établie.',
                    ],
                  },
                  onInspect: (pick) => inspected = pick,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('41 rencontres dans ce périmètre'),
      findsOneWidget,
    );
    expect(find.textContaining('Pour moi'), findsNWidgets(2));
    expect(find.text('Bodo/Glimt gagne'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Bodo/Glimt gagne'));
    await tester.tap(find.text('Bodo/Glimt gagne'));
    expect(inspected?['odds'], 1.04);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'composition alternatives share one stake and remain usable on a narrow mobile',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final first = testTicket(1),
          second = {
            ...testTicket(2),
            'workshop': {'approach': 'fewer_matches'},
          };
      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: GeneratorCompositionOptions(
                tickets: [first, second],
                selectedId: first['id'].toString(),
                onInspect: (_) {},
                onChoose: (t) => chosen = t['id'].toString(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Compositions à examiner'), findsOneWidget);
      expect(find.text('Composition retenue'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Retenir cette composition'));
      expect(chosen, second['id'].toString());
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets('selection detail keeps actions reachable at width $width', (
      tester,
    ) async {
      if (Platform.environment['LECTOR_CAPTURE_UI'] == 'true') {
        await tester.runAsync(() async {
          final font = FontLoader('Inter')
            ..addFont(
              File(
                '/System/Library/Fonts/Supplemental/Arial.ttf',
              ).readAsBytes().then(ByteData.sublistView),
            );
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              File(
                '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes().then(ByteData.sublistView),
            );
          await font.load();
          await icons.load();
        });
      }
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = 0, replaced = 0;
      final pick = generatorRows(testTicket(1)['picks']).single;
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: SafeArea(
              child: RepaintBoundary(
                key: const ValueKey('selection-capture'),
                child: ColoredBox(
                  color: CopilotTheme.dark.scaffoldBackgroundColor,
                  child: GeneratorSelectionSheet(
                    pick: pick,
                    onClose: () {},
                    onOpenMatch: () => opened++,
                    onReplace: () => replaced++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dans le ticket'), findsOneWidget);
      if (width == 390 && Platform.environment['LECTOR_CAPTURE_UI'] == 'true') {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('selection-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/private/tmp/lector-selection-detail-mobile.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.text('Pourquoi ce match ?'), findsNothing);
      final fixed = tester.getRect(
        find.byKey(const ValueKey('selection-fixed-actions')),
      );
      await tester.drag(
        find.byKey(const ValueKey('generator-selection-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('selection-fixed-actions'))),
        fixed,
      );
      await tester.tap(find.text('Voir les données du match'));
      await tester.tap(find.text('Remplacer cette sélection'));
      expect((opened, replaced), (1, 1));
      for (final (tab, label) in [
        (1, 'Données de la sélection'),
        (2, 'Signaux Radar complémentaires'),
        (3, 'Marché retenu'),
      ]) {
        await tester.drag(
          find.byKey(const ValueKey('generator-selection-scroll')),
          const Offset(0, 2000),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(ValueKey('selection-tab-$tab')));
        await tester.tap(find.byKey(ValueKey('selection-tab-$tab')));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets(
    'a chosen selection opens its own sheet and preserves evidence separation',
    (tester) async {
      final ticket = testTicket(1);
      final second = generatorRows(testTicket(2)['picks']).single;
      ticket['picks'] = [...generatorRows(ticket['picks']), second];
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showGeneratorTicketDetail(
                  context,
                  ticket,
                  selection: 1,
                  inTicket: false,
                  onOpenMatch: (_) {},
                  onReplace: (_) {},
                ),
                child: const Text('Détail'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Détail'));
      await tester.pumpAndSettle();
      expect(find.text('Lyon'), findsOneWidget);
      expect(find.text('Lille'), findsNothing);
      expect(find.text('Changement proposé'), findsOneWidget);
      expect(find.text('Solide à domicile'), findsOneWidget);
      await tester.ensureVisible(find.text('Solide à domicile'));
      await tester.tap(find.text('Solide à domicile'));
      await tester.pumpAndSettle();
      expect(find.text('3 victoires consécutives'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
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
      await tester.pump();
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
    await tester.pump();
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
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer la demande'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('Analyse de votre demande…'), findsOneWidget);
      expect(find.text('Un ticket'), findsOneWidget);
      final oldId = service.requests.last['conversationId'];
      await tester.pumpWidget(screen('generator-new-account'));
      await tester.pumpAndSettle();
      service.chat.complete({
        'state': {
          'id': oldId,
          'revision': 1,
          'tickets': <Object?>[],
          'pending': null,
          'messages': [
            {'role': 'assistant', 'text': 'private-old-account'},
          ],
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('private-old-account'), findsNothing);
      expect(find.text('Analyse de votre demande…'), findsNothing);
      expect(find.text('Un ticket'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'tickets belong to their message, detail is structured and another ticket references the right draft',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = TicketGenerator();
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('generator-capture'),
              child: ColoredBox(
                color: CopilotTheme.dark.scaffoldBackgroundColor,
                child: generatorScreen(service),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Un ticket de 50 euros');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.byType(LectorTicketCard), findsOneWidget);
      expect(find.text('TICKET 1'), findsOneWidget);
      expect(find.text('2 lectures'), findsOneWidget);
      expect(find.text('1 joueur Radar'), findsOneWidget);
      expect(find.text('150,00 €'), findsOneWidget);
      await tester.ensureVisible(find.text('Voir le détail du ticket'));
      await tester.tap(find.text('Voir le détail du ticket'));
      await tester.pumpAndSettle();
      expect(find.text('Lectures qui soutiennent ce marché'), findsOneWidget);
      expect(find.text('Contexte complémentaire'), findsOneWidget);
      expect(find.text('3 victoires consécutives'), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer le détail'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Proposer un autre ticket'));
      await tester.tap(find.text('Proposer un autre ticket'));
      await tester.pumpAndSettle();
      expect(service.requests.last['referenceTicketId'], 'ticket-1');
      expect(find.text('TICKET 2'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('TICKET 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'composer remains above a mobile keyboard and empty requests are disabled',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final service = FakeGenerator();
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.light,
          home: Scaffold(body: generatorScreen(service)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Envoyer la demande',
              ),
            )
            .onPressed,
        isNull,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final field = tester.getRect(find.byType(TextField));
      expect(field.bottom, lessThanOrEqualTo(420));
      expect(field.top, greaterThan(100));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'interrupt discards a late result and returns the draft request',
    (tester) async {
      final service = CancelGenerator();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: generatorScreen(service))),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Un ticket');
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer la demande'));
      await tester.pump();
      await tester.tap(find.byTooltip('Interrompre la génération'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Un ticket',
      );
      service.chat.complete({
        'state': {
          'id': 'late',
          'revision': 1,
          'messages': [
            {'role': 'assistant', 'text': 'late-private-result'},
          ],
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('late-private-result'), findsNothing);
      expect(find.byTooltip('Interrompre la génération'), findsNothing);
    },
  );
  testWidgets(
    'dictation inserts editable text and never sends a chat automatically',
    (tester) async {
      final service = VoiceGenerator(), voice = FakeVoice();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: generatorScreen(service, voice: voice)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dicter une demande'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('À l’écoute…'), findsOneWidget);
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Un ticket pour samedi',
      );
      expect(service.requests.where((r) => r['action'] == 'chat'), isEmpty);
      expect(voice.started, true);
    },
  );
  testWidgets('mobile ticket reference capture', (tester) async {
    if (Platform.environment['LECTOR_CAPTURE_UI'] == 'true') {
      await tester.runAsync(() async {
        final font = FontLoader('Inter')
          ..addFont(
            File(
              '/System/Library/Fonts/Supplemental/Arial.ttf',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            File(
              '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await font.load();
        await icons.load();
      });
    }

    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = TicketGenerator();
    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark,
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('generator-capture'),
            child: ColoredBox(
              color: CopilotTheme.dark.scaffoldBackgroundColor,
              child: generatorScreen(service),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Prépare-moi un ticket pour samedi avec une mise de 50 € et un retour autour de 150 €.',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer la demande'));
    await tester.pumpAndSettle();
    if (Platform.environment['LECTOR_CAPTURE_UI'] == 'true') {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('generator-capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/private/tmp/lector-generator-v11-mobile.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
  });
}

Widget generatorScreen(GeneratorRepository service, {GeneratorVoice? voice}) =>
    LectorGeneratorPage(
      date: DateTime(2026, 10, 8),
      scope: const IdentityScope.account('generator-ui-test'),
      repository: service,
      voice: voice,
      loadContext: () async =>
          GeneratorContext(origin: 'explorer', preferences: {}),
      onPreferences: () {},
      onOpenMatch: (_) {},
    );
Map<String, dynamic> testTicket(int number) => {
  'id': 'ticket-$number',
  'number': number,
  'stake': 50,
  'totalOdds': 3.0,
  'returnTotal': 150,
  'netProfit': 100,
  'picks': [
    {
      'id': 'pick-$number',
      'home': number == 1 ? 'Lille' : 'Lyon',
      'away': 'Le Havre',
      'sport': 'football',
      'competition': 'Ligue 1',
      'market': 'Résultat du match',
      'selection': '${number == 1 ? 'Lille' : 'Lyon'} gagne',
      'odds': 3.0,
      'bookmaker': 'Bookmaker',
      'kickoff': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      'oddsAt': DateTime.now().toIso8601String(),
      'evidence': [
        {
          'source': 'reading',
          'family': 'venue',
          'label': 'Solide à domicile',
          'sample': 3,
          'metrics': [
            {'label': '3 victoires consécutives', 'value': ''},
          ],
        },
        {
          'source': 'reading',
          'family': 'standing',
          'label': 'Avantage au classement',
          'sample': 10,
          'supportsMarket': false,
          'text': 'Classement publié',
        },
        {
          'source': 'radar',
          'family': 'form',
          'reusesReading': true,
          'label': 'Solide à domicile',
        },
        {
          'source': 'radar',
          'family': 'player',
          'label': 'J. David',
          'sample': 3,
          'metrics': [
            {'label': 'Décisif', 'value': '2/3 matchs'},
          ],
        },
      ],
    },
  ],
};

class TicketGenerator extends FakeGenerator {
  int turns = 0;
  @override
  Future<Map<String, dynamic>> request(Map<String, Object?> body) async {
    if (body['action'] != 'chat') return super.request(body);
    requests.add(body);
    turns++;
    return {
      'state': {
        'id': body['conversationId'],
        'revision': turns,
        'tickets': [for (int i = 1; i <= turns; i++) testTicket(i)],
        'pending': null,
        'messages': [
          for (int i = 1; i <= turns; i++) ...[
            {
              'role': 'user',
              'text': i == 1
                  ? 'Prépare-moi un ticket pour samedi.'
                  : 'Un autre ticket.',
            },
            {
              'role': 'assistant',
              'text': 'Voici une composition basée sur votre configuration.',
              'ticketIds': ['ticket-$i'],
            },
          ],
        ],
      },
    };
  }
}

class CancelGenerator extends DelayedGenerator {
  @override
  Future<Map<String, dynamic>> request(Map<String, Object?> body) async {
    if (body['action'] == 'cancel') {
      requests.add(body);
      return {
        'turn': {'status': 'failed', 'cancelled': true},
      };
    }
    return super.request(body);
  }
}

class FakeVoice extends GeneratorVoice {
  bool started = false;
  @override
  bool get supported => true;
  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<String> finish() async => 'test-audio';
}

class VoiceGenerator extends FakeGenerator {
  @override
  Future<Map<String, dynamic>> request(Map<String, Object?> body) async {
    if (body['action'] == 'transcribe') {
      requests.add(body);
      return {'transcript': 'Un ticket pour samedi'};
    }
    return super.request(body);
  }
}
