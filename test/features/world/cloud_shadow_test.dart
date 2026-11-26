import 'package:echos_del_tiempo/features/world/presentation/map/region_light_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ground cloud shadows are clearly visible (biome_regions.md § 7.1).
void main() {
  final r = kTuning[TuningId.regions]!;
  const top = RegionLightLayer.cloudLevels;

  test('full cover reaches the tuned peak alpha at the center', () {
    expect(RegionLightLayer.shadowAlpha(1, top),
        closeTo(r.d('cloudShadowAlpha'), 1e-9));
    expect(r.d('cloudShadowAlpha'), greaterThanOrEqualTo(0.3));
  });

  test('low cover still casts a noticeable shadow', () {
    final low = RegionLightLayer.shadowAlpha(0.125, top);
    expect(low, greaterThanOrEqualTo(0.2));
    expect(low, RegionLightLayer.shadowAlpha(0.5, top));
  });

  test('the rim fades in steps toward the edge', () {
    final a = [
      for (var s = 1; s <= top; s++) RegionLightLayer.shadowAlpha(1, s)
    ];
    for (var i = 1; i < a.length; i++) {
      expect(a[i], greaterThan(a[i - 1]));
    }
  });
}
