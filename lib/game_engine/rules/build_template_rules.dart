import 'dart:math' as math;

import '../data/achievements_catalog.dart';
import '../data/ascension_catalog.dart';
import '../data/build_templates_catalog.dart';
import '../data/eco_catalog.dart';
import '../data/ults_v2_catalog.dart';
import '../models/attributes.dart';
import '../models/build_plan.dart';
import '../models/passive_tree.dart';
import 'passive_tree_rules.dart';
import 'progression_rules.dart';
import 'weapon_target_rules.dart';

/// El árbol de una plantilla nivel por nivel (build_planner_v2.md § 2.2
/// y § 3): cada nodo del camino con el nivel en que se toma.
class TemplateTimeline {
  const TemplateTimeline(this.steps, this.errors, this.points);

  final List<TreeStep> steps;
  final List<String> errors;

  /// Puntos que pide el camino completo.
  final int points;

  /// Nodos tomados a [level] (incluye niveles de Maestría: 51–70).
  Set<String> takenAt(int level) =>
      {for (final s in steps) if (s.level <= level) s.node};

  /// Próximo objetivo (notable o keystone) después de [level].
  TreeStep? nextAfter(int level, bool Function(String id) major) {
    for (final s in steps) {
      if (s.level > level && major(s.node)) return s;
    }
    return null;
  }
}

/// Reglas puras de las plantillas v2: validación del archivo, árbol por
/// nivel, atributos por nivel y conversión a plan.
class BuildTemplateRules {
  const BuildTemplateRules(this.progression);

  final ProgressionRules progression;

  PassiveTreeRules get tree => progression.treeRules;
  WeaponTargetRules get weapons => WeaponTargetRules(progression);

  /// Último nivel del árbol por nivel: 50 + 20 de Maestría.
  static const maxTreeLevel = 70;

  /// Pruebas superadas a [level] (30 / 40 / 50).
  static int trialsAt(int level) =>
      [30, 40, 50].where((t) => level >= t).length;

  /// Puntos de árbol a [level] (o nivel + Maestría) con los dos hitos.
  static int pointsAt(int level) => PassiveTreeRules.pointsEarned(level,
      trials: trialsAt(level), ms10: level >= 10, ms20: level >= 20);

  /// Keystone del hito de [e] para [classId]: [e.key] si se ofrece, si
  /// no [e.alt]; `null` si ninguna.
  String? milestoneKey(TemplateTreeEntry e, String classId,
      {Iterable<String> taken = const []}) {
    final opts = tree.milestoneOptions(classId, e.milestone!, taken: taken);
    if (opts.contains(e.key)) return e.key;
    if (e.alt != null && opts.contains(e.alt)) return e.alt;
    return null;
  }

  /// El árbol nivel por nivel: cada objetivo se corre al primer nivel en
  /// que entra su camino (con los puntos de nivel, hitos y Pruebas).
  TemplateTimeline timeline(BuildTemplate t) {
    final errors = <String>[];
    final steps = <TreeStep>[];
    final taken = <String>[];
    var spent = 0;
    var level = 1;
    for (final e in t.tree) {
      String? target;
      if (e.isMilestone) {
        if (e.milestone != 10 && e.milestone != 20) {
          errors.add('Hito ${e.milestone} no existe');
          continue;
        }
        final manual = taken.where((x) => !steps.any(
            (s) => s.node == x && s.milestone != null)).toList();
        target = milestoneKey(e, t.classId, taken: manual);
        if (target == null) {
          errors.add('Hito ${e.milestone}: ni ${e.key} ni ${e.alt} se '
              'ofrecen a ${t.classId}');
          continue;
        }
      } else {
        target = e.node;
      }
      if (target == null) continue;
      final path =
          tree.pathTo(t.classId, PlayerPassiveProgress([...taken]), target);
      if (path == null) {
        errors.add('$target: no se llega desde el inicio');
        continue;
      }
      final cost = path.length;
      var l = math.max(level, math.max(e.level, e.milestone ?? 1));
      while (l <= maxTreeLevel && pointsAt(l) < spent + cost) {
        l++;
      }
      if (l > maxTreeLevel) {
        errors.add('$target: no entra ni con Maestría 20 '
            '(${spent + cost} puntos de ${pointsAt(maxTreeLevel)})');
        break;
      }
      for (final n in path) {
        steps.add(TreeStep(l, n,
            milestone: n == target && e.isMilestone ? e.milestone : null));
        taken.add(n);
      }
      spent += cost;
      level = l;
    }
    return TemplateTimeline(List.unmodifiable(steps), errors, spent);
  }

  /// Atributos crudos de [classId] a [level] con los tramos [spans] (cada
  /// nivel desde el 2 da un punto = +3).
  PlayerAttributes attributesAt(
      String classId, List<AttrSpan> spans, int level) {
    final base = progression.catalog.classes[classId]?.baseAttributes ??
        const <Attribute, int>{};
    final add = <Attribute, int>{};
    for (final s in spans) {
      final to = math.min(s.to, level);
      if (to < s.from) continue;
      add[s.attribute] =
          (add[s.attribute] ?? 0) + (to - s.from + 1) * kAttrPerPoint;
    }
    return PlayerAttributes.base(base).add(add);
  }

  /// Todo lo que está mal en [t] (vacío = válida). Lo usan el test de
  /// datos, la carga y el Editor.
  List<String> validate(BuildTemplate t) {
    final cat = progression.catalog;
    final out = <String>[];
    if (!cat.classes.containsKey(t.classId)) {
      return ['Clase desconocida: ${t.classId}'];
    }
    for (final e in t.tree) {
      for (final id in [e.node, e.key, e.alt]) {
        if (id != null && !tree.catalog.nodes.containsKey(id)) {
          out.add('Nodo desconocido: $id');
        }
      }
    }
    out.addAll(timeline(t).errors);
    if (t.ascensionId != null) {
      final a = kAscensions[t.ascensionId];
      if (a == null) {
        out.add('Ascensión desconocida: ${t.ascensionId}');
      } else {
        if (a.classId != t.classId) out.add('${a.name} no es de ${t.classId}');
        for (final n in t.ascensionOrder) {
          if (a.node(n) == null) out.add('Nodo de ascensión desconocido: $n');
        }
      }
    }
    // Atributos: sin pisarse, de 2 a 50 sin huecos, topes blandos.
    final spans = [...t.attributes]..sort((a, b) => a.from.compareTo(b.from));
    var next = 2;
    for (final s in spans) {
      if (s.from != next) {
        out.add(s.from < next
            ? 'Atributos: tramos que se pisan en el nivel ${s.from}'
            : 'Atributos: hueco entre $next y ${s.from - 1}');
      }
      next = s.to + 1;
    }
    if (spans.isNotEmpty && next != 51) {
      out.add('Atributos: los tramos terminan en ${next - 1} (van hasta 50)');
    }
    for (final s in spans) {
      if (s.overcap) continue;
      final raw = attributesAt(t.classId, spans, s.to)[s.attribute];
      final cap = kAttrSoftCap[s.attribute]!;
      if (raw > cap + 6) {
        out.add('${s.attribute.name.toUpperCase()} $raw pasa el tope $cap '
            '(poné overcap: true si es a propósito)');
      }
    }
    // Armas.
    for (final w in t.weapons) {
      final at = attributesAt(t.classId, spans, w.level);
      for (final m in weapons.validate(w, attributes: at)) {
        out.add('Arma (${w.priority.label}): $m');
      }
    }
    if (t.ultActive != null && !kUltV2.containsKey(t.ultActive)) {
      out.add('ULT desconocida: ${t.ultActive}');
    }
    for (final u in t.ultUpgrades.keys) {
      if (!kUltV2.containsKey(u)) out.add('ULT desconocida: $u');
    }
    for (final f in t.feats) {
      if (!kAchievementsById.containsKey(f)) out.add('Hazaña desconocida: $f');
    }
    for (final m in t.endgame.mastery) {
      if (!tree.catalog.nodes.containsKey(m.node)) {
        out.add('Nodo de Maestría desconocido: ${m.node}');
      }
      if (m.ms < 1 || m.ms > 20) out.add('Maestría ${m.ms} fuera de 1–20');
    }
    for (final a in t.endgame.atlas) {
      if (!kAtlasById.containsKey(a)) out.add('Nodo del Atlas desconocido: $a');
    }
    for (final e in [...t.endgame.ecoPrefer, ...t.endgame.ecoAvoid]) {
      if (!kEcoMods.containsKey(e)) out.add('Mod de Eco desconocido: $e');
    }
    return out;
  }

  /// Objetivos del árbol (sin el camino): notables y keystones.
  List<String> objectives(BuildTemplate t) {
    final out = <String>[];
    final steps = timeline(t).steps;
    for (final e in t.tree) {
      final id = e.isMilestone
          ? steps
              .where((s) => s.milestone == e.milestone)
              .map((s) => s.node)
              .firstOrNull
          : e.node;
      if (id != null && !out.contains(id)) out.add(id);
    }
    for (final m in t.endgame.mastery) {
      if (!out.contains(m.node)) out.add(m.node);
    }
    return out;
  }

  /// La plantilla como plan v2: metas v1 generadas del objetivo
  /// principal (planes viejos y filtro `Build`), árbol por nivel con el
  /// camino completo, atributos por tramo, armas, ULT y hazañas.
  BuildPlan toPlan(BuildTemplate t) {
    final tl = timeline(t);
    final attrsAt50 = attributesAt(t.classId, t.attributes, 50);
    final base = progression.catalog.classes[t.classId]?.baseAttributes ??
        const <Attribute, int>{};
    final goals = <Attribute, int>{
      for (final a in Attribute.values)
        if (attrsAt50[a] > (base[a] ?? 0)) a: attrsAt50[a],
    };
    final main = t.weapons.isEmpty
        ? null
        : (t.weapons.where((w) => w.priority == TargetPriority.main).firstOrNull ??
            t.weapons.first);
    final mainType = main == null ? null : weapons.typeOf(main);
    // Nodos de Maestría al final del árbol por nivel (50 + ms).
    final steps = [...tl.steps];
    final have = {for (final s in steps) s.node};
    for (final m in t.endgame.mastery) {
      final path = tree.pathTo(
          t.classId, PlayerPassiveProgress([...have]), m.node);
      if (path == null) continue;
      for (final n in path) {
        if (have.add(n)) steps.add(TreeStep(50 + m.ms, n));
      }
    }
    final allNodes = [for (final s in steps) s.node];
    return BuildPlan(
      name: t.name,
      templateId: t.id,
      attributes: Map.unmodifiable(goals),
      treeNodes: List.unmodifiable(allNodes),
      ascensionId: t.ascensionId,
      ascensionNodes: List.unmodifiable(t.ascensionOrder),
      weaponTypes: [if (mainType != null) mainType],
      weaponBases: [if (main?.base != null) main!.base!],
      mods: main?.mods ?? const [],
      weaponPassive: main?.passive,
      skills: main?.skills ?? const [],
      targetLevel: 50,
      targetMastery: t.endgame.mastery.isEmpty
          ? null
          : t.endgame.mastery.map((m) => m.ms).reduce(math.max),
      checklist: [for (final c in t.endgame.checklist) ChecklistItem(c)],
      weaponTargets: List.unmodifiable(t.weapons),
      timeline: List.unmodifiable(steps),
      attrSpans: List.unmodifiable(t.attributes),
      ultActive: t.ultActive,
      ultUpgrades: t.ultUpgrades,
      feats: t.feats,
    );
  }

  /// SEGUIR ESTA PLANTILLA: el plan de [t] conservando nombre propio,
  /// notas y checklist de [current] (los ítems del checklist de la
  /// plantilla se suman si no estaban).
  BuildPlan follow(BuildPlan current, BuildTemplate t) {
    final plan = toPlan(t);
    final own = current.name.isNotEmpty &&
        current.name != buildTemplate(current.templateId ?? '')?.name;
    return plan.copyWith(
      name: own ? current.name : t.name,
      notes: current.notes,
      checklist: [
        ...current.checklist,
        for (final c in plan.checklist)
          if (!current.checklist.any((x) => x.text == c.text)) c,
      ],
    );
  }

  /// COMPARAR (§ 3): tu personaje vs. la plantilla al nivel [level], una
  /// línea por cosa.
  List<String> compare(BuildTemplate t, Set<String> taken,
      PlayerAttributes attrs, int level) {
    final tl = timeline(t);
    final want = tl.takenAt(level);
    final name = progression.treeRules.catalog.nodes;
    final out = <String>[];
    final extra = [for (final n in taken) if (!want.contains(n)) n];
    final lack = [for (final n in want) if (!taken.contains(n)) n];
    if (lack.isNotEmpty) {
      out.add('Te faltan ${lack.length} nodo${lack.length == 1 ? '' : 's'}: '
          '${lack.take(4).map((n) => name[n]?.name ?? n).join(', ')}'
          '${lack.length > 4 ? '…' : ''}');
    }
    if (extra.isNotEmpty) {
      out.add('Tenés ${extra.length} nodo${extra.length == 1 ? '' : 's'} '
          'fuera de la plantilla: '
          '${extra.take(4).map((n) => name[n]?.name ?? n).join(', ')}'
          '${extra.length > 4 ? '…' : ''}');
    }
    final plan = attributesAt(t.classId, t.attributes, level);
    for (final a in Attribute.values) {
      final d = attrs[a] - plan[a];
      if (d.abs() >= kAttrPerPoint) {
        out.add('${a.name.toUpperCase()} ${attrs[a]} '
            '(la plantilla tiene ${plan[a]} al nivel $level)');
      }
    }
    if (out.isEmpty) out.add('Vas igual que la plantilla al nivel $level');
    return out;
  }
}
