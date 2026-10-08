import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_loading.dart';
import 'package:copilot/core/widgets/lector_deferred_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

void main() {
  for (final theme in [AppTheme.dark, AppTheme.light]) {
    testWidgets(
      'all loading shapes fit mobile with large text in ${theme.brightness}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final kind in LectorSkeletonKind.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 844),
                  disableAnimations: true,
                  textScaler: TextScaler.linear(1.5),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: LectorLoading(key: ValueKey(kind), kind: kind),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'match detail keeps its skeleton until automatic recovery succeeds',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: LectorDeferredContent<String>(
            title: 'Home · Away',
            load: () async {
              if (++calls == 1) throw TimeoutException('temporary');
              return 'Details ready';
            },
            builder: (context, result) => Text(result),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LectorLoading), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Details ready'), findsOneWidget);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
