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

  Uint16List? _indices;
  int _iw = 0, _ih = 0;

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

  /// Dibuja la luz sobre [view] (px del mundo). [fixed]: luces fijas
  /// (tiles y faros); [moving]: las de este cuadro. [keep]: ajuste
  /// OSCURIDAD (1 = normal, 0 = apagada). [motion]: titileo.
  void draw(Canvas c, GameMap map, Rect view,
      {required (double, double, double) ambient,
      required List<LightSource> Function(int x0, int y0, int x1, int y1)
          fixed,
      required List<LightSource> moving,
      required double t,
      double keep = 1,
      bool motion = true}) {
    final x0 = ((view.left / ts).floor() - margin) ~/ chunk * chunk;
    final y0 = ((view.top / ts).floor() - margin) ~/ chunk * chunk;
    final x1 = (((view.right / ts).ceil() + margin) ~/ chunk + 1) * chunk;
    final y1 = (((view.bottom / ts).ceil() + margin) ~/ chunk + 1) * chunk;
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
      steady = _steady = LightGrid(x0, y0, w, h);
      final flame = _flame = LightGrid(x0, y0, w, h);
      LightRules.accumulate(
          steady, src.where((s) => s.def.flicker == 0), block, tintOf);
      LightRules.accumulate(
          flame, src.where((s) => s.def.flicker > 0), block, tintOf);
      _out = LightGrid(x0, y0, w, h);
      _sig = sig;
      _mapKey = map.rows;
      rebuilds++;
    }
    final out = _out!..copyFrom(steady);
    out.addScaled(_flame!, motion ? LightRules.flicker(t, 0.1, 0) : 1);
    LightRules.accumulate(out, moving, block, tintOf);

    // Malla: un vértice por tile con el color final.
    final n = w * h;
    final pos = Float32List(n * 2);
    final col = Int32List(n);
    final (ar, ag, ab) = ambient;
    final k = keep.clamp(0.0, 1.0);
    int ch(double base, double light) {
      final v = math.min(1.0, base + light);
      return (255 * (1 - k + k * v)).round().clamp(0, 255);
    }

    final g = out.rgb;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        pos[i * 2] = (x0 + x + 0.5) * ts;
        pos[i * 2 + 1] = (y0 + y + 0.5) * ts;
        col[i] = 0xFF000000 |
            (ch(ar, g[i * 3]) << 16) |
            (ch(ag, g[i * 3 + 1]) << 8) |
            ch(ab, g[i * 3 + 2]);
      }
    }
    if (_indices == null || _iw != w || _ih != h) {
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
      _indices = idx;
      _iw = w;
      _ih = h;
    }
    final verts = ui.Vertices.raw(VertexMode.triangles, pos,
        colors: col, indices: _indices);
    c.drawVertices(
        verts, BlendMode.dst, Paint()..blendMode = BlendMode.multiply);
    verts.dispose();
  }
}
