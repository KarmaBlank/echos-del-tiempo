import '../data/renown_catalog.dart';
import '../data/town_dressing_catalog.dart';
import '../models/game_map.dart';
import '../models/world_save.dart';
import 'renown_rules.dart';

/// What the town shows today: its tier dressing and, if an event is on,
/// the event dressing (renown_town_growth.md § 5.2 and § 6.4).
class TownDressing {
  const TownDressing(this.tierIndex, this.tier, [this.eventKind, this.event]);
  final int tierIndex;
  final TownTierDressing tier;
  final TownEventKind? eventKind;
  final TownEventDressing? event;

  @override
  bool operator ==(Object other) =>
      other is TownDressing &&
      other.tierIndex == tierIndex &&
      other.eventKind == eventKind;
  @override
  int get hashCode => Object.hash(tierIndex, eventKind);
}

/// Where each prop goes, in map tiles (pure; computed once per map and
/// dressing, then cached by the layer).
class TownDressingLayout {
  const TownDressingLayout({
    this.lamps = const [],
    this.fences = const [],
    this.banners = const [],
    this.well,
    this.board,
    this.plaza = const [],
    this.roofs = const [],
    this.garlands = const [],
    this.stalls = const [],
    this.centre,
    this.crowd = const [],
  });
  final List<(int, int)> lamps, fences, banners, plaza, stalls, crowd;

  /// Top-left tile of each house cluster (for the roof trim).
  final List<(int, int)> roofs;
  final (int, int)? well, board, centre;

  /// Garland spans between two house tops.
  final List<((int, int), (int, int))> garlands;
}

abstract final class TownDressingRules {
  /// Tier dressing for a `townTiers` index (below 0 = the first one).
  static TownTierDressing tierDressing(int index) =>
      kTownTierDressing[index.clamp(0, kTownTierDressing.length - 1)];

  /// The kind of the town event on today, or `null` (§ 6.1: `day ==
  /// scheduled`). Several on the same day: the festival wins.
  static TownEventKind? eventToday(TownState t, int day, [RenownConfig? cfg]) {
    TownEventKind? kind;
    for (final d in (cfg ?? kRenown).events) {
      if (t.renown.scheduled[d.id] != day) continue;
      if (d.kind == TownEventKind.festival) return d.kind;
      kind = d.kind;
    }
    return kind;
  }

  static TownDressing of(int tierIndex, TownEventKind? kind) {
    final i = tierIndex.clamp(0, kTownTierDressing.length - 1);
    return TownDressing(i, kTownTierDressing[i], kind,
        kind == null ? null : kTownEventDressing[kind]);
  }

  /// Today's dressing of [t].
  static TownDressing select(TownState t, int day, [RenownConfig? cfg]) =>
      of(RenownRules.townTier(t, cfg).index, eventToday(t, day, cfg));

  static bool _walk(String ch) =>
      ch == Tile.grass || ch == Tile.floor || ch == Tile.path;

  /// Picks the spots inside the town rectangle ([ox], [oy], [w], [h]).
  /// Props only go on walkable non-path tiles (never on path, so the map
  /// stays playable: they are decoration, drawn but not solid).
  static TownDressingLayout layout(GameMap map, TownDressing d,
      {int ox = 0, int oy = 0, int w = 26, int h = 14}) {
    final x1 = (ox + w).clamp(0, map.width), y1 = (oy + h).clamp(0, map.height);
    final x0 = ox.clamp(0, map.width), y0 = oy.clamp(0, map.height);
    String at(int x, int y) =>
        x < 0 || y < 0 || x >= map.width || y >= map.height
            ? Tile.wall
            : map.tileAt(x, y);
    final used = <(int, int)>{};
    bool free(int x, int y) =>
        x >= x0 && y >= y0 && x < x1 && y < y1 &&
        at(x, y) == Tile.grass && !used.contains((x, y));
    bool nearPath(int x, int y) => [
          (1, 0), (-1, 0), (0, 1), (0, -1)
        ].any((o) => at(x + o.$1, y + o.$2) == Tile.path);

    // Fountain centre (plaza / centrepiece anchor); else the town middle.
    (int, int)? fountain;
    for (var y = y0; y < y1 && fountain == null; y++) {
      for (var x = x0; x < x1; x++) {
        if (at(x, y) == Tile.fountain) {
          fountain = (x, y);
          break;
        }
      }
    }
    final mid = fountain ?? (x0 + (x1 - x0) ~/ 2, y0 + (y1 - y0) ~/ 2);

    // Nearest free tiles to [p], in a stable order.
    List<(int, int)> around((int, int) p, int r, bool Function(int, int) ok) {
      final out = <(int, int)>[];
      for (var y = p.$2 - r; y <= p.$2 + r; y++) {
        for (var x = p.$1 - r; x <= p.$1 + r; x++) {
          if (ok(x, y)) out.add((x, y));
        }
      }
      int dist((int, int) a) =>
          (a.$1 - p.$1) * (a.$1 - p.$1) + (a.$2 - p.$2) * (a.$2 - p.$2);
      out.sort((a, b) => dist(a).compareTo(dist(b)));
      return out;
    }

    (int, int)? take((int, int) p, int r, [bool Function(int, int)? ok]) {
      final c = around(p, r, ok ?? free).firstOrNull;
      if (c != null) used.add(c);
      return c;
    }

    final plaza = <(int, int)>[];
    if (d.tier.plaza) {
      for (final p in around(mid, 2, (x, y) =>
          x >= x0 && y >= y0 && x < x1 && y < y1 && _walk(at(x, y)))) {
        plaza.add(p);
      }
    }

    // House clusters: top-left of each connected run of house tiles.
    final roofs = <(int, int)>[];
    final seen = <(int, int)>{};
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        if (at(x, y) != Tile.house || seen.contains((x, y))) continue;
        final stack = [(x, y)];
        while (stack.isNotEmpty) {
          final q = stack.removeLast();
          if (!seen.add(q)) continue;
          for (final o in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final n = (q.$1 + o.$1, q.$2 + o.$2);
            if (at(n.$1, n.$2) == Tile.house && !seen.contains(n)) {
              stack.add(n);
            }
          }
        }
        roofs.add((x, y));
      }
    }

    // Lamp posts: grass next to a path, spread along it.
    final lamps = <(int, int)>[];
    if (d.tier.lampPosts > 0) {
      final cand = <(int, int)>[
        for (var y = y0; y < y1; y++)
          for (var x = x0; x < x1; x++)
            if (free(x, y) && nearPath(x, y)) (x, y)
      ];
      if (cand.isNotEmpty) {
        final n = d.tier.lampPosts.clamp(0, cand.length);
        for (var i = 0; i < n; i++) {
          final p = cand[(i * cand.length) ~/ n];
          lamps.add(p);
          used.add(p);
        }
      }
    }

    // Fences: the grass border of the town rectangle, every other tile
    // left open next to paths (gaps for the roads out).
    final fences = <(int, int)>[];
    if (d.tier.fences) {
      for (var x = x0; x < x1; x++) {
        for (final y in [y0, y1 - 1]) {
          if (free(x, y) && !nearPath(x, y)) fences.add((x, y));
        }
      }
      for (var y = y0 + 1; y < y1 - 1; y++) {
        for (final x in [x0, x1 - 1]) {
          if (free(x, y) && !nearPath(x, y)) fences.add((x, y));
        }
      }
      used.addAll(fences);
    }

    // Entrance banners: next to the path tiles on the town border.
    final banners = <(int, int)>[];
    if (d.tier.banners > 0) {
      for (var y = y0; y < y1 && banners.length < d.tier.banners; y++) {
        for (var x = x0; x < x1 && banners.length < d.tier.banners; x++) {
          final edge = x == x0 || y == y0 || x == x1 - 1 || y == y1 - 1;
          if (!edge || at(x, y) != Tile.path) continue;
          for (final o in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            if (banners.length >= d.tier.banners) break;
            final q = (x + o.$1, y + o.$2);
            if (free(q.$1, q.$2)) {
              banners.add(q);
              used.add(q);
            }
          }
        }
      }
    }

    final well = d.tier.well ? take(mid, 5) : null;
    final board = d.tier.noticeBoard ? take(mid, 5) : null;

    final ev = d.event;
    final garlands = <((int, int), (int, int))>[];
    final stalls = <(int, int)>[];
    final crowd = <(int, int)>[];
    (int, int)? centre;
    if (ev != null) {
      // Garlands between neighbouring houses (closest pairs first).
      final pairs = <((int, int), (int, int), int)>[];
      for (var i = 0; i < roofs.length; i++) {
        for (var j = i + 1; j < roofs.length; j++) {
          final a = roofs[i], b = roofs[j];
          final dd = (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs();
          if (dd <= 12) pairs.add((a, b, dd));
        }
      }
      pairs.sort((a, b) => a.$3.compareTo(b.$3));
      for (final p in pairs.take(ev.garlands)) {
        garlands.add((p.$1, p.$2));
      }
      centre = take(mid, 6, (x, y) => free(x, y) && free(x + 1, y));
      if (centre != null) used.add((centre.$1 + 1, centre.$2));
      for (var i = 0; i < ev.stalls; i++) {
        final s = take(mid, 7, (x, y) => free(x, y) && free(x + 1, y));
        if (s == null) break;
        used.add((s.$1 + 1, s.$2));
        stalls.add(s);
      }
      final ring = centre ?? mid;
      for (var i = 0; i < ev.crowd; i++) {
        final p = take(ring, 4, (x, y) => free(x, y) || (
            x >= x0 && y >= y0 && x < x1 && y < y1 &&
            at(x, y) == Tile.path && !used.contains((x, y))));
        if (p == null) break;
        crowd.add(p);
      }
    }

    return TownDressingLayout(
        lamps: lamps, fences: fences, banners: banners, well: well,
        board: board, plaza: plaza, roofs: roofs, garlands: garlands,
        stalls: stalls, centre: centre, crowd: crowd);
  }
}
