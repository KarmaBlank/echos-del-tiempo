import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/weapon_passives.dart';
import '../models/item.dart';
import '../models/player_profile.dart';
import '../models/upgrade_stat.dart';
import '../models/weapon.dart';
import 'battle_engine.dart' show RandomSource;
import 'inventory_rules.dart';
import 'item_rules.dart';
import 'js_math.dart';
import 'loot_rules.dart';

/// Resultado (o vista previa) de una operación de forja / fusión. Las
/// operaciones son funciones puras: la misma llamada sirve de vista previa
/// ("antes → después") y de resultado. Las aleatorias ([CraftOp.addAffix],
/// [CraftOp.reroll], [CraftOp.upgradeRarity]) sin `RandomSource` solo
/// dicen el costo y qué puede salir ([outcomes]); [after] queda `null`.
class CraftResult {
  const CraftResult({
    this.error,
    this.profile,
    this.before,
    this.after,
    this.credits = 0,
    this.materials = const {},
    this.consumed = const [],
    this.replaced,
    this.outcomes = const [],
  });

  const CraftResult.fail(String this.error)
      : profile = null,
        before = null,
        after = null,
        credits = 0,
        materials = const {},
        consumed = const [],
        replaced = null,
        outcomes = const [];

  /// Motivo si no se puede (`null` = válida).
  final String? error;

  /// El perfil después (cobrado). `null` si no es válida o si es la vista
  /// previa de una operación aleatoria.
  final PlayerProfile? profile;
  final ItemInstance? before;
  final ItemInstance? after;

  /// Costo en créditos y materiales.
  final int credits;
  final Map<CraftMaterial, int> materials;

  /// `uid` de las armas que se destruyen.
  final List<String> consumed;

  /// Texto de lo que se reemplaza (habilidad o pasiva vieja).
  final String? replaced;

  /// Vista previa de una operación aleatoria: qué puede salir.
  final List<String> outcomes;

  bool get ok => error == null;
}

/// Forja y fusión libre sobre instancias (por `uid`).
class CraftRules {
  const CraftRules({this.loot = const LootRules()});

  final LootRules loot;

  ItemRules get items => loot.items;
  GameCatalog get catalog => items.catalog;
  InventoryRules get inventory => InventoryRules(items: items);

  // ------------------------------------------------------------------
  // Costos (loot.md § 16)
  // ------------------------------------------------------------------

  /// Costo del nivel de forja `l → l+1` de una estadística:
  /// `round(max(precio, 200) × 0.22 × (l + 1) × rareza)`.
  static int forgeCost(WeaponDef w, Rarity r, int level) =>
      jsRound(math.max(w.price, 200) * 0.22 * (level + 1) * r.costFactor);

  /// Peso del tier para los costos: T5 1, T4 2, T3 3, T2 5, T1 8, fijo 8.
  static int tierCost(int tier) => switch (tier) {
        5 => 1,
        4 => 2,
        3 => 3,
        2 => 5,
        _ => 8,
      };

  static int transferAffixCost(AffixRoll a, Rarity target) =>
      jsRound(100 * tierCost(a.tier) * target.costFactor);

  static int removeAffixCost(AffixRoll a, Rarity r) =>
      jsRound(50 * tierCost(a.tier) * r.costFactor);

  static int transferPassiveCost(Rarity target) =>
      jsRound(300 * target.costFactor);

  /// Trasladar una habilidad: ₵200 × rareza (Común = la fusión vieja).
  static int transferSkillCost(Rarity target) =>
      jsRound(200 * target.costFactor);

  static int addAffixCost(Rarity r) => jsRound(50 * r.costFactor);

  static int rerollCost(Rarity r) => jsRound(25 * r.costFactor);

  /// Prismas y créditos para subir desde [r] (`null` si no se puede).
  static (int, int)? upgradeRarityCost(Rarity r) => switch (r) {
        Rarity.comun => (1, 100),
        Rarity.magico => (2, 300),
        Rarity.raro => (4, 800),
        _ => null,
      };

  // ------------------------------------------------------------------
  // Forja
  // ------------------------------------------------------------------

  List<UpgradeStat> forgeStatsFor(WeaponDef w) => [
        UpgradeStat.pow,
        UpgradeStat.crit,
        UpgradeStat.spd,
        if (w.shieldDefense > 0) UpgradeStat.def,
      ];

  /// Subir 1 nivel [stat] del arma [uid]: tope 5 por estadística y tope
  /// total según rareza. Cada 2 niveles totales la pasiva sube 1.
  CraftResult forge(PlayerProfile p, String uid, UpgradeStat stat) {
    final it = p.itemByUid(uid);
    if (it == null) return const CraftResult.fail('No la tienes');
    final w = items.baseOf(it);
    if (w == null || !forgeStatsFor(w).contains(stat)) {
      return const CraftResult.fail('No se puede mejorar');
    }
    final l = it.forge.level(stat);
    if (l >= WeaponUpgradeLevels.upMax) return const CraftResult.fail('MAX');
    if (it.forgeLevel >= it.rarity.forgeCap) {
      return CraftResult.fail('Tope de forja (${it.rarity.forgeCap})');
    }
    final cost = forgeCost(w, it.rarity, l);
    final after = it.copyWith(forge: it.forge.withLevel(stat, l + 1));
    return _done(p, it, after, credits: cost);
  }

  // ------------------------------------------------------------------
  // Fusión libre
  // ------------------------------------------------------------------

  /// Valida el arma a sacrificar.
  String? _sacrificeError(PlayerProfile p, String targetUid, String sourceUid) {
    if (targetUid == sourceUid) return 'Elige otra arma';
    if (p.itemByUid(sourceUid) == null) return 'No la tienes';
    if (sourceUid == p.equippedUid) return 'Está equipada';
    if (inventory.isProtected(p, sourceUid)) return 'Arma inicial';
    return null;
  }

  CraftResult transferAffix(
      PlayerProfile p, String targetUid, String sourceUid, int index) {
    final t = p.itemByUid(targetUid);
    if (t == null) return const CraftResult.fail('No la tienes');
    final err = _sacrificeError(p, targetUid, sourceUid);
    if (err != null) return CraftResult.fail(err);
    final s = p.itemByUid(sourceUid)!;
    if (index < 0 || index >= s.affixes.length) {
      return const CraftResult.fail('Elige un afijo');
    }
    final a = s.affixes[index];
    if (a.fixed) return const CraftResult.fail('Mod fijo de un legendario');
    final def = items.affixOf(a);
    final w = items.baseOf(t);
    if (def == null || w == null || !def.allows(w.type)) {
      return const CraftResult.fail('No sale en este tipo de arma');
    }
    if (t.affixes.any((x) => x.affixId == a.affixId)) {
      return const CraftResult.fail('Ya tiene ese afijo');
    }
    if (!items.hasRoomFor(t, def)) {
      return CraftResult.fail('Sin lugar (${t.rarity.label}: '
          '${t.rarity.maxMods} mods, ${t.rarity.affixSideCap} '
          '${def.slot == AffixSlot.prefix ? 'prefijos' : 'sufijos'})');
    }
    final after = t.copyWith(affixes: [...t.affixes, a]);
    return _done(p, t, after,
        credits: transferAffixCost(a, t.rarity), consumed: [sourceUid]);
  }

  CraftResult transferPassive(
      PlayerProfile p, String targetUid, String sourceUid) {
    final t = p.itemByUid(targetUid);
    if (t == null) return const CraftResult.fail('No la tienes');
    final err = _sacrificeError(p, targetUid, sourceUid);
    if (err != null) return CraftResult.fail(err);
    final s = p.itemByUid(sourceUid)!;
    final sp = items.passiveOf(s);
    if (sp == null || !s.rarity.hasPassive) {
      return const CraftResult.fail('No tiene pasiva');
    }
    if (sp.unique) return const CraftResult.fail('Pasiva única');
    if (t.rarity != Rarity.epico) {
      return const CraftResult.fail('Solo a un arma Épica');
    }
    final old = items.passiveOf(t);
    final after =
        t.copyWith(passiveId: sp.id, passiveLevel: s.passiveLevel);
    return _done(p, t, after,
        credits: transferPassiveCost(t.rarity),
        consumed: [sourceUid],
        replaced: old == null || old.id == sp.id ? null : old.name);
  }

  CraftResult transferSkill(PlayerProfile p, String targetUid,
      String sourceUid, String skillId) {
    final t = p.itemByUid(targetUid);
    if (t == null) return const CraftResult.fail('No la tienes');
    final err = _sacrificeError(p, targetUid, sourceUid);
    if (err != null) return CraftResult.fail(err);
    final s = p.itemByUid(sourceUid)!;
    if (!items.skillsOf(s).contains(skillId) ||
        !catalog.skills.containsKey(skillId)) {
      return const CraftResult.fail('Elige una habilidad');
    }
    // Lleno: la nueva reemplaza a la más vieja (como la fusión vieja).
    final skills = [for (final x in t.extraSkills) if (x != skillId) x];
    String? replaced;
    while (skills.length >= t.rarity.skillSlots) {
      replaced = skills.removeAt(0);
    }
    final after = t.copyWith(extraSkills: [...skills, skillId]);
    return _done(p, t, after,
        credits: transferSkillCost(t.rarity),
        consumed: [sourceUid],
        replaced: replaced == null ? null : catalog.skills[replaced]?.name);
  }

  CraftResult removeAffix(PlayerProfile p, String uid, int index) {
    final t = p.itemByUid(uid);
    if (t == null) return const CraftResult.fail('No la tienes');
    if (index < 0 || index >= t.affixes.length) {
      return const CraftResult.fail('Elige un afijo');
    }
    final a = t.affixes[index];
    if (a.fixed) return const CraftResult.fail('Mod fijo de un legendario');
    final after = t.copyWith(affixes: [...t.affixes]..removeAt(index));
    return _done(p, t, after, credits: removeAffixCost(a, t.rarity));
  }

  /// Cristal de Era: un afijo aleatorio del pool (si hay lugar).
  CraftResult addAffix(PlayerProfile p, String uid, {RandomSource? random}) {
    final t = p.itemByUid(uid);
    if (t == null) return const CraftResult.fail('No la tienes');
    if (t.rarity == Rarity.comun) {
      return const CraftResult.fail('Un arma Común no lleva afijos');
    }
    final odds = loot.affixOdds(t);
    if (odds.isEmpty) return const CraftResult.fail('Sin lugar');
    final mats = {CraftMaterial.cristal: 1};
    final credits = addAffixCost(t.rarity);
    final outcomes = [
      for (final (a, w) in odds)
        '${a.stat.label} (${(w * 100).toStringAsFixed(1)}%)',
    ];
    if (random == null) {
      return _preview(p, t, credits: credits, materials: mats, outcomes: outcomes);
    }
    final a = loot.rollAffix(random, t)!;
    return _done(p, t, t.copyWith(affixes: [...t.affixes, a]),
        credits: credits, materials: mats);
  }

  /// Esquirla del Eco: valores nuevos dentro de cada tier.
  CraftResult reroll(PlayerProfile p, String uid, {RandomSource? random}) {
    final t = p.itemByUid(uid);
    if (t == null) return const CraftResult.fail('No la tienes');
    if (t.affixes.isEmpty) return const CraftResult.fail('No tiene afijos');
    final mats = {CraftMaterial.esquirla: 1};
    final credits = rerollCost(t.rarity);
    final outcomes = [
      for (final a in t.affixes)
        if (items.rangeOf(t, a) case (final lo, final hi))
          '${items.affixOf(a)?.stat.label ?? a.affixId}: $lo–$hi',
    ];
    if (random == null) {
      return _preview(p, t, credits: credits, materials: mats, outcomes: outcomes);
    }
    return _done(p, t, loot.rerollValues(random, t),
        credits: credits, materials: mats);
  }

  /// Prisma Roto: Común → Mágico → Raro → Épico, y tira los mods que
  /// faltan para el mínimo de la rareza nueva (y la pasiva al llegar a
  /// Épico).
  CraftResult upgradeRarity(PlayerProfile p, String uid,
      {RandomSource? random}) {
    final t = p.itemByUid(uid);
    if (t == null) return const CraftResult.fail('No la tienes');
    final cost = upgradeRarityCost(t.rarity);
    if (cost == null) {
      return const CraftResult.fail('Ya está en la rareza máxima');
    }
    final next = Rarity.values[t.rarity.index + 1];
    final mats = {CraftMaterial.prisma: cost.$1};
    final missing = math.max(0, next.minMods - t.affixes.length);
    final outcomes = [
      '${t.rarity.label} → ${next.label}',
      if (missing > 0) '+$missing afijo${missing == 1 ? '' : 's'} aleatorio${missing == 1 ? '' : 's'}',
      if (next == Rarity.epico) 'pasiva aleatoria del tipo de arma',
    ];
    if (random == null) {
      return _preview(p, t,
          credits: cost.$2, materials: mats, outcomes: outcomes);
    }
    var after = t.copyWith(rarity: next);
    after = loot.addRandomAffixes(random, after, missing);
    if ((next == Rarity.raro || next == Rarity.epico) && after.name == null) {
      after = after.copyWith(name: LootRules.rareName(random));
    }
    if (next == Rarity.epico) {
      final w = items.baseOf(after)!;
      after = after.copyWith(
          passiveId: loot.rollPassiveId(random, w.type), passiveLevel: 1);
    }
    return _done(p, t, after, credits: cost.$2, materials: mats);
  }

  /// Aplica una operación por su [op] (lo que usa `SessionEngine`).
  CraftResult apply(
    PlayerProfile p,
    CraftOp op,
    String targetUid, {
    String? sourceUid,
    int index = 0,
    String? skillId,
    RandomSource? random,
  }) =>
      switch (op) {
        CraftOp.transferAffix => sourceUid == null
            ? const CraftResult.fail('Elige un arma a sacrificar')
            : transferAffix(p, targetUid, sourceUid, index),
        CraftOp.transferPassive => sourceUid == null
            ? const CraftResult.fail('Elige un arma a sacrificar')
            : transferPassive(p, targetUid, sourceUid),
        CraftOp.transferSkill => sourceUid == null || skillId == null
            ? const CraftResult.fail('Elige un arma a sacrificar')
            : transferSkill(p, targetUid, sourceUid, skillId),
        CraftOp.removeAffix => removeAffix(p, targetUid, index),
        CraftOp.addAffix => addAffix(p, targetUid, random: random),
        CraftOp.reroll => reroll(p, targetUid, random: random),
        CraftOp.upgradeRarity => upgradeRarity(p, targetUid, random: random),
      };

  // ------------------------------------------------------------------

  String? _payError(PlayerProfile p, int credits, Map<CraftMaterial, int> m) {
    for (final e in m.entries) {
      if (p.material(e.key) < e.value) return 'Falta ${e.key.label}';
    }
    if (p.credits < credits) return 'Faltan \$${credits - p.credits}';
    return null;
  }

  CraftResult _preview(PlayerProfile p, ItemInstance before,
      {required int credits,
      required Map<CraftMaterial, int> materials,
      required List<String> outcomes}) {
    final err = _payError(p, credits, materials);
    return CraftResult(
      error: err,
      before: before,
      credits: credits,
      materials: materials,
      outcomes: outcomes,
    );
  }

  CraftResult _done(
    PlayerProfile p,
    ItemInstance before,
    ItemInstance after, {
    required int credits,
    Map<CraftMaterial, int> materials = const {},
    List<String> consumed = const [],
    String? replaced,
  }) {
    final err = _payError(p, credits, materials);
    var next = InventoryRules.replaceItem(p, after);
    for (final uid in consumed) {
      next = InventoryRules.removeItem(next, uid);
    }
    next = next.copyWith(
      credits: p.credits - credits,
      materials: {
        ...next.materials,
        for (final e in materials.entries) e.key: p.material(e.key) - e.value,
      },
    );
    return CraftResult(
      error: err,
      profile: err == null ? InventoryRules.relayout(next) : null,
      before: before,
      after: after,
      credits: credits,
      materials: materials,
      consumed: consumed,
      replaced: replaced,
    );
  }

  /// Texto de la pasiva de un arma como quedaría con [forgeLevels] (para
  /// mostrar "nivel II → III" en la forja).
  String? passiveAt(ItemInstance i, int forgeLevels) {
    final def = i.passiveId == null ? null : kWeaponPassives[i.passiveId];
    if (def == null || !i.rarity.hasPassive) return null;
    final l = (i.passiveLevel + forgeLevels ~/ 2)
        .clamp(1, ItemInstance.maxPassiveLevel);
    return '${def.nameAt(l)}: ${def.descriptionAt(l)}';
  }
}
