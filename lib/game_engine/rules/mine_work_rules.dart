import 'dart:collection';
import 'dart:math' as math;

import '../data/mine_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import 'battle_engine.dart' show RandomSource;
import 'mining_rules.dart';

/// What happens in a mine level while time passes (docs/specs/
/// mining_smithing.md § 1.5, § 1.7, § 1.8): veins growing back out of
/// sight, hired miners and their cart. Pure; the host calls it.
abstract final class MineWorkRules {
  static TuningDef get t => MiningRules.t;

  // ---------------- veins growing back (§ 1.5) ----------------

  /// A tile is out of sight when it is outside every viewer's screen
  /// (`regrowSafeTiles` across, 60 % of that up and down) and outside
  /// every torch's light.
  static bool unseen(int x, int y, List<(double, double)> viewers,
      Iterable<(int, int)> torches) {
    final safe = math.max(1, t.i('regrowSafeTiles'));
    for (final (vx, vy) in viewers) {
      if ((x - vx).abs() < safe && (y - vy).abs() < safe * 0.6) return false;
    }
    const lit = kTorchReach * kTorchReach;
    for (final (tx, ty) in torches) {
      final dx = x - tx, dy = y - ty;
      if (dx * dx + dy * dy <= lit) return false;
    }
    return true;
  }

  /// Tiles a torch keeps lit (radius of the torch light, rounded up).
  static const kTorchReach = 7;

  /// [st] with the due veins grown back into intact rock near where they
  /// were, never in sight of [viewers] (tile coordinates). A vein with no
  /// hidden rock around waits.
  static MineLevelState regrowTick(MineLevel lvl, MineLevelState st,
      double now, List<(double, double)> viewers, RandomSource rand) {
    if (st.regrow.isEmpty) return st;
    final due = [
      for (final e in st.regrow.entries)
        if (e.value <= now) e.key
    ]..sort();
    if (due.isEmpty) return st;
    final torches = [for (final i in st.torches) lvl.xy(i)];
    final rad = math.max(1, t.i('regrowRadius'));
    var grown = st.grown, regrow = st.regrow;
    for (final i in due) {
      final (ox, oy) = lvl.xy(i);
      final code = MineTile.veins.contains(lvl.rows[oy][ox])
          ? lvl.rows[oy][ox]
          : (st.grown[i] ?? Tile.ore);
      final cands = <(int, int)>[];
      for (var y = oy - rad; y <= oy + rad; y++) {
        for (var x = ox - rad; x <= ox + rad; x++) {
          if (x < 0 || y < 0 || x >= lvl.width || y >= lvl.height) continue;
          final j = lvl.idx(x, y);
          if (st.dug.contains(j) || grown.containsKey(j)) continue;
          if (st.torches.contains(j)) continue;
          if (lvl.rows[y][x] != Tile.wall) continue;
          if (!unseen(x, y, viewers, torches)) continue;
          cands.add((x, y));
        }
      }
      if (cands.isEmpty) continue;
      final (gx, gy) = cands[(rand() * cands.length).floor() % cands.length];
      grown = {...grown, lvl.idx(gx, gy): code};
      regrow = {...regrow}..remove(i);
    }
    if (identical(regrow, st.regrow)) return st;
    return st.copyWith(grown: grown, regrow: regrow);
  }

  // ---------------- discovered veins (§ 1.11) ----------------

  /// [st] with the veins [who] discovers standing at tile ([px], [py]):
  /// veins within `discoverLit` tiles (their glow is plain to see) and
  /// veins showing on a tunnel face (next to walkable ground) within
  /// `discoverView` tiles. [detect]: the Pico sub-path B radius (tiles)
  /// inside which hidden veins are sensed through the rock.
  static MineLevelState discover(
      MineLevel lvl, MineLevelState st, String who, double px, double py,
      {double detect = 0}) {
    final lit = math.max(t.d('discoverLit'), detect),
        view = math.max(t.d('discoverView'), detect);
    final r = view.ceil();
    final cx = px.floor(), cy = py.floor();
    final had = st.knownBy(who);
    Set<int>? add;
    for (var y = math.max(0, cy - r); y <= math.min(lvl.height - 1, cy + r); y++) {
      for (var x = math.max(0, cx - r); x <= math.min(lvl.width - 1, cx + r); x++) {
        final i = lvl.idx(x, y);
        if (had.contains(i)) continue;
        if (!MineTile.veins.contains(MiningRules.tileAt(lvl, st, x, y))) {
          continue;
        }
        final d2 = (x + 0.5 - px) * (x + 0.5 - px) + (y + 0.5 - py) * (y + 0.5 - py);
        if (d2 > view * view) continue;
        var seen = d2 <= lit * lit;
        if (!seen) {
          for (final (dx, dy) in _n4) {
            if (Tile.isWalkable(MiningRules.tileAt(lvl, st, x + dx, y + dy))) {
              seen = true;
              break;
            }
          }
        }
        if (seen) (add ??= {}).add(i);
      }
    }
    if (add == null) return st;
    return st.copyWith(known: {...st.known, who: {...had, ...add}});
  }

  /// The veins [who] has on the minimap now: discovered and still veins.
  static List<(int, int, String)> knownVeins(
      MineLevel lvl, MineLevelState st, String who) => [
        for (final i in st.knownBy(who))
          if (lvl.xy(i) case (final x, final y)
              when MineTile.veins.contains(MiningRules.tileAt(lvl, st, x, y)))
            (x, y, MiningRules.tileAt(lvl, st, x, y))
      ];

  // ---------------- miners (§ 1.7) ----------------

  /// Where a new miner starts: next to the station.
  static (int, int) minerSpawn(MineLevel lvl) =>
      (lvl.station.$1 - 1, lvl.station.$2 + 1);

  static const _n4 = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  /// Cost of entering a tile for a miner (`null` = never): walking 1,
  /// breaking rock or a vein 4 + hits.
  static int? _cost(
      MineLevel lvl, MineLevelState st, int x, int y, int tier) {
    final c = MiningRules.tileAt(lvl, st, x, y);
    if (Tile.isWalkable(c)) return 1;
    if (!MineTile.breakable.contains(c)) return null;
    // Rock or a vein its pick cannot break: it routes around (§ 1.7).
    if (c != MineTile.wallTorch && MiningRules.reqTierOf(c, lvl.level) > tier) {
      return null;
    }
    return 4 + MiningRules.hits(c, lvl.level);
  }

  /// Gold and ingots to raise a miner's pick to [tier] (`null` = no
  /// such tier).
  static ({int gold, String ingot, int n})? upgradeCost(int tier) {
    final tool = mineTool(kMineTools
        .firstWhere((d) => d.tier == tier, orElse: () => kMineTools.first)
        .id);
    if (tier < 1 || tier > kMineTools.last.tier || tool?.ingot == null) {
      return null;
    }
    return (
      gold: t.i('minerUpGold') * tier,
      ingot: tool!.ingot!,
      n: t.i('minerUpIngots') * tier,
    );
  }

  /// What a miner gets from [code]: the vein's yield scaled down by
  /// `minerYield` (always less than a player; no tool bonus, no oil).
  static Map<String, int> minerYield(
      RandomSource rand, String biome, String code) {
    final got = MiningRules.veinYield(rand, biome, code: code);
    final k = t.d('minerYield');
    final out = <String, int>{};
    for (final e in got.entries) {
      final n = (e.value * k + rand() * 0.5).floor();
      if (n > 0) out[e.key] = n;
    }
    return out;
  }

  /// The first step of the cheapest route from ([x], [y]) to the nearest
  /// vein (Dijkstra over walking and digging; a vein entered is mined).
  /// `null` when no vein is left.
  static (int, int)? nextStep(
      MineLevel lvl, MineLevelState st, int x, int y, {int tier = 0}) {
    final w = lvl.width, h = lvl.height;
    final dist = List<int>.filled(w * h, 1 << 30);
    final from = List<int>.filled(w * h, -1);
    final start = lvl.idx(x, y);
    dist[start] = 0;
    final q = SplayTreeSet<(int, int)>(
        (a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2)
      ..add((0, start));
    while (q.isNotEmpty) {
      final cur = q.first;
      q.remove(cur);
      final (d, i) = cur;
      if (d > dist[i]) continue;
      final (cx, cy) = lvl.xy(i);
      if (i != start &&
          MineTile.veins.contains(MiningRules.tileAt(lvl, st, cx, cy))) {
        var k = i;
        while (from[k] != start) {
          k = from[k];
        }
        return lvl.xy(k);
      }
      for (final (dx, dy) in _n4) {
        final nx = cx + dx, ny = cy + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final c = _cost(lvl, st, nx, ny, tier);
        if (c == null) continue;
        final j = lvl.idx(nx, ny), nd = d + c;
        if (nd < dist[j]) {
          dist[j] = nd;
          from[j] = i;
          q.add((nd, j));
        }
      }
    }
    return null;
  }

  /// One work step of every miner of [st] (every `minerStepSec`): walk,
  /// dig toward the nearest vein, mine it into the cart and light the
  /// tunnel with a torch every `minerTorchEvery` tiles. Paused while the
  /// cart is away or there is no station.
  static MineLevelState minerStep(MineLevel lvl, MineLevelState st,
      double now, RandomSource rand) {
    if (!st.station || st.miners.isEmpty) return st;
    if (st.cart.phase != CartPhase.mine) return st;
    var cur = st;
    final miners = <MinerState>[];
    for (final m0 in st.miners) {
      var m = m0;
      final step = nextStep(lvl, cur, m.x, m.y, tier: m.tier);
      if (step == null) {
        miners.add(m);
        continue;
      }
      final (sx, sy) = step;
      final code = MiningRules.tileAt(lvl, cur, sx, sy);
      if (Tile.isWalkable(code)) {
        m = m.copyWith(x: sx, y: sy, work: 0);
      } else {
        final work = m.work + math.max(1, t.i('minerPower')).toInt();
        if (work < MiningRules.hits(code, lvl.level)) {
          m = m.copyWith(work: work);
        } else {
          cur = MiningRules.dig(lvl, cur, sx, sy, now);
          if (MineTile.veins.contains(code) || code == MineTile.crystal) {
            final got = minerYield(rand, lvl.biome, code);
            final load = {...cur.cart.load};
            for (final e in got.entries) {
              load[e.key] = (load[e.key] ?? 0) + e.value;
            }
            cur = cur.copyWith(cart: cur.cart.copyWith(load: load));
          }
          var since = m.sinceTorch + 1;
          if (since >= math.max(1, t.i('minerTorchEvery')) &&
              !cur.torches.contains(lvl.idx(m.x, m.y))) {
            cur = cur.copyWith(torches: {...cur.torches, lvl.idx(m.x, m.y)});
            since = 0;
          }
          m = m.copyWith(
              x: sx,
              y: sy,
              work: 0,
              sinceTorch: since,
              stat: m.stat.copyWith(xp: (m.stat.xp + 1).round()));
        }
      }
      miners.add(m);
    }
    cur = cur.copyWith(miners: miners);
    if (cur.cart.total >= math.max(1, t.i('cartCap'))) {
      cur = cur.copyWith(cart: cur.cart.copyWith(phase: CartPhase.toTown, t: now));
    }
    return cur;
  }

  // ---------------- carts (§ 1.8) ----------------

  /// [c] after the time passes: a cart rolling to town parks there after
  /// `cartTravelSec`; one rolling back is at its mine `cartBackSec` after
  /// being unloaded.
  static MineCart cartTick(MineCart c, double now) {
    switch (c.phase) {
      case CartPhase.toTown:
        final at = c.t + t.d('cartTravelSec');
        return now >= at ? c.copyWith(phase: CartPhase.town, t: at) : c;
      case CartPhase.back:
        final at = c.t + t.d('cartBackSec');
        return now >= at
            ? MineCart(phase: CartPhase.mine, t: at)
            : c;
      case CartPhase.mine || CartPhase.town:
        return c;
    }
  }

  /// Seconds until a cart rolling to town arrives (0 when parked).
  static double arriveIn(MineCart c, double now) => c.phase == CartPhase.toTown
      ? math.max(0, c.t + t.d('cartTravelSec') - now)
      : 0;

  /// The carts parked or arriving in town, by mine level place, oldest
  /// first.
  static List<(String, MineCart)> townCarts(MinesState mines) => [
        for (final k in (mines.keys.toList()..sort()))
          if (mines[k]!.cart.phase != CartPhase.mine) (k, mines[k]!.cart)
      ]..sort((a, b) => a.$2.t.compareTo(b.$2.t));

  /// Unloading: the cart of [st] (parked in town) rolls back empty. Its
  /// load is returned.
  static (MineLevelState, Map<String, int>)? unload(
      MineLevelState st, double now) {
    if (st.cart.phase != CartPhase.town) return null;
    return (
      st.copyWith(cart: MineCart(phase: CartPhase.back, t: now)),
      st.cart.load,
    );
  }
}
