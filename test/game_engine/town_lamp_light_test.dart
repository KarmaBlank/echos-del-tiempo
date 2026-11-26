import 'package:echos_del_tiempo/game_engine/data/cozy_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Town lamps give light at night (cozy_life.md § 2,
/// renown_town_growth.md § 5.2, lighting.md § 3).
void main() {
  final map = GameMap(
      width: 20,
      height: 12,
      rows: List.filled(12, '.' * 20),
      theme: 'pueblo',
      spawn: const WorldPoint(8, 8));
  const origin = (3, 2);

  test('every light-type decor is a known decor with a light def', () {
    expect(kDecorLights, isNotEmpty);
    for (final MapEntry(:key, :value) in kDecorLights.entries) {
      expect(kFarmDecos, contains(key));
      expect(kLightDefs[value], isNotNull, reason: key);
    }
    // The small yellow lamp is a light-type decor.
    expect(kDecorLights, contains('lamp'));
  });

  test('each light-type decor emits and lights the map at its tile', () {
    for (final id in kDecorLights.keys) {
      final src = LightRules.townLampEmitters(
          [(id, 4, 3)], const [], origin, 0, 0, map.width, map.height);
      expect(src, hasLength(1), reason: id);
      final g = LightGrid(0, 0, map.width, map.height);
      LightRules.accumulate(
          g, src, LightRules.blockOf(map), (_) => (1.0, 1.0, 1.0));
      expect(g.lum(7, 5), greaterThan(0.5), reason: id);
      expect(g.lum(7, 5), greaterThan(g.lum(17, 11)), reason: id);
    }
  });

  test('tier lamp posts emit; non-light decor and off-window do not', () {
    final src = LightRules.townLampEmitters(
        const [('pot', 1, 1), ('fence', 2, 2), ('lamp', 30, 30)],
        const [(5, 5)],
        origin,
        0,
        0,
        map.width,
        map.height);
    expect(src, hasLength(1));
    expect((src.single.x, src.single.y), (5.5, 5.2));
  });
}
