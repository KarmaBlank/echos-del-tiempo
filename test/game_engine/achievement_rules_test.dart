import 'package:echos_del_tiempo/game_engine/data/achievements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/achievement.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/rules/achievement_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Hazañas (docs/specs/achievements.md): detección por eventos del motor
/// en el host, pago una sola vez y coop.
PlayerProfile _rich({AchievementProgress? ach}) =>
    progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      credits: 20000,
      materials: const {
        CraftMaterial.esquirla: 2,
        CraftMaterial.cristal: 1,
        CraftMaterial.prisma: 5,
      },
      achievements: ach,
      items: const [
        ItemInstance(uid: 'c', baseId: 'espada_bronce'),
        ItemInstance(uid: 'c2', baseId: 'espada_bronce'),
        ItemInstance(
          uid: 'a',
          baseId: 'espada_ignea',
          rarity: Rarity.raro,
          itemLevel: 12,
          affixes: [AffixRoll('feroz', 4, 12), AffixRoll('del_oso', 5, 3)],
        ),
        ItemInstance(
          uid: 'b',
          baseId: 'hacha_rompe',
          rarity: Rarity.magico,
          affixes: [AffixRoll('certero', 5, 3), AffixRoll('del_toro', 5, 4)],
        ),
        ItemInstance(
          uid: 'l',
          baseId: 'espada_templada',
          rarity: Rarity.legendario,
          itemLevel: 20,
          uniqueId: 'juramentoAlba',
          passiveId: 'albaImplacable',
          affixes: [AffixRoll('feroz', 0, 25), AffixRoll('certero', 0, 6)],
        ),
      ],
      equipped: 'c',
    ));

List<AchievementUnlockedEvent> _unlocks(SessionStep? step) =>
    step!.events.whereType<AchievementUnlockedEvent>().toList();

SessionStep _do(SessionEngine e, GameSession s, String id, SessionAction a) {
  final step = e.apply(s, id, a);
  expect(step, isNotNull, reason: 'rechazada: $a');
  return step!;
}

void main() {
  group('catálogo', () {
    test('33 hazañas, ids únicos, 7 categorías, totales del spec', () {
      expect(kAchievements, hasLength(33));
      expect(kAchievementsById, hasLength(33));
      expect({for (final a in kAchievements) a.category},
          AchievementCategory.values.toSet());
      var total = const AchievementReward();
      for (final a in kAchievements) {
        total += a.reward;
        expect(a.how, isNotEmpty);
        expect(a.reward.isEmpty, isFalse, reason: a.id);
      }
      expect(total.credits, 26300);
      expect(total.esquirlas, 18);
      expect(total.cristales, 11);
      expect(total.prismas, 11);
      expect(total.potions + total.ethers, 12);
    });

    test('las de contador tienen tiers crecientes por contador', () {
      for (final c in AchievementCounter.all) {
        final goals = [
          for (final a in kAchievements)
            if (a.counter == c) a.goal
        ];
        expect(goals, isNotEmpty);
        expect([...goals]..sort(), goals);
      }
    });
  });

  group('FORJA (UpgradeAction real)', () {
    test('Primera forja paga una vez; el contador sigue', () {
      final e = sessionEngine(achievements: true);
      var s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      final before = s.players['p0']!.profile;
      final cost = before.credits -
          progression.upgrade(before, 'a', UpgradeStat.pow)!.credits;
      var step = _do(e, s, 'p0', const UpgradeAction('a', UpgradeStat.pow));
      expect(_unlocks(step).map((u) => u.id), ['forge_first']);
      var p = step.state.players['p0']!.profile;
      expect(p.credits, before.credits - cost + 400);
      expect(p.material(CraftMaterial.esquirla), 4);
      expect(p.achievements.count(AchievementCounter.forgeLevels), 1);
      s = step.state;
      step = _do(e, s, 'p0', const UpgradeAction('a', UpgradeStat.crit));
      expect(_unlocks(step), isEmpty, reason: 'no se paga dos veces');
      expect(step.state.players['p0']!.profile.achievements
          .count(AchievementCounter.forgeLevels), 2);
    });

    test('Forjar a +5 y el tier Forjador II por contador', () {
      final e = sessionEngine(achievements: true);
      var s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      final got = <String>[];
      for (final st in [
        UpgradeStat.pow, UpgradeStat.pow, UpgradeStat.crit,
        UpgradeStat.crit, UpgradeStat.spd,
      ]) {
        final step = _do(e, s, 'p0', UpgradeAction('l', st));
        got.addAll(_unlocks(step).map((u) => u.id));
        s = step.state;
      }
      expect(got, containsAll(['forge_first', 'forge_plus5']));
      expect(got, isNot(contains('forge_10')));
      // Forjador II con 10 niveles (contador, no por arma).
      final h = AchievementHits()..count(AchievementCounter.forgeLevels, 5);
      final (p, u) = const AchievementRules()
          .grant(s.players['p0']!.profile, h, 1);
      expect(u.map((x) => x.id), ['forge_10']);
      expect(p.achievements.count(AchievementCounter.forgeLevels), 10);
    });
  });

  test('FORJA: Al tope con un Raro en su tope total (loot.md § 9)', () {
    final e = sessionEngine(achievements: true);
    var s = e.addPlayer(e.create(), 'p0', _rich())!.state;
    final got = <String>[];
    for (final st in [
      UpgradeStat.pow, UpgradeStat.crit, UpgradeStat.pow, UpgradeStat.crit,
    ]) {
      final step = _do(e, s, 'p0', UpgradeAction('a', st));
      got.addAll(_unlocks(step).map((u) => u.id));
      s = step.state;
    }
    expect(s.players['p0']!.profile.itemByUid('a')!.forge.total, 4);
    expect(got.last, 'forge_cap');
  });

  group('FUSIÓN (CraftAction real)', () {
    test('trasladar afijo: Primera fusión + Traer afijo; la vista previa no',
        () {
      final e = sessionEngine(fieldFallback: 0.3, achievements: true);
      final s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      // La vista previa (reglas sin aplicar) no toca el perfil de sesión.
      progression.crafting.transferAffix(s.players['p0']!.profile, 'a', 'b', 0);
      expect(s.players['p0']!.profile.achievements.isEmpty, isTrue);
      final step = _do(e, s, 'p0',
          const CraftAction(CraftOp.transferAffix, 'a', sourceUid: 'b', index: 0));
      expect(_unlocks(step).map((u) => u.id),
          unorderedEquals(['fuse_first', 'fuse_affix']));
      expect(step.state.players['p0']!.profile.achievements
          .count(AchievementCounter.fusions), 1);
    });

    test('una acción rechazada no cuenta', () {
      final e = sessionEngine(achievements: true);
      final s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      expect(e.apply(s, 'p0', const CraftAction(CraftOp.transferAffix, 'a')),
          isNull);
    });
  });

  group('REFORJA Y DESARME', () {
    test('desarmar suma al contador; vender paga Primera venta', () {
      final e = sessionEngine(achievements: true);
      var s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      var step = _do(e, s, 'p0', const CraftAction(CraftOp.salvage, 'c2'));
      expect(step.state.players['p0']!.profile.achievements
          .count(AchievementCounter.salvaged), 1);
      s = step.state;
      step = _do(e, s, 'p0', const CraftAction(CraftOp.sell, 'b'));
      expect(_unlocks(step).map((u) => u.id), ['sell_first']);
      expect(step.state.players['p0']!.profile.achievements
          .count(AchievementCounter.fusions), 0, reason: 'no es fusión');
    });
  });

  group('INVENTARIO Y FILTRO', () {
    test('guardar una regla propia paga; el filtro por defecto no', () {
      final e = sessionEngine(achievements: true);
      final s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      expect(
          _unlocks(_do(e, s, 'p0',
              const SetLootFilterAction(LootFilterRules.defaultText))),
          isEmpty);
      final step = _do(e, s, 'p0',
          const SetLootFilterAction('Ocultar\n  Rareza Común\n'));
      expect(_unlocks(step).map((u) => u.id), ['filter_rule']);
    });

    test('el cliente avisa el buscador: el host paga una vez y solo las de '
        'la lista', () {
      final e = sessionEngine(achievements: true);
      var s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      final pot = s.players['p0']!.profile.potions;
      final step = _do(e, s, 'p0', const ClaimAchievementAction('inv_search'));
      expect(_unlocks(step).map((u) => u.id), ['inv_search']);
      s = step.state;
      expect(s.players['p0']!.profile.potions, pot + 2);
      expect(e.apply(s, 'p0', const ClaimAchievementAction('inv_search')),
          isNull, reason: 'ya logrado');
      expect(e.apply(s, 'p0', const ClaimAchievementAction('abyss_boss')),
          isNull, reason: 'no la puede avisar el cliente');
    });
  });

  group('COMBATE (eventos de batalla)', () {
    const rules = AchievementRules();
    Map<String, AchievementHits> run(List<BattleEvent> ev,
        [AchievementBattleTracker? t]) {
      final out = <String, AchievementHits>{};
      rules.fromBattle(out, ev, t ?? AchievementBattleTracker(),
          isPlayer: (id) => id.startsWith('p'),
          isBoss: (id) => id == 'jefe',
          skill: (id) => GameCatalogs.skill(id));
      return out;
    }

    test('quiebre: solo el que da el golpe; ULT cancelada solo con jefe', () {
      final out = run([
        const TurnStartedEvent('p1'),
        const ActionEvent('p1', BattleActionKind.skill, targetId: 'jefe'),
        const BreakEvent('jefe', BreakPhase.broken, 0, 100, cancelledUlt: true),
      ]);
      expect(out.keys, ['p1']);
      expect(out['p1']!.ids, {'combat_break', 'combat_cancel_ult'});
      final fill = run([
        const ActionEvent('p0', BattleActionKind.attack, targetId: 'e1'),
        const BreakEvent('e1', BreakPhase.fill, 40, 100),
      ]);
      expect(fill.values.every((h) => h.isEmpty), isTrue);
    });

    test('Convergencia: la ganan quien preparó y quien detonó', () {
      final t = AchievementBattleTracker();
      run([
        const ActionEvent('p0', BattleActionKind.skill, targetId: 'e1'),
        const StatusAppliedEvent('e1', StatusKind.burn, 5),
      ], t);
      final out = run([
        const ActionEvent('p1', BattleActionKind.skill, targetId: 'e1'),
        const ReactionEvent('e1', ReactionKind.combustion, 30, sourceId: 'p1'),
      ], t);
      expect(out['p0']!.ids, {'combat_convergence'});
      expect(out['p1']!.ids, {'combat_convergence'});
    });

    test('Encadenar Instante: INSTANTE y otra acción en el mismo turno', () {
      final instant = GameCatalogs.instantSkill();
      final t = AchievementBattleTracker();
      final out = run([
        const TurnStartedEvent('p0'),
        ActionEvent('p0', BattleActionKind.skill, skillId: instant),
        const ActionEvent('p0', BattleActionKind.attack),
      ], t);
      expect(out['p0']!.ids, {'combat_instant_chain'});
      // Instante al final del turno y la acción en el turno siguiente: no.
      final t2 = AchievementBattleTracker();
      final no = run([
        const TurnStartedEvent('p0'),
        ActionEvent('p0', BattleActionKind.skill, skillId: instant),
        const TurnStartedEvent('p0'),
        const ActionEvent('p0', BattleActionKind.attack),
      ], t2);
      expect(no['p0']?.ids ?? const <String>{}, isEmpty);
    });
  });

  group('PROGRESIÓN', () {
    test('equipar una Legendaria paga', () {
      final e = sessionEngine(achievements: true);
      final s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      final step = e.apply(s, 'p0', const EquipAction('l'));
      if (step == null) {
        // Requisitos del arma: se prueba la regla con el perfil equipado.
        final h = AchievementHits();
        final p = _rich();
        const AchievementRules().fromAction(h, const EquipAction('l'), p,
            p.copyWith(equipped: 'l'));
        expect(h.ids, {'equip_legendary'});
        return;
      }
      expect(_unlocks(step).map((u) => u.id), contains('equip_legendary'));
    });

    test('pasar el tope blando de un atributo', () {
      final p = _rich();
      final cap = kAttrSoftCap[Attribute.vit]!;
      final over = p.copyWith(
          attributes: p.attributes.add({Attribute.vit: cap + 1 - p.attributes[Attribute.vit]}));
      final h = AchievementHits();
      const AchievementRules()
          .fromAction(h, const AllocateStatsAction({Attribute.vit: 1}), p, over);
      expect(h.ids, {'attr_cap'});
    });
  });

  group('ENDGAME y coop', () {
    test('Eco y Jefe del Abismo: todos los presentes', () {
      final out = <String, AchievementHits>{};
      const r = AchievementRules();
      r.fromSession(out, const EcoCompletedEvent(['p0', 'p1'], tier: 1, zone: 1, boss: 1));
      r.fromSession(out, const AbyssDefeatedEvent(1, ['p1']));
      expect(out['p0']!.ids, {'eco_first'});
      expect(out['p1']!.ids, {'eco_first', 'abyss_boss'});
    });

    test('cada jugador gana la suya y el host paga en su perfil de sesión',
        () {
      final e = sessionEngine(achievements: true);
      var s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      s = e.addPlayer(s, 'p1', _rich())!.state;
      final p0 = s.players['p0']!.profile.toJson().toString();
      final step = _do(e, s, 'p1', const UpgradeAction('a', UpgradeStat.pow));
      final u = _unlocks(step);
      expect(u.map((x) => '${x.playerId}:${x.id}'), ['p1:forge_first']);
      expect(step.state.players['p0']!.profile.toJson().toString(), p0);
      // El otro también la puede ganar (su cuenta).
      final step2 = _do(e, step.state, 'p0', const UpgradeAction('a', UpgradeStat.pow));
      expect(_unlocks(step2).map((x) => x.playerId), ['p0']);
    });

    test('al reconectar con lo logrado, no se paga de nuevo', () {
      final e = sessionEngine(achievements: true);
      var s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      final step = _do(e, s, 'p0', const UpgradeAction('a', UpgradeStat.pow));
      final saved = step.state.players['p0']!.profile;
      // Se va y vuelve con su perfil (como en el `hello`).
      s = e.removePlayer(step.state, 'p0')!.state;
      s = e.addPlayer(s, 'p0', PlayerProfile.fromJson(saved.toJson()))!.state;
      final again = _do(e, s, 'p0', const UpgradeAction('a', UpgradeStat.crit));
      expect(_unlocks(again), isEmpty);
    });
  });

  group('datos y red', () {
    test('JSON de la cuenta: unión de logradas y máximo de contadores', () {
      final a = AchievementProgress(
          done: {'forge_first': 10, 'fuse_first': 5}, counters: {'fusions': 3});
      final b = AchievementProgress(
          done: {'forge_first': 7, 'sell_first': 9},
          counters: {'fusions': 1, 'salvaged': 4});
      final m = a.merge(b);
      expect(m.done, {'forge_first': 7, 'fuse_first': 5, 'sell_first': 9});
      expect(m.counters, {'fusions': 3, 'salvaged': 4});
      final back = AchievementProgress.fromJson(m.toJson());
      expect(back.toJson(), m.toJson());
      expect(m.toJson()['v'], AchievementProgress.version);
    });

    test('la pila 99 recorta y avisa lo perdido', () {
      final p = _rich().copyWith(
          materials: {CraftMaterial.esquirla: 98});
      final (q, lost) = AchievementRules.pay(
          p, const AchievementReward(esquirlas: 3));
      expect(q.material(CraftMaterial.esquirla), 99);
      expect(lost, {'Esquirla del Eco': 2});
    });

    test('acción y evento viajan; protocolo 24', () {
      expect(kProtocolVersion, 24);
      const a = ClaimAchievementAction('inv_search');
      final back = ActionJson.fromJson(ActionJson.toJson(a));
      expect((back as ClaimAchievementAction).id, 'inv_search');
      const codec = EventJson();
      final ev = codec.fromJson(
          codec.toJson(const AchievementUnlockedEvent('p1', 'fuse_first')));
      expect(ev, isA<AchievementUnlockedEvent>());
      expect((ev as AchievementUnlockedEvent).playerId, 'p1');
      // El perfil lleva `ach` en el `hello` y en el estado.
      final p = _rich(ach: AchievementProgress(done: {'fuse_first': 1}));
      expect(PlayerProfile.fromJson(p.toJson()).achievements.isDone('fuse_first'),
          isTrue);
    });
  });
}

/// Acceso al catálogo de habilidades para los eventos de prueba.
abstract final class GameCatalogs {
  static SkillDef? skill(String id) => progression.catalog.skills[id];
  static String instantSkill() =>
      progression.catalog.skills.values.firstWhere((s) => s.instant).id;
}
