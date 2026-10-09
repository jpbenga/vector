import 'package:copilot/features/form_radar/domain/radar_scope.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/identity/memory_local_key_value_store.dart';
import 'package:copilot/core/identity/scoped_persistence.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/generator/data/generator_repository.dart';
import 'package:copilot/features/generator/domain/generator_context.dart';
import 'package:copilot/features/generator/presentation/lector_generator_page.dart';
import 'package:copilot/features/generator/presentation/generator_analysis.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class ConversationService implements GeneratorRepository {
  final requests = <Map<String, Object?>>[];
  final restored = Completer<Map<String, dynamic>>();
  final reply = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> request(Map<String, Object?> body) async {
    requests.add(body);
    return switch (body['action']) {
      'read' => restored.future,
      'chat' => reply.future,
      'prepare' => {
        'preparation': {'matchCount': 3, 'radarCount': 2},
      },
      'status' => {
        'turn': {
          'phase': 'analyze',
          'context': {'view': 'radar', 'date': '2026-10-09', 'matchCount': 3},
          'steps': [
            {'detail': 'Consultation des lectures des rencontres'},
          ],
          'summary': 'Comparaison des éléments disponibles.',
        },
      },
      _ => {},
    };
  }
}

const scope = IdentityScope.account('conversation-ux');
Map<String, dynamic> conversation([int exchanges = 14]) => {
  'id': 'restored-session',
  'revision': 2,
  'messages': [
    for (var i = 0; i < exchanges; i++) ...[
      {
        'role': 'user',
        'text': 'Ma demande $i concernant les rencontres du jour.',
      },
      {
        'role': 'assistant',
        'text':
            'Réponse $i. Voici les éléments disponibles pour cette journée. '
            'Les lectures et le contexte doivent être examinés ensemble. '
            'Je compare les observations et indique les limites des données.',
      },
    ],
  ],
  'tickets': <Object>[],
};

Widget screen(
  ConversationService service,
  ScopedPersistence persistence, {
  Key? pageKey,
  ThemeData? theme,
  Future<Map<String, RadarScope>> Function()? loadRadarContext,
}) => MaterialApp(
  theme: theme ?? CopilotTheme.dark,
  home: Scaffold(
    body: RepaintBoundary(
      key: const ValueKey('chat-capture'),
      child: LectorGeneratorPage(
        key: pageKey,
        date: DateTime(2026, 10, 9),
        scope: scope,
        repository: service,
        persistence: persistence,
        loadContext: () async =>
            GeneratorContext(origin: 'profile', preferences: {}),
        loadRadarContext: loadRadarContext,
        onPreferences: () {},
        onOpenMatch: (_) {},
      ),
    ),
  ),
);

Future<ScopedPersistence> savedReference() async {
  final persistence = ScopedPersistence(store: MemoryLocalKeyValueStore());
  await persistence.write(
    scope,
    'generator.conversation.v1',
    jsonEncode({'id': 'restored-session', 'date': '2026-10-09'}),
  );
  return persistence;
}

ScrollPosition position(WidgetTester tester) => tester
    .widget<ListView>(
      find.byKey(const ValueKey('generator-conversation-scroll')),
    )
    .controller!
    .position;

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets(
    'restoration shows a skeleton then opens at the latest messages on every visit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ConversationService();
      final persistence = await savedReference();
      await tester.pumpWidget(screen(service, persistence));
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        find.byKey(const ValueKey('generator-conversation-skeleton')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Quelle journée souhaitez-vous'),
        findsNothing,
      );
      expect(find.byTooltip('Envoyer la demande'), findsOneWidget);
      service.restored.complete({'state': conversation()});
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('generator-conversation-skeleton')),
        findsNothing,
      );
      expect(position(tester).extentAfter, lessThan(1));
      expect(find.textContaining('Réponse 13.'), findsOneWidget);

      // Recreating the tab must restore the same owner reference and anchor again.
      await tester.pumpWidget(
        screen(service, persistence, pageKey: const ValueKey('second-visit')),
      );
      await tester.pumpAndSettle();
      expect(service.requests.where((r) => r['action'] == 'read').length, 2);
      expect(position(tester).extentAfter, lessThan(1));
      expect(find.text('Générateur'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'suggestions send immediately and leave an editable empty composer',
    (tester) async {
      final service = ConversationService();
      final persistence = ScopedPersistence(store: MemoryLocalKeyValueStore());
      await tester.pumpWidget(screen(service, persistence));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top 5 dans Pour moi'));
      await tester.pump();
      final chats = service.requests
          .where((r) => r['action'] == 'chat')
          .toList();
      expect(chats.length, 1);
      expect(chats.single['message'], 'Top 5 dans Pour moi pour 2026-10-09.');
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('generator-message-input')),
      );
      expect(input.controller!.text, isEmpty);
      expect(input.enabled, isTrue);
      await tester.enterText(find.byType(TextField), 'Une prochaine question');
      service.reply.complete({'state': conversation(1)});
      await tester.pumpAndSettle();
      expect(input.controller!.text, 'Une prochaine question');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Radar request sends the exact UI membership lazily, with an explicit loading phase',
    (tester) async {
      final service = ConversationService();
      final persistence = ScopedPersistence(store: MemoryLocalKeyValueStore());
      var loads = 0;
      final loading = Completer<Map<String, RadarScope>>();
      await tester.pumpWidget(
        screen(
          service,
          persistence,
          loadRadarContext: () {
            loads++;
            return loading.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 0);
      await tester.enterText(
        find.byType(TextField),
        'Deux équipes du radar aujourd’hui',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer la demande'));
      await tester.pump();
      expect(loads, 1);
      expect(find.text('Consultation de votre Radar…'), findsOneWidget);
      expect(service.requests.where((r) => r['action'] == 'chat'), isEmpty);
      final displayed = RadarScope(
        mode: 'teams',
        category: 'club',
        capturedAt: DateTime.utc(2026, 10, 9),
        sourceIds: const ['11111111-1111-4111-8111-111111111111'],
        teams: const [
          RadarMember(
            id: '2',
            teamId: '2',
            rank: 1,
            matchIds: ['10', '11', '12', '13', '14'],
          ),
        ],
        players: const [],
      );
      loading.complete({'football': displayed});
      await tester.pump();
      await tester.pump();
      final body = service.requests.singleWhere((r) => r['action'] == 'chat');
      final context = body['context'] as Map<String, Object?>;
      expect((context['radar'] as Map)['football'], displayed.toJson());
      service.reply.complete({'state': conversation(1)});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reading older messages is preserved while progress and the response arrive',
    (tester) async {
      final service = ConversationService();
      final persistence = await savedReference();
      service.restored.complete({'state': conversation()});
      await tester.pumpWidget(screen(service, persistence));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Compare ces rencontres');
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer la demande'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(
        find.byKey(const ValueKey('generator-conversation-scroll')),
        const Offset(0, 1200),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final offset = position(tester).pixels;
      expect(position(tester).extentAfter, greaterThan(100));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(position(tester).pixels, closeTo(offset, 1));
      service.reply.complete({'state': conversation(15)});
      await tester.pumpAndSettle();
      expect(position(tester).pixels, closeTo(offset, 1));
      await tester.tap(find.byTooltip('Aller aux derniers messages'));
      await tester.pumpAndSettle();
      expect(position(tester).extentAfter, lessThan(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('conversation options remain available in the composer', (
    tester,
  ) async {
    final service = ConversationService();
    await tester.pumpWidget(
      screen(service, ScopedPersistence(store: MemoryLocalKeyValueStore())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Options de la conversation'));
    await tester.pumpAndSettle();
    expect(find.text('Vos brouillons'), findsOneWidget);
    expect(find.text('Nouvelle conversation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile chat is legible at 320px with expandable progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (Platform.environment['LECTOR_CAPTURE_CHAT_UI'] == 'true') {
      await tester.runAsync(() async {
        for (final (name, path) in [
          ('Inter', '/System/Library/Fonts/Supplemental/Arial.ttf'),
          (
            'MaterialIcons',
            '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ),
        ]) {
          final loader = FontLoader(name)
            ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
          await loader.load();
        }
      });
    }
    final service = ConversationService();
    service.restored.complete({
      'state': {
        ...conversation(1),
        'messages': [
          {
            'role': 'user',
            'text': 'Propose-moi deux rencontres du Radar pour aujourd’hui.',
          },
          {
            'role': 'assistant',
            'text':
                'Je vais comparer les rencontres du périmètre demandé, leurs lectures et les marchés disponibles.',
          },
        ],
      },
    });
    final persistence = await savedReference();
    await tester.pumpWidget(screen(service, persistence));
    await tester.pumpAndSettle();
    final user = tester.getRect(
      find.byKey(const ValueKey('generator-user-message')),
    );
    final assistant = tester.getRect(
      find.byKey(const ValueKey('generator-assistant-message')),
    );
    expect(user.left, greaterThan(assistant.left));
    expect(user.right, closeTo(assistant.right, 1));
    await tester.enterText(find.byType(TextField), 'Compare les arguments');
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer la demande'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    if (Platform.environment['LECTOR_CAPTURE_CHAT_UI'] == 'true') {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('chat-capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/private/tmp/lector-generator-chat-mobile.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.byKey(const ValueKey('generator-analysis-progress')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Comparaison des éléments disponibles.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('progress respects reduced motion without a running shimmer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const GeneratorAnalysisProgress(
              phase: 'Réflexion en cours…',
              progress: {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Réflexion en cours…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
