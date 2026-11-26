import '../data/path_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart' show Tile;
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'autotile.dart';
import 'renown_rules.dart';
import 'town_plan.dart';
import 'town_rules.dart';

/// Why a path material can't be painted now (town_editor.md § 4.6), in
/// the order they are checked: town level, gold, ore.
enum PathLockKind { level, gold, ore }

/// A lock with the numbers its tooltip shows; [item] is the ore id.
typedef PathLock = ({PathLockKind kind, int need, int have, String? item});

/// What one tile of a material costs.
typedef PathCost = ({int gold, int ore, String? item, int level});

/// Town paths drawn by hand (town_editor.md § 4.6). Pure; the numbers in
/// `kTuning[TuningId.town]`. The host runs [paint] / [erase] for every
/// `TownOp.paintPath` / `erasePath`.
abstract final class PathRules {
  static TuningDef get t => tuning(TuningId.town);

  static PathCost cost(TownPathDef d) => (
        gold: t.i('${d.key}Gold'),
        ore: d.ore == null ? 0 : t.i('${d.key}Ore'),
        item: d.ore,
        level: t.i('${d.key}Level'),
      );

  /// Town level (1 = the first `townTiers` step, renown_town_growth.md
  /// § 5.1).
  static int townLevel(TownState s) => RenownRules.townTier(s).index + 1;

  /// Why [p] can't paint [d] in [s] (`null` = unlocked and affordable).
  static PathLock? lock(PlayerProfile p, TownState s, TownPathDef d) {
    final c = cost(d);
    final lv = townLevel(s);
    if (lv < c.level) {
      return (kind: PathLockKind.level, need: c.level, have: lv, item: null);
    }
    if (p.credits < c.gold) {
      return (kind: PathLockKind.gold, need: c.gold, have: p.credits, item: null);
    }
    if (c.item case final item? when c.ore > 0) {
      final have = p.life.ore(item);
      if (have < c.ore) {
        return (kind: PathLockKind.ore, need: c.ore, have: have, item: item);
      }
    }
    return null;
  }

  /// The best material [s] has unlocked by level (ignores the purse):
  /// the CAMINOS tool starts on it.
  static TownPathDef bestUnlocked(TownState s) {
    final lv = townLevel(s);
    return kTownPaths.lastWhere((d) => cost(d).level <= lv,
        orElse: () => kTownPaths.first);
  }

  /// Why no path can go on base-town tile ([x], [y]) (`null` = ok): inside
  /// the town (not the tree border), on grass or path, not on a place, a
  /// building, its sign or chest, nor a decoration.
  static String? tileError(TownState s, int x, int y) {
    if (TownRules.lightError(s, x, y, ignore: (x, y)) case final e?) return e;
    if (s.decor.any((d) => d.$2 == x && d.$3 == y)) {
      return 'Ya hay una decoración';
    }
    return null;
  }

  /// Paint [id] on map tile ([mx], [my]) paying one tile; `null` if it
  /// can't (locked, bad tile, or that material is already there).
  static (PlayerProfile, TownState)? paint(
      PlayerProfile p, TownState s, String id, int mx, int my) {
    final d = townPath(id);
    if (d == null || lock(p, s, d) != null) return null;
    final (ox, oy) = s.origin;
    final at = (mx - ox, my - oy);
    if (s.paths[at] == id || tileError(s, at.$1, at.$2) != null) return null;
    final c = cost(d);
    var next = p.copyWith(credits: p.credits - c.gold);
    if (c.item case final item? when c.ore > 0) {
      next = next.copyWith(
          life: next.life.copyWith(
              ores: {...next.life.ores, item: next.life.ore(item) - c.ore}));
    }
    return (next, s.copyWith(paths: {...s.paths, at: id}));
  }

  /// Why the path on map tile ([mx], [my]) can't be erased (`null` = ok):
  /// only hand-drawn tiles go; fixed and auto paths are the town's.
  static String? eraseError(TownState s, int mx, int my) {
    final (ox, oy) = s.origin;
    if (s.paths.containsKey((mx - ox, my - oy))) return null;
    return TownPlan.of(s).at(mx, my) == Tile.path
        ? 'Este camino lo traza el pueblo'
        : 'Ahí no hay camino';
  }

  /// Erase the hand-drawn path on map tile ([mx], [my]) (no refund, like
  /// decorations); `null` if there is none.
  static TownState? erase(TownState s, int mx, int my) {
    if (eraseError(s, mx, my) != null) return null;
    final (ox, oy) = s.origin;
    return s.copyWith(
        paths: {...s.paths}..remove((mx - ox, my - oy)));
  }

  /// Autotile mask of the path on map tile ([x], [y]) of [plan]: its
  /// N / E / S / W neighbours that are path of the same material.
  static int mask(TownPlan plan, int x, int y) {
    final m = plan.materialAt(x, y);
    if (m == null) return 0;
    return Autotile.mask4((dx, dy) => plan.materialAt(x + dx, y + dy) == m);
  }
}
