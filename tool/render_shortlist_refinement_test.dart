// Visual fixture only. No user data, provider requests or model calls.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:copilot/core/identity/scoped_persistence.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/shortlist/application/shortlist_controller.dart';
import 'package:copilot/features/shortlist/domain/shortlist.dart';
import 'package:copilot/features/shortlist/presentation/shortlist_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../test/features/shortlist/shortlist_test.dart' show Repo, Store;

void main() {
  testWidgets('render actual Shortlist at phone and desktop sizes', (
    tester,
  ) async {
    await initializeDateFormatting('fr');
    await tester.runAsync(() async {
      for (final (family, file) in [
        ('Inter', '/System/Library/Fonts/Supplemental/Arial.ttf'),
        (
          'MaterialIcons',
          '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ),
      ]) {
        final bytes = await File(file).readAsBytes();
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
    final now = DateTime(2026, 10, 11, 21, 36);
    final repo = Repo()
      ..value = ShortlistSnapshot({
        'serverNow': now.toIso8601String(),
        'sessions': [
          {
            'id': 'visual-session',
            'revision': 1,
            'lastModifiedAt': now
                .subtract(const Duration(hours: 6))
                .toIso8601String(),
            'expiresAt': now.add(const Duration(hours: 18)).toIso8601String(),
            'recoverableUntil': now
                .add(const Duration(hours: 42))
                .toIso8601String(),
            'extensionOptions': <Map<String, Object?>>[],
            'items': [
              for (final (i, home, away, competition, hours, readings) in [
                (
                  1,
                  'Lille',
                  'Marseille',
                  'Ligue 1',
                  22,
                  ['positive_streak', 'standing_advantage', 'strong_home_team'],
                ),
                (
                  2,
                  'Atalanta',
                  'Venezia',
                  'Serie A',
                  21,
                  ['positive_streak', 'weak_home_team'],
                ),
                (
                  3,
                  'Brann',
                  'Viking',
                  'Eliteserien',
                  23,
                  [
                    'positive_streak',
                    'standing_advantage',
                    'strong_home_team',
                    'recent_form_advantage',
                  ],
                ),
                (
                  4,
                  'Laval Rocket',
                  'Hartford Wolf Pack',
                  'AHL',
                  25,
                  ['negative_streak', 'strong_home_team', 'standing_advantage'],
                ),
              ])
                {
                  'sport': i == 4 ? 'hockey' : 'football',
                  'fixtureId': '$i',
                  'date': '2026-10-12',
                  'fixture': {
                    'home': home,
                    'away': away,
                    'competition': competition,
                    'kickoff': now
                        .add(Duration(hours: hours))
                        .toIso8601String(),
                    'status': 'scheduled',
                    'readings': [
                      for (final id in readings) {'id': id},
                    ],
                  },
                },
            ],
          },
        ],
      });
    final controller = ShortlistController(
      repository: repo,
      persistence: ScopedPersistence(store: Store()),
      clock: () => now,
    );
    await controller.bindAccount('visual-only');
    controller.choose('football:1', true);
    for (final (name, size, theme, scale) in [
      ('phone', const Size(393, 852), CopilotTheme.dark, 1.0),
      ('narrow', const Size(320, 844), CopilotTheme.dark, 1.0),
      ('desktop', const Size(1440, 900), CopilotTheme.dark, 1.0),
      ('large-text', const Size(320, 844), CopilotTheme.light, 1.5),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            key: ValueKey(name),
            initialRoute: '/shortlist',
            routes: {
              '/': (_) => const Scaffold(),
              '/shortlist': (_) =>
                  ShortlistPage(controller: controller, onNavigate: (_) {}),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/shortlist-refinement/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
