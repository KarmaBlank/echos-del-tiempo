import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/abyss_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemy_families.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapon_passives.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/enemy_def.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/abyss_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Jefes del Abismo v0.8 en el motor de batalla: docs/specs/abyss_bosses.md
// § 2 (fases, movimientos, furia, sello, aspecto, inmunidad, curas que
// dañan) con azar fijo.

const _startNodes = PassiveTreeCatalog(
  nodes: {
    's_gue': PassiveNode(id: 's_gue', x: 0, y: -1.1, name: 'Inicio: Guerrero', kind: 'st', effects: {}, links: []),
    's_mag': PassiveNode(id: 's_mag', x: 1.1, y: 0, name: 'Inicio: Maga', kind: 'st', effects: {}, links: []),
    's_tir': PassiveNode(id: 's_tir', x: 0, y: 1.1, name: 'Inicio: Tirador', kind: 'st', effects: {}, links: []),
    's_pal': PassiveNode(id: 's_pal', x: -1.1, y: 0, name: 'Inicio: Paladín', kind: 'st', effects: {}, links: []),
  },
  startNodeByClass: {'guerrero': 's_gue', 'maga': 's_mag', 'tirador': 's_tir', 'paladin': 's_pal'},
  exclusions: {},
);

const _stats = StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(_startNodes));

BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  return BattleEngine(stats: _stats, random: () => i < rolls.length ? rolls[i++] : 0.99);
}

BattlePartyMember _member(String id, String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: '${cls.name} $id',
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

BattleState _start(BattleEngine e, String boss,
    [int players = 2, List<String> classes = const ['guerrero', 'maga', 'tirador', 'paladin']]) {
  final s = e
      .start(
        party: [for (var i = 0; i < players; i++) _member('p${i + 1}', classes[i])],
        enemyTypes: [boss],
      )
      .state;
  for (final p in s.party) {
    p
      ..maxHp = 999999
      ..hp = 999999
      ..mp = 99;
  }
  return s;
}

/// El turno de [id] sin pasar por `nextTurn` (Pulso lleno: estas pruebas
/// no miden el Pulso, combo_balance.md § 5.2).
BattleState _turnOf(BattleState s, String id) {
  final c = s.copy()..currentId = id;
  for (final p in c.party) {
    p.pulse = BattleEngine.pulseMax;
  }
  return c;
}

Iterable<BossMechanicEvent> _mech(BattleStep s, [BossMechanicPhase? ph]) =>
    s.events.whereType<BossMechanicEvent>().where((e) => ph == null || e.phase == ph);

/// Hace actuar al jefe `e0` [n] veces seguidas.
BattleState _bossActs(BattleEngine e, BattleState s, int n, [List<BattleStep>? log]) {
  for (var i = 0; i < n; i++) {
    final st = e.enemyTurn(_turnOf(s, 'e0'))!;
    log?.add(st);
    s = st.state;
    for (final p in s.party) {
      p.hp = p.maxHp;
    }
  }
  return s;
}

/// [player] le pega al jefe con un ataque normal.
BattleStep _hit(BattleEngine e, BattleState s, String player, {String target = 'e0'}) =>
    e.command(_turnOf(s, player), player, AttackCommand(targetId: target))!;

void main() {
  group('catálogo', () {
    test('5 jefes: enemigo, mecánica abyss, ULT, familia, nivel 85–90', () {
      expect(kAbyssBosses.keys, [1, 2, 3, 4, 5]);
      for (final d in kAbyssBosses.values) {
        final en = kEnemies[d.enemyId]!;
        expect(en.boss, isTrue, reason: d.enemyId);
        expect(en.title, isNull, reason: 'sin epítetos nuevos');
        expect(bossMechanicOf(en)!.kind, BossMechanicKind.abyss);
        expect(kEnemyUlts, contains(en.ultId));
        expect(kEnemyFamily, contains(d.enemyId));
        expect(kEnemyBaseLevel[d.enemyId], d.level);
        expect(d.level, inInclusiveRange(85, 90));
        expect(d.phases.length, inInclusiveRange(2, 3));
        expect(d.phases.first.gate, 1);
        for (var i = 1; i < d.phases.length; i++) {
          expect(d.phases[i].gate, lessThan(d.phases[i - 1].gate));
        }
        // Quiebre en puntos (combo_balance.md § 5): jefes 65-95.
        expect(en.breakMax, 95);
        for (final id in d.legendaryIds) {
          expect(kUniques[id]!.exclusive, isTrue, reason: id);
          expect(kUniques[id]!.flavor, isEmpty, reason: 'sin lore');
          expect(kWeaponPassives[kUniques[id]!.passiveId]!.unique, isTrue);
        }
      }
      expect(kAbyssBosses[5]!.secret, isTrue);
      expect(kAbyssBosses[5]!.legendaryIds, hasLength(2));
      expect(kAbyssBosses[5]!.fragment, isNull);
      // Todos los elementos en el secreto.
      final els = {
        for (final ph in kAbyssBosses[5]!.phases) ...ph.aspects,
      };
      expect(els, containsAll([GameElement.fuego, GameElement.agua, GameElement.electro,
          GameElement.hielo, GameElement.veneno]));
    });

    test('los exclusivos nunca salen del pool normal', () {
      const loot = LootRules();
      for (var i = 0; i < 400; i++) {
        var k = i;
        double rng() => ((k = (k * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
        final u = loot.pickUnique(rng, 50);
        expect(u?.exclusive ?? false, isFalse);
      }
    });
  });

  group('inicio y escalado', () {
    test('invocaciones solo si la fase 1 las pide; solo: 1', () {
      final e = _engine();
      expect(_start(e, 'hechiceraAbismo').enemies.where((c) => c.enemyType == 'ecoAbismo'), hasLength(2));
      expect(_start(e, 'hechiceraAbismo', 1).enemies.where((c) => c.enemyType == 'ecoAbismo'), hasLength(1));
      expect(_start(e, 'espectroAbismo', 4).enemies.where((c) => c.enemyType == 'siervoEspectral'), hasLength(2));
      expect(_start(e, 'golemAbismo').enemies, hasLength(1));
      expect(_start(e, 'ecoPrimordial').enemies, hasLength(1));
      // Aspecto inicial del secreto (en ciclo).
      expect(_start(e, 'ecoPrimordial').enemies.first.abyssAspect, GameElement.fuego.index + 1);
    });

    test('solo vs 4 jugadores: vida × (0.6 + 0.3 n) (solo, × jefe en '
        'solitario), quiebre × (0.6 + 0.3 n)', () {
      final e = _engine();
      final one = _start(e, 'devoradorAbismo', 1).enemies.first;
      final four = _start(e, 'devoradorAbismo', 4).enemies.first;
      // combo_balance.md § 3.3: 0.9 solo × soloBossHp (1.0).
      expect(one.maxHp, (8400 * 0.9).round());
      expect(four.maxHp, (8400 * 1.8).round());
      expect(four.breakBase / one.breakBase, closeTo(1.8 / 0.9, 0.001));
    });
  });

  group('Gólem Reloj del Abismo', () {
    test('rotación con aviso, distorsión y rebobinar', () {
      final e = _engine();
      var s = _start(e, 'golemAbismo');
      s.enemies.first.ult = 0; // sin ULT en el medio
      final log = <BattleStep>[];
      s = _bossActs(e, s, 2, log);
      // Después de la 2.ª acción avisa la Distorsión.
      expect(_mech(log[1], BossMechanicPhase.abyssTelegraph).single.value,
          AbyssMoveKind.timeWarp.index);
      final before = {for (final p in s.party) p.id: p.nextTurn};
      s.enemies.first.ult = 0;
      final warp = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(warp, BossMechanicPhase.timeWarp), hasLength(1));
      for (final p in warp.state.party) {
        expect(p.nextTurn, greaterThan(before[p.id]!));
      }
      s = warp.state;
      s = _bossActs(e, s, 1); // ataque; avisa Rebobinar
      // Le pegan y rebobina lo recibido desde su acción anterior.
      final boss = s.enemies.first..ult = 0;
      boss.hp -= 0; // sin cambio
      var st = _hit(e, s, 'p1');
      final lost = boss.maxHp - st.state.enemies.first.hp;
      expect(lost, greaterThan(0));
      expect(st.state.enemies.first.abyssTaken, lost);
      st = e.enemyTurn(_turnOf(st.state, 'e0'))!;
      expect(_mech(st, BossMechanicPhase.rewind).single.value, lost);
      expect(st.state.enemies.first.hp, boss.maxHp);
      expect(st.state.enemies.first.abyssTaken, 0);
    });

    test('quebrado no rebobina; en solo rebobina 50%', () {
      final e = _engine();
      var s = _start(e, 'golemAbismo', 1);
      // Fase 1 (vida solo 7560 desde los pasos 5-6): 5000.
      final b = s.enemies.first
        ..ult = 0
        ..actions = 4
        ..hp = 5000
        ..abyssTaken = 400;
      var st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(st.state.enemies.first.hp, 5200);
      s = _start(e, 'golemAbismo', 1);
      s.enemies.first
        ..ult = 0
        ..actions = 4
        ..hp = 5000
        ..abyssTaken = 400
        ..vulnerable = 2;
      st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(st.state.enemies.first.hp, 5000);
      expect(b.hp, 5000);
    });

    test('fases: el golpe se queda en el umbral; F2 electro y Diluvio + Descarga', () {
      final e = _engine();
      var s = _start(e, 'golemAbismo');
      final boss = s.enemies.first..ult = 0;
      final atk = boss.attack;
      boss.hp = (boss.maxHp * 0.6).ceil() + 1;
      final st = _hit(e, s, 'p1');
      final b2 = st.state.enemies.first;
      expect(b2.phase, 2);
      expect(b2.hp, (boss.maxHp * 0.6).ceil());
      expect(b2.attack, (atk * 1.15).round());
      expect(b2.abyssAspect, GameElement.electro.index + 1);
      expect(_mech(st, BossMechanicPhase.phaseShift).single.value, 2);
      // F2: Diluvio moja a todos; Descarga electrocuta a los Mojados que no
      // se defienden.
      s = st.state;
      s.party[1].defending = true;
      final dil = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(dil.state.party[0].stacks(StatusKind.wet), greaterThan(0));
      expect(dil.state.party[1].stacks(StatusKind.wet), 0, reason: 'defiende');
      s = _bossActs(e, dil.state, 1);
      s.party[0].statuses[StatusKind.wet] = 2;
      final des = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(des.events.whereType<ReactionEvent>().map((r) => r.kind),
          contains(ReactionKind.electrocucion));
      // F3 al 25%.
      final b3 = des.state.enemies.first..hp = (des.state.enemies.first.maxHp * 0.25).ceil() + 1;
      final st3 = _hit(e, des.state, 'p1');
      expect(st3.state.enemies.first.phase, 3);
      expect(b3.phase, 2);
    });
  });

  group('Hechicera del Eco del Abismo', () {
    test('Reflejo: los ecos copian la última habilidad del grupo', () {
      final e = _engine();
      var s = _start(e, 'hechiceraAbismo');
      s.enemies.first
        ..ult = 0
        ..abyssCopy = 'chispazo'
        ..actions = 1; // la próxima es el Reflejo
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      final m = _mech(st, BossMechanicPhase.mirror).toList();
      expect(m, hasLength(2), reason: '2 ecos copian');
      expect(m.every((x) => x.actorId != 'e0'), isTrue);
      expect(st.state.log, contains('Chispazo'));
      s = st.state;
      // Usar una habilidad la copian.
      final used = e.command(_turnOf(s, 'p2'), 'p2', const SkillCommand('chispa', targetId: 'e0'))!;
      expect(used.state.enemies.first.abyssCopy, 'chispa');
      // Y el próximo Reflejo pega con Fuego (Chispa deja Quemadura).
      final s2 = used.state;
      s2.enemies.first
        ..ult = 0
        ..actions = 1;
      final st2 = e.enemyTurn(_turnOf(s2, 'e0'))!;
      expect(st2.state.log, contains('Chispa'));
      expect(st2.state.log, contains('Fuego'));
    });

    test('Sello: −75% de daño; lo rompe la reacción pedida (co-op) o cualquiera (solo)', () {
      final e = _engine();
      var s = _start(e, 'hechiceraAbismo');
      final boss = s.enemies.first
        ..ult = 0
        ..actions = 3;
      var st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(st, BossMechanicPhase.sealCast).single.value, ReactionKind.electrocucion.index);
      expect(st.state.enemies.first.abyssSeal, ReactionKind.electrocucion.index + 1);
      // Daño reducido.
      final clean = _hit(e, _start(e, 'hechiceraAbismo'), 'p1');
      final sealed = _hit(e, st.state, 'p1');
      int dmg(BattleStep x) => x.events.whereType<DamageEvent>().firstWhere((d) => d.targetId == 'e0').amount;
      expect(dmg(sealed), lessThan(dmg(clean) * 0.3));
      expect(sealed.state.log, contains('SELLO'));
      // Con grupo, un Derretir (Chispa de fuego sobre Congelación) no rompe
      // un sello de Electrocución...
      s = st.state;
      s.enemies.first.statuses[StatusKind.freeze] = 2;
      final melt = e.command(_turnOf(s, 'p2'), 'p2', const SkillCommand('chispa', targetId: 'e0'))!;
      expect(melt.events.whereType<ReactionEvent>().single.kind, ReactionKind.derretir);
      expect(melt.state.enemies.first.abyssSeal, isNot(0));
      expect(boss.abyssSeal, 0);
    });

    test('Sello: lo rompe la reacción pedida; en solo cualquiera; el quiebre también', () {
      final e = _engine();
      // Co-op: sello de Derretir, Chispa sobre Congelación.
      var s = _start(e, 'hechiceraAbismo');
      s.enemies.first
        ..abyssSeal = ReactionKind.derretir.index + 1
        ..abyssSealTurns = 3
        ..statuses[StatusKind.freeze] = 2;
      var st = e.command(_turnOf(s, 'p2'), 'p2', const SkillCommand('chispa', targetId: 'e0'))!;
      expect(_mech(st, BossMechanicPhase.sealBroken).single.targetId, 'p2');
      expect(st.state.enemies.first.abyssSeal, 0);
      // Solo (la Maga sola): cualquier reacción, aunque pida Electrocución.
      s = _start(e, 'hechiceraAbismo', 1, const ['maga']);
      s.enemies.first
        ..abyssSeal = ReactionKind.electrocucion.index + 1
        ..abyssSealTurns = 3
        ..statuses[StatusKind.freeze] = 2;
      st = e.command(_turnOf(s, 'p1'), 'p1', const SkillCommand('chispa', targetId: 'e0'))!;
      expect(st.state.enemies.first.abyssSeal, 0);
      // El quiebre también.
      s = _start(e, 'hechiceraAbismo', 1);
      final b = s.enemies.first
        ..abyssSeal = ReactionKind.electrocucion.index + 1
        ..abyssSealTurns = 3;
      b
        ..breakGauge = b.breakMax
        ..fissured = true;
      final br = e.command(_turnOf(s, 'p1'), 'p1',
          const SkillCommand('quebrar', targetId: 'e0'))!;
      expect(_mech(br, BossMechanicPhase.sealBroken), hasLength(1));
      // Se apaga solo.
      s = _start(e, 'hechiceraAbismo');
      s.enemies.first
        ..ult = 0
        ..abyssSeal = 1
        ..abyssSealTurns = 1;
      final fade = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(fade, BossMechanicPhase.sealFade), hasLength(1));
    });
  });

  group('Espectro Coronado del Abismo', () {
    test('F2: inmune al daño con siervos vivos; las curas lo dañan', () {
      final e = _engine();
      var s = _start(e, 'espectroAbismo');
      final boss = s.enemies.first..ult = 0;
      boss.hp = (boss.maxHp * 0.6).ceil() + 1;
      final st = _hit(e, s, 'p1');
      s = st.state;
      expect(s.enemies.first.phase, 2);
      expect(s.enemies.where((c) => c.alive && c.enemyType == 'siervoEspectral'), hasLength(2));
      final hp = s.enemies.first.hp;
      final none = _hit(e, s, 'p1');
      expect(none.state.enemies.first.hp, hp, reason: 'inmune');
      expect(_mech(none, BossMechanicPhase.immune), isNotEmpty);
      // Poción: cura y le hace daño (60%).
      final q = s.party.first
        ..maxHp = 2000
        ..hp = 1000;
      q.potions = 1;
      final pot = e.command(_turnOf(s, q.id), q.id, const ItemCommand(BattleItem.potion));
      expect(pot, isNotNull);
      final healed = pot!.events.whereType<HealEvent>().first.amount;
      expect(pot.state.enemies.first.hp, hp - (healed * 0.6).round());
    });
  });

  group('Devorador de Eras del Abismo', () {
    test('Devorar: se come los buffs y gana ATQ (tope)', () {
      final e = _engine();
      final s = _start(e, 'devoradorAbismo');
      final boss = s.enemies.first
        ..ult = 0
        ..actions = 2; // la próxima es Devorar
      final atk = boss.attack;
      for (final p in s.party) {
        p.effects = [
          const TimedEffect(sourceId: 'x', stat: BuffStat.attack, value: 0.2, turns: 2),
          const TimedEffect(sourceId: 'y', stat: BuffStat.shield, value: 50, turns: 2),
          const TimedEffect(sourceId: 'z', stat: BuffStat.damageTaken, value: 0.2, turns: 2),
        ];
      }
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(st, BossMechanicPhase.devour).single.value, 4);
      expect(st.state.enemies.first.abyssFeast, 4);
      expect(st.state.enemies.first.attack, (atk * 1.2).round());
      expect(st.state.party.every((p) => p.effects.length == 1), isTrue);
    });

    test('3 fases; F3 ciclo de aspecto y resiste su elemento', () {
      final e = _engine();
      var s = _start(e, 'devoradorAbismo');
      final boss = s.enemies.first..ult = 0;
      boss.hp = (boss.maxHp * 0.66).ceil();
      s = _hit(e, s, 'p1').state;
      expect(s.enemies.first.phase, 2);
      s.enemies.first.hp = (boss.maxHp * 0.33).ceil();
      s = _hit(e, s, 'p1').state;
      expect(s.enemies.first.phase, 3);
      expect(s.enemies.first.abyssAspect, GameElement.fuego.index + 1);
      s.enemies.first.ult = 0;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(st, BossMechanicPhase.aspect).single.value, GameElement.agua.index);
      // Su golpe Era es de Agua y deja Mojado.
      expect(st.state.party.any((p) => p.stacks(StatusKind.wet) > 0), isTrue);
    });
  });

  group('furia', () {
    test('al turno 40: ATQ ×2 y golpe a todos', () {
      final e = _engine();
      final s = _start(e, 'golemAbismo');
      final boss = s.enemies.first
        ..ult = 0
        ..abyssTurns = 39;
      final atk = boss.attack;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(st, BossMechanicPhase.enrage).single.value, 2);
      expect(st.state.enemies.first.attack, atk * 2);
      expect(st.state.enemies.first.abyssEnraged, isTrue);
      expect(st.events.whereType<ActionEvent>().single.kind, BattleActionKind.enemyArea);
      expect(AbyssRules.enrageIn(kAbyssBosses[1]!, st.state.enemies.first), 0);
    });
  });

  group('secreto', () {
    test('F3: inmune al daño con ecos vivos; las curas lo dañan', () {
      final e = _engine();
      var s = _start(e, 'ecoPrimordial');
      final boss = s.enemies.first..ult = 0;
      boss.hp = (boss.maxHp * 0.66).ceil();
      s = _hit(e, s, 'p1').state;
      expect(s.enemies.first.phase, 2);
      expect(s.enemies.where((c) => c.alive && c.enemyType == 'ecoAbismo'), hasLength(2));
      s.enemies.first.hp = (boss.maxHp * 0.33).ceil();
      s = _hit(e, s, 'p1').state;
      expect(s.enemies.first.phase, 3);
      final hp = s.enemies.first.hp;
      expect(_hit(e, s, 'p1').state.enemies.first.hp, hp);
    });
  });

  test('red: los campos del Abismo hacen ida y vuelta', () {
    final c = Combatant(
      id: 'e0',
      name: 'X',
      isPlayer: false,
      hp: 1,
      maxHp: 2,
      speed: 1,
      attack: 1,
      critChance: 0,
      enemyType: 'golemAbismo',
      abyssTurns: 7,
      abyssEnraged: true,
      abyssSeal: 2,
      abyssSealTurns: 1,
      abyssAspect: 3,
      abyssTaken: 99,
      abyssFeast: 4,
      abyssCopy: 'chispazo',
    );
    const j = SessionJson();
    final back = j.combatantFromJson(asJson(jsonDecode(jsonEncode(j.combatantToJson(c)))));
    expect([back.abyssTurns, back.abyssEnraged, back.abyssSeal, back.abyssSealTurns, back.abyssAspect,
        back.abyssTaken, back.abyssFeast, back.abyssCopy], [7, true, 2, 1, 3, 99, 4, 'chispazo']);
  });
}

