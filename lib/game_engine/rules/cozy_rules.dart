import 'dart:math' as math;

import '../data/cozy_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import '../models/life_skills.dart';
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'biome_regions.dart' show BiomeLayout;
import 'town_rules.dart';
import 'wild_loot_rules.dart';

/// A cozy ambience sound (cozy_life.md § 1–2).
enum CozySound { water, bird, cricket, rain }

/// A profession journal of the DIARIO (cozy_life.md § 4).
enum ProfessionJournal { fishing, mining, farming }

/// Cozy life rules (docs/specs/cozy_life.md). Pure: the host and the
/// client use the same ones.
abstract final class CozyRules {
  static TuningDef get t => tuning(TuningId.regions);

  // ---------------- fishing calm (§ 1) ----------------

  // The fishing zoom is an integer world-zoom level (WorldZoomRules).
  static double get hudOpacity => t.d('cozyHudOpacity').clamp(0.1, 1.0);
  static int get fireflies => t.i('cozyFireflies').clamp(0, 40);
  static double get musicLevel => t.d('cozyMusicLevel').clamp(0.0, 1.0);

  /// Seconds until the next ambience sound ([r] in 0..1).
  static double nextGapSec(double r) {
    final lo = t.d('cozyAmbGapMinSec');
    final hi = math.max(lo, t.d('cozyAmbGapMaxSec'));
    return lo + (hi - lo) * r.clamp(0.0, 1.0);
  }

  /// The sounds that fit: by the water (fishing / raft) or in a farm, by
  /// day or night, with or without rain. Never empty.
  static List<CozySound> sounds(
          {required bool night, bool rain = false, bool water = false}) =>
      [
        if (water) CozySound.water,
        if (rain) CozySound.rain,
        night ? CozySound.cricket : CozySound.bird,
      ];

  /// One of [sounds] by [r] (0..1).
  static CozySound pick(List<CozySound> sounds, double r) =>
      sounds[(r.clamp(0.0, 0.999999) * sounds.length).floor()];

  // ---------------- raft decorations (§ 1) ----------------

  static int raftCost(String id) {
    final d = kRaftDecos[id];
    return d == null ? 0 : t.i(d.costKey);
  }

  /// Buy [id] (and show it) or, if owned, toggle it. A paint replaces the
  /// other paint. `null` = not possible (unknown, no gold).
  static PlayerProfile? raftDeco(PlayerProfile p, String id) {
    final d = kRaftDecos[id];
    if (d == null) return null;
    final life = p.life;
    var credits = p.credits;
    var owned = life.raftDecos;
    if (!owned.contains(id)) {
      final cost = raftCost(id);
      if (credits < cost) return null;
      credits -= cost;
      owned = {...owned, id};
    }
    final on = {...life.raftOn};
    if (on.contains(id)) {
      on.remove(id);
    } else {
      if (d.slot == RaftDecoSlot.paint) {
        on.removeWhere((o) => kRaftDecos[o]?.slot == RaftDecoSlot.paint);
      }
      on.add(id);
    }
    return p.copyWith(
        credits: credits, life: life.copyWith(raftDecos: owned, raftOn: on));
  }

  /// Paint colour index shown on the raft (`null` = bare wood).
  static int? paintOf(LifeSkills l) {
    for (final id in l.raftOn) {
      if (kRaftDecos[id]?.paint case final p?) return p;
    }
    return null;
  }

  static bool hasLantern(LifeSkills l) => l.raftOn.contains('lantern');
  static bool hasRoof(LifeSkills l) => l.raftOn.contains('roof');

  // ---------------- farm decorations (§ 2) ----------------

  static int decorCost(String id) {
    final d = kFarmDecos[id];
    return d == null ? 0 : t.i(d.costKey);
  }

  /// Why a decoration can't go on base-town tile ([x], [y]) (`null` =
  /// ok). Same spots as a lighthouse, and not on another decoration.
  static String? decorError(TownState s, int x, int y, {(int, int)? ignore}) {
    if (s.decor.any((d) => (d.$2, d.$3) != ignore && d.$2 == x && d.$3 == y)) {
      return 'Ya hay una decoración';
    }
    return TownRules.lightError(s, x, y);
  }

  /// Buy and place [id] on map tile ([mx], [my]).
  static (PlayerProfile, TownState)? placeDecor(
      PlayerProfile p, TownState s, String id, int mx, int my) {
    if (!kFarmDecos.containsKey(id)) return null;
    final (ox, oy) = s.origin;
    if (decorError(s, mx - ox, my - oy) != null) return null;
    final cost = decorCost(id);
    if (p.credits < cost) return null;
    return (
      p.copyWith(credits: p.credits - cost),
      s.copyWith(decor: [...s.decor, (id, mx - ox, my - oy)]),
    );
  }

  static TownState? moveDecor(TownState s, String id, int mx, int my) {
    final from = TownState.parseDecorId(id);
    if (from == null) return null;
    final i = s.decor.indexWhere((d) => (d.$2, d.$3) == from);
    if (i < 0) return null;
    final (ox, oy) = s.origin;
    final to = (mx - ox, my - oy);
    if (decorError(s, to.$1, to.$2, ignore: from) != null) return null;
    return s.copyWith(decor: [
      for (var j = 0; j < s.decor.length; j++)
        j == i ? (s.decor[j].$1, to.$1, to.$2) : s.decor[j],
    ]);
  }

  /// Remove a decoration (no refund, like the lighthouse).
  static TownState? removeDecor(TownState s, String id) {
    final at = TownState.parseDecorId(id);
    if (at == null || !s.decor.any((d) => (d.$2, d.$3) == at)) return null;
    return s.copyWith(decor: [...s.decor.where((d) => (d.$2, d.$3) != at)]);
  }

  /// The decoration on map tile ([mx], [my]), or `null`.
  static (String, int, int)? decorAt(TownState s, int mx, int my) {
    final (ox, oy) = s.origin;
    for (final d in s.decor) {
      if (d.$2 == mx - ox && d.$3 == my - oy) return d;
    }
    return null;
  }

  /// Quality bias of a plot on map tile ([mx], [my]): a scarecrow within
  /// `scarecrowRadius` tiles adds `scarecrowQualityBias` (once).
  static double scarecrowBias(TownState s, int mx, int my) {
    final (ox, oy) = s.origin;
    final r = t.d('scarecrowRadius');
    for (final d in s.decor) {
      if (d.$1 != 'scarecrow') continue;
      final dx = d.$2 + ox - mx, dy = d.$3 + oy - my;
      if (dx * dx + dy * dy <= r * r) return t.d('scarecrowQualityBias');
    }
    return 0;
  }

  // ---------------- hold to gather (§ 3) ----------------

  /// Seconds of E held to gather at Cultivo [level].
  static double gatherHoldSec(int level) {
    final base = t.d('gatherHoldSec');
    final k = 1 - t.d('gatherSpeedPerLevel') * math.max(0, level - 1);
    return math.max(t.d('gatherHoldMinSec'), base * k);
  }

  /// Seconds between repeats of a held E / click (§ 3, hold = repeat).
  static double get holdRepeatSec => t.d('holdRepeatSec');

  /// Reach of the action cursor in tiles (controls.md § Cursor de acción).
  static int get actionReach => t.i('actionReachTiles').clamp(1, 3);

  // ---------------- tree search (§ 3) ----------------

  /// `town.daily` key of [player] searching tree ([x], [y]) of [biome] on
  /// [day]. Under the wilds loot prefix (same pruning and layout
  /// migration) and with [BiomeLayout.version]: a regenerated layout puts
  /// other trees on those tiles.
  static String searchKey(String player, String biome, int x, int y, int day) =>
      '${WildLootRules.prefix}$player:$biome:v${BiomeLayout.version}:'
      't$x.$y:$day';

  /// Stable 0..1 roll of tree ([x], [y]) of [biome] on [day] (FNV-1a:
  /// the same on every peer, no wire state).
  static double searchRollFor(String biome, int day, int x, int y) {
    var h = 0x811c9dc5;
    for (final c in '$biome:$day:$x.$y'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    h ^= h >> 15;
    h = (h * 0x2c1b3c6d) & 0xffffffff;
    h ^= h >> 12;
    return (h & 0xffffff) / 0x1000000;
  }

  /// Tree ([x], [y]) of [map] can be searched today (§ 3): a `T` tile
  /// with a walkable side, picked by [searchRollFor] < `treeSearchFraction`.
  static bool searchable(GameMap map, String biome, int day, int x, int y) {
    if (x < 0 || y < 0 || x >= map.width || y >= map.height) return false;
    if (map.tileAt(x, y) != Tile.tree) return false;
    if (searchRollFor(biome, day, x, y) >= t.d('treeSearchFraction')) {
      return false;
    }
    for (final (dx, dy) in const [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= map.width || ny >= map.height) continue;
      if (Tile.isWalkable(map.tileAt(nx, ny))) return true;
    }
    return false;
  }

  static bool searched(
          TownState town, String player, String biome, int x, int y) =>
      town.daily.containsKey(searchKey(player, biome, x, y, town.sky.day));

  /// What a search finds, by one roll [r] (0..1).
  static SearchFind searchRoll(double r) {
    var x = r.clamp(0.0, 0.999999);
    for (final (f, k) in const [
      (SearchFind.recipe, 'searchRecipeChance'),
      (SearchFind.nest, 'searchNestChance'),
      (SearchFind.mushroom, 'searchMushroomChance'),
      (SearchFind.seed, 'searchSeedChance'),
    ]) {
      final c = t.d(k);
      if (x < c) return f;
      x -= c;
    }
    return SearchFind.nothing;
  }

  /// A compost recipe [known] doesn't have yet, by [r] (`null` = all).
  static String? newRecipe(Set<String> known, double r) {
    final left = [
      for (final id in kCompostRecipes.keys)
        if (!known.contains(id)) id
    ];
    if (left.isEmpty) return null;
    return left[(r.clamp(0.0, 0.999999) * left.length).floor()];
  }

  /// [f] after preparing [recipe] once (`null` = unknown or missing
  /// inputs). [bonus]: the Abono sub-path (`LifeFx.compost`) makes more bags.
  static FarmSkills? compost(FarmSkills f, String recipe, {double bonus = 0}) {
    final c = kCompostRecipes[recipe];
    if (c == null || !f.recipes.contains(recipe)) return null;
    final crops = {...f.crops};
    for (final e in c.inputs.entries) {
      final have = crops[e.key] ?? 0;
      if (have < e.value) return null;
      crops[e.key] = have - e.value;
    }
    return f.copyWith(
        crops: crops,
        ferts: {
          ...f.ferts,
          c.fert: f.fertCount(c.fert) + (c.makes * (1 + bonus)).round(),
        });
  }

  /// Can [f] prepare [recipe] now.
  static bool canCompost(FarmSkills f, String recipe) =>
      compost(f, recipe) != null;

  /// The mushroom a search gives ([kCrops] id).
  static const mushroom = 'hongo_ambar';

  /// Nest: worms (`kBaits`) and how many.
  static const nestBait = 'lombriz';
  static const nestBaits = 2;

  // ---------------- journals (§ 4) ----------------

  /// The journals of the professions [l] has (something done in them).
  static List<ProfessionJournal> journals(LifeSkills l) => [
        if (l.fishXp > 0 || l.log.isNotEmpty) ProfessionJournal.fishing,
        if (l.smithXp > 0 || l.oreLog.isNotEmpty) ProfessionJournal.mining,
        if (l.farm.xp > 0 ||
            l.farm.cropLog.isNotEmpty ||
            l.farm.recipes.isNotEmpty)
          ProfessionJournal.farming,
      ];

  /// Seeds known to [f]: held or ever harvested (catalog order).
  static List<String> knownSeeds(FarmSkills f) => [
        for (final id in kCrops.keys)
          if (f.seedCount(id) > 0 || f.cropLog.containsKey(id)) id
      ];
}
