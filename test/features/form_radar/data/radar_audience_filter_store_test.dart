import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/features/form_radar/data/radar_audience_filter_store.dart';
import 'package:copilot/features/form_radar/domain/radar_audience_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('remembers choices independently for each account and guest', () async {
    const store = SharedPreferencesRadarAudienceFilterStore();
    const accountA = IdentityScope.account('a');
    const accountB = IdentityScope.account('b');
    const guest = IdentityScope.guest('visitor');
    await store.save(accountA, const RadarAudienceFilter(includeWomen: true));
    await store.save(guest, const RadarAudienceFilter(includeYouth: true));
    expect((await store.load(accountA)).includeWomen, isTrue);
    expect((await store.load(accountA)).includeYouth, isFalse);
    expect((await store.load(accountB)).exclusionCount, 2);
    expect((await store.load(guest)).includeWomen, isFalse);
    expect((await store.load(guest)).includeYouth, isTrue);
    expect((await store.load(const IdentityScope.device())).exclusionCount, 2);
  });

  test('corrupt local data resets to default exclusions', () async {
    SharedPreferences.setMockInitialValues({
      'lector.radar.audience.v1:account:a': 'invalid-json',
    });
    const store = SharedPreferencesRadarAudienceFilterStore();
    expect(
      (await store.load(const IdentityScope.account('a'))).exclusionCount,
      2,
    );
  });
}
