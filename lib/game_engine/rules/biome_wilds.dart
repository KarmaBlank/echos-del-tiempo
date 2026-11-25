part of 'biome_regions.dart';

// The wilds around the front of a biome (docs/specs/biome_exploration.md
// § 1–5): sections you can get lost in, joined by winding trails, with
// caverns, a giant lake, shrines, hidden nooks, deep mines and the
// waystones of every point of interest. Pure and deterministic.

/// A section: its kind and its center tile.
typedef WildSection = ({WildKind kind, int x, int y});

/// What the front generator hands to the wilds (front coordinates).
class _Front {
  _Front({
    required this.lakes,
    required this.forage,
    required this.entrances,
    required this.mines,
    required this.npc,
    required this.waystones,
    required this.main,
    required this.events,
    required this.skylights,
    required this.walk,
    required this.nook,
    required this.g,
    required this.indoor,
    required this.reserved,
    required this.mainTiles,
  });

  final List<BiomeLake> lakes;
  final List<ForageSpot> forage;
  final List<(int, int, int)> entrances;
  final List<(int, int)> mines;
  final BiomeNpcDef npc;
  final List<BiomeWaystone> waystones;
  final List<(int, int)> main, events, skylights, walk;
  final (int, int)? nook;
  final List<List<String>> g;
  final IndoorMask indoor;
  final Set<(int, int)> reserved, mainTiles;
}

class _Wilds extends _Gen {
  _Wilds(super.b, super.seed, this.f)
      : super(w: BiomeLayout.width, h: BiomeLayout.height, salt: 0x2545F491);

  final _Front f;
  static const ox = BiomeLayout.frontX, oy = BiomeLayout.frontY;

  (int, int) o((int, int) p) => (p.$1 + ox, p.$2 + oy);

  bool inFront(int x, int y, [int pad = 0]) =>
      x >= ox - pad &&
      x < ox + BiomeLayout.frontW + pad &&
      y >= oy - pad &&
      y < oy + BiomeLayout.frontH + pad;

  BiomeLake _shiftLake(BiomeLake l) {
    final (cx, cy, rx, ry) = l.ellipse;
    final c = l.cave;
    return BiomeLake(
      variant: l.variant,
      ellipse: (cx + ox, cy + oy, rx, ry),
      docks: [for (final d in l.docks) o(d)],
      approach: o(l.approach),
      name: l.name,
      cave: c == null ? null : (c.$1 + ox, c.$2 + oy, c.$3, c.$4),
      giant: l.giant,
    );
  }

  BiomeLayout build() {
    // ---- Canvas: grass wilds, the front pasted bottom-center (§ 1).
    g = [
      for (var y = 0; y < h; y++)
        [
          for (var x = 0; x < w; x++)
            x < 2 || x >= w - 2 || y < 2 || y >= h - 1 ? Tile.tree : Tile.grass
        ]
    ];
    final trail = t.d('wildTrailNoise');
    _cost = [for (var i = 0; i < w * h; i++) 1 + noise.d() * trail];
    for (var y = 0; y < BiomeLayout.frontH; y++) {
      for (var x = 0; x < BiomeLayout.frontW; x++) {
        g[y + oy][x + ox] = f.g[y][x];
        if (f.indoor.at(x, y)) indoor.set(x + ox, y + oy);
      }
    }
    reserved.addAll(f.reserved.map(o));
    mainTiles.addAll(f.mainTiles.map(o));
    final main = [for (final p in f.main) o(p)];
    final lakes = [for (final l in f.lakes) _shiftLake(l)];
    final forage = <ForageSpot>[
      for (final s in f.forage) (x: s.x + ox, y: s.y + oy, kind: s.kind)
    ];
    final entrances = [
      for (final (z, x, y) in f.entrances) (z, x + ox, y + oy)
    ];
    final mines = [for (final m in f.mines) o(m)];
    final waystones = <BiomeWaystone>[
      for (final s in f.waystones)
        (
          x: s.x + ox,
          y: s.y + oy,
          ax: s.ax + ox,
          ay: s.ay + oy,
          site: s.site,
          ref: s.ref
        )
    ];
    final plaza = main.last;

    // ---- Gates through the front's tree border: west, east, north.
    final gates = <(int, int)>[];
    void open(int x0, int y0, int x1, int y1) {
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          if (inside(x, y) && !Tile.isWalkable(g[y][x])) g[y][x] = Tile.grass;
        }
      }
    }

    final gy = plaza.$2 + r.i(5) - 2;
    open(ox - 1, gy, ox + 3, gy + 1);
    gates.add((ox - 2, gy));
    open(ox + BiomeLayout.frontW - 4, gy, ox + BiomeLayout.frontW, gy + 1);
    gates.add((ox + BiomeLayout.frontW + 1, gy));
    final nx = plaza.$1 + r.i(5) - 2;
    open(nx, oy - 1, nx + 1, oy + 3);
    gates.add((nx, oy - 2));
    for (final gt in gates) {
      _carve(_nearestMain(main, gt.$1, gt.$2), gt);
    }

    // ---- Section centers on a jittered grid (§ 2).
    final cell = t.i('wildCell').clamp(12, 40);
    final kinds = b.style.wilds;
    final total = kinds.values.fold(0.0, (a, v) => a + v);
    var giant = r.d() < t.d('giantLakeChance');
    WildKind pickKind() {
      if (giant) {
        giant = false;
        return WildKind.giantLake;
      }
      var x = r.d() * total;
      for (final e in kinds.entries) {
        x -= e.value;
        if (x < 0) return e.key;
      }
      return WildKind.forest;
    }

    final centers = <(int, int)>[];
    for (var cy = 0; cy * cell < h; cy++) {
      for (var cx = 0; cx * cell < w; cx++) {
        final x = cx * cell + cell ~/ 2 + r.i(cell ~/ 2) - cell ~/ 4;
        final y = cy * cell + cell ~/ 2 + r.i(cell ~/ 2) - cell ~/ 4;
        if (x < 6 || y < 6 || x >= w - 6 || y >= h - 5) continue;
        if (inFront(x, y, cell ~/ 3)) continue;
        centers.add((x, y));
      }
    }
    // Far sections first: the giant lake and the deep mines go there.
    final sp = (main.first.$1, main.first.$2);
    int far((int, int) p) => (p.$1 - sp.$1).abs() + (p.$2 - sp.$2).abs();
    centers.sort((a, c) => far(c).compareTo(far(a)));

    final sections = <WildSection>[];
    final anchors = <(int, int)>[];
    final caverns = <(double, double, double, double)>[];
    final shrines = <(int, int)>[];
    final chests = <(int, int)>[];
    final beams = <(int, int)>[];
    final skylights = [for (final s in f.skylights) o(s)];
    final pois = <((int, int), WaystoneSite, int)>[];
    final half = cell ~/ 2 - 1;

    void clearing(int x, int y, int rad) {
      for (var dy = -rad; dy <= rad; dy++) {
        for (var dx = -rad; dx <= rad; dx++) {
          if (dx * dx + dy * dy > rad * rad + 1) continue;
          if (inside(x + dx, y + dy) && g[y + dy][x + dx] == Tile.grass) {
            reserved.add((x + dx, y + dy));
          }
        }
      }
    }

    // ---- The giant lake goes first (§ 3.3): it is far bigger than a
    // section cell, so its whole footprint is claimed before any other
    // section, trail or cavern can land inside it or cut its shore.
    (int, int, int, int)? lakeBox;
    if (giant) {
      giant = false;
      final rx = r.range(t.d('giantLakeRxMin'), t.d('giantLakeRxMax'));
      final ry = r.range(t.d('giantLakeRyMin'), t.d('giantLakeRyMax'));
      // The shoreline wobbles up to ~25 % past the radii.
      final hx = (rx * 1.25).ceil() + 3, hy = (ry * 1.25).ceil() + 3;
      bool clear(int x0, int y0, int x1, int y1) {
        for (var y = y0; y <= y1; y++) {
          for (var x = x0; x <= x1; x++) {
            if (!inside(x, y) || g[y][x] != Tile.grass) return false;
            if (reserved.contains((x, y)) || inFront(x, y, 3)) return false;
          }
        }
        return true;
      }

      for (final (x, y) in centers) {
        final s = (x - hx, y - hy, x + hx, y + hy);
        if (s.$1 < 3 || s.$2 < 3 || s.$3 > w - 4 || s.$4 > h - 3) continue;
        if (!clear(s.$1 - 2, s.$2 - 2, s.$3 + 2, s.$4 + 2)) continue;
        final lk = _lake(s, LakeVariant.open, lakes.length, [(x, y)],
            radii: (rx, ry), carveRoute: false);
        if (lk == null) continue;
        lakes.add(lk.asGiant());
        anchors.add(lk.approach);
        pois.add((lk.approach, WaystoneSite.lake, lakes.length - 1));
        sections.add((kind: WildKind.giantLake, x: x, y: y));
        lakeBox = s;
        // A walkable shore ring: no tree or rock ever closes the bank.
        for (var yy = s.$2 - 1; yy <= s.$4 + 1; yy++) {
          for (var xx = s.$1 - 1; xx <= s.$3 + 1; xx++) {
            if (!inside(xx, yy) || g[yy][xx] == Tile.water) continue;
            var shore = false;
            for (final (ddx, ddy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
              if (at(xx + ddx, yy + ddy) == Tile.water) shore = true;
            }
            if (!shore) continue;
            final c = g[yy][xx];
            if (c == Tile.fishing) continue;
            if (c == Tile.tree || c == Tile.rock) put(xx, yy, Tile.grass);
            reserved.add((xx, yy));
          }
        }
        break;
      }
    }
    // Sections whose own footprint would touch the lake box are dropped.
    bool nearLake(int x, int y) {
      final lb = lakeBox;
      if (lb == null) return false;
      final m = half + 2;
      return x >= lb.$1 - m && x <= lb.$3 + m && y >= lb.$2 - m && y <= lb.$4 + m;
    }

    for (final (x, y) in centers) {
      if (nearLake(x, y)) continue;
      var kind = pickKind();
      if (kind == WildKind.giantLake) kind = WildKind.meadow;
      if (kind == WildKind.cavern) {
        final s = (x - half, y - half, x + half, y + half);
        final wet = r.d() < t.d('cavernLakeChance');
        final before = lakes.length;
        final (int, int)? mouth;
        (double, double, double, double)? cave;
        if (wet) {
          final lk = _lake(s, LakeVariant.cave, lakes.length, [(x, y + half)],
              carveRoute: false);
          if (lk != null) lakes.add(lk);
          mouth = lk?.approach;
          cave = lk?.cave;
        } else {
          final dry = _dryCave(s);
          mouth = dry?.$1;
          cave = dry?.$2;
        }
        if (mouth != null && cave != null) {
          caverns.add(cave);
          anchors.add(mouth);
          pois.add((mouth, WaystoneSite.cavern, caverns.length - 1));
          sections.add((kind: kind, x: x, y: y));
          final c = cave;
          // Openings and, in some, a falling beam (§ 4.2).
          if (b.style.caveOpenings) {
            final n = 1 + r.i(2);
            final beam = r.d() < t.d('cavernShaftChance');
            for (var k = 0; k < n; k++) {
              final a = r.d() * 2 * math.pi;
              final rr = r.range(0.15, 0.6);
              final p = (
                (c.$1 + c.$3 * rr * math.cos(a)).round(),
                (c.$2 + c.$4 * rr * math.sin(a)).round(),
              );
              if (at(p.$1, p.$2) != Tile.floor) continue;
              skylights.add(p);
              if (beam) beams.add(p);
            }
          }
          // A chest on the dry floor, against the far wall.
          if (r.d() < t.d('wildChestChance')) {
            final ch = _caveSpot(c);
            if (ch != null) {
              put(ch.$1, ch.$2, MineTile.chest);
              reserved.add(ch);
              chests.add(ch);
            }
          }
          continue;
        }
        if (lakes.length > before) lakes.removeLast();
        kind = WildKind.forest;
      }
      put(x, y, Tile.path);
      clearing(x, y, kind == WildKind.meadow ? 3 : 2);
      if (kind == WildKind.shrine) {
        // A special fountain or a shrine in a ring of stones (§ 3.4).
        final fx = x, fy = y - 1;
        put(fx, fy, r.d() < 0.5 ? Tile.fountain : Tile.shrine);
        reserved.add((fx, fy));
        shrines.add((fx, fy));
        pois.add(((x, y), WaystoneSite.shrine, shrines.length - 1));
      }
      anchors.add((x, y));
      sections.add((kind: kind, x: x, y: y));
    }

    // ---- Trails (§ 2): a tree over anchors and gates, a few loops.
    final nodes = [...gates, ...anchors];
    final inTree = <int>{0, 1, 2};
    final edges = <(int, int)>[];
    double d2(int a, int c) {
      final dx = nodes[a].$1 - nodes[c].$1, dy = nodes[a].$2 - nodes[c].$2;
      return (dx * dx + dy * dy).toDouble();
    }

    while (inTree.length < nodes.length) {
      var best = (-1, -1);
      var bd = double.infinity;
      for (final a in inTree) {
        for (var c = 0; c < nodes.length; c++) {
          if (inTree.contains(c)) continue;
          final d = d2(a, c);
          if (d < bd) {
            bd = d;
            best = (a, c);
          }
        }
      }
      inTree.add(best.$2);
      edges.add(best);
    }
    for (var k = 0; k < t.i('wildExtraLoops') && nodes.length > 4; k++) {
      final a = 3 + r.i(nodes.length - 3);
      var best = -1;
      var bd = double.infinity;
      for (var c = 3; c < nodes.length; c++) {
        if (c == a || edges.contains((a, c)) || edges.contains((c, a))) {
          continue;
        }
        final d = d2(a, c);
        if (d < bd) {
          bd = d;
          best = c;
        }
      }
      if (best >= 0) edges.add((a, best));
    }
    final degree = List.filled(nodes.length, 0);
    for (final (a, c) in edges) {
      if (_carve(nodes[a], nodes[c]) == null) continue;
      degree[a]++;
      degree[c]++;
    }

    // A trail that could not be carved leaves a node cut off: join every
    // unreachable node to the nearest reachable trail tile.
    for (var pass = 0; pass < 3; pass++) {
      final seen = _reach(main.first);
      final lost = [
        for (var k = 3; k < nodes.length; k++)
          if (!seen[nodes[k].$2 * w + nodes[k].$1]) k
      ];
      if (lost.isEmpty) break;
      final trailTiles = [
        for (final r in sidePaths)
          for (final p in r)
            if (seen[p.$2 * w + p.$1]) p
      ];
      for (final k in lost) {
        final n = nodes[k];
        int dist((int, int) p) => (p.$1 - n.$1).abs() + (p.$2 - n.$2).abs();
        trailTiles.sort((a, b) => dist(a).compareTo(dist(b)));
        for (final target in trailTiles.take(6)) {
          if (_carve(n, target, dig: true) != null) {
            degree[k]++;
            break;
          }
        }
      }
    }

    // ---- Hidden nooks off the trail (§ 2): a clearing reached by a
    // narrow grass gap, with a chest or a rare plant.
    final hidden = <(int, int)>[];
    for (final s in sections) {
      if (s.kind == WildKind.cavern || s.kind == WildKind.giantLake) continue;
      if (r.d() >= t.d('hiddenNookChance')) continue;
      final a = r.d() * 2 * math.pi;
      final rad = 5 + r.i(3);
      final hx = (s.x + rad * math.cos(a)).round();
      final hy = (s.y + rad * math.sin(a)).round();
      if (!_passable(hx, hy) || reserved.contains((hx, hy))) continue;
      if (_nearReserved(hx, hy, 2)) continue;
      final route = _carveHidden((s.x, s.y), (hx, hy));
      if (route == null) continue;
      clearing(hx, hy, 1);
      hidden.add((hx, hy));
    }

    // ---- Deep mines (§ 3.1): far sections, some inside a cavern.
    final want = (t.i('minesMin') +
                r.i(math.max(1, t.i('minesMax') - t.i('minesMin') + 1)))
            .clamp(1, 3) -
        mines.length;
    final mineSpots = <((int, int), bool)>[
      for (var k = 0; k < caverns.length; k++)
        if (_caveWallSpot(caverns[k]) case final p?) (p, true),
      for (final p in hidden) (p, false),
    ];
    // Farthest first.
    mineSpots.sort((a, c) => far(c.$1).compareTo(far(a.$1)));
    for (var k = 0; k < mineSpots.length && k < want * 2; k += 2) {
      final ((mx, my), cave) = mineSpots[k];
      // The mouth is entered from the south: that tile needs open ground
      // around it (not a shore between water).
      if (!cave && _walkable4(mx, my + 1) < 2) continue;
      if (!cave) {
        // Rock around the mouth, but never on the passage that leads in.
        for (var dx = -1; dx <= 1; dx++) {
          if (!reserved.contains((mx + dx, my - 1))) {
            put(mx + dx, my - 1, Tile.rock);
          }
          if (dx != 0 && !reserved.contains((mx + dx, my))) {
            put(mx + dx, my, Tile.rock);
          }
        }
        hidden.remove((mx, my));
        // A worn patch in front of the mouth (the stone stands by it).
        if (at(mx, my + 1) == Tile.grass) put(mx, my + 1, Tile.path);
      }
      put(mx, my, Tile.mineEntrance);
      reserved.add((mx, my));
      mines.add((mx, my));
      pois.add(((mx, my + 1), WaystoneSite.mine, mines.length - 1));
    }
    // Not enough room deep: any free trail tile far away.
    if (mines.length < want + f.mines.length) {
      final side = sidePaths
          .expand((p) => p)
          .where((p) => !inFront(p.$1, p.$2))
          .toList()
        ..sort((a, c) => far(c).compareTo(far(a)));
      for (final p in side) {
        if (mines.length >= want + f.mines.length) break;
        final (mx, my) = (p.$1, p.$2 - 1);
        if (!inside(mx, my - 1) || g[my][mx] != Tile.grass) continue;
        if (reserved.contains((mx, my))) continue;
        if (mines.any((m) => (m.$1 - mx).abs() + (m.$2 - my).abs() < 20)) {
          continue;
        }
        put(mx, my, Tile.mineEntrance);
        reserved.add((mx, my));
        mines.add((mx, my));
        pois.add((p, WaystoneSite.mine, mines.length - 1));
      }
    }
    for (final p in hidden) {
      if (r.d() < t.d('wildChestChance')) {
        put(p.$1, p.$2, MineTile.chest);
        chests.add(p);
      } else {
        forage.add((x: p.$1, y: p.$2, kind: kForageSeedBush));
      }
    }

    // ---- Every point of interest is reachable: what was left cut off
    // (a trail blocked by a later cavern rim, a nook behind a lake) gets
    // a trail to the nearest reachable one.
    void repair() {
      final things = <(int, int)>[
        ...mines,
        ...chests,
        ...shrines,
        for (final f in forage) (f.x, f.y),
        for (final w in waystones) (w.x, w.y),
        for (final l in lakes) l.approach,
        // The tile in front of each mine mouth: it is entered from there.
        for (final m in mines) (m.$1, m.$2 + 1),
      ];
      for (final (mx, my) in mines) {
        if (!inside(mx, my + 1)) continue;
        reserved.add((mx, my + 1));
        if (Tile.isWalkable(at(mx, my + 1))) continue;
        put(mx, my + 1, indoor.at(mx, my + 1) ? Tile.floor : Tile.grass);
      }
      var seen = _reach(main.first);
      bool touch((int, int) p) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final x = p.$1 + dx, y = p.$2 + dy;
          if (x >= 0 && y >= 0 && x < w && y < h && seen[y * w + x]) {
            return true;
          }
        }
        return false;
      }

      for (final p in things) {
        if (touch(p) || seen[p.$2 * w + p.$1]) continue;
        // A side of it to leave from: walkable, else free grass.
        (int, int)? from = _passable(p.$1, p.$2) ? p : null;
        for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
          if (from != null) break;
          final q = (p.$1 + dx, p.$2 + dy);
          if (_passable(q.$1, q.$2)) {
            from = q;
            break;
          }
        }
        // Walled in: dig out from the rock beside it.
        for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
          if (from != null) break;
          final q = (p.$1 + dx, p.$2 + dy);
          if (inside(q.$1, q.$2) && g[q.$2][q.$1] == Tile.rock) from = q;
        }
        if (from == null) continue;
        final reach = [
          for (final r in sidePaths)
            for (final t in r)
              if (seen[t.$2 * w + t.$1]) t
        ];
        int dist((int, int) t) =>
            (t.$1 - from!.$1).abs() + (t.$2 - from.$2).abs();
        reach.sort((a, b) => dist(a).compareTo(dist(b)));
        for (final t in reach.take(6)) {
          if (_carve(from, t, dig: true) != null) {
            seen = _reach(main.first);
            break;
          }
        }
      }
    }

    repair();

    // ---- Forage and exploration spots by the trails (§ 3.2, § 6).
    final explore = <(int, int)>[];
    final per = t.i('wildForagePerSection');
    final wildTrail = [
      for (final s in sidePaths)
        for (final p in s)
          if (!inFront(p.$1, p.$2, 1)) p
    ];
    if (wildTrail.isNotEmpty) {
      final n = per * sections.length;
      for (var k = 0; k < n; k++) {
        final p = wildTrail[r.i(wildTrail.length)];
        final at = _beside(p);
        if (at == null || reserved.contains(at)) continue;
        reserved.add(at);
        forage.add((
          x: at.$1,
          y: at.$2,
          kind: k % 6 == 5
              ? kForageSeasonal
              : b.forageKinds[k % b.forageKinds.length]
        ));
      }
    }
    for (final s in sections) {
      if (s.kind == WildKind.cavern) continue;
      for (final (dx, dy) in const [(2, 1), (-2, 1)]) {
        final p = (s.x + dx, s.y + dy);
        if (inside(p.$1, p.$2) && g[p.$2][p.$1] == Tile.grass) {
          reserved.add(p);
          explore.add(p);
        }
      }
    }

    repair();

    // ---- Waystones at the points of interest (§ 5).
    void stone((int, int) near, WaystoneSite site, int ref) {
      var at = _beside(near);
      for (final (dx, dy) in const [
        (0, 3),
        (3, 0),
        (-3, 0),
        (0, -3),
        (3, 3),
        (-3, 3),
        (3, -3),
        (-3, -3)
      ]) {
        if (at != null) break;
        at = _beside((near.$1 + dx, near.$2 + dy));
      }
      // In a cavern: an open floor tile that blocks nothing.
      for (var rad = 1; rad <= 3 && at == null; rad++) {
        for (var dy = -rad; dy <= rad && at == null; dy++) {
          for (var dx = -rad; dx <= rad; dx++) {
            final x = near.$1 + dx, y = near.$2 + dy;
            if (this.at(x, y) != Tile.floor || reserved.contains((x, y))) {
              continue;
            }
            if (_walkable4(x, y) < 4) continue;
            at = (x, y);
            break;
          }
        }
      }
      // Last resort: replace a tree or rock that touches a walkway (a
      // solid for a solid: it never blocks anything).
      for (var rad = 1; rad <= 4 && at == null; rad++) {
        for (var dy = -rad; dy <= rad && at == null; dy++) {
          for (var dx = -rad; dx <= rad; dx++) {
            final x = near.$1 + dx, y = near.$2 + dy;
            final c = this.at(x, y);
            if (!inside(x, y) || (c != Tile.tree && c != Tile.rock)) continue;
            if (reserved.contains((x, y)) || _walkwayNext(x, y) == null) {
              continue;
            }
            at = (x, y);
            break;
          }
        }
      }
      // Off-trail ground: any free grass by the point, arriving beside it.
      for (var rad = 1; rad <= 3 && at == null; rad++) {
        for (var dy = -rad; dy <= rad && at == null; dy++) {
          for (var dx = -rad; dx <= rad; dx++) {
            final x = near.$1 + dx, y = near.$2 + dy;
            final c = this.at(x, y);
            if (!inside(x, y) || reserved.contains((x, y))) continue;
            // A tree touching open ground, or open grass in the middle of
            // a clearing (all four sides free: it blocks nothing).
            if (c == Tile.tree ? _walkable4(x, y) == 0
                : c != Tile.grass || _walkable4(x, y) < 4) {
              continue;
            }
            at = (x, y);
            break;
          }
        }
      }
      if (at == null) return;
      final a = _walkwayNext(at.$1, at.$2) ?? _walkableNext(at.$1, at.$2);
      if (a == null) return;
      put(at.$1, at.$2, Tile.waystone);
      reserved.add(at);
      waystones
          .add((x: at.$1, y: at.$2, ax: a.$1, ay: a.$2, site: site, ref: ref));
    }

    for (final (p, site, ref) in pois) {
      stone(p, site, ref);
    }
    for (var k = 0; k < sections.length; k++) {
      final s = sections[k];
      if (s.kind != WildKind.forest && s.kind != WildKind.meadow) continue;
      final i = 3 + anchors.indexOf((s.x, s.y));
      if (i < 3 || degree[i] < 3) continue;
      stone((s.x, s.y), WaystoneSite.section, k);
    }

    // ---- Decoration per section kind (§ 2): dense forest, open meadow.
    final dens = {
      WildKind.forest: t.d('wildForestDensity') / 100,
      WildKind.meadow: t.d('wildMeadowDensity') / 100,
      WildKind.shrine: t.d('wildDensity') / 100,
      WildKind.cavern: t.d('wildDensity') / 100,
      WildKind.giantLake: t.d('wildMeadowDensity') / 100,
    };
    for (var y = 2; y < h - 1; y++) {
      for (var x = 2; x < w - 2; x++) {
        if (inFront(x, y)) continue;
        if (g[y][x] != Tile.grass || reserved.contains((x, y))) continue;
        if (_nearReserved(x, y, 1)) continue;
        var best = WildKind.forest;
        var bd = 1 << 30;
        for (final s in sections) {
          final d = (s.x - x) * (s.x - x) + (s.y - y) * (s.y - y);
          if (d < bd) {
            bd = d;
            best = s.kind;
          }
        }
        if (r.d() < dens[best]!) g[y][x] = Tile.tree;
      }
    }

    // Forage spots are solid: stamp them so the last checks see them.
    for (final f in forage) {
      g[f.y][f.x] = Tile.forage;
    }
    repair();
    _fillPockets(main.first);
    // Arrivals on ground that the fill closed move to a reachable side.
    for (var k = 0; k < waystones.length; k++) {
      final w0 = waystones[k];
      if (Tile.isWalkable(at(w0.ax, w0.ay))) continue;
      final a = _walkableNext(w0.x, w0.y);
      if (a == null) continue;
      waystones[k] = (
        x: w0.x,
        y: w0.y,
        ax: a.$1,
        ay: a.$2,
        site: w0.site,
        ref: w0.ref
      );
    }
    // A pocket fill may have swallowed a hidden chest's floor: drop the
    // spots that are no longer what they were.
    chests.removeWhere((p) => g[p.$2][p.$1] != MineTile.chest);

    final (nx0, ny0) = f.npc.tile;
    return BiomeLayout._(
      base: b,
      seed: seed,
      lakes: List.unmodifiable(lakes),
      forage: List.unmodifiable(forage),
      entrances: List.unmodifiable(entrances),
      mineSites: List.unmodifiable(mines),
      npc: b.npc.at((nx0 + ox, ny0 + oy)),
      waystones: List.unmodifiable(waystones),
      mainPath: List.unmodifiable(main),
      eventSpots: List.unmodifiable([for (final p in f.events) o(p)]),
      skylights: List.unmodifiable(skylights),
      fisherWalk: List.unmodifiable([for (final p in f.walk) o(p)]),
      echoNook: f.nook == null ? null : o(f.nook!),
      sections: List.unmodifiable(sections),
      caverns: List.unmodifiable(caverns),
      beams: List.unmodifiable(beams),
      shrines: List.unmodifiable(shrines),
      chestSpots: List.unmodifiable(chests),
      exploreSpots: List.unmodifiable(explore),
      baseRows: [for (final row in g) row.join()],
      indoor: indoor,
    );
  }

  /// Walkable tiles reachable from [from] (flat index).
  List<bool> _reach((int, int) from) {
    final seen = List.filled(w * h, false);
    final q = <int>[from.$2 * w + from.$1];
    seen[q.first] = true;
    for (var i = 0; i < q.length; i++) {
      final u = q[i];
      final ux = u % w, uy = u ~/ w;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final vx = ux + dx, vy = uy + dy;
        if (vx < 0 || vy < 0 || vx >= w || vy >= h) continue;
        final v = vy * w + vx;
        if (seen[v] || !Tile.isWalkable(g[vy][vx])) continue;
        seen[v] = true;
        q.add(v);
      }
    }
    return seen;
  }

  /// A cavern without a lake inside site (x0, y0, x1, y1): floor under a
  /// roof, a rock rim and one mouth to the south. (mouth, cave ellipse).
  ((int, int), (double, double, double, double))? _dryCave(
      (int, int, int, int) site) {
    final (x0, y0, x1, y1) = site;
    final wallT = t.d('caveWallTiles');
    final crx = (x1 - x0) / 2 - wallT - 0.5, cry = (y1 - y0) / 2 - wallT - 0.5;
    if (crx < 3 || cry < 2.5) return null;
    final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    final p1 = r.d() * 6.28, p2 = r.d() * 6.28;
    final a1 = r.range(0.08, 0.16), a2 = r.range(0.05, 0.1);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!inside(x, y) || reserved.contains((x, y))) continue;
        final dx = (x - cx) / crx, dy = (y - cy) / cry;
        final ang = math.atan2(dy, dx);
        final rr =
            1 + a1 * math.sin(2 * ang + p1) + a2 * math.sin(3 * ang + p2);
        final d = math.sqrt(dx * dx + dy * dy) / rr;
        if (d <= 1) {
          g[y][x] = Tile.floor;
          indoor.set(x, y);
        } else if (d <= 1 + wallT / math.min(crx, cry)) {
          g[y][x] = Tile.rock;
        }
      }
    }
    // The mouth: straight down from the center through the rim.
    final mx = cx.round();
    var my = cy.round();
    while (my < y1 + 2 && (at(mx, my) == Tile.floor)) {
      my++;
    }
    var out = 0;
    for (var s = 0; s < 12 && out < 2 && inside(mx, my); s++) {
      var rock = false;
      for (var xx = mx - 1; xx <= mx + 1; xx++) {
        if (at(xx, my) == Tile.rock) {
          rock = true;
          g[my][xx] = Tile.floor;
          indoor.set(xx, my);
        }
      }
      if (!rock && !indoor.at(mx, my)) out++;
      my++;
    }
    final mouth = (mx, my - 1);
    if (!_passable(mouth.$1, mouth.$2)) put(mouth.$1, mouth.$2, Tile.grass);
    reserved.add(mouth);
    return (mouth, (cx, cy, crx, cry));
  }

  /// A dry floor tile of the cavern [c] with rock above (for a chest).
  (int, int)? _caveSpot((double, double, double, double) c) {
    final (cx, cy, rx, ry) = c;
    for (var dy = -ry.floor(); dy < 0; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final x = cx.round() + dx, y = cy.round() + dy;
        if (at(x, y) == Tile.floor &&
            at(x, y - 1) == Tile.rock &&
            !reserved.contains((x, y)) &&
            _walkable4(x, y) >= 2) {
          return (x, y);
        }
      }
    }
    return null;
  }

  /// A floor tile in the north wall of cavern [c] for a mine mouth.
  (int, int)? _caveWallSpot((double, double, double, double) c) {
    final (cx, cy, rx, ry) = c;
    final x0 = cx.round();
    for (var y = (cy - ry).floor(); y < cy; y++) {
      for (final x in [x0 - 2, x0 + 2, x0 - 1, x0 + 1]) {
        if (at(x, y) == Tile.floor &&
            at(x, y - 1) == Tile.rock &&
            at(x, y + 1) == Tile.floor &&
            !reserved.contains((x, y)) &&
            !reserved.contains((x, y + 1))) {
          return (x, y);
        }
      }
    }
    return null;
  }

  (int, int)? _walkableNext(int x, int y) {
    for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
      if (inside(x + dx, y + dy) && Tile.isWalkable(at(x + dx, y + dy))) {
        return (x + dx, y + dy);
      }
    }
    return null;
  }

  int _walkable4(int x, int y) {
    var n = 0;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      if (Tile.isWalkable(at(x + dx, y + dy))) n++;
    }
    return n;
  }

  /// A narrow passage over grass (not a trail): carved like a trail, then
  /// the new tiles go back to grass, reserved so no tree closes it.
  List<(int, int)>? _carveHidden((int, int) a, (int, int) z) {
    final was = <(int, int), String>{};
    for (var y = math.min(a.$2, z.$2) - 8; y <= math.max(a.$2, z.$2) + 8; y++) {
      for (var x = math.min(a.$1, z.$1) - 8;
          x <= math.max(a.$1, z.$1) + 8;
          x++) {
        if (x >= 0 && y >= 0 && x < w && y < h) was[(x, y)] = g[y][x];
      }
    }
    final route = _carve(a, z);
    if (route == null) return null;
    sidePaths.removeLast();
    for (final p in route) {
      if (was[p] == Tile.grass) {
        g[p.$2][p.$1] = Tile.grass;
        reserved.add(p);
      }
    }
    return route;
  }
}
