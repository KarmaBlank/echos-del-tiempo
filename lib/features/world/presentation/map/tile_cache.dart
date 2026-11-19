import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../../game_engine/models/game_map.dart';
import 'tile_painter.dart';

/// Capa de tiles del mapa con caché (docs/specs/exploration.md §
/// "Rendimiento").
///
/// Los tiles que no se animan ([TilePainter.animated] = `false`) se graban
/// UNA vez en imágenes de [chunk]×[chunk] tiles; cada cuadro se dibujan
/// esas pocas imágenes en lugar de miles de rectángulos y caminos (los
/// muros de bosque, las rocas y los árboles son `Path`s que el motor
/// teselaba en cada cuadro). Los tiles animados se redibujan encima en
/// cada cuadro: su zona (celda + lo que sobresale) se borra y se vuelve a
/// pintar con TODOS los tiles que la tocan, en el mismo orden de siempre,
/// así el resultado es idéntico al dibujo directo.
///
/// Si en pantalla hay muchos tiles animados (niebla del cementerio, un
/// mar de lava) no conviene: dibuja directo, como antes ([direct]).
class TileLayerCache {
  TileLayerCache(this.tiles);

  final TilePainter tiles;

  /// Lado de un bloque, en tiles (256 px).
  static const chunk = 16;
  static const _ts = TilePainter.ts;
  static const _chunkPx = chunk * _ts;

  /// Bloques en memoria como mucho (~256 KB cada uno).
  static const maxChunks = 64;

  /// Con más de esta fracción de tiles animados a la vista, dibuja
  /// directo.
  static const maxAnimatedShare = 0.4;

  /// [maxAnimatedShare] de esta caché (los tests la suben para forzar la
  /// caché).
  double animatedShareLimit = maxAnimatedShare;

  GameMap? _map;
  String _theme = '';
  bool _backdrop = false;

  /// Animado por tile (`null` = sin calcular).
  List<bool?> _anim = const [];

  /// Bloques grabados, del menos al más usado.
  final _chunks = <int, ui.Image>{};

  /// Bloques grabados en total y reutilizados (diagnóstico y tests).
  int built = 0, hits = 0;

  /// El último cuadro se dibujó directo (sin caché).
  bool direct = false;

  /// Bloques en memoria (tests).
  int get cachedChunks => _chunks.length;

  void dispose() {
    for (final i in _chunks.values) {
      i.dispose();
    }
    _chunks.clear();
    _map = null;
  }

  /// Prepara la caché para [map]: si es otro mapa con las mismas medidas
  /// (un PdI abrió una sala, se encendió un brasero...) solo se tiran los
  /// bloques que tocan los tiles que cambiaron.
  void _sync(GameMap map, String theme, bool backdrop) {
    final old = _map;
    if (identical(old, map) && theme == _theme && backdrop == _backdrop) {
      return;
    }
    if (old != null &&
        theme == _theme &&
        backdrop == _backdrop &&
        old.width == map.width &&
        old.height == map.height &&
        old.lobby == map.lobby) {
      for (var y = 0; y < map.height; y++) {
        final a = old.rows[y], b = map.rows[y];
        if (identical(a, b) || a == b) continue;
        for (var x = 0; x < map.width; x++) {
          if (a.codeUnitAt(x) == b.codeUnitAt(x)) continue;
          _invalidateAround(x, y, map);
        }
      }
    } else {
      dispose();
      _anim = List<bool?>.filled(map.width * map.height, null);
    }
    _map = map;
    _theme = theme;
    _backdrop = backdrop;
  }

  /// El tile (x, y) cambió: él y sus vecinos (bordes, puentes, orillas)
  /// pueden dibujarse distinto.
  void _invalidateAround(int x, int y, GameMap map) {
    for (var yy = y - 1; yy <= y + 1; yy++) {
      for (var xx = x - 1; xx <= x + 1; xx++) {
        if (map.contains(xx, yy)) _anim[yy * map.width + xx] = null;
      }
    }
    final (l, t, r, _) = TilePainter.maxOverflow;
    final area = Rect.fromLTRB(
        (x - 1) * _ts - l, (y - 1) * _ts - t, (x + 2) * _ts + r, (y + 2) * _ts);
    _chunks.removeWhere((k, img) {
      final hit = _chunkRect(k, map).overlaps(area);
      if (hit) img.dispose();
      return hit;
    });
  }

  bool _isAnimated(GameMap map, int x, int y) {
    final i = y * map.width + x;
    return _anim[i] ??= TilePainter.animated(map.tileAt(x, y), _theme, x, y,
        lobby: map.lobby, voidBackdrop: _backdrop);
  }

  static int _key(int cx, int cy) => cy * 4096 + cx;

  static Rect _chunkRect(int key, GameMap map) {
    final cx = key % 4096, cy = key ~/ 4096;
    final left = cx * _chunkPx, top = cy * _chunkPx;
    return Rect.fromLTRB(
        left,
        top,
        (left + _chunkPx).clamp(left, map.width * _ts),
        (top + _chunkPx).clamp(top, map.height * _ts));
  }

  /// Extensión (px del mundo) del dibujo del tile (x, y).
  static Rect _extent(String ch, int x, int y) {
    final (l, t, r, b) = TilePainter.overflow(ch);
    return Rect.fromLTRB(
        x * _ts - l, y * _ts - t, (x + 1) * _ts + r, (y + 1) * _ts + b);
  }

  /// Dibuja los tiles de [map] que tocan [area] (px del mundo), en orden
  /// de filas; con [only] = `true`/`false` solo los animados / estáticos.
  void _drawTiles(Canvas c, GameMap map, Rect area,
      {bool? only,
      required double t,
      required bool gateOpen,
      required double density,
      required double pulse}) {
    final (ml, mt, mr, _) = TilePainter.maxOverflow;
    final x0 = ((area.left - mr) / _ts).floor().clamp(0, map.width);
    final x1 = ((area.right + ml) / _ts).ceil().clamp(0, map.width);
    final y0 = (area.top / _ts).floor().clamp(0, map.height);
    final y1 = ((area.bottom + mt) / _ts).ceil().clamp(0, map.height);
    String? at(int x, int y) => map.contains(x, y) ? map.tileAt(x, y) : null;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        if (only != null && _isAnimated(map, x, y) != only) continue;
        final ch = map.tileAt(x, y);
        if (!_extent(ch, x, y).overlaps(area)) continue;
        tiles.draw(c, ch, x * _ts, y * _ts, _theme, x, y,
            t: t,
            gateOpen: gateOpen,
            lobby: map.lobby,
            at: at,
            voidBackdrop: _backdrop,
            density: density,
            pulse: pulse);
      }
    }
  }

  /// Graba el bloque [key] (solo los tiles estáticos).
  ui.Image _build(int key, GameMap map) {
    final r = _chunkRect(key, map);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Offset.zero & r.size);
    c.translate(-r.left, -r.top);
    c.clipRect(r, doAntiAlias: false);
    // Los estáticos no dependen del reloj ni del estado de la sala.
    _drawTiles(c, map, r,
        only: false, t: 0, gateOpen: false, density: 1, pulse: 0);
    final pic = rec.endRecording();
    final img = pic.toImageSync(r.width.ceil(), r.height.ceil());
    pic.dispose();
    built++;
    return img;
  }

  ui.Image _chunkImage(int key, GameMap map) {
    final hit = _chunks.remove(key);
    if (hit != null) {
      hits++;
      return _chunks[key] = hit;
    }
    final img = _build(key, map);
    _chunks[key] = img;
    while (_chunks.length > maxChunks) {
      final first = _chunks.keys.first;
      _chunks.remove(first)!.dispose();
    }
    return img;
  }

  /// Dibuja los tiles de [view] (px del mundo; el lienzo ya está
  /// trasladado por la cámara). [theme] es el tema del mapa, [backdrop]
  /// si el vacío deja ver el fondo con paralaje.
  void draw(
    Canvas c,
    GameMap map,
    Rect view, {
    required String theme,
    required bool backdrop,
    required double t,
    required bool gateOpen,
    required double density,
    required double pulse,
  }) {
    _sync(map, theme, backdrop);
    final vx0 = (view.left / _ts).floor().clamp(0, map.width - 1);
    final vx1 = ((view.right - 1) / _ts).floor().clamp(0, map.width - 1);
    final vy0 = (view.top / _ts).floor().clamp(0, map.height - 1);
    final vy1 = ((view.bottom - 1) / _ts).floor().clamp(0, map.height - 1);
    // ¿Conviene la caché? Cuenta los animados a la vista.
    var anim = 0, total = 0;
    for (var y = vy0; y <= vy1; y++) {
      for (var x = vx0; x <= vx1; x++) {
        total++;
        if (_isAnimated(map, x, y)) anim++;
      }
    }
    direct = total == 0 || anim > total * animatedShareLimit;
    if (direct) {
      _drawTiles(c, map, view,
          t: t, gateOpen: gateOpen, density: density, pulse: pulse);
      return;
    }
    // Una capa propia: las zonas animadas se borran (transparente) y se
    // repintan; el fondo (o el vacío con paralaje) queda debajo.
    c.saveLayer(view, Paint());
    final cx0 = (view.left / _chunkPx).floor().clamp(0, 4095);
    final cx1 = ((view.right - 1) / _chunkPx).floor().clamp(0, 4095);
    final cy0 = (view.top / _chunkPx).floor().clamp(0, 4095);
    final cy1 = ((view.bottom - 1) / _chunkPx).floor().clamp(0, 4095);
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        if (cx * chunk >= map.width || cy * chunk >= map.height) continue;
        final key = _key(cx, cy);
        c.drawImage(
            _chunkImage(key, map), Offset(cx * _chunkPx, cy * _chunkPx), paint);
      }
    }
    // Zonas animadas: tramos seguidos de una fila (y los de más abajo que
    // sobresalen hacia la vista).
    final (_, mt, _, _) = TilePainter.maxOverflow;
    final ry1 = ((view.bottom + mt) / _ts).floor().clamp(0, map.height - 1);
    final rx0 = (vx0 - 1).clamp(0, map.width - 1);
    final rx1 = (vx1 + 1).clamp(0, map.width - 1);
    final clear = Paint()..blendMode = BlendMode.clear;
    for (var y = vy0; y <= ry1; y++) {
      var x = rx0;
      while (x <= rx1) {
        if (!_isAnimated(map, x, y)) {
          x++;
          continue;
        }
        var r = _extent(map.tileAt(x, y), x, y);
        var e = x + 1;
        while (e <= rx1 && _isAnimated(map, e, y)) {
          r = r.expandToInclude(_extent(map.tileAt(e, y), e, y));
          e++;
        }
        final zone = r.intersect(view);
        if (!zone.isEmpty) {
          c.save();
          c.clipRect(zone, doAntiAlias: false);
          c.drawRect(zone, clear);
          _drawTiles(c, map, zone,
              t: t, gateOpen: gateOpen, density: density, pulse: pulse);
          c.restore();
        }
        x = e;
      }
    }
    c.restore();
  }

  /// Graba de antemano un bloque que falte cerca de [view] (a un bloque
  /// de distancia): al caminar, los bloques ya están listos. Devuelve si
  /// grabó uno (uno por cuadro como mucho).
  bool prefetch(GameMap map, Rect view) {
    if (_map == null || !identical(_map, map) || direct) return false;
    final r = view.inflate(_chunkPx);
    final cx0 = (r.left / _chunkPx).floor().clamp(0, 4095);
    final cx1 = ((r.right - 1) / _chunkPx).floor().clamp(0, 4095);
    final cy0 = (r.top / _chunkPx).floor().clamp(0, 4095);
    final cy1 = ((r.bottom - 1) / _chunkPx).floor().clamp(0, 4095);
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        if (cx * chunk >= map.width || cy * chunk >= map.height) continue;
        final key = _key(cx, cy);
        if (_chunks.containsKey(key)) continue;
        // No desaloja los que están a la vista.
        if (_chunks.length >= maxChunks) return false;
        _chunks[key] = _build(key, map);
        return true;
      }
    }
    return false;
  }
}
