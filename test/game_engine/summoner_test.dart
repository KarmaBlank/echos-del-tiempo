import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/summoner_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/rules/summon_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Invocador v0.8.1 (docs/specs/summoner.md): invocar, tope, IA,
// duración, Sacrificio, ULT de los tomos, escalado y red.

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

BattleEngine _engine() =>
    BattleEngine(stats: _stats, random: () => 0.99, breakEnabled: false, familiesEnabled: false);

BattleState _start(BattleEngine e, String weapon, {int enemies = 2}) {
  final cls = kClasses['maga']!;
  final s = e.start(party: [
    BattlePartyMember(
      id: 'p1',
      name: 'Maga',
      build: PlayerBuild(
        classId: 'maga',
        level: 10,
        attributes: PlayerAttributes.base(cls.baseAttributes),
        equippedWeapon: kWeapons[weapon]!,
        // ULT libres del arma: la del tomo vale si se eligió.
        ultSel: kWeaponUltOf[weapon],
      ),
    ),
  ], enemyTypes: [for (var i = 0; i < enemies; i++) 'golem']).state;
  for (final c in s.enemies) {
    c
      ..maxHp = 99999
      ..hp = 99999;
  }
  s.party.first
    ..mp = 999
    ..maxHp = 9999
    ..hp = 9999
    ..ult = 100;
  s.currentId = 'p1';
  return s;
}

BattleState _cast(BattleEngine e, BattleState s, String skill) {
  s.currentId = 'p1';
  return e.command(s, 'p1', SkillCommand(skill, targetId: 'e0'))!.state;
}

void main() {
  test('catálogo: 9 habilidades, 5 tomos, solo armas de lanzador', () {
    for (final id in kSummonerSkills.keys) {
      expect(kSkills, contains(id));
      expect(kSkillDelivery[id], SkillDelivery.caster, reason: id);
    }
    for (final id in kSummonerWeapons.keys) {
      expect(kWeapons[id]!.type, 'tomo');
      expect(kWeapons[id]!.skillIds.length, lessThanOrEqualTo(3));
    }
    const items = ItemRules();
    expect(items.canReceiveSkill(const ItemInstance(uid: 'a', baseId: 'espada_bronce'), 'invFuego'),
        'Solo armas de lanzador');
    expect(items.canReceiveSkill(const ItemInstance(uid: 'b', baseId: 'baculo_aprendiz'), 'invFuego'),
        isNull);
  });

  test('invocar crea un aliado con stats por MAG y el tope de 4 reemplaza al más viejo', () {
    final e = _engine();
    var s = _start(e, 'tomo_invocador');
    s = _cast(e, s, 'invFuego');
    expect(s.summons, hasLength(1));
    final f = s.summons.first;
    final p = s.party.first;
    final st = SummonRules.stats(kSummons[SummonKind.fuego]!,
        magic: p.magic, maxHp: p.maxHp, speed: p.speed, crit: p.critChance, level: 10, build: p.build);
    expect(f.summonOwner, 'p1');
    expect(f.attack, st.attack);
    expect(f.hp, st.hp);
    expect(f.summonTurns, kSummonTurns);
    for (var i = 0; i < 4; i++) {
      s = _cast(e, s, 'invGolem');
    }
    expect(s.summons, hasLength(kSummonMax));
    expect(s.summons.any((c) => c.id == f.id), isFalse, reason: 'el más viejo se va');
  });

  test('turno del elemental: pega con su elemento, deja su estado y vence a los 4 turnos', () {
    final e = _engine();
    var s = _start(e, 'tomo_invocador', enemies: 1);
    s = _cast(e, s, 'invFuego');
    final id = s.summons.first.id;
    for (var t = 0; t < kSummonTurns; t++) {
      s.currentId = id;
      final before = s.enemies.first.hp;
      s = e.enemyTurn(s)!.state;
      expect(s.enemies.first.hp, lessThan(before));
      expect(s.enemies.first.stacks(StatusKind.burn), greaterThan(0));
    }
    expect(s.summons, isEmpty);
  });

  test('Sacrificio detona el elemento en todos y gasta la invocación', () {
    final e = _engine();
    var s = _start(e, 'tomo_invocador');
    s = _cast(e, s, 'invFuego');
    final hp = [for (final c in s.enemies) c.hp];
    s = _cast(e, s, 'sacrificio');
    expect(s.summons, isEmpty);
    for (var i = 0; i < hp.length; i++) {
      expect(s.enemies[i].hp, lessThan(hp[i]));
    }
  });

  test('ULT del Libro de los Cuatro: Portal invoca a los 4 elementales y atacan ya', () {
    final e = _engine();
    var s = _start(e, 'libro_cuatro');
    expect(ultimateOf(s.party.first)!.id, 'ult_portal');
    final hp = s.enemies.first.hp + s.enemies.last.hp;
    s = e.command(s, 'p1', const UltimateCommand(targetId: 'e0'))!.state;
    expect(s.summons.map((c) => c.summonKind).toSet(),
        {for (final k in kElementalSummons) k.name});
    expect(s.enemies.first.hp + s.enemies.last.hp, lessThan(hp));
  });

  test('ULT de tomos: Códice → Marea de Espíritus (Gólem + 2 Espíritus y escudo); Pacto → Avatar', () {
    final e = _engine();
    var s = _start(e, 'codice_enjambre');
    expect(ultimateOf(s.party.first)!.id, 'ult_marea');
    s = e.command(s, 'p1', const UltimateCommand())!.state;
    expect(s.summons.map((c) => c.summonKind).toList()..sort(), ['espiritu', 'espiritu', 'golem']);
    expect(s.party.first.shield, greaterThan(0));
    expect(s.summons.every((c) => c.taunt == kMareaTaunt), isTrue);

    var a = _start(e, 'tomo_pacto');
    expect(ultimateOf(a.party.first)!.id, 'ult_avatar');
    a = _cast(e, a, 'invHielo');
    a = _cast(e, a, 'invFuego');
    a.party.first.ult = 100;
    a.currentId = 'p1';
    a = e.command(a, 'p1', const UltimateCommand())!.state;
    expect(a.summons, isEmpty, reason: 'se consumen');
    expect(a.party.first.effectTotal(BuffStat.damage), closeTo(2 * kAvatarPower, 1e-9));
    a.currentId = 'p1';
    a = e.command(a, 'p1', const AttackCommand(targetId: 'e0'))!.state;
    expect(a.enemies.first.stacks(StatusKind.burn), greaterThan(0));
  });

  test('escalado: rareza, forja y afijo Evocador suben el daño; del Pacto suma turnos', () {
    final d = kSummons[SummonKind.fuego]!;
    final w = kWeapons['tomo_invocador']!;
    PlayerBuild b(ItemInstance? it) => PlayerBuild(
        classId: 'maga',
        level: 10,
        attributes: const PlayerAttributes({}),
        equippedWeapon: w,
        item: it);
    SummonStats st(PlayerBuild bb) =>
        SummonRules.stats(d, magic: 100, maxHp: 500, speed: 8, crit: 0.2, level: 10, build: bb);
    final base = st(b(null));
    final epic = st(b(const ItemInstance(uid: 'x', baseId: 'tomo_invocador', rarity: Rarity.epico,
        forge: WeaponUpgradeLevels(pow: 2), affixes: [AffixRoll('evocador', 1, 20), AffixRoll('del_pacto', 1, 1)])));
    expect(epic.attack, greaterThan(base.attack));
    expect(epic.hp, greaterThan(base.hp));
    expect(epic.turns, base.turns + 1);
    final legion = SummonRules.stats(d, magic: 100, maxHp: 500, speed: 8, crit: 0.2, level: 10,
        build: b(null), ids: const ['legion', 'herenciaArcana', 'pactoDuradero']);
    expect(legion.attack, lessThan(base.attack));
    expect(legion.crit, closeTo(0.05 + 0.2 * 0.3, 1e-9));
    expect(legion.turns, base.turns + 2);
    expect(SummonRules.maxActive(const ['legion']), kSummonMaxLegion);
    expect(SummonRules.killBonus(const ['festinArcano'], 9), 0.5);
  });

  test('red: las invocaciones van y vuelven en el JSON de la batalla', () {
    final e = _engine();
    var s = _start(e, 'tomo_invocador');
    s = _cast(e, s, 'invGolem');
    s.summons.first.summonKills = 2;
    const j = SessionJson();
    final back = j.battleStateFromJson(asJson(jsonDecode(jsonEncode(j.battleStateToJson(s)))));
    expect(jsonEncode(j.battleStateToJson(back)), jsonEncode(j.battleStateToJson(s)));
    expect(back.summons.single.summonOwner, 'p1');
    expect(back.summons.single.summonKills, 2);
    expect(back.byId(back.summons.single.id), isNotNull);
  });
}
