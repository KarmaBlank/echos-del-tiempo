import '../data/affixes_catalog.dart';
import '../data/branch_ults_catalog.dart';
import '../data/passive_mechanics.dart';
import '../data/tuning_catalog.dart';
import '../data/weapon_passives.dart';
import '../data/weapons_catalog.dart';
import '../models/attributes.dart';
import '../models/build_plan.dart';
import '../models/item.dart';
import '../models/passive_mechanic.dart';
import '../models/passive_tree.dart';
import '../models/player_profile.dart';
import '../models/skill.dart';
import '../models/status.dart';
import '../models/weapon.dart';
import 'build_plan_rules.dart';
import 'progression_rules.dart';

/// Afinidad: etiqueta → peso, con de dónde salió cada etiqueta
/// (build_planner.md § 9.1).
class BuildAffinity {
  BuildAffinity();

  final Map<String, double> weights = {};
  final Map<String, String> sources = {};

  bool get isEmpty => weights.isEmpty;

  void add(String tag, double w, [String? source]) {
    if (w <= 0) return;
    weights[tag] = (weights[tag] ?? 0) + w;
    if (source != null) sources.putIfAbsent(tag, () => source);
  }

  void addAll(BuildAffinity o, [double factor = 1]) {
    o.weights.forEach((k, v) => add(k, v * factor, o.sources[k]));
  }

  double operator [](String tag) => weights[tag] ?? 0;

  double get total => weights.values.fold(0.0, (a, b) => a + b);
}

/// Un paso del orden sugerido del árbol (§ 9.2).
class TreeOrderStep {
  const TreeOrderStep({
    required this.node,
    required this.step,
    required this.reason,
    this.alternatives = 1,
    this.onPlan = true,
  });

  final String node;
  final int step;
  final String reason;

  /// Cuántos candidatos había en este paso (> 1: había que elegir).
  final int alternatives;

  /// `false`: nodo que conecta, fuera del plan.
  final bool onPlan;
}

/// Secuencia numerada de los nodos del plan que faltan.
class TreeOrder {
  const TreeOrder(this.steps);

  static const empty = TreeOrder([]);

  final List<TreeOrderStep> steps;

  TreeOrderStep? get next => steps.isEmpty ? null : steps.first;

  Map<String, int> get numbers => {for (final s in steps) s.node: s.step};

  TreeOrderStep? of(String node) {
    for (final s in steps) {
      if (s.node == node) return s;
    }
    return null;
  }
}

/// Un arma rankeada para tu build (§ 9.3).
class WeaponPick {
  const WeaponPick({
    required this.base,
    this.item,
    required this.score,
    required this.reasons,
    required this.meets,
    this.equipped = false,
    this.recommended = false,
  });

  final WeaponDef base;
  final ItemInstance? item;
  final double score;
  final List<String> reasons;
  final bool meets;
  final bool equipped;
  final bool recommended;

  String get id => item?.uid ?? base.id;

  WeaponPick _recommend() => WeaponPick(
      base: base,
      item: item,
      score: score,
      reasons: reasons,
      meets: meets,
      equipped: equipped,
      recommended: true);
}

/// Guía del builder (docs/specs/build_planner.md § 9): orden del árbol y
/// armas recomendadas. Puro y determinista.
class BuildGuideRules {
  const BuildGuideRules(this.progression);

  final ProgressionRules progression;

  static TuningDef get _t => tuning(TuningId.buildGuide);

  PassiveTreeCatalog get _tree => progression.treeRules.catalog;

  BuildPlanRules get _plans => BuildPlanRules(progression);

  // ------------------------------------------------------------------
  // Etiquetas
  // ------------------------------------------------------------------

  static String tagLabel(String tag) {
    if (tag.startsWith('s:')) {
      final k = StatusKind.values.where((s) => s.name == tag.substring(2));
      return k.isEmpty ? tag : k.first.label;
    }
    if (tag.startsWith('t:')) {
      return switch (tag.substring(2)) {
        'onCrit' => 'al critar',
        'onHit' => 'al golpear',
        'onKill' => 'al matar',
        'onEnemyDeath' => 'al caer enemigos',
        'onHitTaken' => 'al recibir golpes',
        'onProtectHit' => 'al proteger',
        'onStatusApplied' => 'al aplicar estados',
        'onSkill' => 'al usar habilidades',
        'onHeal' => 'al curar',
        'onTurnStart' => 'al empezar el turno',
        _ => 'mecánica',
      };
    }
    return switch (tag) {
      'atk' => 'ATQ',
      'mag' => 'MAG',
      'crit' => 'crítico',
      'hp' => 'vida',
      'def' => 'defensa',
      'spd' => 'velocidad',
      'heal' => 'curas',
      'mp' => 'MP',
      _ => tag,
    };
  }

  static String? _modTag(ModStat s) => switch (s) {
        ModStat.atkPct || ModStat.flatAtk || ModStat.fue => 'atk',
        ModStat.magPct || ModStat.flatMag || ModStat.esp => 'mag',
        ModStat.critChance || ModStat.critMulti || ModStat.des => 'crit',
        ModStat.speed || ModStat.agi => 'spd',
        ModStat.burnStacks => 's:burn',
        ModStat.poisonStacks => 's:poison',
        ModStat.freezeStacks => 's:freeze',
        ModStat.vit || ModStat.maxHp => 'hp',
        ModStat.maxMp => 'mp',
        ModStat.defense => 'def',
        ModStat.healPower || ModStat.healReceived || ModStat.regen => 'heal',
        _ => null,
      };

  static bool isCaster(WeaponDef w) =>
      kWeaponTypeCategory[w.type] == WeaponCategory.caster;

  // ------------------------------------------------------------------
  // Afinidad (§ 9.1)
  // ------------------------------------------------------------------

  void _skill(BuildAffinity a, SkillDef s, double f, String source) {
    switch (s.kind) {
      case SkillKind.physical:
        a.add('atk', f, source);
      case SkillKind.magical:
        a.add('mag', f, source);
      case SkillKind.heal || SkillKind.regen:
        a.add('heal', f, source);
      case SkillKind.haste:
        a.add('spd', f, source);
      case SkillKind.taunt ||
            SkillKind.guard ||
            SkillKind.defenseUp ||
            SkillKind.protect ||
            SkillKind.bulwark:
        a.add('def', f, source);
        a.add('hp', f * 0.5, source);
      default:
        break;
    }
    for (final st in [if (s.status case final x?) x, ...s.extraStatuses]) {
      a.add('s:${st.kind.name}', f * 1.5, source);
    }
    if (s.critBonus > 0) a.add('crit', f, source);
  }

  void _mechanic(BuildAffinity a, PassiveMechanic m, double f, String source) {
    a.add('t:${m.trigger.name}', f, source);
    if (m.status case final st?) a.add('s:${st.name}', f, source);
    if (m.trigger == ProcTrigger.onCrit) a.add('crit', f * 0.7, source);
  }

  /// Afinidad de un arma (base + instancia, si la hay).
  BuildAffinity weaponAffinity(WeaponDef w, [ItemInstance? it]) {
    final t = _t;
    final a = BuildAffinity();
    final caster = isCaster(w);
    a.add(caster ? 'mag' : 'atk', t.d('dmgWeight'), w.name);
    if (!caster && w.mag != null) a.add('mag', t.d('dmgWeight') * 0.25, w.name);
    final skills = it == null ? w.skillIds : progression.items.skillsOf(it);
    for (final id in skills) {
      final s = progression.catalog.skills[id];
      if (s != null) _skill(a, s, 1, s.name);
    }
    if (it == null) return a;
    if (it.element?.status case final st?) {
      a.add('s:${st.name}', t.d('elementWeight'), 'elemento ${it.element!.label}');
    }
    if (it.passiveId case final pid?) {
      final def = kWeaponPassives[pid];
      if (def != null) {
        for (final m in def.mechanicsAt(it.effectivePassiveLevel)) {
          _mechanic(a, m, t.d('passiveWeight'), 'pasiva ${def.name}');
        }
      }
    }
    if (it.ultId case final u?) {
      final s = progression.catalog.playerUlts[u] ?? kWeaponUltSkills[u];
      if (s != null) _skill(a, s, 1, 'ULT ${s.name}');
    }
    for (final r in it.affixes) {
      final def = kAffixes[r.affixId];
      if (def == null) continue;
      if (_modTag(def.stat) case final tag?) {
        a.add(tag, t.d('modWeight'), 'mod ${def.name}');
      }
    }
    return a;
  }

  /// Arma equipada + lo que pide el plan (habilidades, pasiva, base).
  BuildAffinity affinityOf(BuildPlan plan, PlayerProfile p) {
    final a = BuildAffinity();
    final it = progression.equippedItem(p);
    final w = progression.catalog.weapons[it?.baseId] ??
        progression.equippedWeapon(p);
    a.addAll(weaponAffinity(w, it));
    for (final id in plan.skills) {
      final s = progression.catalog.skills[id];
      if (s != null) _skill(a, s, 0.5, s.name);
    }
    if (plan.weaponPassive case final pid?) {
      final def = kWeaponPassives[pid];
      if (def != null) {
        for (final m in def.mechanicsAt(1)) {
          _mechanic(a, m, _t.d('passiveWeight') * 0.5, 'pasiva ${def.name}');
        }
      }
    }
    for (final b in plan.weaponBases.take(1)) {
      final pw = progression.catalog.weapons[b];
      if (pw != null && pw.id != w.id) a.addAll(weaponAffinity(pw), 0.5);
    }
    return a;
  }

  /// Etiquetas de un nodo (efectos y mecánicas).
  BuildAffinity nodeAffinity(PassiveNode n) {
    final a = BuildAffinity();
    for (final k in n.effects.keys) {
      final tag = switch (k) {
        'burn' => 's:burn',
        'poi' => 's:poison',
        'frz' => 's:freeze',
        'atk' || 'mag' || 'crit' || 'hp' || 'def' || 'spd' || 'heal' || 'mp' =>
          k,
        _ => null,
      };
      if (tag != null) a.add(tag, 1, n.name);
    }
    for (final id in n.mechanicIds) {
      final m = kMechanics[id];
      if (m != null) _mechanic(a, m, 1.5, n.name);
    }
    return a;
  }

  /// Nodos tomados + planificados.
  BuildAffinity treeAffinity(BuildPlan plan, PlayerProfile p) {
    final a = BuildAffinity();
    final start = _tree.startNodeByClass[p.classId];
    for (final id in {...p.passiveProgress.takenNodeIds, ...plan.treeNodes}) {
      if (id == start) continue;
      final n = _tree.nodes[id];
      if (n != null) a.addAll(nodeAffinity(n));
    }
    return a;
  }

  /// Puntaje de [n] contra [a] y la etiqueta que más aporta.
  (double, String?) _match(PassiveNode n, BuildAffinity a) {
    var score = 0.0;
    String? best;
    var bestV = 0.0;
    nodeAffinity(n).weights.forEach((tag, w) {
      final v = w * a[tag];
      score += v;
      if (v > bestV) {
        bestV = v;
        best = tag;
      }
    });
    return (score, best);
  }

  // ------------------------------------------------------------------
  // Orden del árbol (§ 9.2)
  // ------------------------------------------------------------------

  /// BFS desde [taken] (con exclusiones): anterior de cada nodo.
  Map<String, String?> _bfs(Set<String> taken) {
    bool blocked(String id) {
      final ex = _tree.exclusions[id];
      return ex != null && taken.contains(ex);
    }

    final prev = <String, String?>{for (final t in taken) t: null};
    var frontier = [
      for (final t in taken)
        if (_tree.nodes.containsKey(t)) t
    ];
    while (frontier.isNotEmpty) {
      final next = <String>[];
      for (final id in frontier) {
        for (final l in _tree.nodes[id]!.links) {
          if (prev.containsKey(l) || blocked(l)) continue;
          if (!_tree.nodes.containsKey(l)) continue;
          prev[l] = id;
          next.add(l);
        }
      }
      frontier = next;
    }
    return prev;
  }

  static List<String>? _path(
      Map<String, String?> prev, Set<String> taken, String to) {
    if (!prev.containsKey(to)) return null;
    final out = <String>[];
    String? at = to;
    while (at != null && !taken.contains(at)) {
      out.add(at);
      at = prev[at];
    }
    return out.reversed.toList();
  }

  bool _excluded(String id, Set<String> taken) {
    final ex = _tree.exclusions[id];
    return ex != null && taken.contains(ex);
  }

  TreeOrder treeOrder(BuildPlan plan, PlayerProfile p) {
    final start = _tree.startNodeByClass[p.classId];
    final taken = <String>{
      if (start != null) start,
      ...p.passiveProgress.takenNodeIds,
    };
    final remaining = <String>[
      for (final id in plan.treeNodes)
        if (_tree.nodes.containsKey(id) && !taken.contains(id)) id
    ];
    if (remaining.isEmpty && plan.timeline.isEmpty) return TreeOrder.empty;
    final aff = affinityOf(plan, p);
    final goalW = _t.d('goalWeight');
    final steps = <TreeOrderStep>[];
    final inPlan = plan.treeNodes.toSet();

    String affReason(PassiveNode n, String? tag) {
      if (tag == null) return 'Del plan';
      final src = aff.sources[tag];
      return src == null
          ? 'Suma ${tagLabel(tag)}'
          : 'Encaja con $src (${tagLabel(tag)})';
    }

    void push(String id, String reason, {int alt = 1}) {
      taken.add(id);
      remaining.remove(id);
      steps.add(TreeOrderStep(
          node: id,
          step: steps.length + 1,
          reason: reason,
          alternatives: alt,
          onPlan: inPlan.contains(id)));
    }

    // 1. Línea de tiempo de la plantilla.
    final tl = [...plan.timeline]..sort((a, b) => a.level.compareTo(b.level));
    for (final s in tl) {
      if (taken.contains(s.node) || !_tree.nodes.containsKey(s.node)) continue;
      final route = _path(_bfs(taken), taken, s.node);
      if (route == null) continue;
      for (final id in route) {
        final n = _tree.nodes[id]!;
        final (score, tag) = _match(n, aff);
        push(id,
            score > 0 && tag != null
                ? affReason(n, tag)
                : 'Plantilla: nivel ${s.level}');
      }
    }

    // 2. Goloso sobre lo que queda.
    final order = {for (final (i, id) in plan.treeNodes.indexed) id: i};
    var guard = 0;
    while (remaining.isNotEmpty && guard++ < 500) {
      remaining.removeWhere((id) => _excluded(id, taken));
      if (remaining.isEmpty) break;
      final prev = _bfs(taken);
      final cands = [
        for (final id in remaining)
          if (_tree.nodes[id]!.links.any(taken.contains)) id
      ];
      if (cands.isEmpty) {
        // 3. Nada pegado: conectar con el más cercano.
        List<String>? best;
        String? goal;
        for (final id in remaining) {
          final r = _path(prev, taken, id);
          if (r == null || r.isEmpty) continue;
          if (best == null || r.length < best.length) {
            best = r;
            goal = id;
          }
        }
        if (best == null) break;
        push(best.first, 'Conecta con ${_tree.nodes[goal]!.name}');
        continue;
      }
      // Caminos a las metas grandes que faltan.
      final goals = <(String, List<String>, double)>[];
      for (final id in remaining) {
        final n = _tree.nodes[id]!;
        if (n.kind != 'n' && n.kind != 'k') continue;
        final r = _path(prev, taken, id);
        if (r == null || r.isEmpty) continue;
        goals.add((id, r, _match(n, aff).$1));
      }
      String? pick;
      var pickScore = double.negativeInfinity;
      var pickReason = 'Del plan';
      for (final c in cands) {
        final n = _tree.nodes[c]!;
        final (own, tag) = _match(n, aff);
        var s = own;
        String? goalName;
        var goalBest = 0.0;
        for (final (gid, route, gAff) in goals) {
          if (!route.contains(c)) continue;
          final g = (goalW + gAff * 0.5) / route.length;
          s += g;
          if (g > goalBest) {
            goalBest = g;
            goalName = gid;
          }
        }
        final better = s > pickScore + 1e-9 ||
            ((s - pickScore).abs() <= 1e-9 &&
                (order[c] ?? 0) < (order[pick] ?? 0));
        if (!better) continue;
        pick = c;
        pickScore = s;
        if (own > 0 && tag != null && own >= goalBest) {
          pickReason = affReason(n, tag);
        } else if (goalName != null && goalName != c) {
          final g = _tree.nodes[goalName]!;
          pickReason =
              'Camino a ${g.kind == 'k' ? 'Keystone' : 'Notable'} ${g.name}';
        } else if (own > 0 && tag != null) {
          pickReason = affReason(n, tag);
        } else {
          pickReason = 'Del plan';
        }
      }
      push(pick!, pickReason, alt: cands.length);
    }
    return TreeOrder(steps);
  }

  // ------------------------------------------------------------------
  // Armas (§ 9.3)
  // ------------------------------------------------------------------

  /// Los atributos de mayor valor (los 2 más altos).
  static List<Attribute> _topAttrs(PlayerAttributes a) {
    final l = [...Attribute.values]..sort((x, y) => a[y].compareTo(a[x]));
    return l.take(2).toList();
  }

  static PowerFormula _dmgFormula(WeaponDef w) =>
      isCaster(w) ? (w.mag ?? w.atk) : w.atk;

  List<WeaponPick> _rank(BuildPlan plan, PlayerProfile p,
      List<(WeaponDef, ItemInstance?)> list) {
    if (list.isEmpty) return const [];
    final t = _t;
    final treeAff = treeAffinity(plan, p);
    final treeTotal = treeAff.total;
    final top = _topAttrs(p.attributes);
    final eqUid = p.equippedUid;
    double power(WeaponDef w) => _dmgFormula(w).evaluate(p.attributes);
    final maxPow =
        list.map((e) => power(e.$1)).fold(0.0, (a, b) => a > b ? a : b);
    final out = <WeaponPick>[];
    for (final (w, it) in list) {
      final reasons = <String>[];
      var score = 0.0;
      // Plan.
      final fit = _plans.itemFit(
          plan, it ?? ItemInstance.common('_guide', w.id, itemLevel: w.level));
      if (fit.any) {
        score += t.d('fitWeight') * fit.matches.length;
        reasons.add('Del plan: ${fit.matches.first}');
      }
      // Atributos.
      final f = _dmgFormula(w);
      if (f.coefficients.isNotEmpty) {
        final main = f.coefficients.entries
            .reduce((a, b) => b.value > a.value ? b : a)
            .key;
        final short = BuildPlanRules.attributeShort(main);
        if (plan.attributes.containsKey(main)) {
          score += t.d('attrWeight');
          reasons.add('Usa $short, la de tu plan');
        } else if (top.contains(main) && p.attributes[main] > 0) {
          score += t.d('attrWeight');
          reasons.add('Usa $short, que tenés alta (${p.attributes[main]})');
        }
      }
      // Árbol.
      if (treeTotal > 0) {
        final wa = weaponAffinity(w, it);
        var ov = 0.0;
        String? best;
        var bestV = 0.0;
        wa.weights.forEach((tag, v) {
          final x = v * treeAff[tag];
          ov += x;
          if (x > bestV) {
            bestV = x;
            best = tag;
          }
        });
        final norm = (ov / (treeTotal * 2)).clamp(0.0, 1.0);
        score += t.d('treeWeight') * norm;
        if (best != null && norm >= 0.05) {
          final src = wa.sources[best] ?? w.name;
          const prefixed = ['pasiva ', 'elemento ', 'mod ', 'ULT '];
          final what = src == w.name
              ? 'Su daño'
              : prefixed.any(src.startsWith)
                  ? 'Su $src'
                  : 'Su habilidad $src';
          reasons.add('$what encaja con tu árbol (${tagLabel(best!)})');
        }
      }
      // Poder.
      if (maxPow > 0) score += t.d('powerWeight') * power(w) / maxPow;
      // Requisitos.
      final meets = progression.meetsRequirements(p, w);
      if (!meets) {
        score *= t.d('reqPenalty');
        reasons.add(_missing(p, w));
      } else {
        reasons.add('Requisitos cumplidos');
      }
      out.add(WeaponPick(
          base: w,
          item: it,
          score: score,
          reasons: reasons.take(3).toList(),
          meets: meets,
          equipped: it != null && it.uid == eqUid));
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      final l = b.base.level.compareTo(a.base.level);
      if (l != 0) return l;
      return a.id.compareTo(b.id);
    });
    // Recomendadas: las primeras con puntaje; si alguna se puede usar,
    // solo las que cumplen requisitos.
    final anyMeets = out.any((w) => w.meets);
    var left = t.i('recommendTop');
    final ranked = <WeaponPick>[];
    for (final w in out) {
      if (left > 0 && w.score > 0 && (w.meets || !anyMeets)) {
        left--;
        ranked.add(w._recommend());
      } else {
        ranked.add(w);
      }
    }
    return ranked;
  }

  String _missing(PlayerProfile p, WeaponDef w) {
    if (p.level < w.level) return 'Nivel ${w.level}';
    final parts = <String>[
      for (final e in w.requirements.entries)
        if (p.attributes[e.key] < e.value)
          '${e.value - p.attributes[e.key]} ${BuildPlanRules.attributeShort(e.key)}'
    ];
    return 'Te faltan ${parts.join(', ')}';
  }

  /// Ranking de las armas que ya tenés (y del alijo, si se pasa).
  List<WeaponPick> rankItems(BuildPlan plan, PlayerProfile p,
      {List<ItemInstance> stash = const []}) {
    final list = <(WeaponDef, ItemInstance?)>[];
    for (final it in [...p.items, ...stash]) {
      final w = progression.catalog.weapons[it.baseId];
      if (w != null) list.add((w, it));
    }
    return _rank(plan, p, list);
  }

  /// Ranking de bases a la venta (armería).
  List<WeaponPick> rankBases(
          BuildPlan plan, PlayerProfile p, Iterable<WeaponDef> bases) =>
      _rank(plan, p, [for (final w in bases) (w, null)]);
}
