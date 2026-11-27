import 'dart:math' as math;

import '../data/biomes_catalog.dart' show kPueblo;
import '../data/construction_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import '../models/game_session.dart' show SessionPlayer;
import '../models/player_profile.dart';
import '../models/town_build.dart';
import '../models/world_save.dart' show TownState;
import 'map_generator.dart';
import 'sky_rules.dart';
import 'world_rules.dart';

/// The player house (docs/specs/player_house.md): a piece of EDITAR
/// PUEBLO whose door leads to a small interior with beds. Sleeping in a
/// bed skips to the next morning (or to nightfall by day) once every
/// human in the room is in bed. Pure data and rules, no Flutter.
abstract final class HomeInteriorRules {
  static TuningDef get t => tuning(TuningId.town);

  /// Place id of the interior (`GameSession.place`).
  static const place = 'home';

  static bool isHome(String? p) => p == place;

  static const width = 12;
  static const height = 8;

  /// `#` walls, `.` floor, `C` beds (solid, 1 x 2 each); the door is the
  /// two wall tiles at the bottom middle ([door]).
  static const rows = [
    '############',
    '#C.C..C.C..#',
    '#C.C..C.C..#',
    '#..........#',
    '#..........#',
    '#..........#',
    '#..........#',
    '#####..#####',
  ];

  /// Door tiles (left corner, 2 wide) in the bottom wall.
  static const door = (5, 7);

  /// Bed head tiles (each bed is 1 x 2: head and foot below), in order.
  static const bedTiles = [(1, 1), (3, 1), (6, 1), (8, 1)];

  /// Where a player stands on arrival: just inside the door.
  static const arrival = WorldPoint(6.0 * 16, 6.0 * 16 + 6);

  static GameMap? _map;

  /// The interior map (always the same). Its theme is not an outdoor
  /// one: no sky, clouds, rain or night indoors (§ 2).
  static GameMap map() => _map ??= GameMap(
        width: width,
        height: height,
        rows: rows,
        theme: indoorTheme,
        spawn: arrival,
        lobby: true,
        place: place,
      );

  /// Map theme of the interior (never in `SkyRules.outdoorThemes`).
  static const indoorTheme = 'interior';

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
  static WorldPoint safeLanding(String to, TownState town, WorldPoint p) =>
      WorldRules.safeLanding(isHome(to) ? map() : MapGenerator.town(town), p);

  // ---------------- inside ----------------

  static double _rectDist(double x, double y, int tx, int ty, int w, int h) {
    final x0 = tx * 16.0, y0 = ty * 16.0;
    final dx = math.max(math.max(x0 - x, 0.0), x - (x0 + w * 16));
    final dy = math.max(math.max(y0 - y, 0.0), y - (y0 + h * 16));
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Reach (px) to a bed or the door.
  static const reach = 12.0;

  /// Index of the bed in reach of ([x], [y]), or `null`.
  static int? bedNear(double x, double y) {
    int? best;
    var bd = reach;
    for (var i = 0; i < bedTiles.length; i++) {
      final (tx, ty) = bedTiles[i];
      final d = _rectDist(x, y, tx, ty, 1, 2);
      if (d < bd) (bd, best) = (d, i);
    }
    return best;
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

  /// Town landmark ids never overlap the house: the plan reserves them.
  static bool isHouse(TownBuild b) => b.kind == BuildKind.home;
}
