import 'dart:io';
import 'dart:ui' as ui;
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/domain/lector_recorded_radar.dart';
import 'package:copilot/core/domain/lector_radar_contributions.dart';
import 'package:copilot/core/domain/lector_temporal_state.dart';
import 'package:copilot/core/widgets/lector_workspace_navigation.dart';
import 'package:copilot/core/widgets/lector_temporal_feed.dart';
import 'package:copilot/core/widgets/lector_match_card.dart';
import 'package:copilot/core/widgets/lector_live_badge.dart';
import 'package:copilot/core/widgets/lector_recorded_radar_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/core/widgets/lector_navigation_live_visual_test.dart'
    show radarRecord;

void main() {
  testWidgets('render the actual shared widgets at mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
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
    final boundary = GlobalKey();
    final radar = LectorRecordedRadar.parse(radarRecord(), 'football', '100')!;
    final contributions = footballRadarContributions(radar, [
      {
        'type': 'Goal',
        'detail': 'Normal Goal',
        'team': {'id': 2},
        'player': {'id': 7},
        'time': {'elapsed': 33},
      },
    ], DateTime.parse('2026-10-09T18:40:00Z'));
    Widget card(bool live) => LectorMatchCard(
      onTap: () {},
      temporal: LectorTemporalState(
        phase: live ? LectorMatchPhase.live : LectorMatchPhase.finished,
      ),
      header: Row(
        children: [
          Text(live ? 'Eliteserien' : 'Liga Portugal 2'),
          const Spacer(),
          if (live)
            const LectorLiveBadge(
              state: LectorTemporalState(
                phase: LectorMatchPhase.live,
                clock: '33′',
              ),
            )
          else
            const Text('Terminé'),
        ],
      ),
      teams: LectorMatchTeams(
        first: LectorTeamLine(
          name: live ? 'Vålerenga' : 'Farense',
          score: live ? 1 : 2,
          isLive: live,
        ),
        second: LectorTeamLine(
          name: live ? 'Brann' : 'Chaves',
          score: 0,
          isLive: live,
        ),
      ),
      contextPanel: live
          ? LectorRecordedRadarPanel(
              snapshot: radar,
              contributions: contributions,
              isLive: true,
            )
          : null,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: AppTheme.dark.scaffoldBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Football ⌄',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    LectorWorkspaceNavigation(
                      selected: LectorWorkspaceSection.forMe,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'À suivre aujourd’hui',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LectorTemporalFeed<bool>(
                      items: const [true, false],
                      phaseOf: (v) =>
                          v ? LectorMatchPhase.live : LectorMatchPhase.finished,
                      sectionBuilder: (context, items, phase) => Column(
                        children: [for (final item in items) card(item)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('output/visual-iteration/navigation-live-mobile.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });
  });
}
