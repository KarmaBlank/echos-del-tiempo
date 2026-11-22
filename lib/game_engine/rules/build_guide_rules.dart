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
import 'craft_rules.dart';
import 'item_rules.dart';
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

/// Mejora proyectada de un arma tuya en la forja (§ 9.4).
class ForgeProjection {
  const ForgeProjection({
    required this.pick,
    required this.levels,
    required this.credits,
    required this.value,
    required this.gain,
  });

  final WeaponPick pick;

  /// Niveles de POT que se proyectan (hasta el tope de su rareza).
  final int levels;

  /// Créditos que cuestan esos niveles.
  final int credits;

  /// Valor proyectado y cuánto le gana al de "mejor que tenés".
  final double value;
  final double gain;
}

/// Consejo de arma para tu plan (build_planner.md § 9.4).
class WeaponAdvice {
  const WeaponAdvice({
    required this.idealTypes,
    required this.idealAttribute,
    required this.idealReason,
    this.best,
    this.bestValue = 0,
    this.upgrade,
    this.buy,
    this.buyGain = 0,
    this.chosenType,
    this.allTypes = const [],
    this.howTo = const [],
  });

  /// Tipo que eligió el jugador (`null` = el ideal); con tipo elegido las
  /// 3 líneas de armas se filtran a ese tipo.
  final String? chosenType;

  /// Todos los tipos de arma (cualquier clase usa cualquiera).
  final List<String> allTypes;

  /// "Cómo armarlo" para el tipo vigente (§ 9.5).
  final List<String> howTo;

  /// El tipo que manda: el elegido o el primero ideal.
  String get activeType =>
      chosenType ?? (idealTypes.isEmpty ? '' : idealTypes.first);

  /// Tipo(s) de arma ideal(es) y su atributo principal.
  final List<String> idealTypes;
  final Attribute? idealAttribute;
  final String idealReason;

  /// La mejor arma que ya tenés (inventario o alijo).
  final WeaponPick? best;
  final double bestValue;

  /// La que más rinde si la forjás (solo si le gana a [best]).
  final ForgeProjection? upgrade;

  /// La mejor base de la armería (solo si le gana a [best]).
  final WeaponPick? buy;
  final double buyGain;
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
    a.addAll(_planAffinity(plan, skipBase: w.id));
    return a;
  }

  /// Lo que pide el plan sin el arma equipada.
  BuildAffinity _planAffinity(BuildPlan plan, {String? skipBase}) {
    final a = BuildAffinity();
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
      if (pw != null && pw.id != skipBase) a.addAll(weaponAffinity(pw), 0.5);
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

  // ------------------------------------------------------------------
  // Consejo de arma (§ 9.4)
  // ------------------------------------------------------------------

  /// Atributo principal de la fórmula de daño de [w].
  static Attribute? mainAttribute(WeaponDef w) {
    final f = _dmgFormula(w);
    if (f.coefficients.isEmpty) return null;
    return f.coefficients.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
  }

  /// Bases de la armería para [p]: las de su familia con precio.
  /// Con [type], las de ese tipo de cualquier familia (cualquier clase
  /// usa cualquier tipo).
  List<WeaponDef> shopStock(PlayerProfile p, {String? type}) => [
        for (final w in progression.catalog.weapons.values)
          if (w.price > 0 &&
              (type == null ? w.classId == p.classId : w.type == type))
            w
      ];

  /// Valor de un arma tuya: su puntaje + lo forjado en POT (× forgeWeight).
  double _value(WeaponPick w, [int extraPow = 0]) {
    final pow = (w.item?.forge.pow ?? 0) + extraPow;
    return w.score + _t.d('forgeWeight') * WeaponUpgradeLevels.powPer * pow;
  }

  /// Niveles de POT que le quedan por forjar a [it] (tope de rareza y
  /// nivel, y tope por estadística) y lo que cuestan en créditos.
  static (int, int) forgeRoom(WeaponDef w, ItemInstance it) {
    final byCap = ItemRules.forgeCapOf(it) - it.forgeLevel;
    final byStat = WeaponUpgradeLevels.upMax - it.forge.pow;
    final n = byCap < byStat ? byCap : byStat;
    if (n <= 0) return (0, 0);
    var cost = 0;
    for (var l = it.forge.pow; l < it.forge.pow + n; l++) {
      cost += CraftRules.forgeCost(w, it.rarity, l);
    }
    return (n, cost);
  }

  (List<String>, Attribute?, String) _ideal(BuildPlan plan, PlayerProfile p) {
    Attribute? planAttr;
    if (plan.attributes.isNotEmpty) {
      planAttr = plan.attributes.entries
          .reduce((a, b) => b.value > a.value ||
                  (b.value == a.value && b.key.index < a.key.index)
              ? b
              : a)
          .key;
    }
    String note(Attribute? a) =>
        a == null ? '' : ' · usa ${BuildPlanRules.attributeShort(a)}';
    for (final b in plan.weaponBases) {
      final w = progression.catalog.weapons[b];
      if (w == null) continue;
      final a = planAttr ?? mainAttribute(w);
      return ([w.type], a, 'Base de tu plan: ${w.name}${note(a)}');
    }
    if (plan.weaponTypes.isNotEmpty) {
      WeaponDef? w;
      for (final x in progression.catalog.weapons.values) {
        if (x.type != plan.weaponTypes.first) continue;
        if (w == null || x.level < w.level) w = x;
      }
      final a = planAttr ?? (w == null ? null : mainAttribute(w));
      return ([...plan.weaponTypes], a, 'Tipo de tu plan${note(a)}');
    }
    final want = _planAffinity(plan)..addAll(treeAffinity(plan, p));
    final eq = progression.equippedWeapon(p);
    if (want.isEmpty) {
      final a = planAttr ?? mainAttribute(eq);
      return ([eq.type], a, 'Sin plan: el tipo que usás${note(a)}');
    }
    final types =
        progression.catalog.classes[p.classId]?.allowedWeaponTypes ?? const [];
    // Por tipo: la base que más se parece a lo que pide el plan.
    final byType = <String, (double, String?, WeaponDef)>{};
    for (final w in progression.catalog.weapons.values) {
      final ok = types.isNotEmpty
          ? types.contains(w.type)
          : w.classId == p.classId;
      if (!ok) continue;
      var ov = 0.0;
      String? best;
      var bestV = 0.0;
      weaponAffinity(w).weights.forEach((tag, v) {
        final x = v * want[tag];
        ov += x;
        if (x > bestV) {
          bestV = x;
          best = tag;
        }
      });
      final cur = byType[w.type];
      if (cur == null || ov > cur.$1 + 1e-9) byType[w.type] = (ov, best, w);
    }
    if (byType.isEmpty) {
      final a = planAttr ?? mainAttribute(eq);
      return ([eq.type], a, 'El tipo que usás${note(a)}');
    }
    final sorted = byType.entries.toList()
      ..sort((a, b) {
        final c = b.value.$1.compareTo(a.value.$1);
        if ((a.value.$1 - b.value.$1).abs() > 1e-9 && c != 0) return c;
        if (a.key == eq.type) return -1;
        if (b.key == eq.type) return 1;
        return a.key.compareTo(b.key);
      });
    final top = sorted.first;
    final eps = _t.d('typeTie');
    final ideal = [
      for (final e in sorted)
        if (top.value.$1 - e.value.$1 <= eps) e.key
    ].take(2).toList();
    final a = planAttr ?? mainAttribute(top.value.$3);
    final tag = top.value.$2;
    final src = tag == null ? null : want.sources[tag];
    final why = tag == null
        ? 'Encaja con tu plan'
        : src == null
            ? 'Tu plan pide ${tagLabel(tag)}'
            : 'Tu plan pide ${tagLabel(tag)} ($src)';
    return (ideal, a, '$why${note(a)}');
  }

  /// Consejo de arma (§ 9.4): tipo ideal, la mejor que tenés, la que más
  /// rinde si la forjás y la mejor de la armería. [shop] por defecto es
  /// [shopStock]; con una lista vacía no mira la armería.
  WeaponAdvice advice(BuildPlan plan, PlayerProfile p,
      {List<ItemInstance> stash = const [], Iterable<WeaponDef>? shop}) {
    final t = _t;
    final (types, attr, why) = _ideal(plan, p);
    final all = allWeaponTypes();
    final chosen = all.contains(plan.chosenType) ? plan.chosenType : null;
    bool ofType(WeaponDef w) => chosen == null || w.type == chosen;
    final mine = [...p.items, ...stash];
    final ownedBases = {for (final it in mine) it.baseId};
    final ranked = _rank(plan, p, [
      for (final it in mine)
        if (progression.catalog.weapons[it.baseId] case final w?)
          if (ofType(w)) (w, it),
      for (final w in shop ?? shopStock(p, type: chosen))
        if (!ownedBases.contains(w.id) && ofType(w)) (w, null),
    ]);
    final owned = [for (final w in ranked) if (w.item != null) w];
    final bases = [for (final w in ranked) if (w.item == null) w];

    // Mejor que tenés: la de mayor valor (con requisitos si alguna los
    // cumple); empate: la equipada, después el uid.
    WeaponPick? best;
    var bestValue = 0.0;
    final pool = owned.any((w) => w.meets)
        ? [for (final w in owned) if (w.meets) w]
        : owned;
    for (final w in pool) {
      final v = _value(w);
      final better = best == null ||
          v > bestValue + 1e-9 ||
          ((v - bestValue).abs() <= 1e-9 &&
              (w.equipped && !best.equipped ||
                  (w.equipped == best.equipped && w.id.compareTo(best.id) < 0)));
      if (better) {
        best = w;
        bestValue = v;
      }
    }

    // Mejor para mejorar: forjada en POT hasta su tope; tiene que ganarle
    // a la mejor por upgradeMinGain. Empate: la más barata, después uid.
    ForgeProjection? up;
    final minUp = t.d('upgradeMinGain');
    for (final w in owned) {
      if (!w.meets) continue;
      final (n, cost) = forgeRoom(w.base, w.item!);
      if (n <= 0) continue;
      final v = _value(w, n);
      final gain = v - bestValue;
      if (gain < minUp - 1e-9) continue;
      final better = up == null ||
          v > up.value + 1e-9 ||
          ((v - up.value).abs() <= 1e-9 &&
              (cost < up.credits ||
                  (cost == up.credits && w.id.compareTo(up.pick.id) < 0)));
      if (better) {
        up = ForgeProjection(
            pick: w, levels: n, credits: cost, value: v, gain: gain);
      }
    }

    // Para comprar: la primera base (ya ordenadas) que cumple requisitos
    // y le gana a la mejor por buyMinGain.
    WeaponPick? buy;
    var buyGain = 0.0;
    final minBuy = t.d('buyMinGain');
    for (final w in bases) {
      if (!w.meets) continue;
      final gain = w.score - bestValue;
      if (gain < minBuy - 1e-9) continue;
      buy = w;
      buyGain = gain;
      break;
    }
    return WeaponAdvice(
        idealTypes: types,
        idealAttribute: attr,
        idealReason: why,
        best: best,
        bestValue: bestValue,
        upgrade: up,
        buy: buy,
        buyGain: buyGain,
        chosenType: chosen,
        allTypes: all,
        howTo: howTo(plan, p, chosen ?? (types.isEmpty ? '' : types.first)));
  }

  /// Todos los tipos de arma del catálogo, en orden alfabético.
  List<String> allWeaponTypes() =>
      {for (final w in progression.catalog.weapons.values) w.type}.toList()
        ..sort();

  List<WeaponDef> _basesOf(String type) => [
        for (final w in progression.catalog.weapons.values)
          if (w.type == type) w
      ];

  /// Afinidad típica de un tipo de arma: la suma de sus bases.
  BuildAffinity typeAffinity(String type) {
    final a = BuildAffinity();
    for (final w in _basesOf(type)) {
      a.addAll(weaponAffinity(w));
    }
    return a;
  }

  /// Etiquetas que "pegan": daño, crítico, estados y disparadores. Las
  /// defensivas (vida, defensa, curas, velocidad, MP) sirven con cualquier
  /// arma y no cuentan como choque.
  static bool _offensive(String tag) =>
      tag == 'atk' ||
      tag == 'mag' ||
      tag == 'crit' ||
      tag.startsWith('s:') ||
      tag.startsWith('t:');

  /// "Cómo armarlo" (§ 9.5) para [type]: atributos a subir, nodos del
  /// plan que encajan y los que no, y habilidades típicas del tipo.
  List<String> howTo(BuildPlan plan, PlayerProfile p, String type) {
    final bases = _basesOf(type);
    if (bases.isEmpty) return const [];
    final out = <String>[];
    // Atributos: suma de coeficientes de la fórmula de daño.
    final coef = <Attribute, double>{};
    for (final w in bases) {
      _dmgFormula(w).coefficients.forEach((k, v) => coef[k] = (coef[k] ?? 0) + v);
    }
    final attrs = coef.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.index.compareTo(b.key.index);
      });
    if (attrs.isNotEmpty) {
      final names = [
        for (final e in attrs.take(2)) BuildPlanRules.attributeShort(e.key)
      ];
      out.add('Subí ${names.join(' y ')}');
    }
    // Árbol: nodos del plan (y tomados) contra el tipo.
    final ta = typeAffinity(type);
    final start = _tree.startNodeByClass[p.classId];
    final good = <(double, String)>[];
    final bad = <String>[];
    for (final id in {...plan.treeNodes, ...p.passiveProgress.takenNodeIds}) {
      if (id == start) continue;
      final n = _tree.nodes[id];
      if (n == null) continue;
      final na = nodeAffinity(n);
      var ov = 0.0;
      var hasOff = false;
      na.weights.forEach((tag, w) {
        ov += w * ta[tag];
        if (_offensive(tag)) hasOff = true;
      });
      if (ov > 0) {
        good.add((ov, n.name));
      } else if (hasOff && (n.kind == 'n' || n.kind == 'k')) {
        bad.add(n.name);
      }
    }
    good.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    bad.sort();
    final cap = _t.i('howToNames');
    if (good.isNotEmpty) {
      out.add('Te sirven del árbol: '
          '${good.take(cap).map((g) => g.$2).join(', ')}');
    }
    if (bad.isNotEmpty) {
      out.add('No rinden con ${type.toUpperCase()}: '
          '${bad.take(cap).join(', ')}');
    }
    // Habilidades típicas: las que más se repiten entre sus bases.
    final count = <String, int>{};
    for (final w in bases) {
      for (final id in w.skillIds) {
        count[id] = (count[id] ?? 0) + 1;
      }
    }
    final skills = count.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    final names = [
      for (final e in skills)
        if (progression.catalog.skills[e.key] case final s?) s.name
    ].take(cap).toList();
    if (names.isNotEmpty) out.add('Suele traer: ${names.join(', ')}');
    return out;
  }

  // ------------------------------------------------------------------
  // Marcas de traslado (build_planner.md § 9.6)
  // ------------------------------------------------------------------

  /// Afinidad del plan para las marcas: lo que pide (habilidades, pasiva,
  /// base), el árbol (tomado + plan) y el tipo elegido (`chosenType`). No
  /// mira el arma equipada: la marca dice si va con el plan.
  BuildAffinity buildAffinity(BuildPlan plan, PlayerProfile p) {
    final a = BuildAffinity()
      ..addAll(_planAffinity(plan))
      ..addAll(treeAffinity(plan, p));
    if (plan.chosenType case final t? when allWeaponTypes().contains(t)) {
      a.addAll(typeAffinity(t), 0.5);
    }
    return a;
  }

  /// Marca de una habilidad a trasladar; `null` sin plan.
  BuildFit? skillFit(BuildPlan plan, PlayerProfile p, String skillId) {
    if (plan.goalCount == 0) return null;
    final s = progression.catalog.skills[skillId];
    if (s == null) return null;
    if (plan.skills.contains(skillId)) {
      return const BuildFit(true, 'Tu plan la pide');
    }
    final own = BuildAffinity();
    _skill(own, s, 1, s.name);
    return _fit(own, buildAffinity(plan, p));
  }

  /// Marca de una pasiva de arma a trasladar; `null` sin plan.
  BuildFit? passiveFit(BuildPlan plan, PlayerProfile p, String passiveId) {
    if (plan.goalCount == 0) return null;
    final def = kWeaponPassives[passiveId];
    if (def == null) return null;
    if (plan.weaponPassive == passiveId) {
      return const BuildFit(true, 'Tu plan pide esta pasiva');
    }
    final own = BuildAffinity();
    for (final m in def.mechanicsAt(1)) {
      _mechanic(own, m, 1, def.name);
    }
    return _fit(own, buildAffinity(plan, p));
  }

  /// Va si comparte alguna etiqueta con el plan (la de más peso da el
  /// motivo). Sin etiquetas propias o sin plan con etiquetas: no marca.
  BuildFit? _fit(BuildAffinity own, BuildAffinity plan) {
    if (own.isEmpty || plan.isEmpty) return null;
    String? best;
    var bestV = 0.0;
    own.weights.forEach((tag, w) {
      final v = w * plan[tag];
      if (v > bestV + 1e-9 || (v > 0 && (v - bestV).abs() <= 1e-9 &&
          best != null && tag.compareTo(best!) < 0)) {
        bestV = v;
        best = tag;
      }
    });
    if (best case final tag?) {
      final from = plan.sources[tag];
      return BuildFit(true,
          'Suma ${tagLabel(tag)}${from == null ? '' : ' (como $from)'}');
    }
    final main = own.weights.entries.reduce((a, b) => b.value > a.value ? b : a);
    return BuildFit(false,
        'Tu plan no usa ${tagLabel(main.key)}');
  }
}

/// Marca "para tu build" / "no va con tu build" (build_planner.md § 9.6).
class BuildFit {
  const BuildFit(this.fits, this.reason);

  final bool fits;

  /// Una línea para el tooltip.
  final String reason;
}
