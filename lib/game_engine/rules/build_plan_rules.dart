import '../data/affixes_catalog.dart';
import '../data/ascension_catalog.dart';
import '../data/build_templates_catalog.dart';
import '../data/weapon_passives.dart';
import '../models/ascension.dart';
import '../models/attributes.dart';
import '../models/build_plan.dart';
import '../models/item.dart';
import '../models/passive_tree.dart';
import '../models/player_profile.dart';
import 'ascension_rules.dart';
import 'progression_rules.dart';

/// Clase de meta de un plan (docs/specs/build_planner.md § 2).
enum BuildGoalKind {
  attribute,
  treeNode,
  ascension,
  ascensionNode,
  weaponType,
  weaponBase,
  mod,
  weaponPassive,
  skill,
  level,
  mastery,
  check,
}

/// Sección de la pantalla BUILD donde va cada meta (en orden).
enum BuildSection {
  attributes('ATRIBUTOS'),
  tree('ÁRBOL'),
  ascension('ASCENSIÓN'),
  weapon('ARMA Y MODS'),
  skills('HABILIDADES'),
  level('NIVEL'),
  notes('NOTAS Y CHECKLIST');

  const BuildSection(this.label);
  final String label;
}

extension BuildGoalKindSection on BuildGoalKind {
  BuildSection get section => switch (this) {
        BuildGoalKind.attribute => BuildSection.attributes,
        BuildGoalKind.treeNode => BuildSection.tree,
        BuildGoalKind.ascension ||
        BuildGoalKind.ascensionNode =>
          BuildSection.ascension,
        BuildGoalKind.weaponType ||
        BuildGoalKind.weaponBase ||
        BuildGoalKind.mod ||
        BuildGoalKind.weaponPassive =>
          BuildSection.weapon,
        BuildGoalKind.skill => BuildSection.skills,
        BuildGoalKind.level || BuildGoalKind.mastery => BuildSection.level,
        BuildGoalKind.check => BuildSection.notes,
      };
}

/// Estado de una meta: hecha, en camino, sin empezar o imposible con
/// este personaje.
enum GoalState { done, partial, todo, blocked }

/// El estado calculado de una meta del plan.
class GoalStatus {
  const GoalStatus({
    required this.kind,
    required this.key,
    required this.ref,
    required this.label,
    required this.state,
    this.current = 0,
    this.total = 0,
    this.hint,
    this.major = false,
  });

  final BuildGoalKind kind;

  /// Clave estable (`attr:fue`, `node:<id>`, `mod:<afijo>`...).
  final String key;

  /// Id de lo que apunta (para quitarla del plan).
  final String ref;

  /// Texto corto ("FUE 40", "Keystone Demoledor", "Feroz T3+").
  final String label;
  final GoalState state;

  /// Progreso contable; `total` 0 = la meta no tiene barra.
  final int current;
  final int total;

  /// Pista corta de qué falta.
  final String? hint;

  /// Notable o keystone del árbol (se lista aparte de los nodos chicos).
  final bool major;

  bool get done => state == GoalState.done;
  bool get countable => total > 1;

  /// Fracción para la barra total (bloqueadas: 0, no cuentan).
  double get fraction => switch (state) {
        GoalState.done => 1,
        GoalState.partial =>
          total > 0 ? (current / total).clamp(0.0, 0.99) : 0.5,
        _ => 0,
      };
}

/// Todo el progreso de un plan contra un perfil.
class BuildProgress {
  const BuildProgress({
    required this.goals,
    required this.next,
    this.classId = '',
  });

  static const none =
      BuildProgress(goals: [], next: 'Agregá metas o aplicá una plantilla');

  final List<GoalStatus> goals;

  /// Siguiente paso sugerido (una línea).
  final String next;
  final String classId;

  Iterable<GoalStatus> get counted =>
      goals.where((g) => g.state != GoalState.blocked);

  int get doneCount => goals.where((g) => g.done).length;

  /// Promedio de las metas que cuentan (0..1).
  double get ratio {
    final c = counted.toList();
    if (c.isEmpty) return 0;
    return c.fold<double>(0, (s, g) => s + g.fraction) / c.length;
  }

  GoalStatus? byKey(String key) {
    for (final g in goals) {
      if (g.key == key) return g;
    }
    return null;
  }

  List<GoalStatus> section(BuildSection s) => [
        for (final g in goals)
          if (g.kind.section == s) g
      ];
}

/// Un aviso de avance (§ 5).
class BuildNotice {
  const BuildNotice(this.key, this.text, {this.done = false});

  final String key;
  final String text;

  /// La meta se completó (★).
  final bool done;

  @override
  String toString() => text;
}

/// Lo que un arma concreta aporta al plan (§ 4.1).
class ItemFit {
  const ItemFit({this.matches = const [], this.near = const []});

  static const none = ItemFit();

  /// Metas que cumple ("+7% ATQ (T5)", "base del plan").
  final List<String> matches;

  /// Casi: el mod con peor tier ("Feroz T5 (buscás T3)").
  final List<String> near;

  bool get any => matches.isNotEmpty;
  bool get isEmpty => matches.isEmpty && near.isEmpty;
}

/// Reglas puras del planificador de build (docs/specs/build_planner.md):
/// progreso de cada meta, siguiente paso, avisos y encaje de un arma.
class BuildPlanRules {
  const BuildPlanRules(this.progression);

  final ProgressionRules progression;

  static const _asc = AscensionRules();

  static String attributeShort(Attribute a) => a.name.toUpperCase();

  /// "Feroz (% ATQ)".
  static String affixLabel(String affixId) {
    final a = kAffixes[affixId];
    if (a == null) return affixId;
    return '${a.name} (${a.stat.label.trim()})';
  }

  String skillName(String id) => progression.catalog.skills[id]?.name ?? id;

  String baseName(String id) => progression.catalog.weapons[id]?.name ?? id;

  String nodeName(String id) =>
      progression.treeRules.catalog.nodes[id]?.name ?? id;

  /// Texto de un nodo del árbol con su tipo ("Keystone Demoledor").
  String nodeLabel(String id) {
    final n = progression.treeRules.catalog.nodes[id];
    if (n == null) return id;
    return switch (n.kind) {
      'k' => 'Keystone ${n.name}',
      'n' => 'Notable ${n.name}',
      _ => n.name,
    };
  }

  /// Habilidades que [p] tiene en batalla: kit, arma equipada (con las
  /// fusionadas) y el kit de su ascensión.
  Set<String> skillsInUse(PlayerProfile p) => {
        ...progression.weaponSkills(p),
        ...?_asc.of(p)?.skillIds,
      };

  // ------------------------------------------------------------------
  // Evaluación
  // ------------------------------------------------------------------

  BuildProgress evaluate(BuildPlan plan, PlayerProfile p) {
    if (plan.goalCount == 0) return BuildProgress.none;
    final goals = <GoalStatus>[
      for (final a in Attribute.values)
        if (plan.attributes[a] case final t?) _attribute(p, a, t),
      for (final id in plan.treeNodes) _treeNode(p, id),
      if (plan.ascensionId case final id?) _ascension(p, id),
      for (final id in plan.ascensionNodes) _ascensionNode(p, plan, id),
      for (final t in plan.weaponTypes) _weaponType(p, t),
      for (final b in plan.weaponBases) _weaponBase(p, b),
      for (final m in plan.mods) _mod(p, m),
      if (plan.weaponPassive case final wp?) _passive(p, wp),
      for (final s in plan.skills) _skill(p, s),
      if (plan.targetLevel case final l?)
        _counter(BuildGoalKind.level, 'lvl', 'Nivel $l', p.level, l),
      if (plan.targetMastery case final m?)
        _counter(BuildGoalKind.mastery, 'ms', 'Maestría $m', p.mastery, m),
      for (var i = 0; i < plan.checklist.length; i++)
        GoalStatus(
          kind: BuildGoalKind.check,
          key: 'check:$i',
          ref: '$i',
          label: plan.checklist[i].text,
          state: plan.checklist[i].done ? GoalState.done : GoalState.todo,
        ),
    ];
    return BuildProgress(
        goals: List.unmodifiable(goals),
        next: _next(plan, p, goals),
        classId: p.classId);
  }

  GoalStatus _attribute(PlayerProfile p, Attribute a, int target) {
    final cur = p.attributes[a];
    final short = attributeShort(a);
    return GoalStatus(
      kind: BuildGoalKind.attribute,
      key: 'attr:${a.name}',
      ref: a.name,
      label: '$short $target',
      state: cur >= target ? GoalState.done : GoalState.partial,
      current: cur.clamp(0, target),
      total: target,
      hint: cur >= target ? null : 'faltan ${target - cur} puntos',
    );
  }

  GoalStatus _counter(
      BuildGoalKind kind, String key, String label, int cur, int target) {
    return GoalStatus(
      kind: kind,
      key: key,
      ref: key,
      label: label,
      state: cur >= target
          ? GoalState.done
          : cur > 0
              ? GoalState.partial
              : GoalState.todo,
      current: cur.clamp(0, target),
      total: target,
      hint: cur >= target ? null : 'faltan ${target - cur}',
    );
  }

  GoalStatus _treeNode(PlayerProfile p, String id) {
    final tree = progression.treeRules;
    final node = tree.catalog.nodes[id];
    final major = node != null && (node.kind == 'n' || node.kind == 'k');
    GoalStatus st(GoalState s, [String? hint]) => GoalStatus(
          kind: BuildGoalKind.treeNode,
          key: 'node:$id',
          ref: id,
          label: nodeLabel(id),
          state: s,
          hint: hint,
          major: major,
        );
    if (node == null) return st(GoalState.blocked, 'nodo desconocido');
    if (tree.hasNode(p.classId, p.passiveProgress, id)) {
      return st(GoalState.done);
    }
    final route = tree.pathTo(p.classId, p.passiveProgress, id);
    if (route == null) {
      final ex = tree.catalog.exclusions[id];
      return st(GoalState.blocked,
          ex == null ? 'no se llega' : 'excluido por ${nodeName(ex)}');
    }
    final n = route.length;
    return st(GoalState.todo, n == 1 ? 'falta 1 punto' : 'faltan $n puntos');
  }

  GoalStatus _ascension(PlayerProfile p, String id) {
    final def = kAscensions[id];
    GoalStatus st(GoalState s, [String? hint]) => GoalStatus(
          kind: BuildGoalKind.ascension,
          key: 'asc',
          ref: id,
          label: 'Ascender a ${def?.name ?? id}',
          state: s,
          hint: hint,
        );
    if (def == null) return st(GoalState.blocked, 'ascensión desconocida');
    if (def.classId != p.classId) {
      return st(GoalState.blocked, 'es de otra clase');
    }
    if (p.ascension.id == id) return st(GoalState.done);
    if (p.ascension.id != null) {
      return st(GoalState.blocked,
          'elegiste ${kAscensions[p.ascension.id]?.name ?? p.ascension.id}');
    }
    if (p.ascension.trials.contains(1)) {
      return st(GoalState.partial, 'elegila en la Estatua del Tiempo');
    }
    return st(GoalState.todo, 'superá la Prueba del Tiempo I');
  }

  GoalStatus _ascensionNode(PlayerProfile p, BuildPlan plan, String id) {
    final def = kAscensions[plan.ascensionId] ??
        kAscensions.values.where((a) => a.node(id) != null).firstOrNull;
    final node = def?.node(id);
    GoalStatus st(GoalState s, [String? hint]) => GoalStatus(
          kind: BuildGoalKind.ascensionNode,
          key: 'ascN:$id',
          ref: id,
          label: node?.name ?? id,
          state: s,
          hint: hint,
        );
    if (def == null || node == null) {
      return st(GoalState.blocked, 'nodo desconocido');
    }
    if (def.classId != p.classId) {
      return st(GoalState.blocked, 'es de otra clase');
    }
    final a = p.ascension;
    if (a.id == def.id && _asc.has(a, id)) return st(GoalState.done);
    if (a.id != null && a.id != def.id) {
      return st(GoalState.blocked, 'es de ${def.name}');
    }
    if (a.id == def.id) {
      final free = _asc.free(a);
      return st(
          GoalState.partial,
          free >= node.cost
              ? 'cuesta ${node.cost} (tenés $free)'
              : 'cuesta ${node.cost}: faltan Pruebas');
    }
    return st(GoalState.todo, 'primero ascendé a ${def.name}');
  }

  ItemInstance? _equipped(PlayerProfile p) => progression.equippedItem(p);

  String _itemName(ItemInstance it) => progression.items.displayName(it);

  GoalStatus _weaponType(PlayerProfile p, String type) {
    final cat = progression.catalog;
    GoalStatus st(GoalState s, [String? hint]) => GoalStatus(
          kind: BuildGoalKind.weaponType,
          key: 'type:$type',
          ref: type,
          label: 'Tipo: $type',
          state: s,
          hint: hint,
        );
    if (!cat.weapons.values.any((w) => w.type == type)) {
      return st(GoalState.blocked, 'tipo desconocido');
    }
    final eq = _equipped(p);
    if (eq != null && cat.weapons[eq.baseId]?.type == type) {
      return st(GoalState.done);
    }
    for (final it in p.items) {
      if (cat.weapons[it.baseId]?.type == type) {
        return st(GoalState.partial, 'tenés ${_itemName(it)}: equipala');
      }
    }
    return st(GoalState.todo, 'Armería o loot');
  }

  GoalStatus _weaponBase(PlayerProfile p, String id) {
    final w = progression.catalog.weapons[id];
    GoalStatus st(GoalState s, [String? hint]) => GoalStatus(
          kind: BuildGoalKind.weaponBase,
          key: 'base:$id',
          ref: id,
          label: w?.name ?? id,
          state: s,
          hint: hint,
        );
    if (w == null) return st(GoalState.blocked, 'base desconocida');
    final eq = _equipped(p);
    if (eq?.baseId == id) return st(GoalState.done);
    if (p.items.any((i) => i.baseId == id)) {
      return st(GoalState.partial, 'la tenés: equipala');
    }
    return st(
        GoalState.todo,
        w.price > 0
            ? 'Armería · Nv ${w.level} · ₵${w.price}'
            : 'sale como loot (Nv ${w.level})');
  }

  /// Mejor tirada de [affixId] en [it] (menor tier; los fijos, 0).
  static AffixRoll? _bestRoll(ItemInstance it, String affixId) {
    AffixRoll? best;
    for (final a in it.affixes) {
      if (a.affixId != affixId) continue;
      if (best == null || a.tier < best.tier) best = a;
    }
    return best;
  }

  static String _tierText(int tier) => tier == 0 ? 'fijo' : 'T$tier';

  GoalStatus _mod(PlayerProfile p, ModGoal m) {
    final def = kAffixes[m.affixId];
    final label = '${def?.name ?? m.affixId} T${m.minTier}+';
    GoalStatus st(GoalState s, [String? hint]) => GoalStatus(
          kind: BuildGoalKind.mod,
          key: 'mod:${m.affixId}',
          ref: m.affixId,
          label: label,
          state: s,
          hint: hint,
        );
    if (def == null) return st(GoalState.blocked, 'afijo desconocido');
    final eq = _equipped(p);
    final onEq = eq == null ? null : _bestRoll(eq, m.affixId);
    if (onEq != null && m.accepts(onEq.tier)) {
      return st(GoalState.done,
          '${def.stat.format(onEq.value)} (${_tierText(onEq.tier)})');
    }
    for (final it in p.items) {
      if (it.uid == eq?.uid) continue;
      final r = _bestRoll(it, m.affixId);
      if (r != null && m.accepts(r.tier)) {
        return st(GoalState.partial,
            '${_tierText(r.tier)} en ${_itemName(it)}: trasladalo en FUSIÓN');
      }
    }
    if (onEq != null) {
      return st(GoalState.partial,
          '${_tierText(onEq.tier)} en tu arma (buscás T${m.minTier})');
    }
    final need = def.tier(m.minTier)?.minLevel;
    return st(GoalState.todo,
        need == null ? 'buscalo en el loot' : 'sale desde Nv de objeto $need');
  }

  GoalStatus _passive(PlayerProfile p, String id) {
    final def = kWeaponPassives[id];
    GoalStatus st(GoalState s, [String? hint]) => GoalStatus(
          kind: BuildGoalKind.weaponPassive,
          key: 'wp',
          ref: id,
          label: 'Pasiva ${def?.name ?? id}',
          state: s,
          hint: hint,
        );
    if (def == null) return st(GoalState.blocked, 'pasiva desconocida');
    final eq = _equipped(p);
    if (eq?.passiveId == id) return st(GoalState.done);
    for (final it in p.items) {
      if (it.passiveId == id) {
        return st(GoalState.partial,
            'en ${_itemName(it)}: equipala o trasladala en FUSIÓN');
      }
    }
    return st(GoalState.todo,
        def.unique ? 'de un Legendario único' : 'sale en armas Épicas');
  }

  GoalStatus _skill(PlayerProfile p, String id) {
    final cat = progression.catalog;
    GoalStatus st(GoalState s, [String? hint]) => GoalStatus(
          kind: BuildGoalKind.skill,
          key: 'skill:$id',
          ref: id,
          label: skillName(id),
          state: s,
          hint: hint,
        );
    if (!cat.skills.containsKey(id)) {
      return st(GoalState.blocked, 'habilidad desconocida');
    }
    if (skillsInUse(p).contains(id)) return st(GoalState.done);
    for (final it in p.items) {
      if (progression.items.skillsOf(it).contains(id)) {
        return st(GoalState.partial, 'la da ${_itemName(it)}');
      }
    }
    for (final a in kAscensions.values) {
      if (a.skillIds.contains(id)) {
        return st(a.classId == p.classId ? GoalState.todo : GoalState.blocked,
            'kit de ${a.name}');
      }
    }
    final givers = [
      for (final w in cat.weapons.values)
        if (w.skillIds.contains(id)) w,
    ]..sort((a, b) => a.level.compareTo(b.level));
    return st(
        GoalState.todo,
        givers.isEmpty
            ? 'trasladala en FUSIÓN'
            : 'la da ${givers.take(2).map((w) => w.name).join(' o ')}');
  }

  // ------------------------------------------------------------------
  // Siguiente paso (§ 2)
  // ------------------------------------------------------------------

  String _next(BuildPlan plan, PlayerProfile p, List<GoalStatus> goals) {
    // 1. Puntos de atributo sin repartir: el atributo al que más le
    // falta.
    if (p.points > 0) {
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
        return 'Tenés ${p.points} punto${p.points == 1 ? '' : 's'}: '
            'según tu build, ${attributeShort(best)} '
            '(${p.attributes[best]}/${plan.attributes[best]})';
      }
    }
    // 2. El nodo planificado más cercano.
    final tree = progression.treeRules;
    final free = tree.pointsAvailable(p.treeLevel, p.passiveProgress);
    List<String>? bestRoute;
    String? bestTarget;
    for (final id in plan.treeNodes) {
      final r = tree.pathTo(p.classId, p.passiveProgress, id);
      if (r == null || r.isEmpty) continue;
      if (bestRoute == null || r.length < bestRoute.length) {
        bestRoute = r;
        bestTarget = id;
      }
    }
    if (bestRoute != null && bestTarget != null) {
      final target = nodeName(bestTarget);
      if (free > 0) {
        return bestRoute.length == 1
            ? 'Tenés puntos de árbol: tomá $target'
            : 'Tomá ${nodeName(bestRoute.first)} → camino a $target '
                '(${bestRoute.length} puntos)';
      }
      final n = bestRoute.length;
      final pending = goals.any((g) =>
          g.kind != BuildGoalKind.treeNode &&
          g.kind != BuildGoalKind.check &&
          g.state != GoalState.done &&
          g.state != GoalState.blocked);
      if (!pending || n <= 3) {
        return n == 1
            ? 'Te falta 1 punto para $target'
            : 'Te faltan $n puntos para $target';
      }
    }
    // 3. Ascensión.
    for (final g in goals) {
      if (g.kind == BuildGoalKind.ascension && g.state == GoalState.partial) {
        return 'Elegí ${kAscensions[g.ref]?.name ?? g.ref} en la Estatua '
            'del Tiempo';
      }
      if (g.kind == BuildGoalKind.ascensionNode &&
          g.state == GoalState.partial &&
          _asc.cannotTake(p, g.ref) == null) {
        return 'Tomá ${g.label} en la Estatua del Tiempo';
      }
    }
    // 4. Arma: primero equipar la base del plan que ya tiene.
    for (final g in goals) {
      if (g.kind == BuildGoalKind.weaponBase && g.state == GoalState.partial) {
        return 'Equipá ${g.label}';
      }
    }
    for (final g in goals) {
      if (g.state != GoalState.partial) continue;
      switch (g.kind) {
        case BuildGoalKind.weaponBase:
          return 'Equipá ${g.label}';
        case BuildGoalKind.weaponType:
        case BuildGoalKind.mod:
        case BuildGoalKind.weaponPassive:
        case BuildGoalKind.skill:
          return '${g.label}: ${g.hint}';
        default:
          break;
      }
    }
    for (final g in goals) {
      if (g.kind == BuildGoalKind.weaponBase && g.state == GoalState.todo) {
        final w = progression.catalog.weapons[g.ref];
        if (w != null && w.price > 0 && w.level <= p.level) {
          return 'Comprá ${w.name} en la Armería (₵${w.price})';
        }
      }
    }
    // 5. La primera meta sin hacer con pista.
    for (final g in goals) {
      if (g.state == GoalState.done || g.state == GoalState.blocked) continue;
      return g.hint == null ? g.label : '${g.label}: ${g.hint}';
    }
    return goals.every((g) => g.done || g.state == GoalState.blocked)
        ? '¡Build completa!'
        : 'Seguí jugando: tu build avanza sola';
  }

  // ------------------------------------------------------------------
  // Avisos (§ 5)
  // ------------------------------------------------------------------

  /// Qué avanzó de [before] a [after] (mismo plan). No avisa retrocesos.
  static List<BuildNotice> diff(BuildProgress before, BuildProgress after) {
    // Solo glifos que tiene la fuente (★ y », no ✓): retro_text.dart.
    final out = <BuildNotice>[];
    var smallDone = 0;
    for (final g in after.goals) {
      final old = before.byKey(g.key);
      if (old == null || g.kind == BuildGoalKind.check) continue;
      if (g.done && !old.done) {
        if (g.kind == BuildGoalKind.treeNode && !g.major) {
          smallDone++;
          continue;
        }
        out.add(BuildNotice(g.key, 'Build: ★ ${g.label}', done: true));
        continue;
      }
      if (g.done) continue;
      if (g.countable && g.current > old.current) {
        final short = switch (g.kind) {
          BuildGoalKind.attribute => g.label.split(' ').first,
          BuildGoalKind.level => 'Nivel',
          BuildGoalKind.mastery => 'Maestría',
          _ => g.label,
        };
        out.add(BuildNotice(g.key, 'Build: $short ${g.current}/${g.total}'));
        continue;
      }
      if (g.state == GoalState.partial && old.state == GoalState.todo) {
        out.add(BuildNotice(g.key, 'Build: » ${g.label} (${g.hint})'));
      }
    }
    if (smallDone > 0) {
      final small = [
        for (final g in after.goals)
          if (g.kind == BuildGoalKind.treeNode) g
      ];
      final done = small.where((g) => g.done).length;
      out.add(BuildNotice('tree', 'Build: árbol $done/${small.length}'));
    }
    return out;
  }

  // ------------------------------------------------------------------
  // Encaje de un arma (§ 4.1)
  // ------------------------------------------------------------------

  /// Qué metas del plan cumple el arma [it] por sí misma.
  ItemFit itemFit(BuildPlan plan, ItemInstance it) {
    if (plan.goalCount == 0) return ItemFit.none;
    final w = progression.catalog.weapons[it.baseId];
    final matches = <String>[];
    final near = <String>[];
    if (plan.weaponBases.contains(it.baseId)) matches.add('base del plan');
    if (w != null && plan.weaponTypes.contains(w.type)) {
      matches.add('tipo ${w.type}');
    }
    for (final m in plan.mods) {
      final r = _bestRoll(it, m.affixId);
      final def = kAffixes[m.affixId];
      if (r == null || def == null) continue;
      if (m.accepts(r.tier)) {
        matches.add('${def.stat.format(r.value)} (${_tierText(r.tier)})');
      } else {
        near.add('${def.name} ${_tierText(r.tier)} (buscás T${m.minTier})');
      }
    }
    if (plan.weaponPassive != null && it.passiveId == plan.weaponPassive) {
      matches
          .add('pasiva ${kWeaponPassives[it.passiveId]?.name ?? it.passiveId}');
    }
    final skills = progression.items.skillsOf(it);
    for (final s in plan.skills) {
      if (skills.contains(s)) matches.add(skillName(s));
    }
    return ItemFit(matches: matches, near: near);
  }

  /// Lo que [after] cumple y [before] no (vista previa de la fusión).
  ItemFit advances(BuildPlan plan, ItemInstance before, ItemInstance after) {
    final a = itemFit(plan, before);
    final b = itemFit(plan, after);
    return ItemFit(
      matches: [
        for (final m in b.matches)
          if (!a.matches.contains(m)) m
      ],
      near: [
        for (final m in b.near)
          if (!a.near.contains(m)) m
      ],
    );
  }

  // ------------------------------------------------------------------
  // Edición
  // ------------------------------------------------------------------

  /// Agrega al plan los nodos que faltan para llegar a cada nodo
  /// planificado desde el inicio de [classId] (pasando por los ya
  /// planificados), en orden. Lo usan las plantillas y + CAMINO.
  BuildPlan withTreePaths(BuildPlan plan, String classId,
      {PlayerPassiveProgress? taken}) {
    final tree = progression.treeRules;
    final have = <String>[...?taken?.takenNodeIds];
    final out = <String>[];
    for (final id in plan.treeNodes) {
      final route =
          tree.pathTo(classId, PlayerPassiveProgress([...have, ...out]), id);
      if (route == null) {
        if (!out.contains(id)) out.add(id);
        continue;
      }
      for (final n in route) {
        if (!out.contains(n)) out.add(n);
      }
      // Ya lo tiene (o es el inicio): la meta se queda igual.
      if (!out.contains(id)) out.add(id);
    }
    return plan.copyWith(treeNodes: out);
  }

  /// Aplica la plantilla [t]: reemplaza las metas (con el camino del
  /// árbol completo) y conserva nombre propio, notas y checklist de
  /// [current] (§ 3).
  BuildPlan applyTemplate(BuildPlan current, BuildTemplate t) {
    final plan = withTreePaths(t.plan, t.classId);
    return plan.copyWith(
      // Nombre propio del jugador: se queda; el de otra plantilla, no.
      name: current.name.isEmpty ||
              current.name == buildTemplate(current.templateId ?? '')?.name
          ? t.name
          : current.name,
      notes: current.notes,
      checklist: current.checklist,
    );
  }

  /// Ascensión a la que pertenece un nodo de mini-árbol.
  static AscensionDef? ascensionOfNode(String nodeId) {
    for (final a in kAscensions.values) {
      if (a.node(nodeId) != null) return a;
    }
    return null;
  }
}
