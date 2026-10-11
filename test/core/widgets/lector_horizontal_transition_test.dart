import 'package:copilot/core/widgets/lector_horizontal_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget pane(
    num position, {
    bool reducedMotion = false,
    String text = 'pane',
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Center(
        child: SizedBox(
          width: 200,
          child: LectorHorizontalTransition(
            position: position,
            child: _RetainedPane(text: text),
          ),
        ),
      ),
    ),
  );

  testWidgets('moves in navigation order and retains a single mounted pane', (
    tester,
  ) async {
    _RetainedPane.mounts = 0;
    await tester.pumpWidget(pane(0));
    final origin = tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx;
    await tester.pumpWidget(pane(1));
    expect(tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx, origin);
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx,
      greaterThan(origin),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx, origin);
    await tester.pumpWidget(pane(0));
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx,
      lessThan(origin),
    );
    expect(_RetainedPane.mounts, 1);
    expect(find.byType(_RetainedPane), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('data refreshes do not restart a navigation transition', (
    tester,
  ) async {
    await tester.pumpWidget(pane(0));
    await tester.pumpWidget(pane(1));
    await tester.pump(const Duration(milliseconds: 220));
    final progress = tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx;
    await tester.pumpWidget(pane(1, text: 'updated'));
    expect(find.text('updated'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx, progress);
    await tester.pumpAndSettle();
  });

  testWidgets('rapid direction changes show only the latest content', (
    tester,
  ) async {
    await tester.pumpWidget(pane(0));
    final origin = tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx;
    await tester.pumpWidget(pane(4, text: 'forward'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(pane(2, text: 'backward'));
    expect(find.text('forward'), findsNothing);
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text('backward'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx,
      lessThan(origin),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('outgoing content fades before the destination is mounted', (
    tester,
  ) async {
    await tester.pumpWidget(pane(0, text: 'old'));
    await tester.pumpWidget(pane(1, text: 'new'));
    expect(find.text('old'), findsOneWidget);
    expect(find.text('new'), findsNothing);
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(.6));
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.text('old'), findsNothing);
    expect(find.text('new'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(.05));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('reduced motion stops movement without remounting content', (
    tester,
  ) async {
    _RetainedPane.mounts = 0;
    await tester.pumpWidget(pane(0));
    final origin = tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx;
    await tester.pumpWidget(pane(1));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(pane(2, reducedMotion: true));
    expect(tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx, origin);
    expect(_RetainedPane.mounts, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a sheet rises when opened and descends when dismissed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                sheetAnimationStyle: lectorSheetAnimationStyle(context),
                builder: (_) => const SizedBox(
                  key: ValueKey('sheet'),
                  height: 200,
                  child: Text('Sheet'),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final rising = tester.getTopLeft(find.byKey(const ValueKey('sheet'))).dy;
    await tester.pumpAndSettle();
    final open = tester.getTopLeft(find.byKey(const ValueKey('sheet'))).dy;
    expect(rising, greaterThan(open));
    final sheetContext = tester.element(find.byKey(const ValueKey('sheet')));
    Navigator.of(sheetContext).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('sheet'))).dy,
      greaterThan(open),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet')), findsNothing);
  });
}

class _RetainedPane extends StatefulWidget {
  const _RetainedPane({required this.text});
  final String text;
  static int mounts = 0;

  @override
  State<_RetainedPane> createState() => _RetainedPaneState();
}

class _RetainedPaneState extends State<_RetainedPane> {
  @override
  void initState() {
    super.initState();
    _RetainedPane.mounts++;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('pane'),
    height: 100,
    child: Text(widget.text),
  );
}
