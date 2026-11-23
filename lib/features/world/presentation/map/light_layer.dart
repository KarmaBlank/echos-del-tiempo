import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/light_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/rules/light_rules.dart';
import 'map_themes.dart';

/// Capa de luz del mapa (docs/specs/lighting.md § 4): un mapa de luz por
/// tile ([LightRules]) que se dibuja como una malla de vértices en el
/// centro de cada tile (colores interpolados entre tiles, nada de
/// bloques) multiplicada sobre el mapa.
///
/// Rendimiento: la ventana de tiles se alinea a bloques de [chunk]; las
/// luces fijas (tiles, faros) se recalculan solo si cambia la ventana o
/// el conjunto de luces. Por cuadro solo se suman las móviles (jugadores,
/// luciérnagas, botín) y el titileo.
class MapLightLayer {
  static const ts = 16.0;
  static const chunk = 16;

  /// Muestras por tile y eje (lighting.md § 4): 2 × 2 por tile, para que
  /// el borde de las sombras sea nítido sin verse en bloques.
  static const sub = 2;

  /// Margen (tiles) alrededor de la vista: el radio más grande del catálogo.
  static final int margin =
      kLightDefs.values.map((d) => d.radius).reduce(math.max).ceil() + 1;

  LightGrid? _steady, _flame, _out;
  int _sig = 0;
  Object? _mapKey;

  /// Recálculos de las luces fijas (para la línea de rendimiento).
  int rebuilds = 0;

  /// Último mapa de luz combinado (para ocultar enemigos en la penumbra).
  LightGrid? get last => _out;

  /// Índices de la malla por cantidad de filas de una banda (los índices
  /// son de 16 bits: la malla se parte en bandas de < 65 536 vértices).
  final Map<int, Uint16List> _indices = {};
  int _iw = 0;
  Float32List? _pos;
  Int32List? _col;
  int _px0 = 0, _py0 = 0, _pw = 0, _ph = 0;

  static (double, double, double) _rgb(Color c) => (c.r, c.g, c.b);
  static (double, double, double) tintOf(String id) =>
      _rgb(LightPalette.tints[id] ?? LightPalette.fallback);

  /// Ambiente al aire libre.
  static (double, double, double) outdoorAmbient(double dark,
          {double overcast = 0, double bolt = 0}) =>
      LightRules.ambient(dark,
          overcast: overcast,
          bolt: bolt,
          dusk: _rgb(LightPalette.dusk),
          night: _rgb(LightPalette.night));

  static (double, double, double) get dungeonAmbient =>
      _rgb(LightPalette.darkDungeon);

  /// Alinea [v] al bloque de [chunk] hacia abajo. Con `~/` los negativos
  /// se truncaban hacia 0: cerca del borde superior/izquierdo la malla
  /// arrancaba en el centro del tile 0 y media fila quedaba sin oscurecer.
  static int floorChunk(int v) => (v / chunk).floor() * chunk;

  /// Dibuja la luz sobre [view] (px del mundo). [fixed]: luces fijas
  /// (tiles y faros); [moving]: las de este cuadro. [keep]: ajuste
  /// OSCURIDAD (1 = normal, 0 = apagada). [motion]: titileo.
  void draw(Canvas c, GameMap map, Rect view,
      {required (double, double, double) ambient,
      required List<LightSource> Function(int x0, int y0, int x1, int y1) fixed,
      required List<LightSource> moving,
      required double t,
      double keep = 1,
      bool motion = true}) {
    final x0 = floorChunk((view.left / ts).floor() - margin);
    final y0 = floorChunk((view.top / ts).floor() - margin);
    final x1 = floorChunk((view.right / ts).ceil() + margin) + chunk;
    final y1 = floorChunk((view.bottom / ts).ceil() + margin) + chunk;
    final w = x1 - x0, h = y1 - y0;
    final block = LightRules.blockOf(map);
    final src = fixed(x0 - margin, y0 - margin, x1 + margin, y1 + margin);
    var sig = Object.hash(x0, y0, w, h, src.length);
    for (final s in src) {
      sig = Object.hash(sig, s.x, s.y, s.def);
    }
    var steady = _steady;
    if (steady == null ||
        sig != _sig ||
        !identical(_mapKey, map.rows) ||
        steady.x0 != x0 ||
        steady.y0 != y0 ||
        steady.w != w ||
        steady.h != h) {
      steady = _steady = LightGrid(x0, y0, w, h, sub: sub);
      final flame = _flame = LightGrid(x0, y0, w, h, sub: sub);
      LightRules.accumulate(
          steady, src.where((s) => s.def.flicker == 0), block, tintOf);
      LightRules.accumulate(
          flame, src.where((s) => s.def.flicker > 0), block, tintOf);
      _out = LightGrid(x0, y0, w, h, sub: sub);
      _sig = sig;
      _mapKey = map.rows;
      rebuilds++;
    }
    final out = _out!..copyFrom(steady);
    out.addScaled(_flame!, motion ? LightRules.flicker(t, 0.1, 0) : 1);
    LightRules.accumulate(out, moving, block, tintOf);

    // Malla: un vértice por muestra (2 × 2 por tile) con el color final.
    final sw = w * sub, sh = h * sub;
    final n = sw * sh;
    var pos = _pos;
    if (pos == null || _px0 != x0 || _py0 != y0 || _pw != sw || _ph != sh) {
      pos = _pos = Float32List(n * 2);
      for (var y = 0; y < sh; y++) {
        for (var x = 0; x < sw; x++) {
          final i = y * sw + x;
          pos[i * 2] = (x0 + (x + 0.5) / sub) * ts;
          pos[i * 2 + 1] = (y0 + (y + 0.5) / sub) * ts;
        }
      }
      _px0 = x0;
      _py0 = y0;
      _pw = sw;
      _ph = sh;
    }
    final col =
        _col != null && _col!.length == n ? _col! : (_col = Int32List(n));
    final (ar, ag, ab) = ambient;
    final k = keep.clamp(0.0, 1.0);
    // Canal final = 255 × (1 − k + k × mín(1, base + luz)), sin clamp ni
    // closures: es el bucle más caliente de la capa (4 muestras por tile).
    final kk = 255 * k, base = 255 * (1 - k) + 0.5;
    final g = out.rgb;
    for (var i = 0, j = 0; i < n; i++, j += 3) {
      var r = ar + g[j], gg = ag + g[j + 1], b = ab + g[j + 2];
      if (r > 1) r = 1;
      if (gg > 1) gg = 1;
      if (b > 1) b = 1;
      col[i] = 0xFF000000 |
          ((base + kk * r).toInt() << 16) |
          ((base + kk * gg).toInt() << 8) |
          (base + kk * b).toInt();
    }
    if (_iw != sw) {
      _indices.clear();
      _iw = sw;
    }
    final paint = Paint()..blendMode = BlendMode.multiply;
    // Bandas de filas que comparten la fila del borde.
    final maxRows = math.max(2, 65535 ~/ sw);
    for (var r0 = 0; r0 < sh - 1; r0 += maxRows - 1) {
      final rows = math.min(maxRows, sh - r0);
      final idx = _indices[rows] ??= _bandIndices(sw, rows);
      final v0 = r0 * sw, v1 = (r0 + rows) * sw;
      final verts = ui.Vertices.raw(
          VertexMode.triangles, Float32List.sublistView(pos, v0 * 2, v1 * 2),
          colors: Int32List.sublistView(col, v0, v1), indices: idx);
      c.drawVertices(verts, BlendMode.dst, paint);
      verts.dispose();
    }
  }

  static Uint16List _bandIndices(int w, int h) {
    final idx = Uint16List((w - 1) * (h - 1) * 6);
    var j = 0;
    for (var y = 0; y < h - 1; y++) {
      for (var x = 0; x < w - 1; x++) {
        final a = y * w + x, b = a + 1, d = a + w, e = d + 1;
        idx[j++] = a;
        idx[j++] = b;
        idx[j++] = d;
        idx[j++] = b;
        idx[j++] = e;
        idx[j++] = d;
      }
    }
    return idx;
  }
}
