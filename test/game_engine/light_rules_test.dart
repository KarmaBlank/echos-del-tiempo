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
      LightRules.accumulate(
          g, [const LightSource(1.5, 0.5, def)], LightRules.blockOf(m), _white);
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

  test('la luz sigue la posición exacta de la fuente, sin estela', () {
    final m = _map(['.' * 21]);
    double at(double sx, int tx) {
      final g = LightGrid(0, 0, m.width, 1);
      LightRules.accumulate(
          g, [LightSource(sx, 0.5, def)], LightRules.blockOf(m), _white);
      return g.lum(tx, 0);
    }

    // En el borde entre dos tiles, los dos quedan igual (antes el tile de
    // la fuente iba adelante y el de atrás arrastraba la luz).
    expect(at(10.0, 9), closeTo(at(10.0, 10), 1e-9));
    // Corrida a la derecha dentro del mismo tile: más luz adelante.
    expect(at(10.9, 13), greaterThan(at(10.1, 13)));
    expect(at(10.9, 7), lessThan(at(10.1, 7)));
  });

  test('caída redonda en campo abierto (no octogonal)', () {
    final m = _map(List.filled(21, '.' * 21));
    final g = LightGrid(0, 0, 21, 21);
    const big = LightDef(radius: 8, intensity: 1, tint: 'x');
    LightRules.accumulate(
        g, [const LightSource(10.5, 10.5, big)], LightRules.blockOf(m), _white);
    // Misma distancia recta (5): recto (15, 10) y en diagonal (14, 13).
    expect(g.lum(14, 13), closeTo(g.lum(15, 10), 1e-9));
    // Se apaga suave hasta el radio.
    expect(g.lum(17, 10), greaterThan(0));
    expect(g.lum(17, 10), lessThan(g.lum(15, 10)));
    expect(g.lum(19, 10), 0);
  });

  group('sombras (lighting.md § 2.1, v0.36.2)', () {
    test('un farol con un muro adelante deja oscuro el otro lado', () {
      final m = _map([
        '...............',
        '...............',
        '.......#.......',
        '.......#.......',
        '.......#.......',
        '...............',
        '...............',
      ]);
      final g = LightGrid(0, 0, m.width, m.height, sub: 2);
      LightRules.accumulate(
          g,
          [LightSource(4.5, 3.5, kLightDefs[LightId.farol]!)],
          LightRules.blockOf(m),
          _white);
      // Del lado de la luz: lleno; justo detrás del muro: nada (antes la
      // luz rodeaba el muro y dejaba una mancha borrosa).
      expect(g.lum(6, 3), greaterThan(0.5));
      expect(g.lum(8, 3), 0);
      expect(g.lum(10, 3), 0);
      // La cara del muro que da a la luz se ilumina.
      expect(g.lum(7, 3), greaterThan(0.3));
      // Fuera de la sombra (por arriba del muro) sigue habiendo luz.
      expect(g.lum(8, 0), greaterThan(0));
    });

    test('el borde de la sombra es nítido dentro del tile (2 × 2)', () {
      final m = _map([
        '..........',
        '..........',
        '....#.....',
        '..........',
        '..........',
      ]);
      final g = LightGrid(0, 0, m.width, m.height, sub: 2);
      LightRules.accumulate(
          g, [const LightSource(1.5, 2.5, def)], LightRules.blockOf(m), _white);
      // Detrás del muro (fila 2) oscuro; la fila de al lado, con luz.
      expect(g.lum(6, 2), 0);
      expect(g.lum(6, 1), greaterThan(0));
      expect(g.lum(6, 3), greaterThan(0));
    });

    test('un edificio tapa una antorcha', () {
      final m = _map([
        '............',
        '............',
        '...zzz......',
        '...zzz......',
        '............',
        '............',
        '............',
      ]);
      const torch = LightDef(radius: 9, intensity: 1, tint: 'x');
      final g = LightGrid(0, 0, m.width, m.height);
      LightRules.accumulate(g, [const LightSource(0.5, 2.5, torch)],
          LightRules.blockOf(m), _white);
      expect(LightRules.blockOf(m)(4, 2), double.infinity);
      expect(g.lum(7, 2), 0); // detrás de la casa
      expect(g.lum(8, 3), 0);
      expect(g.lum(6, 6), greaterThan(0)); // por debajo, a la vista
    });

    test('una luz sobre un edificio igual alumbra alrededor', () {
      final m = _map([
        '.........',
        '.........',
        '...AAA...',
        '...AAA...',
        '.........',
        '.........',
      ]);
      final src = LightRules.tileEmitters(m, 0, 0, m.width, m.height);
      expect(src, isNotEmpty);
      expect(src.first.ownX1 - src.first.ownX0, 3);
      final g = LightGrid(0, 0, m.width, m.height);
      LightRules.accumulate(g, src, LightRules.blockOf(m), _white);
      // Alrededor de la forja, de todos los lados.
      expect(g.lum(4, 0), greaterThan(0));
      expect(g.lum(4, 5), greaterThan(0));
      expect(g.lum(1, 2), greaterThan(0));
      expect(g.lum(7, 3), greaterThan(0));
    });
  });
}
