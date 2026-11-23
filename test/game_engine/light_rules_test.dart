import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:flutter_test/flutter_test.dart';

GameMap _map(List<String> rows) => GameMap(
    width: rows.first.length,
    height: rows.length,
    rows: rows,
    theme: 'cavernas',
    spawn: const WorldPoint(8, 8));

(double, double, double) _white(String _) => (1, 1, 1);

void main() {
  const def = LightDef(radius: 5, intensity: 1, tint: 'x');

  test('la luz cae con la distancia y no pasa los muros (lighting.md § 2)', () {
    final m = _map([
      '..........',
      '..........',
      '.....#....',
      '.....#....',
      '.....#....',
      '..........',
    ]);
    final g = LightGrid(0, 0, m.width, m.height);
    LightRules.accumulate(
        g, [const LightSource(2.5, 3.5, def)], LightRules.blockOf(m), _white);
    expect(g.lum(2, 3), greaterThan(g.lum(3, 3)));
    expect(g.lum(3, 3), greaterThan(g.lum(4, 3)));
    // El muro se ilumina pero detrás queda en sombra (rodeo > radio).
    expect(g.lum(5, 3), greaterThan(0));
    expect(g.lum(6, 3), 0);
    expect(g.lum(9, 3), 0);
  });

  test('los árboles atenúan sin cortar', () {
    final open = _map(['.......']);
    final trees = _map(['...T...']);
    double at(GameMap m) {
      final g = LightGrid(0, 0, m.width, 1);
      LightRules.accumulate(g, [const LightSource(1.5, 0.5, def)],
          LightRules.blockOf(m), _white);
      return g.lum(4, 0);
    }

    expect(at(trees), lessThan(at(open)));
  });

  test('mazmorras oscuras y luz que lleva el jugador', () {
    expect(LightRules.isDark('cavernas'), isTrue);
    expect(LightRules.isDark('abismo', floor: 1), isTrue);
    expect(LightRules.isDark('abismo', floor: 0), isFalse);
    expect(LightRules.isDark('ruinas'), isFalse);
    expect(LightRules.carried(dark: true).radius,
        greaterThan(LightRules.carried(dark: false).radius));
    expect(LightRules.carried(dark: true, bonus: 2).radius,
        kLightDefs[LightId.jugadorOscuro]!.radius + 2);
  });

  test('ambiente: día blanco, noche azul oscura, el rayo aclara', () {
    const dusk = (0.8, 0.6, 0.5), night = (0.1, 0.1, 0.3);
    expect(LightRules.ambient(0, dusk: dusk, night: night), (1.0, 1.0, 1.0));
    final n = LightRules.ambient(1, dusk: dusk, night: night);
    expect(n.$3, greaterThan(n.$1));
    final storm = LightRules.ambient(1, overcast: 1, dusk: dusk, night: night);
    expect(storm.$3, lessThan(n.$3));
    final bolt = LightRules.ambient(1, bolt: 1, dusk: dusk, night: night);
    expect(bolt.$1, 1.0);
  });
}
