import 'dart:math' as math;

import '../data/town_layout.dart';
import '../models/game_map.dart' show Tile;
import '../models/world_save.dart';
import 'animal_rules.dart' show AnimalRules;

/// El plano del pueblo de un mundo (town_editor.md § 4): los tiles que
/// salen de `TownState` (ampliaciones por lado, construcciones, caminos
/// procedurales). Puro y determinista: el mismo estado da el mismo mapa
/// en el anfitrión y en cada cliente.
class TownPlan {
  TownPlan._(this.width, this.height, this.ox, this.oy, this.tiles,
      this.unreached);

  final int width, height;

  /// Origen del pueblo base dentro del mapa.
  final int ox, oy;
  final List<List<String>> tiles;

  /// Construcciones sin camino hasta la plaza.
  final Set<String> unreached;

  String at(int x, int y) =>
      x < 0 || y < 0 || x >= width || y >= height ? Tile.tree : tiles[y][x];

  /// Longest rail stub of the cart station (mining_smithing.md § 1.8).
  static const cartRailMax = 2;

  /// The rail stub of the cart [station] (map tiles, top row first): the
  /// rows straight south of it, at most [cartRailMax], while every tile
  /// under the station is bare grass (never over plots, builds, lakes,
  /// trees, lights or paths). It ends at the map edge (the exit side) or
  /// at the first occupied row, whichever comes first.
  /// [lights] (town lights, base-town coordinates) are not plan tiles,
  /// so they are passed in.
  List<(int, int)> cartRail(TownLandmark station,
      [Iterable<(int, int)> lights = const []]) {
    final lit = {for (final (x, y) in lights) (x + ox, y + oy)};
    final out = <(int, int)>[];
    final x0 = station.x + ox;
    for (var k = 0; k < cartRailMax; k++) {
      final y = station.y + station.h + oy + k;
      final row = [
        for (var x = x0; x < x0 + station.w; x++) (x, y),
      ];
      if (row.any((p) => at(p.$1, p.$2) != Tile.grass || lit.contains(p))) {
        break;
      }
      out.addAll(row);
    }
    return out;
  }

  static int widthOf(TownState s) =>
      TownLayout.width +
      kTownStrip * (s.side(TownSide.este) + s.side(TownSide.oeste));
  static int heightOf(TownState s) =>
      TownLayout.height +
      kTownStrip * (s.side(TownSide.norte) + s.side(TownSide.sur));

  /// Los lugares del pueblo en su posición de este mundo (coordenadas del
  /// pueblo base; town_editor.md § 3.3): los movidos donde los dejó el
  /// dueño, el resto en su lugar de siempre. Mismo orden que
  /// `TownLayout.landmarks` (la prioridad de las etiquetas).
  ///
  /// La ARMERÍA y el TALLER DE OFICIOS (v0.32.3, `TownLayout.lateSpots`)
  /// llegaron después: en un pueblo guardado antes, si su lugar de
  /// siempre ya está ocupado (una construcción, un faro, otro lugar
  /// movido), sin marca propia van al hueco libre más cercano
  /// (town_editor.md § 3.3).
  ///
  /// Memorizado (exploration.md § "Rendimiento"): con un lugar tardío
  /// tapado, ubicarlo recorre todo el pueblo, y esto se pide decenas de
  /// veces por cuadro (carteles, cofres, pescadores, avisos). Por
  /// instancia de [TownState] (es inmutable) y, si llega otra con el
  /// mismo plano (cambió una parcela o un cofre), por su clave.
  static List<TownLandmark> landmarksOf(TownState s) {
    final hit = _landmarks[s];
    if (hit != null) return hit;
    final key = _layoutKey(s);
    final byKey = _landmarksByKey[key];
    if (byKey != null) return _landmarks[s] = byKey;
    if (_landmarksByKey.length > 16) _landmarksByKey.clear();
    return _landmarks[s] = _landmarksByKey[key] = _computeLandmarks(s);
  }

  static final _landmarks = Expando<List<TownLandmark>>('lugares');
  static final _landmarksByKey = <String, List<TownLandmark>>{};
  static final _reserved = Expando<List<TownRect>>('reservado');

  /// Lo que mueve los lugares: lados, marcas, construcciones y faros.
  static String _layoutKey(TownState s) => [
        for (final v in TownSide.values) s.side(v),
        for (final e in s.marks.entries) '${e.key}:${e.value.$1}.${e.value.$2}',
        for (final b in s.builds)
          '${b.id}:${b.kind.name}:${b.parts.map((p) => p.toJson().join('.')).join('/')}',
        for (final (x, y) in s.lights) 'f$x.$y',
      ].join(',');

  static List<TownLandmark> _computeLandmarks(TownState s) {
    var raw = _rawLandmarks(s);
    for (final spot in TownLayout.lateSpots) {
      final i = raw.indexWhere((l) => l.spot == spot);
      final def = raw[i];
      if (s.marks.containsKey(def.id)) continue;
      if (!_blocked(s, raw, def.x, def.y, def)) continue;
      final (x, y) = _freeSpot(s, raw, def);
      raw = [...raw]..[i] = def.at(x, y);
    }
    return raw;
  }

  static List<TownLandmark> _rawLandmarks(TownState s) => s.marks.isEmpty
      ? TownLayout.landmarks
      : [
          for (final l in TownLayout.landmarks)
            if (s.marks[l.id] case (final x, final y)) l.at(x, y) else l,
        ];

  /// ¿El lugar [l] con su esquina en ([x], [y]) pisa algo de [s]?
  static bool _blocked(
      TownState s, List<TownLandmark> raw, int x, int y, TownLandmark l) {
    final r = TownRect(x, y, l.w, l.h);
    final (ox, oy) = s.origin;
    if (x + ox < 2 ||
        y + oy < 2 ||
        r.right + ox > widthOf(s) - 2 ||
        r.bottom + oy > heightOf(s) - 2) {
      return true;
    }
    for (final o in raw) {
      if (o.spot == l.spot) continue;
      if (TownRect(o.x, o.y, o.w, o.h).inflate(1).overlaps(r)) return true;
    }
    for (final p in _fixedPathsOf(s, raw)) {
      if (p.overlaps(r)) return true;
    }
    for (final b in s.builds) {
      if (b.parts.any((p) => p.inflate(2).overlaps(r))) return true;
    }
    for (final (tx, ty) in [...TownLayout.trees, ...s.lights]) {
      if (r.contains(tx, ty)) return true;
    }
    return false;
  }

  /// El hueco libre más cercano a la posición de siempre de [l] (o esa
  /// misma si no hay ninguno).
  static (int, int) _freeSpot(
      TownState s, List<TownLandmark> raw, TownLandmark l) {
    final (ox, oy) = s.origin;
    (int, int)? best;
    var bd = 1 << 30;
    for (var y = 2 - oy; y + l.h + oy <= heightOf(s) - 2; y++) {
      for (var x = 2 - ox; x + l.w + ox <= widthOf(s) - 2; x++) {
        final d = (x - l.x).abs() + (y - l.y).abs();
        if (d >= bd || _blocked(s, raw, x, y, l)) continue;
        (bd, best) = (d, (x, y));
      }
    }
    return best ?? (l.x, l.y);
  }

  /// El lugar [spot] en este mundo.
  static TownLandmark landmarkOf(TownState s, TownSpot spot) =>
      landmarksOf(s).firstWhere((l) => l.spot == spot);

  /// ¿Algún lugar quedó fuera de su posición de siempre? Con todo en su
  /// lugar el plano es el de siempre (caminos fijos completos); si no,
  /// solo queda fijo el anillo de la fuente con su eje al sur y cada lugar
  /// se conecta por un camino procedural (§ 4.1).
  static bool rearranged(TownState s) {
    for (final l in TownLayout.landmarks) {
      final m = s.marks[l.id];
      if (m != null && m != (l.x, l.y)) return true;
    }
    return false;
  }

  /// Caminos fijos (coordenadas del pueblo base; el eje norte-sur sigue
  /// hasta el borde sur del mapa). Sin lugares movidos, los de siempre;
  /// con alguno movido, el anillo de la fuente (la plaza, el centro de la
  /// red) y su eje al sur, donde esté la fuente.
  static List<TownRect> fixedPaths(TownState s) =>
      _fixedPathsOf(s, _rawLandmarks(s));

  static List<TownRect> _fixedPathsOf(
      TownState s, List<TownLandmark> marks) {
    final south = heightOf(s) - s.origin.$2;
    if (!rearranged(s)) {
      return [
        const TownRect(3, 5, 28, 1),
        TownRect(16, 5, 2, south - 5),
        const TownRect(14, 8, 6, 6),
        const TownRect(11, 16, 16, 1),
      ];
    }
    final f = marks.firstWhere((l) => l.spot == TownSpot.fountain);
    return [
      TownRect(f.x - 2, f.y - 2, 6, 6),
      TownRect(f.x, f.y + 4, 2, math.max(0, south - f.y - 4)),
    ];
  }

  /// Lugares (con un tile de margen) y caminos fijos: ahí no se construye.
  static List<TownRect> reserved(TownState s) => _reserved[s] ??=
      List.unmodifiable([
        for (final l in landmarksOf(s))
          TownRect(l.x, l.y, l.w, l.h).inflate(1),
        ...fixedPaths(s),
      ]);

  /// El cartel de [b]: el primer lugar de `signSpots` que no pisa un
  /// camino fijo, un lugar ni otra construcción (si ninguno, el primero).
  static (int, int) signOf(TownState s, TownBuild b) {
    final res = reserved(s);
    for (final (x, y) in b.signSpots) {
      final r = TownRect(x, y, 1, 1);
      if (res.any((o) => o.overlaps(r))) continue;
      if (s.builds.any((o) => o.contains(x, y))) continue;
      return (x, y);
    }
    return b.signSpots.first;
  }

  static final _cache = <String, TownPlan>{};

  /// Lo que cambia el plano (no las parcelas ni los peces).
  static String keyOf(TownState s) => [
        for (final v in TownSide.values) s.side(v),
        for (final l in landmarksOf(s)) '${l.id}:${l.x}.${l.y}',
        for (final b in s.builds)
          '${b.id}:${b.kind.name}:${b.parts.map((p) => p.toJson().join('.')).join('/')}',
      ].join(',');

  static TownPlan of(TownState s) {
    final key = keyOf(s);
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 16) _cache.clear();
    return _cache[key] = _build(s);
  }

  static int _hash(int x, int y) {
    var h = x * 374761393 + y * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  static TownPlan _build(TownState s) {
    final w = widthOf(s), h = heightOf(s);
    final (ox, oy) = s.origin;
    final t = [
      for (var y = 0; y < h; y++)
        [
          for (var x = 0; x < w; x++)
            x <= 1 || y == 0 || x >= w - 2 || y == h - 1
                ? Tile.tree
                : Tile.grass,
        ],
    ];
    void put(TownRect r, String c) {
      for (var y = r.y; y < r.bottom; y++) {
        for (var x = r.x; x < r.right; x++) {
          final mx = x + ox, my = y + oy;
          if (mx >= 0 && my >= 0 && mx < w && my < h) t[my][mx] = c;
        }
      }
    }

    for (final (x, y) in TownLayout.trees) {
      t[y + oy][x + ox] = Tile.tree;
    }
    for (final p in fixedPaths(s)) {
      put(p, Tile.path);
    }
    // Construcciones: huertas de tierra; lagos de agua con orilla
    // orgánica (esquinas de pasto y, si se fusionaron, mordiscos).
    for (final b in s.builds) {
      if (b.kind.ranch) {
        // Coop / barn (animals.md § 3): solid house, walkable fenced yard.
        for (final p in b.parts) {
          put(p, Tile.grass);
        }
        put(AnimalRules.houseOf(b), Tile.house);
        continue;
      }
      final water = b.kind == BuildKind.lago;
      for (final p in b.parts) {
        put(
            p,
            water
                ? Tile.water
                : b.kind == BuildKind.casa
                    ? Tile.house
                    : Tile.soil);
      }
      if (!water) continue;
      bool inLake(int x, int y) => b.contains(x, y);
      bool edge(int x, int y) =>
          !inLake(x - 1, y) || !inLake(x + 1, y) ||
          !inLake(x, y - 1) || !inLake(x, y + 1);
      final bites = <(int, int)>[];
      for (final p in b.parts) {
        for (final (cx, cy, dx, dy) in [
          (p.x, p.y, 1, 1),
          (p.right - 1, p.y, -1, 1),
          (p.x, p.bottom - 1, 1, -1),
          (p.right - 1, p.bottom - 1, -1, -1),
        ]) {
          final outX = !inLake(cx - dx, cy), outY = !inLake(cx, cy - dy);
          if (outX && outY) {
            bites.add((cx, cy));
            if (b.parts.length > 1 && _hash(cx, cy) % 2 == 0) {
              bites.add((cx + dx, cy));
              bites.add((cx, cy + dy));
            }
          }
        }
      }
      for (final (x, y) in bites) {
        if (edge(x, y)) put(TownRect(x, y, 1, 1), Tile.grass);
      }
      // Muelles: en la orilla de cada parte (town_editor.md § 4.3).
      for (final p in b.parts) {
        for (final (x, y) in [
          (p.right - 1, p.y + 1),
          (p.right - 1, p.bottom - 2),
          (p.x + 3, p.y),
        ]) {
          final mx = x + ox, my = y + oy;
          if (mx < 0 || my < 0 || mx >= w || my >= h) continue;
          if (t[my][mx] != Tile.water || !edge(x, y)) continue;
          put(TownRect(x, y, 1, 1), Tile.fishing);
        }
      }
    }
    for (final b in s.builds) {
      final (sx, sy) = signOf(s, b);
      put(TownRect(sx, sy, 1, 1), Tile.sign);
    }
    final marks = landmarksOf(s);
    for (final l in marks) {
      put(TownRect(l.x, l.y, l.w, l.h), l.tile);
    }
    // Caminos procedurales: con lugares movidos, primero cada lugar (en
    // orden) hasta la red que sale de la fuente; después cada
    // construcción al camino más cercano.
    final unreached = <String>{};
    if (rearranged(s)) {
      for (final l in marks) {
        if (l.spot == TownSpot.fountain) continue;
        final r = TownRect(l.x, l.y, l.w, l.h);
        if (!_connect(t, w, h, r, r.contains, ox, oy)) unreached.add(l.id);
      }
    }
    for (final b in s.builds) {
      if (!_connect(t, w, h, b.bounds, b.contains, ox, oy)) {
        unreached.add(b.id);
      }
    }
    return TownPlan._(w, h, ox, oy, t, unreached);
  }

  /// Dijkstra desde los tiles al lado de lo que ocupa [bb] ([inside])
  /// hasta cualquier camino; pinta el recorrido. `false` si no hay forma
  /// de llegar.
  static bool _connect(List<List<String>> t, int w, int h, TownRect bb,
      bool Function(int, int) inside, int ox, int oy) {
    bool open(int x, int y) =>
        x >= 0 && y >= 0 && x < w && y < h &&
        (t[y][x] == Tile.grass || t[y][x] == Tile.path);
    final starts = <int>[];
    for (var y = bb.y - 1; y <= bb.bottom; y++) {
      for (var x = bb.x - 1; x <= bb.right; x++) {
        if (inside(x, y)) continue;
        final near = inside(x - 1, y) || inside(x + 1, y) ||
            inside(x, y - 1) || inside(x, y + 1);
        final mx = x + ox, my = y + oy;
        if (!near || !open(mx, my)) continue;
        if (t[my][mx] == Tile.path) return true;
        starts.add(my * w + mx);
      }
    }
    if (starts.isEmpty) return false;
    final dist = List<int>.filled(w * h, 1 << 30);
    final prev = List<int>.filled(w * h, -1);
    final heap = _Heap();
    for (final s in starts) {
      dist[s] = 0;
      heap.push(0, s);
    }
    while (heap.isNotEmpty) {
      final (d, i) = heap.pop();
      if (d > dist[i]) continue;
      final x = i % w, y = i ~/ w;
      if (t[y][x] == Tile.path) {
        var k = prev[i];
        while (k >= 0) {
          t[k ~/ w][k % w] = Tile.path;
          k = prev[k];
        }
        return true;
      }
      for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
        if (!open(nx, ny)) continue;
        final j = ny * w + nx;
        final nd = d + 4 + _hash(nx, ny) % 3;
        if (nd < dist[j]) {
          dist[j] = nd;
          prev[j] = i;
          heap.push(nd, j);
        }
      }
    }
    return false;
  }
}

class _Heap {
  final _k = <int>[], _v = <int>[];
  bool get isNotEmpty => _k.isNotEmpty;

  void push(int k, int v) {
    _k.add(k);
    _v.add(v);
    var i = _k.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_k[p] <= _k[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  (int, int) pop() {
    final out = (_k.first, _v.first);
    final lk = _k.removeLast(), lv = _v.removeLast();
    if (_k.isNotEmpty) {
      _k[0] = lk;
      _v[0] = lv;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _k.length && _k[l] < _k[m]) m = l;
        if (r < _k.length && _k[r] < _k[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return out;
  }

  void _swap(int a, int b) {
    final k = _k[a], v = _v[a];
    _k[a] = _k[b];
    _v[a] = _v[b];
    _k[b] = k;
    _v[b] = v;
  }
}
