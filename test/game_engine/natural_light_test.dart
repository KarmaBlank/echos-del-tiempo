import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:flutter_test/flutter_test.dart';

(double, double, double) _white(String _) => (1, 1, 1);

/// Fracción de tiles caminables de [r] que la luz natural y de los tiles
/// deja "a la vista" (umbral 0.12, lighting.md § 5.3), sin jugadores.
double _coverage(GameMap m, TileRect r,
    {required bool dark, bool biome = false}) {
  final g = LightGrid(r.x, r.y, r.w, r.h);
  const m0 = MapLightMargin.m;
  LightRules.accumulate(
      g,
      [
        ...LightRules.tileEmitters(
            m, r.x - m0, r.y - m0, r.x + r.w + m0, r.y + r.h + m0,
            dark: dark, biome: biome),
        ...LightRules.ambientEmitters(
            m, r.x - m0, r.y - m0, r.x + r.w + m0, r.y + r.h + m0),
      ],
      LightRules.blockOf(m),
      _white);
  var walk = 0, seen = 0;
  for (var y = r.y; y < r.y + r.h; y++) {
    for (var x = r.x; x < r.x + r.w; x++) {
      if (!Tile.isWalkable(m.tileAt(x, y))) continue;
      walk++;
      if (g.lum(x, y) >= 0.12) seen++;
    }
  }
  return walk == 0 ? 1 : seen / walk;
}

abstract final class MapLightMargin {
  static const m = 13;
}

/// Luz natural de los lugares oscuros (lighting.md § 3.3): de noche o en
/// un piso oscuro se ve la forma del lugar sin linterna, pero sin
/// iluminarlo todo.
void main() {
  test('cada tema tiene luz natural en el catálogo', () {
    for (final z in kZones) {
      expect(kAmbientLights[z.theme], isNotNull, reason: z.theme);
    }
  });

  test('cobertura mínima por tema, de noche y en pisos oscuros', () {
    final report = <String>[], fails = <String>[];
    for (final z in kZones) {
      var sum = 0.0, n = 0;
      for (final seed in [1, 42]) {
        final m = MapGenerator.zone(z, seed);
        for (final f in m.floors) {
          sum += _coverage(m, f.bounds,
              dark: LightRules.isDark(z.theme, floor: f.index));
          n++;
        }
      }
      final avg = sum / n;
      report.add('${z.theme} ${(avg * 100).toStringAsFixed(0)} %');
      if (avg <= 0.2) fails.add(z.theme);
      expect(avg, lessThan(0.9), reason: '${z.theme}: no todo iluminado');
    }
    final b = MapGenerator.bosque();
    final cov = _coverage(b, TileRect(0, 0, b.width, b.height),
        dark: false, biome: true);
    report.add('bosque_ext ${(cov * 100).toStringAsFixed(0)} %');
    if (cov <= 0.2) fails.add('bosque_ext');
    // ignore: avoid_print
    print('luz natural: ${report.join(' · ')}');
    expect(fails, isEmpty);
  });

  test('la llegada de cada piso tiene luz guía', () {
    final z = kZones.firstWhere((z) => z.theme == 'cavernas');
    final m = MapGenerator.zone(z, 7);
    for (final f in m.floors) {
      final tx = f.spawn.x / 16, ty = f.spawn.y / 16;
      final src = LightRules.ambientEmitters(
          m, tx.floor() - 1, ty.floor() - 1, tx.floor() + 2, ty.floor() + 2);
      expect(src.any((s) => s.def == kLightDefs[LightId.guia]), isTrue);
    }
  });

  test('las luciérnagas alumbran de verdad', () {
    final d = kLightDefs[LightId.luciernaga]!;
    expect(d.radius, greaterThanOrEqualTo(3));
    expect(d.intensity, greaterThanOrEqualTo(0.5));
  });
}
