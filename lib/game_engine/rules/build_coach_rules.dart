import '../data/affixes_catalog.dart';
import '../data/ascension_catalog.dart';
import '../data/build_templates_catalog.dart';
import '../models/attributes.dart';
import '../models/build_plan.dart';
import '../models/item.dart';
import '../models/player_profile.dart';
import 'build_guide_rules.dart';
import 'build_plan_rules.dart';
import 'craft_rules.dart';

/// Áreas de la vista simple de BUILD (build_planner.md § 10.3), en orden.
enum BuildArea {
  attributes('Atributos'),
  tree('Árbol'),
  weapon('Arma'),
  mods('Mods'),
  skills('Habilidades'),
  ult('ULT');

  const BuildArea(this.label);
  final String label;
}

/// A dónde lleva el botón de un paso (§ 10.2). `none`: sin botón.
enum BuildStepAction { attributes, tree, armory, equip, ult, none }

/// Un paso de "Qué hacer ahora", en palabras completas.
class BuildStep {
  const BuildStep(this.text, this.action, {this.ref, this.where = const []});

  final String text;
  final BuildStepAction action;

  /// Uid del arma para [BuildStepAction.equip].
  final String? ref;

  /// "Dónde la conseguís": fuentes concretas, una por línea (§ 10.2).
  final List<String> where;
}

/// Progreso de un área: metas hechas / metas.
class AreaProgress {
  const AreaProgress(this.area, this.done, this.total);

  final BuildArea area;
  final int done;
  final int total;

  bool get complete => total > 0 && done >= total;
  double get ratio => total == 0 ? 0 : done / total;
}

/// Etiqueta simple de cuánto te sirve un arma (§ 10.4).
enum WeaponFit {
  ideal('Ideal'),
  works('Sirve'),
  stopgap('De paso');

  const WeaponFit(this.label);
  final String label;
}

/// Estado de un mod buscado respecto del arma objetivo (§ 10.5).
enum ModState {
  /// El arma objetivo ya lo tiene con ese nivel.
  onWeapon,

  /// Otra arma tuya lo tiene y se puede pasar al arma objetivo en FUSIÓN.
  transferable,

  /// Otra arma tuya lo tiene pero no entra en el arma objetivo.
  blocked,

  /// Otra arma tuya lo tiene y no hay arma objetivo.
  elsewhere,

  /// Ninguna arma tuya lo tiene.
  missing,
}

/// Un mod buscado (del plan o del arma objetivo principal), § 10.5.
class ModWanted {
  const ModWanted(this.affixId, this.minTier,
      {this.state = ModState.missing,
      this.source,
      this.target,
      this.reason,
      this.suggestion});

  final String affixId;
  final int minTier;
  final ModState state;

  /// Nombre del arma tuya que ya lo tiene (si no es la objetivo).
  final String? source;

  /// Nombre del arma objetivo.
  final String? target;

  /// Por qué no entra en el arma objetivo ([ModState.blocked]).
  final String? reason;

  /// Dónde sí podría ir ([ModState.blocked]).
  final String? suggestion;

  /// Listo solo si está en el arma objetivo.
  bool get have => state == ModState.onWeapon;

  String get name => kAffixes[affixId]?.name ?? affixId;

  /// "Arcano, nivel 3 o mejor".
  String get text => '$name, ${BuildCoach.tierText(minTier)}';

  /// Estado en una línea.
  String get status => switch (state) {
        ModState.onWeapon => 'En tu arma',
        ModState.transferable =>
          'Lo tenés en $source: pasalo a $target en FUSIÓN',
        ModState.blocked => 'Lo tenés en $source, pero no entra en '
            '$target: $reason${suggestion == null ? '' : '. $suggestion'}',
        ModState.elsewhere => 'Lo tenés en $source',
        ModState.missing => 'Falta',
      };
}

/// Vista simple del builder (build_planner.md § 10): textos en palabras
/// completas, próximos pasos y progreso por área. Puro y determinista.
class BuildCoach {
  const BuildCoach(this.plans);

  final BuildPlanRules plans;

  BuildGuideRules get _guide => BuildGuideRules(plans.progression);

  /// Máximo de pasos en "Qué hacer ahora".
  static const maxSteps = 3;

  static String attributeName(Attribute a) => switch (a) {
        Attribute.vit => 'Vitalidad',
        Attribute.esp => 'Espíritu',
        Attribute.agi => 'Agilidad',
        Attribute.fue => 'Fuerza',
        Attribute.des => 'Destreza',
      };

  /// "Fuerza (FUE)": la sigla solo entre paréntesis.
  static String attributeLabel(Attribute a) =>
      '${attributeName(a)} (${BuildPlanRules.attributeShort(a)})';

  /// Expande las siglas sueltas de atributos de un texto del motor
  /// ("usa FUE" → "usa Fuerza (FUE)").
  static String expandShorts(String text) => text.replaceAllMapped(
      RegExp(r'(?<![(\w])(VIT|ESP|AGI|FUE|DES)(?![\w)])'),
      (m) => attributeLabel(Attribute.values.byName(m[1]!.toLowerCase())));

  /// `maza+escudo` → "Maza y escudo".
  static String typeName(String type) {
    final s = type.replaceAll('+', ' y ').replaceAll('_', ' ');
    return s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  }

  /// Nivel de mod en palabras (T1 es el mejor).
  static String tierText(int tier) => tier <= 1
      ? 'nivel 1 (el mejor)'
      : tier >= 5
          ? 'cualquier nivel'
          : 'nivel $tier o mejor';

  static String difficultyLabel(int d) => switch (d) {
        <= 1 => 'Fácil',
        2 => 'Media',
        _ => 'Avanzada',
      };

  /// Tipo de arma recomendado de una plantilla (el de su objetivo
  /// principal), o `null`.
  String? templateWeaponType(BuildTemplate t) {
    final targets = plans.targets;
    WeaponTarget? main;
    for (final w in t.weapons) {
      if (w.priority == TargetPriority.main) {
        main = w;
        break;
      }
    }
    main ??= t.weapons.isEmpty ? null : t.weapons.first;
    return main == null ? null : targets.typeOf(main);
  }

  /// Progreso por área.
  List<AreaProgress> areas(BuildPlan plan, PlayerProfile p, BuildProgress pr,
      {List<ItemInstance> stash = const []}) {
    AreaProgress of(BuildArea a, bool Function(BuildGoalKind) f) {
      final g = [
        for (final x in pr.goals)
          if (f(x.kind)) x
      ];
      return AreaProgress(a, g.where((x) => x.done).length, g.length);
    }

    final mods = modsWanted(plan, p, stash: stash);
    return [
      of(BuildArea.attributes, (k) => k == BuildGoalKind.attribute),
      of(
          BuildArea.tree,
          (k) =>
              k == BuildGoalKind.treeNode ||
              k == BuildGoalKind.ascension ||
              k == BuildGoalKind.ascensionNode),
      of(
          BuildArea.weapon,
          (k) =>
              k == BuildGoalKind.weaponType ||
              k == BuildGoalKind.weaponBase ||
              k == BuildGoalKind.weaponPassive ||
              k == BuildGoalKind.weaponTarget),
      AreaProgress(
          BuildArea.mods, mods.where((m) => m.have).length, mods.length),
      of(BuildArea.skills, (k) => k == BuildGoalKind.skill),
      of(
          BuildArea.ult,
          (k) =>
              k == BuildGoalKind.ultActive ||
              k == BuildGoalKind.ultUpgrade ||
              k == BuildGoalKind.feat),
    ];
  }

  CraftRules get _craft => CraftRules(loot: plans.progression.loot);

  String _name(ItemInstance it) => plans.progression.items.displayName(it);

  WeaponTarget? _mainTarget(BuildPlan plan) {
    for (final t in plan.weaponTargets) {
      if (t.priority == TargetPriority.main) return t;
    }
    return plan.weaponTargets.isEmpty ? null : plan.weaponTargets.first;
  }

  /// Arma contra la que se miden los mods: la mejor candidata del
  /// objetivo principal o, si no hay, la equipada.
  ItemInstance? targetWeapon(BuildPlan plan, PlayerProfile p,
      {List<ItemInstance> stash = const []}) {
    final main = _mainTarget(plan);
    if (main != null) {
      final b = plans.targets.best(main, p, stash: stash);
      if (b != null) return b.item;
    }
    return p.equippedItem;
  }

  Map<String, int> _wantedTiers(BuildPlan plan) {
    final want = <String, int>{};
    void add(ModGoal m) {
      final cur = want[m.affixId];
      if (cur == null || m.minTier < cur) want[m.affixId] = m.minTier;
    }

    plan.mods.forEach(add);
    _mainTarget(plan)?.mods.forEach(add);
    return want;
  }

  static AffixRoll? _rollOf(ItemInstance it, String id, int tier) {
    for (final a in it.affixes) {
      if (a.affixId == id && ModGoal(id, tier).accepts(a.tier)) return a;
    }
    return null;
  }

  /// Mods del plan y del arma objetivo principal, sin repetir (gana el
  /// nivel más exigente), con su estado respecto de [targetWeapon].
  List<ModWanted> modsWanted(BuildPlan plan, PlayerProfile p,
      {List<ItemInstance> stash = const []}) {
    final items = [...p.items, ...stash];
    final target = targetWeapon(plan, p, stash: stash);
    final craft = _craft;
    final out = <ModWanted>[];
    for (final e in _wantedTiers(plan).entries) {
      final id = e.key, tier = e.value;
      if (target != null && _rollOf(target, id, tier) != null) {
        out.add(ModWanted(id, tier,
            state: ModState.onWeapon, target: _name(target)));
        continue;
      }
      final sources = [
        for (final it in items)
          if (it.uid != target?.uid && _rollOf(it, id, tier) != null) it
      ];
      if (sources.isEmpty) {
        out.add(
            ModWanted(id, tier, target: target == null ? null : _name(target)));
        continue;
      }
      if (target == null) {
        out.add(ModWanted(id, tier,
            state: ModState.elsewhere, source: _name(sources.first)));
        continue;
      }
      ItemInstance? ok;
      String? why;
      for (final s in sources) {
        final w = craft.transferAffixBlock(target, _rollOf(s, id, tier)!);
        if (w == null) {
          ok = s;
          break;
        }
        why ??= w;
      }
      if (ok != null) {
        out.add(ModWanted(id, tier,
            state: ModState.transferable,
            source: _name(ok),
            target: _name(target)));
        continue;
      }
      final from = sources.first;
      final roll = _rollOf(from, id, tier)!;
      String? suggestion;
      for (final it in items) {
        if (it.uid == from.uid || it.uid == target.uid) continue;
        if (craft.transferAffixBlock(it, roll) == null) {
          suggestion = 'Podría ir en ${_name(it)}';
          break;
        }
      }
      final types = kAffixes[id]?.types;
      if (suggestion == null && types != null && types.isNotEmpty) {
        suggestion = 'Entra en armas de tipo '
            '${_orList((types.toList()..sort()).map(typeName).toList())}';
      }
      out.add(ModWanted(id, tier,
          state: ModState.blocked,
          source: _name(from),
          target: _name(target),
          reason: why,
          suggestion: suggestion));
    }
    return out;
  }

  /// Mods buscados que podés pasarle a [target] desde otras armas tuyas
  /// (FUSIÓN, "Traer un mod"), respetando las reglas: "Arcano desde
  /// <arma>" (§ 10.4).
  List<String> transferableTo(
      ItemInstance target, BuildPlan plan, PlayerProfile p,
      {List<ItemInstance> stash = const []}) {
    final items = [...p.items, ...stash];
    final craft = _craft;
    final out = <String>[];
    for (final e in _wantedTiers(plan).entries) {
      if (_rollOf(target, e.key, e.value) != null) continue;
      for (final s in items) {
        if (s.uid == target.uid) continue;
        final r = _rollOf(s, e.key, e.value);
        if (r != null && craft.transferAffixBlock(target, r) == null) {
          out.add('${kAffixes[e.key]?.name ?? e.key} desde ${_name(s)}');
          break;
        }
      }
    }
    return out;
  }

  /// "Dónde la conseguís" de una habilidad (§ 10.2).
  List<String> skillWhere(String id, PlayerProfile p,
      {List<ItemInstance> stash = const []}) {
    final items = plans.progression.items;
    final cat = plans.progression.catalog;
    final stashUids = {for (final s in stash) s.uid};
    final out = <String>[];
    ItemInstance? owned;
    for (final it in [...p.items, ...stash]) {
      if (items.skillsOf(it).contains(id)) {
        owned ??= it;
        out.add('Ya la tenés en ${_name(it)} '
            '(${stashUids.contains(it.uid) ? 'alijo' : 'inventario'}): '
            'equipala');
      }
    }
    final givers = [
      for (final w in cat.weapons.values)
        if (w.skillIds.contains(id)) w,
    ]..sort((a, b) => a.level.compareTo(b.level));
    for (final w in givers.take(3)) {
      out.add('La da ${w.name} (${typeName(w.type)}, nivel ${w.level})');
    }
    for (final a in kAscensions.values) {
      if (a.skillIds.contains(id)) {
        out.add(a.classId == p.classId
            ? 'Kit de la ascensión ${a.name}'
            : 'Kit de la ascensión ${a.name} (de otra clase)');
      }
    }
    out.add(owned != null
        ? 'FUSIÓN, Traer una habilidad: desde ${_name(owned)} a tu arma'
        : 'FUSIÓN, Traer una habilidad: desde un arma que la tenga');
    return out;
  }

  /// "Dónde lo conseguís" de un mod buscado (§ 10.2).
  List<String> modWhere(ModWanted m) {
    final rar = [
      for (final r in Rarity.values)
        if (r.maxMods > 0) r.label
    ];
    final types = kAffixes[m.affixId]?.types;
    final typeText = types == null || types.isEmpty
        ? ''
        : ' de tipo ${_orList((types.toList()..sort()).map(typeName).toList())}';
    return [
      if (m.state == ModState.transferable)
        'FUSIÓN, Traer un mod: de ${m.source} a ${m.target}',
      if (m.state == ModState.blocked || m.state == ModState.elsewhere)
        m.status,
      'Sale al azar en armas de rareza ${_orList(rar)}$typeText',
      'FORJA, Agregar un mod: suma uno al azar a tu arma',
      if (m.state == ModState.missing)
        'FUSIÓN, Traer un mod: desde un arma que lo tenga',
    ];
  }

  /// "Dónde la conseguís" de un tipo de arma (§ 10.2).
  List<String> typeWhere(String type) {
    final bases = [
      for (final w in plans.progression.catalog.weapons.values)
        if (w.type == type) w,
    ]..sort((a, b) => a.level.compareTo(b.level));
    return [
      for (final w in bases.take(3))
        '${w.name} (${typeName(w.type)}, nivel ${w.level})',
      'ARMERÍA: comprala si está a la venta',
      'FORJA, Reforjar base: pasá tu arma a ${typeName(type)}',
    ];
  }

  static String _orList(List<String> l) => l.length <= 1
      ? l.join()
      : '${l.sublist(0, l.length - 1).join(', ')} o ${l.last}';

  /// Qué tan bien te sirve un arma tuya: contra el objetivo principal
  /// si hay (`≥ 80 %` Ideal, `≥ 50 %` Sirve), si no por tipo.
  WeaponFit fitOf(WeaponPick w, BuildPlan plan, WeaponAdvice advice) {
    if (!w.meets) return WeaponFit.stopgap;
    final r = targetRatio(w, plan);
    if (r != null) {
      return r >= 0.8
          ? WeaponFit.ideal
          : r >= 0.5
              ? WeaponFit.works
              : WeaponFit.stopgap;
    }
    final type = advice.activeType;
    return type.isNotEmpty && w.base.type == type
        ? WeaponFit.ideal
        : WeaponFit.works;
  }

  /// Cuánto cumple [w] del objetivo principal (0–1), o `null`.
  double? targetRatio(WeaponPick w, BuildPlan plan) {
    if (w.item == null || plan.weaponTargets.isEmpty) return null;
    final t = plan.weaponTargets.firstWhere(
        (t) => t.priority == TargetPriority.main,
        orElse: () => plan.weaponTargets.first);
    return plans.targets.score(t, w.item!);
  }

  /// "Qué hacer ahora": hasta [maxSteps] pasos, el más urgente primero.
  List<BuildStep> nextSteps(BuildPlan plan, PlayerProfile p,
      {List<ItemInstance> stash = const [], BuildProgress? progress}) {
    final pr = progress ?? plans.evaluate(plan, p, stash: stash);
    final out = <BuildStep>[];

    // 1. Atributos: puntos libres en el del tramo de la plantilla o, si
    // no hay, en el que más falta.
    if (p.points > 0 && plan.spanAttributeAt(p.level) != null) {
      final a = plan.spanAttributeAt(p.level)!;
      out.add(BuildStep(
          'Poné ${p.points} ${p.points == 1 ? 'punto' : 'puntos'} en '
          '${attributeLabel(a)}',
          BuildStepAction.attributes));
    } else if (p.points > 0) {
      Attribute? best;
      var gap = 0;
      for (final a in Attribute.values) {
        final t = plan.attributes[a];
        if (t != null && t - p.attributes[a] > gap) {
          gap = t - p.attributes[a];
          best = a;
        }
      }
      if (best != null) {
        final n =
            ((gap + kAttrPerPoint - 1) ~/ kAttrPerPoint).clamp(1, p.points);
        out.add(BuildStep(
            'Poné $n ${n == 1 ? 'punto' : 'puntos'} en ${attributeLabel(best)}',
            BuildStepAction.attributes));
      }
    }

    // 2. Árbol: el siguiente nodo del orden sugerido.
    final next = _guide.treeOrder(plan, p).next;
    if (next != null) {
      final tree = plans.progression.treeRules;
      final free = tree.pointsAvailable(p.treePoints, p.passiveProgress);
      final path = tree.pathTo(p.classId, p.passiveProgress, next.node);
      final need = (path?.length ?? 1) - free;
      final name = plans.nodeName(next.node);
      out.add(BuildStep(
          need > 0
              ? 'Tomá el nodo $name del árbol (te '
                  '${need == 1 ? 'falta 1 punto' : 'faltan $need puntos'})'
              : 'Tomá el nodo $name del árbol',
          BuildStepAction.tree));
    }

    // 3. Arma: equipar la mejor que tenés o ir a comprar del tipo ideal.
    if (plan.goalCount > 0) {
      final a = _guide.advice(plan, p, stash: stash);
      final best = a.best;
      final stashUids = {for (final s in stash) s.uid};
      final type = a.activeType;
      if (best != null &&
          best.meets &&
          !best.equipped &&
          !stashUids.contains(best.item!.uid)) {
        out.add(BuildStep(
            'Equipá ${plans.progression.items.displayName(best.item!)}',
            BuildStepAction.equip,
            ref: best.item!.uid));
      } else if (type.isNotEmpty && (best == null || best.base.type != type)) {
        out.add(BuildStep('Conseguí un arma de tipo ${typeName(type)}',
            BuildStepAction.armory,
            where: typeWhere(type)));
      }
    }

    // 4. Mods que faltan.
    for (final m in modsWanted(plan, p, stash: stash)) {
      if (!m.have) {
        out.add(BuildStep(
            'Conseguí el mod ${m.name} en tu arma (${tierText(m.minTier)})',
            BuildStepAction.none,
            where: modWhere(m)));
        break;
      }
    }

    // 5. Habilidades y ULT.
    for (final g in pr.goals) {
      if (g.done || g.state == GoalState.blocked) continue;
      if (g.kind == BuildGoalKind.skill) {
        out.add(BuildStep(
            'Conseguí la habilidad ${g.label}', BuildStepAction.none,
            where: skillWhere(g.ref, p, stash: stash)));
        break;
      }
    }
    for (final g in pr.goals) {
      if (g.done || g.state == GoalState.blocked) continue;
      if (g.kind == BuildGoalKind.ultActive) {
        out.add(BuildStep(
            'Equipá la ${g.label.replaceFirst('ULT activa: ', 'ULT ')}',
            BuildStepAction.ult));
        break;
      }
    }
    return out.take(maxSteps).toList();
  }
}
