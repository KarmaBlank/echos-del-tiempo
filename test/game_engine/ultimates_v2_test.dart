import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/branch_ults_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/ult_def.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/exploration_rules.dart';
import 'package:echos_del_tiempo/game_engine/models/exploration.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/rules/ult_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';
import '../helpers/battle_log_helper.dart';

// ULT v2: docs/specs/ultimates_v2.md.

final _stats =
    StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  return BattleEngine(
      stats: _stats, random: () => i < rolls.length ? rolls[i++] : 0.99);
}

BattlePartyMember _member(String id, String classId,
    {double ult = 0, String? sel, String? weapon, int level = 1}) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: cls.name,
    ult: ult,
    build: PlayerBuild(
      classId: classId,
      level: 10,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[weapon ?? cls.startWeaponId]!,
      ultSel: sel,
      ultLevel: level,
    ),
  );
}

BattleState _turn(BattleEngine e, List<BattlePartyMember> party,
    List<String> enemies, {bool elite = false}) {
  final s = e.start(
      party: party, enemyTypes: enemies, triggeredBy: party.first.id, elite: elite);
  final t = e.nextTurn(s.state).state;
  expect(t.currentId, party.first.id);
  return t;
}

void main() {
  group('catálogo', () {
    test('50 ULT, ids únicos, fuentes del spec y costos 60/80/100', () {
      expect(kUltV2List, hasLength(50));
      expect(kUltV2, hasLength(50));
      final by = <UltSource, int>{};
      for (final u in kUltV2List) {
        by[u.source] = (by[u.source] ?? 0) + 1;
        expect([60, 80, 100], contains(u.cost), reason: u.id);
        expect(u.id, startsWith('ult2_'));
      }
      expect(by, {
        UltSource.weaponMod: 12,
        UltSource.unique: 8,
        UltSource.tree: 8,
        UltSource.feat: 6,
        UltSource.eco: 6,
        UltSource.boss: 10,
      });
    });

    test('20 élites con ULT propia y Furia Élite de respaldo', () {
      final elites = kEnemies.values.where((e) => e.eliteUltId != null);
      expect(elites, hasLength(20));
      for (final e in elites) {
        expect(kEnemyUlts, contains(e.eliteUltId), reason: e.id);
      }
      expect(kEnemyUlts, contains(kEliteUltId));
      // Los del Abismo con nombre propio (§ 4.2).
      final names = kEnemyUlts.values.map((u) => u.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });
  });

  group('motor', () {
    test('toda ULT pide la barra llena y la vacía; sin carga se rechaza', () {
      final e = _engine();
      final t = _turn(e, [_member('p1', 'guerrero', ult: 100, sel: 'ult2_sangreEco')],
          ['golem']);
      expect(ultimateOf(t.party.single)!.id, 'ult2_sangreEco');
      final step = e.command(t, 'p1', const UltimateCommand())!;
      expect(step.state.party.single.ult, 0);
      final low = _turn(e, [_member('p1', 'guerrero', ult: 90, sel: 'ult2_sangreEco')],
          ['golem']);
      expect(e.command(low, 'p1', const UltimateCommand()), isNull);
    });

    test('ULT activa de otra clase cae al orden de siempre; la de otro tipo de arma manda igual (v0.20.9)', () {
      final p = _turn(e(), [_member('p1', 'guerrero', ult: 100, sel: 'ult2_ojoFuturo')],
          ['golem']).party.single;
      expect(ultimateOf(p)!.id, isNot('ult2_ojoFuturo'));
      final q = _turn(e(), [_member('p1', 'guerrero', ult: 100, sel: 'ult2_milAyeres')],
          ['golem']).party.single;
      expect(ultimateOf(q)!.id, 'ult2_milAyeres');
    });

    test('pulseParty: +2 Pulso a todo el grupo', () {
      final eng = _engine();
      final t = _turn(eng, [
        _member('p1', 'tirador', ult: 100, sel: 'ult2_pulsoMagitec', weapon: 'rifle_cronal'),
        _member('p2', 'guerrero'),
      ], ['golem']);
      // Pulso Magitec es de legendario: con el rifle equipado y en uk.
      final before = t.party[1].pulse;
      final step = eng.command(t, 'p1', const UltimateCommand())!;
      expect(step.state.party[1].pulse, before + 2);
    });

    test('openerBonus: +50% con la vida llena', () {
      final a = _engine();
      final t = _turn(a, [_member('p1', 'guerrero', ult: 100, sel: 'ult2_primerGolpe')],
          ['caballeroHueco']);
      final full = a.command(t, 'p1', const UltimateCommand())!;
      final hurt = t.copy()..enemies.single.hp -= 10;
      final b = _engine();
      final half = b.command(hurt, 'p1', const UltimateCommand())!;
      int dmg(BattleStep s) => s.events
          .whereType<DamageEvent>()
          .where((d) => d.targetId == 'e0')
          .fold(0, (a, d) => a + d.amount);
      expect(dmg(full), greaterThan(dmg(half) * 1.3));
    });

    test('echoLast: repite la última habilidad', () {
      final eng = _engine();
      var t = _turn(eng, [_member('p1', 'guerrero', ult: 100, sel: 'ult2_ecoDoble')],
          ['caballeroHueco']);
      t.party.single.lastSkillId = 'giro';
      final step = eng.command(t, 'p1', const UltimateCommand())!;
      expect(step.state.log, contains('Corte Giratorio'));
    });

    test('delayedHit: marca, cae tras 2 turnos del objetivo', () {
      final eng = _engine();
      final t = _turn(eng, [_member('p1', 'guerrero', ult: 100, sel: 'ult2_loQueSera')],
          ['caballeroHueco']);
      final s1 = eng.command(t, 'p1', const UltimateCommand())!.state;
      final boss = s1.enemies.single;
      expect(boss.doomTurns, 2);
      expect(boss.doom, greaterThan(0));
      expect(boss.hp, boss.maxHp);
    });

    test('perAlly: más poder con más aliados vivos', () {
      final solo = _engine();
      final a = solo.command(
          _turn(solo, [_member('p1', 'maga', ult: 100, sel: 'ult2_coroPrestado')], ['caballeroHueco']),
          'p1',
          const UltimateCommand())!;
      expect(a.state.log, isNot(contains('por aliados')));
      final grp = _engine();
      final b = grp.command(
          _turn(grp, [
            _member('p1', 'maga', ult: 100, sel: 'ult2_coroPrestado'),
            _member('p2', 'guerrero'),
          ], ['caballeroHueco']),
          'p1',
          const UltimateCommand())!;
      expect(b.state.log, contains('por aliados'));
    });

    test('stripBuffs: quita los buffs del enemigo', () {
      final eng = _engine();
      final t = _turn(eng, [_member('p1', 'maga', ult: 100, sel: 'ult2_finPrestado')],
          ['caballeroHueco']);
      t.enemies.single.effects = [
        const TimedEffect(sourceId: 'x', stat: BuffStat.attack, value: 0.3, turns: 3),
      ];
      final s = eng.command(t, 'p1', const UltimateCommand())!.state;
      expect(s.enemies.single.effects.where((f) => f.value > 0), isEmpty);
    });

    test('nivel de mejora: más poder', () {
      final base = kUltV2Skills['ult2_ojoFuturo']!;
      expect(UltRules.leveled(base, 5).power,
          closeTo(base.power * UltRules.levelFactor(5), 1e-9));
      expect(UltRules.levelFactor(5), closeTo(1.24, 1e-9));
    });
  });

  group('élites', () {
    test('cada élite usa su ULT; drenaje en aviso le baja el poder', () {
      final eng = _engine();
      final s = eng.start(
          party: [_member('p1', 'maga', ult: 100, sel: 'ult2_eraSuspendida')],
          enemyTypes: ['lobo'],
          elite: true,
          triggeredBy: 'p1');
      expect(s.state.enemies.single.ultId, 'eult_e_lobo');
      final t = eng.nextTurn(s.state).state;
      t.enemies.single.ultPending = true;
      final after = eng.command(t, 'p1', const UltimateCommand())!.state;
      expect(after.enemies.single.ultWeaken,
          closeTo(BattleEngine.ultWeakenMax, 1e-9),
          reason: 'Era Suspendida drena 50: tope −40%');
    });

    test('Manada Fantasma pega 3 veces', () {
      final eng = _engine([0.0]);
      final s = eng.start(
          party: [_member('p1', 'guerrero')], enemyTypes: ['lobo'], elite: true);
      final t = eng.nextTurn(s.state).state..enemies.single.ultPending = true;
      final step = eng.enemyTurn(t)!;
      expect(step.events.whereType<DamageEvent>().where((d) => d.targetId == 'p1'),
          hasLength(3));
    });
  });

  group('repertorio', () {
    PlayerProfile prof() => newProfile('Ana', 'guerrero');

    test('perfil viejo sin uk/us: comportamiento de hoy; ida y vuelta', () {
      final p = prof();
      // La normalización ya suma la ULT base de la clase (v0.20.15).
      expect(p.ultKnown, {UltRules.baseUltId(p.classId)});
      expect(p.ultSel, isNull);
      final q = p.copyWith(
          ultKnown: {'ult2_sangreEco'},
          ultSel: () => 'ult2_sangreEco',
          ultLevels: {'ult2_sangreEco': 3});
      final back = PlayerProfile.fromJson(
          jsonDecode(jsonEncode(q.toJson())) as Map<String, Object?>);
      expect(back.ultKnown, {'ult2_sangreEco'});
      expect(back.ultSel, 'ult2_sangreEco');
      expect(back.ultLevels, {'ult2_sangreEco': 3});
    });

    test('la ULT de un arma entra al repertorio y no se pierde al soltarla', () {
      const item = ItemInstance(
          uid: 'w1', baseId: 'espada_bronce', rarity: Rarity.raro, ultId: 'ult2_ecoFilo');
      final p = prof().copyWith(items: [...prof().items, item]);
      final a = UltRules.absorb(p);
      expect(a.ultKnown, contains('ult2_ecoFilo'));
      final sold = a.copyWith(items: [for (final i in a.items) if (i.uid != 'w1') i]);
      expect(UltRules.absorb(sold).ultKnown, contains('ult2_ecoFilo'));
      // Migración: un arma vieja con ULT de camino también la suma.
      final old = ItemInstance(
          uid: 'w2', baseId: 'espada_bronce', rarity: Rarity.raro,
          ultId: kBranchUltList.firstWhere((b) => b.$1 == 'filo').$2.id);
      expect(UltRules.absorb(prof().copyWith(items: [...prof().items, old])).ultKnown,
          contains(old.ultId));
    });

    test('la elegida se usa con cualquier arma, de cualquier tipo (v0.20.9)', () {
      final p = prof().copyWith(ultKnown: {'ult2_ecoFilo'}, ultSel: () => 'ult2_ecoFilo');
      expect(UltRules.validSel(p, kWeapons['espada_bronce']!, null), 'ult2_ecoFilo');
      expect(UltRules.validSel(p, kWeapons['hacha_rompe']!, null), 'ult2_ecoFilo');
    });

    test('mejorar valida fondos y paga', () {
      final p = prof().copyWith(ultKnown: {'ult2_sangreEco'});
      expect(UltRules.upgrade(p, 'ult2_sangreEco'), isNull, reason: 'sin fondos');
      final rich = p.copyWith(credits: 5000, materials: {CraftMaterial.cristal: 5});
      final up = UltRules.upgrade(rich, 'ult2_sangreEco')!;
      expect(UltRules.levelOf(up, 'ult2_sangreEco'), 2);
      expect(up.credits, 4000);
      expect(up.material(CraftMaterial.cristal), 4);
      expect(UltRules.upgrade(rich, 'ult2_ojoFuturo'), isNull, reason: 'no la tiene');
      // Jefe con Abismo: Fragmento desde el nivel 3.
      expect(UltRules.upgradeCost('ult2_finPrestado', 3)!.materials,
          contains(CraftMaterial.fragEras));
    });

    test('acciones nuevas viajan por la red', () {
      for (final a in const [SelectUltAction('ult2_ecoFilo'), SelectUltAction(null), UpgradeUltAction('ult2_ecoFilo')]) {
        final back = ActionJson.fromJson(ActionJson.toJson(a));
        expect(back.runtimeType, a.runtimeType);
      }
    });

    test('host: elegir rechaza ids que no tiene y mejora valida fondos (co-op)', () {
      final e = sessionEngine();
      var s = e.addPlayer(e.create(), 'a', newProfile('Ana', 'guerrero'))!.state;
      s = e.addPlayer(s, 'b', newProfile('Beto', 'maga'))!.state;
      expect(e.apply(s, 'a', const SelectUltAction('ult2_ojoFuturo')), isNull);
      expect(e.apply(s, 'a', const SelectUltAction('no_existe')), isNull);
      s.players['a']!.profile = s.players['a']!.profile.copyWith(
          ultKnown: {'ult2_sangreEco'}, credits: 900);
      s = act(e, s, 'a', const SelectUltAction('ult2_sangreEco'));
      expect(s.players['a']!.profile.ultSel, 'ult2_sangreEco');
      expect(e.apply(s, 'a', const UpgradeUltAction('ult2_sangreEco')), isNull,
          reason: 'faltan créditos / cristales');
      s.players['a']!.profile = s.players['a']!.profile.copyWith(
          credits: 1000, materials: {CraftMaterial.cristal: 1});
      s = act(e, s, 'a', const UpgradeUltAction('ult2_sangreEco'));
      expect(UltRules.levelOf(s.players['a']!.profile, 'ult2_sangreEco'), 2);
      expect(s.players['b']!.profile.ultLevels, isEmpty, reason: 'por personaje');
    });

    test('v0.20.13: la ULT elegida de otra arma sigue al deshacerse de esa arma', () {
      final e = sessionEngine();
      final base = newProfile('Ana', 'maga');
      final tomo = ItemInstance.common('t1', 'tomo_plaga');
      var s = e.addPlayer(e.create(), 'a',
          base.copyWith(items: [...base.items, tomo]))!.state;
      s = act(e, s, 'a', const SelectUltAction('ult_tomo'));
      expect(s.players['a']!.profile.ultKnown, contains('ult_tomo'));
      // El tomo se va (venta, fusión o alijo): la elección se mantiene.
      final p = s.players['a']!.profile;
      final sin = p.copyWith(items: [for (final i in p.items) if (i.uid != 't1') i]);
      final rules = e.progression;
      expect(UltRules.validSel(sin, rules.equippedWeapon(sin), rules.equippedItem(sin)),
          'ult_tomo');
      expect(UltRules.isLearnable('ult_baculo'), isTrue);
    });

    test('v0.20.13: una bendición no borra la ULT elegida', () {
      for (final k in BlessingKind.values) {
        final b = ExplorationRules.blessedBuild(
            PlayerBuild(
                classId: 'maga',
                level: 10,
                attributes: const PlayerAttributes({}),
                equippedWeapon: kWeapons['tomo_plaga']!,
                ultSel: 'ult2_ecoFilo',
                ultLevel: 3),
            k);
        expect(b.ultSel, 'ult2_ecoFilo', reason: '$k');
        expect(b.ultLevel, 3, reason: '$k');
      }
    });

    test('el build lleva ULT activa y nivel (snapshot de batalla)', () {
      const codec = SessionJson();
      final b = PlayerBuild(
          classId: 'guerrero',
          level: 1,
          attributes: const PlayerAttributes({}),
          equippedWeapon: kWeapons['espada_bronce']!,
          ultSel: 'ult2_ecoFilo',
          ultLevel: 3);
      final back = codec.buildFromJson(codec.buildToJson(b));
      expect(back.ultSel, 'ult2_ecoFilo');
      expect(back.ultLevel, 3);
    });
  });
}

BattleEngine e() => _engine();
