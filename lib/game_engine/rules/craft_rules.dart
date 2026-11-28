import 'dart:math' as math;

import '../data/tuning_catalog.dart';
import '../data/game_catalog.dart';
import '../data/weapon_passives.dart';
import '../models/item.dart';
import '../models/player_profile.dart';
import '../models/upgrade_stat.dart';
import '../models/weapon.dart';
import 'battle_engine.dart' show RandomSource;
import 'life_craft_rules.dart';
import 'inventory_rules.dart';
import 'item_rules.dart';
import 'js_math.dart';
import 'life_tree_rules.dart' show LifeTreeRules, LifeFx;
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
    this.replacedSkillId,
    this.outcomes = const [],
    this.gainedCredits = 0,
    this.gainedMaterials = const {},
    this.chances = const [],
    this.lost = const [],
  });

  const CraftResult.fail(String this.error)
      : profile = null,
        before = null,
        after = null,
        credits = 0,
        materials = const {},
        consumed = const [],
        replaced = null,
        replacedSkillId = null,
        outcomes = const [],
        gainedCredits = 0,
        gainedMaterials = const {},
        chances = const [],
        lost = const [];

  /// Créditos que se ganan (vender).
  final int gainedCredits;

  /// Materiales que se ganan seguro (desarmar; ya con el tope de 99).
  /// Con `RandomSource`, también lo que salió de [chances].
  final Map<CraftMaterial, int> gainedMaterials;

  /// Desarmar: lo que *puede* salir además de lo seguro.
  final List<MaterialChance> chances;

  /// Lo que se pierde además de las armas destruidas (mods o pasiva que
  /// no salen en la base nueva, materiales por encima del tope...).
  final List<String> lost;

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

  /// Trasladar habilidad: id de la trasladada que se pierde (loot.md
  /// § 16.2), o `null`.
  final String? replacedSkillId;

  /// Vista previa de una operación aleatoria: qué puede salir.
  final List<String> outcomes;

  bool get ok => error == null;
}

/// Una tirada extra al desarmar: [chance] de sumar [count] de [material],
/// [rolls] veces (una por arma en los lotes).
class MaterialChance {
  const MaterialChance(this.material, this.chance,
      {this.count = 1, this.rolls = 1});

  final CraftMaterial material;
  final double chance;
  final int count;
  final int rolls;

  /// `25% de +1 Cristal de Era` (`(×3 armas)` en los lotes).
  String get text => '${(chance * 100).round()}% de +$count ${material.label}'
      '${rolls > 1 ? ' (×$rolls armas)' : ''}';
}

/// Lo que da desarmar un arma (loot.md § 21.1).
class SalvageYield {
  const SalvageYield(this.guaranteed, this.chances);

  final Map<CraftMaterial, int> guaranteed;
  final List<MaterialChance> chances;
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

  /// [cost] con el descuento [discount] (fracción, 0 a 0,9).
  static int discounted(int cost, double discount) =>
      jsRound(cost * (1 - discount.clamp(0.0, 0.9)));

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
      jsRound(tuning(TuningId.materials).d('transferCredits') * target.costFactor);

  /// Materiales de trasladar una habilidad: 2 Cristales de Era hacia un
  /// arma Rara o mejor; nada a Común / Mágico (materials_economy.md
  /// § 4.2).
  static Map<CraftMaterial, int> transferSkillMaterials(Rarity target) =>
      target.index >= Rarity.raro.index
          ? {CraftMaterial.cristal: tuning(TuningId.materials).i('transferCristales')}
          : const {};

  /// Restaurar el Quebrar propio (loot.md § 16.3.1): créditos × rareza,
  /// sin materiales ni arma sacrificada.
  static int restoreQuebrarCost(Rarity r) => jsRound(
      tuning(TuningId.materials).d('restoreQuebrarCredits') * r.costFactor);

  static int addAffixCost(Rarity r) => jsRound(tuning(TuningId.materials).d('addAffixCredits') * r.costFactor);

  static int rerollCost(Rarity r) => jsRound(tuning(TuningId.materials).d('rerollCredits') * r.costFactor);

  /// Prismas y créditos para subir desde [r] (`null` si no se puede):
  /// 1 / 3 / 6 Prismas, 10 de Común a Épico (materials_economy.md § 4.2).
  static (int, int)? upgradeRarityCost(Rarity r) {
    final t = tuning(TuningId.materials);
    return switch (r) {
      Rarity.comun => (t.i('upComunPrismas'), t.i('upComunCredits')),
      Rarity.magico => (t.i('upMagicoPrismas'), t.i('upMagicoCredits')),
      Rarity.raro => (t.i('upRaroPrismas'), t.i('upRaroCredits')),
      _ => null,
    };
  }

  // ------------------------------------------------------------------
  // Sumideros de loot: desarmar, vender, reforjar (loot.md § 21)
  // ------------------------------------------------------------------

  /// Nivel de objeto desde el que desarmar da 1 material más.
  static int get salvageHighLevel => tuning(TuningId.materials).i('salvageHighLevel');

  /// Lo que da desarmar [i]: seguro según rareza y nivel de objeto (+1
  /// desde el nivel [salvageHighLevel]) y +1 Esquirla cada 2 niveles de
  /// forja; y la tirada extra de la rareza.
  static SalvageYield salvageYield(ItemInstance i) {
    final hi = i.itemLevel >= salvageHighLevel ? 1 : 0;
    final g = <CraftMaterial, int>{};
    void add(CraftMaterial m, int n) {
      if (n > 0) g[m] = (g[m] ?? 0) + n;
    }

    final chances = <MaterialChance>[];
    switch (i.rarity) {
      case Rarity.comun:
        add(CraftMaterial.esquirla, 1 + hi);
      case Rarity.magico:
        add(CraftMaterial.esquirla, 2 + hi);
        chances.add(const MaterialChance(CraftMaterial.cristal, 0.25));
      case Rarity.raro:
        add(CraftMaterial.esquirla, 2 + hi);
        chances.add(const MaterialChance(CraftMaterial.cristal, 0.50));
        chances.add(const MaterialChance(CraftMaterial.prisma, 0.05));
      case Rarity.epico:
        add(CraftMaterial.cristal, 1 + hi);
        chances.add(const MaterialChance(CraftMaterial.prisma, 0.15));
      case Rarity.legendario:
        add(CraftMaterial.prisma, 1);
        add(CraftMaterial.cristal, 2 + hi);
    }
    add(CraftMaterial.esquirla, i.forgeLevel ~/ 2);
    return SalvageYield(g, chances);
  }

  /// Valor de referencia de un objeto de nivel [itemLevel] (la fórmula de
  /// precio de las bases: `100·L + 4·L²`).
  static int itemValue(int itemLevel) =>
      100 * itemLevel + 4 * itemLevel * itemLevel;

  /// Fracción del valor que se cobra al vender, por rareza.
  static double sellFraction(Rarity r) => switch (r) {
        Rarity.comun => 0.10,
        Rarity.magico => 0.15,
        Rarity.raro => 0.25,
        Rarity.epico => 0.40,
        Rarity.legendario => 0.60,
      };

  /// Créditos que se gastaron en forjar [i] (lo que costaría hoy).
  int forgeSpent(ItemInstance i) {
    final w = items.baseOf(i);
    if (w == null) return 0;
    var total = 0;
    for (final s in UpgradeStat.values) {
      for (var l = 0; l < i.forge.level(s); l++) {
        total += forgeCost(w, i.rarity, l);
      }
    }
    return total;
  }

  /// Precio de venta: `valor(nivel de objeto) × fracción de la rareza +
  /// 25% de lo gastado en forja`, mínimo ₵10.
  int sellPrice(ItemInstance i) => math.max(
      10,
      jsRound((itemValue(i.itemLevel) * sellFraction(i.rarity) +
              forgeSpent(i) * 0.25) *
          forgedSellMult(i)));

  /// Uid prefix of a weapon forged at the HERRERÍA (mining_smithing.md
  /// § 4): it sells above loot of the same rarity.
  static const forgedPrefix = kForgedUidPrefix;

  /// Sell multiplier of [i]: `forgedSellMult + forgedSellPerRarity ×
  /// rarity` for forged weapons, 1 for the rest.
  static double forgedSellMult(ItemInstance i) {
    if (!i.uid.startsWith(forgedPrefix)) return 1;
    final t = tuning(TuningId.smithing);
    return t.d('forgedSellMult') + t.d('forgedSellPerRarity') * i.rarity.index;
  }

  /// Costo de reforjar la base: créditos `(100 + 25·nivel de objeto) ×
  /// factor de rareza` y Común 1 Esquirla, Mágico / Raro 1 Cristal, Épico
  /// 1 Cristal + 1 Prisma. `null` = Legendario (su base es parte del
  /// único).
  static (int, Map<CraftMaterial, int>)? reforgeCost(ItemInstance i) {
    final c = jsRound((100 + 25 * i.itemLevel) * i.rarity.costFactor);
    return switch (i.rarity) {
      Rarity.comun => (c, const {CraftMaterial.esquirla: 1}),
      Rarity.magico || Rarity.raro => (c, const {CraftMaterial.cristal: 1}),
      Rarity.epico => (
          c,
          const {CraftMaterial.cristal: 1, CraftMaterial.prisma: 1}
        ),
      Rarity.legendario => null,
    };
  }

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
  /// [discount]: lo que descuenta Brann (0,05 = 5 %; overworld_biomes.md
  /// § 10.6).
  CraftResult forge(PlayerProfile p, String uid, UpgradeStat stat,
      {double discount = 0}) {
    final it = p.itemByUid(uid);
    if (it == null) return const CraftResult.fail('No la tienes');
    final w = items.baseOf(it);
    if (w == null || !forgeStatsFor(w).contains(stat)) {
      return const CraftResult.fail('No se puede mejorar');
    }
    final l = it.forge.level(stat);
    if (l >= WeaponUpgradeLevels.upMax) return const CraftResult.fail('MAX');
    // Tope por rareza y por nivel de objeto (combo_balance.md § 2).
    final cap = ItemRules.forgeCapOf(it);
    if (it.forgeLevel >= cap) {
      return CraftResult.fail('Tope de forja ($cap)');
    }
    final cost = discounted(forgeCost(w, it.rarity, l), discount);
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
    if (transferAffixBlock(t, a) case final why?) {
      return CraftResult.fail(why);
    }
    final after = t.copyWith(affixes: [...t.affixes, a]);
    return _done(p, t, after,
        credits: transferAffixCost(a, t.rarity), consumed: [sourceUid]);
  }

  /// Motivo de [transferAffix] que depende solo del mod [a] y del arma
  /// [t] (sin costo ni sacrificio): `null` = entra. La forja lo usa para
  /// mostrar en gris los mods que no se pueden traer.
  String? transferAffixBlock(ItemInstance t, AffixRoll a) {
    if (a.fixed) return 'Mod fijo de un legendario';
    final def = items.affixOf(a);
    final w = items.baseOf(t);
    if (def == null || w == null || !def.allows(w.type)) {
      return 'No sale en este tipo de arma';
    }
    if (t.affixes.any((x) => x.affixId == a.affixId)) return kAlreadyHasAffix;
    if (!items.hasRoomFor(t, def)) {
      final side = def.slot == AffixSlot.prefix ? 'prefijos' : 'sufijos';
      if (t.rarity.maxMods == 0) {
        return 'Sin lugar: un arma ${t.rarity.label} no lleva mods';
      }
      return t.affixes.length >= t.rarity.maxMods
          ? 'Sin lugar: un arma ${t.rarity.label} lleva '
              '${t.rarity.maxMods} mods y ya los tiene'
          : 'Sin lugar de su lado: un arma ${t.rarity.label} lleva hasta '
              '${t.rarity.affixSideCap} $side y ya los tiene';
    }
    return null;
  }

  static const kAlreadyHasAffix = 'Ya tiene ese afijo';

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

  /// Trasladar [skillId] de [sourceUid] (que se consume) a [targetUid]
  /// (loot.md § 16, 16.1–16.3). Con los cupos llenos hay que elegir
  /// [replaceSkillId], una de las trasladadas del destino o su Quebrar
  /// base ([ItemRules.replaceableSkills]).
  CraftResult transferSkill(PlayerProfile p, String targetUid,
      String sourceUid, String skillId, {String? replaceSkillId}) {
    final t = p.itemByUid(targetUid);
    if (t == null) return const CraftResult.fail('No la tienes');
    final err = _sacrificeError(p, targetUid, sourceUid);
    if (err != null) return CraftResult.fail(err);
    final s = p.itemByUid(sourceUid)!;
    if (!items.skillsOf(s).contains(skillId) ||
        !catalog.skills.containsKey(skillId)) {
      return const CraftResult.fail('Elige una habilidad');
    }
    final reject = items.canReceiveSkill(t, skillId);
    if (reject != null) return CraftResult.fail(reject);
    String? replaced;
    // Quebrar de la ranura base (loot.md § 16.3): la trasladada ocupa su
    // ranura y el arma deja de tener Quebrar.
    final quebrar = items.quebrarOf(t);
    if (quebrar != null && replaceSkillId == quebrar) {
      if (t.extraSkills.contains(skillId)) {
        return const CraftResult.fail('Ya la tiene');
      }
      final after = t.copyWith(
          quebrarReplaced: true, extraSkills: [...t.extraSkills, skillId]);
      return _done(p, t, after,
          credits: transferSkillCost(t.rarity),
          materials: transferSkillMaterials(t.rarity),
          consumed: [sourceUid],
          replaced: catalog.skills[quebrar]?.name,
          replacedSkillId: quebrar);
    }
    if (replaceSkillId != null) {
      if (!t.extraSkills.contains(replaceSkillId)) {
        return CraftResult.fail(
            (items.baseOf(t)?.skillIds.contains(replaceSkillId) ?? false)
                ? 'Las habilidades base no se reemplazan'
                : 'No tiene esa habilidad');
      }
      if (replaceSkillId != skillId) replaced = replaceSkillId;
    } else if (items.needsReplaceChoice(t, skillId)) {
      return const CraftResult.fail('Elegí qué habilidad reemplazar');
    }
    final skills = [
      for (final x in t.extraSkills)
        if (x != skillId && x != replaced) x,
    ];
    if (skills.length >= t.skillCapacity) {
      // Solo con un perfil fuera de cupo (no pasa tras `sanitize`).
      return const CraftResult.fail('Elegí qué habilidad reemplazar');
    }
    final after = t.copyWith(extraSkills: [...skills, skillId]);
    return _done(p, t, after,
        credits: transferSkillCost(t.rarity),
        materials: transferSkillMaterials(t.rarity),
        consumed: [sourceUid],
        replaced: replaced == null ? null : catalog.skills[replaced]?.name,
        replacedSkillId: replaced);
  }

  /// Restaurar el Quebrar del tipo de [uid] si se reemplazó por fusión
  /// (loot.md § 16.3.1). La ranura vuelve a ser de Quebrar: si las
  /// trasladadas no entran en los cupos de la rareza, hay que elegir
  /// [replaceSkillId], que se pierde (como al reemplazar).
  CraftResult restoreQuebrar(PlayerProfile p, String uid,
      {String? replaceSkillId}) {
    final t = p.itemByUid(uid);
    if (t == null) return const CraftResult.fail('No la tienes');
    final w = items.baseOf(t);
    if (w == null) return const CraftResult.fail('No la tienes');
    if (!t.quebrarReplaced) return const CraftResult.fail('Ya tiene su Quebrar');
    final full = t.extraSkills.length > t.rarity.skillSlots;
    String? lost;
    if (replaceSkillId != null && full) {
      if (!t.extraSkills.contains(replaceSkillId)) {
        return const CraftResult.fail('No tiene esa habilidad');
      }
      lost = replaceSkillId;
    } else if (full) {
      return const CraftResult.fail('Elegí qué habilidad deja su ranura');
    }
    final after = t.copyWith(quebrarReplaced: false, extraSkills: [
      for (final x in t.extraSkills)
        if (x != lost) x,
    ]);
    return _done(p, t, after,
        credits: restoreQuebrarCost(t.rarity),
        replaced: lost == null ? null : catalog.skills[lost]?.name,
        replacedSkillId: lost,
        lost: [
          if (lost != null) catalog.skills[lost]?.name ?? lost,
        ]);
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

  // ------------------------------------------------------------------
  // Desarmar / vender / reforjar (loot.md § 21)
  // ------------------------------------------------------------------

  /// Motivo por el que [uid] no se puede destruir (desarmar / vender) ni
  /// reforjar.
  String? _keepError(PlayerProfile p, String uid) {
    if (p.itemByUid(uid) == null) return 'No la tienes';
    if (uid == p.equippedUid) return 'Está equipada';
    if (inventory.isProtected(p, uid)) return 'Arma inicial';
    return null;
  }

  /// Armas de rareza [r] que se pueden destruir de una vez: no la
  /// equipada ni la última del arma inicial (se queda una).
  List<ItemInstance> batchTargets(PlayerProfile p, Rarity r) {
    final out = <ItemInstance>[];
    var q = p;
    for (final it in p.items) {
      if (it.rarity != r || inventory.isProtected(q, it.uid)) continue;
      out.add(it);
      q = q.copyWith(items: [for (final x in q.items) if (x.uid != it.uid) x]);
    }
    return out;
  }

  /// Desarmar [uid]: se destruye y da materiales ([salvageYield]). Sin
  /// tirada extra (Común, Legendario) el resultado es completo aun sin
  /// `random`; con tirada y sin `random`, vista previa (lo seguro en
  /// `gainedMaterials` y lo posible en `chances`).
  CraftResult salvage(PlayerProfile p, String uid, {RandomSource? random}) {
    final err = _keepError(p, uid);
    if (err != null) return CraftResult.fail(err);
    return _salvageMany(p, [p.itemByUid(uid)!], random);
  }

  /// Desarmar todas las armas de rareza [r] ([batchTargets]).
  CraftResult salvageAll(PlayerProfile p, Rarity r, {RandomSource? random}) {
    final list = batchTargets(p, r);
    if (list.isEmpty) return CraftResult.fail('No hay armas de rareza ${r.label}');
    return _salvageMany(p, list, random);
  }

  /// Tope de armas elegidas en una sola operación (el inventario entero).
  static const maxSelected = InventoryRules.maxItems;

  /// Por qué [uid] no se puede elegir para desarmar / vender si ya están
  /// elegidas [others] (`null` = se puede). Con dos armas iniciales se
  /// puede elegir una sola: la otra queda como "Arma inicial".
  String? selectionBlock(PlayerProfile p, String uid,
      {Iterable<String> others = const []}) {
    if (p.itemByUid(uid) == null) return 'No la tienes';
    if (uid == p.equippedUid) return 'Está equipada';
    final rest = {...others}..remove(uid);
    final q = rest.isEmpty
        ? p
        : p.copyWith(items: [
            for (final i in p.items)
              if (!rest.contains(i.uid)) i,
          ]);
    if (inventory.isProtected(q, uid)) return 'Arma inicial';
    return null;
  }

  /// Las armas [uids] (en ese orden, sin repetir) si todas se pueden
  /// destruir juntas; si no, el motivo de la primera que no.
  ({List<ItemInstance> list, String? error}) selectedTargets(
      PlayerProfile p, List<String> uids) {
    final seen = <String>{};
    final list = <ItemInstance>[];
    var q = p;
    for (final uid in uids) {
      if (!seen.add(uid)) continue;
      final it = q.itemByUid(uid);
      final why = it == null
          ? 'No la tienes'
          : uid == q.equippedUid
              ? 'Está equipada'
              : inventory.isProtected(q, uid)
                  ? 'Arma inicial'
                  : null;
      if (why != null) return (list: const [], error: why);
      list.add(it!);
      q = q.copyWith(items: [for (final x in q.items) if (x.uid != uid) x]);
    }
    if (list.isEmpty) return (list: const [], error: 'Elige armas');
    if (list.length > maxSelected) {
      return (list: const [], error: 'Máximo $maxSelected armas');
    }
    return (list: list, error: null);
  }

  /// Desarmar las armas elegidas a mano (todas o ninguna).
  CraftResult salvageSelected(PlayerProfile p, List<String> uids,
      {RandomSource? random}) {
    final t = selectedTargets(p, uids);
    if (t.error != null) return CraftResult.fail(t.error!);
    return _salvageMany(p, t.list, random);
  }

  /// Vender las armas elegidas a mano (todas o ninguna).
  CraftResult sellSelected(PlayerProfile p, List<String> uids) {
    final t = selectedTargets(p, uids);
    if (t.error != null) return CraftResult.fail(t.error!);
    return _sellMany(p, t.list);
  }

  CraftResult _sellMany(PlayerProfile p, List<ItemInstance> list) =>
      _done(p, null, null,
          consumed: [for (final it in list) it.uid],
          gainCredits: list.fold(0, (a, it) => a + sellPrice(it)));

  CraftResult _salvageMany(
      PlayerProfile p, List<ItemInstance> list, RandomSource? random) {
    // Fundición sub-path B (life_trees_v2.md § 2.1): more back.
    final mult = 1 + LifeTreeRules.smith(p, LifeFx.salvage);
    final gained = <CraftMaterial, int>{};
    final byChance = <(CraftMaterial, double, int), int>{};
    for (final it in list) {
      final y = salvageYield(it);
      y.guaranteed.forEach(
          (m, n) => gained[m] = (gained[m] ?? 0) + (n * mult).round());
      for (final c in y.chances) {
        final k = (c.material, c.chance, c.count);
        byChance[k] = (byChance[k] ?? 0) + 1;
        if (random != null && random() < c.chance) {
          gained[c.material] = (gained[c.material] ?? 0) + c.count;
        }
      }
    }
    final chances = [
      for (final e in byChance.entries)
        MaterialChance(e.key.$1, e.key.$2, count: e.key.$3, rolls: e.value),
    ];
    final consumed = [for (final it in list) it.uid];
    final before = list.length == 1 ? list.first : null;
    if (random == null && chances.isNotEmpty) {
      return CraftResult(
        before: before,
        consumed: consumed,
        gainedMaterials: _capped(p, gained),
        chances: chances,
        outcomes: [for (final c in chances) c.text],
        lost: _capLoss(p, gained),
      );
    }
    return _done(p, before, null,
        consumed: consumed, gainMaterials: gained, chances: chances);
  }

  /// Vender [uid]: se destruye y da [sellPrice] créditos.
  CraftResult sell(PlayerProfile p, String uid) {
    final err = _keepError(p, uid);
    if (err != null) return CraftResult.fail(err);
    final it = p.itemByUid(uid)!;
    return _done(p, it, null, consumed: [uid], gainCredits: sellPrice(it));
  }

  /// Vender todas las armas de rareza [r] ([batchTargets]).
  CraftResult sellAll(PlayerProfile p, Rarity r) {
    final list = batchTargets(p, r);
    if (list.isEmpty) return CraftResult.fail('No hay armas de rareza ${r.label}');
    return _sellMany(p, list);
  }

  /// Bases a las que se puede reforjar [i]: cualquier tipo, de nivel ≤
  /// nivel de objeto (la misma regla con la que cae el loot), sin la
  /// actual; de la más cercana al nivel de objeto a la más baja.
  List<WeaponDef> reforgeBases(ItemInstance i) => [
        for (final w in catalog.weapons.values)
          if (w.level <= i.itemLevel && w.id != i.baseId) w,
      ]..sort((a, b) => a.level != b.level
          ? b.level.compareTo(a.level)
          : a.name.compareTo(b.name));

  /// Reforjar [uid] a la base [baseId]: conserva rareza, nivel de objeto,
  /// nombre, mods, pasiva, forja y habilidades trasladadas; se pierden los
  /// mods que no salen en el tipo nuevo, la pasiva si no está en su pool
  /// y la forja de Defensa si la base nueva no tiene escudo ([lost]).
  CraftResult reforge(PlayerProfile p, String uid, String baseId) {
    final err = _keepError(p, uid);
    if (err != null) return CraftResult.fail(err);
    final t = p.itemByUid(uid)!;
    final cost = reforgeCost(t);
    if (cost == null) {
      return const CraftResult.fail('Un Legendario no cambia de base');
    }
    final w = catalog.weapons[baseId];
    if (w == null) return const CraftResult.fail('Elige una base');
    if (baseId == t.baseId) return const CraftResult.fail('Ya tiene esa base');
    if (w.level > t.itemLevel) {
      return CraftResult.fail(
          'Base de nivel ${w.level} (el arma es de nivel ${t.itemLevel})');
    }
    final lost = <String>[];
    final kept = <AffixRoll>[];
    for (final a in t.affixes) {
      final def = items.affixOf(a);
      if (def != null && def.allows(w.type)) {
        kept.add(a);
      } else {
        lost.add('Mod ${items.affixText(a)} (no sale en ${w.type})');
      }
    }
    var keepPassive = true;
    final pd = items.passiveOf(t);
    if (pd != null &&
        t.rarity.hasPassive &&
        !weaponPassivePool(w.type).any((x) => x.id == pd.id)) {
      keepPassive = false;
      lost.add('Pasiva ${pd.name} (no sale en ${w.type})');
    }
    var forge = t.forge;
    if (w.shieldDefense <= 0 && forge.def > 0) {
      lost.add('Forja de Defensa +${forge.def} (la base nueva no tiene escudo)');
      forge = forge.withLevel(UpgradeStat.def, 0);
    }
    final after = t.copyWith(
      baseId: baseId,
      affixes: kept,
      clearPassive: !keepPassive,
      forge: forge,
    );
    return _done(p, t, after,
        credits: cost.$1, materials: cost.$2, lost: lost);
  }

  /// Aplica una operación por su [op] (lo que usa `SessionEngine`).
  CraftResult apply(
    PlayerProfile p,
    CraftOp op,
    String targetUid, {
    String? sourceUid,
    int index = 0,
    String? skillId,
    String? replaceSkillId,
    List<String> uids = const [],
    RandomSource? random,
  }) =>
      switch (op) {
        CraftOp.salvageSelected =>
          salvageSelected(p, uids, random: random),
        CraftOp.sellSelected => sellSelected(p, uids),
        CraftOp.transferAffix => sourceUid == null
            ? const CraftResult.fail('Elige un arma a sacrificar')
            : transferAffix(p, targetUid, sourceUid, index),
        CraftOp.transferPassive => sourceUid == null
            ? const CraftResult.fail('Elige un arma a sacrificar')
            : transferPassive(p, targetUid, sourceUid),
        CraftOp.transferSkill => sourceUid == null || skillId == null
            ? const CraftResult.fail('Elige un arma a sacrificar')
            : transferSkill(p, targetUid, sourceUid, skillId,
                replaceSkillId: replaceSkillId),
        CraftOp.removeAffix => removeAffix(p, targetUid, index),
        CraftOp.addAffix => addAffix(p, targetUid, random: random),
        CraftOp.reroll => reroll(p, targetUid, random: random),
        CraftOp.upgradeRarity => upgradeRarity(p, targetUid, random: random),
        CraftOp.salvage => salvage(p, targetUid, random: random),
        CraftOp.sell => sell(p, targetUid),
        CraftOp.reforge => sourceUid == null
            ? const CraftResult.fail('Elige una base')
            : reforge(p, targetUid, sourceUid),
        CraftOp.salvageAll => index < 0 || index >= Rarity.values.length
            ? const CraftResult.fail('Elige una rareza')
            : salvageAll(p, Rarity.values[index], random: random),
        CraftOp.sellAll => index < 0 || index >= Rarity.values.length
            ? const CraftResult.fail('Elige una rareza')
            : sellAll(p, Rarity.values[index]),
        CraftOp.essence => essence(p, targetUid, random: random),
        CraftOp.condense => switch (CraftMaterial.values
              .where((m) => m.name == targetUid)
              .firstOrNull) {
            final m? => condense(p, m, index),
            null when targetUid.startsWith(LifeCraftRules.prefix) =>
              _condenseLife(p, targetUid.substring(LifeCraftRules.prefix.length), index),
            null => const CraftResult.fail('Elige un material'),
          },
        CraftOp.restoreQuebrar =>
          restoreQuebrar(p, targetUid, replaceSkillId: replaceSkillId),
      };

  // ------------------------------------------------------------------
  // Condensar (materials_economy.md § 4.3)
  // ------------------------------------------------------------------

  /// Receta para obtener 1 de [out]: (material que se gasta, cuántos,
  /// créditos), o `null` si [out] no se condensa. 20 Esquirlas + ₵100 →
  /// 1 Cristal; 8 Cristales + ₵500 → 1 Prisma (v0.20.8; Editor → Balance).
  static (CraftMaterial, int, int)? condenseRecipe(CraftMaterial out) =>
      switch (out) {
        CraftMaterial.cristal => (CraftMaterial.esquirla,
            tuning(TuningId.condense).i('cristalCost'),
            tuning(TuningId.condense).i('cristalCredits')),
        CraftMaterial.prisma => (CraftMaterial.cristal,
            tuning(TuningId.condense).i('prismaCost'),
            tuning(TuningId.condense).i('prismaCredits')),
        _ => null,
      };

  /// Materiales de oficio (v0.27.0; materials_economy.md § 4.4).
  CraftResult _condenseLife(PlayerProfile p, String id, int times) {
    if (LifeCraftRules.recipe(id) == null) {
      return const CraftResult.fail('Ese material no se condensa');
    }
    if (times < 1) return const CraftResult.fail('Elige cuántos');
    final next = LifeCraftRules.condense(p, id, times);
    if (next == null) return const CraftResult.fail('No alcanza');
    return CraftResult(profile: next);
  }

  /// Materiales que se obtienen condensando.
  static const condensable = [CraftMaterial.cristal, CraftMaterial.prisma];

  /// Cuántos de [out] se pueden condensar ahora (materiales, créditos y
  /// lugar en la pila de 99).
  static int condenseMax(PlayerProfile p, CraftMaterial out) {
    final r = condenseRecipe(out);
    if (r == null) return 0;
    final (from, n, cr) = r;
    return math.max(
        0,
        [
          p.material(from) ~/ n,
          p.credits ~/ cr,
          CraftMaterial.maxStack - p.material(out),
        ].reduce(math.min));
  }

  /// Condensar [times] veces hacia [out]: sin azar, sin vuelta atrás. No
  /// deja pasar del tope de 99 (nunca se pierde lo condensado).
  CraftResult condense(PlayerProfile p, CraftMaterial out, int times) {
    final r = condenseRecipe(out);
    if (r == null) return const CraftResult.fail('Ese material no se condensa');
    if (times < 1) return const CraftResult.fail('Elige cuántos');
    final (from, n, cr) = r;
    if (p.material(out) + times > CraftMaterial.maxStack) {
      return const CraftResult.fail(
          'Pila llena (tope ${CraftMaterial.maxStack})');
    }
    return _done(p, null, null,
        credits: cr * times,
        materials: {from: n * times},
        gainMaterials: {out: times});
  }

  /// Esencia del Abismo (v0.8, abyss_bosses.md § 3.1): los mods fijos de
  /// un legendario se re-tiran dos veces cada uno y queda el mayor, nunca
  /// por debajo del actual.
  CraftResult essence(PlayerProfile p, String uid, {RandomSource? random}) {
    final t = p.itemByUid(uid);
    if (t == null) return const CraftResult.fail('No la tienes');
    if (t.rarity != Rarity.legendario) {
      return const CraftResult.fail('Solo legendarios');
    }
    final fixed = [
      for (final a in t.affixes)
        if (a.fixed)
          if (items.rangeOf(t, a) case (final lo, final hi)) (a, lo, hi),
    ];
    if (fixed.isEmpty) return const CraftResult.fail('No tiene mods fijos');
    if (fixed.every((f) => f.$1.value >= f.$3)) {
      return const CraftResult.fail('Los mods fijos ya están al máximo');
    }
    const mats = {CraftMaterial.esencia: 1};
    final outcomes = [
      for (final (a, lo, hi) in fixed)
        '${items.affixOf(a)?.stat.label ?? a.affixId}: ${a.value} → '
            '${a.value}–$hi (mejor de 2, nunca baja; rango $lo–$hi)',
    ];
    if (random == null) {
      return _preview(p, t, credits: 0, materials: mats, outcomes: outcomes);
    }
    AffixRoll better(AffixRoll a) {
      final r = a.fixed ? items.rangeOf(t, a) : null;
      if (r == null) return a;
      final best = math.max(LootRules.rollValue(random, r.$1, r.$2),
          LootRules.rollValue(random, r.$1, r.$2));
      return AffixRoll(a.affixId, a.tier, math.max(a.value, best));
    }

    final after = t.copyWith(affixes: [for (final a in t.affixes) better(a)]);
    return _done(p, t, after, materials: mats);
  }

  // ------------------------------------------------------------------

  String? _payError(PlayerProfile p, int credits, Map<CraftMaterial, int> m) {
    for (final e in m.entries) {
      if (p.material(e.key) < e.value) return 'Falta ${e.key.label}';
    }
    if (p.credits < credits) return 'Faltan ₵${credits - p.credits}';
    return null;
  }

  /// [gained] recortado al tope de cada pila (99).
  static Map<CraftMaterial, int> _capped(
          PlayerProfile p, Map<CraftMaterial, int> gained) =>
      {
        for (final e in gained.entries)
          if (math.min(e.value, CraftMaterial.maxStack - p.material(e.key)) > 0)
            e.key: math.min(e.value, CraftMaterial.maxStack - p.material(e.key)),
      };

  /// Lo que se pierde por el tope de 99.
  static List<String> _capLoss(
          PlayerProfile p, Map<CraftMaterial, int> gained) =>
      [
        for (final e in gained.entries)
          if (p.material(e.key) + e.value > CraftMaterial.maxStack)
            '${p.material(e.key) + e.value - CraftMaterial.maxStack} '
                '${e.key.label} (tope ${CraftMaterial.maxStack})',
      ];

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
    ItemInstance? before,
    ItemInstance? after, {
    int credits = 0,
    Map<CraftMaterial, int> materials = const {},
    List<String> consumed = const [],
    String? replaced,
    String? replacedSkillId,
    int gainCredits = 0,
    Map<CraftMaterial, int> gainMaterials = const {},
    List<MaterialChance> chances = const [],
    List<String> lost = const [],
  }) {
    final err = _payError(p, credits, materials);
    var next = after == null ? p : InventoryRules.replaceItem(p, after);
    if (consumed.isNotEmpty) {
      final gone = consumed.toSet();
      next = next.copyWith(
          items: [for (final i in next.items) if (!gone.contains(i.uid)) i]);
    }
    next = next.copyWith(
      credits: p.credits - credits + gainCredits,
      materials: {
        ...next.materials,
        for (final m in {...materials.keys, ...gainMaterials.keys})
          m: math.min(
              CraftMaterial.maxStack,
              p.material(m) - (materials[m] ?? 0) + (gainMaterials[m] ?? 0)),
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
      replacedSkillId: replacedSkillId,
      gainedCredits: gainCredits,
      gainedMaterials: _capped(p, gainMaterials),
      chances: chances,
      outcomes: [for (final c in chances) c.text],
      lost: [...lost, ..._capLoss(p, gainMaterials)],
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
