import 'dart:math' as math;

import '../data/exploration_catalog.dart';
import '../models/exploration.dart';
import '../models/game_map.dart';
import '../models/zone_def.dart';
import 'mulberry32.dart';

/// Lo que agrega [PoiGenerator] a un piso (coordenadas locales del piso;
/// ids locales `k`, el atlas los pasa a `piso × 100 + k`).
class PoiLayout {
  const PoiLayout({
    this.pois = const [],
    this.quests = const [],
    this.chestSpots = const [],
    this.reserved = const [],
    this.area = 0,
  });

  final List<MapPoi> pois;
  final List<FloorQuest> quests;
  final List<(int, int)> chestSpots;

  /// Huella de las salas secretas (no se vuelven vacío ni tienen spots).
  final List<TileRect> reserved;

  /// Tiles caminables del piso (antes de poner los objetos).
  final int area;
}

/// Puntos de interés, lugares de cofre y misiones opcionales de un piso
/// (docs/specs/worldgen.md § 11). Función pura de la semilla del piso.
abstract final class PoiGenerator {
  static const _dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  /// Pone todo sobre [t] (filas mutables del piso). [passable]: caminable
  /// sin caerse. [abyss]: el vacío cuenta como masa sólida para las salas.
  static PoiLayout place(
    List<List<String>> t, {
    required int seed,
    required ZoneGen gen,
    required TileRect arena,
    required List<TileRect> vaults,
    required (int, int) spawn,
    required (int, int)? stairsDown,
    required (int, int)? stairsUp,
    required List<(int, int)> marks,
    required bool last,
    required bool Function(String) passable,
  }) {
    final h = t.length, w = t.first.length;
    final r = mulberry32((seed ^ 0x9E37) | 0);
    int ri(int a, int b) => a + (r() * (b - a + 1)).floor();
    final abyss = gen.abyss;
    final maze = gen == ZoneGen.laberinto;
    bool inb(int x, int y) => x >= 1 && y >= 1 && x < w - 1 && y < h - 1;
    String at(int x, int y) =>
        x >= 0 && y >= 0 && x < w && y < h ? t[y][x] : Tile.wall;
    bool inRect(TileRect q, int x, int y) =>
        x >= q.x && y >= q.y && x < q.x + q.w && y < q.y + q.h;
    TileRect grow(TileRect q, int m) =>
        TileRect(q.x - m, q.y - m, q.w + 2 * m, q.h + 2 * m);
    int cheb((int, int) a, (int, int) b) =>
        math.max((a.$1 - b.$1).abs(), (a.$2 - b.$2).abs());

    Map<int, int> bfs(Iterable<(int, int)> from) {
      final d = <int, int>{};
      final q = <(int, int)>[];
      for (final p in from) {
        final k = p.$2 * w + p.$1;
        if (d.containsKey(k)) continue;
        d[k] = 0;
        q.add(p);
      }
      for (var i = 0; i < q.length; i++) {
        final (x, y) = q[i];
        final dv = d[y * w + x]!;
        for (final (dx, dy) in _dirs) {
          final nx = x + dx, ny = y + dy;
          if (!inb(nx, ny) || !passable(at(nx, ny))) continue;
          if (d.containsKey(ny * w + nx)) continue;
          d[ny * w + nx] = dv + 1;
          q.add((nx, ny));
        }
      }
      return d;
    }

    final fromSpawn = bfs([spawn]);
    final area = fromSpawn.length;
    final noGo = [grow(arena, 2), for (final v in vaults) grow(v, 1)];
    final stairs = [if (stairsDown != null) stairsDown, if (stairsUp != null) stairsUp];
    final pois = <MapPoi>[];
    final reserved = <TileRect>[];
    var k = 0;

    // ---- salas secretas ----
    bool mass(int x, int y) {
      final c = at(x, y);
      return c == Tile.wall || (abyss && c == Tile.voidTile);
    }

    final nSecret = 1 + (area >= kSecondSecretArea ? 1 : 0);
    for (var s = 0; s < nSecret; s++) {
      if (r() >= kSecretChance) continue;
      final cands = <(int, int, int, int)>[];
      for (var y = 1; y < h - 1; y++) {
        for (var x = 1; x < w - 1; x++) {
          if (at(x, y) != Tile.wall && !(abyss && at(x, y) == Tile.voidTile)) {
            continue;
          }
          (int, int)? dir;
          var n = 0;
          for (final (dx, dy) in _dirs) {
            if (fromSpawn.containsKey((y + dy) * w + x + dx)) {
              n++;
              dir = (-dx, -dy);
            }
          }
          if (n != 1 || dir == null) continue;
          if (cheb((x, y), spawn) < 6) continue;
          if (stairs.any((q) => cheb((x, y), q) < 6)) continue;
          cands.add((x, y, dir.$1, dir.$2));
        }
      }
      for (var tries = 0; tries < 300 && cands.isNotEmpty; tries++) {
        final (x, y, dx, dy) = cands[ri(0, cands.length - 1)];
        // Interior: 3 de fondo (en la dirección) × 4 de ancho.
        final px = dy, py = dx; // perpendicular
        final inner = <(int, int)>[];
        for (var d = 1; d <= 3; d++) {
          for (var o = -1; o <= 2; o++) {
            inner.add((x + dx * d + px * o, y + dy * d + py * o));
          }
        }
        final foot = <(int, int)>[];
        for (var d = 0; d <= 4; d++) {
          for (var o = -2; o <= 3; o++) {
            foot.add((x + dx * d + px * o, y + dy * d + py * o));
          }
        }
        final ok = foot.every((p) =>
            inb(p.$1, p.$2) &&
            (p == (x, y) || mass(p.$1, p.$2)) &&
            !fromSpawn.containsKey(p.$2 * w + p.$1) &&
            !noGo.any((q) => inRect(q, p.$1, p.$2)) &&
            !reserved.any((q) => inRect(grow(q, 1), p.$1, p.$2)));
        if (!ok) continue;
        for (final p in foot) {
          t[p.$2][p.$1] = Tile.wall;
        }
        for (final p in inner) {
          t[p.$2][p.$1] = Tile.secretFloor;
        }
        t[y][x] = Tile.cracked;
        int lo(Iterable<int> v) => v.reduce(math.min);
        final ix = lo(inner.map((p) => p.$1)), iy = lo(inner.map((p) => p.$2));
        final fx = lo(foot.map((p) => p.$1)), fy = lo(foot.map((p) => p.$2));
        final room = TileRect(ix, iy, dx == 0 ? 4 : 3, dx == 0 ? 3 : 4);
        reserved.add(TileRect(fx, fy, dx == 0 ? 6 : 5, dx == 0 ? 5 : 6));
        pois.add(MapPoi(
            id: k++,
            kind: PoiKind.secret,
            tx: x,
            ty: y,
            room: room,
            chest: (x + dx * 2, y + dy * 2)));
        break;
      }
    }

    // ---- atajo (no en abismo: el muro ahí es vacío) ----
    if (!abyss) {
      (int, int, (int, int), int)? best;
      for (var y = 1; y < h - 1; y++) {
        for (var x = 1; x < w - 1; x++) {
          if (at(x, y) != Tile.wall) continue;
          if (noGo.any((q) => inRect(q, x, y)) ||
              reserved.any((q) => inRect(grow(q, 1), x, y))) {
            continue;
          }
          for (final (dx, dy) in const [(1, 0), (0, 1)]) {
            final a = fromSpawn[(y - dy) * w + x - dx];
            final b = fromSpawn[(y + dy) * w + x + dx];
            if (a == null || b == null) continue;
            // Los otros dos vecinos, muro (un paso de 1 tile de grosor).
            if (at(x + dy, y + dx) != Tile.wall ||
                at(x - dy, y - dx) != Tile.wall) {
              continue;
            }
            final save = (a - b).abs();
            if (save < kShortcutMinSaving) continue;
            if (best == null || save > best.$4) {
              final far = a > b ? (x - dx, y - dy) : (x + dx, y + dy);
              best = (x, y, far, save);
            }
          }
        }
      }
      if (best != null) {
        t[best.$2][best.$1] = Tile.shortcut;
        pois.add(MapPoi(
            id: k++,
            kind: PoiKind.shortcut,
            tx: best.$1,
            ty: best.$2,
            side: best.$3));
      }
    }

    // ---- objetos sueltos (un tile sólido rodeado de suelo) ----
    final objects = <(int, int)>[
      for (final p in pois) (p.tx, p.ty),
    ];
    bool open8(int x, int y) {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final c = at(x + dx, y + dy);
          if (c != Tile.floor && c != Tile.path) return false;
        }
      }
      return true;
    }

    bool freeFor(int x, int y, {int minSpawn = 8, int gap = 6}) =>
        open8(x, y) &&
        !noGo.any((q) => inRect(q, x, y)) &&
        cheb((x, y), spawn) >= minSpawn &&
        !stairs.any((q) => cheb((x, y), q) < 4) &&
        !objects.any((o) => cheb((x, y), o) < gap) &&
        !marks.any((o) => cheb((x, y), o) < 3);

    List<(int, int)> openTiles({int minSpawn = 8, int gap = 6}) => [
          for (var y = 1; y < h - 1; y++)
            for (var x = 1; x < w - 1; x++)
              if (fromSpawn.containsKey(y * w + x) &&
                  freeFor(x, y, minSpawn: minSpawn, gap: gap))
                (x, y),
        ];

    (int, int)? randomOpen() {
      final c = openTiles();
      return c.isEmpty ? null : c[ri(0, c.length - 1)];
    }

    void put((int, int) p, String tile, PoiKind kind,
        {int variant = 0, int? quest}) {
      t[p.$2][p.$1] = tile;
      objects.add(p);
      pois.add(MapPoi(
          id: k++, kind: kind, tx: p.$1, ty: p.$2, variant: variant, quest: quest));
    }

    if (r() < kShrineChance) {
      final p = randomOpen();
      if (p != null) {
        put(p, Tile.shrine, PoiKind.shrine,
            variant: ri(0, BlessingKind.values.length - 1));
      }
    }

    // ---- piedras de paso ----
    if (area >= kWaystoneArea) {
      final n = area >= kThirdWaystoneArea ? 3 : 2;
      final near = [
        for (final p in openTiles(minSpawn: 2, gap: 6))
          if (cheb(p, spawn) <= 5) p,
      ];
      if (near.isNotEmpty) {
        final first = near[ri(0, near.length - 1)];
        final stones = [first];
        put(first, Tile.waystone, PoiKind.waystone);
        while (stones.length < n) {
          final d = bfs([
            for (final s in stones)
              for (final (dx, dy) in _dirs)
                if (passable(at(s.$1 + dx, s.$2 + dy))) (s.$1 + dx, s.$2 + dy),
          ]);
          (int, int)? bestP;
          var bestD = -1;
          for (final p in openTiles()) {
            final dv = d[p.$2 * w + p.$1] ?? -1;
            if (dv > bestD) {
              bestD = dv;
              bestP = p;
            }
          }
          if (bestP == null || bestD < 25) break;
          stones.add(bestP);
          put(bestP, Tile.waystone, PoiKind.waystone);
        }
      }
    }

    if (area >= kWindArea && r() < kWindChance) {
      final p = randomOpen();
      if (p != null) put(p, Tile.wind, PoiKind.wind);
    }

    // ---- misiones opcionales ----
    final quests = <FloorQuest>[];
    final pool = <QuestKind>[
      QuestKind.braseros,
      QuestKind.reliquia,
      if (!last) QuestKind.guardian,
      QuestKind.limpieza,
      if (pois.any((p) => p.kind == PoiKind.secret)) QuestKind.secreto,
      QuestKind.cofres,
    ];
    QuestReward reward() {
      final total = kQuestRewardWeights.values.fold(0.0, (a, b) => a + b);
      var x = r() * total;
      for (final e in kQuestRewardWeights.entries) {
        x -= e.value;
        if (x < 0) return e.key;
      }
      return QuestReward.arma;
    }

    final nq = 1 + (area >= kSecondQuestArea ? 1 : 0);
    while (quests.length < nq && pool.isNotEmpty) {
      final kind = pool.removeAt(ri(0, pool.length - 1));
      final qid = 50 + quests.length;
      switch (kind) {
        case QuestKind.braseros:
          final got = <(int, int)>[];
          final c = openTiles();
          for (var tries = 0;
              tries < 200 && got.length < kBraziers && c.isNotEmpty;
              tries++) {
            final p = c[ri(0, c.length - 1)];
            if (got.any((g) => cheb(g, p) < 10)) continue;
            got.add(p);
          }
          if (got.length < kBraziers) continue;
          for (final p in got) {
            put(p, Tile.brazier, PoiKind.brazier, quest: qid);
          }
          quests.add(FloorQuest(
              id: qid, kind: kind, target: kBraziers, reward: reward()));
        case QuestKind.reliquia:
          final far = [
            for (final e in fromSpawn.entries)
              if ((at(e.key % w, e.key ~/ w) == Tile.floor ||
                      at(e.key % w, e.key ~/ w) == Tile.path) &&
                  !noGo.any((q) => inRect(q, e.key % w, e.key ~/ w)) &&
                  !objects.any((o) => cheb(o, (e.key % w, e.key ~/ w)) < 3))
                (e.key % w, e.key ~/ w, e.value),
          ]..sort((a, b) => b.$3.compareTo(a.$3));
          if (far.isEmpty) continue;
          final top = math.max(1, far.length ~/ 5);
          final (x, y, _) = far[ri(0, top - 1)];
          objects.add((x, y));
          pois.add(MapPoi(
              id: k++, kind: PoiKind.relic, tx: x, ty: y, quest: qid));
          quests.add(FloorQuest(id: qid, kind: kind, target: 1, reward: reward()));
        case QuestKind.guardian || QuestKind.secreto:
          quests.add(FloorQuest(id: qid, kind: kind, target: 1, reward: reward()));
        case QuestKind.limpieza || QuestKind.cofres:
          // El total lo sabe la sesión (grupos / cofres del piso).
          quests.add(FloorQuest(id: qid, kind: kind, target: 0, reward: reward()));
      }
    }

    // ---- lugares de cofre: punto más lejano a todo PdI ----
    final reach = bfs([spawn]);
    final chests = <(int, int)>[];
    List<(int, int)> sources() => [
          spawn,
          if (stairsUp != null) stairsUp,
          (arena.cx, arena.cy),
          ...marks,
          ...chests,
          for (final p in pois)
            if (p.kind == PoiKind.relic)
              (p.tx, p.ty)
            else
              for (final (dx, dy) in _dirs)
                if (reach.containsKey((p.ty + dy) * w + p.tx + dx))
                  (p.tx + dx, p.ty + dy),
        ];
    bool chestOk(int x, int y, {int minN = 3}) {
      final c = at(x, y);
      // Relajado (pisos chicos): también sobre un puente (el cofre es un
      // objeto, no un tile: no corta el paso).
      if (c != Tile.floor &&
          c != Tile.path &&
          !(minN < 3 && c == Tile.bridge)) {
        return false;
      }
      if (noGo.any((q) => inRect(q, x, y))) return false;
      var n = 0;
      for (final (dx, dy) in _dirs) {
        if (passable(at(x + dx, y + dy))) n++;
      }
      return n >= minN;
    }

    final gap = maze ? kMaxPoiGapMaze : kMaxPoiGap;
    final cap = math.max(kMinChestSpots, area ~/ kChestSpotArea);
    // v0.20.22 (worldgen.md § 6.8): en los pisos chicos el tope por área
    // no alcanza para la regla de § 11.2; se sigue (hasta 3× el tope)
    // mientras quede un tile a más de [gap] o falte densidad.
    bool dense() => (chests.length + pois.length) * kPoiDensityArea >= reach.length;
    while (chests.length < cap * 3) {
      final d = bfs(sources().where((p) => reach.containsKey(p.$2 * w + p.$1)));
      var maxD = 0, maxK = -1;
      for (final e in d.entries) {
        if (reach.containsKey(e.key) && e.value > maxD) {
          maxD = e.value;
          maxK = e.key;
        }
      }
      if (maxD <= gap &&
          chests.length >= kMinChestSpots &&
          dense()) {
        break;
      }
      if (maxK < 0 || maxD <= 2) break;
      // El tile más lejano o, si no sirve para un cofre, el más cercano a
      // él que sirva.
      (int, int)? pick;
      final near = bfs([(maxK % w, maxK ~/ w)]);
      final order = near.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final e in order) {
        if (chestOk(e.key % w, e.key ~/ w) && !chests.contains((e.key % w, e.key ~/ w))) {
          pick = (e.key % w, e.key ~/ w);
          break;
        }
      }
      // v0.20.22: en pisos chicos (pasillos, puentes) el lugar "cómodo"
      // más cercano puede quedar lejos; se acepta uno de pasillo.
      if (pick == null || near[pick.$2 * w + pick.$1]! > gap ~/ 2) {
        for (final e in order) {
          if (e.value > gap ~/ 2) break;
          final q = (e.key % w, e.key ~/ w);
          if (chestOk(q.$1, q.$2, minN: 1) && !chests.contains(q)) {
            pick = q;
            break;
          }
        }
      }
      if (pick == null) break;
      chests.add(pick);
    }

    return PoiLayout(
      pois: pois,
      quests: quests,
      chestSpots: chests,
      reserved: reserved,
      area: area,
    );
  }
}
