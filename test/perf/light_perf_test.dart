import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Costo del mapa de luz en un pueblo grande de noche (lighting.md § 4):
/// la ventana de la vista (con margen, alineada a 16) con muchos faros,
/// casas y braseros, más 4 jugadores y luciérnagas por cuadro. Imprime
/// los tiempos (JIT: para comparar, no absoluto).
void main() {
  test('mapa de luz de un pueblo grande', () {
    const w = 200, h = 160;
    final rows = [
      for (var y = 0; y < h; y++)
        String.fromCharCodes([
          for (var x = 0; x < w; x++)
            (x * 7 + y * 13) % 41 == 0
                ? Tile.brazierLit.codeUnitAt(0)
                : (x * 3 + y * 5) % 17 == 0
                    ? Tile.tree.codeUnitAt(0)
                    : (x % 23 == 0 && y % 5 != 0)
                        ? Tile.wall.codeUnitAt(0)
                        : Tile.grass.codeUnitAt(0)
        ])
    ];
    final map = GameMap(
        width: w, height: h, rows: rows, theme: 'pueblo',
        spawn: const WorldPoint(0, 0), lobby: true);
    (double, double, double) tint(String _) => (1, 0.8, 0.6);
    final block = LightRules.blockOf(map);
    const gw = 80, gh = 64; // vista con zoom + margen
    final sw = Stopwatch()..start();
    final fixed = LightRules.tileEmitters(map, 40, 40, 40 + gw, 40 + gh);
    final steady = LightGrid(40, 40, gw, gh);
    LightRules.accumulate(steady, fixed, block, tint);
    final cold = sw.elapsedMicroseconds;
    sw.reset();
    for (var i = 0; i < 10; i++) {
      LightRules.accumulate(LightGrid(40, 40, gw, gh), fixed, block, tint);
    }
    final build = sw.elapsedMicroseconds / 10;
    final out = LightGrid(40, 40, gw, gh);
    final moving = [
      for (var i = 0; i < 4; i++)
        LightSource(70.0 + i, 70.0 + i, LightRules.carried(dark: true)),
      for (var i = 0; i < 24; i++)
        LightSource(45.0 + i * 3, 50.0 + i, kLightDefs[LightId.luciernaga]!),
    ];
    sw.reset();
    const frames = 200;
    for (var f = 0; f < frames; f++) {
      out.copyFrom(steady);
      LightRules.accumulate(out, moving, block, tint);
    }
    final perFrame = sw.elapsedMicroseconds / frames;
    // ignore: avoid_print
    print('luz: ${fixed.length} fijas, recálculo ${(build / 1000).toStringAsFixed(2)} ms (frío ${cold / 1000}), '
        'por cuadro ${(perFrame / 1000).toStringAsFixed(3)} ms');
    expect(perFrame, lessThan(4000));
    expect(build, lessThan(16000));
  });
}
