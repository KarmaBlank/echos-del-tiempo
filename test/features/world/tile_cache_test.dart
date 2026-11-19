import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/map_themes.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_cache.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Capa de tiles con caché (docs/specs/exploration.md § "Rendimiento"):
/// la clasificación estático / animado y lo que sobresale cada tile se
/// verifican dibujando de verdad, y la caché tiene que dar los mismos
/// píxeles que el dibujo directo.

const _chars = [
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
  Tile.gear,
  ...Tile.poiTiles,
  '1',
  '0',
  '?',
];

/// Posiciones con hashes variados (cada resto que usan los tiles) dentro
/// y fuera del pueblo del mapa del mundo.
final List<(int, int)> _positions = () {
  final out = <(int, int)>{(1, 0), (2, 0), (12, 3), (30, 20)};
  for (final (m, r) in [
    (2, 0),
    (3, 0),
    (4, 0),
    (4, 1),
    (5, 0),
    (5, 1),
    (6, 0),
    (7, 0),
    (9, 0),
    (10, 0),
    (11, 0),
    (17, 0),
    (3, 1),
    (3, 2),
  ]) {
    for (var i = 0; i < 4000; i++) {
      final x = 27 + i % 60, y = 15 + i ~/ 60;
      if (TilePainter.tileHash(x, y) % m == r) {
        out.add((x, y));
        break;
      }
    }
  }
  return out.toList();
}();

const _cell = 48.0, _ox = 16.0, _oy = 24.0;

/// Dibuja [ch] en cada posición, cada una en su celda de 48 px (el tile
/// en (16, 24) de la celda); los vecinos alternan suelo y vacío.
Future<Uint8List> _render(String ch, String theme,
    {required double t,
    required bool gate,
    required double density,
    required double pulse}) async {
  final w = (_cell * _positions.length).toInt(), h = _cell.toInt();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final p = TilePainter();
  final abyss = kAbyssThemes.contains(theme);
  for (var i = 0; i < _positions.length; i++) {
    final (tx, ty) = _positions[i];
    c.save();
    c.translate(i * _cell + _ox - tx * 16, _oy - ty * 16);
    c.clipRect(Rect.fromLTWH(tx * 16 - _ox, ty * 16 - _oy, _cell, _cell));
    p.draw(c, ch, tx * 16.0, ty * 16.0, theme, tx, ty,
        t: t,
        gateOpen: gate,
        lobby: theme == 'lobby',
        at: (x, y) => (x == tx && y == ty) ? ch : ((x + y).isEven ? '.' : '_'),
        voidBackdrop: abyss,
        density: density,
        pulse: pulse);
    c.restore();
  }
  final img = await rec.endRecording().toImage(w, h);
  final bytes = await img.toByteData();
  img.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  final themes = [...kMapThemes.keys];

  testWidgets(
      'estáticos: mismos píxeles con cualquier reloj y estado; '
      'nada fuera de lo que sobresale', (tester) async {
    await tester.runAsync(() async {
      final problems = <String>[];
      final measured = <String, (int, int, int, int)>{};
      addTearDown(() => debugPrint('sobresale: $measured'));
      for (final theme in themes) {
        for (final ch in _chars) {
          final frames = [
            await _render(ch, theme, t: 0, gate: false, density: 1, pulse: 0),
            await _render(ch, theme,
                t: 12345.6, gate: true, density: 0.3, pulse: 1),
            await _render(ch, theme,
                t: 777.7, gate: false, density: 0.6, pulse: 0.5),
            await _render(ch, theme,
                t: 3333.3, gate: true, density: 1, pulse: 0.2),
          ];
          final (l, tp, r, b) = TilePainter.overflow(ch);
          final (ml, mt, mr, mb) = TilePainter.maxOverflow;
          expect(l <= ml && tp <= mt && r <= mr && b <= mb, isTrue);
          final w = (_cell * _positions.length).toInt();
          for (var i = 0; i < _positions.length; i++) {
            final (tx, ty) = _positions[i];
            final animated = TilePainter.animated(ch, theme, tx, ty,
                lobby: theme == 'lobby',
                voidBackdrop: kAbyssThemes.contains(theme));
            var differs = false, outside = false;
            var mxl = 0, mxt = 0, mxr = 0, mxb = 0;
            for (var y = 0; y < _cell; y++) {
              for (var x = 0; x < _cell; x++) {
                final o = (y * w + (i * _cell).toInt() + x) * 4;
                final inside = x >= _ox - l &&
                    x < _ox + 16 + r &&
                    y >= _oy - tp &&
                    y < _oy + 16 + b;
                for (final f in frames) {
                  if (f[o + 3] != 0) {
                    mxl = math.max(mxl, (_ox - x).toInt());
                    mxt = math.max(mxt, (_oy - y).toInt());
                    mxr = math.max(mxr, (x - _ox - 15).toInt());
                    mxb = math.max(mxb, (y - _oy - 15).toInt());
                  }
                  if (!inside && f[o + 3] != 0) outside = true;
                  for (var k = 0; k < 4; k++) {
                    if (f[o + k] != frames[0][o + k]) differs = true;
                  }
                }
              }
            }
            if (!animated && differs) {
              problems.add('$theme "$ch" ($tx,$ty): estático pero cambia');
            }
            if (outside) {
              problems.add('$theme "$ch" ($tx,$ty): sobresale de más');
            }
            final m = measured[ch] ?? (0, 0, 0, 0);
            measured[ch] = (
              math.max(m.$1, mxl),
              math.max(m.$2, mxt),
              math.max(m.$3, mxr),
              math.max(m.$4, mxb)
            );
          }
        }
      }
      expect(problems, isEmpty, reason: problems.take(30).join('\n'));
    });
  });

  /// Un mapa con todos los tiles mezclados (semilla fija). Con
  /// [circles] en `false`, sin lo que dibuja círculos (árboles,
  /// engranajes, muros de pradera / bosque / mundo).
  GameMap randomMap(String theme,
      {int w = 70, int h = 50, int seed = 7, bool circles = true}) {
    final rnd = math.Random(seed);
    const round = {
      Tile.tree,
      Tile.gear,
      Tile.wall,
      Tile.secretFloor,
      Tile.cracked,
      Tile.shortcut
    };
    // Más suelo y pasto que el resto, como un mapa real.
    final pool = [
      for (var i = 0; i < 12; i++) Tile.floor,
      for (var i = 0; i < 6; i++) Tile.grass,
      for (var i = 0; i < 4; i++) Tile.wall,
      ..._chars,
    ]..removeWhere((c) => !circles && round.contains(c));
    return GameMap(
      width: w,
      height: h,
      rows: [
        for (var y = 0; y < h; y++)
          String.fromCharCodes([
            for (var x = 0; x < w; x++)
              pool[rnd.nextInt(pool.length)].codeUnitAt(0)
          ]),
      ],
      theme: theme,
      spawn: const WorldPoint(0, 0),
      lobby: theme == 'lobby',
    );
  }

  Future<Uint8List> frame(GameMap map, Rect view,
      {TileLayerCache? cache, double t = 1000}) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & view.size, Paint()..color = kMapBackground);
    c.translate(-view.left, -view.top);
    final abyss = kAbyssThemes.contains(map.theme);
    final layer = cache ??
        (TileLayerCache(TilePainter())..animatedShareLimit = -1); // directo
    layer.draw(c, map, view,
        theme: map.theme,
        backdrop: abyss,
        t: t,
        gateOpen: false,
        density: 1,
        pulse: 0.4);
    final img = await rec
        .endRecording()
        .toImage(view.width.toInt(), view.height.toInt());
    final b = await img.toByteData();
    img.dispose();
    return b!.buffer.asUint8List();
  }

  /// Píxeles distintos (algún canal > 2) entre [a] y [b], y la mayor
  /// diferencia.
  (int, int) diff(Uint8List a, Uint8List b) {
    var maxDiff = 0, bad = 0;
    for (var i = 0; i < a.length; i += 4) {
      var px = 0;
      for (var k = 0; k < 4; k++) {
        px = math.max(px, (a[i + k] - b[i + k]).abs());
      }
      maxDiff = math.max(maxDiff, px);
      if (px > 2) bad++;
    }
    return (bad, maxDiff);
  }

  const views = [
    Rect.fromLTWH(37, 21, 480, 288),
    Rect.fromLTWH(250, 260, 480, 288),
    Rect.fromLTWH(0, 0, 480, 288),
  ];

  testWidgets('caché = dibujo directo, en todos los temas', (tester) async {
    await tester.runAsync(() async {
      for (final theme in themes) {
        for (final circles in [false, true]) {
          final map = randomMap(theme, circles: circles);
          final cache = TileLayerCache(TilePainter())..animatedShareLimit = 1;
          for (final view in views) {
            for (final t in [0.0, 5000.0]) {
              final a = await frame(map, view, t: t);
              final b = await frame(map, view, cache: cache, t: t);
              expect(cache.direct, isFalse);
              final (bad, maxDiff) = diff(a, b);
              if (circles) {
                // Los círculos sin suavizado cambian algún píxel del borde
                // según dónde se dibujan (igual que al mover la cámara).
                expect(bad, lessThan(40), reason: '$theme $view t=$t');
              } else {
                // Componer la capa puede redondear ±1 lo semitransparente.
                expect(maxDiff, lessThanOrEqualTo(2),
                    reason: '$theme $view t=$t');
              }
            }
          }
          cache.dispose();
        }
      }
    });
  });

  testWidgets(
      'bloques: se graban una vez, se reutilizan y solo se tiran '
      'los que tocan un tile que cambió', (tester) async {
    await tester.runAsync(() async {
      final map = randomMap('pradera', w: 80, h: 60);
      final cache = TileLayerCache(TilePainter())..animatedShareLimit = 1;
      const view = Rect.fromLTWH(20, 20, 480, 288);
      await frame(map, view, cache: cache);
      final first = cache.built;
      expect(first, greaterThan(0));
      expect(cache.hits, 0);
      await frame(map, view, cache: cache, t: 2000);
      expect(cache.built, first, reason: 'mismo mapa: sin regrabar');
      expect(cache.hits, first);
      // Grabar de antemano: uno por llamada, alrededor de la vista.
      expect(cache.prefetch(map, view), isTrue);
      expect(cache.built, first + 1);
      // Cambia un tile (un PdI usado): solo su bloque.
      final rows = [...map.rows];
      rows[3] = '${rows[3].substring(0, 3)}:${rows[3].substring(4)}';
      final changed = GameMap(
          width: map.width,
          height: map.height,
          rows: rows,
          theme: map.theme,
          spawn: map.spawn);
      final before = cache.cachedChunks;
      await frame(changed, view, cache: cache);
      expect(cache.cachedChunks, before);
      expect(cache.built, first + 2);
      // Otro mapa (otra zona): empieza de cero.
      await frame(randomMap('bosque'), view, cache: cache);
      expect(cache.cachedChunks, lessThanOrEqualTo(first));
      cache.dispose();
      expect(cache.cachedChunks, 0);
    });
  });

  test('muchos animados a la vista: dibuja directo', () {
    final map = GameMap(
        width: 40,
        height: 30,
        rows: [for (var y = 0; y < 30; y++) Tile.water * 40],
        theme: 'pradera',
        spawn: const WorldPoint(0, 0));
    final cache = TileLayerCache(TilePainter());
    final rec = ui.PictureRecorder();
    cache.draw(Canvas(rec), map, const Rect.fromLTWH(0, 0, 480, 288),
        theme: 'pradera',
        backdrop: false,
        t: 0,
        gateOpen: false,
        density: 1,
        pulse: 0);
    rec.endRecording().dispose();
    expect(cache.direct, isTrue);
    expect(cache.built, 0);
  });
}
