import '../data/affixes_catalog.dart';
import '../data/build_templates_catalog.dart';
import '../models/attributes.dart';
import '../models/build_plan.dart';
import '../models/item.dart';
import '../models/player_profile.dart';
import 'build_guide_rules.dart';
import 'build_plan_rules.dart';

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
enum BuildStepAction { attributes, tree, armory, equip, none }

/// Un paso de "Qué hacer ahora", en palabras completas.
class BuildStep {
  const BuildStep(this.text, this.action, {this.ref});

  final String text;
  final BuildStepAction action;

  /// Uid del arma para [BuildStepAction.equip].
  final String? ref;
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

/// Un mod buscado (del plan o del arma objetivo principal), § 10.5.
class ModWanted {
  const ModWanted(this.affixId, this.minTier, {required this.have});

  final String affixId;
  final int minTier;

  /// Alguna de tus armas (o del alijo) ya lo tiene con ese nivel.
  final bool have;

  String get name => kAffixes[affixId]?.name ?? affixId;

  /// "Arcano, nivel 3 o mejor".
  String get text => '$name, ${BuildCoach.tierText(minTier)}';
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

  /// Mods del plan y del arma objetivo principal, sin repetir (gana el
  /// nivel más exigente).
  List<ModWanted> modsWanted(BuildPlan plan, PlayerProfile p,
      {List<ItemInstance> stash = const []}) {
    final want = <String, int>{};
    void add(ModGoal m) {
      final cur = want[m.affixId];
      if (cur == null || m.minTier < cur) want[m.affixId] = m.minTier;
    }

    plan.mods.forEach(add);
    WeaponTarget? main;
    for (final t in plan.weaponTargets) {
      if (t.priority == TargetPriority.main) {
        main = t;
        break;
      }
    }
    main ??= plan.weaponTargets.isEmpty ? null : plan.weaponTargets.first;
    main?.mods.forEach(add);
    final items = [...p.items, ...stash];
    bool have(String id, int tier) => items.any((it) => it.affixes
        .any((a) => a.affixId == id && ModGoal(id, tier).accepts(a.tier)));
    return [
      for (final e in want.entries)
        ModWanted(e.key, e.value, have: have(e.key, e.value)),
    ];
  }

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
            BuildStepAction.armory));
      }
    }

    // 4. Mods que faltan.
    for (final m in modsWanted(plan, p, stash: stash)) {
      if (!m.have) {
        out.add(BuildStep(
            'Conseguí el mod ${m.name} en tu arma (${tierText(m.minTier)})',
            BuildStepAction.none));
        break;
      }
    }

    // 5. Habilidades y ULT.
    for (final g in pr.goals) {
      if (g.done || g.state == GoalState.blocked) continue;
      if (g.kind == BuildGoalKind.skill) {
        out.add(BuildStep(
            'Conseguí la habilidad ${g.label}', BuildStepAction.none));
        break;
      }
    }
    for (final g in pr.goals) {
      if (g.done || g.state == GoalState.blocked) continue;
      if (g.kind == BuildGoalKind.ultActive) {
        out.add(BuildStep(
            'Usá la ${g.label.replaceFirst('ULT activa: ', 'ULT ')}',
            BuildStepAction.none));
        break;
      }
    }
    return out.take(maxSteps).toList();
  }
}
