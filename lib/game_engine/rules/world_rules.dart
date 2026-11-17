import 'dart:math' as math;

import '../models/game_map.dart';
import 'map_generator.dart';

/// Colisión y movimiento en el mapa — puerto de `solidT`, `hit`,
/// `moveEnt` y de los helpers de interacción del cliente (`nearSeal`,
/// `nearArm`, `nearCounter`). Ver docs/specs/world.md.
abstract final class WorldRules {
  static const tileSize = MapGenerator.tileSize;

  /// Velocidad del jugador en px/s (`sp2` en `updateMe`).
  static const playerSpeed = 78.0;

  /// Puntos de la caja del personaje que se prueban contra los tiles.
  static const _probes = [(-5, -3), (5, -3), (-5, 4), (5, 4)];

  /// `solidT`.
  static bool isSolid(GameMap map, int tx, int ty, {bool gateOpen = false}) {
    if (!map.contains(tx, ty)) return true;
    final c = map.tileAt(tx, ty);
    return c == Tile.wall ||
        c == Tile.water ||
        c == Tile.counter ||
        c == Tile.armory ||
        c == Tile.merchant ||
        c == Tile.tree ||
        c == Tile.rock ||
        Tile.entranceZone(c) != null ||
        (c == Tile.gate && !gateOpen);
  }

  /// `hit`: la caja del personaje en (x, y) toca algo sólido.
  static bool collides(GameMap map, double x, double y,
      {bool gateOpen = false}) {
    for (final (ox, oy) in _probes) {
      if (isSolid(map, ((x + ox) / tileSize).floor(),
          ((y + oy) / tileSize).floor(),
          gateOpen: gateOpen)) {
        return true;
      }
    }
    return false;
  }

  /// `moveEnt`: mueve primero en X y después en Y, cada eje por separado
  /// (así se desliza contra las paredes). Devuelve la posición nueva.
  static WorldPoint move(GameMap map, double x, double y, double dx, double dy,
      {bool gateOpen = false}) {
    final nx = x + dx;
    if (!collides(map, nx, y, gateOpen: gateOpen)) x = nx;
    final ny = y + dy;
    if (!collides(map, x, ny, gateOpen: gateOpen)) y = ny;
    return WorldPoint(x, y);
  }

  /// Un paso del jugador local con la entrada del teclado/joystick
  /// (`ix`, `iy` en -1..1; la diagonal se normaliza). Lo usa el cliente
  /// antes de mandar su `MoveAction`.
  static WorldPoint stepPlayer(GameMap map, double x, double y, double ix,
      double iy, double dt,
      {bool gateOpen = false}) {
    final l = math.sqrt(ix * ix + iy * iy);
    if (l == 0) return WorldPoint(x, y);
    return move(map, x, y, ix / l * playerSpeed * dt, iy / l * playerSpeed * dt,
        gateOpen: gateOpen);
  }

  static double distance(double ax, double ay, double bx, double by) {
    final dx = ax - bx, dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// `nearCounter`: frente al mostrador de misiones del lobby.
  static bool nearCounter(double x, double y) =>
      y < 4.6 * tileSize && x > 8.5 * tileSize && x < 17.5 * tileSize;

  /// `nearArm`: frente a la armería del lobby.
  static bool nearArmory(double x, double y) =>
      y < 4.6 * tileSize && x > 18.5 * tileSize && x < 24.5 * tileSize;

  /// Distancia a la que la UI ofrece activar un sello (`nearSeal`). El
  /// host acepta hasta `SessionEngine.sealRange`.
  static const sealPromptRange = 26.0;

  /// Distancia (px, al centro del tile de la entrada) para entrar a una
  /// zona con E (worldgen.md § 7.3).
  static const entranceRange = 28.0;

  /// Distancia (px, al centro del tile) para usar una escalera con E.
  static const stairsRange = 24.0;

  /// La entrada de zona frente a la que está el jugador, o `null`.
  static ZoneEntrance? nearEntrance(GameMap map, double x, double y) {
    for (final e in map.entrances) {
      final c = e.center;
      if (distance(x, y, c.x, c.y) < entranceRange) return e;
    }
    return null;
  }

  /// La escalera del piso actual cerca del jugador, o `null`.
  static StairsKind? nearStairs(GameMap map, double x, double y) {
    final f = map.floorAt(x, y);
    if (f == null) return null;
    final d = f.stairsDown, u = f.stairsUp;
    if (d != null && distance(x, y, d.x, d.y) < stairsRange) {
      return StairsKind.down;
    }
    if (u != null && distance(x, y, u.x, u.y) < stairsRange) {
      return StairsKind.up;
    }
    return null;
  }
}
