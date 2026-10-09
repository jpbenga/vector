import 'dart:io';
import 'dart:ui' as ui;
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/features/hockey/presentation/hockey_context_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/features/sports/presentation/hockey_grouped_standings_test.dart'
    show nhl, fixture;

void main() {
  testWidgets('render actual hockey comparison widgets at mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final (family, path) in [
        ('Inter', '/System/Library/Fonts/Supplemental/Arial.ttf'),
        (
          'MaterialIcons',
          '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ),
      ]) {
        final bytes = await File(path).readAsBytes();
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      }
    });

    final dir = Directory('output/standing-comparison')
      ..createSync(recursive: true);
    final western = nhl.tables
        .firstWhere((t) => t.group == 'Western Conference')
        .rows
        .first
        .team
        .id;
    for (final (name, away) in [
      ('same-conference', fixture.away.id),
      ('cross-conference', western),
    ]) {
      final boundary = GlobalKey();
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: AppTheme.dark.scaffoldBackgroundColor,
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: HockeyStandingsPanel(
                      competition: nhl,
                      homeTeamId: fixture.home.id,
                      awayTeamId: away,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final (part, offset) in [('top', 0.0), ('comparison', 780.0)]) {
        scroll.jumpTo(offset.clamp(0, scroll.position.maxScrollExtent));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${dir.path}/$name-$part.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
