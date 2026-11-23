import 'dart:math' as math;

import '../models/fish_line.dart';
import '../models/game_map.dart';
import 'fishing_minigame.dart';
import 'fishing_rules.dart';

/// Dónde se puede pescar en el mapa y a dónde cae la boya (fishing.md
/// § 1 y § 4). Puro: lo usan el cliente (lance) y el anfitrión (valida).
abstract final class FishingCast {
  static const ts = 16.0;

  static bool _inside(GameMap m, int tx, int ty) =>
      tx >= 0 && ty >= 0 && tx < m.width && ty < m.height;

  static bool isWater(GameMap m, int tx, int ty) =>
      _inside(m, tx, ty) && m.tileAt(tx, ty) == Tile.water;

  static bool _shore(GameMap m, int tx, int ty) =>
      isWater(m, tx, ty) ||
      (_inside(m, tx, ty) && m.tileAt(tx, ty) == Tile.fishing);

  /// Tile del punto (x, y) px.
  static (int, int) tileOf(double x, double y) =>
      ((x / ts).floor(), (y / ts).floor());

  /// Mirando ([fx], [fy]) desde (x, y): ¿hay agua (o un muelle) justo
  /// enfrente? Se mira el tile vecino y el que queda a 10 px del centro
  /// del personaje, así sirve parado pegado a la orilla.
  static bool facingWater(GameMap m, double x, double y, int fx, int fy) {
    if (fx == 0 && fy == 0) return false;
    final (tx, ty) = tileOf(x, y);
    if (_shore(m, tx + fx, ty + fy)) return true;
    final (ax, ay) = tileOf(x + fx * 10, y + fy * 10);
    return (ax != tx || ay != ty) && _shore(m, ax, ay);
  }

  /// La dirección hacia el agua: ([fx], [fy]) si mira al agua; si no, la
  /// primera de las cuatro que da al agua; `null` = no hay orilla.
  static (int, int)? castDir(GameMap m, double x, double y, int fx, int fy) {
    if (facingWater(m, x, y, fx, fy)) return (fx, fy);
    for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      if (facingWater(m, x, y, d.$1, d.$2)) return d;
    }
    return null;
  }

  /// El host: hay agua a menos de [range] px del jugador (cualquier tile
  /// de la orilla del lago, no solo los muelles).
  static bool nearWater(GameMap m, double x, double y, {double range = 22}) {
    final (tx, ty) = tileOf(x, y);
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final nx = tx + dx, ny = ty + dy;
        if (!isWater(m, nx, ny)) continue;
        final cx = math.max(math.max(nx * ts - x, 0.0), x - (nx + 1) * ts);
        final cy = math.max(math.max(ny * ts - y, 0.0), y - (ny + 1) * ts);
        if (math.sqrt(cx * cx + cy * cy) < range) return true;
      }
    }
    return false;
  }

  /// Tiles que vuela la boya con la carga [power] (1 .. `maxCastTiles`).
  static int distanceTiles(double power) {
    final max = math.max(1, FishingRules.t.i('maxCastTiles'));
    return 1 + (power.clamp(0.0, 1.0) * (max - 1)).round();
  }

  /// El tile donde cae la boya desde (x, y) hacia [dir] con [power].
  static (int, int) landing(double x, double y, (int, int) dir, double power) {
    final (tx, ty) = tileOf(x, y);
    final d = distanceTiles(power);
    return (tx + dir.$1 * d, ty + dir.$2 * d);
  }

  /// Centro en px de un tile.
  static (double, double) center((int, int) t) =>
      ((t.$1 + 0.5) * ts, (t.$2 + 0.5) * ts);

  /// El host: una boya en (bx, by) es creíble para un jugador en (x, y):
  /// está en el agua y a lo sumo a un lance máximo (+ margen).
  static bool plausibleBobber(
      GameMap m, double x, double y, double bx, double by) {
    if (!bx.isFinite || !by.isFinite) return false;
    final (tx, ty) = tileOf(bx, by);
    if (!isWater(m, tx, ty)) return false;
    final reach = (FishingRules.t.i('maxCastTiles') + 1.5) * ts;
    final dx = bx - x, dy = by - y;
    return math.sqrt(dx * dx + dy * dy) <= reach;
  }
}

/// La pesca en el mapa del jugador local (fishing.md § 4): caña afuera,
/// carga, lance a un tile del lago, señuelos, picada, barra. Envuelve al
/// [FishingMinigame] (tiempos y barra) y le suma el lugar: de qué orilla
/// se tira, a qué tile cae la boya y si cayó en el agua.
class MapFishing {
  MapFishing._(this.map, this.x, this.y, this.dir, this.game);

  /// Saca la caña parado en (x, y) mirando ([fx], [fy]). `null` = no hay
  /// agua enfrente (ni al costado).
  static MapFishing? start(GameMap map, double x, double y, int fx, int fy,
      {required double Function() rand,
      double biteBonus = 0,
      double zoneBonus = 0,
      double biteChance = 1}) {
    final d = FishingCast.castDir(map, x, y, fx, fy);
    if (d == null) return null;
    return MapFishing._(map, x, y, d,
        FishingMinigame(rand,
            biteBonus: biteBonus, zoneBonus: zoneBonus, biteChance: biteChance));
  }

  final GameMap map;

  /// Donde está parado (la caña sale de acá).
  final double x, y;

  /// Hacia dónde tira (un paso de tile).
  final (int, int) dir;
  final FishingMinigame game;

  /// Tile donde cae (o cayó) la boya; `null` antes de soltar.
  (int, int)? target;

  /// Se guardó la caña (se movió o Esc): ya no sirve.
  bool ended = false;

  FishPhase get phase => game.phase;

  /// La boya cayó en el agua (`false` = en la orilla: se pierde el lance).
  bool get onWater {
    final t = target;
    return t != null && FishingCast.isWater(map, t.$1, t.$2);
  }

  void press() {
    if (ended) return;
    game.press();
    if (game.phase == FishPhase.charging) target = null;
  }

  void release() {
    if (ended) return;
    final was = game.phase;
    game.release();
    if (was == FishPhase.charging && game.phase == FishPhase.flying) {
      target = FishingCast.landing(x, y, dir, game.power);
    }
  }

  void tick(double dt) {
    if (ended) return;
    final was = game.phase;
    game.tick(dt);
    if (was == FishPhase.flying &&
        game.phase == FishPhase.waiting &&
        !onWater) {
      game.fail('Cayó en la orilla.');
    }
  }

  /// Se movió o tocó Esc: guarda la caña.
  void cancel() => ended = true;

  /// La boya ahora (px); mientras vuela, en arco. `null` sin lance o si
  /// se perdió.
  (double, double)? get bobber {
    final t = target;
    if (t == null || game.phase == FishPhase.lost) return null;
    if (game.phase == FishPhase.won) return null;
    final (bx, by) = FishingCast.center(t);
    if (game.phase == FishPhase.flying) {
      final k = (game.phaseTime / FishingMinigame.flySec).clamp(0.0, 1.0);
      return (x + (bx - x) * k, y + (by - y) * k - math.sin(k * math.pi) * 14);
    }
    return (bx, by);
  }

  /// Lo que ven los demás (`fLn`).
  FishLine get line {
    final t = target;
    final (cx, cy) = t == null ? (0.0, 0.0) : FishingCast.center(t);
    final wet = t != null && onWater;
    return switch (game.phase) {
      FishPhase.charging => const FishLine(FishLineStage.charging),
      FishPhase.waiting when wet =>
        FishLine(FishLineStage.line, bx: cx, by: cy),
      FishPhase.bite ||
      FishPhase.hooking when wet =>
        FishLine(FishLineStage.bite, bx: cx, by: cy),
      FishPhase.reel when wet => FishLine(FishLineStage.reel, bx: cx, by: cy),
      _ => const FishLine(FishLineStage.rod),
    };
  }

  /// Pez clavado (para el aviso).
  FishCatch? get fish => game.fish;
}
