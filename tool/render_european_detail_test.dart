// Visual QA of real public sporting publications; no provider, model or account request.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/di/service_locator.dart';
import 'package:copilot/features/matches/data/api_football_match_adapter.dart';
import 'package:copilot/features/matches/presentation/match_detail_page.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/shortlist/application/shortlist_controller.dart';
import 'package:copilot/features/shortlist/data/shortlist_repository.dart';
import 'package:copilot/features/shortlist/domain/shortlist.dart';

class _NoPersonalWrites implements ShortlistRepository {
  @override
  Future<ShortlistSnapshot> request(
    String action, {
    String? session,
    ShortlistFixture? fixture,
    DateTime? until,
    int? revision,
  }) async => ShortlistSnapshot({
    'serverNow': DateTime.now().toUtc().toIso8601String(),
    'sessions': <Map<String, Object?>>[],
  });
}

void main() {
  testWidgets('capture actual European detail in mobile and tablet layouts', (
    tester,
  ) async {
    await initializeDateFormatting('fr');
    await tester.runAsync(() async {
      await (FontLoader(
        'Inter',
      )..addFont(rootBundle.load('assets/fonts/Inter-variable.ttf'))).load();
      final bytes = await File(
        '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    });
    final rows =
        jsonDecode(
              File(
                '/private/tmp/lector-europe-publications/public-sources.json',
              ).readAsStringSync(),
            )
            as List;
    final matches = rows
        .expand(
          (r) => const ApiFootballMatchAdapter().fromSnapshot(
            Map<String, Object?>.from((r as Map)['payload'] as Map),
          ),
        )
        .where((m) => m.analysis.europeanComparison != null)
        .toList();
    matches.sort((a, b) {
      int score(MatchBoardItem m) =>
          m.analysis.europeanComparison!.home.domesticMatches.length +
          m.analysis.europeanComparison!.away.domesticMatches.length +
          m.analysis.europeanComparison!.home.europeanMatches.length +
          m.analysis.europeanComparison!.away.europeanMatches.length;
      return score(b).compareTo(score(a));
    });
    final match = matches.first;
    final controller = ShortlistController(repository: _NoPersonalWrites());
    getIt.registerSingleton<ShortlistController>(controller);
    final out = Directory('output/european-comparison/captures')
      ..createSync(recursive: true);
    for (final width in [320.0, 375.0, 390.0, 430.0, 768.0]) {
      tester.view.physicalSize = Size(width, 1300);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: RepaintBoundary(
            key: key,
            child: MatchDetailPage(match: match, onAskEuropean: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${out.path}/synthesis-${width.toInt()}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        img.dispose();
      });
      await tester.tap(find.text('Contexte'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${out.path}/context-${width.toInt()}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        img.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
    await File('${out.path}/fixture.json').writeAsString(
      jsonEncode({
        'fixtureId': match.fixture.apiFootballFixtureId,
        'home': match.homeTeam.name,
        'away': match.awayTeam.name,
        'dossier': match.analysis.europeanComparison!.json,
      }),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    getIt.unregister<ShortlistController>();
    controller.dispose();
  });
}
