import 'dart:math' as math;

import '../data/passive_mechanics.dart';
import '../data/weapons_catalog.dart';
import '../models/attributes.dart';
import '../models/build_plan.dart';
import '../models/passive_mechanic.dart';
import '../models/passive_tree.dart';
import '../models/player_profile.dart';
import '../models/player_state.dart';
import '../models/weapon.dart';
import 'progression_rules.dart';

/// Por qué el asesor pone puntos en un atributo, de más a menos urgente
/// (docs/specs/build_planner.md § 8).
enum AttrSuggestionKind {
  /// Requisito sin cumplir de un arma del plan que ya podés usar.
  requirement,

  /// Piso de supervivencia: vida baja para tu nivel.
  survival,

  /// Lo que más rinde con tu arma y tu árbol.
  scaling,
}

/// Una línea de la sugerencia: [points] puntos a [attribute] y por qué.
class AttrSuggestion {
  const AttrSuggestion({
    required this.attribute,
    required this.points,
    required this.kind,
    required this.reasons,
    this.score = 0,
  });

  final Attribute attribute;
  final int points;

  /// La razón más urgente que lo puso acá.
  final AttrSuggestionKind kind;

  /// Textos para el jugador, el más importante primero.
  final List<String> reasons;

  /// Valor relativo por punto (solo informativo, para ordenar).
  final double score;

  String get short => attribute.name.toUpperCase();

  @override
  String toString() => '$short +$points (${reasons.join('; ')})';
}

/// Stats que mira el asesor (lo que cada atributo mueve en
/// `StatsCalculator`).
enum AdviceStat {
  atk('ATQ'),
  mag('MAG'),
  hp('HP'),
  mp('MP'),
  crit('crítico'),
  spd('VEL');

  const AdviceStat(this.label);
  final String label;
}

/// Recomendación de atributos (docs/specs/build_planner.md § 8): mira el
/// arma equipada y las del plan, los nodos del árbol tomados y
/// planificados y la vida para tu nivel, y reparte los puntos libres.
/// Puro y determinista: mismo perfil y plan, misma sugerencia.
class AttributeAdvisor {
  const AttributeAdvisor(this.progression);

  final ProgressionRules progression;

  /// Peso base de cada stat (antes del árbol). El stat de daño del arma
  /// equipada vale 1.
  static const baseNeed = {
    AdviceStat.hp: 0.15,
    AdviceStat.mp: 0.10,
    AdviceStat.crit: 0.30,
    AdviceStat.spd: 0.15,
  };

  /// Peso del arma del plan que todavía no tenés equipada.
  static const plannedWeaponWeight = 0.6;

  /// Un arma del plan cuenta como requisito duro si su nivel es como
  /// mucho el tuyo + esto.
  static const requirementLevelSlack = 3;

  /// Un atributo entra al reparto si vale al menos esto del mejor.
  static const shareThreshold = 0.4;
  static const maxScaling = 3;

  /// Puntos de prueba para medir cuánto mueve un atributo (con los
  /// redondeos de `StatsCalculator`, 1 punto puede dar 0).
  static const _probe = 10;

  /// Vida mínima esperable a nivel [level] (§ 8.3).
  static int survivalHp(int level) => 30 + 4 * level;

  /// Puntos que el BUILD proyecta: los libres + los de los próximos
  /// [levels] niveles (sin pasar del máximo).
  static int horizonPoints(PlayerProfile p, {int levels = 5}) =>
      p.points +
      ProgressionRules.pointsPerLevel *
          math.max(0, math.min(levels, ProgressionRules.maxLevel - p.level));

  /// La sugerencia para los puntos libres de [p] (o [points], para
  /// proyectar). Vacía si no hay puntos.
  List<AttrSuggestion> recommend(PlayerProfile p,
      [BuildPlan? plan, int? points]) {
    final total = points ?? p.points;
    if (total <= 0) return const [];
    plan ??= BuildPlan.empty;
    final alloc = <Attribute, int>{};
    final reasons = <Attribute, List<String>>{};
    final kinds = <Attribute, AttrSuggestionKind>{};
    var left = total;

    void give(Attribute a, int n, AttrSuggestionKind kind, String why) {
      if (n <= 0) return;
      alloc[a] = (alloc[a] ?? 0) + n;
      (reasons[a] ??= []).add(why);
      final k = kinds[a];
      if (k == null || kind.index < k.index) kinds[a] = kind;
      left -= n;
    }

    // 1. Requisitos de las armas del plan.
    for (final w in _plannedBases(plan)) {
      if (left <= 0) break;
      if (w.level > p.level + requirementLevelSlack) continue;
      for (final e in w.requirements.entries) {
        if (left <= 0) break;
        final have = p.attributes[e.key] + (alloc[e.key] ?? 0);
        final gap = e.value - have;
        if (gap <= 0) continue;
        final n = math.min(gap, left);
        final short = e.key.name.toUpperCase();
        give(
            e.key,
            n,
            AttrSuggestionKind.requirement,
            'Te falta${gap == 1 ? '' : 'n'} $gap $short para equipar ${w.name}'
            '${w.level > p.level ? ' (nivel ${w.level})' : ''}'
            '${n < gap ? ' (después quedan ${gap - n})' : ''}');
      }
    }

    // 2. Piso de supervivencia.
    if (left > 0) {
      final now = progression.previewAllocation(p, alloc);
      final floor = survivalHp(p.level);
      if (now.maxHp < floor) {
        final perPoint = _delta(p, alloc, Attribute.vit).maxHp;
        if (perPoint > 0) {
          final need = ((floor - now.maxHp) / perPoint).ceil();
          final cap = math.max(1, total ~/ 2);
          final n = math.min(left, math.min(need, cap));
          give(
              Attribute.vit,
              n,
              AttrSuggestionKind.survival,
              'Tu vida (${now.maxHp}) está baja para nivel ${p.level} '
              '(mínimo sugerido $floor): +${_fmt(perPoint)} HP por punto');
        }
      }
    }

    // 3. Lo que más rinde.
    final scores = this.scores(p, plan, alloc);
    if (left > 0) {
      final ranked = [...Attribute.values]
        ..sort((a, b) {
          final c = scores[b]!.total.compareTo(scores[a]!.total);
          return c != 0 ? c : a.index.compareTo(b.index);
        });
      final top = scores[ranked.first]!.total;
      final pick = [
        for (final a in ranked)
          if (top > 0 && scores[a]!.total >= top * shareThreshold) a,
      ].take(maxScaling).toList();
      final sum = pick.fold<double>(0, (s, a) => s + scores[a]!.total);
      final share = <Attribute, int>{};
      final rest = <Attribute, double>{};
      var given = 0;
      for (final a in pick) {
        final exact = left * scores[a]!.total / sum;
        share[a] = exact.floor();
        rest[a] = exact - exact.floor();
        given += exact.floor();
      }
      // Resto mayor primero; empate: el de más valor (orden de `pick`).
      final byRest = [...pick]..sort((a, b) {
          final c = rest[b]!.compareTo(rest[a]!);
          return c != 0 ? c : pick.indexOf(a).compareTo(pick.indexOf(b));
        });
      for (var i = 0; given < left; i++, given++) {
        final a = byRest[i % byRest.length];
        share[a] = share[a]! + 1;
      }
      final n = left;
      for (final a in pick) {
        final s = share[a]!;
        if (s <= 0) continue;
        alloc[a] = (alloc[a] ?? 0) + s;
        (reasons[a] ??= []).addAll(scores[a]!.reasons);
        kinds[a] ??= AttrSuggestionKind.scaling;
      }
      left -= n;
    }

    final out = [
      for (final a in Attribute.values)
        if ((alloc[a] ?? 0) > 0)
          AttrSuggestion(
            attribute: a,
            points: alloc[a]!,
            kind: kinds[a]!,
            reasons: List.unmodifiable(reasons[a]!),
            score: scores[a]!.total,
          ),
    ]..sort((x, y) {
        var c = x.kind.index.compareTo(y.kind.index);
        if (c != 0) return c;
        c = y.points.compareTo(x.points);
        if (c != 0) return c;
        c = y.score.compareTo(x.score);
        return c != 0 ? c : x.attribute.index.compareTo(y.attribute.index);
      });
    return List.unmodifiable(out);
  }

  /// El reparto como mapa (para `AllocateStatsAction`).
  static Map<Attribute, int> allocation(List<AttrSuggestion> s) =>
      {for (final x in s) x.attribute: x.points};

  /// "FUE +2, DES +1".
  static String split(List<AttrSuggestion> s) =>
      [for (final x in s) '${x.short} +${x.points}'].join(', ');

  /// Una línea: "FUE +2, DES +1: <la razón principal>".
  static String summary(List<AttrSuggestion> s) {
    if (s.isEmpty) return 'Sin puntos para repartir';
    final why = s.first.reasons.isEmpty ? '' : ': ${s.first.reasons.first}';
    return '${split(s)}$why';
  }

  /// [plan] con metas de atributo para la sugerencia [s] sobre [p]: cada
  /// atributo sugerido queda con objetivo `actual + puntos` (si ya había
  /// uno mayor, se queda el mayor).
  static BuildPlan addAsGoals(
      BuildPlan plan, PlayerProfile p, List<AttrSuggestion> s) {
    if (s.isEmpty) return plan;
    final attrs = Map<Attribute, int>.from(plan.attributes);
    for (final x in s) {
      final t = p.attributes[x.attribute] + x.points;
      attrs[x.attribute] = math.max(attrs[x.attribute] ?? 0, t);
    }
    return plan.copyWith(attributes: Map.unmodifiable(attrs));
  }

  // ------------------------------------------------------------------
  // Puntaje por atributo
  // ------------------------------------------------------------------

  /// Cuánto rinde un punto de cada atributo (suma de lo que sube cada
  /// stat, relativo a su valor actual, por su peso) y por qué.
  Map<Attribute, AttrScore> scores(PlayerProfile p, BuildPlan plan,
      [Map<Attribute, int> alloc = const {}]) {
    final needs = this.needs(p, plan);
    final now = progression.previewAllocation(p, alloc);
    final w = progression.equippedWeapon(p);
    final planned = [
      for (final b in _plannedWeapons(plan, p.level))
        if (b.id != w.id) b,
    ];
    final attrs = p.attributes.add(alloc);
    final out = <Attribute, AttrScore>{};
    for (final a in Attribute.values) {
      final d = _delta(p, alloc, a);
      final short = a.name.toUpperCase();
      final parts = <(double, String)>[];
      void part(AdviceStat s, double gain, double base, String text) {
        final need = needs.weight(s);
        if (gain <= 0 || need <= 0) return;
        final v = need * gain / math.max(1.0, base);
        final src = needs.sources(s);
        parts.add((v, src.isEmpty ? text : '$text; tu árbol: $src'));
      }

      // Daño del arma equipada.
      final atkCoef = w.atk.coefficients[a];
      part(AdviceStat.atk, d.attack, now.attack.toDouble(),
          '+${_fmt(d.attack)} ATQ por punto con tu ${w.name}'
          '${atkCoef == null ? '' : ' (escala $short×${_coef(atkCoef)})'}');
      final magCoef = (w.mag ?? w.atk).coefficients[a];
      part(AdviceStat.mag, d.magic, now.magic.toDouble(),
          '+${_fmt(d.magic)} MAG por punto con tu ${w.name}'
          '${magCoef == null ? '' : ' (escala $short×${_coef(magCoef)})'}');
      part(AdviceStat.hp, d.maxHp, now.maxHp.toDouble(),
          '+${_fmt(d.maxHp)} HP por punto');
      part(AdviceStat.mp, d.maxMp, now.maxMp.toDouble(),
          '+${_fmt(d.maxMp)} MP por punto');
      part(AdviceStat.spd, d.speed, now.speed,
          '+${_fmt(d.speed)} VEL por punto');
      // Crítico como daño esperado: 1 + crit × (multiplicador − 1).
      final extra = now.critMultiplier - 1;
      part(AdviceStat.crit, d.critChance * extra,
          1 + now.critChance * extra,
          '+${_fmt(d.critChance * 100)}% crítico por punto');
      // Armas del plan sin equipar: su fórmula de daño.
      if (planned.isNotEmpty) {
        var sum = 0.0;
        WeaponDef? best;
        var bestRel = 0.0;
        for (final b in planned) {
          final f = _isCaster(b) ? (b.mag ?? b.atk) : b.atk;
          final coef = f.coefficients[a] ?? 0;
          final rel = coef / math.max(1.0, f.evaluate(attrs));
          sum += rel;
          if (rel > bestRel) {
            bestRel = rel;
            best = b;
          }
        }
        if (best != null) {
          final f = _isCaster(best) ? (best.mag ?? best.atk) : best.atk;
          final stat = _isCaster(best) ? 'MAG' : 'ATQ';
          parts.add((
            plannedWeaponWeight * sum / planned.length,
            '${best.name} del plan escala $short×'
                '${_coef(f.coefficients[a]!)} ($stat)'
          ));
        }
      }
      parts.sort((x, y) => y.$1.compareTo(x.$1));
      final total = parts.fold<double>(0, (s, x) => s + x.$1);
      final top = parts.isEmpty ? 0.0 : parts.first.$1;
      out[a] = AttrScore(total, [
        for (final x in parts)
          if (x.$1 >= top * 0.25) x.$2,
      ].take(2).toList());
    }
    return out;
  }

  /// Qué stats usa el build (pesos) y qué nodos lo piden.
  AdviceNeeds needs(PlayerProfile p, BuildPlan plan) {
    final n = AdviceNeeds();
    final w = progression.equippedWeapon(p);
    final caster = _isCaster(w);
    n.add(caster ? AdviceStat.mag : AdviceStat.atk, 1);
    if (!caster && w.mag != null) n.add(AdviceStat.mag, 0.3);
    baseNeed.forEach(n.add);
    if (caster) n.add(AdviceStat.mp, 0.1);

    final nodes = progression.treeRules.catalog.nodes;
    final ids = <String>{...p.tree, ...plan.treeNodes};
    for (final id in ids) {
      final node = nodes[id];
      if (node == null || node.kind == 'st') continue;
      _nodeNeeds(node, n);
    }
    return n;
  }

  static void _nodeNeeds(PassiveNode node, AdviceNeeds n) {
    final name = node.name;
    node.effects.forEach((k, v) {
      final x = v.toDouble();
      switch (k) {
        case 'atk':
          n.add(AdviceStat.atk, x * 5, name);
        case 'mag':
          n.add(AdviceStat.mag, x * 5, name);
        // Las curas de habilidad escalan con MAG.
        case 'heal':
          n.add(AdviceStat.mag, x * 5, name);
        case 'hp':
          n.add(AdviceStat.hp, x * 5, name);
        case 'def':
          n.add(AdviceStat.hp, x * 0.05, name);
        case 'mp':
          n.add(AdviceStat.mp, x * 4, name);
        case 'crit':
          n.add(AdviceStat.crit, x * 8, name);
        case 'spd':
          n.add(AdviceStat.spd, x * 0.6, name);
      }
    });
    final m = node.mechanicId == null ? null : mechanicById(node.mechanicId!);
    if (m == null) return;
    const v = 0.1;
    switch (m.trigger) {
      case ProcTrigger.onCrit:
        n.add(AdviceStat.crit, v, name);
      case ProcTrigger.whileLowHealth ||
            ProcTrigger.whileMissingHealth ||
            ProcTrigger.onHitTaken ||
            ProcTrigger.onProtectHit:
        n.add(AdviceStat.hp, v * 0.8, name);
      default:
    }
    for (final fx in m.effects) {
      switch (fx.kind) {
        case ProcEffectKind.statBonus ||
              ProcEffectKind.buffSelf ||
              ProcEffectKind.buffParty:
          switch (fx.stat) {
            case BuffStat.crit || BuffStat.critMulti:
              n.add(AdviceStat.crit, v, name);
            case BuffStat.attack:
              n.add(AdviceStat.atk, v, name);
            case BuffStat.speed:
              n.add(AdviceStat.spd, v, name);
            case BuffStat.shieldPower || BuffStat.guard ||
                  BuffStat.shieldReflect || BuffStat.lifeSteal:
              n.add(AdviceStat.hp, v * 0.8, name);
            case BuffStat.holyPower:
              n.add(AdviceStat.mag, v, name);
            default:
          }
        // Escudos y curas de mecánica: % de la vida máxima.
        case ProcEffectKind.shieldSelf ||
              ProcEffectKind.shieldParty ||
              ProcEffectKind.shieldLowestAlly ||
              ProcEffectKind.shieldHealed ||
              ProcEffectKind.healSelf ||
              ProcEffectKind.healParty ||
              ProcEffectKind.healLowestAlly ||
              ProcEffectKind.reflect:
          n.add(AdviceStat.hp, v * 0.8, name);
        // Invocaciones y daño sagrado: MAG del dueño.
        case ProcEffectKind.summon || ProcEffectKind.holyDamage:
          n.add(AdviceStat.mag, v, name);
        case ProcEffectKind.advanceTurn ||
              ProcEffectKind.extraTurn ||
              ProcEffectKind.advanceAlly ||
              ProcEffectKind.advanceParty:
          n.add(AdviceStat.spd, v * 0.8, name);
        case ProcEffectKind.refundMp:
          n.add(AdviceStat.mp, v, name);
        default:
      }
    }
  }

  // ------------------------------------------------------------------
  // Auxiliares
  // ------------------------------------------------------------------

  static bool _isCaster(WeaponDef w) =>
      kWeaponTypeCategory[w.type] == WeaponCategory.caster;

  /// Lo que sube por punto de [a] (promedio de [_probe] puntos, a 0.1).
  _Delta _delta(PlayerProfile p, Map<Attribute, int> alloc, Attribute a) {
    final DerivedStats now = progression.previewAllocation(p, alloc);
    final next = progression
        .previewAllocation(p, {...alloc, a: (alloc[a] ?? 0) + _probe});
    double per(num d) => (d / _probe * 10).round() / 10;
    return _Delta(
      attack: per(next.attack - now.attack),
      magic: per(next.magic - now.magic),
      maxHp: per(next.maxHp - now.maxHp),
      maxMp: per(next.maxMp - now.maxMp),
      speed: per(next.speed - now.speed),
      critChance: (next.critChance - now.critChance) / _probe,
    );
  }

  /// Bases del plan, en orden (las desconocidas no cuentan).
  Iterable<WeaponDef> _plannedBases(BuildPlan plan) sync* {
    for (final id in plan.weaponBases) {
      final w = progression.catalog.weapons[id];
      if (w != null) yield w;
    }
  }

  /// Bases del plan + una base representativa por tipo del plan.
  List<WeaponDef> _plannedWeapons(BuildPlan plan, int level) {
    final out = <WeaponDef>[..._plannedBases(plan)];
    for (final t in plan.weaponTypes) {
      if (out.any((w) => w.type == t)) continue;
      final r = representative(t, level);
      if (r != null) out.add(r);
    }
    return out;
  }

  /// La base de tipo [type] más alta a la que llegás pronto (nivel ≤
  /// [level] + 5); si ninguna, la de menor nivel. Sin [level], la más
  /// baja.
  WeaponDef? representative(String type, int? level) {
    final list = [
      for (final w in progression.catalog.weapons.values)
        if (w.type == type) w,
    ]..sort((a, b) {
        final c = a.level.compareTo(b.level);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    if (list.isEmpty) return null;
    if (level == null) return list.first;
    final near = list.where((w) => w.level <= level + 5).toList();
    return near.isEmpty ? list.first : near.last;
  }

  /// Coeficiente de fórmula con hasta 2 decimales ("0.75", "1.2").
  static String _coef(double v) {
    var t = v.toStringAsFixed(2);
    while (t.contains('.') && (t.endsWith('0') || t.endsWith('.'))) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  static String _fmt(num v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.round().toString() : r.toString();
  }
}

/// Lo que sube cada stat por punto de un atributo.
class _Delta {
  const _Delta({
    required this.attack,
    required this.magic,
    required this.maxHp,
    required this.maxMp,
    required this.speed,
    required this.critChance,
  });
  final double attack, magic, maxHp, maxMp, speed, critChance;
}

/// Puntaje de un atributo y sus razones (las dos más fuertes).
class AttrScore {
  const AttrScore(this.total, this.reasons);
  final double total;
  final List<String> reasons;
}

/// Pesos por stat y qué nodos del árbol los suben.
class AdviceNeeds {
  final _w = <AdviceStat, double>{};
  final _src = <AdviceStat, Map<String, double>>{};

  void add(AdviceStat s, double v, [String? source]) {
    _w[s] = (_w[s] ?? 0) + v;
    if (source != null) {
      final m = _src[s] ??= {};
      m[source] = (m[source] ?? 0) + v;
    }
  }

  double weight(AdviceStat s) => _w[s] ?? 0;

  /// "Frenesí, Ojo Certero +2": los dos nodos que más lo piden.
  String sources(AdviceStat s) {
    final m = _src[s];
    if (m == null || m.isEmpty) return '';
    final names = m.keys.toList()
      ..sort((a, b) {
        final c = m[b]!.compareTo(m[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    final shown = names.take(2).join(', ');
    return names.length > 2 ? '$shown +${names.length - 2}' : shown;
  }
}
