// Actual shared Flutter surfaces and archived public fixtures; no model/provider calls.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:copilot/features/matches/data/api_football_match_adapter.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:copilot/features/matches/presentation/widgets/european_evening_briefing.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import '../test/core/theme/competition_card_theme_test.dart'
    show selectableThemes;

void main() {
  testWidgets('capture archived fixtures and briefing in all selectable themes', (
    tester,
  ) async {
    await initializeDateFormatting('fr');
    await tester.runAsync(() async {
      for (final file in ['Regular', 'Medium', 'Bold', 'Black']) {
        await (FontLoader(
          'Roboto',
        )..addFont(rootBundle.load('assets/fonts/Roboto-$file.ttf'))).load();
      }
      final icons = await File(
        '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    });
    final matches = <MatchBoardItem>[];
    for (final file in [
      '/private/tmp/lector-public-delivery-cache/ab203c43-3918-47ca-8851-aa4bc772633d.json',
      '/private/tmp/lector-public-delivery-cache/97ccbbec-5c22-4e7f-932d-82accf6ead2e.json',
      '/private/tmp/lector-public-delivery-cache/f23d1ee8-0de8-4590-b657-e7eaf24f3d7f.json',
    ]) {
      final source =
          jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
      final items = const ApiFootballMatchAdapter().fromSnapshot(
        source['payload'] as Map<String, dynamic>,
      );
      matches.add(items.first);
    }
    final league = const ApiFootballMatchAdapter()
        .fromSnapshot(
          jsonDecode(
                File('assets/design_preview/league.json').readAsStringSync(),
              )
              as Map<String, dynamic>,
        )
        .single;
    final out =
        Platform.environment['LECTOR_THEME_CAPTURES'] ??
        'output/competition-themes';
    for (final entry in selectableThemes.entries) {
      tester.view.physicalSize = const Size(390, 1350);
      tester.view.devicePixelRatio = 1;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(entry.key),
          debugShowCheckedModeBanner: false,
          theme: entry.value,
          themeAnimationDuration: Duration.zero,
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  EuropeanEveningBriefing(
                    matches: matches,
                    date: DateTime(2026, 10, 13),
                    showReadings: false,
                    onOpenMatch: (_) {},
                  ),
                  for (final match in [league, ...matches])
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: MatchFeedCard(
                        match: match,
                        showReadings: false,
                        onTap: () {},
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final identity in ['champions', 'europa', 'conference']) {
          await precacheImage(
            AssetImage(
              'assets/backgrounds/competition-$identity-original-v1.png',
            ),
            boundary.currentContext!,
          );
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final target = File('$out/${entry.key}.png');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
