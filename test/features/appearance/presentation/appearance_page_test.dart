import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/theme/app_components.dart';
import 'package:copilot/core/theme/app_theme_controller.dart';
import 'package:copilot/features/appearance/presentation/appearance_page.dart';
import 'package:copilot/features/appearance/presentation/appearance_preview.dart';
import 'package:copilot/features/form_radar/presentation/form_radar_signal_panel.dart';
import 'package:copilot/features/matches/presentation/widgets/lector_match_hero.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final variant in AppThemeVariant.values) {
    testWidgets(
      'Real match and Radar preview use ${variant.name} tokens on mobile',
      (tester) async {
        final controller = AppThemeController(initialVariant: variant);
        addTearDown(controller.dispose);
        await _pump(tester, controller);
        expect(find.byType(LectorMatchHero), findsOneWidget);
        expect(find.byType(FormRadarSignalPanel), findsOneWidget);
        expect(find.text('Dynamique positive'), findsOneWidget);
        expect(find.text('K. Mbappé'), findsOneWidget);
        expect(find.text('L. Yamal'), findsOneWidget);
        expect(find.text('Données d’exemple · Aperçu visuel'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('appearance-theme-vectorDark')),
          findsOneWidget,
        );
        final context = tester.element(
          find.byKey(const ValueKey('appearance-live-preview')),
        );
        final expected = AppTheme.forVariant(variant);
        expect(
          context.surfaces.background,
          expected.extension<AppSurfacePalette>()!.background,
        );
        expect(
          context.brand.accent,
          expected.extension<AppBrandPalette>()!.accent,
        );
        expect(
          context.textColors.primary,
          expected.extension<AppTextPalette>()!.primary,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Theme family selection updates preview and persists without changing the preview tab',
    (tester) async {
      final store = _Store();
      final controller = AppThemeController(preferenceStore: store);
      addTearDown(controller.dispose);
      await _pump(tester, controller);
      await _tap(tester, 'appearance-preview-match');
      expect(find.byType(MatchFeedCard), findsOneWidget);
      await _tap(tester, 'appearance-family-light');
      expect(
        find.byKey(const ValueKey('appearance-theme-dracula')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('appearance-theme-catppuccinLatte')),
        findsOneWidget,
      );
      await _tap(tester, 'appearance-theme-catppuccinLatte');
      expect(controller.variant, AppThemeVariant.catppuccinLatte);
      expect(store.value, 'catppuccinLatte');
      expect(
        tester.widget<AppearancePreview>(find.byType(AppearancePreview)).kind,
        AppearancePreviewKind.match,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('appearance-active-theme')))
            .data,
        'Catppuccin Latte',
      );
      final context = tester.element(find.byType(MatchFeedCard));
      expect(Theme.of(context).brightness, Brightness.light);
      expect(
        context.brand.accent,
        AppTheme.catppuccinLatte.extension<AppBrandPalette>()!.accent,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All preview categories remain usable on a narrow mobile with large text',
    (tester) async {
      final controller = AppThemeController();
      addTearDown(controller.dispose);
      await _pump(tester, controller, width: 320, textScale: 1.4);
      for (final kind in AppearancePreviewKind.values) {
        await _tap(tester, 'appearance-preview-${kind.name}');
        expect(
          tester.widget<AppearancePreview>(find.byType(AppearancePreview)).kind,
          kind,
        );
        expect(tester.takeException(), isNull, reason: kind.name);
      }
      final toggle = find.byType(Switch);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(controller.variant, AppThemeVariant.vectorDark);
    },
  );

  testWidgets(
    'Theme arrows stay within the chosen family and reset restores the default',
    (tester) async {
      final controller = AppThemeController(
        initialVariant: AppThemeVariant.dracula,
      );
      addTearDown(controller.dispose);
      await _pump(tester, controller);
      await _tap(tester, 'appearance-family-light');
      final next = find.byTooltip('Thème suivant');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(controller.variant, AppThemeVariant.vectorLight);
      await tester.tap(find.byTooltip('Thème précédent'));
      await tester.pumpAndSettle();
      expect(controller.variant, AppThemeVariant.quietLight);
      await _tap(tester, 'appearance-reset');
      expect(controller.variant, AppThemeVariant.vectorDark);
      expect(
        find.byKey(const ValueKey('appearance-theme-dracula')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('appearance-family-all')),
            )
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Desktop places the palette beside the preview; reduced motion selection works',
    (tester) async {
      final controller = AppThemeController();
      addTearDown(controller.dispose);
      await _pump(tester, controller, width: 1280, reducedMotion: true);
      final preview = tester.getRect(
        find.byKey(const ValueKey('appearance-live-preview')),
      );
      final choice = tester.getRect(
        find.byKey(const ValueKey('appearance-theme-vectorDark')),
      );
      expect(choice.left, greaterThan(preview.right));
      await _tap(tester, 'appearance-theme-tokyoNight');
      expect(controller.variant, AppThemeVariant.tokyoNight);
      await _pump(tester, controller, reducedMotion: true);
      await _tap(tester, 'appearance-theme-solarizedLight');
      expect(controller.variant, AppThemeVariant.solarizedLight);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  AppThemeController controller, {
  double width = 390,
  double textScale = 1,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.forVariant(controller.variant),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: AppearancePage(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

class _Store implements AppThemePreferenceStore {
  String? value;
  @override
  Future<String?> readVariantName() async => value;
  @override
  Future<void> writeVariantName(String name) async => value = name;
}
