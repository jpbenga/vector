import 'package:copilot/core/theme/app_theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppThemeController', () {
    test('restores the persisted theme when a new session starts', () async {
      final store = _MemoryThemePreferenceStore('tokyoNight');
      final controller = AppThemeController(preferenceStore: store);

      await controller.restore();

      expect(controller.variant, AppThemeVariant.tokyoNight);
    });

    test('persists each user selection independently of authentication', () {
      final store = _MemoryThemePreferenceStore();
      final controller = AppThemeController(preferenceStore: store);

      controller.select(AppThemeVariant.catppuccinLatte);

      expect(store.value, 'catppuccinLatte');
    });

    test('restores a selection after a fresh controller is created', () async {
      final store = _MemoryThemePreferenceStore();
      final firstSession = AppThemeController(preferenceStore: store)
        ..select(AppThemeVariant.dracula);
      final nextSession = AppThemeController(preferenceStore: store);

      await nextSession.restore();

      expect(firstSession.variant, AppThemeVariant.dracula);
      expect(nextSession.variant, AppThemeVariant.dracula);
    });

    test('keeps the default theme when persisted data is obsolete', () async {
      final store = _MemoryThemePreferenceStore('retired-theme');
      final controller = AppThemeController(preferenceStore: store);

      await controller.restore();

      expect(controller.variant, AppThemeVariant.vectorDark);
    });

    test('recognises every added light variant for the header toggle', () {
      expect(AppThemeVariant.catppuccinLatte.isLight, isTrue);
      expect(AppThemeVariant.solarizedLight.isLight, isTrue);
      expect(AppThemeVariant.quietLight.isLight, isTrue);
      expect(AppThemeVariant.dracula.isLight, isFalse);
      expect(AppThemeVariant.tokyoNight.isLight, isFalse);
      expect(AppThemeVariant.catppuccinMocha.isLight, isFalse);
    });
  });
}

class _MemoryThemePreferenceStore implements AppThemePreferenceStore {
  _MemoryThemePreferenceStore([this.value]);

  String? value;

  @override
  Future<String?> readVariantName() async => value;

  @override
  Future<void> writeVariantName(String nextValue) async {
    value = nextValue;
  }
}
