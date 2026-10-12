// Renders the actual Flutter prototype, not a generated UI image.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_workspace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'previews/compact_matches_preview.dart';

void main() {
  testWidgets('render the two published match prototypes at supported widths', (
    tester,
  ) async {
    await initializeDateFormatting('fr');
    await tester.runAsync(() async {
      await (FontLoader(
        'Inter',
      )..addFont(rootBundle.load('assets/fonts/Inter-variable.ttf'))).load();
      final icons = await File(
        '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    });
    final matches = (await tester.runAsync(loadCompactPreviewMatches))!;
    for (final (name, width, height, section, light, scale) in [
      ('for-me-320', 320.0, 920.0, LectorWorkspaceSection.forMe, false, 1.0),
      ('for-me-375', 375.0, 900.0, LectorWorkspaceSection.forMe, false, 1.0),
      ('for-me-390', 390.0, 900.0, LectorWorkspaceSection.forMe, false, 1.0),
      ('all-430', 430.0, 900.0, LectorWorkspaceSection.all, false, 1.0),
      ('all-tablet', 768.0, 1024.0, LectorWorkspaceSection.all, false, 1.0),
      (
        'large-text-light',
        320.0,
        1100.0,
        LectorWorkspaceSection.forMe,
        true,
        1.5,
      ),
    ]) {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            key: ValueKey(name),
            debugShowCheckedModeBanner: false,
            theme: light ? CopilotTheme.light : CopilotTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: CompactMatchesPreviewPage(
              matches: matches,
              initialSection: section,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final asset in [
          'assets/brand/ls-logo-mark-clean.png',
          'assets/backgrounds/competition-champions-original-v1.png',
        ]) {
          await precacheImage(AssetImage(asset), boundary.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/compact-match-design/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
