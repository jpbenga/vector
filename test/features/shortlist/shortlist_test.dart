import 'dart:async';
import 'dart:convert';
import 'package:copilot/core/di/service_locator.dart';
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/identity/scoped_persistence.dart';
import 'package:copilot/core/persistence/local_key_value_store_base.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/shortlist/application/shortlist_controller.dart';
import 'package:copilot/features/shortlist/data/shortlist_repository.dart';
import 'package:copilot/features/shortlist/domain/shortlist.dart';
import 'package:copilot/features/shortlist/presentation/shortlist_page.dart';
import 'package:copilot/features/shortlist/presentation/shortlist_actions.dart';
import 'package:copilot/features/shortlist/presentation/shortlist_comparison_page.dart';
import 'package:copilot/features/generator/presentation/lector_generator_page.dart';
import 'package:copilot/features/generator/domain/generator_context.dart';
import 'package:copilot/features/generator/data/generator_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final now = DateTime.utc(2026, 10, 11, 10);
ShortlistSnapshot snapshot({
  String id = 'session-a',
  int revision = 1,
  List<String> keys = const ['football:1', 'hockey:1'],
  DateTime? expires,
}) => ShortlistSnapshot({
  'serverNow': now.toIso8601String(),
  'sessions': [
    {
      'id': id,
      'revision': revision,
      'status': 'active',
      'expiresAt': (expires ?? now.add(const Duration(hours: 24)))
          .toIso8601String(),
      'recoverableUntil': (expires ?? now.add(const Duration(hours: 24)))
          .add(const Duration(hours: 24))
          .toIso8601String(),
      'items': [
        for (final key in keys)
          {
            'key': key,
            'sport': key.split(':')[0],
            'fixtureId': key.split(':')[1],
            'date': '2026-10-12',
            'fixture': {
              'home': 'Équipe à domicile au nom très long',
              'away': 'Équipe à l’extérieur',
              'competition': 'Championnat',
              'kickoff': now.add(const Duration(days: 1)).toIso8601String(),
              'status': 'scheduled',
            },
          },
      ],
      'extensionOptions': <Object>[],
    },
  ],
});

class Store implements LocalKeyValueStore {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async {
    if (fail) throw StateError('storage unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class Repo implements ShortlistRepository {
  final calls = <String>[];
  ShortlistSnapshot value = snapshot();
  Future<ShortlistSnapshot> Function(String)? execute;
  @override
  Future<ShortlistSnapshot> request(
    String action, {
    String? session,
    ShortlistFixture? fixture,
    DateTime? until,
    int? revision,
  }) {
    calls.add(action);
    return execute?.call(action) ?? Future.value(value);
  }
}

class ConversationRepo implements GeneratorRepository {
  final calls = <Map<String, Object?>>[];
  @override
  Future<Map<String, dynamic>> request(Map<String, Object?> body) async {
    calls.add(body);
    if (body['action'] == 'prepare') {
      return {
        'preparation': {'matchCount': 2, 'radarCount': 0},
      };
    }
    if (body['action'] == 'shortlist_inspect') {
      return {
        'matches': [
          for (final names in [
            ['Lille', 'Marseille'],
            ['Brann', 'Viking'],
          ])
            {
              'home': names[0],
              'away': names[1],
              'sport': 'football',
              'competition': 'Ligue de test',
              'kickoff': '2026-10-12T18:00:00Z',
              'evidence': <Object>[],
              'candidates': <Object>[],
            },
        ],
        'missing': <Object>[],
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
          {'role': 'assistant', 'text': 'Préparation conservée'},
        ],
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));
  test(
    'cross-sport identities, final results and unavailable publications remain distinct',
    () {
      final fixtures = snapshot().sessions.single.items;
      expect(fixtures.map((f) => f.key), ['football:1', 'hockey:1']);
      expect(fixtures.first.phase(now), 'upcoming');
      expect(
        ShortlistFixture({...fixtures.first.json, 'status': 'FT'}).phase(now),
        'finished',
      );
      expect(
        ShortlistFixture({
          ...fixtures.first.json,
          'available': false,
        }).phase(now),
        'unavailable',
      );
      expect(
        snapshot(
          expires: now.subtract(const Duration(hours: 1)),
        ).recoverable(now),
        hasLength(1),
      );
    },
  );
  test(
    'a response for a former account cannot repopulate the next account',
    () async {
      final repo = Repo(), store = Store();
      final pending = Completer<ShortlistSnapshot>();
      repo.execute = (_) => pending.future;
      final c = ShortlistController(
        repository: repo,
        persistence: ScopedPersistence(store: store),
        clock: () => now,
      );
      final first = c.bindAccount('a');
      await Future<void>.delayed(Duration.zero);
      repo.execute = (_) async => ShortlistSnapshot({
        'serverNow': now.toIso8601String(),
        'sessions': <Object>[],
      });
      await c.bindAccount('b');
      pending.complete(snapshot());
      await first;
      expect(c.account, 'b');
      expect(c.items, isEmpty);
      expect(c.selected, isEmpty);
      expect(store.values.keys.any((k) => k.contains('account:a')), false);
      c.dispose();
    },
  );
  test(
    'broken browser storage does not prevent loading or successful mutations',
    () async {
      final store = Store()..fail = true, repo = Repo();
      final c = ShortlistController(
        repository: repo,
        persistence: ScopedPersistence(store: store),
        clock: () => now,
      );
      await c.bindAccount('a');
      expect(c.items, hasLength(2));
      await c.mutate('remove', fixture: c.items.first);
      expect(c.error, isNull);
      final deadline = c.active!.expiresAt;
      c.choose('football:1', true);
      expect(c.active!.expiresAt, deadline);
      expect(repo.calls, ['read', 'remove']);
      c.dispose();
    },
  );
  test(
    'cache displays immediately and refresh keeps data while pending',
    () async {
      final store = Store(), repo = Repo();
      store.values[const ScopedPersistence().keyFor(
        IdentityScope.account('a'),
        'shortlist.v1',
      )] = jsonEncode(
        snapshot().json,
      );
      final pending = Completer<ShortlistSnapshot>();
      repo.execute = (_) => pending.future;
      final c = ShortlistController(
        repository: repo,
        persistence: ScopedPersistence(store: store),
        clock: () => now,
      );
      final load = c.bindAccount('a');
      await Future<void>.delayed(Duration.zero);
      expect(c.items, hasLength(2));
      expect(c.loading, true);
      pending.complete(snapshot(revision: 2));
      await load;
      expect(c.active!.revision, 2);
      c.dispose();
    },
  );
  test('a pending read cannot overwrite a completed mutation', () async {
    final repo = Repo(), store = Store();
    final c = ShortlistController(
      repository: repo,
      persistence: ScopedPersistence(store: store),
      clock: () => now,
    );
    await c.bindAccount('a');
    final read = Completer<ShortlistSnapshot>(),
        edit = Completer<ShortlistSnapshot>();
    repo.execute = (action) => action == 'read' ? read.future : edit.future;
    final mutation = c.mutate('add');
    await Future<void>.delayed(Duration.zero);
    final refresh = c.refresh();
    edit.complete(
      snapshot(revision: 2, keys: ['football:1', 'hockey:1', 'football:2']),
    );
    await mutation;
    read.complete(snapshot());
    await refresh;
    expect(c.active!.revision, 2);
    expect(c.items, hasLength(3));
    c.dispose();
  });
  testWidgets(
    'Shortlist fits 320px and comparing selects two fixtures from different sports',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = Repo(),
          c = ShortlistController(
            repository: repo,
            persistence: ScopedPersistence(store: Store()),
            clock: () => now,
          );
      await c.bindAccount('a');
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: ShortlistPage(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      c.choose('football:1', true);
      c.choose('hockey:1', true);
      await tester.pump();
      final compare = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('shortlist-compare')),
      );
      expect(compare.onPressed, isNotNull);
      expect(repo.calls.every((a) => a == 'read'), true);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'comparison keeps four team identities and clears private data on account switch',
    (tester) async {
      final repo = Repo(),
          c = ShortlistController(
            repository: repo,
            persistence: ScopedPersistence(store: Store()),
            clock: () => now,
          );
      await c.bindAccount('a');
      final service = ConversationRepo();
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: ShortlistComparisonPage(
            controller: c,
            keys: ['football:1', 'hockey:1'],
            repository: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lille — Marseille'), findsOneWidget);
      expect(find.text('Brann — Viking'), findsOneWidget);
      expect(service.calls.single['action'], 'shortlist_inspect');
      await c.bindAccount('b');
      await tester.pumpAndSettle();
      expect(find.text('Lille — Marseille'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'a Shortlist conversation keeps its id across dates and restores its own reference',
    (tester) async {
      final persistence = ScopedPersistence(store: Store()),
          service = ConversationRepo();
      Widget page(DateTime date) => MaterialApp(
        theme: CopilotTheme.dark,
        home: Scaffold(
          body: LectorGeneratorPage(
            date: date,
            scope: IdentityScope.account('a'),
            workspaceKey: 'shortlist:session-a',
            repository: service,
            persistence: persistence,
            loadContext: () async => GeneratorContext(
              origin: 'profile',
              preferences: {
                'football': <String, List<String>>{
                  'competitions': [],
                  'readings': [],
                  'markets': [],
                },
              },
              shortlist: {
                'sessionId': 'session-a',
                'revision': 1,
                'keys': ['football:1'],
              },
            ),
            onOpenMatch: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(page(now));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('generator-message-input')),
        'Compare ma préparation',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer la demande'));
      await tester.pumpAndSettle();
      final id = service.calls.singleWhere(
        (c) => c['action'] == 'chat',
      )['conversationId'];
      await tester.pumpWidget(page(now.add(const Duration(days: 1))));
      await tester.pumpAndSettle();
      expect(find.text('Préparation conservée'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page(now.add(const Duration(days: 2))));
      await tester.pumpAndSettle();
      expect(
        service.calls.singleWhere(
          (c) => c['action'] == 'read',
        )['conversationId'],
        id,
      );
      final reference =
          (service.calls.singleWhere((c) => c['action'] == 'chat')['context']
                  as Map)['shortlist']
              as Map;
      expect(reference.keys.toSet(), {'sessionId', 'revision', 'keys'});
      expect(service.calls.where((c) => c['action'] == 'chat'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('adding a fixture does not open its enclosing detail link', (
    tester,
  ) async {
    final repo = Repo(),
        c = ShortlistController(
          repository: repo,
          persistence: ScopedPersistence(store: Store()),
          clock: () => now,
        );
    await c.bindAccount('a');
    repo.execute = (action) async {
      repo.value = snapshot(
        keys: action == 'remove'
            ? const ['hockey:1']
            : const ['football:1', 'hockey:1'],
        revision: repo.value.active(now)!.revision + 1,
      );
      return repo.value;
    };
    getIt.registerSingleton<ShortlistController>(c);
    bool opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark,
        home: Scaffold(
          body: GestureDetector(
            onTap: () => opened = true,
            child: ShortlistAddButton(fixture: c.items.first),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('shortlist-add:football:1')));
    await tester.pumpAndSettle();
    expect(opened, false);
    expect(repo.calls.last, 'remove');
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shortlist-add:football:1')));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'add');
    expect(opened, false);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await getIt.unregister<ShortlistController>();
    c.dispose();
  });
}
