import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/identity/memory_local_key_value_store.dart';
import 'package:copilot/core/identity/scoped_persistence.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_compact_workspace_header.dart';
import 'package:copilot/core/widgets/lector_workspace_navigation.dart';
import 'package:copilot/core/widgets/lector_match_card.dart';
import 'package:copilot/features/generator/data/generator_repository.dart';
import 'package:copilot/features/generator/domain/generator_context.dart';
import 'package:copilot/features/generator/presentation/lector_generator_page.dart';
import 'package:copilot/features/generator/presentation/generator_exploration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final corpus = generatorMap(
  jsonDecode(
    File(
      'test/fixtures/generator_exploration_continuity.json',
    ).readAsStringSync(),
  ),
);
final publishedCorpus = generatorMap(
  jsonDecode(
    File(
      'test/fixtures/generator_exploration_published_review.json',
    ).readAsStringSync(),
  ),
);
const scope = IdentityScope.account('controlled-exploration');

class ExplorationService implements GeneratorRepository {
  ExplorationService({String initial = 'initial', this.published = false})
    : report = generatorMap((published ? publishedCorpus : corpus)[initial]);
  final bool published;
  Map<String, dynamic> report;
  final requests = <Map<String, Object?>>[];
  final messages = <Map<String, dynamic>>[];
  int revision = 1;
  bool failRead = false, failChat = false, pending = false;
  Map<String, dynamic> get state => {
    'id': 'controlled-session',
    'revision': revision,
    'expiresAt': DateTime.now()
        .add(const Duration(hours: 24))
        .toIso8601String(),
    'messages': [
      ...messages,
      {
        'id': 'response-$revision',
        'role': 'assistant',
        'text': published
            ? 'Dix rencontres à examiner selon les faits publiés.'
            : 'Préparation issue du corpus de tests contrôlés.',
        'analysis': {'exploration': report},
      },
    ],
    'tickets': <Object>[],
  };
  @override
  Future<Map<String, dynamic>> request(Map<String, Object?> body) async {
    requests.add(body);
    switch (body['action']) {
      case 'read':
        return {'state': state};
      case 'prepare':
        return {
          'preparation': {'matchCount': 80},
        };
      case 'chat':
        if (failChat) throw StateError('Interruption contrôlée');
        final action = generatorMap(body['explorationAction']);
        messages.addAll(state['messages'] as List<Map<String, dynamic>>);
        messages.add({'role': 'user', 'text': body['message']});
        report = generatorMap(
          corpus[action['mode'] == 'resume' ? 'resumed' : 'refreshed'],
        );
        revision++;
        return {'state': state};
      case 'status':
        return {
          if (!pending && !failChat && body['includeResult'] == true)
            'state': state,
          'turn': {
            'status': pending
                ? 'pending'
                : failChat
                ? 'failed'
                : 'complete',
            'explorationCheckpoint': {
              'evaluationId': failChat
                  ? generatorMap(corpus['resumed'])['evaluationId']
                  : report['evaluationId'],
            },
          },
        };
      case 'exploration_read':
        if (failRead) throw StateError('Archive indisponible');
        return {
          'exploration':
              body['evaluationId'] ==
                  generatorMap(corpus['initial'])['evaluationId']
              ? corpus['initial']
              : failChat
              ? {
                  ...generatorMap(corpus['initial']),
                  'evaluationId': generatorMap(
                    corpus['resumed'],
                  )['evaluationId'],
                }
              : report,
        };
      case 'exploration_compare':
        expect((body['matchKeys'] as List).length, inInclusiveRange(2, 4));
        expect(body.containsKey('explorationAction'), false);
        final comparison = generatorMap(
          (published ? publishedCorpus : corpus)['comparison'],
        );
        return {
          'comparison': {
            ...comparison,
            'comparisons': generatorRows(comparison['comparisons'])
                .where(
                  (r) => (body['matchKeys'] as List).contains(
                    generatorMap(r['match'])['key'],
                  ),
                )
                .toList(),
          },
        };
      case 'exploration_changes':
        return {'changes': publishedCorpus['changes']};
      case 'exploration_explain':
        expect(
          body['matchKey'],
          generatorMap(generatorMap(corpus['explanation'])['match'])['key'],
        );
        return {'explanation': corpus['explanation']};
      default:
        return {};
    }
  }
}

Future<ScopedPersistence> reference() async {
  final persistence = ScopedPersistence(store: MemoryLocalKeyValueStore());
  await persistence.write(
    scope,
    const String.fromEnvironment(
              'LECTOR_GENERATOR_ENDPOINT',
              defaultValue: 'lector-generator',
            ) ==
            'lector-generator-workshop'
        ? 'generator.conversation.workshop.v1'
        : 'generator.conversation.v1',
    jsonEncode({'id': 'controlled-session', 'date': '2026-10-10'}),
  );
  return persistence;
}

Widget app(
  ExplorationService service,
  ScopedPersistence persistence, {
  ThemeData? theme,
}) => RepaintBoundary(
  key: const ValueKey('capture'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme ?? CopilotTheme.dark,
    home: Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LectorCompactWorkspaceHeader(
              sportSelector: const Row(
                children: [
                  Icon(Icons.sports_soccer, size: 20),
                  SizedBox(width: 6),
                  Text('Football'),
                ],
              ),
              identity: const CircleAvatar(child: Text('JB')),
              onOpenShortlist: () {},
              onOpenSettings: () {},
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LectorWorkspaceNavigation(
              selected: LectorWorkspaceSection.generator,
              onChanged: (_) {},
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              service.published
                  ? 'Publications réelles · évaluation UI simulée'
                  : 'Validation locale · données et IA simulées',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          Expanded(
            child: LectorGeneratorPage(
              date: DateTime(2026, 10, 10),
              scope: scope,
              repository: service,
              persistence: persistence,
              durableSessions: true,
              embedded: true,
              loadContext: () async =>
                  GeneratorContext(origin: 'profile', preferences: {}),
              onOpenMatch: (_) {},
            ),
          ),
        ],
      ),
    ),
  ),
);
Future<void> top(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('generator-conversation-scroll')),
    const Offset(0, 70),
  );
  await tester.pumpAndSettle();
  tester
      .widget<ListView>(
        find.byKey(const ValueKey('generator-conversation-scroll')),
      )
      .controller!
      .jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['LECTOR_CAPTURE_EXPLORATION'] != 'true') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('output/generator-exploration-review/captures');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png').writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    final font = FontLoader('Roboto');
    font.addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  final themes = <String, ThemeData>{
    'dark': CopilotTheme.dark,
    'light': CopilotTheme.light,
    'gold': CopilotTheme.gold,
    'aurora': CopilotTheme.aurora,
    'dracula': CopilotTheme.dracula,
    'tokyoNight': CopilotTheme.tokyoNight,
    'mocha': CopilotTheme.catppuccinMocha,
    'latte': CopilotTheme.catppuccinLatte,
    'solarized': CopilotTheme.solarizedLight,
    'quiet': CopilotTheme.quietLight,
  };
  testWidgets(
    'native preparation fits all five widths and ten existing themes, with top navigation and bottom input',
    (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      tester.view.devicePixelRatio = 1;
      for (final entry in themes.entries) {
        for (final width in [320, 375, 390, 430, 768]) {
          tester.view.physicalSize = Size(width.toDouble(), 844);
          await tester.pumpWidget(
            app(
              ExplorationService(published: true),
              await reference(),
              theme: entry.value,
            ),
          );
          await tester.pumpAndSettle();
          await top(tester);
          expect(find.text('19 / 19 évaluées · 10 retenues'), findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} / $width',
          );
          if (entry.key == 'dark' &&
              width == 390 &&
              Platform.environment['LECTOR_CAPTURE_EXPLORATION'] == 'true') {
            final first = tester.getRect(
              find.byType(LectorMatchCardFrame).first,
            );
            final start = tester.getRect(
              find.textContaining('Lectures publiées et forme').first,
            );
            await tester.runAsync(() async {
              final folder = Directory('output/generator-exploration-review');
              await folder.create(recursive: true);
              await File('${folder.path}/ui-measures.json').writeAsString(
                jsonEncode({
                  'width': width,
                  'firstCardHeight': first.height,
                  'summaryAndActionsHeight': first.top - start.top,
                  'retainedCount': find.byType(Checkbox).evaluate().length,
                  'capture': 'Flutter widget renderer, not a physical phone',
                }),
              );
            });
          }
          if (entry.key == 'dark' || width == 375) {
            await capture(tester, 'exploration-${entry.key}-$width');
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      }
    },
    tags: ['visual'],
  );
  testWidgets(
    'four archived observations compare, an excluded match explains, without any chat; explicit refresh keeps initial version',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      final service = ExplorationService();
      await tester.pumpWidget(app(service, await reference()));
      await tester.pumpAndSettle();
      await top(tester);
      final boxes = find.byType(Checkbox);
      for (var i = 0; i < 4; i++) {
        await reveal(tester, boxes.at(i));
        await tester.tap(boxes.at(i));
        await tester.pumpAndSettle();
      }
      await reveal(tester, find.widgetWithText(OutlinedButton, 'Comparer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Comparer'));
      await tester.pumpAndSettle();
      expect(find.text('Arguments favorables'), findsOneWidget);
      expect(find.text('Contradictions'), findsOneWidget);
      expect(service.requests.where((r) => r['action'] == 'chat'), isEmpty);
      await capture(tester, 'comparison-390');
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Voir aussi les rencontres écartées'));
      await tester.tap(find.text('Voir aussi les rencontres écartées'));
      await tester.pumpAndSettle();
      final proofs = find.byTooltip('Voir les preuves');
      await reveal(tester, proofs.first);
      await tester.tap(proofs.first);
      await tester.pumpAndSettle();
      expect(find.text('Écartée de cette préparation'), findsOneWidget);
      expect(service.requests.where((r) => r['action'] == 'chat'), isEmpty);
      await capture(tester, 'explanation-390');
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Actualiser'));
      await tester.tap(find.text('Actualiser'));
      await tester.pumpAndSettle();
      final paid = service.requests.where((r) => r['action'] == 'chat').single;
      expect(generatorMap(paid['explorationAction'])['mode'], 'refresh');
      expect(paid['requestId'], isNotNull);
      expect(find.text('Préparation actualisée'), findsOneWidget);
      expect(
        generatorMap(
          generatorMap(service.messages.first['analysis'])['exploration'],
        )['evaluationId'],
        generatorMap(corpus['initial'])['evaluationId'],
      );
      await tester.drag(
        find.byKey(const ValueKey('generator-conversation-scroll')),
        const Offset(0, 70),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Préparation actualisée'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await capture(tester, 'refresh-390');
      await reveal(tester, find.byTooltip('Voir la préparation initiale').last);
      await tester.tap(find.byTooltip('Voir la préparation initiale').last);
      await tester.pumpAndSettle();
      expect(find.text('62 / 80 évaluées · 10 retenues'), findsOneWidget);
      expect(service.requests.where((r) => r['action'] == 'chat').length, 1);
      await capture(tester, 'initial-390');
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'published fixtures render two and four shared-rubric comparisons and scope versus selection differences',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ExplorationService(published: true);
      await tester.pumpWidget(app(service, await reference()));
      await tester.pumpAndSettle();
      await top(tester);
      final boxes = find.byType(Checkbox);
      for (var i = 0; i < 2; i++) {
        await reveal(tester, boxes.at(i));
        await tester.tap(boxes.at(i));
        await tester.pumpAndSettle();
      }
      await reveal(tester, find.widgetWithText(OutlinedButton, 'Comparer'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Comparer'));
      await tester.pumpAndSettle();
      expect(find.text('Dynamique'), findsOneWidget);
      expect(find.text('Arguments favorables'), findsOneWidget);
      expect(find.text('Qualité des données'), findsOneWidget);
      await capture(tester, 'comparison-two-390');
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      for (var i = 2; i < 4; i++) {
        await reveal(tester, boxes.at(i));
        await tester.tap(boxes.at(i));
        await tester.pumpAndSettle();
      }
      await reveal(tester, find.widgetWithText(OutlinedButton, 'Comparer'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Comparer'));
      await tester.pumpAndSettle();
      expect(find.text('Arguments favorables'), findsOneWidget);
      await capture(tester, 'comparison-four-390');
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        app(
          ExplorationService(initial: 'refreshed', published: true),
          await reference(),
        ),
      );
      await tester.pumpAndSettle();
      await top(tester);
      expect(find.text('Périmètre · +0 / −1 rencontres'), findsOneWidget);
      expect(
        find.text('Publications · 0 rencontres modifiées'),
        findsOneWidget,
      );
      await capture(tester, 'refresh-390');
      await reveal(tester, find.text('Voir les changements'));
      await tester.tap(find.text('Voir les changements'));
      await tester.pumpAndSettle();
      expect(find.text('Périmètre · retirées'), findsOneWidget);
      expect(find.text('Classement retenu · sorties'), findsOneWidget);
      await capture(tester, 'differences-390');
      expect(service.requests.where((r) => r['action'] == 'chat'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('generic reasons use a cited fact, never an uncited datum', () {
    expect(
      generatorExplorationArgument({
        'reason': 'Adéquation documentée par le fait publié cité.',
        'favorable': [
          {'text': 'Deux victoires sur trois rencontres publiées.'},
        ],
        'evidence': [
          {'text': 'Une autre donnée brute.'},
        ],
      }),
      'Deux victoires sur trois rencontres publiées.',
    );
    expect(
      generatorExplorationArgument({
        'evidence': [
          {'text': 'Fait non cité'},
        ],
      }),
      'Aucun argument archivé.',
    );
  });
  testWidgets(
    'all ten published observations remain compact in a full native scroll capture',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: const ValueKey('full-list'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GeneratorExplorationResult(
                    report: generatorMap(publishedCorpus['initial']),
                    read: (_, _) async => {},
                    onAction: (_, _) {},
                    onOpenMatch: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNWidgets(10));
      if (Platform.environment['LECTOR_CAPTURE_EXPLORATION'] == 'true') {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('full-list')),
          );
          final image = await boundary.toImage(pixelRatio: 2),
              png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'output/generator-exploration-review/captures/exploration-ten-full-390.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'archive error can retry only the read; a failed request restores its partial checkpoint without resubmission',
    (tester) async {
      final service = ExplorationService()..failRead = true;
      await tester.pumpWidget(app(service, await reference()));
      await tester.pumpAndSettle();
      await top(tester);
      await reveal(tester, find.byTooltip('Voir la préparation initiale'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voir la préparation initiale'));
      await tester.pumpAndSettle();
      expect(find.text('Réessayer la consultation'), findsOneWidget);
      service.failRead = false;
      await tester.tap(find.text('Réessayer la consultation'));
      await tester.pumpAndSettle();
      expect(find.text('Préparation initiale'), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      service.failChat = true;
      await reveal(tester, find.text('Reprendre'));
      await tester.tap(find.text('Reprendre'));
      await tester.pumpAndSettle();
      expect(service.requests.where((r) => r['action'] == 'chat').length, 1);
      expect(
        service.requests
            .where((r) => r['action'] == 'exploration_read')
            .last['evaluationId'],
        generatorMap(corpus['resumed'])['evaluationId'],
      );
      expect(
        find.byKey(
          ValueKey(
            'exploration-${generatorMap(corpus['resumed'])['evaluationId']}',
          ),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'a pending request restored after restart is read by its requestId, without another chat',
    (tester) async {
      final service = ExplorationService()..pending = true;
      final persistence = await reference();
      final key =
          const String.fromEnvironment(
                'LECTOR_GENERATOR_ENDPOINT',
                defaultValue: 'lector-generator',
              ) ==
              'lector-generator-workshop'
          ? 'generator.conversation.workshop.v1'
          : 'generator.conversation.v1';
      await persistence.write(
        scope,
        key,
        jsonEncode({
          'id': 'controlled-session',
          'date': '2026-10-10',
          'requestId': 'original-request',
        }),
      );
      await tester.pumpWidget(app(service, persistence));
      await tester.pumpAndSettle();
      expect(service.requests.where((r) => r['action'] == 'chat'), isEmpty);
      expect(
        service.requests.firstWhere(
          (r) => r['action'] == 'status',
        )['requestId'],
        'original-request',
      );
      service.pending = false;
      final button = find.text('Retrouver la demande');
      await reveal(tester, button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(service.requests.where((r) => r['action'] == 'chat'), isEmpty);
      expect(find.text('Retrouver la demande'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'an absent preparation distinguishes unavailable counts from zero performance',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: GeneratorExplorationResult(
                report: {
                  'evaluationId': 'empty',
                  'schemaVersion': 1,
                  'coverage': <String, dynamic>{},
                  'observations': <Object>[],
                },
                read: (_, _) async => {},
                onAction: (_, _) {},
                onOpenMatch: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Sans données'), findsOneWidget);
      expect(find.text('— / — évaluées · 0 retenues'), findsOneWidget);
      expect(
        find.text('Aucune rencontre disponible dans ce périmètre.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'an older summary-only analysis reads archived observations without re-evaluation',
    (tester) async {
      final service = ExplorationService();
      final keys = generatorRows(
        service.report['observations'],
      ).map((r) => r['key']).toList();
      service.report = {...service.report, 'selectedKeys': keys}
        ..remove('observations');
      await tester.pumpWidget(app(service, await reference()));
      await tester.pumpAndSettle();
      await top(tester);
      expect(find.text('62 / 80 évaluées · 10 retenues'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(10));
      expect(
        service.requests.where((r) => r['action'] == 'exploration_read').length,
        1,
      );
      expect(service.requests.where((r) => r['action'] == 'chat'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
