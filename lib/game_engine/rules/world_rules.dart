import 'dart:math' as math;

import '../models/game_map.dart';
import '../data/town_layout.dart';
import '../data/tuning_catalog.dart';
import 'map_generator.dart';

/// Colisión y movimiento en el mapa — puerto de `solidT`, `hit`,
/// `moveEnt` y de los helpers de interacción del cliente (`nearSeal`,
/// `nearArm`, `nearCounter`). Ver docs/specs/world.md.
abstract final class WorldRules {
  static const tileSize = MapGenerator.tileSize;

  /// Velocidad del jugador en px/s (`sp2` en `updateMe`); ajuste de
  /// balance `exploration.playerSpeed` (Editor → Balance → Exploración).
  static double get playerSpeed =>
      kTuning[TuningId.exploration]!.d('playerSpeed');

  /// Puntos de la caja del personaje que se prueban contra los tiles.
  static const _probes = [(-5, -3), (5, -3), (-5, 4), (5, 4)];

  /// `solidT`.
  /// [blockVoid]: el vacío cuenta como sólido (enemigos; worldgen.md § 9.3).
  static bool isSolid(GameMap map, int tx, int ty,
      {bool gateOpen = false, bool blockVoid = false}) {
    if (!map.contains(tx, ty)) return true;
    final c = map.tileAt(tx, ty);
    return Tile.solidTiles.contains(c) ||
        Tile.entranceZone(c) != null ||
        (blockVoid && c == Tile.voidTile) ||
        (c == Tile.gate && !gateOpen);
  }

  /// El tile ([tx], [ty]) es vacío.
  static bool isVoid(GameMap map, int tx, int ty) =>
      map.contains(tx, ty) && map.tileAt(tx, ty) == Tile.voidTile;

  /// El centro del personaje en (x, y) px está sobre el vacío (se cae).
  static bool overVoid(GameMap map, double x, double y) =>
      isVoid(map, (x / tileSize).floor(), (y / tileSize).floor());

  /// `hit`: la caja del personaje en (x, y) toca algo sólido.
  static bool collides(GameMap map, double x, double y,
      {bool gateOpen = false, bool blockVoid = false}) {
    for (final (ox, oy) in _probes) {
      if (isSolid(map, ((x + ox) / tileSize).floor(),
          ((y + oy) / tileSize).floor(),
          gateOpen: gateOpen, blockVoid: blockVoid)) {
        return true;
      }
    }
    return false;
  }

  /// `moveEnt`: mueve primero en X y después en Y, cada eje por separado
  /// (así se desliza contra las paredes). Devuelve la posición nueva.
  static WorldPoint move(GameMap map, double x, double y, double dx, double dy,
      {bool gateOpen = false, bool blockVoid = false}) {
    final nx = x + dx;
    if (!collides(map, nx, y, gateOpen: gateOpen, blockVoid: blockVoid)) x = nx;
    final ny = y + dy;
    if (!collides(map, x, ny, gateOpen: gateOpen, blockVoid: blockVoid)) y = ny;
    return WorldPoint(x, y);
  }

  /// Un paso del jugador local con la entrada del teclado/joystick
  /// (`ix`, `iy` en -1..1; la diagonal se normaliza). Lo usa el cliente
  /// antes de mandar su `MoveAction`.
  static WorldPoint stepPlayer(GameMap map, double x, double y, double ix,
      double iy, double dt,
      {bool gateOpen = false, double speedMult = 1}) {
    final l = math.sqrt(ix * ix + iy * iy);
    if (l == 0) return WorldPoint(x, y);
    final v = playerSpeed * speedMult * dt;
    return move(map, x, y, ix / l * v, iy / l * v,
        gateOpen: gateOpen);
  }

  static double distance(double ax, double ay, double bx, double by) {
    final dx = ax - bx, dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Distancia (px) del personaje al borde de un lugar del pueblo para
  /// usarlo con E (town_loop.md § 2.1).
  static const townRange = 12.0;

  /// El lugar del pueblo frente al que está el personaje en (x, y) px, o
  /// `null` (el más cercano si hay dos). Ver `TownLayout`. Con [map], los
  /// lugares se corren con su origen y los muelles y carteles salen de
  /// sus tiles (town_editor.md § 4); sin él, los del pueblo base.
  static TownSpot? townSpot(double x, double y, {GameMap? map}) {
    TownSpot? best;
    var bd = townRange;
    final (ox, oy) = map?.townOrigin ?? (0, 0);
    double rectDist(int tx, int ty, int w, int h) {
      final x0 = tx * tileSize, y0 = ty * tileSize;
      final x1 = x0 + w * tileSize, y1 = y0 + h * tileSize;
      final dx = math.max(math.max(x0 - x, 0.0), x - x1);
      final dy = math.max(math.max(y0 - y, 0.0), y - y1);
      return math.sqrt(dx * dx + dy * dy);
    }

    for (final l in map?.townMarks ?? TownLayout.landmarks) {
      final d = rectDist(l.x + ox, l.y + oy, l.w, l.h);
      if (d < bd) (bd, best) = (d, l.spot);
    }
    if (map == null) {
      for (final (fx, fy) in TownLayout.fishingSpots) {
        final d = rectDist(fx, fy, 1, 1);
        if (d < bd) (bd, best) = (d, TownSpot.fishing);
      }
      final (sx, sy) = TownLayout.baseSign;
      final d = rectDist(sx, sy, 1, 1);
      if (d < bd) (bd, best) = (d, TownSpot.sign);
      return best;
    }
    final cx = (x / tileSize).floor(), cy = (y / tileSize).floor();
    for (var ty = cy - 2; ty <= cy + 2; ty++) {
      for (var tx = cx - 2; tx <= cx + 2; tx++) {
        if (tx < 0 || ty < 0 || tx >= map.width || ty >= map.height) continue;
        final spot = switch (map.tileAt(tx, ty)) {
          Tile.fishing => TownSpot.fishing,
          Tile.sign => TownSpot.sign,
          _ => null,
        };
        if (spot == null) continue;
        final d = rectDist(tx, ty, 1, 1);
        if (d < bd) (bd, best) = (d, spot);
      }
    }
    return best;
  }

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
