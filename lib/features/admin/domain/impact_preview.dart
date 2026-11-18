import 'dart:math' as math;

import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/data/game_catalog.dart';
import '../../../game_engine/data/passive_tree_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/passive_tree.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/battle_engine.dart';
import '../../../game_engine/rules/mulberry32.dart';
import '../../../game_engine/rules/passive_tree_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../game_engine/rules/stats_calculator.dart';
import '../../../game_engine/rules/zone_rules.dart';

/// Daño de un uso contra un muñeco (docs/specs/balance_admin.md § 5).
class HitPreview {
  const HitPreview({required this.normal, required this.crit, this.mp = 0});

  /// Sin crítico ni efectos con probabilidad.
  final int normal;

  /// Con crítico y todos los efectos con probabilidad.
  final int crit;
  final int mp;
}

/// Resultado de N batallas simuladas.
class BattleSimResult {
  const BattleSimResult({
    required this.runs,
    required this.wins,
    required this.avgActions,
    required this.avgHpLeft,
    required this.avgDamagePerAction,
  });

  final int runs;
  final int wins;

  /// Acciones propias hasta ganar (TTK), promedio de las victorias.
  final double avgActions;

  /// Vida que queda al ganar (fracción), promedio de las victorias.
  final double avgHpLeft;

  /// Daño directo hecho por acción propia.
  final double avgDamagePerAction;

  double get winRate => runs == 0 ? 0 : wins / runs;
}

/// Qué usa el personaje típico en la simulación.
class SimLoadout {
  const SimLoadout({
    required this.classId,
    required this.level,
    required this.weaponId,
    this.skillId,
    this.fusedSkillId,
    this.takenNodes = const [],
  });

  final String classId;
  final int level;
  final String weaponId;

  /// Habilidad que usa cuando le alcanza el MP (`null` = solo ataca).
  final String? skillId;

  /// Habilidad agregada por fusión (variantes y kits sin arma).
  final String? fusedSkillId;

  /// Nodos del árbol tomados (vista previa de nodos y mecánicas).
  final List<String> takenNodes;
}

/// Vista previa de impacto con el motor real (Dart puro). Usa el
/// [catalog] que le pasen (código + parche) y los registros globales tal
/// como estén instalados: quien llama instala el parche antes.
class ImpactSimulator {
  ImpactSimulator(this.catalog)
      : stats = StatsCalculator(
            classes: catalog.classes,
            treeRules: PassiveTreeRules(kPassiveTree));

  final GameCatalog catalog;
  final StatsCalculator stats;

  /// Atributos típicos: base de la clase + `(nivel−1)·3` puntos, ⅔ al
  /// atributo principal del arma y ⅓ a VIT (§ 5).
  PlayerAttributes typicalAttributes(String classId, int level, WeaponDef w) {
    final cls = catalog.classes[classId]!;
    final points = (level - 1) * ProgressionRules.pointsPerLevel;
    final formula = w.mag ?? w.atk;
    var main = Attribute.fue;
    var best = -1.0;
    formula.coefficients.forEach((a, c) {
      if (c > best) {
        best = c;
        main = a;
      }
    });
    final toMain = (points * 2) ~/ 3;
    return PlayerAttributes.base(cls.baseAttributes)
        .add({main: toMain})
        .add({Attribute.vit: points - toMain});
  }

  PlayerBuild typicalBuild(SimLoadout l) {
    final w = catalog.weapons[l.weaponId]!;
    return PlayerBuild(
      classId: l.classId,
      level: l.level,
      attributes: typicalAttributes(l.classId, l.level, w),
      equippedWeapon: w,
      passiveProgress: PlayerPassiveProgress(l.takenNodes),
    );
  }

  DerivedStats statSheet(SimLoadout l) => stats.calculate(typicalBuild(l));

  BattlePartyMember _member(SimLoadout l, {double ult = 0}) =>
      BattlePartyMember(
        id: 'p1',
        name: catalog.classes[l.classId]!.name,
        build: typicalBuild(l),
        ult: ult,
        fusedSkillId: l.fusedSkillId,
      );

  /// El arma "natural" de una habilidad: la primera base que la otorga.
  String? weaponFor(String skillId) {
    for (final w in catalog.weapons.values) {
      if (w.skillIds.contains(skillId)) return w.id;
    }
    return null;
  }

  /// El primer arma de un tipo (ULT por tipo de arma).
  String? weaponOfType(String type) {
    for (final w in catalog.weapons.values) {
      if (w.type == type) return w.id;
    }
    return null;
  }

  /// La clase dueña de una habilidad de kit de ascensión, si es de una.
  String? ascensionClassOf(String skillId) {
    for (final a in kAscensions.values) {
      if (a.skillIds.contains(skillId)) return a.classId;
    }
    return null;
  }

  /// Daño de un uso de [skillId] (o ataque básico si es `null`, o la ULT
  /// del arma si [ultimate]) contra [enemyId] con vida infinita.
  HitPreview? hit(SimLoadout l,
      {required String enemyId, String? skillId, bool ultimate = false}) {
    int? once(double roll) {
      final engine = BattleEngine(
          stats: stats, catalog: catalog, random: () => roll);
      final s = engine
          .start(
              party: [_member(l, ult: ultimate ? 100 : 0)],
              enemyTypes: [enemyId],
              triggeredBy: 'p1')
          .state;
      for (final e in s.enemies) {
        e
          ..hp = 1 << 30
          ..maxHp = 1 << 30
          ..nextTurn = 1e9;
      }
      var cur = s;
      for (var i = 0; i < 6 && cur.currentId != 'p1'; i++) {
        cur = engine.nextTurn(cur).state;
      }
      if (cur.currentId != 'p1') return null;
      final BattleCommand cmd = ultimate
          ? const UltimateCommand(targetId: 'e0')
          : skillId == null
              ? const AttackCommand(targetId: 'e0')
              : SkillCommand(skillId, targetId: 'e0');
      final step = engine.command(cur, 'p1', cmd);
      if (step == null) return null;
      return step.events
          .whereType<DamageEvent>()
          .where((e) => e.targetId.startsWith('e') && !e.fromStatus)
          .fold<int>(0, (n, e) => n + e.amount);
    }

    final normal = once(0.99);
    final crit = once(0.0);
    if (normal == null || crit == null) return null;
    return HitPreview(
        normal: normal,
        crit: crit,
        mp: skillId == null ? 0 : catalog.skills[skillId]?.mp ?? 0);
  }

  /// [runs] batallas de un personaje típico contra [enemies] escalados a
  /// [enemyLevel] (semillas fijas: el mismo resultado cada vez).
  BattleSimResult simulate(SimLoadout l,
      {required List<String> enemies,
      required int enemyLevel,
      int runs = 40,
      int seed = 1,
      bool elite = false}) {
    var wins = 0;
    var actionsSum = 0;
    var hpSum = 0.0;
    var dmgSum = 0;
    var actionsAll = 0;
    for (var r = 0; r < runs; r++) {
      final engine = BattleEngine(
          stats: stats,
          catalog: catalog,
          random: mulberry32(seed * 7919 + r * 104729));
      var s = engine
          .start(party: [_member(l)], enemyTypes: enemies, elite: elite)
          .state;
      ZoneRules.scaleBattle(s, enemyLevel);
      var actions = 0;
      for (var i = 0; i < 3000 && !s.ended; i++) {
        final cur = s.current;
        if (cur != null && cur.isPlayer && !cur.alive) s.currentId = null;
        BattleStep? step;
        if (s.currentId == null) {
          step = engine.nextTurn(s);
        } else if (!s.current!.isPlayer) {
          step = engine.enemyTurn(s);
        } else {
          final p = s.current!;
          final sk = l.skillId == null ? null : catalog.skills[l.skillId];
          final target = s.enemies.where((e) => e.alive).firstOrNull?.id;
          step = (p.ult >= 100
                  ? engine.command(s, 'p1', UltimateCommand(targetId: target))
                  : null) ??
              (sk != null && p.mp >= sk.mp
                  ? engine.command(s, 'p1', SkillCommand(sk.id, targetId: target))
                  : null) ??
              engine.command(s, 'p1', AttackCommand(targetId: target)) ??
              engine.timeout(s);
          actions++;
          if (step != null) {
            dmgSum += step.events
                .whereType<DamageEvent>()
                .where((e) => e.targetId.startsWith('e'))
                .fold<int>(0, (n, e) => n + e.amount);
          }
        }
        if (step == null) break;
        s = step.state;
      }
      actionsAll += actions;
      if (s.outcome?.victory ?? false) {
        wins++;
        actionsSum += actions;
        final p = s.party.first;
        hpSum += p.maxHp == 0 ? 0 : math.max(0, p.hp) / p.maxHp;
      }
    }
    return BattleSimResult(
      runs: runs,
      wins: wins,
      avgActions: wins == 0 ? 0 : actionsSum / wins,
      avgHpLeft: wins == 0 ? 0 : hpSum / wins,
      avgDamagePerAction: actionsAll == 0 ? 0 : dmgSum / actionsAll,
    );
  }
}
