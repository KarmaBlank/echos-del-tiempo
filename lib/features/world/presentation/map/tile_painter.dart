import 'dart:math' as math;
import 'dart:ui';

import '../../../../core/settings/graphics.dart';
import '../../../../game_engine/data/biomes_catalog.dart' show kBiomeLayouts;
import '../../../../game_engine/data/mine_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import 'map_themes.dart';
part 'mine_tiles.dart';

/// Tile vecino (tx, ty) del mapa; `null` fuera del mapa.
typedef TileAt = String? Function(int tx, int ty);

/// `drawTile` del prototipo (líneas 964-988). Dibuja un tile de 16 px en
/// (px, py) del lienzo virtual. Ver docs/specs/exploration.md § "Tiles".
/// Part of a glow tile that [TilePainter.draw] paints.
enum TileGlowPass { all, base }

class TilePainter {
  TilePainter();

  static const ts = 16.0;

  final _paint = Paint()..isAntiAlias = false;

  /// Which part of a glow tile ([glowSplit]) [draw] paints: everything,
  /// only the clock-free base (chunk cache) or only the glow on top.
  TileGlowPass glowPass = TileGlowPass.all;

  /// `true` when the only clock-dependent part of tile [ch] is a small
  /// glow drawn last inside its own cell (the rift's basalt cracks and
  /// ember floor): the base can go to the static chunk cache and the glow
  /// is drawn on top each frame ([TileGlowPass]). Both tiles stay inside
  /// their 16 × 16 cell.
  static bool glowSplit(String ch, String themeId, {required bool lobby}) =>
      themeId == 'grieta' && !lobby && (ch == Tile.wall || ch == Tile.floor);

  /// Tiles whose real drawing stays inside their own cell in [themeId]
  /// (their declared [overflow] is conservative): a later one never covers
  /// a neighbour's glow.
  static bool cellBound(String ch, String themeId) =>
      themeId == 'grieta' &&
      (ch == Tile.wall || ch == Tile.floor || ch == Tile.lava);

  /// The glow of a [glowSplit] tile alone, exactly as [draw] paints it
  /// last (plus the opaque ash fleck that [draw] paints over the ember).
  void drawGlow(Canvas c, String ch, double px, double py, int tx, int ty,
      {required double t}) {
    final h = tileHash(tx, ty);
    if (ch == Tile.wall) {
      if (h % 3 == 0) _basaltGlow(c, px, py, h, t);
      return;
    }
    if (h % 7 == 0) _emberGlow(c, px, py, h, t);
    if (h % 4 == 1) _ashFleck(c, px, py, h);
  }

  /// Hash por tile `((tx*73856093)^(ty*19349663))>>>0` con la aritmética
  /// de 32 bits de JS (sin signo).
  static int tileHash(int tx, int ty) =>
      ((tx * 73856093).toSigned(32) ^ (ty * 19349663).toSigned(32)) &
      0xFFFFFFFF;

  /// `(h >> n) % m` de JS: `>>` trabaja sobre el int32 con signo y `%`
  /// conserva el signo del dividendo.
  static int jsShiftMod(int h, int n, int m) =>
      (h.toSigned(32) >> n).remainder(m);

  void _rect(Canvas c, Color color, double x, double y, double w, double h) {
    _paint.color = color;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _paint);
  }

  void _circle(Canvas c, Color color, double x, double y, double r) {
    _paint.color = color;
    c.drawCircle(Offset(x, y), r, _paint);
  }

  void draw(
    Canvas c,
    String ch,
    double px,
    double py,
    String themeId,
    int tx,
    int ty, {
    required double t,
    required bool gateOpen,
    required bool lobby,
    TileAt? at,
    bool voidBackdrop = false,
    double density = 1,
    double pulse = 0,
    bool cave = false,
  }) {
    // El mapa del mundo: el pueblo con el estilo del lobby, el resto al
    // aire libre (worldgen.md § 7.6).
    if (themeId == 'mundo') {
      lobby = inTown(tx, ty);
      if (lobby) themeId = 'lobby';
    }
    // El pueblo v0.21.0 es al aire libre (town_loop.md § 2.1).
    if (themeId == 'pueblo' ||
        themeId.endsWith('_ext') ||
        themeId.startsWith('mina_')) {
      lobby = false;
    }
    final th = mapTheme(themeId);
    final h = tileHash(tx, ty);

    void floor() {
      _rect(c, th.ground, px, py, ts, ts);
      if (lobby) {
        if ((tx + ty) % 2 == 0) _rect(c, th.ground2, px, py, ts, ts);
        _rect(c, const Color(0x08FFFFFF), px, py, ts, 1);
        return;
      }
      if (h % 3 == 0) {
        _rect(c, th.ground2, px + jsShiftMod(h, 3, 12),
            py + jsShiftMod(h, 7, 12), 2, 2);
      }
      if (h % 5 == 0) {
        _rect(c, th.ground2, px + jsShiftMod(h, 11, 13),
            py + jsShiftMod(h, 15, 13), 1, 3);
      }
      // Bosque: hojas secas sueltas.
      if (themeId == 'bosque' && h % 7 == 0) {
        _rect(c, const Color(0xFF8A6A32), px + jsShiftMod(h, 6, 12).abs() + 2,
            py + jsShiftMod(h, 10, 12).abs() + 2, 2, 1);
      }
      _floorDetail(c, th, themeId, px, py, tx, ty, h, t);
    }

    // Roofed cave of a biome region (biome_regions.md § 7.2.1): rock
    // walls and dark stone floor instead of peaks and grass.
    if (cave && (ch == Tile.rock || ch == Tile.floor)) {
      if (ch == Tile.rock) {
        _caveWall(c, px, py, h);
      } else {
        _caveFloor(c, px, py, h);
      }
      return;
    }
    // Mines v2 (mining_smithing.md § 1.2): natural rock, auto-tiled edges.
    if (themeId.startsWith('mina_') &&
        mineTiles.contains(ch) &&
        _mineTile(c, ch, themeId, px, py, tx, ty, h, at)) {
      return;
    }

    switch (ch) {
      case Tile.floor:
        floor();
      case Tile.path:
        _rect(c, th.path, px, py, ts, ts);
        if (h % 2 == 0) {
          _rect(c, th.path2, px + jsShiftMod(h, 4, 13),
              py + jsShiftMod(h, 9, 13), 2, 2);
        }
        if (lobby) _rect(c, const Color(0x33FFD166), px, py, ts, 1);
        // Fortaleza: losas con junta.
        if (themeId == 'fortaleza' || themeId == 'laberinto') {
          _rect(c, const Color(0x33000000), px, py + ts - 1, ts, 1);
          _rect(c, const Color(0x33000000), px + ((tx + ty).isEven ? 7 : 0), py,
              1, ts);
        }
      case Tile.wall:
        if (lobby) {
          _rect(c, th.wall, px, py, ts, ts);
          _rect(c, th.wall2, px, py + ts - 4, ts, 2);
          if (ty == 0 && tx % 4 == 0) {
            _rect(c, const Color(0x5548DBFB), px + 5, py + 3, 6, 8);
          }
          return;
        }
        floor();
        switch (themeId) {
          case 'pradera':
            _rect(c, const Color(0xFF4A2F1A), px + 6, py + 10, 4, 6);
            _circle(c, th.wall, px + 8, py + 7, 8);
            _circle(c, th.wall2, px + 6, py + 5, 4);
          case 'mundo':
            _tree(c, th, px, py, h);
          case 'bosque':
            _forestWall(c, th, px, py, h);
          case 'cavernas':
            _iceWall(c, th, px, py, h);
          case 'fortaleza':
            _brickWall(c, th, px, py, ty, h);
          case 'laberinto':
            _clockWall(c, th, px, py, ty, h);
          case 'grieta':
            _basaltWall(c, th, px, py, h, t);
          case 'abismo' || 'cementerio' || 'corazon':
            _floatingRock(c, th, themeId, px, py, h, t);
          case 'ruinas':
            _rect(c, th.wall, px + 1, py + 1, ts - 2, ts - 1);
            _rect(c, th.wall2, px + 1, py + 1, ts - 2, 3);
            _rect(c, const Color(0x55000000), px + 1, py + 8, ts - 2, 1);
            _rect(c, const Color(0x55000000), px + (h % 2 != 0 ? 5 : 10),
                py + 4, 1, 4);
          default:
            _rect(c, th.wall, px, py, ts, ts);
            _paint.color = th.wall2;
            c.drawPath(
                Path()
                  ..moveTo(px + 8, py + 1)
                  ..lineTo(px + 12, py + 13)
                  ..lineTo(px + 4, py + 13)
                  ..close(),
                _paint);
            _rect(c, const Color(0x55FFFFFF), px + 7, py + 4, 1, 6);
        }
      case Tile.water:
        _rect(c, th.water, px, py, ts, ts);
        final o = (t / 250 + tx).floor() % 4;
        _rect(c, const Color(0x40FFFFFF), px + o * 3, py + 4 + (ty % 2) * 6, 5,
            1);
        // Hielo: placas brillantes quietas sobre el agua cian.
        if (themeId == 'cavernas' && h % 3 == 0) {
          _rect(c, const Color(0x55DFF9FF), px + jsShiftMod(h, 5, 9).abs() + 1,
              py + jsShiftMod(h, 9, 9).abs() + 1, 5, 3);
        }
      case Tile.gate:
        if (gateOpen) {
          _rect(c, th.path, px, py, ts, ts);
        } else {
          floor();
          final a = (0.5 + 0.3 * math.sin(t / 120 + ty)).clamp(0.0, 1.0);
          final bar = Color.fromRGBO(255, 71, 87, a);
          for (var i = 2; i < ts; i += 5) {
            _rect(c, bar, px + i, py, 2, ts);
          }
        }
      case Tile.merchant:
        floor();
        _rect(c, const Color(0xFF6B4423), px, py + 6, ts, ts - 6);
        _rect(c, const Color(0xFFC08A4A), px, py + 6, ts, 3);
        for (var i = 0; i < 4; i++) {
          _rect(c, i.isOdd ? const Color(0xFFFFFFFF) : const Color(0xFFE74C3C),
              px + i * 4, py - 2, 4, 5);
        }
        _rect(c, const Color(0xFF8A5A2B), px + (tx.isOdd ? ts - 2 : 0), py - 2,
            2, 9);
        if (tx.isEven) {
          _rect(c, const Color(0xFFFF6B81), px + 4, py + 3, 3, 3);
          _rect(c, const Color(0xFF74B9FF), px + 9, py + 3, 3, 3);
        }
      case Tile.armory:
        // FORJA: only the floor here; the stall is the manifest sprite
        // `items.vida_forja`, drawn over the landmark by MapGame.
        floor();
      case Tile.portal:
        // Portal del Eco (ecos_atlas.md § 1): base de piedra y, en el
        // tile del medio, un anillo turquesa que late.
        floor();
        _rect(c, const Color(0xFF2E3142), px, py + 4, ts, ts - 4);
        _rect(c, const Color(0xFF555A70), px, py + 4, ts, 3);
        if (tx % 3 == 1) {
          final k = 0.5 + 0.5 * math.sin(t / 220);
          final glow = Color.fromRGBO(90, 230, 210, 0.55 + 0.35 * k);
          _rect(c, const Color(0xFF555A70), px - 6, py - 12, 2, 16);
          _rect(c, const Color(0xFF555A70), px + ts + 4, py - 12, 2, 16);
          _rect(c, const Color(0xFF555A70), px - 6, py - 14, ts + 12, 2);
          _rect(c, glow, px - 3, py - 11, ts + 6, 14);
          _rect(c, const Color(0xCC0B0E1A), px, py - 8, ts, 8);
          _rect(c, glow, px + 6, py - 6 + (k * 2).round(), 4, 3);
        }
      case Tile.statue:
        // Estatua del Tiempo (ascension.md § 1): pedestal y, en el tile
        // del medio, la figura con un reloj de arena que brilla.
        floor();
        _rect(c, const Color(0xFF3A3550), px, py + 6, ts, ts - 6);
        _rect(c, const Color(0xFF6C5CE7), px, py + 6, ts, 2);
        if (tx % 3 == 2) {
          final k = 0.5 + 0.5 * math.sin(t / 300);
          _rect(c, const Color(0xFFB8B3D9), px + 4, py - 14, 8, 20);
          _rect(c, const Color(0xFF8E88B8), px + 5, py - 18, 6, 5);
          _rect(c, const Color(0xFF8E88B8), px + 2, py - 8, 12, 3);
          _rect(c, Color.fromRGBO(255, 209, 102, 0.6 + 0.4 * k), px + 6,
              py - 12, 4, 2);
          _rect(c, Color.fromRGBO(255, 209, 102, 0.6 + 0.4 * k), px + 7,
              py - 10, 2, 2);
          _rect(c, Color.fromRGBO(162, 155, 254, 0.25 + 0.25 * k), px - 2,
              py - 20, ts + 4, 2);
        }
      case Tile.lostTower:
        // Loot perdido (v0.20.22): base de piedra y, en el tile del medio,
        // una torrecita con una ventana que brilla.
        floor();
        _rect(c, LostTowerPalette.base, px, py + 6, ts, ts - 6);
        _rect(c, LostTowerPalette.rim, px, py + 6, ts, 2);
        if (tx % 3 == 1) {
          final k = 0.5 + 0.5 * math.sin(t / 260);
          _rect(c, LostTowerPalette.stone, px + 3, py - 14, 10, 20);
          _rect(c, LostTowerPalette.cap, px + 1, py - 18, 14, 4);
          _rect(c, LostTowerPalette.cap, px + 5, py - 20, 6, 2);
          _rect(c, LostTowerPalette.glow.withValues(alpha: 0.5 + 0.5 * k),
              px + 6, py - 10, 4, 5);
        }
      case Tile.fountain:
        _grass(c, th, px, py, h);
        _fountain(c, px, py, tx, ty, t);
      case Tile.fishing:
        _rect(c, th.water, px, py, ts, ts);
        _fishingSpot(c, px, py, t);
      case Tile.sign:
        _grass(c, th, px, py, h);
        _sign(c, px, py);
      case Tile.house || Tile.workshop || Tile.shop:
        _grass(c, th, px, py, h);
      case Tile.spikes:
        // Púas de la Prueba: placa de metal y púas que suben y bajan.
        floor();
        _rect(c, const Color(0xFF3B3B48), px + 1, py + 1, ts - 2, ts - 2);
        final up = ((t / 400 + tx + ty) % 2) < 1.4;
        for (var i = 0; i < 3; i++) {
          for (var j = 0; j < 3; j++) {
            final sx = px + 2 + i * 5.0, sy = py + 3 + j * 5.0;
            _rect(c, const Color(0xFF8395A7), sx, sy + (up ? 0 : 2), 2,
                up ? 3 : 1);
            if (up) _rect(c, const Color(0xFFDFE6E9), sx, sy, 1, 1);
          }
        }
      case Tile.pulse:
        // Pulso del Tiempo: glifo que carga (violeta) y estalla (blanco).
        floor();
        final active = pulse >= 1;
        final a = active ? 0.85 : 0.18 + 0.4 * pulse;
        _rect(c, Color.fromRGBO(108, 92, 231, a * 0.5), px, py, ts, ts);
        _rect(c, Color.fromRGBO(162, 155, 254, a), px, py, ts, 1);
        _rect(c, Color.fromRGBO(162, 155, 254, a), px, py, 1, ts);
        if ((tx + ty).isEven) {
          final r = 2 + 5 * (active ? 1.0 : pulse);
          _rect(c, active ? const Color(0xFFFFFFFF) : const Color(0xFFA29BFE),
              px + 8 - r / 2, py + 8 - r / 2, r, r);
        }
      case Tile.counter:
        floor();
        _rect(c, const Color(0xFF6B4423), px, py + 3, ts, ts - 3);
        _rect(c, const Color(0xFFC08A4A), px, py + 3, ts, 4);
        if (tx == 12 || tx == 13) {
          _rect(c, const Color(0xFF48DBFB), px + 4, py - 4, 8, 6);
        }
      case Tile.grass:
        _grass(c, th, px, py, h);
      // Tierra de la huerta (farming.md § 2.3): lo arado y los cultivos
      // los dibuja la capa de la huerta, desde el estado.
      case Tile.soil:
        _rect(c, FarmPalette.soil, px, py, ts, ts);
        if (h % 3 == 0) _rect(c, FarmPalette.soilDark, px + 3 + h % 7, py + 4 + h % 5, 2, 1);
        if (h % 5 == 1) _rect(c, FarmPalette.soilDark, px + 9, py + 11, 2, 1);
      case Tile.tree:
        _grass(c, th, px, py, h);
        _tree(c, th, px, py, h);
      case Tile.rock:
        _grass(c, th, px, py, h);
        _rock(c, th, px, py, h);
      case Tile.stairsDown:
        floor();
        _stairsDown(c, th, px, py);
      case Tile.stairsUp:
        floor();
        _stairsUp(c, th, px, py);
      case Tile.vaultFloor:
        floor();
        // Borde dorado tenue: las baldosas de la bóveda forman una grilla.
        _rect(c, const Color(0x40FFD166), px, py, ts, 1);
        _rect(c, const Color(0x40FFD166), px, py, 1, ts);
        _rect(c, const Color(0x22000000), px + 1, py + ts - 1, ts - 1, 1);
        if (h % 7 == 0) {
          _rect(c, const Color(0x66FFD166), px + 7, py + 7, 2, 2);
        }
      case Tile.voidTile:
        _void(c, th, themeId, px, py, tx, ty, h, t,
            at: at, backdrop: voidBackdrop);
      case Tile.bridge:
        _bridge(c, themeId, px, py, tx, ty, h, t, at);
      case Tile.lava:
        _lava(c, px, py, tx, ty, h, t, at, density);
      case Tile.tombstone:
        floor();
        _tombstone(c, px, py, h);
      case Tile.gear:
        floor();
        _gear(c, px, py, tx, ty, t);
      // ---- exploración v0.6 (worldgen.md § 11, exploration.md) ----
      case Tile.secretFloor:
        // Sala secreta sin abrir: muro del tema (no se delata).
        draw(c, Tile.wall, px, py, themeId, tx, ty,
            t: t,
            gateOpen: gateOpen,
            lobby: lobby,
            at: at,
            voidBackdrop: voidBackdrop,
            density: density,
            pulse: pulse);
        return;
      case Tile.cracked || Tile.shortcut:
        // El muro del tema con grietas (sala secreta) o con una reja y su
        // palanca (atajo).
        draw(c, Tile.wall, px, py, themeId, tx, ty,
            t: t,
            gateOpen: gateOpen,
            lobby: lobby,
            at: at,
            voidBackdrop: voidBackdrop,
            density: density,
            pulse: pulse);
        if (ch == Tile.cracked) {
          _cracks(c, px, py, t);
        } else {
          _shortcut(c, px, py);
        }
        return;
      case Tile.shrine || Tile.shrineUsed:
        floor();
        _shrine(c, px, py, t, used: ch == Tile.shrineUsed);
      case Tile.waystone || Tile.waystoneOn:
        // Region waystones stand on grass (biome_regions.md § 4).
        if (themeId.endsWith('_ext')) {
          _grass(c, th, px, py, h);
        } else {
          floor();
        }
        _waystone(c, px, py, t, on: ch == Tile.waystoneOn);
      // Glowing shore plants (biome_regions.md § 3).
      case Tile.glowPlant:
        _grass(c, th, px, py, h);
        _glowPlant(c, px, py, h);
      case Tile.wind:
        floor();
        _windShrine(c, px, py, t);
      case Tile.brazier || Tile.brazierLit:
        floor();
        _brazier(c, px, py, t, lit: ch == Tile.brazierLit);
      // Farol de mazmorra oscura (lighting.md § 5.5): como el faro.
      case Tile.lantern || Tile.lanternLit:
        floor();
        faro(c, px, py, t, lit: ch == Tile.lanternLit);
      // Minería (mining_smithing.md § 1): boca de mina y vetas.
      case Tile.mineEntrance:
        _grass(c, th, px, py, h);
        _mineMouth(c, px, py);
      case Tile.ore || Tile.oreUsed:
        floor();
        _oreVein(c, themeId, px, py, h, used: ch == Tile.oreUsed);
      // Recolectable de un exterior (overworld_biomes.md § 3.2).
      case Tile.forage || Tile.forageUsed:
        _grass(c, th, px, py, h);
        _forageBush(c, px, py, tx, ty, used: ch == Tile.forageUsed);
      default:
        final zone = Tile.entranceZone(ch);
        if (zone != null) {
          // Base de la entrada; el arco lo dibuja [entrance] encima.
          _grass(c, th, px, py, h);
          _rect(c, const Color(0xFF44474F), px, py + 4, ts, ts - 4);
          _rect(c, const Color(0xFF6B6F7A), px + 1, py + 4, ts - 2, 2);
        } else {
          // Tile desconocido: magenta, para que se note en las pruebas.
          _rect(c, const Color(0xFFFF00FF), px, py, ts, ts);
        }
    }
    // Islas: reborde y canto desmoronado del lado del vacío.
    if (at != null &&
        kAbyssThemes.contains(themeId) &&
        ch != Tile.voidTile &&
        ch != Tile.wall &&
        ch != Tile.bridge) {
      _islandRim(c, th, px, py, tx, ty, h, at);
    }
    // Cementerio: niebla que deriva sobre todo lo que no es vacío.
    if (themeId == 'cementerio' && ch != Tile.voidTile) {
      _fog(c, px, py, tx, ty, t);
    }
  }

  // ------------------------------------------------------------------
  // Rendimiento (exploration.md § "Rendimiento"): qué tiles se pueden
  // grabar una vez (capa estática por bloques) y cuánto sobresalen.
  // ------------------------------------------------------------------

  /// `true` si el dibujo del tile [ch] en ([tx], [ty]) depende del reloj
  /// (`t`), la barrera, el Pulso o las PARTÍCULAS: se dibuja en cada
  /// cuadro. `false`: siempre igual mientras el mapa no cambie (va a la
  /// capa estática). Conservador: ante la duda, animado. Lo verifica
  /// `tile_cache_test.dart` dibujando cada tile con relojes distintos.
  static bool animated(String ch, String themeId, int tx, int ty,
      {required bool lobby, required bool voidBackdrop}) {
    if (themeId == 'mundo') {
      lobby = inTown(tx, ty);
      if (lobby) themeId = 'lobby';
    }
    if (themeId == 'pueblo' ||
        themeId.endsWith('_ext') ||
        themeId.startsWith('mina_')) {
      lobby = false;
    }
    // Mine tiles are static (the torches flicker in the light layer).
    if (themeId.startsWith('mina_') && mineTiles.contains(ch)) return false;
    // Niebla del cementerio: sobre todo lo que no es vacío.
    if (themeId == 'cementerio' && ch != Tile.voidTile) return true;
    final h = tileHash(tx, ty);
    // Brasas de la grieta y destellos del corazón en el suelo.
    final floorAnim = !lobby &&
        ((themeId == 'grieta' && h % 7 == 0) ||
            (themeId == 'corazon' && h % 5 == 1));
    bool wall() {
      if (lobby) return false;
      return floorAnim ||
          (themeId == 'grieta' && h % 3 == 0) ||
          themeId == 'corazon';
    }

    switch (ch) {
      case Tile.path ||
            Tile.grass ||
            Tile.tree ||
            Tile.rock ||
            Tile.sign ||
            Tile.house ||
            Tile.workshop ||
            Tile.shop ||
            Tile.forage ||
            Tile.forageUsed ||
            Tile.glowPlant ||
            Tile.mineEntrance:
        return false;
      case Tile.ore || Tile.oreUsed:
        return floorAnim;
      case Tile.floor ||
            Tile.merchant ||
            Tile.armory ||
            Tile.counter ||
            Tile.stairsDown ||
            Tile.stairsUp ||
            Tile.vaultFloor ||
            Tile.tombstone:
        return floorAnim;
      case Tile.wall || Tile.secretFloor || Tile.shortcut:
        return wall();
      case Tile.voidTile:
        return !voidBackdrop;
      case Tile.bridge:
        return themeId == 'grieta' || themeId == 'corazon';
      case Tile.water ||
            Tile.gate ||
            Tile.portal ||
            Tile.statue ||
            Tile.lostTower ||
            Tile.fountain ||
            Tile.fishing ||
            Tile.spikes ||
            Tile.pulse ||
            Tile.lava ||
            Tile.gear ||
            Tile.cracked ||
            Tile.shrine ||
            Tile.shrineUsed ||
            Tile.waystone ||
            Tile.waystoneOn ||
            Tile.wind ||
            Tile.brazier ||
            Tile.brazierLit ||
            Tile.lantern ||
            Tile.lanternLit:
        return true;
      default:
        // Base de una entrada de zona (el arco va aparte) o desconocido.
        return false;
    }
  }

  /// Cuánto sobresale el dibujo del tile [ch] de su celda de 16 px:
  /// (izquierda, arriba, derecha, abajo). Las motas del suelo usan el
  /// `(h >> n) % m` de JS, que puede ser negativo: el suelo (y todo lo que
  /// lo dibuja debajo) sobresale hasta 12 px a la izquierda y arriba.
  /// Ningún tile sobresale hacia abajo. Lo verifica `tile_cache_test.dart`.
  static (int, int, int, int) overflow(String ch) => switch (ch) {
        Tile.portal => (12, 14, 6, 0),
        Tile.statue || Tile.lostTower => (12, 20, 2, 0),
        Tile.water ||
        Tile.grass ||
        Tile.rock ||
        Tile.fountain ||
        Tile.fishing ||
        Tile.voidTile ||
        Tile.bridge ||
        Tile.lava =>
          (0, 0, 0, 0),
        Tile.tree => (0, 1, 0, 0),
        Tile.sign || Tile.house || Tile.workshop || Tile.shop => (0, 0, 0, 0),
        Tile.mineEntrance => (0, 0, 0, 0),
        _ when Tile.entranceZone(ch) != null => (0, 0, 0, 0),
        _ when !handles(ch) => (0, 0, 0, 0),
        // Suelo y todo lo que se apoya en él (muros, PdI, mostradores...).
        _ => (12, 12, 0, 0),
      };

  /// Lo máximo que sobresale cualquier tile (izq, arriba, der, abajo).
  static const maxOverflow = (12, 20, 6, 0);

  /// Todos los códigos que [draw] sabe dibujar (los de entrada `0`..`9`
  /// incluidos). Ver worldgen.md § 7.6.
  static bool handles(String ch) =>
      mineTiles.contains(ch) ||
      const {
        Tile.soil,
        Tile.floor,
        Tile.path,
        Tile.wall,
        Tile.water,
        Tile.gate,
        Tile.merchant,
        Tile.armory,
        Tile.counter,
        Tile.portal,
        Tile.statue,
        Tile.lostTower,
        Tile.fountain,
        Tile.fishing,
        Tile.sign,
        Tile.house,
        Tile.workshop,
        Tile.shop,
        Tile.spikes,
        Tile.pulse,
        Tile.grass,
        Tile.tree,
        Tile.rock,
        Tile.stairsDown,
        Tile.stairsUp,
        Tile.vaultFloor,
        Tile.voidTile,
        Tile.bridge,
        Tile.lava,
        Tile.tombstone,
        Tile.forage,
        Tile.forageUsed,
        Tile.glowPlant,
        Tile.mineEntrance,
        Tile.ore,
        Tile.oreUsed,
        Tile.gear,
        ...Tile.poiTiles,
      }.contains(ch) ||
      Tile.entranceZone(ch) != null;

  // ------------------------------------------------------------------
  // Puntos de interés (v0.6, worldgen.md § 11)
  // ------------------------------------------------------------------

  /// Grietas en zigzag con un brillo violeta tenue que late.
  void _cracks(Canvas c, double px, double py, double t) {
    const dark = Color(0xEE07080F);
    final k = 0.45 + 0.3 * math.sin(t / 380);
    final glow = Color.fromRGBO(190, 110, 255, k);
    // Halo violeta tenue: algo hay detrás.
    _rect(c, Color.fromRGBO(190, 110, 255, 0.12 + 0.1 * k), px, py, ts, ts);
    for (final (x, y) in const [
      (7, 0),
      (8, 1),
      (7, 2),
      (6, 3),
      (7, 4),
      (8, 5),
      (9, 6),
      (8, 7),
      (7, 8),
      (6, 9),
      (7, 10),
      (8, 11),
      (8, 12),
      (9, 13),
      (5, 5),
      (4, 6),
      (3, 7),
      (10, 8),
      (11, 9),
      (12, 10),
      (13, 11),
    ]) {
      _rect(c, dark, px + x, py + y, 2, 1);
    }
    _rect(c, glow, px + 8, py + 3, 1, 3);
    _rect(c, glow, px + 7, py + 8, 1, 3);
    _rect(c, glow, px + 11, py + 9, 1, 1);
  }

  /// Atajo: reja de hierro con una palanca a un costado.
  void _shortcut(Canvas c, double px, double py) {
    _rect(c, const Color(0xFF2A2D38), px + 2, py + 2, ts - 4, ts - 3);
    for (var i = 4.0; i < ts - 3; i += 3) {
      _rect(c, const Color(0xFF8395A7), px + i, py + 2, 1, ts - 3);
    }
    _rect(c, const Color(0xFF8395A7), px + 2, py + 6, ts - 4, 1);
    _rect(c, const Color(0xFFB08A3A), px + 12, py + 9, 1, 5);
    _rect(c, const Color(0xFFFF6B6B), px + 11, py + 8, 3, 2);
  }

  /// Santuario: pedestal con un cristal que flota; usado, apagado.
  void _shrine(Canvas c, double px, double py, double t, {required bool used}) {
    _rect(c, const Color(0x55000000), px + 2, py + 13, ts - 4, 2);
    _rect(c, const Color(0xFF5A5F73), px + 3, py + 9, ts - 6, 5);
    _rect(c, const Color(0xFF7D8399), px + 3, py + 9, ts - 6, 1);
    final bob = used ? 0.0 : (math.sin(t / 260) * 1.5).roundToDouble();
    final gem = used ? const Color(0xFF6C707A) : const Color(0xFF5AE6D2);
    _rect(c, gem, px + 6, py - 2 + bob, 4, 8);
    _rect(c, used ? const Color(0xFF8A8E99) : const Color(0xFFDFFFFA), px + 7,
        py - 1 + bob, 1, 3);
    if (!used) {
      final k = 0.25 + 0.2 * math.sin(t / 200);
      _rect(c, Color.fromRGBO(90, 230, 210, k), px + 3, py - 4 + bob, 10, 12);
    }
  }

  /// Piedra de paso: menhir con una runa (dorada encendida).
  /// Activated region waystone (biome_regions.md § 4): its rune lit for
  /// the local player, drawn over the static tile.
  void waystoneGlow(Canvas c, double px, double py, double t) {
    final k = 0.6 + 0.4 * math.sin(t / 300);
    _rect(c, RegionPalette.waystoneOn.withValues(alpha: k), px + 7, py - 3, 2,
        8);
    _rect(c, RegionPalette.waystoneOn.withValues(alpha: k), px + 6, py, 4, 1);
    _rect(c, RegionPalette.waystoneOn.withValues(alpha: 0.18 * k), px + 2,
        py - 9, 12, 24);
  }

  void _waystone(Canvas c, double px, double py, double t, {required bool on}) {
    _rect(c, const Color(0x55000000), px + 3, py + 13, ts - 6, 2);
    _rect(c, const Color(0xFF4E5568), px + 4, py - 6, 8, 20);
    _rect(c, const Color(0xFF6B7388), px + 4, py - 6, 2, 20);
    _rect(c, const Color(0xFF4E5568), px + 5, py - 8, 6, 2);
    final k = 0.6 + 0.4 * math.sin(t / 300);
    final rune =
        on ? Color.fromRGBO(255, 209, 102, k) : const Color(0xFF2A2F3D);
    _rect(c, rune, px + 7, py - 3, 2, 8);
    _rect(c, rune, px + 6, py, 4, 1);
    if (on) {
      _rect(c, Color.fromRGBO(255, 209, 102, 0.2 * k), px + 2, py - 9, 12, 24);
    }
  }

  /// Santuario del Viento del Eco: arco bajo con remolinos celestes.
  void _windShrine(Canvas c, double px, double py, double t) {
    _rect(c, const Color(0x55000000), px + 2, py + 13, ts - 4, 2);
    _rect(c, const Color(0xFF7A8AA8), px + 2, py - 2, 2, 15);
    _rect(c, const Color(0xFF7A8AA8), px + 12, py - 2, 2, 15);
    _rect(c, const Color(0xFF9AAAC8), px + 2, py - 4, 12, 2);
    for (var i = 0; i < 3; i++) {
      final a = t / 180 + i * 2.1;
      _rect(c, const Color(0xCCBFEFFF), px + 7 + math.cos(a) * 3,
          py + 5 + math.sin(a) * 3, 2, 1);
    }
  }

  /// Faro del pueblo (day_night_weather.md § 5): el brasero de las
  /// misiones sobre un poste de piedra; [lit] de noche.
  void faro(Canvas c, double px, double py, double t, {required bool lit}) {
    _rect(c, SkyPalette.faroPost, px + 7, py + 6, 2, 9);
    _rect(c, SkyPalette.faroHead, px + 5, py + 13, 6, 2);
    _brazier(c, px, py - 6, t, lit: lit);
  }

  /// Brasero de piedra; encendido, con llama animada.
  void _brazier(Canvas c, double px, double py, double t, {required bool lit}) {
    _rect(c, const Color(0x55000000), px + 3, py + 13, ts - 6, 2);
    _rect(c, const Color(0xFF5A4636), px + 6, py + 8, 4, 6);
    _rect(c, const Color(0xFF7A5F48), px + 3, py + 5, 10, 3);
    _rect(c, const Color(0xFF3A2A20), px + 4, py + 4, 8, 1);
    if (!lit) return;
    final f = (t / 90).floor() % 3;
    _rect(c, const Color(0xFFFF6B1F), px + 5, py - 1 + f * 0.5, 6, 5);
    _rect(c, const Color(0xFFFFD166), px + 6 + (f == 1 ? 1 : 0), py - 3, 3, 4);
    _rect(c, const Color(0x55FFB347), px + 2, py - 5, 12, 10);
  }

  // ------------------------------------------------------------------
  // Mundo
  // ------------------------------------------------------------------

  /// Pasto: verde claro con matas y alguna flor (sin cuadriculado).
  // ------------------------------------------------------------------
  // Pueblo v0.21.0 (town_loop.md § 2.1)
  // ------------------------------------------------------------------

  /// Fuente rúnica de 2×2 (empieza en tile par): pileta de piedra con
  /// agua y, donde se juntan los cuatro tiles, el pilar con runas que
  /// laten. Cada tile dibuja su cuarto.
  void _fountain(Canvas c, double px, double py, int tx, int ty, double t) {
    final left = tx.isEven, top = ty.isEven;
    _rect(c, TownPalette.stoneDark, px, py, ts, ts);
    _rect(c, TownPalette.stone, px + (left ? 1 : 0), py + (top ? 1 : 0),
        ts - 1, ts - 1);
    _rect(c, TownPalette.basin, px + (left ? 3 : 0), py + (top ? 3 : 0),
        ts - 3, ts - 3);
    final o = (t / 300 + tx + ty).floor() % 3;
    _rect(c, TownPalette.foam, px + (left ? 5 : 2) + o * 2,
        py + (top ? 7 : 4), 3, 1);
    // Pilar central (cuarto de un cuadrado de 6×6 en la esquina interior).
    final cx = left ? px + ts - 3 : px, cy = top ? py + ts - 3 : py;
    _rect(c, TownPalette.stoneDark, cx, cy, 3, 3);
    final k = 0.5 + 0.5 * math.sin(t / 280);
    _rect(c, TownPalette.rune.withValues(alpha: 0.45 + 0.5 * k),
        left ? cx + 1 : cx, top ? cy + 1 : cy, 2, 2);
  }

  /// Punto de pesca: muellecito de tablas sobre el agua y una boya.
  void _fishingSpot(Canvas c, double px, double py, double t) {
    _rect(c, TownPalette.plankDark, px + 2, py + 3, 12, 8);
    for (var i = 0; i < 3; i++) {
      _rect(c, TownPalette.plank, px + 3 + i * 4, py + 4, 3, 6);
    }
    final bob = (math.sin(t / 240) * 1.2).roundToDouble();
    _rect(c, TownPalette.foam, px + 5, py + 13, 6, 1);
    _rect(c, TownPalette.bobber, px + 7, py + 11 + bob, 2, 2);
  }

  /// Cartel del lago (pesca).
  /// Mata recolectable: con frutos del color de su tipo, o pelada.
  void _forageBush(Canvas c, double px, double py, int tx, int ty,
      {required bool used}) {
    final kind = [for (final l in kBiomeLayouts.values) ...l.forage]
        .where((f) => f.x == tx && f.y == ty)
        .map((f) => f.kind)
        .firstOrNull ?? 0;
    _circle(c, used ? ForagePalette.picked : ForagePalette.bush, px + 8,
        py + 9, 7);
    _circle(c, used ? ForagePalette.picked : ForagePalette.bushLight, px + 6,
        py + 7, 3);
    if (used) return;
    final col = ForagePalette.fruit[kind % ForagePalette.fruit.length];
    for (final (fx, fy) in const [(4, 9), (9, 5), (11, 11), (7, 12)]) {
      _rect(c, col, px + fx, py + fy, 2, 2);
    }
  }

  /// Glowing shore plant: a few stems with luminous bulbs (static: the
  /// glow at night comes from the light layer).
  void _glowPlant(Canvas c, double px, double py, int h) {
    for (var k = 0; k < 3; k++) {
      final x = px + 3 + ((h >> (k * 3)) % 10);
      final top = py + 3 + ((h >> (k * 2 + 5)) % 6);
      _rect(c, RegionPalette.glowStem, x, top + 2, 1, py + 15 - top - 2);
      _rect(c, RegionPalette.glowLeaf, x - 1, top + 5, 1, 2);
      _rect(c, RegionPalette.glowHalo, x - 1, top - 1, 3, 3);
      _rect(c, RegionPalette.glowBulb, x, top, 1, 2);
    }
  }

  /// Mine entrance: a dark arch in a rock face with timber props.
  void _mineMouth(Canvas c, double px, double py) {
    _rect(c, MinePalette.rock, px, py, ts, ts);
    _rect(c, MinePalette.rockLight, px, py, ts, 2);
    _rect(c, MinePalette.mouth, px + 3, py + 5, ts - 6, ts - 5);
    _rect(c, MinePalette.timber, px + 2, py + 4, 2, ts - 4);
    _rect(c, MinePalette.timber, px + ts - 4, py + 4, 2, ts - 4);
    _rect(c, MinePalette.timber, px + 2, py + 3, ts - 4, 2);
  }

  /// Ore vein: a rock lump with ore flecks (the colour of the mine's
  /// biome); spent, only the bare rock.
  void _oreVein(Canvas c, String themeId, double px, double py, int h,
      {required bool used}) {
    _rect(c, MinePalette.rock, px + 2, py + 4, 12, 11);
    _rect(c, MinePalette.rock, px + 4, py + 2, 8, 2);
    _rect(c, MinePalette.rockLight, px + 4, py + 4, 4, 3);
    if (used) return;
    final col = MinePalette.vein(themeId);
    for (final (fx, fy) in const [(4, 8), (9, 5), (11, 10), (6, 12), (8, 9)]) {
      _rect(c, col, px + fx, py + fy, 2, 2);
    }
  }

  void _sign(Canvas c, double px, double py) {
    _rect(c, TownPalette.plankDark, px + 7, py + 8, 2, 8);
    _rect(c, TownPalette.plankDark, px + 2, py + 2, 12, 7);
    _rect(c, TownPalette.signBoard, px + 3, py + 3, 10, 5);
    _rect(c, TownPalette.plankDark, px + 5, py + 5, 6, 1);
  }

  void _grass(Canvas c, MapTheme th, double px, double py, int h) {
    _rect(c, th.grass, px, py, ts, ts);
    if (h % 3 == 0) {
      final x = px + jsShiftMod(h, 3, 11).abs() + 2,
          y = py + jsShiftMod(h, 7, 10).abs() + 3;
      _rect(c, th.grass2, x, y, 1, 3);
      _rect(c, th.grass2, x + 2, y - 1, 1, 4);
      _rect(c, th.grass2, x + 4, y + 1, 1, 2);
    }
    if (h % 5 == 0) {
      _rect(c, th.grass2, px + jsShiftMod(h, 11, 13).abs(),
          py + jsShiftMod(h, 15, 13).abs(), 2, 2);
    }
    if (h % 17 == 0) {
      _rect(
          c,
          h % 2 == 0 ? const Color(0xFFFFD166) : const Color(0xFFFF8FA3),
          px + jsShiftMod(h, 5, 12).abs() + 2,
          py + jsShiftMod(h, 13, 12).abs() + 2,
          2,
          2);
    }
  }

  /// Árbol redondo (como el `#` de pradera) con los colores del tema.
  void _tree(Canvas c, MapTheme th, double px, double py, int h) {
    _rect(c, th.trunk, px + 6, py + 10, 4, 6);
    _circle(c, th.tree, px + 8, py + 7, 8);
    _circle(c, th.tree2, px + 6, py + 5, 4);
    if (h % 4 == 0) _rect(c, const Color(0x33000000), px + 10, py + 9, 3, 2);
  }

  /// Cave wall block: stacked stone with a lit top edge and cracks.
  void _caveWall(Canvas c, double px, double py, int h) {
    _rect(c, RegionPalette.caveWall, px, py, ts, ts);
    // Two courses of blocks, offset by the hash.
    final off = (h % 3) * 3.0;
    _rect(c, RegionPalette.caveWallDark, px, py + 7, ts, 1);
    _rect(c, RegionPalette.caveWallDark, px + 4 + off, py, 1, 7);
    _rect(c, RegionPalette.caveWallDark, px + (10 - off).abs(), py + 8, 1, 8);
    _rect(c, RegionPalette.caveWallLight, px, py, ts, 1);
    _rect(c, RegionPalette.caveWallLight, px, py + 8, ts, 1);
    if (h % 4 == 0) {
      _rect(c, RegionPalette.caveCrack, px + 2 + h % 9, py + 3, 1, 3);
      _rect(c, RegionPalette.caveCrack, px + 3 + h % 9, py + 5, 2, 1);
    }
    _rect(c, RegionPalette.caveWallDark, px, py + ts - 1, ts, 1);
  }

  /// Cave floor: dark stone with a few pebbles.
  void _caveFloor(Canvas c, double px, double py, int h) {
    _rect(c, RegionPalette.caveFloor, px, py, ts, ts);
    if (h % 3 == 0) {
      _rect(c, RegionPalette.caveFloor2, px + jsShiftMod(h, 3, 12).abs(),
          py + jsShiftMod(h, 7, 12).abs(), 3, 2);
    }
    if (h % 5 == 1) {
      _rect(c, RegionPalette.caveWallLight, px + jsShiftMod(h, 9, 13).abs(),
          py + jsShiftMod(h, 13, 13).abs(), 1, 1);
    }
  }

  /// Roca / montaña gris con nieve arriba.
  void _rock(Canvas c, MapTheme th, double px, double py, int h) {
    final shift = (h % 3 - 1).toDouble();
    _paint.color = th.rock;
    c.drawPath(
        Path()
          ..moveTo(px + 8 + shift, py)
          ..lineTo(px + 16, py + 15)
          ..lineTo(px, py + 15)
          ..close(),
        _paint);
    _paint.color = th.rock2;
    c.drawPath(
        Path()
          ..moveTo(px + 8 + shift, py)
          ..lineTo(px + 8 + shift, py + 15)
          ..lineTo(px, py + 15)
          ..close(),
        _paint);
    _paint.color = const Color(0xFFE8F0FF);
    c.drawPath(
        Path()
          ..moveTo(px + 8 + shift, py)
          ..lineTo(px + 11 + shift, py + 5)
          ..lineTo(px + 8 + shift, py + 4)
          ..lineTo(px + 5 + shift, py + 5)
          ..close(),
        _paint);
    _rect(c, const Color(0x44000000), px, py + 15, ts, 1);
  }

  /// Arco de piedra de la entrada a la zona [zone], de 32 × 40 px con la
  /// base en el borde de abajo del tile de la entrada ([tx], [ty]). Lo
  /// dibuja `MapGame` encima de los tiles (sobresale del tile). Abierta:
  /// portal del color de la zona que late; bloqueada o próximamente:
  /// interior oscuro con candado.
  void entrance(Canvas c, int tx, int ty, int zone,
      {required bool open, required double t, double density = 1}) {
    const stone = Color(0xFF8A8E9A),
        stoneMid = Color(0xFF6B6F7A),
        stoneDark = Color(0xFF44474F);
    final cx = tx * ts + 8, by = ty * ts + ts;
    final left = cx - 16, top = by - 40;
    // Sombra y escalón.
    _rect(c, const Color(0x55000000), left - 1, by - 2, 34, 3);
    _rect(c, stoneDark, left, by - 4, 32, 4);
    _rect(c, stoneMid, left, by - 4, 32, 1);
    // Pilares.
    for (final x in [left + 2, left + 23]) {
      _rect(c, stoneDark, x, top + 6, 7, 30);
      _rect(c, stone, x, top + 6, 5, 30);
      for (var y = top + 12; y < by - 4; y += 7) {
        _rect(c, stoneDark, x, y, 7, 1);
      }
    }
    // Interior.
    final ix = left + 9, iy = top + 8, iw = 14.0, ih = by - 4 - iy;
    if (open) {
      final col = zoneColor(zone);
      final a = (0.55 + 0.25 * math.sin(t / 220 + zone)).clamp(0.0, 1.0);
      _rect(c, const Color(0xFF101018), ix, iy, iw, ih);
      _rect(c, col.withValues(alpha: a), ix, iy, iw, ih);
      _rect(c, col.withValues(alpha: 0.35), ix + 3, iy + 3, iw - 6, ih - 6);
      // Chispas que suben.
      for (var i = 0; i < scaledCount(3, density); i++) {
        final q = ((t / 900 + i / 3 + zone * 0.17) % 1.0);
        _rect(c, const Color(0xCCFFFFFF), ix + 2 + ((i * 5 + zone) % 10),
            iy + ih - 2 - q * (ih - 4), 1, 2);
      }
    } else {
      _rect(c, const Color(0xFF1C1E25), ix, iy, iw, ih);
      _rect(c, const Color(0xFF2A2D36), ix, iy, iw, 2);
      // Candado.
      final lx = cx - 4, ly = iy + ih / 2 - 4;
      _rect(c, kLockedZoneColor, lx + 1, ly - 4, 6, 1);
      _rect(c, kLockedZoneColor, lx, ly - 3, 1, 4);
      _rect(c, kLockedZoneColor, lx + 7, ly - 3, 1, 4);
      _rect(c, const Color(0xFFB0B3BC), lx - 1, ly + 1, 10, 8);
      _rect(c, const Color(0xFF1C1E25), lx + 3, ly + 3, 2, 3);
    }
    // Dintel con piedra clave.
    _rect(c, stoneDark, left - 2, top, 36, 8);
    _rect(c, stone, left - 2, top, 36, 6);
    _rect(c, stoneMid, left - 2, top + 5, 36, 1);
    _rect(c, stoneDark, cx - 4, top - 2, 8, 9);
    _rect(c, open ? zoneColor(zone) : kLockedZoneColor, cx - 2, top, 4, 4);
  }

  // ------------------------------------------------------------------
  // Muros de las zonas
  // ------------------------------------------------------------------

  /// Bosque: árboles densos; pino o copa redonda según el hash.
  void _forestWall(Canvas c, MapTheme th, double px, double py, int h) {
    _rect(c, const Color(0xFF0E2A14), px, py, ts, ts);
    if (h % 3 != 0) {
      _rect(c, th.trunk, px + 7, py + 12, 2, 4);
      _paint.color = th.wall;
      c.drawPath(
          Path()
            ..moveTo(px + 8, py)
            ..lineTo(px + 15, py + 13)
            ..lineTo(px + 1, py + 13)
            ..close(),
          _paint);
      _paint.color = th.wall2;
      c.drawPath(
          Path()
            ..moveTo(px + 8, py + 1)
            ..lineTo(px + 11, py + 7)
            ..lineTo(px + 5, py + 7)
            ..close(),
          _paint);
    } else {
      _rect(c, th.trunk, px + 6, py + 11, 4, 5);
      _circle(c, th.wall, px + 8, py + 7, 8);
      _circle(c, th.wall2, px + 6, py + 5, 3);
      _rect(c, const Color(0x55000000), px + 9, py + 10, 4, 2);
    }
  }

  /// Cavernas: roca helada con facetas y cristales de hielo.
  void _iceWall(Canvas c, MapTheme th, double px, double py, int h) {
    _rect(c, th.wall, px, py, ts, ts);
    _rect(c, th.rock2, px + jsShiftMod(h, 3, 8).abs(),
        py + jsShiftMod(h, 6, 8).abs() + 2, 6, 4);
    _rect(c, th.rock, px + jsShiftMod(h, 9, 9).abs(),
        py + jsShiftMod(h, 12, 6).abs() + 8, 7, 3);
    if (h % 4 == 0) {
      final x = px + jsShiftMod(h, 5, 10).abs() + 3;
      _paint.color = th.wall2;
      c.drawPath(
          Path()
            ..moveTo(x, py + 2)
            ..lineTo(x + 2, py + 9)
            ..lineTo(x - 2, py + 9)
            ..close(),
          _paint);
      _rect(c, const Color(0xCCFFFFFF), x - 1, py + 5, 1, 2);
    }
  }

  /// Fortaleza: ladrillo oscuro con juntas desfasadas por fila.
  void _brickWall(Canvas c, MapTheme th, double px, double py, int ty, int h) {
    _rect(c, th.wall, px, py, ts, ts);
    const mortar = Color(0xFF15121A);
    final top = th.wall2.withValues(alpha: 0.35);
    for (var r = 0; r < 4; r++) {
      final y = py + r * 4;
      _rect(c, mortar, px, y + 3, ts, 1);
      final off = (r + ty).isEven ? 0.0 : 4.0;
      _rect(c, mortar, px + off + 3, y, 1, 3);
      _rect(c, mortar, px + off + 11, y, 1, 3);
      _rect(c, top, px, y, ts, 1);
    }
    if (h % 9 == 0) _rect(c, const Color(0xFF3E5A3A), px + 2, py + 13, 4, 2);
    if (h % 7 == 0) _rect(c, const Color(0xAA000000), px + 9, py + 5, 1, 5);
  }

  // ------------------------------------------------------------------
  // Escaleras
  // ------------------------------------------------------------------

  /// `>`: agujero oscuro con peldaños que bajan.
  void _stairsDown(Canvas c, MapTheme th, double px, double py) {
    _rect(c, th.wall2, px + 1, py + 1, 14, 14);
    _rect(c, const Color(0xFF07070C), px + 2, py + 2, 12, 12);
    const steps = [Color(0xFF8A8A96), Color(0xFF5E5E6A), Color(0xFF3A3A44)];
    for (var i = 0; i < steps.length; i++) {
      _rect(c, steps[i], px + 3 + i, py + 3 + i * 3, 10 - i * 2.0, 2);
    }
    _rect(c, const Color(0xFFFFD166), px + 7, py + 12, 2, 1);
  }

  /// `<`: peldaños claros que suben.
  void _stairsUp(Canvas c, MapTheme th, double px, double py) {
    const steps = [
      Color(0xFFDDE0E8),
      Color(0xFFC2C6D0),
      Color(0xFFA6AAB6),
      Color(0xFF8A8E9A),
    ];
    for (var i = 0; i < steps.length; i++) {
      final y = py + 2 + i * 3;
      _rect(c, steps[i], px + 2, y, 12, 3);
      _rect(c, const Color(0x55000000), px + 2, y + 2, 12, 1);
    }
    _rect(c, th.wall2, px + 1, py + 1, 1, 14);
    _rect(c, th.wall2, px + 14, py + 1, 1, 14);
  }

  // ------------------------------------------------------------------
  // Zonas 6–10 (v0.3.0, exploration.md § "Zonas 6–10")
  // ------------------------------------------------------------------

  /// Hueco (vacío o lava) para bordes y orientación de puentes.
  static bool _gap(String? c) => c == Tile.voidTile || c == Tile.lava;

  /// Detalle del suelo de los temas nuevos.
  void _floorDetail(Canvas c, MapTheme th, String themeId, double px, double py,
      int tx, int ty, int h, double t) {
    switch (themeId) {
      case 'laberinto':
        // Losas con junta y alguna marca de engranaje.
        _rect(c, const Color(0x40000000), px, py + ts - 1, ts, 1);
        _rect(c, const Color(0x40000000), px + (ty.isEven ? 0 : 8), py, 1,
            ts - 1);
        _rect(c, const Color(0x14FFFFFF), px, py, ts, 1);
        if (h % 11 == 0) {
          const b = Color(0x88B08A3A);
          _rect(c, b, px + 6, py + 6, 3, 3);
          _rect(c, b, px + 7, py + 5, 1, 5);
          _rect(c, b, px + 5, py + 7, 5, 1);
          _rect(c, th.ground, px + 7, py + 7, 1, 1);
        }
      case 'grieta':
        // Ceniza con brasas que laten.
        if (h % 7 == 0 && glowPass == TileGlowPass.all) {
          _emberGlow(c, px, py, h, t);
        }
        if (h % 4 == 1) _ashFleck(c, px, py, h);
      case 'cementerio':
        // Pasto seco y musgo.
        if (h % 5 == 0) {
          final x = px + jsShiftMod(h, 3, 11).abs() + 2,
              y = py + jsShiftMod(h, 7, 10).abs() + 3;
          const dry = Color(0xFF8E8C5E);
          _rect(c, dry, x, y, 1, 3);
          _rect(c, dry, x + 2, y - 1, 1, 4);
        }
        if (h % 9 == 0) {
          _rect(c, const Color(0xFF5E7A44), px + jsShiftMod(h, 9, 10).abs(),
              py + jsShiftMod(h, 13, 10).abs() + 4, 4, 2);
        }
      case 'abismo':
        // Vetas de la roca.
        if (h % 4 == 0) {
          final x = px + jsShiftMod(h, 5, 10).abs() + 2,
              y = py + jsShiftMod(h, 9, 10).abs() + 2;
          _rect(c, th.rock, x, y, 4, 1);
          _rect(c, th.rock, x + 3, y + 1, 3, 1);
        }
      case 'corazon':
        // Cristal: faceta clara y, a veces, un reloj tallado.
        _rect(c, const Color(0x22FFFFFF), px, py, ts, 1);
        _rect(c, const Color(0x18000000), px + ts - 1, py, 1, ts);
        if (h % 4 == 1) {
          // Faceta diagonal del cristal.
          for (var i = 0; i < 6; i++) {
            _rect(c, const Color(0x30FFFFFF), px + 3 + i, py + 9 - i, 1, 1);
          }
        }
        if (h % 10 == 0) {
          // Reloj tallado: aro de 7 px con dos agujas.
          const g = Color(0xFFB8902A);
          final x = px + 4, y = py + 4;
          _rect(c, g, x + 2, y, 3, 1);
          _rect(c, g, x + 2, y + 6, 3, 1);
          _rect(c, g, x, y + 2, 1, 3);
          _rect(c, g, x + 6, y + 2, 1, 3);
          _rect(c, g, x + 1, y + 1, 1, 1);
          _rect(c, g, x + 5, y + 1, 1, 1);
          _rect(c, g, x + 1, y + 5, 1, 1);
          _rect(c, g, x + 5, y + 5, 1, 1);
          _rect(c, g, x + 3, y + 2, 1, 2);
          _rect(c, g, x + 3, y + 3, 2, 1);
        }
        final tw = math.sin(t / 500 + h % 23);
        if (h % 5 == 1 && tw > 0.6) {
          final x = px + jsShiftMod(h, 7, 12).abs() + 2,
              y = py + jsShiftMod(h, 11, 12).abs() + 2;
          _rect(c, const Color(0xFFFFFFFF), x, y - 1, 1, 3);
          _rect(c, const Color(0xFFFFFFFF), x - 1, y, 3, 1);
        }
    }
  }

  /// Laberinto: sillar de pizarra con ribete de bronce y remaches.
  void _clockWall(Canvas c, MapTheme th, double px, double py, int ty, int h) {
    _rect(c, th.wall, px, py, ts, ts);
    const mortar = Color(0xFF151B28);
    _rect(c, const Color(0xFF2C3850), px, py + 2, ts, 6);
    _rect(c, mortar, px, py + 8, ts, 1);
    _rect(c, mortar, px + (ty.isEven ? 7 : 3), py + 2, 1, 6);
    _rect(c, mortar, px + (ty.isEven ? 3 : 11), py + 9, 1, 7);
    // Ribete y remaches de bronce.
    _rect(c, th.wall2, px, py, ts, 2);
    _rect(c, const Color(0xFF7A5A22), px, py + 1, ts, 1);
    _rect(c, const Color(0xFFE0B860), px + 2, py + 4, 1, 1);
    _rect(c, const Color(0xFFE0B860), px + 13, py + 4, 1, 1);
    if (h % 6 == 0) {
      // Engranaje incrustado.
      const b = Color(0xFF8A6A2A);
      _rect(c, b, px + 6, py + 10, 4, 4);
      _rect(c, b, px + 7, py + 9, 2, 6);
      _rect(c, b, px + 5, py + 11, 6, 2);
      _rect(c, mortar, px + 7, py + 11, 2, 2);
    }
  }

  /// Grieta: columna de basalto con grietas que brillan.
  void _basaltWall(
      Canvas c, MapTheme th, double px, double py, int h, double t) {
    _rect(c, th.wall, px, py, ts, ts);
    _rect(c, const Color(0xFF2A2426), px, py, ts, 3);
    _rect(c, const Color(0xFF0F0C0D), px + 5, py + 3, 1, 13);
    _rect(c, const Color(0xFF0F0C0D), px + 11, py + 3, 1, 13);
    _rect(c, const Color(0xFF242022), px + 1, py + 3, 3, 13);
    if (h % 3 == 0 && glowPass == TileGlowPass.all) {
      _basaltGlow(c, px, py, h, t);
    }
  }

  void _basaltGlow(Canvas c, double px, double py, int h, double t) {
    final a = (0.5 + 0.35 * math.sin(t / 300 + h % 10)).clamp(0.0, 1.0);
    final glow = Color.fromRGBO(255, 123, 41, a);
    final x = px + 6 + jsShiftMod(h, 4, 4).abs();
    _rect(c, glow, x, py + 4, 1, 3);
    _rect(c, glow, x + 1, py + 7, 1, 3);
    _rect(c, glow, x, py + 10, 1, 4);
    _rect(c, Color.fromRGBO(255, 209, 102, a * 0.8), x + 1, py + 8, 1, 1);
  }

  void _emberGlow(Canvas c, double px, double py, int h, double t) {
    final a = 0.45 + 0.35 * math.sin(t / 300 + h % 13);
    _rect(
        c,
        Color.fromRGBO(255, 123, 41, a.clamp(0.0, 1.0)),
        px + jsShiftMod(h, 4, 13).abs() + 1,
        py + jsShiftMod(h, 8, 13).abs() + 1,
        1,
        1);
  }

  void _ashFleck(Canvas c, double px, double py, int h) =>
      _rect(c, const Color(0xFF26211F), px + jsShiftMod(h, 6, 12).abs(),
          py + jsShiftMod(h, 12, 12).abs() + 2, 3, 1);

  /// Abismo / cementerio / corazón: pilar de roca (o cristal) flotante.
  void _floatingRock(Canvas c, MapTheme th, String themeId, double px,
      double py, int h, double t) {
    _rect(c, th.wall, px, py, ts, ts);
    _rect(c, th.rock2, px, py, ts, 4);
    _rect(c, th.rock, px, py + 4, ts, 1);
    _rect(c, th.rock, px + jsShiftMod(h, 3, 9).abs() + 2, py + 7, 4, 1);
    _rect(c, th.rock, px + jsShiftMod(h, 7, 7).abs() + 5, py + 11, 3, 1);
    if (themeId == 'corazon') {
      // Cristal dorado con destello.
      _paint.color = th.wall2;
      final x = px + 4 + (h % 6);
      c.drawPath(
          Path()
            ..moveTo(x, py + 1)
            ..lineTo(x + 3, py + 9)
            ..lineTo(x - 3, py + 9)
            ..close(),
          _paint);
      if (math.sin(t / 400 + h % 17) > 0.5) {
        _rect(c, const Color(0xFFFFFFFF), x - 1, py + 4, 1, 2);
      }
    } else if (themeId == 'cementerio' && h % 3 == 0) {
      _rect(c, const Color(0xFF6B8A4A), px + 2, py, 5, 2);
    }
  }

  /// `_`: vacío. Con [backdrop] el fondo ya lo pintó `VoidPainter`; solo
  /// se dibuja el canto de las islas vecinas.
  void _void(Canvas c, MapTheme th, String themeId, double px, double py,
      int tx, int ty, int h, double t,
      {required TileAt? at, required bool backdrop}) {
    if (!backdrop) {
      final (top, bottom) = voidGradient(themeId);
      _rect(c, Color.lerp(top, bottom, (ty % 8) / 8)!, px, py, ts, ts);
      if (h % 5 == 0) {
        final a = (0.5 + 0.4 * math.sin(t / 400 + h % 17)).clamp(0.0, 1.0);
        _rect(
            c,
            Color.fromRGBO(255, 255, 255, a),
            px + jsShiftMod(h, 3, 14).abs(),
            py + jsShiftMod(h, 7, 14).abs(),
            1,
            1);
      }
    }
    if (at == null) return;
    final up = at(tx, ty - 1);
    final left = at(tx - 1, ty), right = at(tx + 1, ty);
    // Sombras laterales de las islas.
    if (left != null && left != Tile.voidTile) {
      _rect(c, const Color(0x55000000), px, py, 2, ts);
    }
    if (right != null && right != Tile.voidTile) {
      _rect(c, const Color(0x55000000), px + ts - 2, py, 2, ts);
    }
    if (up == null || up == Tile.voidTile) return;
    if (up == Tile.bridge) {
      // Viga bajo el puente.
      _rect(c, const Color(0xFF3A2A18), px, py, ts, 2);
      _rect(c, const Color(0x66000000), px, py + 2, ts, 2);
      return;
    }
    // Canto de roca que cuelga, dentado por hash.
    final face = th.wall, band = th.rock;
    for (var x = 0; x < 16; x += 2) {
      final d = 5 + ((h >> (x + 1)) & 3) + (x == 0 || x == 14 ? -1 : 0);
      _rect(c, const Color(0x66000000), px + x, py + d, 2, 4);
      _rect(c, face, px + x, py, 2, d.toDouble());
      _rect(c, band, px + x, py, 2, 3);
      if (((h >> x) & 7) == 0) {
        _rect(c, band, px + x, py + d - 2, 1, 1);
      }
    }
    _rect(c, th.ground2, px, py, ts, 1);
    if (themeId == 'corazon' && h % 4 == 0) {
      _rect(c, const Color(0xFFFFF3C4), px + 5 + (h % 5), py + 2, 1, 2);
    }
  }

  /// Reborde y desmoronado de un tile de isla junto al vacío.
  void _islandRim(Canvas c, MapTheme th, double px, double py, int tx, int ty,
      int h, TileAt at) {
    const crumb = Color(0xFF05060C);
    final rim = th.ground2;
    if (at(tx, ty - 1) == Tile.voidTile) {
      _rect(c, rim, px, py, ts, 1);
      _rect(c, crumb, px + jsShiftMod(h, 3, 14).abs(), py, 2, 1);
    }
    if (at(tx, ty + 1) == Tile.voidTile) {
      _rect(c, th.rock, px, py + ts - 2, ts, 2);
      _rect(c, crumb, px + jsShiftMod(h, 5, 14).abs(), py + ts - 1, 2, 1);
      _rect(c, crumb, px + jsShiftMod(h, 9, 13).abs() + 2, py + ts - 1, 1, 1);
    }
    if (at(tx - 1, ty) == Tile.voidTile) {
      _rect(c, rim, px, py, 1, ts);
      _rect(c, crumb, px, py + jsShiftMod(h, 7, 14).abs(), 1, 2);
    }
    if (at(tx + 1, ty) == Tile.voidTile) {
      _rect(c, th.rock, px + ts - 1, py, 1, ts);
      _rect(c, crumb, px + ts - 1, py + jsShiftMod(h, 11, 14).abs(), 1, 2);
    }
  }

  /// Niebla del cementerio: dos bandas por tile que derivan.
  void _fog(Canvas c, double px, double py, int tx, int ty, double t) {
    for (var i = 0; i < 2; i++) {
      final a = math.sin(tx * 0.35 + t / 1800 + (ty * 2 + i) * 0.7) * 0.10;
      if (a <= 0.01) continue;
      _rect(c, Color.fromRGBO(220, 225, 235, a), px, py + i * 8, ts, 8);
    }
  }

  /// `=`: puente. La dirección y las barandas salen de los vecinos.
  void _bridge(Canvas c, String themeId, double px, double py, int tx, int ty,
      int h, double t, TileAt? at) {
    final up = _gap(at?.call(tx, ty - 1)), down = _gap(at?.call(tx, ty + 1));
    final left = _gap(at?.call(tx - 1, ty)), right = _gap(at?.call(tx + 1, ty));
    final horizontal = up || down || !(left || right);
    final (Color base, Color plank, Color rail, Color post) = switch (themeId) {
      'corazon' => (
          const Color(0xFFA89E80),
          const Color(0xFFCFC6A8),
          const Color(0xFFFFD166),
          const Color(0xFFB8902A)
        ),
      'grieta' => (
          const Color(0xFF231E20),
          const Color(0xFF3A3436),
          const Color(0xFF5A5050),
          const Color(0xFF2A2426)
        ),
      _ => (
          const Color(0xFF4E3820),
          const Color(0xFF8A6A3A),
          const Color(0xFFC8A86A),
          const Color(0xFF5A4026)
        ),
    };
    _rect(c, base, px, py, ts, ts);
    final stone = themeId == 'corazon' || themeId == 'grieta';
    for (var i = 0; i < 4; i++) {
      final shade = (h >> i) & 1 == 0 ? plank : Color.lerp(plank, base, 0.25)!;
      if (horizontal) {
        _rect(c, shade, px + i * 4, py, stone ? 4 : 3, ts);
      } else {
        _rect(c, shade, px, py + i * 4, ts, stone ? 4 : 3);
      }
    }
    if (stone) {
      // Juntas de las losas.
      if (horizontal) {
        _rect(c, base, px + ((tx.isEven) ? 7 : 15), py, 1, ts);
      } else {
        _rect(c, base, px, py + ((ty.isEven) ? 7 : 15), ts, 1);
      }
    } else if (h % 3 == 0) {
      // Clavos.
      _rect(c, const Color(0xFF2A1E10), px + 1, py + 2, 1, 1);
      _rect(c, const Color(0xFF2A1E10), px + 9, py + 12, 1, 1);
    }
    if (themeId == 'grieta') {
      final a = (0.25 + 0.2 * math.sin(t / 350 + tx)).clamp(0.0, 1.0);
      _rect(c, Color.fromRGBO(255, 123, 41, a), px + (h % 9) + 3,
          py + (horizontal ? 0 : 7), horizontal ? 1 : 6, horizontal ? 6 : 1);
    }
    if (themeId == 'corazon' && h % 4 == 0) {
      final a = (0.5 + 0.4 * math.sin(t / 300 + h % 7)).clamp(0.0, 1.0);
      final r = Color.fromRGBO(255, 209, 102, a);
      _rect(c, r, px + 6, py + 5, 4, 1);
      _rect(c, r, px + 7, py + 5, 1, 6);
      _rect(c, r, px + 6, py + 10, 4, 1);
    }
    // Barandas del lado del hueco.
    void railH(double y) {
      _rect(c, rail, px, y, ts, 1);
      _rect(c, post, px + 1, y - 1, 2, 3);
      _rect(c, post, px + 9, y - 1, 2, 3);
    }

    void railV(double x) {
      _rect(c, rail, x, py, 1, ts);
      _rect(c, post, x - 1, py + 1, 3, 2);
      _rect(c, post, x - 1, py + 9, 3, 2);
    }

    if (up) railH(py + 1);
    if (down) {
      railH(py + ts - 2);
      _rect(c, const Color(0x66000000), px, py + ts - 1, ts, 1);
    }
    if (left) railV(px + 1);
    if (right) railV(px + ts - 2);
  }

  /// `%`: lava animada con corriente, brillo y burbujas (según PARTÍCULAS).
  void _lava(Canvas c, double px, double py, int tx, int ty, int h, double t,
      TileAt? at, double density) {
    _rect(c, const Color(0xFFC0391B), px, py, ts, ts);
    // Corriente: bandas que se desplazan.
    for (var i = 0; i < 3; i++) {
      final y = ((i * 6 + t / 180 + tx * 3 + ty * 5) % 16).floorToDouble();
      final x = ((i * 5 + ty * 3 + (t / 260).floor()) % 6).toDouble();
      _rect(c, const Color(0xFFFF6B1F), px + x, py + y, 9, y > 14 ? 1 : 2);
    }
    final glow = (0.35 + 0.3 * math.sin(t / 260 + h % 11)).clamp(0.0, 1.0);
    _rect(
        c,
        Color.fromRGBO(255, 209, 102, glow),
        px + jsShiftMod(h, 3, 12).abs() + 2,
        py + jsShiftMod(h, 7, 12).abs() + 2,
        2,
        1);
    // Burbujas: menos tiles con menos partículas.
    final every = density >= 1 ? 3 : (density >= 0.6 ? 5 : 9);
    if (h % every == 0 && scaledCount(1, density) > 0) {
      final q = (t / 1400 + (h % 100) / 100) % 1.0;
      final bx = px + jsShiftMod(h, 9, 10).abs() + 3,
          by = py + jsShiftMod(h, 13, 10).abs() + 3;
      if (q < 0.8) {
        final r = 1 + (q * 2.5).floor().toDouble();
        _rect(c, const Color(0xFFFFB347), bx, by, r, r);
        _rect(c, const Color(0xFFFFE08A), bx, by, 1, 1);
      } else {
        const pop = Color(0xFFFFD166);
        _rect(c, pop, bx - 1, by, 1, 1);
        _rect(c, pop, bx + 2, by, 1, 1);
        _rect(c, pop, bx, by - 2, 1, 1);
      }
    }
    // Costra contra la orilla.
    if (at != null) {
      const crust = Color(0xFF4A1A10);
      bool shore(String? n) => n != null && n != Tile.lava && n != Tile.bridge;
      if (shore(at(tx, ty - 1))) _rect(c, crust, px, py, ts, 2);
      if (shore(at(tx, ty + 1))) _rect(c, crust, px, py + ts - 1, ts, 1);
      if (shore(at(tx - 1, ty))) _rect(c, crust, px, py, 1, ts);
      if (shore(at(tx + 1, ty))) _rect(c, crust, px + ts - 1, py, 1, ts);
    }
  }

  /// `t`: lápida gris con cruz o RIP y musgo.
  void _tombstone(Canvas c, double px, double py, int h) {
    const stone = Color(0xFF8A8E96),
        dark = Color(0xFF5E626A),
        light = Color(0xFFA8ACB4);
    _rect(c, const Color(0x55000000), px + 3, py + 13, 11, 2);
    _rect(c, dark, px + 4, py + 4, 9, 11);
    _rect(c, stone, px + 4, py + 4, 8, 10);
    _rect(c, stone, px + 5, py + 3, 6, 1);
    _rect(c, stone, px + 6, py + 2, 4, 1);
    _rect(c, light, px + 5, py + 4, 1, 8);
    if (h % 2 == 0) {
      _rect(c, dark, px + 7, py + 5, 2, 7);
      _rect(c, dark, px + 5, py + 7, 6, 2);
    } else {
      _rect(c, dark, px + 5, py + 7, 6, 1);
      _rect(c, dark, px + 5, py + 9, 6, 1);
      _rect(c, dark, px + 5, py + 11, 4, 1);
    }
    if (h % 3 == 0) _rect(c, const Color(0xFF6B8A4A), px + 4, py + 12, 4, 2);
    _rect(c, const Color(0xFF4A4E56), px + 3, py + 14, 10, 1);
  }

  /// `o`: engranaje de bronce que gira lento (en zigzag).
  void _gear(Canvas c, double px, double py, int tx, int ty, double t) {
    const bronze = Color(0xFFB08A3A),
        dark = Color(0xFF7A5A22),
        hub = Color(0xFF2A1E10);
    final dir = (tx + ty).isEven ? 1.0 : -1.0;
    final a0 = dir * t / 1600 + tx * 0.7;
    final cx = px + 8, cy = py + 8;
    _rect(c, const Color(0x55000000), px + 3, py + 13, 11, 2);
    for (var k = 0; k < 8; k++) {
      final a = a0 + k * math.pi / 4;
      final x = (cx + math.cos(a) * 6 - 1).roundToDouble();
      final y = (cy + math.sin(a) * 6 - 1).roundToDouble();
      _rect(c, dark, x, y, 2, 2);
    }
    _circle(c, dark, cx, cy, 5);
    _circle(c, bronze, cx - 0.5, cy - 0.5, 4.5);
    _circle(c, dark, cx, cy, 2.5);
    _rect(c, hub, cx - 1, cy - 1, 2, 2);
    // Rayo que marca el giro.
    final x = (cx + math.cos(a0) * 3).roundToDouble(),
        y = (cy + math.sin(a0) * 3).roundToDouble();
    _rect(c, const Color(0xFFE0B860), x, y, 1, 1);
  }
}
