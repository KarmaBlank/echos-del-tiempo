import 'dart:math' as math;
import 'dart:typed_data';

import '../data/light_catalog.dart';
import '../data/mine_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import 'shop_interior_rules.dart';
import 'sky_rules.dart';

/// Una luz puesta en el mapa, en coordenadas de tile (con fracción: el
/// centro del tile (3, 4) es (3.5, 4.5)).
class LightSource {
  const LightSource(this.x, this.y, this.def,
      {this.scale = 1,
      this.ownX0 = 0,
      this.ownY0 = 0,
      this.ownX1 = 0,
      this.ownY1 = 0});
  final double x, y;
  final LightDef def;

  /// Estructura propia de la luz, rectángulo de tiles [ownX0, ownX1) ×
  /// [ownY0, ownY1) (lighting.md § 2.2): para esta luz es transparente,
  /// así la ventana de una casa o el brillo de la forja salen hacia
  /// afuera en vez de quedar tapados por su propio edificio. Vacío por
  /// defecto.
  final int ownX0, ownY0, ownX1, ownY1;

  /// Multiplica el brillo (titileo, luciérnagas que parpadean).
  final double scale;
}

/// Mapa de luz de una ventana de tiles (lighting.md § 2): por muestra, el
/// color de la luz (r, g, b en 0–1) sin el ambiente. Cada tile tiene
/// [sub] × [sub] muestras (en los centros de sus subceldas): con 1, una en
/// el centro del tile; la capa de dibujo usa 2 para que las sombras
/// tengan borde nítido.
class LightGrid {
  LightGrid(this.x0, this.y0, this.w, this.h, {this.sub = 1})
      : rgb = Float32List(w * h * sub * sub * 3);
  final int x0, y0, w, h, sub;
  final Float32List rgb;

  /// Muestras por fila / columna.
  int get sw => w * sub;
  int get sh => h * sub;

  bool inside(int tx, int ty) =>
      tx >= x0 && ty >= y0 && tx < x0 + w && ty < y0 + h;

  /// Brillo (el canal más alto) en el tile (el máximo de sus muestras);
  /// 0 afuera de la ventana.
  double lum(int tx, int ty) {
    if (!inside(tx, ty)) return 0;
    var best = 0.0;
    final rw = sw;
    for (var j = 0; j < sub; j++) {
      for (var k = 0; k < sub; k++) {
        final i = (((ty - y0) * sub + j) * rw + (tx - x0) * sub + k) * 3;
        best =
            math.max(best, math.max(rgb[i], math.max(rgb[i + 1], rgb[i + 2])));
      }
    }
    return best;
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
  /// Daylight through a window (player_house.md § 8.5): 1 at full day,
  /// fading at dusk, 0 at night (no light comes in).
  static double daylight(SkyState sky) {
    if (!sky.started) return 1;
    final v = 1 - SkyRules.darkness(sky);
    return v < 0.05 ? 0 : v;
  }

  /// El mapa (o el piso [floor] de una misión) es una mazmorra oscura.
  static bool isDark(String theme, {int floor = 0}) =>
      kDarkThemes.contains(theme) ||
      (kDarkFloorThemes.contains(theme) && floor.isOdd);

  /// Luz que lleva un jugador. [bonus]: tiles extra de radio (linternas,
  /// pasivas). [wisp]: con la Llama errante (lighting.md § 3.1.1). Al aire
  /// libre suma [wispBonus] al radio y sube la intensidad a
  /// [wispIntensity] como mínimo. En mazmorra oscura multiplica el radio
  /// por [wispDarkRadiusFactor] (sin ella se ve la mitad) y sube la
  /// intensidad a [wispDarkIntensity].
  static LightDef carried(
      {required bool dark, double bonus = 0, bool wisp = false}) {
    final d = kLightDefs[dark ? LightId.jugadorOscuro : LightId.jugadorPueblo]!;
    if (!wisp && bonus == 0) return d;
    if (!wisp) {
      return LightDef(
          radius: d.radius + bonus,
          intensity: d.intensity,
          tint: d.tint,
          flicker: d.flicker);
    }
    return LightDef(
        radius: dark
            ? d.radius * wispDarkRadiusFactor + bonus
            : d.radius + wispBonus + bonus,
        intensity: math.max(
            d.intensity, dark ? wispDarkIntensity : wispIntensity),
        tint: d.tint,
        flicker: d.flicker);
  }

  /// Tiles extra de radio con la Llama errante al aire libre
  /// (lighting.md § 3.1.1).
  static const wispBonus = 5.0;

  /// Intensidad mínima de la luz con la Llama errante al aire libre.
  static const wispIntensity = 1.0;

  /// Factor del radio con la Llama errante en mazmorra oscura.
  static const wispDarkRadiusFactor = 2.0;

  /// Intensidad de la luz con la Llama errante en mazmorra oscura.
  static const wispDarkIntensity = 1.5;

  /// Si la Llama errante está prendida (lighting.md § 3.1.1): al aire
  /// libre (mundo y pueblo) sola de noche, sin importar [toggled]; en
  /// mazmorras, solo si el jugador la prendió con L ([toggled]).
  static bool wispActive(
          {required bool toggled,
          required bool outdoor,
          required bool night,
          bool cave = false}) =>
      outdoor && !cave ? night : toggled || (cave && night);

  /// Multiplicador del radio en que los enemigos detectan a un jugador:
  /// con la Llama errante prendida a mano en una mazmorra oscura se lo ve
  /// de lejos. Al aire libre (la de la noche, automática) no castiga
  /// (lighting.md § 3.1.1).
  static const wispAggro = 1.5;
  static double aggroFactor(
          {required bool wisp, required bool dark, bool outdoor = false}) =>
      wisp && dark && !outdoor ? wispAggro : 1;

  /// Cuánto se ve una luciérnaga (0–1) en (x, y) (tiles) según las
  /// luces puestas [placed] (centros en tiles; lighting.md § 3.4): lejos
  /// de toda luz, 1; dentro de [fireflyInner] × [radius], 0; en el medio
  /// baja suave (smoothstep). Las [survivor] (una de cada
  /// [fireflySurvivorEvery]) quedan visibles aunque haya luz, a media luz.
  static double fireflyFade(
      double x, double y, Iterable<(double, double)> placed,
      {required double radius, bool survivor = false}) {
    var best = double.infinity;
    for (final (lx, ly) in placed) {
      final dx = x - lx, dy = y - ly;
      best = math.min(best, dx * dx + dy * dy);
    }
    if (best == double.infinity) return 1;
    final inner = radius * fireflyInner;
    final q = ((math.sqrt(best) - inner) / (radius - inner)).clamp(0.0, 1.0);
    final k = q * q * (3 - 2 * q);
    return survivor ? math.max(k, fireflySurvivorAlpha) : k;
  }

  /// Fracción del radio de la luz en la que ya no quedan luciérnagas.
  static const fireflyInner = 0.45;

  /// Una de cada tantas luciérnagas sobrevive en zona iluminada.
  static const fireflySurvivorEvery = 7;

  /// Brillo mínimo de las sobrevivientes.
  static const fireflySurvivorAlpha = 0.7;

  /// Visibilidad mínima con la que se distingue algo (la de los enemigos
  /// en la penumbra).
  static const seenLum = 0.12;

  /// Radio en tiles hasta donde la luz [d] supera [seenLum] (sin muros).
  static double visibleRadius(LightDef d) => d.intensity <= seenLum
      ? 0
      : d.radius * (1 - math.sqrt(seenLum / d.intensity));

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
  static Map<String, double> _veinGlow() {
    final t = tuning(TuningId.smithing);
    final base = t.d('veinGlow');
    return {
      Tile.ore: base,
      MineTile.rich: base * t.d('veinGlowRich'),
      MineTile.deep: base * t.d('veinGlowDeep'),
      MineTile.gem: base * t.d('veinGlowGem'),
    };
  }

  static List<LightSource> tileEmitters(
      GameMap map, int x0, int y0, int x1, int y1,
      {bool dark = false, bool biome = false}) {
    final out = <LightSource>[];
    x0 = math.max(0, x0);
    y0 = math.max(0, y0);
    x1 = math.min(map.width, x1);
    y1 = math.min(map.height, y1);
    // Mines (mining_smithing.md § 1.2): every vein glows faintly through
    // the rock, rarer ores a little more (tunable in Balance).
    final mine = map.theme.startsWith('mina_');
    final glow = mine ? _veinGlow() : null;
    for (var y = y0; y < y1; y++) {
      final row = map.rows[y];
      for (var x = x0; x < x1; x++) {
        final c = row[x];
        final k = glow?[c];
        if (k != null) {
          if (k > 0) {
            out.add(LightSource(x + 0.5, y + 0.5, kLightDefs[LightId.veta]!,
                scale: k, ownX0: x, ownY0: y, ownX1: x + 1, ownY1: y + 1));
          }
          continue;
        }
        final id = kTileLights[c];
        if (id != null) {
          if (c == Tile.house &&
              ((x > 0 && row[x - 1] == c) ||
                  (y > 0 && map.rows[y - 1][x] == c))) {
            continue;
          }
          if (c == Tile.forage && !biome) continue;
          if (kOpaqueTiles.contains(c)) {
            // Luz sobre un edificio: su estructura no la tapa (§ 2.2).
            final (ox0, oy0, ox1, oy1) = structureOf(map, x, y);
            out.add(LightSource(x + 0.5, y + 0.5, kLightDefs[id]!,
                ownX0: ox0, ownY0: oy0, ownX1: ox1, ownY1: oy1));
          } else {
            out.add(LightSource(x + 0.5, y + 0.5, kLightDefs[id]!));
          }
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

  /// Luz natural de [map] en el rectángulo [x0, x1)×[y0, y1)
  /// (lighting.md § 3.3): la del tema ([kAmbientLights]) en tiles
  /// caminables elegidos por hash de la posición, y una luz guía en la
  /// llegada y las escaleras de cada piso (también en los pisos de
  /// faroles, para que el arranque no sea negro). Determinista: sale del
  /// mapa (que sale de la semilla). El pueblo no tiene.
  static List<LightSource> ambientEmitters(
      GameMap map, int x0, int y0, int x1, int y1) {
    final out = <LightSource>[];
    if (map.lobby && map.place == null) return out; // el pueblo: faros
    x0 = math.max(0, x0);
    y0 = math.max(0, y0);
    x1 = math.min(map.width, x1);
    y1 = math.min(map.height, y1);
    final spec = kAmbientLights[map.theme];
    if (spec != null) {
      final def = kLightDefs[spec.light]!;
      for (var y = y0; y < y1; y++) {
        final row = map.rows[y];
        for (var x = x0; x < x1; x++) {
          if (_hash(x * 3 + 7, y * 5 + 11) % spec.every != 0) continue;
          if (!Tile.isWalkable(row[x]) || row[x] == Tile.voidTile) continue;
          out.add(LightSource(x + 0.5, y + 0.5, def));
        }
      }
    }
    final guide = kLightDefs[LightId.guia]!;
    void anchor(WorldPoint? p) {
      if (p == null) return;
      final tx = p.x / 16, ty = p.y / 16;
      if (tx < x0 || ty < y0 || tx >= x1 || ty >= y1) return;
      out.add(LightSource(tx, ty, guide));
    }

    if (map.floors.isEmpty) {
      anchor(map.spawn);
    }
    // Wall lamps of the shop interior (player_shop.md § 6.1).
    if (ShopInteriorRules.isShop(map.place)) {
      final lamp = kLightDefs[LightId.lamparaTienda]!;
      for (final (lx, ly) in ShopInteriorRules.lamps) {
        if (lx < x0 || ly < y0 || lx >= x1 || ly >= y1) continue;
        out.add(LightSource(lx, ly, lamp));
      }
    }
    for (final f in map.floors) {
      anchor(f.spawn);
      anchor(f.stairsDown);
      anchor(f.stairsUp);
    }
    return out;
  }

  /// Rectángulo [x0, x1) × [y0, y1) de la estructura del tile ([x], [y]):
  /// el tramo de fila y de columna del mismo tile que lo contiene.
  static (int, int, int, int) structureOf(GameMap map, int x, int y) {
    final c = map.rows[y][x];
    var ax = x, bx = x + 1, ay = y, by = y + 1;
    while (ax > 0 && map.rows[y][ax - 1] == c) {
      ax--;
    }
    while (bx < map.width && map.rows[y][bx] == c) {
      bx++;
    }
    while (ay > 0 && map.rows[ay - 1][x] == c) {
      ay--;
    }
    while (by < map.height && map.rows[by][x] == c) {
      by++;
    }
    return (ax, ay, bx, by);
  }

  static const _dirs = [
    (1, 0, 1.0),
    (-1, 0, 1.0),
    (0, 1, 1.0),
    (0, -1, 1.0),
    (1, 1, math.sqrt2),
    (1, -1, math.sqrt2),
    (-1, 1, math.sqrt2),
    (-1, -1, math.sqrt2),
  ];

  /// Sobreestimación máxima del camino de 8 vecinos respecto de la línea
  /// recta (a 22.5°: cos + (√2 − 1)·sen ≈ 1.0824). Ese sobrante no es un
  /// rodeo: se descuenta para que la luz sea redonda y no octogonal.
  static const octileSlack = 0.0824;

  /// Suma la luz de [sources] en [grid] (lighting.md § 2). Cada luz se
  /// propaga tile a tile (camino más corto, 8 vecinos) desde el tile de la
  /// fuente: los tiles opacos se iluminan pero no dejan pasar; los que
  /// atenúan cuestan recorrido extra. La distancia final de un tile es la
  /// recta desde la posición exacta de la fuente más el rodeo del camino
  /// (lo que el camino tiene de más que la recta desde el tile de la
  /// fuente): la luz sigue a la fuente sin saltos ni estela.
  /// Caída suave: (1 − d/r)². [tintOf]: color de cada clave (r, g, b).
  static void accumulate(LightGrid grid, Iterable<LightSource> sources,
      LightBlock block, (double, double, double) Function(String) tintOf) {
    for (final s in sources) {
      final r = s.def.radius;
      final k0 = s.def.intensity * s.scale;
      if (r <= 0 || k0 <= 0) continue;
      final sx = s.x.floor(), sy = s.y.floor();
      // El camino se mide desde el centro del tile de la fuente; la fuente
      // puede estar hasta ~0.71 tiles corrida: se propaga un poco más.
      final reach = r + 1.5;
      final ri = reach.ceil() + 1;
      // Ventana local de la luz.
      final lx0 = sx - ri, ly0 = sy - ri, n = ri * 2 + 1;
      final dist = Float64List(n * n)..fillRange(0, n * n, double.infinity);
      final (tr, tg, tb) = tintOf(s.def.tint);
      dist[(sy - ly0) * n + (sx - lx0)] = 0;
      // Bloqueo de la ventana local, leído una sola vez. La estructura
      // propia de la luz (§ 2.2) es transparente para ella.
      final blk = Float64List(n * n);
      var anyOpaque = false;
      for (var cy = 0; cy < n; cy++) {
        final ty = cy + ly0;
        for (var cx = 0; cx < n; cx++) {
          final tx = cx + lx0;
          if (tx >= s.ownX0 && tx < s.ownX1 && ty >= s.ownY0 && ty < s.ownY1) {
            continue;
          }
          final v = block(tx, ty);
          blk[cy * n + cx] = v;
          if (v.isInfinite) anyOpaque = true;
        }
      }
      final si = (sy - ly0) * n + (sx - lx0);
      final queue = <int>[si];
      // Relajación en cola (radios chicos: barata).
      var qi = 0;
      while (qi < queue.length) {
        final i = queue[qi++];
        final cx = i % n, cy = i ~/ n;
        final d = dist[i];
        // Un opaco que no es la fuente no deja pasar.
        if (i != si && blk[i].isInfinite) continue;
        for (final (dx, dy, step) in _dirs) {
          final nx = cx + dx, ny = cy + dy;
          if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
          final b = blk[ny * n + nx];
          // Diagonal entre dos opacos: no se cuela.
          if (dx != 0 &&
              dy != 0 &&
              blk[cy * n + nx].isInfinite &&
              blk[ny * n + cx].isInfinite) {
            continue;
          }
          final nd = d + step + (b.isInfinite ? 0 : b);
          if (nd >= reach) continue;
          final j = ny * n + nx;
          if (nd < dist[j] - 1e-6) {
            dist[j] = nd;
            queue.add(j);
          }
        }
      }
      final sub = grid.sub, rw = grid.sw;
      final inv = 1 / sub;
      // Posición de la fuente relativa a la ventana local (para el rayo).
      final ox = s.x - lx0, oy = s.y - ly0;
      for (var cy = 0; cy < n; cy++) {
        final ty = cy + ly0;
        if (ty < grid.y0 || ty >= grid.y0 + grid.h) continue;
        for (var cx = 0; cx < n; cx++) {
          final tx = cx + lx0;
          if (tx < grid.x0 || tx >= grid.x0 + grid.w) continue;
          final path = dist[cy * n + cx];
          if (path.isInfinite) continue;
          // Rodeo = camino − recta (ambos desde el centro del tile de la
          // fuente), sin la sobreestimación propia de los 8 vecinos.
          final straight = _len(tx + 0.5 - sx - 0.5, ty + 0.5 - sy - 0.5);
          final detour = math.max(0.0, path - straight * (1 + octileSlack));
          final opaqueCell = blk[cy * n + cx].isInfinite;
          for (var j = 0; j < sub; j++) {
            final py = ty + (j + 0.5) * inv;
            for (var k = 0; k < sub; k++) {
              final px = tx + (k + 0.5) * inv;
              final d = _len(px - s.x, py - s.y) + detour;
              if (d >= r) continue;
              // Sombra nítida (§ 2.1): la muestra tiene que verse desde la
              // fuente en línea recta. De un opaco solo se ilumina la mitad
              // que da a la fuente.
              if (anyOpaque) {
                if (opaqueCell &&
                    (px - tx - 0.5) * (s.x - tx - 0.5) +
                            (py - ty - 0.5) * (s.y - ty - 0.5) <
                        0) {
                  continue;
                }
                if (!_sees(blk, n, ox, oy, px - lx0, py - ly0)) continue;
              }
              final f = 1 - d / r;
              final kk = k0 * f * f;
              final gi =
                  (((ty - grid.y0) * sub + j) * rw + (tx - grid.x0) * sub + k) *
                      3;
              grid.rgb[gi] += tr * kk;
              grid.rgb[gi + 1] += tg * kk;
              grid.rgb[gi + 2] += tb * kk;
            }
          }
        }
      }
    }
  }

  /// Línea de vista de (ax, ay) a (bx, by) en la ventana local [blk] de
  /// lado [n] (recorrido de celdas exacto): corta si cruza un opaco que
  /// no sea la celda de partida ni la de llegada, o si pasa justo por la
  /// esquina entre dos opacos en diagonal.
  static bool _sees(
      Float64List blk, int n, double ax, double ay, double bx, double by) {
    var cx = ax.floor(), cy = ay.floor();
    final ex = bx.floor(), ey = by.floor();
    if (cx == ex && cy == ey) return true;
    final dx = bx - ax, dy = by - ay;
    final stepX = dx > 0 ? 1 : (dx < 0 ? -1 : 0);
    final stepY = dy > 0 ? 1 : (dy < 0 ? -1 : 0);
    final tdx = stepX == 0 ? double.infinity : (1 / dx).abs();
    final tdy = stepY == 0 ? double.infinity : (1 / dy).abs();
    var tmx = stepX == 0
        ? double.infinity
        : (stepX > 0 ? (cx + 1 - ax) : (ax - cx)) * tdx;
    var tmy = stepY == 0
        ? double.infinity
        : (stepY > 0 ? (cy + 1 - ay) : (ay - cy)) * tdy;
    // Como mucho |Δx| + |Δy| pasos.
    for (var guard = (ex - cx).abs() + (ey - cy).abs() + 2;
        guard > 0;
        guard--) {
      if ((tmx - tmy).abs() < 1e-9) {
        // Esquina exacta: pasa si al menos uno de los dos lados está libre.
        if (_opaque(blk, n, cx + stepX, cy) &&
            _opaque(blk, n, cx, cy + stepY)) {
          return false;
        }
        cx += stepX;
        cy += stepY;
        tmx += tdx;
        tmy += tdy;
      } else if (tmx < tmy) {
        cx += stepX;
        tmx += tdx;
      } else {
        cy += stepY;
        tmy += tdy;
      }
      if (cx == ex && cy == ey) return true;
      if (_opaque(blk, n, cx, cy)) return false;
    }
    return true;
  }

  static bool _opaque(Float64List blk, int n, int x, int y) =>
      x < 0 || y < 0 || x >= n || y >= n || blk[y * n + x] == double.infinity;

  static double _len(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

  /// Titileo suave de una llama en el instante [tMs] (lighting.md § 3.2):
  /// factor alrededor de 1 con amplitud [amp], distinto por luz ([seed]).
  static double flicker(double tMs, double amp, int seed) {
    if (amp <= 0) return 1;
    final p = seed * 0.37;
    final v =
        math.sin(tMs / 130 + p) * 0.6 + math.sin(tMs / 47 + p * 2.1) * 0.4;
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
        (
          a.$1 + (b.$1 - a.$1) * t,
          a.$2 + (b.$2 - a.$2) * t,
          a.$3 + (b.$3 - a.$3) * t
        );
    const day = (1.0, 1.0, 1.0);
    final d = dark.clamp(0.0, 1.0);
    var c = d < 0.5 ? mix(day, dusk, d * 2) : mix(dusk, night, (d - 0.5) * 2);
    final o = 1 - overcast.clamp(0.0, 1.0) * 0.45;
    c = (c.$1 * o, c.$2 * o, c.$3 * o);
    return mix(c, day, bolt.clamp(0.0, 1.0));
  }
}
