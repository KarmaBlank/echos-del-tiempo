// Generated biome regions (docs/specs/biome_regions.md). Pure and
// deterministic: the same (biome, world seed) gives the same tiles on
// every peer. The host never sends the layout; everybody builds it.

import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/mine_catalog.dart' show MineTile, mineEntrances;
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import '../models/world_save.dart' show TownState;
import 'raft_rules.dart';
import 'wild_loot_rules.dart' show WildLootRules;

part 'biome_wilds.dart';

/// A lake of a region (§ 3).
class BiomeLake {
  const BiomeLake({
    required this.variant,
    required this.ellipse,
    required this.docks,
    required this.approach,
    required this.name,
    this.cave,
    this.giant = false,
  });

  /// A giant lake of the wilds (biome_exploration.md § 2): always gets a
  /// raft dock (fishing.md § 15).
  final bool giant;

  /// This lake marked as giant.
  BiomeLake asGiant() => BiomeLake(
      variant: variant,
      ellipse: ellipse,
      docks: docks,
      approach: approach,
      name: name,
      cave: cave,
      giant: true);

  final LakeVariant variant;

  /// Center x, center y, radius x, radius y (tiles).
  final (double, double, double, double) ellipse;

  /// Dock tiles (on the water edge; fish from beside them).
  final List<(int, int)> docks;

  /// The land tile the side path ends on, next to the first dock.
  final (int, int) approach;
  final String name;

  /// The cavern around a cave lake (center x, center y, rx, ry), or `null`.
  final (double, double, double, double)? cave;
}

/// Where a waystone stands (§ 4).
enum WaystoneSite { entrance, lake, mine, section, shrine, cavern }

/// A waystone of a region: its tile, where travellers arrive and what it
/// belongs to ([ref] = lake or mine index).
typedef BiomeWaystone = ({
  int x,
  int y,
  int ax,
  int ay,
  WaystoneSite site,
  int ref,
});

/// The generated exterior of a biome (biome_regions.md § 2): same API the
/// fixed 34 × 22 layouts had, plus lakes, waystones, caves and paths.
class BiomeLayout {
  BiomeLayout._({
    required this.base,
    required this.seed,
    required this.lakes,
    required this.forage,
    required this.entrances,
    required this.mineSites,
    required this.npc,
    required this.waystones,
    required this.mainPath,
    required this.eventSpots,
    required this.skylights,
    required this.fisherWalk,
    required this.echoNook,
    this.sections = const [],
    this.caverns = const [],
    this.beams = const [],
    this.shrines = const [],
    this.chestSpots = const [],
    this.exploreSpots = const [],
    required List<String> baseRows,
    required IndoorMask indoor,
  })  : _rows = baseRows,
        _indoor = indoor;

  /// The whole canvas (biome_exploration.md § 1): the front (the old
  /// 60 × 34 plan) sits bottom-center, the wilds all around.
  static const width = 150;
  static const height = 112;

  /// The front plan and where it sits on the canvas.
  static const frontW = 60, frontH = 34;
  static const frontX = (width - frontW) ~/ 2, frontY = height - frontH;

  /// Generator version (biome_exploration.md § 7): worlds saved with
  /// another one drop their layout-indexed state on load.
  static const version = 3;

  /// The sections of the wilds (§ 2): kind and center tile.
  final List<WildSection> sections;

  /// Small caverns of the wilds (center x, y, rx, ry).
  final List<(double, double, double, double)> caverns;

  /// Skylights that also get a falling beam (§ 4.2).
  final List<(int, int)> beams;

  /// Shrines and special fountains (tile, `Tile.shrine` / `Tile.fountain`).
  final List<(int, int)> shrines;

  /// Chests in caverns and hidden nooks (tile `MineTile.chest`).
  final List<(int, int)> chestSpots;

  /// Free ground deep in the wilds for exploration actors (§ 6).
  final List<(int, int)> exploreSpots;

  final BiomeBase base;
  final int seed;
  final List<BiomeLake> lakes;
  final List<ForageSpot> forage;

  /// Dungeon entrances (zone, x, y).
  final List<(int, int, int)> entrances;

  /// Cave mouths the generator carved for mines (§ 2.3).
  final List<(int, int)> mineSites;
  final BiomeNpcDef npc;
  final List<BiomeWaystone> waystones;

  /// Spawn → plaza (tiles), the short way every fighter walks.
  final List<(int, int)> mainPath;

  /// Free ground next to the main path for world-event actors (§ 2.4).
  final List<(int, int)> eventSpots;

  /// Openings in cave ceilings: light shafts fall here (§ 7).
  final List<(int, int)> skylights;

  /// Tiles the native fisher paces along.
  final List<(int, int)> fisherWalk;

  /// The optional nook with the echo bloom (tile), or `null`.
  final (int, int)? echoNook;

  final List<String> _rows;
  final IndoorMask _indoor;

  String get id => base.id;
  String get theme => base.theme;
  String get lakeName => base.lakeName;
  List<String> get fish => base.fish;
  List<String> get junk => base.junk;
  Map<String, double> get seeds => base.seeds;

  /// The first lake (the one the native fisher walks to).
  (double, double, double, double) get lake => lakes.first.ellipse;
  List<(int, int)> get docks => [for (final l in lakes) ...l.docks];

  /// Mine entrances: the mining hook when one is registered
  /// ([BiomeRegions.mineHook]), else the generated cave mouths.
  List<(int, int)> get mines =>
      BiomeRegions.mineHook?.call(this) ?? mineSites;

  /// Arrival from the town: the south path.
  WorldPoint get spawn => WorldPoint(
      (mainPath.first.$1 + 1) * 16.0, (height - 2.5) * 16.0);

  /// Portales de Ecos (ecos_zone.md § 2): one per zone, right of its
  /// entrance. (zone, middle tile x, y); 3 tiles wide, middle `x % 3 == 1`.
  List<(int, int, int)> get ecoPortals => [
        for (final (zone, x, y) in entrances) (zone, ringX(x + 3), y),
      ];

  static int ringX(int x) {
    while (x % 3 != 1) {
      x++;
    }
    return x;
  }

  /// Map labels (text, tile).
  List<(String, int, int)> get labels => [
        ('CAMINO AL PUEBLO', mainPath.first.$1, height - 2),
        for (final l in lakes)
          (
            l.name,
            l.ellipse.$1.round(),
            (l.ellipse.$2 - (l.cave?.$4 ?? l.ellipse.$4) - 1).round()
          ),
        for (final (zone, x, y) in ecoPortals) ('ECOS · ZONA $zone', x, y - 1),
      ];

  /// The generated tile at (x, y) (without forage marks).
  String baseTile(int x, int y) => _rows[y][x];

  /// Raft docks of the big lakes (fishing.md § 15), deterministic.
  late final List<RaftDock> raftDocks = RaftRules.placeDocks(this);

  bool isLake(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      x < width &&
      y < height &&
      (_rows[y][x] == Tile.water || _rows[y][x] == Tile.fishing);

  /// Under a roof (cave lake, short cave): darker, with shafts (§ 7).
  bool isIndoor(int x, int y) => _indoor.at(x, y);

  /// The map rows with the spots of [picked] already picked.
  List<String> rows(Set<int> picked) {
    if (picked.isEmpty) return _withForage(const {});
    return _withForage(picked);
  }

  List<String>? _fresh;

  List<String> _withForage(Set<int> picked) {
    if (picked.isEmpty && _fresh != null) return _fresh!;
    final g = [for (final r in _rows) r.split('')];
    for (var i = 0; i < forage.length; i++) {
      final f = forage[i];
      g[f.y][f.x] = picked.contains(i) ? Tile.forageUsed : Tile.forage;
    }
    final out = [for (final r in g) r.join()];
    if (picked.isEmpty) _fresh = out;
    return out;
  }
}

/// A packed per-tile flag.
class IndoorMask {
  IndoorMask(this.w, this.h) : _bits = List.filled(w * h, false);
  final int w, h;
  final List<bool> _bits;

  bool at(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && _bits[y * w + x];
  void set(int x, int y) {
    if (x >= 0 && y >= 0 && x < w && y < h) _bits[y * w + x] = true;
  }
}

/// The active world seed and the generated regions (cached per seed).
abstract final class BiomeRegions {
  static int _seed = 0;
  static final Map<String, BiomeLayout> _cache = {};

  /// Mining's entrance hook (mining_smithing.md § 1.1): picks the mine
  /// entrances of a layout (the generated cave mouths, off the main path,
  /// are in `lay.mineSites`). Set to mining's [mineEntrances]; `null` =
  /// use the cave mouths.
  static List<(int, int)> Function(BiomeLayout lay)? mineHook =
      mineEntrances;

  /// The world seed the regions are built from (`town.sky.seed`).
  static int get seed => _seed;

  /// Binds the world seed (host: `setWorld` / each map; clients: each
  /// snapshot). Cheap when unchanged.
  static void bind(int seed) {
    if (seed == _seed) return;
    _seed = seed;
    _cache.clear();
  }

  /// A world saved with another layout version (biome_exploration.md
  /// § 7): the regions regenerate on their own (the layout is never
  /// saved), so only the state indexed by the old layout goes — activated
  /// waystones, picked forage and today's wilds chest / shrine marks
  /// (indexed by spot, so they would land on new spots). Everything else
  /// stays. Same instance
  /// when already current.
  static TownState migrate(TownState t) {
    if (t.layoutVersion == BiomeLayout.version) return t;
    return t.copyWith(
        waystones: const {},
        wild: const {},
        daily: WildLootRules.dropLoot(t.daily),
        layoutVersion: BiomeLayout.version);
  }

  static BiomeLayout? of(String? id) {
    final b = kBiomeBases[id];
    if (b == null) return null;
    return _cache[b.id] ??= BiomeRegionGen.generate(b, _seed);
  }
}

/// El exterior generado de [id] (`null` = pueblo o desconocido).
BiomeLayout? biomeLayout(String? id) => BiomeRegions.of(id);

/// Every generated exterior by id, for the active world seed.
Map<String, BiomeLayout> get kBiomeLayouts =>
    {for (final id in kBiomeBases.keys) id: BiomeRegions.of(id)!};

/// El exterior del Bosque.
BiomeLayout get bosqueLayout => BiomeRegions.of(kBosque)!;

/// Los habitantes de todos los biomas (with their generated camp).
List<BiomeNpcDef> get kBiomeNpcs =>
    [for (final id in kBiomeBases.keys) BiomeRegions.of(id)!.npc];

BiomeNpcDef? biomeNpc(String id) {
  for (final b in kBiomeBases.values) {
    if (b.npc.id == id) return BiomeRegions.of(b.id)!.npc;
  }
  return null;
}

/// Nombre del habitante [id] (o el id si no existe).
String biomeNpcName(String id) {
  for (final b in kBiomeBases.values) {
    if (b.npc.id == id) return b.npc.name;
  }
  return id;
}

/// Small deterministic PRNG (same numbers on VM and web).
class _Rng {
  _Rng(int seed) : _s = (seed & 0x7fffffff) | 1;
  int _s;

  int next() {
    var x = _s;
    x ^= (x << 13) & 0x7fffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0x7fffffff;
    _s = x & 0x7fffffff;
    if (_s == 0) _s = 1;
    return _s;
  }

  double d() => next() / 0x7fffffff;
  int i(int n) => n <= 0 ? 0 : next() % n;
  double range(double a, double b) => a + (b - a) * d();
}

/// The region generator (biome_regions.md § 2).
abstract final class BiomeRegionGen {
  static TuningDef get t => tuning(TuningId.regions);

  static const w = BiomeLayout.width, h = BiomeLayout.height;

  /// Row of the plaza where the main path ends.
  static const plazaY = 16;

  static int hashSeed(int seed, String id) {
    var x = 0x811c9dc5 ^ seed;
    for (final c in id.codeUnits) {
      x = ((x ^ c) * 0x01000193) & 0x7fffffff;
    }
    return x == 0 ? 1 : x;
  }

  static BiomeLayout generate(BiomeBase b, int seed) =>
      _Wilds(b, seed, _Gen(b, seed).buildFront()).build();
}

class _Gen {
  _Gen(this.b, this.seed,
      {this.w = BiomeLayout.frontW, this.h = BiomeLayout.frontH, int salt = 0})
      : r = _Rng(BiomeRegionGen.hashSeed(seed ^ salt, b.id)),
        noise = _Rng(BiomeRegionGen.hashSeed(seed ^ 0x5bd1e995 ^ salt, b.id)),
        indoor = IndoorMask(w, h);

  final BiomeBase b;
  final int seed;
  final _Rng r, noise;
  final int w, h;

  late final List<List<String>> g;
  final reserved = <(int, int)>{};
  final IndoorMask indoor;
  final sidePaths = <List<(int, int)>>[];
  final lakeRoutes = <List<(int, int)>>[];

  /// The main path, plaza, entrance and portal routes and forecourts:
  /// groves, short caves and forage never touch these.
  final mainTiles = <(int, int)>{};
  late final List<double> _cost;

  TuningDef get t => BiomeRegionGen.t;

  bool inside(int x, int y) => x >= 2 && y >= 2 && x < w - 2 && y < h - 1;

  String at(int x, int y) =>
      x < 0 || y < 0 || x >= w || y >= h ? Tile.tree : g[y][x];

  void put(int x, int y, String c) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    g[y][x] = c;
  }

  void path(int x, int y) {
    if (!inside(x, y)) return;
    final c = g[y][x];
    if (c == Tile.floor) {
      reserved.add((x, y));
      return;
    }
    if (c == Tile.grass || c == Tile.tree || c == Tile.path) {
      g[y][x] = Tile.path;
      reserved.add((x, y));
    }
  }

  _Front buildFront() {
    g = [
      for (var y = 0; y < h; y++)
        [
          for (var x = 0; x < w; x++)
            x < 2 || x >= w - 2 || y < 2 || y >= h - 1
                ? Tile.tree
                : Tile.grass
        ]
    ];
    _cost = [for (var i = 0; i < w * h; i++) 1 + noise.d() * 1.2];

    // ---- Main path (§ 2.1): south exit → plaza, gently winding.
    final sx = w ~/ 2 - 1;
    var x = sx;
    final main = <(int, int)>[];
    for (var y = h - 1; y >= BiomeRegionGen.plazaY; y--) {
      if (y < h - 3 && y % 3 == 0) {
        x = (x + r.i(3) - 1).clamp(sx - 3, sx + 3);
      }
      main.add((x, y));
      for (final xx in [x, x + 1]) {
        g[y][xx] = Tile.path;
        reserved.add((xx, y));
      }
    }
    // The exit itself (the border row) stays walkable.
    final px = x;
    const py = BiomeRegionGen.plazaY;
    for (var yy = py - 1; yy <= py + 1; yy++) {
      for (var xx = px - 2; xx <= px + 3; xx++) {
        path(xx, yy);
      }
    }

    // ---- Dungeon entrances and Echo portals, a bit irregular (§ 2.1).
    final entrances = <(int, int, int)>[];
    for (var k = 0; k < b.zones.length; k++) {
      final left = k.isEven;
      final ex = left ? px - 10 + r.i(3) : px + 4 + r.i(3);
      final ey = 7 + r.i(3);
      entrances.add((b.zones[k], ex, ey));
    }
    for (final (zone, ex, ey) in entrances) {
      g[ey][ex] = Tile.entrance(zone);
      reserved.add((ex, ey));
      path(ex, ey + 1);
      final rx = BiomeLayout.ringX(ex + 3);
      for (var dx = -1; dx <= 1; dx++) {
        g[ey][rx + dx] = Tile.portal;
        reserved.add((rx + dx, ey));
        path(rx + dx, ey + 1);
      }
      // Clear a little forecourt so the arches read.
      for (var yy = ey + 1; yy <= ey + 2; yy++) {
        for (var xx = ex - 1; xx <= rx + 1; xx++) {
          reserved.add((xx, yy));
        }
      }
      _carve((px, py - 1), (ex, ey + 1), width: 2);
      _carve((ex, ey + 1), (rx, ey + 1));
    }

    mainTiles.addAll(reserved);
    final mainRoutes = sidePaths.length;

    // ---- Waystone at the entrance (§ 4).
    final waystones = <BiomeWaystone>[];
    void stone((int, int) near, WaystoneSite site, int ref, {int prefer = 0}) {
      final at = _beside(near, prefer: prefer);
      if (at == null) return;
      final a = _walkwayNext(at.$1, at.$2)!;
      put(at.$1, at.$2, Tile.waystone);
      reserved.add(at);
      waystones.add(
          (x: at.$1, y: at.$2, ax: a.$1, ay: a.$2, site: site, ref: ref));
    }

    stone(main[3], WaystoneSite.entrance, 0, prefer: -1);

    // ---- Mines: cave mouths off the north corners (§ 2.3).
    final mines = <(int, int)>[];
    // Only one by the portals (biome_exploration.md § 3.1); the others
    // are deep in the wilds.
    for (final left in [r.d() < 0.5]) {
      final mx = left ? 4 + r.i(5) : w - 5 - r.i(5);
      const my = 3;
      for (var dx = -1; dx <= 1; dx++) {
        put(mx + dx, my - 1, Tile.rock);
        if (dx != 0) put(mx + dx, my, Tile.rock);
      }
      put(mx, my, Tile.mineEntrance);
      reserved.add((mx, my));
      path(mx, my + 1);
      final e = left ? entrances.first : entrances.last;
      _carve((e.$2, e.$3 + 1), (mx, my + 1));
      mines.add((mx, my));
    }

    // ---- Sites for lakes, the camp and the echo nook.
    final sw = (3, py + 2, px - 5, h - 3);
    final se = (px + 7, py + 2, w - 3, h - 3);
    final wm = (3, 10, px - 6, py + 1);
    final em = (px + 8, 10, w - 3, py + 1);
    final southFirst = r.d() < 0.5;
    final sites = southFirst ? [sw, se] : [se, sw];
    final lakeCount = r.d() < t.d('secondLakeChance') ? 2 : 1;
    final lakes = <BiomeLake>[];
    final variants = _pickVariants(lakeCount);
    // A cavern (§ 3.1) also takes the middle site above its lake site:
    // it is far bigger than an open lake.
    final caveSites = <(int, int, int, int)>{};
    for (var k = 0; k < lakeCount; k++) {
      var site = sites[k];
      if (variants[k] == LakeVariant.cave) {
        final mid = site == sw ? wm : em;
        site = (site.$1, mid.$2, site.$3, site.$4);
        caveSites.add(mid);
      }
      final lk = _lake(site, variants[k], k, main);
      if (lk != null) lakes.add(lk);
    }
    // At least one lake: the first site with an open lake.
    if (lakes.isEmpty) {
      lakes.add(_lake(sites[0], LakeVariant.open, 0, main)!);
    }
    final free = [
      if (lakeCount == 1) sites[1],
      if (r.d() < 0.5) wm else em,
      if (r.d() < 0.5) em else wm,
    ]..removeWhere(caveSites.contains);
    if (free.isEmpty) {
      free.add(lakeCount == 1
          ? sites[1]
          : (caveSites.contains(wm) ? em : wm));
    }

    // Waystones at the lakes and mines.
    for (var k = 0; k < lakes.length; k++) {
      stone(lakes[k].approach, WaystoneSite.lake, k);
    }
    for (var k = 0; k < mines.length; k++) {
      stone((mines[k].$1, mines[k].$2 + 2), WaystoneSite.mine, k);
    }

    // ---- Camp of the resident (§ 2.4).
    final cs = free.first;
    final cx = (cs.$1 + cs.$3) ~/ 2 - 1, cy = (cs.$2 + cs.$4) ~/ 2;
    for (var yy = cy - 2; yy <= cy + 2; yy++) {
      for (var xx = cx - 2; xx <= cx + 4; xx++) {
        if (inside(xx, yy) && g[yy][xx] == Tile.grass) reserved.add((xx, yy));
      }
    }
    _carve(_nearestMain(main, cx, cy), (cx - 2, cy + 1));
    final npc = b.npc.at((cx, cy));

    // ---- Echo nook: a quiet clearing ringed by trees (§ 5).
    (int, int)? nook;
    final ns = free.length > 1 ? free[1] : free.first;
    final nx = ns.$1 + 2 + r.i(math.max(1, ns.$3 - ns.$1 - 4));
    final ny = ns.$2 + 1 + r.i(math.max(1, ns.$4 - ns.$2 - 2));
    if (inside(nx, ny) &&
        g[ny][nx] == Tile.grass &&
        !reserved.contains((nx, ny)) &&
        (nx - cx).abs() + (ny - cy).abs() > 6) {
      final route = _carve(_nearestMain(main, nx, ny), (nx, ny + 1));
      if (route != null) {
        nook = (nx, ny);
        reserved.remove((nx, ny));
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final d = dx.abs() + dy.abs();
            if (d >= 3 && !reserved.contains((nx + dx, ny + dy))) {
              if (inside(nx + dx, ny + dy) &&
                  g[ny + dy][nx + dx] == Tile.grass) {
                g[ny + dy][nx + dx] = Tile.tree;
              }
            }
          }
        }
      }
    }

    // ---- Groves and short caves along side paths (§ 2.2).
    for (final sp in sidePaths.skip(mainRoutes)) {
      if (sp.length < 10) continue;
      final roll = r.d();
      if (roll < b.style.tunnel) {
        _tunnel(sp);
      } else if (roll < b.style.tunnel + b.style.grove) {
        _grove(sp);
      }
    }

    // ---- Forage spots (§ 5).
    final forage = <ForageSpot>[];
    final taken = <(int, int)>{};
    void spot((int, int)? at, int kind) {
      if (at == null || taken.contains(at)) return;
      taken.add(at);
      reserved.add(at);
      forage.add((x: at.$1, y: at.$2, kind: kind));
    }

    final side = [
      for (final s in sidePaths.skip(mainRoutes))
        for (final p in s)
          if (!mainTiles.contains(p)) p
    ];
    // The first spots are the three base kinds (callers read `.first`).
    final plants = t.i('plantSpots');
    for (var k = 0; k < plants && side.isNotEmpty; k++) {
      final p = side[(k * 7 + r.i(5)) % side.length];
      spot(_beside(p), b.forageKinds[k % b.forageKinds.length]);
    }
    for (var k = 0; k < t.i('seedBushes') && side.isNotEmpty; k++) {
      spot(_beside(side[r.i(side.length)]), kForageSeedBush);
    }
    for (var k = 0; k < t.i('seasonalSpots') && side.isNotEmpty; k++) {
      spot(_beside(side[r.i(side.length)]), kForageSeasonal);
    }
    if (nook != null) spot(nook, kForageEchoBloom);

    // ---- Event spots next to the main path (§ 2.4).
    final events = <(int, int)>[];
    for (var k = 4; k < main.length - 2 && events.length < 8; k += 2) {
      final (mx, my) = main[k];
      for (final ex in [mx - 2, mx + 3]) {
        if (inside(ex, my) &&
            g[my][ex] == Tile.grass &&
            !reserved.contains((ex, my)) &&
            !reserved.contains((ex + (ex < mx ? 1 : -1), my))) {
          events.add((ex, my));
          reserved.add((ex, my));
        }
      }
    }

    // ---- Decoration: trees away from paths (§ 2.5).
    final dens = t.d('treeDensity') / 100;
    for (var y = 2; y < h - 1; y++) {
      for (var x = 2; x < w - 2; x++) {
        if (g[y][x] != Tile.grass || reserved.contains((x, y))) continue;
        if (_nearReserved(x, y, 1)) continue;
        if (r.d() < dens) g[y][x] = Tile.tree;
      }
    }

    final skylights = <(int, int)>[];
    for (final lk in lakes) {
      if (lk.cave case final c? when b.style.caveOpenings) {
        // At most one or two faint openings (§ 7.2.1), tunable.
        final maxN = t.i('caveSkylightsMax').clamp(0, 4);
        final n = maxN == 0 ? 0 : r.i(maxN + 1);
        for (var k = 0; k < n; k++) {
          final a = r.d() * 2 * math.pi;
          final rr = r.range(0.2, 0.75);
          skylights.add((
            (c.$1 + c.$3 * rr * math.cos(a)).round(),
            (c.$2 + c.$4 * rr * math.sin(a)).round(),
          ));
        }
      }
    }

    final first = lakeRoutes.isEmpty ? main : lakeRoutes.first;
    final walk = first.length > 6 ? first.sublist(first.length - 6) : first;

    return _Front(
      lakes: lakes,
      forage: forage,
      entrances: entrances,
      mines: mines,
      npc: npc,
      waystones: waystones,
      main: main,
      events: events,
      skylights: skylights,
      walk: walk,
      nook: nook,
      g: g,
      indoor: indoor,
      reserved: reserved,
      mainTiles: mainTiles,
    );
  }

  List<LakeVariant> _pickVariants(int n) {
    final ws = b.style.lakes;
    final total = ws.values.fold(0.0, (a, v) => a + v);
    LakeVariant pick() {
      var x = r.d() * total;
      for (final e in ws.entries) {
        x -= e.value;
        if (x < 0) return e.key;
      }
      return ws.keys.first;
    }

    final a = pick();
    if (n == 1) return [a];
    // Two lakes: try for two different variants.
    var bb = pick();
    for (var k = 0; k < 3 && bb == a && ws.length > 1; k++) {
      bb = pick();
    }
    return [a, bb];
  }

  (int, int) _nearestMain(List<(int, int)> main, int x, int y) {
    var best = main.first;
    var bd = 1 << 30;
    for (final m in main) {
      final d = (m.$1 - x).abs() + (m.$2 - y).abs();
      if (d < bd) {
        bd = d;
        best = m;
      }
    }
    // Leave from the side of the 2-wide path that faces the target.
    return x > best.$1 ? (best.$1 + 1, best.$2) : best;
  }

  bool _nearReserved(int x, int y, int d) {
    for (var dy = -d; dy <= d; dy++) {
      for (var dx = -d; dx <= d; dx++) {
        if (reserved.contains((x + dx, y + dy)) &&
            (at(x + dx, y + dy) == Tile.path ||
                at(x + dx, y + dy) == Tile.floor)) {
          return true;
        }
      }
    }
    return false;
  }

  /// A free grass tile next to [p] (not on a path), or `null`.
  (int, int)? _beside((int, int) p, {int prefer = 0}) {
    final dirs = prefer < 0
        ? const [(-1, 0), (0, -1), (1, 0), (0, 1)]
        : const [(1, 0), (-1, 0), (0, 1), (0, -1)];
    // Ring by ring around [p]: a free grass tile touching a walkway, so
    // the solid thing placed there never blocks a path and is reachable.
    for (var rad = 1; rad <= 3; rad++) {
      for (var dy = -rad; dy <= rad; dy++) {
        for (var dx0 = -rad; dx0 <= rad; dx0++) {
          final dx = prefer < 0 ? dx0 : -dx0;
          if (dx.abs() != rad && dy.abs() != rad) continue;
          final x = p.$1 + dx, y = p.$2 + dy;
          if (!inside(x, y) || g[y][x] != Tile.grass) continue;
          if (reserved.contains((x, y))) continue;
          if (_walkwayNext(x, y, dirs) == null) continue;
          return (x, y);
        }
      }
    }
    return null;
  }

  /// The walkway (path / floor) tile next to ([x], [y]), or `null`.
  (int, int)? _walkwayNext(int x, int y,
      [List<(int, int)> dirs = const [(1, 0), (-1, 0), (0, 1), (0, -1)]]) {
    for (final (dx, dy) in dirs) {
      final c = at(x + dx, y + dy);
      if ((c == Tile.path || c == Tile.floor) && inside(x + dx, y + dy)) {
        return (x + dx, y + dy);
      }
    }
    return null;
  }

  /// Lake [k] of [variant] inside site rect (x0, y0, x1, y1) (§ 3).
  BiomeLake? _lake((int, int, int, int) site, LakeVariant variant, int k,
      List<(int, int)> main,
      {(double, double)? radii, bool carveRoute = true}) {
    final (x0, y0, x1, y1) = site;
    final cave = variant == LakeVariant.cave;
    final pad = cave ? 3.0 : 1.5;
    final maxRx = (x1 - x0) / 2 - pad - 1;
    final maxRy = (y1 - y0) / 2 - pad - 0.5;
    if (maxRx < 2.5 || maxRy < 2) return null;
    final rx = math.min(
        maxRx, radii?.$1 ?? r.range(t.d('lakeRxMin'), t.d('lakeRxMax')));
    final ry = math.min(
        maxRy, radii?.$2 ?? r.range(t.d('lakeRyMin'), t.d('lakeRyMax')));
    final cx = (x0 + x1) / 2 + r.range(-1, 1);
    final cy = (y0 + y1) / 2 + r.range(-0.5, 0.5);
    final ph1 = r.d() * 6.28, ph2 = r.d() * 6.28;
    final a1 = r.range(0.05, 0.14), a2 = r.range(0.04, 0.1);
    double rad(double ang) =>
        1 + a1 * math.sin(ang + ph1) + a2 * math.sin(2 * ang + ph2);
    double norm(double ex, double ey, double rxx, double ryy) {
      final dx = (ex - cx) / rxx, dy = (ey - cy) / ryy;
      final ang = math.atan2(dy, dx);
      return math.sqrt(dx * dx + dy * dy) / rad(ang);
    }

    // The approach comes from the main path side.
    final towardMain = main.last.$1 < cx ? -1 : 1;
    // The cavern (§ 3.1): an irregular blob 2–3 × the lake, ringed by a
    // thick rock rim. Its own harmonics and a per-tile jitter make the
    // silhouette organic; the rim fills the site up to its border.
    final wallT = t.d('caveWallTiles');
    final crx = math.min((x1 - x0) / 2 - wallT - 0.5,
        rx * t.d('caveScaleX') + 1);
    final cry = math.min((y1 - y0) / 2 - wallT - 0.5,
        ry * t.d('caveScaleY') + 1);
    final cp1 = r.d() * 6.28, cp2 = r.d() * 6.28, cp3 = r.d() * 6.28;
    final ca1 = r.range(0.08, 0.16), ca2 = r.range(0.06, 0.12),
        ca3 = r.range(0.03, 0.07);
    final jit = r.i(1 << 20);
    double cnorm(int x, int y) {
      final dx = (x - cx) / crx, dy = (y - cy) / cry;
      final ang = math.atan2(dy, dx);
      final rr = 1 +
          ca1 * math.sin(2 * ang + cp1) +
          ca2 * math.sin(3 * ang + cp2) +
          ca3 * math.sin(5 * ang + cp3);
      final j = (((x * 73856093) ^ (y * 19349663) ^ jit) & 0xff) / 255;
      return math.sqrt(dx * dx + dy * dy) / rr + (j - 0.5) * 0.08;
    }

    if (cave) {
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          if (!inside(x, y) || reserved.contains((x, y))) continue;
          final d = cnorm(x, y);
          if (d <= 1) {
            g[y][x] = Tile.floor;
            indoor.set(x, y);
          } else if (d <= 1 + wallT / math.min(crx, cry)) {
            g[y][x] = Tile.rock;
          }
        }
      }
    }
    final water = <(int, int)>[];
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!inside(x, y) || reserved.contains((x, y))) continue;
        if (norm(x.toDouble(), y.toDouble(), rx, ry) <= 1) {
          g[y][x] = Tile.water;
          water.add((x, y));
        }
      }
    }
    if (water.length < 6) return null;
    // Later caverns never carve into this lake or its docks.
    reserved.addAll(water);

    // Dock: the water tile on the edge facing the main path, on the
    // center row; the approach is the land tile beyond it.
    final row = cy.round();
    var dx0 = cx.round();
    while (at(dx0 + towardMain, row) == Tile.water) {
      dx0 += towardMain;
    }
    final dock = (dx0, row);
    final approach = (dx0 + towardMain, row);
    put(dock.$1, dock.$2, Tile.fishing);
    final docks = [dock];
    // Open lakes get a second dock on the far shore row (south side).
    if (variant == LakeVariant.open) {
      var dy0 = cy.round();
      final col = cx.round();
      while (at(col, dy0 + 1) == Tile.water) {
        dy0++;
      }
      if (dy0 != row || col != dock.$1) {
        put(col, dy0, Tile.fishing);
        docks.add((col, dy0));
        reserved.add((col, dy0 + 1));
        if (!_passable(col, dy0 + 1)) put(col, dy0 + 1, Tile.grass);
      }
    }

    // Cave mouth: open the rock toward the approach.
    // The one mouth: carve through the rim toward the approach until
    // open ground (§ 3.1).
    if (cave) {
      var mx = approach.$1;
      var outside = 0;
      for (var s = 0; s < 40 && outside < 2 && inside(mx, row); s++) {
        var rock = false;
        for (var yy = row - 1; yy <= row + 1; yy++) {
          if (at(mx, yy) == Tile.rock) {
            rock = true;
            g[yy][mx] = Tile.floor;
            indoor.set(mx, yy);
          }
        }
        if (!rock && !indoor.at(mx, row)) outside++;
        mx += towardMain;
      }
    }

    reserved.add(approach);
    // Glow shore: plants all around except the arc facing the approach.
    if (variant == LakeVariant.glowShore) {
      final open = math.atan2(0, towardMain.toDouble());
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          if (!inside(x, y) || g[y][x] != Tile.grass) continue;
          if (reserved.contains((x, y))) continue;
          final d = norm(x.toDouble(), y.toDouble(), rx, ry);
          if (d <= 1 || d > 1 + 2.2 / rx) continue;
          final ang = math.atan2((y - cy) / ry, (x - cx) / rx);
          var diff = (ang - open).abs();
          if (diff > math.pi) diff = 2 * math.pi - diff;
          if (diff > 0.95) g[y][x] = Tile.glowPlant;
        }
      }
    }

    if (carveRoute) {
      final route =
          _carve(_nearestMain(main, approach.$1, approach.$2), approach);
      if (route == null) return null;
      lakeRoutes.add(route);
    } else if (!_passable(approach.$1, approach.$2)) {
      put(approach.$1, approach.$2, Tile.grass);
    }
    for (final d in docks.skip(1)) {
      _carve(approach, (d.$1, d.$2 + 1));
    }
    final name = k == 0
        ? b.lakeName
        : (b.style.lakeNames[variant] ?? b.lakeName);
    return BiomeLake(
      variant: variant,
      ellipse: (cx, cy, rx, ry),
      docks: docks,
      approach: approach,
      name: name,
      cave: cave ? (cx, cy, crx, cry) : null,
    );
  }

  /// Walkable ground the spawn cannot reach (a far cave shore, a ring of
  /// trees) becomes solid: every open tile of a region is reachable, so
  /// the shiny water and any spot by the shore are always fishable.
  void _fillPockets((int, int) from) {
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
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (seen[y * w + x] || !Tile.isWalkable(g[y][x])) continue;
        g[y][x] = indoor.at(x, y) ? Tile.rock : Tile.tree;
      }
    }
  }

  bool _passable(int x, int y) {
    if (!inside(x, y)) return false;
    final c = g[y][x];
    return c == Tile.grass || c == Tile.path || c == Tile.floor;
  }

  /// Carves a path from [a] to [b] (A* over grass with a little noise so
  /// it wanders) and records it as a side path. Returns the tiles.
  /// With [dig], the route may cut through cave rock (it becomes cave
  /// floor under the roof).
  List<(int, int)>? _carve((int, int) a, (int, int) b,
      {int width = 1, bool dig = false}) {
    if (!_passable(b.$1, b.$2)) put(b.$1, b.$2, Tile.grass);
    final n = w * h;
    final dist = List.filled(n, double.infinity);
    final prev = List.filled(n, -1);
    final heap = _Heap();
    final s = a.$2 * w + a.$1, goal = b.$2 * w + b.$1;
    dist[s] = 0;
    heap.push(0, s);
    while (heap.isNotEmpty) {
      final (f, u) = heap.pop();
      if (u == goal) break;
      final ux = u % w, uy = u ~/ w;
      final du = dist[u];
      if (f - _h(ux, uy, b) > du + 1e-9) continue;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final vx = ux + dx, vy = uy + dy;
        final v = vy * w + vx;
        if (vx < 0 || vy < 0 || vx >= w || vy >= h) continue;
        final rock = dig &&
            inside(vx, vy) &&
            (g[vy][vx] == Tile.rock || g[vy][vx] == Tile.tree);
        if (v != goal && !_passable(vx, vy) && !rock) continue;
        final c = rock ? 4.0 : (g[vy][vx] == Tile.path ? 0.35 : _cost[v]);
        final nd = du + c;
        if (nd < dist[v]) {
          dist[v] = nd;
          prev[v] = u;
          heap.push(nd + _h(vx, vy, b), v);
        }
      }
    }
    if (prev[goal] < 0 && goal != s) return null;
    final out = <(int, int)>[];
    for (var u = goal; u >= 0; u = prev[u]) {
      out.add((u % w, u ~/ w));
      if (u == s) break;
    }
    final route = out.reversed.toList();
    for (final (x, y) in route) {
      if (dig && g[y][x] == Tile.rock) {
        g[y][x] = Tile.floor;
        indoor.set(x, y);
      }
      path(x, y);
      if (width > 1) path(x + 1, y);
    }
    sidePaths.add(route);
    return route;
  }

  double _h(int x, int y, (int, int) b) =>
      ((x - b.$1).abs() + (y - b.$2).abs()) * 0.35;

  /// Trees on both sides of the middle of [sp] (a small grove).
  void _grove(List<(int, int)> sp) {
    final a = sp.length ~/ 3, z = sp.length * 2 ~/ 3;
    for (var k = a; k < z; k++) {
      final (x, y) = sp[k];
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          if (dx == 0 && dy == 0) continue;
          final xx = x + dx, yy = y + dy;
          if (!inside(xx, yy) || g[yy][xx] != Tile.grass) continue;
          if (reserved.contains((xx, yy))) continue;
          if (r.d() < 0.55) g[yy][xx] = Tile.tree;
        }
      }
    }
  }

  /// A short cave over the middle of [sp]: rock walls on both sides and a
  /// floor under a roof (§ 2.2).
  void _tunnel(List<(int, int)> sp) {
    final mid = sp.length ~/ 2;
    final a = math.max(1, mid - 3), z = math.min(sp.length - 1, mid + 3);
    for (var k = a; k < z; k++) {
      final (x, y) = sp[k];
      if (g[y][x] != Tile.path || mainTiles.contains((x, y))) continue;
      g[y][x] = Tile.floor;
      indoor.set(x, y);
    }
    for (var k = a; k < z; k++) {
      final (x, y) = sp[k];
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx, yy = y + dy;
          if (!inside(xx, yy) || g[yy][xx] != Tile.grass) continue;
          if (reserved.contains((xx, yy))) continue;
          g[yy][xx] = Tile.rock;
        }
      }
    }
  }
}

/// A tiny binary min-heap of (priority, node).
class _Heap {
  final _p = <double>[];
  final _v = <int>[];
  bool get isNotEmpty => _p.isNotEmpty;

  void push(double p, int v) {
    _p.add(p);
    _v.add(v);
    var i = _p.length - 1;
    while (i > 0) {
      final up = (i - 1) >> 1;
      if (_p[up] <= _p[i]) break;
      _swap(i, up);
      i = up;
    }
  }

  (double, int) pop() {
    final top = (_p.first, _v.first);
    final lp = _p.removeLast(), lv = _v.removeLast();
    if (_p.isNotEmpty) {
      _p[0] = lp;
      _v[0] = lv;
      var i = 0;
      while (true) {
        final l = i * 2 + 1, rr = l + 1;
        var m = i;
        if (l < _p.length && _p[l] < _p[m]) m = l;
        if (rr < _p.length && _p[rr] < _p[m]) m = rr;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final tp = _p[a];
    _p[a] = _p[b];
    _p[b] = tp;
    final tv = _v[a];
    _v[a] = _v[b];
    _v[b] = tv;
  }
}
