import 'dart:math' as math;

import '../data/cooking_catalog.dart' show mealKey;
import '../data/life_tree_catalog.dart';
import '../data/tuning_catalog.dart';
import '../data/weapons_catalog.dart' show kWeapons;
import '../models/item.dart' show CraftMaterial, ItemInstance;
import '../models/life_skills.dart' show kLifeMaterialIds;
import '../models/loot.dart' show LootDrop;
import '../models/player_profile.dart';
import 'farming_rules.dart';
import 'fishing_rules.dart';
import 'inventory_rules.dart';
import 'mining_rules.dart';

export '../data/life_tree_catalog.dart';

/// Profession trees v2 (docs/specs/life_trees_v2.md): points per level,
/// tiers gated by the profession level, chains per branch, one capstone
/// per tree, free reset, one-time rewards and the sum of the continuous
/// effects the fishing / farming / smithing / cooking rules read. Pure:
/// the host applies them.
abstract final class LifeTreeRules {
  static TuningDef get t => tuning(TuningId.lifeTree);

  static int level(PlayerProfile p, LifeSkillKind k) => switch (k) {
        LifeSkillKind.pesca => FishingRules.level(p),
        LifeSkillKind.cultivo => FarmingRules.level(p),
        LifeSkillKind.herreria => SmithRules.level(p),
      };

  static List<String> taken(PlayerProfile p, LifeSkillKind k) =>
      switch (k) {
        LifeSkillKind.pesca => p.life.fishTree,
        LifeSkillKind.cultivo => p.life.farm.tree,
        LifeSkillKind.herreria => p.life.smithTree,
      };

  static String rootOf(LifeSkillKind k) =>
      kLifeTrees[k]!.firstWhere((n) => n.root).id;

  /// Points earned: `(level − 1) × pointsPerLevel`.
  static int earned(PlayerProfile p, LifeSkillKind k) =>
      math.max(0, (level(p, k) - 1) * t.i('pointsPerLevel'));

  static int spent(PlayerProfile p, LifeSkillKind k) {
    var s = 0;
    for (final id in taken(p, k)) {
      s += lifeTreeNode(k, id)?.cost ?? 0;
    }
    return s;
  }

  static int free(PlayerProfile p, LifeSkillKind k) =>
      earned(p, k) - spent(p, k);

  /// All trees (for the PERSONAJE badge).
  static int freeTotal(PlayerProfile p) => [
        for (final k in LifeSkillKind.values) math.max(0, free(p, k)),
      ].fold(0, (a, b) => a + b);

  /// Profession level tier [tier] asks for (§ 2).
  static int tierLevel(int tier) =>
      tier <= 0 ? 1 : math.max(0, t.i('tierLevelStep')) * (tier - 1) + 1;

  static bool has(PlayerProfile p, LifeSkillKind k, String id) =>
      id == rootOf(k) || taken(p, k).contains(id);

  /// Whether the one-time rewards of [id] were already delivered.
  static bool claimed(PlayerProfile p, String id) =>
      p.life.claimed.contains(id);

  /// Why [id] can't be taken (or `null`).
  static String? cannotTake(PlayerProfile p, LifeSkillKind k, String id) {
    final n = lifeTreeNode(k, id);
    if (n == null) return 'Nodo desconocido';
    if (has(p, k, id)) return 'Ya lo tenés';
    final f = free(p, k);
    if (f < n.cost) return 'Faltan puntos ($f/${n.cost})';
    final need = tierLevel(n.tier);
    if (level(p, k) < need) return 'Pide nivel $need';
    if (!n.links.any((l) => has(p, k, l))) return 'No está conectado';
    final ex = n.exclusive;
    if (ex != null) {
      for (final o in taken(p, k)) {
        final on = lifeTreeNode(k, o);
        if (on != null && on.exclusive == ex) return 'Elegiste ${on.name}';
      }
    }
    if (!claimed(p, id) && n.grants.keys.any((g) => g.startsWith('weapon:'))) {
      final w = weaponFor(p, n);
      if (w != null &&
          InventoryRules.cannotReceive(p, LootDrop.item(w)) != null) {
        return 'Inventario lleno';
      }
    }
    return null;
  }

  static PlayerProfile _with(
          PlayerProfile p, LifeSkillKind k, List<String> nodes) =>
      switch (k) {
        LifeSkillKind.pesca =>
          p.copyWith(life: p.life.copyWith(fishTree: nodes)),
        LifeSkillKind.cultivo => p.copyWith(
            life: p.life.copyWith(farm: p.life.farm.copyWith(tree: nodes))),
        LifeSkillKind.herreria =>
          p.copyWith(life: p.life.copyWith(smithTree: nodes)),
      };

  /// Takes [id] and delivers its rewards the first time (§ 4).
  static PlayerProfile? take(PlayerProfile p, LifeSkillKind k, String id) {
    if (cannotTake(p, k, id) != null) return null;
    final next = _with(p, k, [...taken(p, k), id]);
    return claim(next, lifeTreeNode(k, id)!);
  }

  /// Free reset (like ascension): every point back; rewards stay.
  static PlayerProfile? reset(PlayerProfile p, LifeSkillKind k) =>
      taken(p, k).isEmpty ? null : _with(p, k, const []);

  /// Keeps the saved trees valid (existing, connected, no clash, enough
  /// points and level), in order. Never delivers rewards.
  static PlayerProfile sanitize(PlayerProfile p) {
    var out = p;
    for (final k in LifeSkillKind.values) {
      final want = taken(p, k);
      out = _with(out, k, const []);
      for (final id in want) {
        if (cannotTake(out, k, id) == null) {
          out = _with(out, k, [...taken(out, k), id]);
        }
      }
    }
    return out;
  }

  // ---------------- one-time rewards (§ 4) ----------------

  /// Amount of grant [key] of a node (Balance).
  static int amount(String key) => math.max(0, t.d(key).round());

  /// The Common weapon of [p]'s class a `weapon:<tier>` grant of [n]
  /// gives (the highest tier ≤ the asked one), or `null`.
  static ItemInstance? weaponFor(PlayerProfile p, LifeTreeNode n) {
    for (final g in n.grants.keys) {
      if (!g.startsWith('weapon:')) continue;
      final want = int.tryParse(g.substring(7)) ?? 0;
      final pool = [
        for (final w in kWeapons.values)
          if (w.classId == p.classId && w.tier <= want) w
      ]..sort((a, b) => b.tier.compareTo(a.tier));
      if (pool.isEmpty) return null;
      final w = pool.first;
      return ItemInstance.common('', w.id, itemLevel: w.level);
    }
    return null;
  }

  /// [p] with the rewards of [n] delivered (once; marks `life.lc`).
  static PlayerProfile claim(PlayerProfile p, LifeTreeNode n) {
    if (n.grants.isEmpty || claimed(p, n.id)) return p;
    var out = p;
    for (final e in n.grants.entries) {
      out = grant(out, n, e.key, amount(e.value));
    }
    return out.copyWith(
        life: out.life.copyWith(claimed: {...out.life.claimed, n.id}));
  }

  /// One grant [spec] × [n] (see [LifeTreeNode.grants]).
  static PlayerProfile grant(
      PlayerProfile p, LifeTreeNode node, String spec, int n) {
    if (n <= 0) return p;
    final parts = spec.split(':');
    final id = parts.length > 1 ? parts[1] : '';
    final life = p.life;
    switch (parts.first) {
      case 'gold':
        return p.copyWith(credits: p.credits + n);
      case 'mat':
        final m = CraftMaterial.values.where((m) => m.name == id).firstOrNull;
        if (m == null) return p;
        return p.copyWith(
            materials: {...p.materials, m: (p.materials[m] ?? 0) + n});
      case 'ore':
        return MiningRules.give(p, {id: n});
      case 'craft':
        if (!kLifeMaterialIds.contains(id)) return p;
        return p.copyWith(
            life: life
                .copyWith(crafts: {...life.crafts, id: life.craft(id) + n}));
      case 'bait':
        return p.copyWith(
            life: life.copyWith(
                baits: {...life.baits, id: (life.baits[id] ?? 0) + n}));
      case 'rod':
        return life.rods.contains(id)
            ? p
            : p.copyWith(life: life.copyWith(rods: [...life.rods, id]));
      case 'meal':
        final qi = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
        final q =
            CropQuality.values[qi.clamp(0, CropQuality.values.length - 1)];
        final key = mealKey(id, q);
        final f = life.farm;
        return p.copyWith(
            life: life.copyWith(
                farm: f.copyWith(
                    meals: {...f.meals, key: f.mealCount(key) + n})));
      case 'weapon':
        var out = p;
        for (var i = 0; i < n; i++) {
          final w = weaponFor(out, node);
          if (w == null) break;
          out = InventoryRules.receive(out, LootDrop.item(w)) ?? out;
        }
        return out;
    }
    return p;
  }

  // ---------------- continuous effects (§ 5) ----------------

  /// Sum of effect [fx] in tree [k] of [p] (root included).
  static double fx(PlayerProfile p, LifeSkillKind k, String fx) {
    var v = 0.0;
    for (final n in kLifeTrees[k]!) {
      if (!has(p, k, n.id)) continue;
      final key = n.effects[fx];
      if (key != null) v += t.d(key);
    }
    return v;
  }

  static double fish(PlayerProfile p, String f) =>
      fx(p, LifeSkillKind.pesca, f);
  static double farm(PlayerProfile p, String f) =>
      fx(p, LifeSkillKind.cultivo, f);
  static double smith(PlayerProfile p, String f) =>
      fx(p, LifeSkillKind.herreria, f);

  /// Sum of [f] over the three trees (adventurer power `hp` / `atk`,
  /// `meal`).
  static double power(PlayerProfile p, String f) => [
        for (final k in LifeSkillKind.values) fx(p, k, f),
      ].fold(0.0, (a, b) => a + b);

  /// Extra missions a meal lasts for [p] (`meal`).
  static int mealMissions(PlayerProfile p) =>
      math.max(0, power(p, LifeFx.meal).round());
}

/// Herrería (roles.md § 6): XP por forjar, encargos de forja y condensar.
abstract final class SmithRules {
  static TuningDef get t => LifeTreeRules.t;

  static int get maxLevel => math.max(1, t.i('smithMaxLevel'));

  static int xpNeed(int l) =>
      (t.d('smithXpBase') * math.pow(l, t.d('smithXpExp'))).round();

  static int levelFor(int xp) {
    var l = 1, rest = xp;
    while (l < maxLevel && rest >= xpNeed(l)) {
      rest -= xpNeed(l);
      l++;
    }
    return l;
  }

  static int level(PlayerProfile p) => levelFor(p.life.smithXp);

  static (int, int) progress(int xp) {
    var l = 1, rest = xp;
    while (l < maxLevel && rest >= xpNeed(l)) {
      rest -= xpNeed(l);
      l++;
    }
    return l >= maxLevel ? (0, 0) : (rest, xpNeed(l));
  }

  /// Suma [base] de XP de Herrería (con el bonus de XP del árbol).
  static PlayerProfile gain(PlayerProfile p, int base) {
    if (base <= 0) return p;
    final xp = (base * (1 + LifeTreeRules.smith(p, LifeFx.xp))).round();
    return p.copyWith(life: p.life.copyWith(smithXp: p.life.smithXp + xp));
  }

  /// Descuento de la forja del árbol (tope `smithForgeCap`).
  static double forgeDiscount(PlayerProfile p) => LifeTreeRules.smith(
          p, LifeFx.forge)
      .clamp(0.0, t.d('smithForgeCap'))
      .toDouble();
}
