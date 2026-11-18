import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/abyss_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/abyss_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/atlas_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecos_session_test.dart' show endgamer, lobby, openEco, winBattle, winFight;
import 'session_test_helpers.dart';

// Jefes del Abismo en la sala: Fragmentos, abrir / consumir, la pelea sin
// mazmorra, recompensas por jugador, el secreto, la Esencia y la red
// (docs/specs/abyss_bosses.md § 1, § 3, § 5).

const _rules = AbyssRules();

EcoItem _eco({int tier = 12, int boss = 1, Rarity rarity = Rarity.magico, int mods = 1}) => EcoItem(
      uid: 'e',
      tier: tier,
      zone: 1,
      boss: boss,
      rarity: rarity,
      mods: [for (var i = 0; i < mods; i++) EcoModRoll(['vida', 'furia', 'prisa', 'coraza', 'tirano'][i], 20)],
      floors: 1,
      seed: 1,
    );

PlayerProfile _withMats(PlayerProfile p, Map<CraftMaterial, int> m) =>
    p.copyWith(materials: {...p.materials, ...m});

SessionEngine _engine({RandomSource? abyss, bool dev = false}) => SessionEngine(
      battles: BattleEngine(stats: statsCalc, random: rolls(const [])),
      progression: zoneProgression,
      random: rolls(const []),
      seeds: () => 123,
      ecoRandom: () => 0.999,
      abyssRandom: abyss ?? () => 0.5,
      devTools: dev,
    );

/// p0 abre el jefe [n], todos votan y se preparan → batalla.
GameSession _open(SessionEngine e, GameSession s, int n, {List<SessionEvent>? log}) {
  s = act(e, s, 'p0', ProposeAbyssAction(n));
  for (final id in s.players.keys.skip(1)) {
    s = act(e, s, id, const VoteMissionAction(true));
  }
  s = e.tick(s, 0.05).state;
  expect(s.mode, SessionMode.prep);
  for (final id in s.players.keys) {
    s = act(e, s, id, const ReadyAction(true));
  }
  final st = e.tick(s, 0.05);
  log?.addAll(st.events);
  return st.state;
}

void main() {
  group('Fragmentos (§ 1.1)', () {
    test('solo en Ecos de tier 10+; escala con tier, rareza y mods', () {
      expect(_rules.fragmentChance(_eco(tier: 9), LootSource.boss), 0);
      final t10 = _rules.fragmentChance(_eco(tier: 10, rarity: Rarity.comun, mods: 0), LootSource.battle);
      expect(t10, closeTo(0.02, 1e-9));
      final t16 = _rules.fragmentChance(_eco(tier: 16, rarity: Rarity.comun, mods: 0), LootSource.battle);
      expect(t16, closeTo(0.02 * 1.9, 1e-9));
      final rich = _rules.fragmentChance(_eco(tier: 10, rarity: Rarity.legendario, mods: 5), LootSource.battle);
      expect(rich, closeTo(0.02 * (1 + 0.4 + 0.25), 1e-9));
      // Jefe del Eco que coincide (Gólem Reloj = jefe 3): ×1.5 en jefe y fin.
      final plain = _rules.fragmentChance(_eco(boss: 1), LootSource.boss);
      final match = _rules.fragmentChance(_eco(boss: 3), LootSource.boss);
      expect(match / plain, closeTo(1.5, 1e-9));
      expect(_rules.fragmentChance(_eco(boss: 3), LootSource.battle),
          _rules.fragmentChance(_eco(boss: 1), LootSource.battle));
      // Tope.
      expect(_rules.fragmentChance(_eco(tier: 16, boss: 10, rarity: Rarity.legendario, mods: 5), LootSource.mission),
          lessThanOrEqualTo(0.95));
    });

    test('determinista; el que coincide pesa ×4', () {
      // Cae (0.01 < chance) y elige por peso: con el jefe 3, [4,1,1,1]/7.
      expect(_rules.rollFragment(rolls([0.01, 0.1]), _eco(boss: 3), LootSource.boss), CraftMaterial.fragReloj);
      expect(_rules.rollFragment(rolls([0.01, 0.6]), _eco(boss: 3), LootSource.boss), CraftMaterial.fragEco);
      expect(_rules.rollFragment(rolls([0.01, 0.99]), _eco(boss: 3), LootSource.boss), CraftMaterial.fragEras);
      // Sin coincidencia: 1/4 cada uno.
      expect(_rules.rollFragment(rolls([0.01, 0.3]), _eco(boss: 1), LootSource.boss), CraftMaterial.fragEco);
      // No cae.
      expect(_rules.rollFragment(rolls([0.99]), _eco(), LootSource.boss), isNull);
      // Mismo azar, mismo resultado.
      final a = [for (var i = 0; i < 20; i++) _rules.rollFragment(rolls([i / 40, 0.5]), _eco(boss: 6), LootSource.boss)];
      final b = [for (var i = 0; i < 20; i++) _rules.rollFragment(rolls([i / 40, 0.5]), _eco(boss: 6), LootSource.boss)];
      expect(a, b);
    });

    test('en la sala: cada jugador tira lo suyo en las tiradas del Eco', () {
      final e = SessionEngine(
        battles: BattleEngine(stats: statsCalc, random: rolls(const [])),
        progression: zoneProgression,
        random: rolls(const []),
        seeds: () => 5,
        ecoRandom: () => 0.999,
        abyssRandom: () => 0.001, // siempre cae
      );
      var s = lobby(e, [endgamer('Ana', ecos: [_eco(tier: 12)]), endgamer('Bo')]);
      s = openEco(e, s);
      expect(s.mode, SessionMode.field);
      s = winFight(e, s, s.mission!.enemies.first.id);
      for (final id in ['p0', 'p1']) {
        final p = s.players[id]!.profile;
        expect(kFragments.map(p.material).fold(0, (a, b) => a + b), greaterThanOrEqualTo(1),
            reason: id);
      }
      // Fuera de un Eco (o tier < 10) no caen.
      final low = SessionEngine(
        battles: BattleEngine(stats: statsCalc, random: rolls(const [])),
        progression: zoneProgression,
        random: rolls(const []),
        seeds: () => 5,
        ecoRandom: () => 0.999,
        abyssRandom: () => 0.001,
      );
      var s2 = lobby(low, [endgamer('Ana', ecos: [_eco(tier: 9)])]);
      s2 = openEco(low, s2);
      s2 = winFight(low, s2, s2.mission!.enemies.first.id);
      expect(kFragments.map(s2.players['p0']!.profile.material).fold(0, (a, b) => a + b), 0);
    });
  });

  group('abrir y consumir (§ 1.2)', () {
    test('costo, requisitos y consumo al empezar', () {
      final d = kAbyssBosses[1]!;
      var p = endgamer('Ana');
      expect(_rules.cannotOpen(p, d), contains('Fragmento del Reloj (0/5)'));
      p = _withMats(p, {CraftMaterial.fragReloj: 5});
      expect(_rules.cannotOpen(p, d), isNull);
      expect(_rules.cannotOpen(p.copyWith(ecosUnlocked: false), d), isNotNull);
      final paid = _rules.consume(p, d)!;
      expect(paid.material(CraftMaterial.fragReloj), 0);
      expect(_rules.consume(paid, d), isNull);
    });

    test('secreto: los 4 vencidos + 1 de cada Fragmento', () {
      final d = kAbyssBosses[5]!;
      var p = _withMats(endgamer('Ana'), {for (final f in kFragments) f: 1});
      expect(_rules.cannotOpen(p, d), 'Vencé a los 4 Jefes del Abismo');
      expect(AbyssRules.visible(p, d), isFalse);
      p = p.copyWith(abyssKills: {1, 2, 3});
      expect(_rules.cannotOpen(p, d), isNotNull);
      p = p.copyWith(abyssKills: {1, 2, 3, 4});
      expect(_rules.cannotOpen(p, d), isNull);
      expect(AbyssRules.visible(p, d), isTrue);
      final paid = _rules.consume(p, d)!;
      for (final f in kFragments) {
        expect(paid.material(f), 0);
      }
      // La cuenta también cuenta (Atlas x1..x4).
      final fresh = _withMats(endgamer('Bo'), {for (final f in kFragments) f: 1});
      final merged = AbyssRules.withAccount(fresh, AtlasProgress(done: ['x1', 'x2', 'x3', 'x4', 't1']));
      expect(merged.abyssKills, {1, 2, 3, 4});
      expect(_rules.cannotOpen(merged, d), isNull);
    });

    test('rechazar o cancelar no consume; el host valida el costo', () {
      final e = _engine();
      var s = lobby(e, [_withMats(endgamer('Ana'), {CraftMaterial.fragEco: 5}), endgamer('Bo')]);
      expect(e.apply(s, 'p1', const ProposeAbyssAction(2)), isNull, reason: 'Bo no tiene Fragmentos');
      expect(e.apply(s, 'p0', const ProposeAbyssAction(5)), isNull, reason: 'secreto bloqueado');
      s = act(e, s, 'p0', const ProposeAbyssAction(2));
      expect([s.abyss, s.abyssOwner, s.vote!.missionId], [2, 'p0', AbyssRules.missionId]);
      s = act(e, s, 'p1', const VoteMissionAction(false));
      expect(s.abyss, isNull);
      expect(s.players['p0']!.profile.material(CraftMaterial.fragEco), 5);
    });

    test('empieza directo en la batalla con el jefe, nivel 86, y consume', () {
      final e = _engine();
      var s = lobby(e, [_withMats(endgamer('Ana'), {CraftMaterial.fragEco: 7}), endgamer('Bo')]);
      final log = <SessionEvent>[];
      s = _open(e, s, 2, log: log);
      expect(s.mode, SessionMode.battle);
      expect(s.players['p0']!.profile.material(CraftMaterial.fragEco), 2);
      expect(s.battle!.level, 86);
      expect(s.battle!.state.enemies.first.enemyType, 'hechiceraAbismo');
      // Vida a nivel 86 sin escalar de más: 6600 × (0.55 + 0.45 × 2).
      expect(s.battle!.state.enemies.first.maxHp, (6600 * 1.45).round());
      expect(log.whereType<MissionStartedEvent>(), hasLength(1));
      expect(log.whereType<BattleStartedEvent>(), hasLength(1));
      // El mapa existe (1 piso, tema de su zona base).
      expect(e.mapFor(s).floors, hasLength(1));
    });
  });

  group('victoria y recompensas (§ 3)', () {
    test('exclusivo seguro la 1.ª vez para cada uno, Esencias, marca y evento', () {
      final e = _engine();
      var s = lobby(e, [_withMats(endgamer('Ana'), {CraftMaterial.fragReloj: 5}), endgamer('Bo')]);
      s = _open(e, s, 1);
      final log = <SessionEvent>[];
      s = winBattle(e, s, until: (x) => x.mode == SessionMode.result, log: log);
      expect(s.result!.success, isTrue);
      expect(s.result!.missionId, AbyssRules.missionId);
      for (final id in ['p0', 'p1']) {
        final p = s.players[id]!.profile;
        expect(p.abyssKills, contains(1));
        expect(p.items.where((i) => i.uniqueId == 'manecillaAbismo'), hasLength(1), reason: id);
        expect(p.material(CraftMaterial.esencia), inInclusiveRange(1, 2));
      }
      final ev = log.whereType<AbyssDefeatedEvent>().single;
      expect([ev.boss, ev.playerIds], [1, ['p0', 'p1']]);
      // No desbloquea zonas ni el portal de nuevo.
      expect(s.result!.unlocked, isEmpty);
    });

    test('repetido: el exclusivo es por chance (25%)', () {
      final d = kAbyssBosses[1]!;
      final p = endgamer('Ana').copyWith(abyssKills: {1});
      const loot = LootRules();
      expect(_rules.rewards(rolls([0.9, 0.9]), d, p, loot).where((x) => x.isItem), isEmpty);
      expect(_rules.rewards(rolls([0.1, 0.0]), d, p, loot).where((x) => x.isItem), hasLength(1));
      final first = _rules.rewards(rolls(const []), d, endgamer('Bo'), loot);
      expect(first.first.item!.uniqueId, 'manecillaAbismo');
      expect(first.last.stack, StackKind.esencia);
      // El secreto: uno de sus 2, 3 Esencias.
      final sec = _rules.rewards(rolls(const [0, 0.7]), kAbyssBosses[5]!, endgamer('Cy'), loot);
      expect(kAbyssBosses[5]!.legendaryIds, contains(sec.first.item!.uniqueId));
      expect(sec.last.count, 3);
    });

    test('fallar consume igual', () {
      final e = _engine();
      var s = lobby(e, [_withMats(endgamer('Ana'), {CraftMaterial.fragEras: 5})]);
      s = _open(e, s, 4);
      for (final c in s.battle!.state.party) {
        c.hp = 0;
      }
      s.battle!.state.currentId = null;
      s = wait(e, s, 6);
      expect(s.mode, SessionMode.result);
      expect(s.result!.success, isFalse);
      expect(s.players['p0']!.profile.material(CraftMaterial.fragEras), 0);
      expect(s.players['p0']!.profile.abyssKills, isEmpty);
    });

    test('Atlas: x1..x5 dan 1 (secreto 2) punto la primera vez', () {
      const r = AbyssRules();
      var a = AtlasProgress();
      final g = r.recordAccount(a, 1);
      expect(g.points, 1);
      a = g.progress;
      expect(r.recordAccount(a, 1).points, 0);
      expect(r.recordAccount(a, 5).points, 2);
      expect(const AtlasRules().earned(a), 1);
      expect(AtlasRules.maxPoints, 50, reason: 'sigue sin alcanzar para los 51 de costo');
    });
  });

  group('Esencia del Abismo (§ 3.1)', () {
    test('mejor de 2 tiradas, nunca baja; solo legendarios', () {
      const craft = CraftRules(loot: LootRules());
      final u = kUniques['manecillaAbismo']!;
      final item = const LootRules().generateUnique(rolls([0, 0, 0, 0]), u, 50, uid: 'leg');
      var p = endgamer('Ana');
      p = p.copyWith(items: [...p.items, item], materials: {CraftMaterial.esencia: 2});
      final fixedBefore = [for (final a in item.affixes) if (a.fixed) a.value];
      expect(fixedBefore, [u.fixed[0].min, u.fixed[1].min]);
      final r = craft.essence(p, 'leg', random: rolls([0.2, 0.99, 0.0, 0.0]));
      expect(r.error, isNull);
      final after = r.profile!.itemByUid('leg')!;
      final fixedAfter = [for (final a in after.affixes) if (a.fixed) a.value];
      expect(fixedAfter[0], u.fixed[0].max, reason: 'la mejor de 2');
      expect(fixedAfter[1], u.fixed[1].min, reason: 'nunca baja');
      expect(r.profile!.material(CraftMaterial.esencia), 1);
      // No legendario.
      final plain = p.items.first;
      expect(craft.essence(p, plain.uid, random: rolls(const [])).error, isNotNull);
      // Sin Esencia.
      expect(craft.essence(p.copyWith(materials: {}), 'leg', random: rolls(const [])).error, isNotNull);
    });
  });

  group('desarrollo', () {
    test('DevAbyssAction solo con devTools', () {
      var e = _engine();
      var s = lobby(e, [endgamer('Ana')]);
      expect(e.apply(s, 'p0', const DevAbyssAction('frag')), isNull);
      e = _engine(dev: true);
      s = lobby(e, [endgamer('Ana')]);
      s = act(e, s, 'p0', const DevAbyssAction('frag'));
      final p = s.players['p0']!.profile;
      for (final f in kFragments) {
        expect(p.material(f), 5);
      }
      expect(p.material(CraftMaterial.esencia), 3);
      s = act(e, s, 'p0', const DevAbyssAction('kills'));
      expect(s.players['p0']!.profile.abyssKills, {1, 2, 3, 4});
      // Con eso abre el secreto.
      s = act(e, s, 'p0', const ProposeAbyssAction(5));
      expect(s.abyss, 5);
    });
  });

  group('red (protocolo 9)', () {
    test('versión 9', () => expect(kProtocolVersion, 9));

    test('acciones, evento, sesión, perfil y materiales hacen ida y vuelta', () {
      for (final a in const [ProposeAbyssAction(3), DevAbyssAction('kills')]) {
        final back = ActionJson.fromJson(asJson(jsonDecode(jsonEncode(ActionJson.toJson(a)))));
        expect(ActionJson.toJson(back), ActionJson.toJson(a));
      }
      const ej = EventJson();
      const ev = AbyssDefeatedEvent(5, ['h', 'p1']);
      final back = ej.fromJson(asJson(jsonDecode(jsonEncode(ej.toJson(ev))))) as AbyssDefeatedEvent;
      expect([back.boss, back.playerIds], [5, ['h', 'p1']]);
      final e = _engine();
      var s = lobby(e, [_withMats(endgamer('Ana'), {CraftMaterial.fragCorona: 5, CraftMaterial.esencia: 2})]);
      s = act(e, s, 'p0', const ProposeAbyssAction(3));
      s.players['p0']!.profile = s.players['p0']!.profile.copyWith(abyssKills: {1, 3});
      const sj = SessionJson();
      final s2 = sj.fromJson(asJson(jsonDecode(jsonEncode(sj.toJson(s)))));
      expect([s2.abyss, s2.abyssOwner], [3, 'p0']);
      final p = s2.players['p0']!.profile;
      expect(p.abyssKills, {1, 3});
      expect(p.material(CraftMaterial.fragCorona), 5);
      expect(p.material(CraftMaterial.esencia), 2);
      // El drop de Fragmento viaja como pila.
      const d = LootDrop.stack(StackKind.fragEras, 1);
      expect(LootDrop.fromJson(jsonDecode(jsonEncode(d.toJson())))!.stack, StackKind.fragEras);
    });
  });
}

