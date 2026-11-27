import 'dart:math' as math;

import '../data/biomes_catalog.dart' show kPueblo;
import '../data/construction_catalog.dart';
import '../data/home_furniture_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import '../models/game_session.dart' show GameSession, SessionPlayer;
import '../models/home_layout.dart';
import '../models/player_profile.dart';
import '../models/town_build.dart';
import '../models/world_save.dart' show TownState;
import 'helper_rules.dart';
import 'light_rules.dart';
import 'map_generator.dart';
import 'renown_rules.dart';
import 'sky_rules.dart';
import 'world_rules.dart';

/// The player house (docs/specs/player_house.md): a piece of EDITAR
/// PUEBLO whose door leads to an interior with beds. Sleeping in a bed
/// skips to the next morning (or to nightfall by day) once every human
/// is in bed. The inside is furnished with EDITAR CASA (§ 8). Pure data
/// and rules, no Flutter.
abstract final class HomeInteriorRules {
  static TuningDef get t => tuning(TuningId.town);

  /// Place id of the interior (`GameSession.place`).
  static const place = 'home';

  static bool isHome(String? p) => p == place;

  static const width = 12;
  static const height = 8;

  /// The empty room: `#` walls, `.` floor; the door is the two wall
  /// tiles at the bottom middle ([door]). Furniture goes on top
  /// ([rowsOf]).
  static const shell = [
    '############',
    '#..........#',
    '#..........#',
    '#..........#',
    '#..........#',
    '#..........#',
    '#..........#',
    '#####..#####',
  ];

  /// Door tiles (left corner, 2 wide) in the bottom wall.
  static const door = (5, 7);

  /// Tiles kept free for the door: the two in front of it.
  static const doorFront = [(5, 6), (6, 6)];

  /// Where a player stands on arrival: just inside the door.
  static const arrival = WorldPoint(6.0 * 16, 6.0 * 16 + 6);

  /// Map theme of the interior (never in `SkyRules.outdoorThemes`).
  static const indoorTheme = 'interior';

  /// The rows of [l]: solid furniture is `C` (a counter: solid, drawn by
  /// `HomeInteriorLayer`); rugs and wall pieces leave the tile as it is.
  static List<String> rowsOf(HomeLayout l) {
    final t = [for (final r in shell) r.split('')];
    for (final p in l.pieces) {
      final d = furniture(p.id);
      if (d == null || d.onWall || d.walkable) continue;
      for (var y = p.y; y < p.y + d.h; y++) {
        for (var x = p.x; x < p.x + d.w; x++) {
          if (y > 0 && y < height - 1 && x > 0 && x < width - 1) {
            t[y][x] = Tile.counter;
          }
        }
      }
    }
    return [for (final r in t) r.join()];
  }

  static final _maps = <String, GameMap>{};
  static final _layouts = Expando<HomeLayout>('homeLayout');

  /// The interior map of [l] (cached per layout). Its theme is not an
  /// outdoor one: no sky, clouds, rain or night indoors (§ 2).
  static GameMap map([HomeLayout l = kDefaultHomeLayout]) {
    final hit = _maps[l.key];
    if (hit != null) return hit;
    if (_maps.length > 16) _maps.clear();
    final m = GameMap(
      width: width,
      height: height,
      rows: rowsOf(l),
      theme: indoorTheme,
      spawn: arrival,
      lobby: true,
      place: place,
    );
    _layouts[m] = l;
    return _maps[l.key] = m;
  }

  /// The layout a map of the interior was built from (default otherwise).
  static HomeLayout layoutOfMap(GameMap? m) =>
      (m == null ? null : _layouts[m]) ?? kDefaultHomeLayout;

  /// Whose layout the room shows (§ 8.1): the world owner if inside,
  /// else the first human inside by id. `null` = nobody.
  static String? layoutOwner(GameSession s) {
    final humans = [
      for (final p in s.players.values)
        if (!p.isCompanion) p.id
    ]..sort();
    if (humans.isEmpty) return null;
    final o = s.ownerId;
    return o != null && humans.contains(o) ? o : humans.first;
  }

  /// The layout the room of [s] shows.
  static HomeLayout layoutOf(GameSession s) =>
      s.players[layoutOwner(s)]?.profile.home ?? kDefaultHomeLayout;

  /// Only town <-> home.
  static bool canTravel(String? from, String to) =>
      isHome(to) ? from == null : isHome(from) && to == kPueblo;

  // ---------------- the piece in town ----------------

  /// Gold the house costs (`playerHouseGold`).
  static int get price => t.i('playerHouseGold');

  /// How many player houses a town may have (`playerHouseMax`).
  static int get maxHouses => math.max(1, t.i('playerHouseMax'));

  static Iterable<TownBuild> housesOf(TownState s) =>
      s.builds.where((b) => b.kind == BuildKind.home);

  /// Why [p] cannot build the house in [s] now (`null` = it can).
  static String? cannotBuild(PlayerProfile p, TownState s) {
    if (housesOf(s).length >= maxHouses) return 'Ya hay una casa propia';
    if (p.credits < price) {
      return 'Te falta oro (tenés ${p.credits}, necesitás $price)';
    }
    return null;
  }

  /// Door tile of [b], relative to the town origin: bottom middle.
  static (int, int) doorOf(TownBuild b) {
    final r = b.bounds;
    return (r.x + r.w ~/ 2, r.bottom - 1);
  }

  /// Where a player lands back in town: in front of the house door (map
  /// px). Without a house, in front of the fountain spawn.
  static WorldPoint townFront(TownState s) {
    final b = housesOf(s).firstOrNull;
    if (b == null) return MapGenerator.townOf(s).spawn;
    final (dx, dy) = doorOf(b);
    final (ox, oy) = s.origin;
    return WorldPoint((dx + ox + 0.5) * 16, (dy + oy + 1) * 16 + 8.0);
  }

  /// [p] moved to the nearest walkable tile of the map it lands on.
  static WorldPoint safeLanding(String to, TownState town, WorldPoint p,
          [HomeLayout layout = kDefaultHomeLayout]) =>
      WorldRules.safeLanding(
          isHome(to) ? map(layout) : MapGenerator.town(town), p);

  // ---------------- inside ----------------

  static double _rectDist(double x, double y, int tx, int ty, int w, int h) {
    final x0 = tx * 16.0, y0 = ty * 16.0;
    final dx = math.max(math.max(x0 - x, 0.0), x - (x0 + w * 16));
    final dy = math.max(math.max(y0 - y, 0.0), y - (y0 + h * 16));
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Reach (px) to a piece of furniture or the door.
  static const reach = 12.0;

  /// The floor piece of [l] in reach of ([x], [y]) (of [kind] if given),
  /// the closest one, or `null`.
  static HomePiece? pieceNear(HomeLayout l, double x, double y,
      {FurnitureKind? kind}) {
    HomePiece? best;
    var bd = reach;
    for (final p in l.pieces) {
      final d = furniture(p.id);
      if (d == null || d.onWall || d.walkable) continue;
      if (kind != null && d.kind != kind) continue;
      final dist = _rectDist(x, y, p.x, p.y, d.w, d.h);
      if (dist < bd) (bd, best) = (dist, p);
    }
    return best;
  }

  /// Uid of the bed of [l] in reach of ([x], [y]), or `null`.
  static int? bedNear(HomeLayout l, double x, double y) =>
      pieceNear(l, x, y, kind: FurnitureKind.bed)?.uid;

  /// The piece of [l] on tile ([tx], [ty]) (the top one), or `null`.
  static HomePiece? pieceAt(HomeLayout l, int tx, int ty) {
    for (final p in l.pieces.reversed) {
      final d = furniture(p.id);
      if (d == null) continue;
      if (tx >= p.x && tx < p.x + d.w && ty >= p.y && ty < p.y + d.h) {
        return p;
      }
    }
    return null;
  }

  /// In reach of the exit door.
  static bool nearDoor(double x, double y) =>
      _rectDist(x, y, door.$1, door.$2, 2, 1) < reach;

  // ---------------- sleeping ----------------

  /// Humans (no companions) and how many of them are in bed.
  static (int, int) sleepers(Iterable<SessionPlayer> players) {
    var n = 0, inBed = 0;
    for (final p in players) {
      if (p.isCompanion) continue;
      n++;
      if (p.inBed) inBed++;
    }
    return (inBed, n);
  }

  /// Everyone connected is in bed (and there is someone).
  static bool allAsleep(Iterable<SessionPlayer> players) {
    final (x, n) = sleepers(players);
    return n > 0 && x == n;
  }

  /// Clock (seconds since dawn) the sleep wakes up at: fully light in the
  /// morning, or fully dark at nightfall.
  static double wakeClock({required bool toMorning}) {
    final d = math.max(1.0, SkyRules.t.d('duskSec'));
    return toMorning ? d : SkyRules.daySec + d;
  }

  /// Seconds of world time a sleep that starts at [sky] skips: at night
  /// (or before dawn) up to the next morning; by day up to nightfall.
  static double skipSeconds(SkyState sky) {
    final c = sky.clock;
    final len = SkyRules.length;
    if (SkyRules.isNight(sky)) {
      final wake = wakeClock(toMorning: true);
      // Before dawn of the same day (clock near 0) or after nightfall.
      return c < wake ? wake - c : len - c + wake;
    }
    final dusk = wakeClock(toMorning: false);
    return c < dusk ? dusk - c : len - c + dusk;
  }

  /// The construction def of the house.
  static ConstructionDef get def => construction(kPlayerHouseId)!;

  // ---------------- EDITAR CASA (§ 8) ----------------

  /// Town level for the furniture gates: the town tier (1 = the first).
  static int level(TownState s) => RenownRules.townTier(s).index + 1;

  /// Town level [id] (furniture or surface) asks for.
  static int levelOf(String id) => math.max(1, t.i('home_${id}_lvl'));

  /// What [id] costs: gold and, for a wall or floor, craft material.
  static HelperCost costOf(String id) {
    final s = homeSurface(id);
    final n = s == null || s.mat.isEmpty ? 0 : t.i('home_${id}_mat');
    return (
      gold: math.max(0, t.i('home_${id}_gold')),
      mats: {if (n > 0) s!.mat: n},
      level: levelOf(id),
    );
  }

  /// Gold to paint the walls.
  static int get paintGold => math.max(0, t.i('homePaintGold'));

  /// Why [p] cannot buy [id] in town [s] now (`null` = can).
  static String? cannotBuy(PlayerProfile p, TownState s, String id) {
    final lv = levelOf(id);
    if (level(s) < lv) {
      return 'Necesita el pueblo en nivel $lv (ahora: ${level(s)})';
    }
    return HelperRules.cannotPay(p, costOf(id));
  }

  /// Why [defId] cannot go with its corner on ([x], [y]) in [l]
  /// (`null` = it fits). [moving]: the uid being moved (ignored).
  /// Nothing ever overlaps anything else (§ 8.3).
  static String? cannotPlace(HomeLayout l, String defId, int x, int y,
      {int? moving}) {
    final d = furniture(defId);
    if (d == null) return 'No existe';
    if (d.onWall) {
      if (y != 0 || x < 1 || x + d.w > width - 1) {
        return 'Va en la pared del fondo';
      }
    } else if (x < 1 || y < 1 || x + d.w > width - 1 || y + d.h > height - 1) {
      return 'Fuera de la casa';
    }
    bool hit(int ox, int oy, int ow, int oh) =>
        x < ox + ow && ox < x + d.w && y < oy + oh && oy < y + d.h;
    if (!d.onWall) {
      for (final (fx, fy) in doorFront) {
        if (hit(fx, fy, 1, 1)) return 'Tapa la puerta';
      }
    }
    for (final o in l.pieces) {
      if (o.uid == moving) continue;
      final od = furniture(o.id);
      if (od == null || od.onWall != d.onWall) continue;
      if (hit(o.x, o.y, od.w, od.h)) return 'Se pisa con otro mueble';
    }
    // Every solid piece leaves a way from the door to all the floor.
    if (!d.walkable && !d.onWall) {
      final next = [
        for (final o in l.pieces)
          if (o.uid != moving) o,
        HomePiece(-1, defId, x, y),
      ];
      if (!_reachable(l.copyWith(pieces: next))) {
        return 'Así queda un rincón sin paso';
      }
    }
    return null;
  }

  /// Every free floor tile of [l] is reachable from the door.
  static bool _reachable(HomeLayout l) {
    final rows = rowsOf(l);
    bool open(int x, int y) => rows[y][x] == '.';
    final seen = <(int, int)>{};
    final todo = [doorFront.first];
    while (todo.isNotEmpty) {
      final (x, y) = todo.removeLast();
      if (!seen.add((x, y))) continue;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx, ny = y + dy;
        if (ny < 1 || ny >= height - 1 || nx < 1 || nx >= width - 1) continue;
        if (open(nx, ny) && !seen.contains((nx, ny))) todo.add((nx, ny));
      }
    }
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        if (open(x, y) && !seen.contains((x, y))) return false;
      }
    }
    return true;
  }

  /// Buys and places [defId] at ([x], [y]) in [p]'s house.
  static ({PlayerProfile? profile, String? error}) placePiece(
      PlayerProfile p, TownState s, String defId, int x, int y) {
    final why = cannotBuy(p, s, defId) ?? cannotPlace(p.home, defId, x, y);
    if (why != null) return (profile: null, error: why);
    final paid = HelperRules.pay(p, costOf(defId))!;
    final l = p.home;
    return (
      profile: paid.copyWith(
          home: l.copyWith(
              pieces: [...l.pieces, HomePiece(l.nextUid, defId, x, y)])),
      error: null,
    );
  }

  /// Moves piece [uid] of [p]'s house to ([x], [y]).
  static PlayerProfile? move(PlayerProfile p, int uid, int x, int y) {
    final l = p.home;
    final o = l.piece(uid);
    if (o == null || cannotPlace(l, o.id, x, y, moving: uid) != null) {
      return null;
    }
    return p.copyWith(
        home: l.copyWith(pieces: [
      for (final q in l.pieces) q.uid == uid ? q.copyWith(x: x, y: y) : q
    ]));
  }

  /// Why piece [uid] cannot be removed (`null` = can): one bed stays.
  static String? cannotRemove(HomeLayout l, int uid) {
    final o = l.piece(uid);
    if (o == null) return 'No existe';
    final beds = l.pieces
        .where((q) => furniture(q.id)?.kind == FurnitureKind.bed)
        .length;
    if (furniture(o.id)?.kind == FurnitureKind.bed && beds <= 1) {
      return 'Tiene que quedar una cama';
    }
    return null;
  }

  /// Removes piece [uid] (no refund; § 8.3).
  static PlayerProfile? remove(PlayerProfile p, int uid) {
    if (cannotRemove(p.home, uid) != null) return null;
    final l = p.home;
    return p.copyWith(
        home: l.copyWith(pieces: [...l.pieces.where((q) => q.uid != uid)]));
  }

  /// Changes the wall or floor material to [id] (§ 8.4).
  static ({PlayerProfile? profile, String? error}) surface(
      PlayerProfile p, TownState s, String id) {
    final d = homeSurface(id);
    if (d == null) return (profile: null, error: 'No existe');
    final l = p.home;
    if ((d.wall ? l.wall : l.floor) == id) {
      return (profile: null, error: 'Ya está puesto');
    }
    final why = cannotBuy(p, s, id);
    if (why != null) return (profile: null, error: why);
    final paid = HelperRules.pay(p, costOf(id))!;
    return (
      profile: paid.copyWith(
          home: d.wall ? l.copyWith(wall: id) : l.copyWith(floor: id)),
      error: null,
    );
  }

  /// Why the walls cannot take paint [i] (`null` = can).
  static String? cannotPaint(PlayerProfile p, int i) {
    if (i < 0 || i >= kHomePaints.length) return 'No existe';
    if (p.home.paint == i) return 'Ya está puesto';
    if (p.credits < paintGold) {
      return 'Falta oro (${p.credits}/$paintGold)';
    }
    return null;
  }

  /// Paints the walls with paint [i] of `kHomePaints`.
  static PlayerProfile? paint(PlayerProfile p, int i) {
    if (cannotPaint(p, i) != null) return null;
    return p.copyWith(
        credits: p.credits - paintGold, home: p.home.copyWith(paint: i));
  }

  /// Puts [weapons] (uids of [p]'s weapons, at most 3) on rack [uid].
  static PlayerProfile? rack(PlayerProfile p, int uid, List<String> weapons) {
    final l = p.home;
    final o = l.piece(uid);
    if (o == null || furniture(o.id)?.kind != FurnitureKind.rack) return null;
    final owned = {for (final i in p.items) i.uid};
    final ws = [
      for (final w in {...weapons})
        if (owned.contains(w)) w
    ].take(3).toList();
    return p.copyWith(
        home: l.copyWith(pieces: [
      for (final q in l.pieces) q.uid == uid ? q.copyWith(weapons: ws) : q
    ]));
  }

  // ---------------- daylight (§ 8.5) ----------------

  /// Floor patches the windows of [l] light up (tile rects and alpha
  /// 0-1): by day a patch under each window that leans with the sun; at
  /// night nothing. Strength from `LightRules.daylight`.
  static List<({double x, double y, double w, double h, double a})>
      daylight(HomeLayout l, SkyState sky) {
    final a = LightRules.daylight(sky);
    if (a <= 0) return const [];
    // The sun moves through the day: the patch leans right, then left.
    final f = (sky.clock / SkyRules.daySec).clamp(0.0, 1.0);
    final lean = (0.5 - f) * 1.6;
    return [
      for (final p in l.pieces)
        if (furniture(p.id) case final d?
            when d.kind == FurnitureKind.window)
          (x: p.x + 0.1 + lean, y: 1.0, w: d.w - 0.2, h: 2.6, a: a),
    ];
  }
}
