import 'package:echos_del_tiempo/game_engine/data/missions_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lobby = MapGenerator.lobby();

  test('isSolid: muros, agua, mostrador, armería y fuera del mapa', () {
    expect(WorldRules.isSolid(lobby, 0, 0), isTrue); // muro
    expect(WorldRules.isSolid(lobby, 1, 1), isFalse); // camino
    expect(WorldRules.isSolid(lobby, 1, 3), isFalse); // suelo
    expect(WorldRules.isSolid(lobby, 3, 7), isTrue); // agua
    expect(WorldRules.isSolid(lobby, 9, 2), isTrue); // mostrador
    expect(WorldRules.isSolid(lobby, 19, 2), isTrue); // armería
    expect(WorldRules.isSolid(lobby, -1, 5), isTrue);
    expect(WorldRules.isSolid(lobby, 26, 5), isTrue);
  });

  test('la barrera G es sólida solo cerrada', () {
    final m = MapGenerator.generate(kMissions.first, 12345);
    // Barrera al oeste en x = arena.x + 13, filas cy-1..cy+2.
    final ar = m.arena!;
    final gx = ar.x + 13, gy = ar.cy;
    expect(m.tileAt(gx, gy), Tile.gate);
    expect(WorldRules.isSolid(m, gx, gy), isTrue);
    expect(WorldRules.isSolid(m, gx, gy, gateOpen: true), isFalse);
  });

  test('collides prueba las 4 esquinas de la caja', () {
    // Tile (1,3) libre; (0,3) muro. x = 16+5 → la esquina izquierda en 16.
    expect(WorldRules.collides(lobby, 21, 56), isFalse);
    expect(WorldRules.collides(lobby, 20.9, 56), isTrue);
  });

  test('move: se desliza contra la pared (cada eje por separado)', () {
    // Pegado a la pared izquierda: no avanza en X pero sí en Y.
    final p = WorldRules.move(lobby, 21, 60, -5, 4);
    expect(p, const WorldPoint(21, 64));
    // Libre: avanza en los dos ejes.
    expect(WorldRules.move(lobby, 100, 100, 3, -2), const WorldPoint(103, 98));
  });

  test('stepPlayer normaliza la diagonal a 78 px/s', () {
    final p = WorldRules.stepPlayer(lobby, 150, 100, 1, 1, 0.1);
    expect(p.x - 150, closeTo(7.8 / 1.4142135623730951, 1e-9));
    expect(p.y - 100, closeTo(7.8 / 1.4142135623730951, 1e-9));
    expect(WorldRules.stepPlayer(lobby, 100, 120, 0, 0, 0.1),
        const WorldPoint(100, 120));
  });

  test('zonas del lobby', () {
    expect(WorldRules.nearCounter(13 * 16, 4 * 16), isTrue);
    expect(WorldRules.nearCounter(13 * 16, 5 * 16), isFalse);
    expect(WorldRules.nearArmory(21 * 16, 4 * 16), isTrue);
    expect(WorldRules.nearArmory(13 * 16, 4 * 16), isFalse);
  });
}
