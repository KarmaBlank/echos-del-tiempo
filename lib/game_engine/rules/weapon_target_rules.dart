import 'dart:math' as math;

import '../data/affixes_catalog.dart';
import '../data/elements_catalog.dart' show elementOf;
import '../data/skills_catalog.dart' show kBaseQuebrarIds;
import '../data/weapon_passives.dart';
import '../data/weapons_catalog.dart' show kWeaponTypeCategory;
import '../models/attributes.dart';
import '../models/build_plan.dart';
import '../models/elements.dart';
import '../models/item.dart';
import '../models/player_profile.dart';
import '../models/upgrade_stat.dart';
import '../models/weapon.dart';
import 'build_plan_rules.dart' show GoalState;
import 'craft_rules.dart';
import 'progression_rules.dart';

/// Clase de requisito de un objetivo de arma (build_planner_v2.md § 1.3).
enum TargetReqKind { base, rarity, slots, mod, passive, skill, itemLevel, stat, forge }

/// Un requisito del objetivo contra un arma: [value] 0–1 (1 = cumplido).
class TargetReq {
  const TargetReq({
    required this.kind,
    required this.key,
    required this.label,
    required this.value,
    this.weight = 1,
    this.detail,
  });

  final TargetReqKind kind;

  /// Único por requisito (`mod:feroz`, `skill:remolino`...).
  final String key;
  final String label;
  final double value;
  final double weight;

  /// Lo que tiene el arma (`T4`, `Raro`, `3/5`).
  final String? detail;

  bool get done => value >= 1;

  GoalState get state => value >= 1
      ? GoalState.done
      : value > 0
          ? GoalState.partial
          : GoalState.todo;
}

/// Un arma (del inventario o del alijo) contra un objetivo.
class WeaponMatch {
  const WeaponMatch({
    required this.item,
    required this.reqs,
    this.inStash = false,
    this.equipped = false,
  });

  final ItemInstance item;
  final List<TargetReq> reqs;

  /// Está en el alijo compartido (se muestra aparte, con etiqueta).
  final bool inStash;
  final bool equipped;

  /// Promedio con peso (base 2, mods 1.5, el resto 1); 0–1.
  double get ratio {
    var w = 0.0, s = 0.0;
    for (final r in reqs) {
      w += r.weight;
      s += r.weight * r.value.clamp(0, 1);
    }
    return w == 0 ? 0 : s / w;
  }

  int get percent => (ratio * 100).round();

  int get missing => reqs.where((r) => !r.done).length;

  TargetReq? req(String key) {
    for (final r in reqs) {
      if (r.key == key) return r;
    }
    return null;
  }
}

/// Una línea de "qué te falta" (build_planner_v2.md § 1.3) o un paso del
/// PLAN DE FUSIÓN (§ 1.5).
class MissingLine {
  const MissingLine({
    required this.key,
    required this.text,
    this.op,
    this.forge = false,
    this.credits = 0,
    this.materials = const {},
    this.sourceUid,
    this.sourceInStash = false,
    this.ref,
  });

  /// Requisito al que responde (`mod:feroz`).
  final String key;
  final String text;

  /// Operación de fusión que lo resuelve (`null` = loot o tienda).
  final CraftOp? op;

  /// Se resuelve forjando (herrería; no es una fusión).
  final bool forge;
  final int credits;
  final Map<CraftMaterial, int> materials;

  /// Donante (se destruye al fusionar).
  final String? sourceUid;

  /// El donante está en el alijo: hay que sacarlo antes (nunca se mueve
  /// solo).
  final bool sourceInStash;

  /// Afijo, habilidad o estadística de forja en juego.
  final String? ref;
}

/// PLAN DE FUSIÓN: pasos en orden con su costo total.
class FusionPlan {
  const FusionPlan(this.steps);
  static const empty = FusionPlan([]);
  final List<MissingLine> steps;
  int get credits => steps.fold(0, (a, s) => a + s.credits);
  Map<CraftMaterial, int> get materials {
    final out = <CraftMaterial, int>{};
    for (final s in steps) {
      for (final e in s.materials.entries) {
        out[e.key] = (out[e.key] ?? 0) + e.value;
      }
    }
    return out;
  }
}

/// Filtros del buscador de bases (§ 1.1). Todo combina con Y.
class BaseQuery {
  const BaseQuery({
    this.text = '',
    this.types = const {},
    this.families = const {},
    this.categories = const {},
    this.elements = const {},
    this.minLevel = 1,
    this.maxLevel = 50,
    this.usableAt,
  });

  final String text;
  final Set<String> types;
  final Set<String> families;
  final Set<WeaponCategory> categories;
  final Set<GameElement> elements;
  final int minLevel;
  final int maxLevel;

  /// "Puedo usarla al nivel del plan": nivel de la base ≤ este.
  final int? usableAt;
}

/// Reglas puras del arma objetivo (docs/specs/build_planner_v2.md § 1):
/// validación, % de cumplimiento contra cada arma, mejor candidata,
/// "qué te falta" con costos (economía v0.15) y plan de fusión.
class WeaponTargetRules {
  const WeaponTargetRules(this.progression);

  final ProgressionRules progression;

  static const baseWeight = 2.0;
  static const modWeight = 1.5;

  WeaponDef? baseOf(ItemInstance i) => progression.catalog.weapons[i.baseId];

  String _itemName(ItemInstance i) => progression.items.displayName(i);

  String affixName(String id) => kAffixes[id]?.name ?? id;

  String skillName(String id) =>
      progression.catalog.skills[id]?.name ?? id;

  String passiveName(String id) => kWeaponPassives[id]?.name ?? id;

  /// Nombre del objetivo: `Hacha Tronante Épica`, `hacha Épica`.
  String targetName(WeaponTarget t) {
    final b = t.base == null ? null : progression.catalog.weapons[t.base];
    final what = b?.name ?? t.type ?? 'Arma';
    final r = t.rarity;
    if (r == null) return what;
    // Género del tipo (hacha Épica, tomo Épico); "Arma" es femenino.
    final type = typeOf(t);
    final female = type == null || _feminine.contains(type);
    final label = switch (r) {
      Rarity.comun => 'Común',
      Rarity.magico => female ? 'Mágica' : 'Mágico',
      Rarity.raro => female ? 'Rara' : 'Raro',
      Rarity.epico => female ? 'Épica' : 'Épico',
      Rarity.legendario => female ? 'Legendaria' : 'Legendario',
    };
    return '$what $label';
  }

  static const _feminine = {
    'espada',
    'hacha',
    'lanza',
    'dagas',
    'varita',
    'ballesta',
    'espada+escudo',
    'maza+escudo',
  };

  /// Tipo del objetivo (de la base o el pedido).
  String? typeOf(WeaponTarget t) =>
      (t.base == null ? null : progression.catalog.weapons[t.base]?.type) ??
      t.type;

  // ------------------------------------------------------------------
  // Validación (§ 1.2)
  // ------------------------------------------------------------------

  /// Motivos por los que [t] no se puede armar (vacío = válido). Con
  /// [attributes] (los del plan a ese nivel) también chequea los
  /// requisitos de la base.
  List<String> validate(WeaponTarget t, {PlayerAttributes? attributes}) {
    final cat = progression.catalog;
    final out = <String>[];
    WeaponDef? base;
    if (t.base != null) {
      base = cat.weapons[t.base];
      if (base == null) out.add('Base desconocida: ${t.base}');
    }
    final type = typeOf(t);
    if (t.base == null && t.type != null &&
        !cat.weapons.values.any((w) => w.type == t.type)) {
      out.add('Tipo desconocido: ${t.type}');
    }
    if (base == null && type == null) out.add('Elegí una base o un tipo');
    final rarity = t.rarity ?? Rarity.comun;
    if (t.slots != null && t.slots! > rarity.maxMods) {
      out.add('${rarity.label}: ${rarity.maxMods} ranuras como máximo');
    }
    var pre = 0, suf = 0;
    for (final m in t.mods) {
      final def = kAffixes[m.affixId];
      if (def == null) {
        out.add('Afijo desconocido: ${m.affixId}');
        continue;
      }
      if (def.slot == AffixSlot.prefix) {
        pre++;
      } else {
        suf++;
      }
      if (type != null && !def.allows(type)) {
        out.add('${def.name} no sale en $type');
      }
      final tier = def.tier(m.minTier) ??
          def.tiers.where((x) => x.tier <= m.minTier).lastOrNull;
      if (tier == null) {
        out.add('${def.name} no tiene T${m.minTier}');
      } else if (t.itemLevel != null && tier.minLevel > t.itemLevel!) {
        out.add('${def.name} T${tier.tier} pide nivel de objeto '
            '${tier.minLevel}');
      }
    }
    if (t.mods.length > rarity.maxMods) {
      out.add('${rarity.label}: ${rarity.maxMods} mods como máximo');
    }
    final side = rarity.affixSideCap;
    if (pre > side) out.add('${rarity.label}: $side prefijos como máximo');
    if (suf > side) out.add('${rarity.label}: $side sufijos como máximo');
    if (t.passive != null) {
      final p = kWeaponPassives[t.passive];
      if (p == null) {
        out.add('Pasiva desconocida: ${t.passive}');
      } else if (!p.unique && type != null && !p.types.contains(type)) {
        out.add('${p.name} no sale en $type');
      } else if (!rarity.hasPassive) {
        out.add('La pasiva pide Épico o Legendario');
      }
    }
    final baseSkills = base?.skillIds ?? const <String>[];
    final extra = [
      for (final s in t.skills)
        if (!baseSkills.contains(s)) s
    ];
    final cap = rarity.skillSlots + (t.keepQuebrar ? 0 : 1);
    if (extra.length > cap) {
      out.add('${rarity.label}: $cap habilidad${cap == 1 ? '' : 'es'} '
          'traída${cap == 1 ? '' : 's'} como máximo');
    }
    for (final s in t.skills) {
      if (!cat.skills.containsKey(s)) {
        out.add('Habilidad desconocida: $s');
        continue;
      }
      if (baseSkills.contains(s) || type == null) continue;
      final why = _skillReject(type, s);
      if (why != null) out.add('${skillName(s)}: $why');
    }
    final forgeCap = rarity.forgeCap;
    if (t.forgeTotal > forgeCap) {
      out.add('${rarity.label}: forja $forgeCap como máximo');
    }
    for (final e in t.forge.entries) {
      if (e.value > WeaponUpgradeLevels.upMax) {
        out.add('${e.key.label}: máximo ${WeaponUpgradeLevels.upMax}');
      }
    }
    if (base != null && attributes != null) {
      for (final e in base.requirements.entries) {
        if (attributes[e.key] < e.value) {
          out.add('Pide ${e.key.name.toUpperCase()} ${e.value}: el plan '
              'tiene ${attributes[e.key]}');
        }
      }
    }
    return out;
  }

  String? _skillReject(String type, String skillId) {
    if (kBaseQuebrarIds.contains(skillId)) return 'Quebrar no se trae';
    final d = progression.items.skillCategory(skillId);
    if (d == null) return 'no se traslada';
    final c = kWeaponTypeCategory[type];
    return switch (d.name) {
      'any' => null,
      'melee' => c == WeaponCategory.melee ? null : 'solo cuerpo a cuerpo',
      'caster' => c == WeaponCategory.caster ? null : 'solo lanzador',
      _ => c == WeaponCategory.ranged ? null : 'solo a distancia',
    };
  }

  // ------------------------------------------------------------------
  // Cumplimiento (§ 1.3)
  // ------------------------------------------------------------------

  /// Cada requisito de [t] contra [it]. Con [viewer], también las
  /// estadísticas mínimas (con su perfil); sin él (el anfitrión, el
  /// filtro) no cuentan.
  WeaponMatch match(WeaponTarget t, ItemInstance it,
      {PlayerProfile? viewer, bool inStash = false}) {
    final w = baseOf(it);
    final reqs = <TargetReq>[];
    if (t.base != null) {
      final want = progression.catalog.weapons[t.base];
      final v = it.baseId == t.base
          ? 1.0
          : (want != null && w?.type == want.type)
              ? 0.5
              : 0.0;
      reqs.add(TargetReq(
          kind: TargetReqKind.base,
          key: 'base',
          label: want?.name ?? t.base!,
          value: v,
          weight: baseWeight,
          detail: w?.name));
    } else if (t.type != null) {
      reqs.add(TargetReq(
          kind: TargetReqKind.base,
          key: 'base',
          label: 'Tipo ${t.type}',
          value: w?.type == t.type ? 1 : 0,
          weight: baseWeight,
          detail: w?.type));
    }
    if (t.rarity case final r?) {
      reqs.add(TargetReq(
          kind: TargetReqKind.rarity,
          key: 'rarity',
          label: r.label,
          value: math.min(1, (it.rarity.index + 1) / (r.index + 1)),
          detail: it.rarity.label));
    }
    if (t.slots case final s?) {
      reqs.add(TargetReq(
          kind: TargetReqKind.slots,
          key: 'slots',
          label: '$s ranuras',
          value: math.min(1, it.rarity.maxMods / s),
          detail: '${it.rarity.maxMods}'));
    }
    for (final m in t.mods) {
      final r = _bestRoll(it, m.affixId);
      final double v;
      if (r == null) {
        v = 0;
      } else if (m.accepts(r.tier)) {
        v = 1;
      } else {
        v = ((6 - r.tier) / (6 - m.minTier)).clamp(0.0, 1.0);
      }
      reqs.add(TargetReq(
          kind: TargetReqKind.mod,
          key: 'mod:${m.affixId}',
          label: '${affixName(m.affixId)} T${m.minTier}',
          value: v,
          weight: modWeight,
          detail: r == null ? null : _tierText(r.tier)));
    }
    if (t.passive case final pid?) {
      final has = it.passiveId == pid && it.rarity.hasPassive;
      final lv = it.effectivePassiveLevel;
      reqs.add(TargetReq(
          kind: TargetReqKind.passive,
          key: 'passive',
          label: '${passiveName(pid)} ${_roman(t.passiveLevel)}',
          value: !has
              ? 0
              : lv >= t.passiveLevel
                  ? 1
                  : lv / t.passiveLevel,
          detail: it.passiveId == null
              ? null
              : '${passiveName(it.passiveId!)} ${_roman(lv)}'));
    }
    final skills = progression.items.skillsOf(it);
    for (final s in t.skills) {
      reqs.add(TargetReq(
          kind: TargetReqKind.skill,
          key: 'skill:$s',
          label: skillName(s),
          value: skills.contains(s) ? 1 : 0));
    }
    if (t.itemLevel case final il?) {
      reqs.add(TargetReq(
          kind: TargetReqKind.itemLevel,
          key: 'ilvl',
          label: 'Nv. de objeto $il',
          value: math.min(1, it.itemLevel / il),
          detail: '${it.itemLevel}'));
    }
    if (viewer != null && t.stats.isNotEmpty) {
      final st = statsWith(viewer, it);
      for (final e in t.stats.entries) {
        final have = st[e.key] ?? 0;
        reqs.add(TargetReq(
            kind: TargetReqKind.stat,
            key: 'stat:${e.key}',
            label: '${kTargetStats[e.key]} ${e.value}${e.key == 'crit' ? '%' : ''}',
            value: e.value <= 0 ? 1 : math.min(1, have / e.value),
            detail: '$have'));
      }
    }
    if (t.forge.isNotEmpty) {
      var want = 0, have = 0;
      for (final e in t.forge.entries) {
        want += e.value;
        have += math.min(e.value, it.forge.level(e.key));
      }
      reqs.add(TargetReq(
          kind: TargetReqKind.forge,
          key: 'forge',
          label: 'Forja ${[
            for (final e in t.forge.entries) '${e.key.label} ${e.value}'
          ].join(', ')}',
          value: want == 0 ? 1 : have / want,
          detail: '$have/$want'));
    }
    return WeaponMatch(
        item: it,
        reqs: reqs,
        inStash: inStash,
        equipped: viewer?.equippedUid == it.uid);
  }

  /// % sin estadísticas (lo mismo que calcula el anfitrión para
  /// `BuildMejora`), 0–1.
  double score(WeaponTarget t, ItemInstance it) => match(t, it).ratio;

  /// Estadísticas de [p] con [it] equipada (claves de [kTargetStats]).
  Map<String, int> statsWith(PlayerProfile p, ItemInstance it) {
    final w = baseOf(it);
    if (w == null) return const {};
    final items = [
      for (final x in p.items)
        if (x.uid != it.uid) x,
      it,
    ];
    final d = progression.previewEquip(p.copyWith(items: items), it.uid);
    return {
      'atk': d.attack,
      'mag': d.magic,
      'crit': (d.critChance * 100).round(),
      'spd': d.speed.round(),
      'def': d.defense,
      'hp': d.maxHp,
    };
  }

  /// Armas de [p] (inventario) y del [stash] contra [t], de mejor a peor:
  /// mayor %, a igual % la equipada, después la de mayor nivel de objeto.
  List<WeaponMatch> candidates(WeaponTarget t, PlayerProfile p,
      {List<ItemInstance> stash = const []}) {
    final out = [
      for (final it in p.items)
        if (baseOf(it) != null) match(t, it, viewer: p),
      for (final it in stash)
        if (baseOf(it) != null) match(t, it, viewer: p, inStash: true),
    ];
    out.sort((a, b) {
      final c = b.ratio.compareTo(a.ratio);
      if (c != 0) return c;
      if (a.equipped != b.equipped) return a.equipped ? -1 : 1;
      if (a.inStash != b.inStash) return a.inStash ? 1 : -1;
      return b.item.itemLevel.compareTo(a.item.itemLevel);
    });
    return out;
  }

  WeaponMatch? best(WeaponTarget t, PlayerProfile p,
      {List<ItemInstance> stash = const []}) {
    final c = candidates(t, p, stash: stash);
    return c.isEmpty ? null : c.first;
  }

  // ------------------------------------------------------------------
  // Qué te falta (§ 1.3) y donantes (§ 1.5)
  // ------------------------------------------------------------------

  static AffixRoll? _bestRoll(ItemInstance it, String affixId) {
    AffixRoll? best;
    for (final a in it.affixes) {
      if (a.affixId != affixId) continue;
      if (best == null || a.tier < best.tier) best = a;
    }
    return best;
  }

  static String _tierText(int tier) => tier == 0 ? 'fijo' : 'T$tier';

  static String _roman(int n) => const ['I', 'II', 'III', 'IV', 'V'][
      (n.clamp(1, 5)) - 1];

  static String credits(int c) {
    final s = '$c';
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '₵$b';
  }

  /// Cuántos requisitos de [t] (sin contar [except]) cumple [it]: un
  /// donante que cumple otros conviene menos.
  int _usefulness(WeaponTarget t, ItemInstance it, String except) =>
      match(t, it).reqs.where((r) => r.key != except && r.value > 0).length;

  /// El mejor donante de [pool] para [key] (`mod:`, `skill:`, `passive`)
  /// hacia [target]: el que lo tiene con mejor tier y menos se pierde al
  /// destruirlo (no equipada, no la última inicial, sin otros requisitos
  /// del plan; inventario antes que alijo).
  ({ItemInstance item, bool inStash, AffixRoll? roll})? donor(
      WeaponTarget t, ItemInstance target, String key, PlayerProfile p,
      {List<ItemInstance> stash = const []}) {
    final pool = [
      for (final it in p.items) (it, false),
      for (final it in stash) (it, true),
    ];
    final inv = progression.inventory;
    ({ItemInstance item, bool inStash, AffixRoll? roll})? best;
    int? bestTier;
    int? bestUse;
    for (final (it, st) in pool) {
      if (it.uid == target.uid) continue;
      if (!st && inv.isProtected(p, it.uid)) continue;
      AffixRoll? roll;
      if (key.startsWith('mod:')) {
        roll = _bestRoll(it, key.substring(4));
        if (roll == null || roll.fixed) continue;
      } else if (key.startsWith('skill:')) {
        final s = key.substring(6);
        if (!progression.items.skillsOf(it).contains(s)) continue;
        if (progression.items.canReceiveSkill(target, s) != null) continue;
      } else if (key == 'passive') {
        final sp = progression.items.passiveOf(it);
        if (sp == null || sp.id != t.passive || sp.unique) continue;
        if (!it.rarity.hasPassive) continue;
      } else {
        continue;
      }
      final tier = roll?.tier ?? 0;
      final use = _usefulness(t, it, key) + (st ? 1 : 0);
      final better = best == null ||
          (roll != null && bestTier != null && tier < bestTier) ||
          ((roll == null || tier == bestTier) && use < bestUse!);
      if (better) {
        best = (item: it, inStash: st, roll: roll);
        bestTier = tier;
        bestUse = use;
      }
    }
    return best;
  }

  String _from(ItemInstance it, bool inStash) =>
      '${_itemName(it)}${inStash ? ' [ALIJO]' : ''}';

  /// "Qué te falta" de [m] (la candidata) para [t], en el orden del spec,
  /// con la acción concreta y su costo. [attributesAt] (opcional) dice
  /// los atributos del plan a un nivel, para el requisito de la base.
  List<MissingLine> missing(WeaponTarget t, WeaponMatch m, PlayerProfile p,
      {List<ItemInstance> stash = const [],
      PlayerAttributes Function(int level)? attributesAt}) {
    final it = m.item;
    final w = baseOf(it);
    final out = <MissingLine>[];
    final rarity = it.rarity;
    for (final r in m.reqs) {
      if (r.done) continue;
      switch (r.kind) {
        case TargetReqKind.base:
          final want = t.base == null
              ? null
              : progression.catalog.weapons[t.base];
          out.add(MissingLine(
              key: r.key,
              text: want == null
                  ? 'Otro tipo: buscá ${t.type}'
                  : 'Otra base: buscá ${want.name} '
                      '(${want.price > 0 ? 'Armería Nv ${want.level} · ${credits(want.price)}' : 'loot Nv ${want.level}+'})'));
        case TargetReqKind.mod:
          final id = r.key.substring(4);
          final goal = t.mods.firstWhere((x) => x.affixId == id);
          final have = _bestRoll(it, id);
          final d = donor(t, it, r.key, p, stash: stash);
          final name = affixName(id);
          if (have != null) {
            if (d != null && d.roll != null && goal.accepts(d.roll!.tier)) {
              final cost = CraftRules.removeAffixCost(have, rarity) +
                  CraftRules.transferAffixCost(d.roll!, rarity);
              out.add(MissingLine(
                  key: r.key,
                  text: '$name ${_tierText(have.tier)} (pedís T${goal.minTier}) '
                      '→ quitalo y trasladá ${_tierText(d.roll!.tier)} desde '
                      '${_from(d.item, d.inStash)} · ${credits(cost)}',
                  op: CraftOp.transferAffix,
                  credits: cost,
                  sourceUid: d.item.uid,
                  sourceInStash: d.inStash,
                  ref: id));
            } else {
              out.add(MissingLine(
                  key: r.key,
                  text: '$name ${_tierText(have.tier)} (pedís T${goal.minTier}) '
                      '→ el tier no sube: buscá uno mejor'));
            }
          } else if (d != null && d.roll != null) {
            final cost = CraftRules.transferAffixCost(d.roll!, rarity);
            out.add(MissingLine(
                key: r.key,
                text: 'Falta $name T${goal.minTier} → trasladalo desde '
                    '${_from(d.item, d.inStash)} (${_tierText(d.roll!.tier)}) '
                    '· ${credits(cost)}',
                op: CraftOp.transferAffix,
                credits: cost,
                sourceUid: d.item.uid,
                sourceInStash: d.inStash,
                ref: id));
          } else {
            out.add(MissingLine(
                key: r.key,
                text: 'Falta $name T${goal.minTier} → Cristal de Era (al azar) '
                    'o buscalo en el loot',
                op: CraftOp.addAffix,
                credits: CraftRules.addAffixCost(rarity),
                materials: const {CraftMaterial.cristal: 1},
                ref: id));
          }
        case TargetReqKind.passive:
          final d = donor(t, it, 'passive', p, stash: stash);
          final cur = it.passiveId == null ? null : passiveName(it.passiveId!);
          final want = passiveName(t.passive!);
          if (it.passiveId == t.passive) {
            out.add(MissingLine(
                key: r.key,
                text: '$want ${_roman(it.effectivePassiveLevel)} '
                    '(pedís ${_roman(t.passiveLevel)}) → subila con forja'));
          } else if (d != null) {
            final cost = CraftRules.transferPassiveCost(Rarity.epico);
            out.add(MissingLine(
                key: r.key,
                text: '${cur == null ? 'Sin pasiva' : 'Pasiva distinta ($cur)'} '
                    '→ fusioná $want desde ${_from(d.item, d.inStash)} · '
                    '${credits(cost)}',
                op: CraftOp.transferPassive,
                credits: cost,
                sourceUid: d.item.uid,
                sourceInStash: d.inStash,
                ref: t.passive));
          } else {
            out.add(MissingLine(
                key: r.key,
                text: 'Pasiva $want → sale en armas Épicas '
                    '(${kWeaponPassives[t.passive]?.unique ?? false ? 'única de un Legendario' : 'buscala en el loot'})'));
          }
        case TargetReqKind.skill:
          final s = r.key.substring(6);
          final d = donor(t, it, r.key, p, stash: stash);
          if (d != null) {
            final cost = CraftRules.transferSkillCost(rarity);
            final mats = CraftRules.transferSkillMaterials(rarity);
            out.add(MissingLine(
                key: r.key,
                text: 'Falta ${skillName(s)} → traela desde '
                    '${_from(d.item, d.inStash)} · ${credits(cost)}'
                    '${mats.isEmpty ? '' : ' + ${mats.values.first} ${CraftMaterial.cristal.label}'}',
                op: CraftOp.transferSkill,
                credits: cost,
                materials: mats,
                sourceUid: d.item.uid,
                sourceInStash: d.inStash,
                ref: s));
          } else {
            final givers = [
              for (final g in progression.catalog.weapons.values)
                if (g.skillIds.contains(s)) g.name
            ];
            out.add(MissingLine(
                key: r.key,
                text: 'Falta ${skillName(s)} → '
                    '${givers.isEmpty ? 'buscala en el loot' : 'la da ${givers.take(2).join(' o ')}'}'));
          }
        case TargetReqKind.rarity:
        case TargetReqKind.slots:
          if (out.any((l) => l.key == 'rarity')) break;
          final want = t.rarity ??
              Rarity.values.firstWhere((x) => x.maxMods >= (t.slots ?? 0),
                  orElse: () => Rarity.epico);
          if (want == Rarity.legendario) {
            out.add(const MissingLine(
                key: 'rarity',
                text: 'Legendario: solo como loot (no se sube por fusión)'));
            break;
          }
          var prisms = 0, cr = 0;
          for (var x = rarity; x.index < want.index; x = Rarity.values[x.index + 1]) {
            final c = CraftRules.upgradeRarityCost(x);
            if (c == null) break;
            prisms += c.$1;
            cr += c.$2;
          }
          final short = prisms - p.material(CraftMaterial.prisma);
          final condense = short <= 0
              ? ''
              : ' (te faltan $short: Condensar 10 Cristales + ${credits(500)} = 1)';
          out.add(MissingLine(
              key: 'rarity',
              text: '${rarity.label} → ${want.label}: $prisms '
                  '${CraftMaterial.prisma.label}${prisms == 1 ? '' : 's'} + '
                  '${credits(cr)}$condense',
              op: CraftOp.upgradeRarity,
              credits: cr,
              materials: {CraftMaterial.prisma: prisms}));
        case TargetReqKind.forge:
          if (w == null) break;
          var cost = 0;
          final parts = <String>[];
          for (final e in t.forge.entries) {
            final have = it.forge.level(e.key);
            if (have >= e.value) continue;
            for (var l = have; l < e.value; l++) {
              cost += CraftRules.forgeCost(w, rarity, l);
            }
            parts.add('${e.key.label} $have/${e.value}');
          }
          out.add(MissingLine(
              key: r.key,
              text: 'Forja ${parts.join(', ')} → ${credits(cost)}',
              forge: true,
              credits: cost));
        case TargetReqKind.itemLevel:
          final hi = [
            for (final m in t.mods)
              if (kAffixes[m.affixId]?.tier(m.minTier) case final tr?
                  when tr.minLevel > it.itemLevel)
                '${affixName(m.affixId)} T${m.minTier}'
          ];
          out.add(MissingLine(
              key: r.key,
              text: hi.isEmpty
                  ? 'Nv. de objeto ${it.itemLevel} (pedís ${t.itemLevel})'
                  : 'Nv. de objeto ${it.itemLevel}: ${hi.first} no puede '
                      'salir; buscá una de nivel ${t.itemLevel}+'));
        case TargetReqKind.stat:
          out.add(MissingLine(
              key: r.key,
              text: '${r.label}: tenés ${r.detail} con esta arma'));
      }
    }
    // Requisitos de atributo de la base.
    final base = t.base == null ? w : progression.catalog.weapons[t.base];
    if (base != null) {
      for (final e in base.requirements.entries) {
        if (p.attributes[e.key] >= e.value) continue;
        int? when;
        if (attributesAt != null) {
          for (var l = p.level; l <= 50; l++) {
            if (attributesAt(l)[e.key] >= e.value) {
              when = l;
              break;
            }
          }
        }
        out.add(MissingLine(
            key: 'req:${e.key.name}',
            text: 'Pide ${e.key.name.toUpperCase()} ${e.value}: '
                '${when == null ? 'tenés ${p.attributes[e.key]}' : 'según tu plan la tenés al nivel $when'}'));
      }
    }
    return out;
  }

  /// PLAN DE FUSIÓN (§ 1.5): las líneas de [missing] que se resuelven con
  /// fusión, en orden: rareza, mods, pasiva, habilidades, forja.
  FusionPlan fusionPlan(WeaponTarget t, WeaponMatch m, PlayerProfile p,
      {List<ItemInstance> stash = const []}) {
    final lines = missing(t, m, p, stash: stash)
        .where((l) => l.op != null || l.forge)
        .toList();
    int order(MissingLine l) => l.forge
        ? 4
        : switch (l.op) {
            CraftOp.upgradeRarity => 0,
            CraftOp.transferAffix || CraftOp.addAffix => 1,
            CraftOp.transferPassive => 2,
            CraftOp.transferSkill => 3,
            _ => 5,
          };
    final sorted = [...lines]..sort((a, b) => order(a).compareTo(order(b)));
    return FusionPlan(sorted);
  }

  /// Lo que un drop aporta al objetivo (aviso y tooltip del loot, § 1.4):
  /// `★ Feroz T2 (te falta)` si cumple un requisito que ninguna tuya
  /// cumple, `★ 81% del objetivo` si sube el % de la mejor; `null` si no
  /// mejora nada.
  String? lootNote(WeaponTarget t, ItemInstance drop, WeaponMatch? best) {
    final m = match(t, drop);
    final bestScore = best == null ? 0.0 : match(t, best.item).ratio;
    for (final r in m.reqs) {
      if (!r.done || r.kind == TargetReqKind.base) continue;
      final mine = best == null ? null : match(t, best.item).req(r.key);
      if (mine == null || !mine.done) return '★ ${r.label} (te falta)';
    }
    if (m.ratio > bestScore) return '★ ${m.percent}% del objetivo';
    return null;
  }

  // ------------------------------------------------------------------
  // Buscador de bases (§ 1.1)
  // ------------------------------------------------------------------

  static String fold(String s) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunAEIOUUN';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final k = from.indexOf(ch);
      b.write(k < 0 ? ch : to[k]);
    }
    return b.toString().toLowerCase();
  }

  /// Elementos de las habilidades de una base.
  Set<GameElement> elementsOf(WeaponDef w) => {
        for (final s in w.skillIds)
          if (elementOf(s) != GameElement.fisico) elementOf(s),
      };

  /// Todas las bases del catálogo que pasan [q]: por nivel; con texto, por
  /// coincidencia (nombre de la base primero, después habilidades e
  /// implícito).
  List<WeaponDef> searchBases(BaseQuery q) {
    final text = fold(q.text.trim());
    final out = <(WeaponDef, int)>[];
    for (final w in progression.catalog.weapons.values) {
      if (w.level < q.minLevel || w.level > q.maxLevel) continue;
      if (q.usableAt != null && w.level > q.usableAt!) continue;
      if (q.types.isNotEmpty && !q.types.contains(w.type)) continue;
      if (q.families.isNotEmpty && !q.families.contains(w.classId)) continue;
      if (q.categories.isNotEmpty &&
          !q.categories.contains(kWeaponTypeCategory[w.type])) {
        continue;
      }
      if (q.elements.isNotEmpty &&
          !elementsOf(w).any(q.elements.contains)) {
        continue;
      }
      var rank = 0;
      if (text.isNotEmpty) {
        if (fold(w.name).contains(text)) {
          rank = fold(w.name).startsWith(text) ? 0 : 1;
        } else if (w.skillIds.any((s) => fold(skillName(s)).contains(text))) {
          rank = 2;
        } else if (w.implicit.any((m) => fold(m.text).contains(text)) ||
            fold(w.type).contains(text)) {
          rank = 3;
        } else {
          continue;
        }
      }
      out.add((w, rank));
    }
    out.sort((a, b) {
      final c = a.$2.compareTo(b.$2);
      return c != 0 ? c : a.$1.level.compareTo(b.$1.level);
    });
    return [for (final (w, _) in out) w];
  }

  /// Objetivo nuevo para la base [w] con lo que ya trae (sus habilidades).
  WeaponTarget targetFor(WeaponDef w,
          {TargetPriority priority = TargetPriority.main, int level = 1}) =>
      WeaponTarget(
          priority: priority,
          level: math.max(level, w.level),
          base: w.id,
          type: w.type,
          skills: List.unmodifiable(w.skillIds));

  /// Atributos que piden [w] y que [attrs] no alcanza.
  List<Attribute> missingRequirements(WeaponDef w, PlayerAttributes attrs) => [
        for (final e in w.requirements.entries)
          if (attrs[e.key] < e.value) e.key
      ];
}
