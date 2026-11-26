import 'dart:math' as math;

import '../data/biomes_catalog.dart' show kPueblo;
import '../data/town_layout.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import '../models/game_session.dart' show SessionPlayer;

/// Interior of the players' shop (docs/specs/player_shop.md § 6): a
/// separate lobby map entered through the TIENDA door in town, like a
/// mine. One counter per player inside; pure data, no Flutter.
abstract final class ShopInteriorRules {
  /// Place id of the interior (`GameSession.place`).
  static const place = 'shop';

  static bool isShop(String? p) => p == place;

  static const width = 16;
  static const height = 11;

  /// `#` walls and shelves, `.` floor, `C` counters; the door is the two
  /// wall tiles at the bottom middle ([door]).
  static const rows = [
    '################',
    '#####......#####',
    '#..............#',
    '#..CC......CC..#',
    '#..............#',
    '#..............#',
    '#..CC......CC..#',
    '#..............#',
    '#..............#',
    '#..............#',
    '#######..#######',
  ];

  /// Door tiles (left corner, 2 wide) in the bottom wall.
  static const door = (7, 10);

  /// Counter corners (2 x 1 tiles), in slot order.
  static const counterTiles = [(3, 3), (11, 3), (3, 6), (11, 6)];

  /// How many counters are in use (tunable, at most [counterTiles]).
  static int get counters => tuning(TuningId.town)
      .i('shopCounters')
      .clamp(1, counterTiles.length);

  /// Where a player stands on arrival: just inside the door.
  static const arrival = WorldPoint(8.0 * 16, 9.0 * 16 + 6);

  static GameMap? _map;

  /// The interior map (always the same).
  static GameMap map() => _map ??= GameMap(
        width: width,
        height: height,
        rows: rows,
        theme: TownLayout.theme,
        spawn: arrival,
        lobby: true,
        place: place,
      );

  /// Only town ↔ shop: the shop is entered from town and left to town.
  static bool canTravel(String? from, String to) =>
      isShop(to) ? from == null : isShop(from) && to == kPueblo;

  /// Where a player lands back in town: in front of the TIENDA door.
  static WorldPoint townFront(List<TownLandmark> marks) {
    final l = marks.firstWhere((l) => l.spot == TownSpot.shop,
        orElse: () => TownLayout.landmarks
            .firstWhere((l) => l.spot == TownSpot.shop));
    return WorldPoint((l.x + l.w / 2) * 16, (l.y + l.h) * 16 + 8.0);
  }

  /// Ids of the counter owners, in slot order: the players inside (no
  /// companions), sorted by id so every peer sees the same layout.
  static List<String> owners(Iterable<SessionPlayer> players) {
    final ids = [
      for (final p in players)
        if (!p.isCompanion) p.id
    ]..sort();
    return ids.take(counters).toList();
  }

  static double _rectDist(double x, double y, int tx, int ty, int w, int h) {
    final x0 = tx * 16.0, y0 = ty * 16.0;
    final dx = math.max(math.max(x0 - x, 0.0), x - (x0 + w * 16));
    final dy = math.max(math.max(y0 - y, 0.0), y - (y0 + h * 16));
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Reach (px) to a counter or the door.
  static const reach = 12.0;

  /// Slot of the counter in reach of ([x], [y]), or `null`.
  static int? counterNear(double x, double y) {
    int? best;
    var bd = reach;
    for (var i = 0; i < counters; i++) {
      final (tx, ty) = counterTiles[i];
      final d = _rectDist(x, y, tx, ty, 2, 1);
      if (d < bd) (bd, best) = (d, i);
    }
    return best;
  }

  /// In reach of the exit door.
  static bool nearDoor(double x, double y) =>
      _rectDist(x, y, door.$1, door.$2, 2, 1) < reach;
}
