import 'dart:math' as math;
import 'dart:typed_data';

import '../data/light_catalog.dart';
import '../models/game_map.dart';

/// Una luz puesta en el mapa, en coordenadas de tile (con fracción: el
/// centro del tile (3, 4) es (3.5, 4.5)).
class LightSource {
  const LightSource(this.x, this.y, this.def, {this.scale = 1});
  final double x, y;
  final LightDef def;

  /// Multiplica el brillo (titileo, luciérnagas que parpadean).
  final double scale;
}

/// Mapa de luz de una ventana de tiles (lighting.md § 2): por tile, el
/// color de la luz (r, g, b en 0–1) sin el ambiente.
class LightGrid {
  LightGrid(this.x0, this.y0, this.w, this.h) : rgb = Float32List(w * h * 3);
  final int x0, y0, w, h;
  final Float32List rgb;

  bool inside(int tx, int ty) =>
      tx >= x0 && ty >= y0 && tx < x0 + w && ty < y0 + h;

  /// Brillo (el canal más alto) en el tile; 0 afuera de la ventana.
  double lum(int tx, int ty) {
    if (!inside(tx, ty)) return 0;
    final i = ((ty - y0) * w + (tx - x0)) * 3;
    return math.max(rgb[i], math.max(rgb[i + 1], rgb[i + 2]));
  }

  /// Suma [other] por [k] (misma ventana).
  void addScaled(LightGrid other, double k) {
    final a = rgb, b = other.rgb;
    for (var i = 0; i < a.length; i++) {
      a[i] += b[i] * k;
    }
  }

  void copyFrom(LightGrid other) => rgb.setAll(0, other.rgb);
}

/// Bloqueo de un tile para la luz: 0 pasa, [double.infinity] corta,
/// otro valor = tiles extra de recorrido.
typedef LightBlock = double Function(int tx, int ty);

/// Reglas puras de la luz (lighting.md). Sin Flutter ni colores.
abstract final class LightRules {
  /// El mapa (o el piso [floor] de una misión) es una mazmorra oscura.
  static bool isDark(String theme, {int floor = 0}) =>
      kDarkThemes.contains(theme) ||
      (kDarkFloorThemes.contains(theme) && floor.isOdd);

  /// Radio de la luz que lleva un jugador. [bonus]: gancho para
  /// linternas, pasivas o bonos de habitantes (tiles extra; hoy 0).
  static LightDef carried({required bool dark, double bonus = 0}) {
    final d = kLightDefs[dark ? LightId.jugadorOscuro : LightId.jugadorPueblo]!;
    if (bonus == 0) return d;
    return LightDef(
        radius: d.radius + bonus,
        intensity: d.intensity,
        tint: d.tint,
        flicker: d.flicker);
  }

  /// Bloqueo según los tiles del mapa.
  static LightBlock blockOf(GameMap map) => (tx, ty) {
        if (!map.contains(tx, ty)) return double.infinity;
        final c = map.tileAt(tx, ty);
        if (kOpaqueTiles.contains(c)) return double.infinity;
        if (kAttenuatingTiles.contains(c)) return kAttenuationCost;
        return 0;
      };

  static int _hash(int x, int y) {
    var h = x * 374761393 + y * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  /// Luces fijas de los tiles de [map] en el rectángulo [x0, x1)×[y0, y1)
  /// (lighting.md § 3). [dark]: mazmorra oscura (agrega antorchas de
  /// pared). Las casas emiten una sola vez (su tile de arriba a la
  /// izquierda).
  static List<LightSource> tileEmitters(
      GameMap map, int x0, int y0, int x1, int y1,
      {bool dark = false, bool biome = false}) {
    final out = <LightSource>[];
    x0 = math.max(0, x0);
    y0 = math.max(0, y0);
    x1 = math.min(map.width, x1);
    y1 = math.min(map.height, y1);
    for (var y = y0; y < y1; y++) {
      final row = map.rows[y];
      for (var x = x0; x < x1; x++) {
        final c = row[x];
        final id = kTileLights[c];
        if (id != null) {
          if (c == Tile.house &&
              ((x > 0 && row[x - 1] == c) ||
                  (y > 0 && map.rows[y - 1][x] == c))) {
            continue;
          }
          if (c == Tile.forage && !biome) continue;
          out.add(LightSource(x + 0.5, y + 0.5, kLightDefs[id]!));
        } else if (dark &&
            c == Tile.wall &&
            _hash(x, y) % kTorchEvery == 0 &&
            y + 1 < map.height &&
            Tile.isWalkable(map.rows[y + 1][x])) {
          // Antorcha en la cara de la pared que da a un piso.
          out.add(LightSource(x + 0.5, y + 0.9, kLightDefs[LightId.antorcha]!));
        }
      }
    }
    return out;
  }

  static const _dirs = [
    (1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0),
    (1, 1, math.sqrt2), (1, -1, math.sqrt2),
    (-1, 1, math.sqrt2), (-1, -1, math.sqrt2),
  ];

  /// Suma la luz de [sources] en [grid] (lighting.md § 2). Cada luz se
  /// propaga tile a tile (camino más corto, 8 vecinos) hasta su radio:
  /// los tiles opacos se iluminan pero no dejan pasar; los que atenúan
  /// cuestan recorrido extra. Caída suave: (1 − d/r)². [tintOf]: color de
  /// cada clave (r, g, b).
  static void accumulate(LightGrid grid, Iterable<LightSource> sources,
      LightBlock block, (double, double, double) Function(String) tintOf) {
    for (final s in sources) {
      final r = s.def.radius;
      final k0 = s.def.intensity * s.scale;
      if (r <= 0 || k0 <= 0) continue;
      final sx = s.x.floor(), sy = s.y.floor();
      final ri = r.ceil() + 1;
      // Ventana local de la luz.
      final lx0 = sx - ri, ly0 = sy - ri, n = ri * 2 + 1;
      final dist = Float64List(n * n)..fillRange(0, n * n, double.infinity);
      final (tr, tg, tb) = tintOf(s.def.tint);
      final d0 = math.sqrt(math.pow(s.x - sx - 0.5, 2) + math.pow(s.y - sy - 0.5, 2));
      dist[(sy - ly0) * n + (sx - lx0)] = d0;
      // Bloqueo de la ventana local, leído una sola vez.
      final blk = Float64List(n * n);
      for (var cy = 0; cy < n; cy++) {
        for (var cx = 0; cx < n; cx++) {
          blk[cy * n + cx] = block(cx + lx0, cy + ly0);
        }
      }
      final queue = <int>[(sy - ly0) * n + (sx - lx0)];
      // Relajación en cola (radios chicos: barata).
      var qi = 0;
      while (qi < queue.length) {
        final i = queue[qi++];
        final cx = i % n, cy = i ~/ n;
        final d = dist[i];
        // Un opaco que no es la fuente no deja pasar.
        if (i != (sy - ly0) * n + (sx - lx0) && blk[i].isInfinite) {
          continue;
        }
        for (final (dx, dy, step) in _dirs) {
          final nx = cx + dx, ny = cy + dy;
          if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
          final b = blk[ny * n + nx];
          // Diagonal entre dos opacos: no se cuela.
          if (dx != 0 && dy != 0 &&
              blk[cy * n + nx].isInfinite &&
              blk[ny * n + cx].isInfinite) {
            continue;
          }
          final nd = d + step + (b.isInfinite ? 0 : b);
          if (nd >= r) continue;
          final j = ny * n + nx;
          if (nd < dist[j] - 1e-6) {
            dist[j] = nd;
            queue.add(j);
          }
        }
      }
      for (var cy = 0; cy < n; cy++) {
        final ty = cy + ly0;
        if (ty < grid.y0 || ty >= grid.y0 + grid.h) continue;
        for (var cx = 0; cx < n; cx++) {
          final tx = cx + lx0;
          if (tx < grid.x0 || tx >= grid.x0 + grid.w) continue;
          final d = dist[cy * n + cx];
          if (d >= r) continue;
          final f = 1 - d / r;
          final k = k0 * f * f;
          final gi = ((ty - grid.y0) * grid.w + (tx - grid.x0)) * 3;
          grid.rgb[gi] += tr * k;
          grid.rgb[gi + 1] += tg * k;
          grid.rgb[gi + 2] += tb * k;
        }
      }
    }
  }

  /// Titileo suave de una llama en el instante [tMs] (lighting.md § 3.2):
  /// factor alrededor de 1 con amplitud [amp], distinto por luz ([seed]).
  static double flicker(double tMs, double amp, int seed) {
    if (amp <= 0) return 1;
    final p = seed * 0.37;
    final v = math.sin(tMs / 130 + p) * 0.6 + math.sin(tMs / 47 + p * 2.1) * 0.4;
    return 1 + amp * v;
  }

  /// Ambiente (r, g, b) al aire libre para la oscuridad [dark] (0 = día,
  /// 1 = noche), el encapotado [overcast] (0–1) y el destello de un rayo
  /// [bolt] (0–1). [dusk] y [night]: colores del atardecer y la noche.
  static (double, double, double) ambient(double dark,
      {double overcast = 0,
      double bolt = 0,
      required (double, double, double) dusk,
      required (double, double, double) night}) {
    (double, double, double) mix(
            (double, double, double) a, (double, double, double) b, double t) =>
        (a.$1 + (b.$1 - a.$1) * t, a.$2 + (b.$2 - a.$2) * t, a.$3 + (b.$3 - a.$3) * t);
    const day = (1.0, 1.0, 1.0);
    final d = dark.clamp(0.0, 1.0);
    var c = d < 0.5 ? mix(day, dusk, d * 2) : mix(dusk, night, (d - 0.5) * 2);
    final o = 1 - overcast.clamp(0.0, 1.0) * 0.45;
    c = (c.$1 * o, c.$2 * o, c.$3 * o);
    return mix(c, day, bolt.clamp(0.0, 1.0));
  }
}
