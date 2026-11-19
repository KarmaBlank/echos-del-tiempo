import 'dart:math' as math;

import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/data/elements_catalog.dart' show elementOf;
import '../../../game_engine/data/game_catalog.dart';
import '../../../game_engine/data/passive_tree_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/elements.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/passive_tree.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
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
    this.avgBestHit = 0,
    this.avgBreaks = 0,
    this.bossEarlyBreaks = 0,
    this.bossRuns = 0,
    this.avgFoeHpLeftOnLoss = 0,
    this.avgActionsOnLoss = 0,
  });

  /// En las derrotas: vida que le quedaba al bando enemigo (fracción de su
  /// vida máxima total) y acciones propias hasta caer (promedios).
  final double avgFoeHpLeftOnLoss, avgActionsOnLoss;

  /// Quiebres por batalla (combo_balance.md § 5), promedio.
  final double avgBreaks;

  /// Batallas en las que un jefe se quebró antes de su primera ULT, sobre
  /// [bossRuns] (batallas con jefe con ULT).
  final int bossEarlyBreaks;
  final int bossRuns;

  /// Fracción de batallas con jefe quebrado antes de su primera ULT.
  double get bossEarlyBreakRate =>
      bossRuns == 0 ? 0 : bossEarlyBreaks / bossRuns;

  final int runs;
  final int wins;

  /// Acciones propias hasta ganar (TTK), promedio de las victorias.
  final double avgActions;

  /// Vida que queda al ganar (fracción), promedio de las victorias.
  final double avgHpLeft;

  /// Daño directo hecho por acción propia.
  final double avgDamagePerAction;

  /// Golpe directo más grande de cada batalla, como fracción de la vida
  /// máxima del blanco (promedio). Sirve para ver el tope por golpe.
  final double avgBestHit;

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
    this.item,
    this.potions = 0,
  });

  /// Pociones de vida con las que entra (el perfil nuevo trae 3).
  final int potions;

  final String classId;
  final int level;
  final String weaponId;

  /// Habilidad que usa cuando le alcanza el MP (`null` = solo ataca).
  final String? skillId;

  /// Habilidad agregada por fusión (variantes y kits sin arma).
  final String? fusedSkillId;

  /// Nodos del árbol tomados (vista previa de nodos y mecánicas).
  final List<String> takenNodes;

  /// Arma concreta (afijos, forja, legendaria). Si está, su base manda
  /// sobre [weaponId] (combo_balance.md § 7: medir con loot).
  final ItemInstance? item;
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
    final w = catalog.weapons[l.item?.baseId ?? l.weaponId]!;
    return PlayerBuild(
      classId: l.classId,
      level: l.level,
      attributes: typicalAttributes(l.classId, l.level, w),
      equippedWeapon: w,
      passiveProgress: PlayerPassiveProgress(l.takenNodes),
      item: l.item,
    );
  }

  DerivedStats statSheet(SimLoadout l) => stats.calculate(typicalBuild(l));

  BattlePartyMember _member(SimLoadout l,
          {double ult = 0, String id = 'p1'}) =>
      BattlePartyMember(
        id: id,
        name: catalog.classes[l.classId]!.name,
        build: typicalBuild(l),
        ult: ult,
        potions: l.potions,
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
  /// [enemyLevel] (semillas fijas: el mismo resultado cada vez). Con
  /// [party], un grupo de esos personajes (uno por jugador) en vez de
  /// [partySize] copias de [l].
  ///
  /// IA simple: con menos de [potionAt] de vida y pociones, toma una; si
  /// hay un enemigo Fisurado, lo quiebra (ULT cargada o la habilidad con
  /// Quebrar de su kit); si un enemigo avisó su ULT y tiene menos de
  /// [defendBelow] de vida, se defiende (una vez por aviso); si no,
  /// ULT si está cargada, si no su habilidad si alcanza el MP, si no
  /// ataque; al primer enemigo vivo (combo_balance.md § 7, paso 5).
  BattleSimResult simulate(SimLoadout l,
      {required List<String> enemies,
      required int enemyLevel,
      int runs = 40,
      int seed = 1,
      bool elite = false,
      int partySize = 1,
      List<SimLoadout>? party,
      double potionAt = 0.4,
      double defendBelow = 0.5,
      bool combos = false}) {
    final loadouts = party == null || party.isEmpty
        ? [for (var k = 0; k < partySize.clamp(1, 4); k++) l]
        : party.take(4).toList();
    var wins = 0;
    var actionsSum = 0;
    var hpSum = 0.0;
    var dmgSum = 0;
    var actionsAll = 0;
    var bestSum = 0.0;
    var breaks = 0;
    var bossRuns = 0;
    var bossEarly = 0;
    var foeLeftSum = 0.0;
    var lossActions = 0;
    for (var r = 0; r < runs; r++) {
      final engine = BattleEngine(
          stats: stats,
          catalog: catalog,
          random: mulberry32(seed * 7919 + r * 104729));
      var s = engine
          .start(party: [
            for (var k = 0; k < loadouts.length; k++)
              _member(loadouts[k], id: 'p${k + 1}'),
          ], enemyTypes: enemies, elite: elite)
          .state;
      ZoneRules.scaleBattle(s, enemyLevel, curve: catalog.curve);
      // Jefes con ULT: si se quiebran antes de lanzarla (combo_balance.md
      // § 5, meta < 10% con un grupo al azar).
      final bossIds = {
        for (final e in s.enemies)
          if (e.boss && e.ultId != null) e.id,
      };
      final ulted = <String>{};
      var early = false;
      var actions = 0;
      var best = 0.0;
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
          final k = int.tryParse(p.id.substring(1)) ?? 1;
          final lo = loadouts[(k - 1).clamp(0, loadouts.length - 1)];
          final sk = lo.skillId == null ? null : catalog.skills[lo.skillId];
          final alive = s.enemies.where((e) => e.alive);
          final fissured = alive.where((e) => e.fissured).firstOrNull;
          final target = (fissured ?? alive.firstOrNull)?.id;
          SkillDef? quebrar;
          if (fissured != null) {
            for (final id in p.skillIds) {
              final q = catalog.skills[id];
              if (q != null && q.breaks && p.mp >= q.mp) {
                quebrar = q;
                break;
              }
            }
          }
          final warned = alive.any((e) => e.ultPending);
          final hpFrac = p.maxHp > 0 ? p.hp / p.maxHp : 1.0;
          final low = hpFrac < potionAt;
          // Con [combos]: detona una Convergencia si el objetivo tiene 5+
          // stacks de su preparación; si no, prepara (Quemadura / Veneno).
          SkillDef? combo;
          if (combos && fissured == null) {
            final t = alive.firstOrNull;
            SkillDef? prep;
            for (final id in p.skillIds) {
              final q = catalog.skills[id];
              if (q == null || p.mp < q.mp || t == null) continue;
              final el = elementOf(id);
              for (final st in const [StatusKind.burn, StatusKind.poison]) {
                final rk = reactionOf(st, el);
                if (rk != null && rk.convergence && t.stacks(st) >= 5) {
                  combo = q;
                }
              }
              final applies = [if (q.status != null) q.status!, ...q.extraStatuses]
                  .any((a) => a.kind == StatusKind.burn || a.kind == StatusKind.poison);
              if (applies) prep ??= q;
            }
            combo ??= prep;
          }
          step = (low && p.potions > 0
                  ? engine.command(
                      s, p.id, ItemCommand(BattleItem.potion, targetPlayerId: p.id))
                  : null) ??
              (fissured != null && (p.ult >= 100 || quebrar != null)
                  ? null
                  : warned && !p.defending && hpFrac < defendBelow
                      ? engine.command(s, p.id, const DefendCommand())
                      : null) ??
              (combo != null
                  ? engine.command(s, p.id, SkillCommand(combo.id, targetId: target))
                  : null) ??
              (p.ult >= 100
                  ? engine.command(s, p.id, UltimateCommand(targetId: target))
                  : null) ??
              (quebrar != null
                  ? engine.command(
                      s, p.id, SkillCommand(quebrar.id, targetId: target))
                  : null) ??
              (sk != null && p.mp >= sk.mp
                  ? engine.command(s, p.id, SkillCommand(sk.id, targetId: target))
                  : null) ??
              engine.command(s, p.id, AttackCommand(targetId: target)) ??
              engine.timeout(s);
          actions++;
          if (step != null) {
            dmgSum += step.events
                .whereType<DamageEvent>()
                .where((e) => e.targetId.startsWith('e'))
                .fold<int>(0, (n, e) => n + e.amount);
            for (final ev in step.events.whereType<DamageEvent>()) {
              final t = step.state.enemies
                  .where((e) => e.id == ev.targetId)
                  .firstOrNull;
              if (t != null && t.maxHp > 0 && !ev.fromStatus) {
                best = math.max(best, ev.amount / t.maxHp);
              }
            }
          }
        }
        if (step == null) break;
        for (final ev in step.events) {
          if (ev is EnemyUltEvent) ulted.add(ev.actorId);
          if (ev is BreakEvent && ev.phase == BreakPhase.broken) {
            breaks++;
            if (bossIds.contains(ev.targetId) && !ulted.contains(ev.targetId)) {
              early = true;
            }
          }
        }
        s = step.state;
      }
      if (bossIds.isNotEmpty) {
        bossRuns++;
        if (early) bossEarly++;
      }
      actionsAll += actions;
      bestSum += best;
      if (s.outcome?.victory ?? false) {
        wins++;
        actionsSum += actions;
        final p = s.party.first;
        hpSum += p.maxHp == 0 ? 0 : math.max(0, p.hp) / p.maxHp;
      } else {
        lossActions += actions;
        final max = s.enemies.fold<int>(0, (n, e) => n + e.maxHp);
        final left = s.enemies.fold<int>(0, (n, e) => n + math.max(0, e.hp));
        foeLeftSum += max == 0 ? 0 : left / max;
      }
    }
    return BattleSimResult(
      runs: runs,
      wins: wins,
      avgActions: wins == 0 ? 0 : actionsSum / wins,
      avgHpLeft: wins == 0 ? 0 : hpSum / wins,
      avgDamagePerAction: actionsAll == 0 ? 0 : dmgSum / actionsAll,
      avgBestHit: runs == 0 ? 0 : bestSum / runs,
      avgBreaks: runs == 0 ? 0 : breaks / runs,
      bossEarlyBreaks: bossEarly,
      bossRuns: bossRuns,
      avgFoeHpLeftOnLoss: wins == runs ? 0 : foeLeftSum / (runs - wins),
      avgActionsOnLoss: wins == runs ? 0 : lossActions / (runs - wins),
    );
  }
}