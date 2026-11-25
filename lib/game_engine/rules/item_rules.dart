import '../data/weapon_elements_catalog.dart';
import '../data/affixes_catalog.dart';
import '../data/ascension_catalog.dart';
import '../data/branch_ults_catalog.dart' show kBranchUltWeaponTypes;
import '../data/ults_v2_catalog.dart' show kUltV2;
import '../models/ult_def.dart' show UltSource;
import '../data/game_catalog.dart';
import '../data/skills_catalog.dart' show kBaseQuebrarIds, kSkillDelivery, quebrarSkillFor;
import '../data/uniques_catalog.dart';
import '../data/weapon_passives.dart';
import '../data/weapons_catalog.dart' show kWeaponTypeCategory;
import '../models/item.dart';
import 'gear_v2_rules.dart' show GearV2Rules;
import 'break_rules.dart';
import '../models/skill.dart' show SkillDelivery;
import '../models/upgrade_stat.dart';
import '../models/weapon.dart';
import '../models/weapon_passive.dart';

/// Consultas y validación de instancias de arma (loot.md § 1–3). Puras:
/// no tocan perfiles (eso es `InventoryRules` / `CraftRules`).
class ItemRules {
  const ItemRules({this.catalog = GameCatalog.standard});

  final GameCatalog catalog;

  static const maxItemLevel = 50;

  WeaponDef? baseOf(ItemInstance i) => catalog.weapons[i.baseId];

  AffixDef? affixOf(AffixRoll r) => kAffixes[r.affixId];

  UniqueDef? uniqueOf(ItemInstance i) =>
      i.uniqueId == null ? null : kUniques[i.uniqueId];

  WeaponPassiveDef? passiveOf(ItemInstance i) =>
      i.passiveId == null ? null : kWeaponPassives[i.passiveId];

  /// Implícito + afijos como mods con texto.
  List<ItemMod> implicitMods(WeaponDef w) => [
        if (w.shieldDefense > 0) ItemMod(ModStat.defense, w.shieldDefense),
        ...w.implicit,
      ];

  ItemMod? modOf(AffixRoll r) {
    final a = affixOf(r);
    return a == null ? null : ItemMod(a.stat, r.value);
  }

  int prefixCount(ItemInstance i) => i.affixes
      .where((a) => affixOf(a)?.slot == AffixSlot.prefix)
      .length;

  int suffixCount(ItemInstance i) => i.affixes
      .where((a) => affixOf(a)?.slot == AffixSlot.suffix)
      .length;

  /// Cuántos mods más entran respetando el total y el lado del afijo.
  bool hasRoomFor(ItemInstance i, AffixDef a) {
    if (i.affixes.length >= i.modCap) return false;
    if (i.affixes.any((x) => x.affixId == a.id)) return false;
    final side = a.slot == AffixSlot.prefix ? prefixCount(i) : suffixCount(i);
    return side < i.sideCap;
  }

  /// Afijos que todavía pueden salir en [i] (tipo, lado, cupo y nivel).
  List<AffixDef> candidateAffixes(ItemInstance i) {
    final w = baseOf(i);
    if (w == null) return const [];
    return [
      for (final a in kAffixes.values)
        if (a.allows(w.type) &&
            hasRoomFor(i, a) &&
            a.tiersFor(i.itemLevel).isNotEmpty)
          a,
    ];
  }

  /// La Quebrar de la ranura base de [i] (loot.md § 16.3), o `null` si
  /// el jugador la reemplazó (o la base no existe).
  String? quebrarOf(ItemInstance i) {
    final w = baseOf(i);
    if (w == null || i.quebrarReplaced) return null;
    return quebrarSkillFor(w.type);
  }

  /// Habilidades del arma: las de la base, las trasladadas y Quebrar (si
  /// sigue en su ranura).
  List<String> skillsOf(ItemInstance i) {
    final w = baseOf(i);
    final out = [...?w?.skillIds];
    for (final s in i.extraSkills) {
      if (!out.contains(s)) out.add(s);
    }
    // Al final, como en el kit de batalla.
    final q = quebrarOf(i);
    if (q != null && !out.contains(q)) out.add(q);
    return out;
  }

  // ---- traslado de habilidades (loot.md § 16.1–16.2) ----

  /// Forma de entrega de [skillId]; `null` si no es una habilidad de arma
  /// trasladable (desconocida o del kit de una ascensión).
  SkillDelivery? skillCategory(String skillId) =>
      catalog.skills.containsKey(skillId) ? kSkillDelivery[skillId] : null;

  /// Categoría del tipo de arma de [i] (`null` si la base no existe).
  WeaponCategory? weaponCategoryOf(ItemInstance i) {
    final w = baseOf(i);
    return w == null ? null : kWeaponTypeCategory[w.type];
  }

  /// Motivo por el que [weapon] no puede recibir [skillId] trasladada, o
  /// `null` si puede. Solo valida la forma de entrega (no cupos ni costo).
  String? canReceiveSkill(ItemInstance weapon, String skillId) {
    if (kBaseQuebrarIds.contains(skillId)) {
      // loot.md § 16.3.1: el Quebrar no se traslada; el propio se
      // restaura (CraftOp.restoreQuebrar), el de otro tipo nunca.
      final own = quebrarSkillFor(baseOf(weapon)?.type);
      return skillId == own && weapon.quebrarReplaced
          ? 'Usá Restaurar Quebrar: no hace falta sacrificar un arma'
          : 'Solo podés restaurar el Quebrar propio de esta arma';
    }
    final d = skillCategory(skillId);
    if (d == null) return 'Elige una habilidad';
    final c = weaponCategoryOf(weapon);
    if (c == null) return 'No la tienes';
    return switch (d) {
      SkillDelivery.any => null,
      SkillDelivery.melee =>
        c == WeaponCategory.melee ? null : 'Solo armas cuerpo a cuerpo',
      SkillDelivery.caster =>
        c == WeaponCategory.caster ? null : 'Solo armas de lanzador',
      SkillDelivery.ranged =>
        c == WeaponCategory.ranged ? null : 'Solo armas a distancia',
    };
  }

  /// Habilidades que se pueden elegir para reemplazar: las trasladadas y
  /// Quebrar de la ranura base (loot.md § 16.3); las otras de la base
  /// nunca.
  List<String> replaceableSkills(ItemInstance i) =>
      [...i.extraSkills, if (quebrarOf(i) case final q?) q];

  /// Si trasladar [skillId] a [target] obliga a elegir cuál reemplazar
  /// (cupos llenos y no la tiene ya trasladada).
  bool needsReplaceChoice(ItemInstance target, String skillId) =>
      !target.extraSkills.contains(skillId) &&
      target.extraSkills.length >= target.skillCapacity;

  /// Nombre para mostrar: Común = base; Mágico = base + prefijo + sufijo;
  /// Raro / Épico = nombre generado; Legendario = nombre único. Con forja,
  /// `+N` al final (como `wName`).
  String displayName(ItemInstance i) {
    final w = baseOf(i);
    final base = w?.name ?? i.baseId;
    final name = switch (i.rarity) {
      Rarity.comun => base,
      Rarity.magico => [
          base,
          for (final a in i.affixes)
            if (affixOf(a) case final d? when d.slot == AffixSlot.prefix) d.name,
          for (final a in i.affixes)
            if (affixOf(a) case final d? when d.slot == AffixSlot.suffix) d.name,
        ].join(' '),
      Rarity.raro || Rarity.epico => i.name ?? base,
      Rarity.legendario => uniqueOf(i)?.name ?? i.name ?? base,
    };
    final t = i.forgeLevel;
    return '$name${t > 0 ? ' +$t' : ''}';
  }

  /// Tiers de ventaja de los mods fijos de una legendaria sobre los
  /// aleatorios del mismo nivel (combo_balance.md § 2).
  static const legendaryTierBonus = 2;

  /// Rango de un mod fijo de legendaria a nivel de objeto [itemLevel]
  /// (combo_balance.md § 2): escala como los aleatorios. El rango del
  /// catálogo es el de nivel alto (T1); a un nivel donde lo mejor que sale
  /// es el tier `Tn`, el rango se multiplica por `máx(T(n−1)) / máx(T1)`
  /// ([legendaryTierBonus] tier por encima). Nunca baja de 1.
  static (int, int) fixedRangeAt(UniqueMod f, int itemLevel) {
    final def = kAffixes[f.affixId];
    if (def == null || def.tiers.isEmpty) return (f.min, f.max);
    final top = def.tier(1) ?? def.tiers.first;
    if (top.max <= 0) return (f.min, f.max);
    final open = def.tiersFor(itemLevel);
    final best = open.isEmpty
        ? def.tiers.map((t) => t.tier).reduce((a, b) => a > b ? a : b)
        : open.map((t) => t.tier).reduce((a, b) => a < b ? a : b);
    final boosted = best - legendaryTierBonus < 1 ? 1 : best - legendaryTierBonus;
    final ref = def.tier(boosted) ?? top;
    final ratio = ref.max / top.max;
    if (ratio >= 1) return (f.min, f.max);
    final lo = (f.min * ratio).round().clamp(1, f.min);
    final hi = (f.max * ratio).round().clamp(lo, f.max);
    return (lo, hi);
  }

  /// Tope de forja de [i] (combo_balance.md § 2): el de su rareza, pero
  /// no más que `2 + nivel de objeto / 5` (una legendaria de nivel 5
  /// llega a +3, no a +10).
  static int forgeCapOf(ItemInstance i) => forgeCapAt(i.rarity, i.itemLevel);

  static int forgeCapAt(Rarity r, int itemLevel) {
    final byLevel = 2 + itemLevel ~/ 5;
    return byLevel < r.forgeCap ? byLevel : r.forgeCap;
  }

  /// Texto de un afijo con su tier: `+12% ATQ (T3)`.
  /// Texto de [r]. Con [on] (el arma que lo lleva), Quebrantador nombra
  /// la habilidad que puede quebrar (`BreakRules.modSkillOf`).
  String affixText(AffixRoll r, {ItemInstance? on}) {
    final m = modOf(r);
    if (m == null) return r.affixId;
    final tier = r.fixed ? 'único' : 'T${r.tier}';
    if (m.stat == ModStat.breakSkill && on != null) {
      if (breakSkillText(on) case final t?) return '$t ($tier)';
    }
    return '${m.text} ($tier)';
  }

  /// Quebrantador sobre [i]: `<Habilidad> puede quebrar` o `sin habilidad
  /// que pueda quebrar`; `null` si la base no existe.
  String? breakSkillText(ItemInstance i) {
    final w = baseOf(i);
    if (w == null) return null;
    final id = BreakRules.modSkillOf(w, catalog.skills);
    final name = id == null ? null : catalog.skills[id]?.name;
    return name == null
        ? 'Sin habilidad que pueda quebrar'
        : '$name puede quebrar';
  }

  /// Línea de ayuda del afijo Quebrantador (tooltips).
  static const breakSkillHelp = 'Quebrantador: la primera habilidad de daño '
      'a un objetivo del arma que todavía no quiebra pasa a poder quebrar';

  /// Rango del valor de [r] (su tier, o el del mod fijo del único al
  /// nivel del objeto; con [scaled] en `false`, el rango de diseño).
  (int, int)? rangeOf(ItemInstance i, AffixRoll r, {bool scaled = true}) {
    if (r.fixed) {
      for (final f in uniqueOf(i)?.fixed ?? const <UniqueMod>[]) {
        if (f.affixId == r.affixId) {
          return scaled ? fixedRangeAt(f, i.itemLevel) : (f.min, f.max);
        }
      }
      return null;
    }
    final t = affixOf(r)?.tier(r.tier);
    return t == null ? null : (t.min, t.max);
  }

  /// Ids de las mecánicas que la pasiva del arma aporta al combate.
  List<String> mechanicIds(ItemInstance i) =>
      i.passiveId == null || !i.rarity.hasPassive
          ? const []
          : weaponPassiveMechanicIds(i.passiveId!, i.effectivePassiveLevel);

  /// Mecánicas efectivas (para mostrar el texto de la pasiva).
  String? passiveText(ItemInstance i) {
    final p = passiveOf(i);
    if (p == null || !i.rarity.hasPassive) return null;
    final l = i.effectivePassiveLevel;
    return '${p.nameAt(l)}: ${p.descriptionAt(l)}';
  }

  /// El mod "ULT: <nombre>" [ultId] puede estar en un arma [rarity] de
  /// tipo [type] (docs/specs/branch_ults.md): solo Raro / Épico y una ULT
  /// de camino compatible con el tipo (los legendarios traen la suya).
  /// Desde v0.17 también las 12 ULT v2 de mod (ultimates_v2.md § 3.1);
  /// las de camino siguen valiendo en las armas ya caídas.
  static bool ultModAllowed(Rarity rarity, String type, String? ultId) =>
      ultId != null &&
      (rarity == Rarity.raro || rarity == Rarity.epico) &&
      ((kBranchUltWeaponTypes[ultId]?.contains(type) ?? false) ||
          _v2Mod(ultId, type));

  /// Whether [i] is a profession weapon (`gear-` mark in its uid,
  /// profession_gear.md § 1).
  static bool isProfessionGear(ItemInstance i) => i.uid.contains('gear-');

  /// ULT a profession weapon may keep (profession_gear_v2.md § 1): any
  /// path or v2 ULT of its type, a legendary one on a Legendary.
  static bool gearUltAllowed(Rarity rarity, String type, String? ultId) {
    if (ultId == null || rarity.index < Rarity.raro.index) return false;
    if (kBranchUltWeaponTypes[ultId]?.contains(type) ?? false) return true;
    final u = kUltV2[ultId];
    return u != null &&
        u.weapons.contains(type) &&
        (u.source == UltSource.weaponMod ||
            (u.source == UltSource.unique && rarity == Rarity.legendario));
  }

  static bool _v2Mod(String id, String type) {
    final u = kUltV2[id];
    return u != null &&
        u.source == UltSource.weaponMod &&
        u.weapons.contains(type);
  }

  /// Deja una instancia leída de disco o de la red en un estado válido.
  /// `null` si la base no existe. Lo inválido se corrige o se descarta:
  /// afijos desconocidos, de otro tipo, repetidos o fuera de cupo; valores
  /// fuera de su rango; pasiva en una rareza sin pasiva; habilidades
  /// desconocidas, del kit de una ascensión o de más; mejoras > 5 por estadística (la suma no se
  /// recorta: las armas migradas conservan su forja).
  ItemInstance? sanitize(ItemInstance raw) {
    final w = catalog.weapons[raw.baseId];
    if (w == null) return null;
    var rarity = raw.rarity;
    final unique = raw.uniqueId == null ? null : kUniques[raw.uniqueId];
    // Profession weapons (profession_gear.md, `gear-` mark) are Legendary
    // without a unique: an Epic made Legendary with a weapon passive.
    final gear = isProfessionGear(raw) && unique == null;
    if (rarity == Rarity.legendario &&
        !gear &&
        (unique == null || unique.baseId != raw.baseId)) {
      rarity = Rarity.epico;
    }
    var item = ItemInstance(
      uid: raw.uid,
      baseId: raw.baseId,
      rarity: rarity,
      itemLevel: raw.itemLevel.clamp(1, maxItemLevel),
      name: raw.name,
      uniqueId: rarity == Rarity.legendario && !gear ? raw.uniqueId : null,
      ultId: ultModAllowed(rarity, w.type, raw.ultId) ||
              (gear && gearUltAllowed(rarity, w.type, raw.ultId))
          ? raw.ultId
          : null,
      // Profession gear v2 (profession_gear_v2.md § 7): its parts and the
      // masterwork mod (before the affixes, so the cap counts it).
      // v1 weapons get `['v1', <affinity>]` (migration, § 8).
      parts: gear ? GearV2Rules.migrate(raw).parts : raw.parts,
      masterwork: raw.masterwork && rarity.maxMods > 0,
      quebrarReplaced: raw.quebrarReplaced,
      // Elemento de base (weapon_identity.md § 4): el legendario recibe
      // el de su tema (migración de los guardados sin el campo); Raro y
      // Épico conservan el suyo; Común y Mágico nunca.
      element: rarity == Rarity.legendario && !gear
          ? uniqueWeaponElement(raw.uniqueId!)
          : rarityAllowsElement(rarity)
              ? raw.element
              : null,
    );
    final kept = <AffixRoll>[];
    for (final a in raw.affixes) {
      final def = kAffixes[a.affixId];
      if (def == null || !def.allows(w.type)) continue;
      final probe = item.copyWith(affixes: kept);
      if (!hasRoomFor(probe, def)) continue;
      if (a.fixed && gear) {
        // A profession weapon's signature / compost mods: fixed, kept.
        kept.add(a);
      } else if (a.fixed) {
        if (rarity != Rarity.legendario) continue;
        // Del piso escalado al techo de diseño: lo nuevo sale escalado y
        // bajar los viejos es la migración (combo_balance.md § 6b).
        final d = rangeOf(item, a, scaled: false);
        final sc = rangeOf(item, a);
        if (d == null || sc == null) continue;
        kept.add(a.withValue(a.value.clamp(sc.$1, d.$2)));
      } else {
        final t = def.tier(a.tier);
        if (t == null) continue;
        kept.add(a.withValue(a.value.clamp(t.min, t.max)));
      }
    }
    var passive = raw.passiveId;
    final pdef = passive == null ? null : kWeaponPassives[passive];
    if (!rarity.hasPassive ||
        pdef == null ||
        (rarity == Rarity.legendario &&
            !gear &&
            passive != unique!.passiveId) ||
        (rarity == Rarity.epico && pdef.unique)) {
      passive = null;
    }
    var forge = const WeaponUpgradeLevels();
    for (final s in UpgradeStat.values) {
      if (s == UpgradeStat.def && w.shieldDefense <= 0) continue;
      forge = forge.withLevel(
          s, raw.forge.level(s).clamp(0, WeaponUpgradeLevels.upMax));
    }
    final skills = <String>[];
    for (final s in raw.extraSkills) {
      // Solo habilidades de arma: el kit de una ascensión (p. ej. el viejo
      // kit del Paladín, hoy del Guardián) nunca se traslada. La forma de
      // entrega (§ 16.1) NO se valida acá: las trasladadas antes de
      // v0.5.1 que hoy no se podrían traer se conservan.
      if (catalog.skills.containsKey(s) &&
          !kAscensionSkills.containsKey(s) &&
          !kBaseQuebrarIds.contains(s) &&
          !skills.contains(s)) {
        skills.add(s);
      }
    }
    item = item.copyWith(
      affixes: kept,
      passiveId: passive,
      clearPassive: passive == null,
      passiveLevel: raw.passiveLevel.clamp(1, ItemInstance.maxPassiveLevel),
      forge: forge,
      extraSkills: skills.length > item.skillCapacity
          ? skills.sublist(skills.length - item.skillCapacity)
          : skills,
    );
    return item;
  }
}
