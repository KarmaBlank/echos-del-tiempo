import 'dart:math' as math;

import '../data/bait_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/player_profile.dart';
import 'life_time_rules.dart';

export '../data/bait_catalog.dart';

/// Baits (docs/specs/fishing.md § 14). Pure; the host applies them on
/// every catch (manual and auto, same rule) and spends one per fish.
abstract final class BaitRules {
  static TuningDef get t => tuning(TuningId.fishing);

  static double bite(String id) => _d(id, 'Bite');
  static double rare(String id) => _d(id, 'Rare');
  static double size(String id) => _d(id, 'Size').clamp(0.0, 1.0);
  static int price(String id) => _d(id, 'Price').round();
  static int gold(String id) => _d(id, 'Gold').round();

  static double _d(String id, String what) {
    final b = kBaits[id];
    if (b == null) return 0;
    return (t.values['bait${b.key}$what'] ?? 0).toDouble();
  }

  /// Baits [p] owns, worst to best (catalog order).
  static List<String> owned(PlayerProfile p) => [
        for (final id in kBaits.keys)
          if (p.life.baitCount(id) > 0) id
      ];

  /// The bait on the hook: the picked one if any left, else the best
  /// owned; `null` = none.
  static String? active(PlayerProfile p) {
    final own = owned(p);
    if (own.isEmpty) return null;
    final pick = p.life.bait;
    return own.contains(pick) ? pick : own.last;
  }

  /// CEBO slot / F: the next owned bait.
  static PlayerProfile? cycle(PlayerProfile p) {
    final own = owned(p);
    if (own.length < 2) return null;
    final i = own.indexOf(active(p)!);
    return select(p, own[(i + 1) % own.length]);
  }

  static PlayerProfile? select(PlayerProfile p, String id) {
    if (p.life.baitCount(id) <= 0) return null;
    return p.copyWith(life: p.life.copyWith(bait: id));
  }

  /// [bait] attracts fish [fishId] (§ 14.2).
  static bool attracts(String bait, String fishId) {
    final b = kBaits[bait];
    final f = kFish[fishId];
    if (b == null || f == null) return false;
    if (b.species.contains(fishId)) return true;
    if (b.attractsRarity != null && f.rarity == b.attractsRarity) return true;
    if (b.weather != null && LifeTimeRules.fishWeather(fishId) == b.weather) {
      return true;
    }
    final seasons = LifeTimeRules.fishSeasons(fishId);
    return b.season != null && seasons.length < 4 && seasons.contains(b.season);
  }

  /// The best bait for a fish (the rarest that attracts it), for the
  /// COLECCIÓN detail; `null` = none in particular.
  static String? bestFor(String fishId) {
    String? best;
    for (final id in kBaits.keys) {
      if (attracts(id, fishId)) best = id;
    }
    return best;
  }

  /// The roll table with the fish [bait] attracts weighted ×
  /// `baitAffinity` (extra copies; the roll picks uniformly in a tier).
  static List<String> weighted(List<String> table, String? bait) {
    if (bait == null) return table;
    final extra = math.max(0, t.i('baitAffinity') - 1);
    if (extra == 0) return table;
    return [
      ...table,
      for (final id in table)
        if (attracts(bait, id))
          for (var i = 0; i < extra; i++) id,
    ];
  }

  /// Spends one [bait] of [p] (after a catch).
  static PlayerProfile consume(PlayerProfile p, String bait) =>
      p.life.baitCount(bait) <= 0
          ? p
          : p.copyWith(life: p.life.addBait(bait, -1));

  /// Buys [n] of [id] at the trader.
  static PlayerProfile? buy(PlayerProfile p, String id, [int n = 1]) {
    if (!kBaits.containsKey(id) || n <= 0) return null;
    final cost = price(id) * n;
    if (p.credits < cost) return null;
    return p.copyWith(
        credits: p.credits - cost, life: p.life.addBait(id, n));
  }

  /// Why a recipe cannot be made (`null` = it can).
  static String? craftBlock(PlayerProfile p, String id) {
    final b = kBaits[id];
    if (b == null) return 'unknown';
    final r = b.recipe;
    if (p.life.craft('cebo') < r.cebo) return 'cebo';
    if (r.item != null && _have(p, r.item!) < r.n) return 'item';
    if (p.credits < gold(id)) return 'gold';
    return null;
  }

  static int _have(PlayerProfile p, String item) => item.contains('@')
      ? p.life.farm.cropCount(item)
      : p.life.count(item);

  /// Crafts one batch of [id]: pressed baits + item + gold → baits.
  static PlayerProfile? craft(PlayerProfile p, String id) {
    if (craftBlock(p, id) != null) return null;
    final r = kBaits[id]!.recipe;
    var life = p.life.copyWith(
        crafts: {...p.life.crafts, 'cebo': p.life.craft('cebo') - r.cebo});
    final item = r.item;
    if (item != null && r.n > 0) {
      if (item.contains('@')) {
        final f = life.farm;
        life = life.copyWith(
            farm: f.copyWith(crops: {...f.crops, item: f.cropCount(item) - r.n}));
      } else {
        life = life.copyWith(bag: {...life.bag, item: life.count(item) - r.n});
      }
    }
    life = life.addBait(id, r.yield);
    return p.copyWith(credits: p.credits - gold(id), life: life);
  }

  /// A bait found in the water loot or a mine (§ 14.4): common ones
  /// more often. [roll] in [0, 1).
  static String foundBait(double roll) {
    const w = [6, 3, 2, 1, 0.3];
    final total = w.fold<double>(0, (a, b) => a + b);
    var x = roll.clamp(0.0, 0.9999) * total;
    final ids = kBaits.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      if (x < w[i]) return ids[i];
      x -= w[i];
    }
    return ids.first;
  }

  /// Unused guard for the crop namespace of recipes.
  static bool recipeItemKnown(String item) => item.contains('@')
      ? parseCropKey(item) != null
      : kFish.containsKey(item);
}
