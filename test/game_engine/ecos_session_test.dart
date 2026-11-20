import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Ecos en la sala: abrir, consumir, completar, fallar, co-op, Atlas del
/// anfitrión y Maestría (docs/specs/ecos_atlas.md § 4–7).

const testEco = EcoItem(
  uid: 'x',
  tier: 2,
  zone: 1,
  boss: 1,
  rarity: Rarity.magico,
  mods: [EcoModRoll('vida', 30)],
  floors: 1,
  seed: 777,
);

/// Nivel 50 con el portal activado y [ecos] en el inventario.
PlayerProfile endgamer(String name,
    {List<EcoItem> ecos = const [], bool unlocked = true, int xp = 0}) {
  final p = zoneProgression
      .normalize(PlayerProfile(name: name, classId: 'guerrero', level: 50));
  final half = p.points ~/ 2;
  var q = zoneProgression.allocate(p, {
    Attribute.vit: half,
    Attribute.fue: p.points - half
  })!.copyWith(unlockedZone: 10, ecosUnlocked: unlocked, xp: xp);
  for (final e in ecos) {
    q = InventoryRules.addEco(q, e).$1;
  }
  return q;
}

/// Sala con [profiles] (p0, p1...) en el pueblo.
GameSession lobby(SessionEngine e, List<PlayerProfile> profiles) {
  var s = e.create();
  for (var i = 0; i < profiles.length; i++) {
    s = e.addPlayer(s, 'p$i', profiles[i])!.state;
  }
  return s;
}

/// p0 abre su primer Eco, todos votan y se preparan → campo.
GameSession openEco(SessionEngine e, GameSession s, {List<SessionEvent>? log}) {
  final uid = s.players['p0']!.profile.ecos.first.uid;
  s = act(e, s, 'p0', ProposeEcoAction(uid));
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

/// Como `runBattle`, pero con los enemigos siempre a 1 de vida (fases
/// incluidas) hasta que [until].
GameSession winBattle(SessionEngine e, GameSession s,
    {required bool Function(GameSession) until,
    List<SessionEvent>? log,
    int maxTicks = 4000}) {
  for (var i = 0; i < maxTicks && !until(s); i++) {
    for (final en in s.battle?.state.enemies ?? const []) {
      if (en.hp > 1) en.hp = 1;
    }
    // Y el grupo no cae (la ULT del Devorador pega fuerte).
    for (final c in s.battle?.state.party ?? const []) {
      if (c.alive) c.hp = c.maxHp;
    }
    final b = s.battle;
    if (b != null && b.waitingForPlayer) {
      // Primero las invocaciones (el Devorador las protege), después el jefe.
      final alive = b.state.enemies.where((x) => x.alive).toList()
        ..sort((x, y) => (x.boss ? 1 : 0) - (y.boss ? 1 : 0));
      final step = e.apply(s, b.state.currentId!,
          BattleAction(AttackCommand(targetId: alive.firstOrNull?.id)));
      if (step != null) {
        log?.addAll(step.events);
        s = step.state;
        continue;
      }
    }
    final step = e.tick(s, 0.05);
    log?.addAll(step.events);
    s = step.state;
  }
  return s;
}

/// Pelea con el grupo [id] (lo busca después de la gracia) y lo gana.
GameSession winFight(SessionEngine e, GameSession s, int id,
    {List<SessionEvent>? log, bool Function(GameSession)? until}) {
  s = wait(e, s, s.graceLeft + 0.1, log: log);
  final en = s.mission!.enemy(id)!;
  s = moveTo(e, s, 'p0', en.x, en.y);
  final st = e.tick(s, 0.05);
  log?.addAll(st.events);
  s = st.state;
  expect(s.mode, SessionMode.battle, reason: 'no empezó la batalla');
  return winBattle(e, s,
      until: until ?? (x) => x.mode != SessionMode.battle, log: log);
}

/// Al jefe y a ganar.
GameSession beatBoss(SessionEngine e, GameSession s, List<SessionEvent> log) =>
    winFight(e, s, s.mission!.enemies.singleWhere((x) => x.boss).id,
        log: log, until: (x) => x.mode == SessionMode.result);

/// Un grupo normal del piso actual.
int normalEnemy(GameSession s) => s.mission!.enemies
    .firstWhere((x) => !x.boss && !x.elite && x.floor == s.mission!.floor)
    .id;

void main() {
  group('abrir un Eco', () {
    test('se propone, se vota y se consume al empezar', () {
      final e = sessionEngine(zones: true);
      var s = lobby(e, [
        endgamer('Ana', ecos: [testEco]),
        endgamer('Bo')
      ]);
      final uid = s.players['p0']!.profile.ecos.single.uid;
      s = act(e, s, 'p0', ProposeEcoAction(uid));
      expect(s.vote!.missionId, EcoRules.missionId);
      expect(s.eco!.uid, uid);
      expect(s.ecoOwner, 'p0');
      expect(e.missionOf(s, 'eco')!.name, 'Eco de Pradera Esmeralda · T2');
      // En votación no se tira ni se regala.
      expect(e.apply(s, 'p0', DropItemAction(uid)), isNull);
      expect(e.apply(s, 'p0', GiveItemAction('p1', uid)), isNull);
      expect(s.players['p0']!.profile.ecos, hasLength(1),
          reason: 'no se consume hasta empezar');
      s = act(e, s, 'p1', const VoteMissionAction(true));
      s = e.tick(s, 0.05).state;
      expect(s.prep!.missionId, 'eco');
      for (final id in ['p0', 'p1']) {
        s = act(e, s, id, const ReadyAction(true));
      }
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.field);
      expect(s.players['p0']!.profile.ecos, isEmpty, reason: 'consumido');
      final m = s.mission!;
      expect(m.missionId, 'eco');
      expect(m.zone, 1);
      expect(m.floors, 1);
      expect(m.zoneLevel, testEco.monsterLevel);
      final map = e.mapFor(s);
      expect(map.floors, hasLength(1));
      expect(map.theme, 'pradera');
      expect(m.enemies.singleWhere((x) => x.boss).group.first, 'reyLimo');
    });

    test('rechazos: sin portal, sin el Eco, fuera del pueblo', () {
      final e = sessionEngine(zones: true);
      final s = lobby(e, [
        endgamer('Ana', ecos: [testEco], unlocked: false),
      ]);
      final uid = s.players['p0']!.profile.ecos.single.uid;
      expect(e.apply(s, 'p0', ProposeEcoAction(uid)), isNull);
      final t = lobby(e, [endgamer('Ana')]);
      expect(e.apply(t, 'p0', const ProposeEcoAction('e9')), isNull);
      expect(e.apply(t, 'p0', const ProposeMissionAction('eco')), isNull);
    });

    test('rechazar o salir el dueño cancela sin consumir', () {
      final e = sessionEngine(zones: true);
      var s = lobby(e, [
        endgamer('Ana', ecos: [testEco]),
        endgamer('Bo')
      ]);
      final uid = s.players['p0']!.profile.ecos.single.uid;
      s = act(e, s, 'p0', ProposeEcoAction(uid));
      s = act(e, s, 'p1', const VoteMissionAction(false));
      expect(s.vote, isNull);
      expect(s.eco, isNull);
      expect(s.players['p0']!.profile.ecos, hasLength(1));
      s = act(e, s, 'p0', ProposeEcoAction(uid));
      s = act(e, s, 'p1', const VoteMissionAction(true));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.prep);
      s = e.removePlayer(s, 'p0')!.state;
      expect(s.mode, SessionMode.lobby);
      expect(s.prep, isNull);
      expect(s.eco, isNull);
    });

    test('el Atlas del anfitrión agrega mods gratis al abrir', () {
      final e = sessionEngine(zones: true, ecoRandom: () => 0.3);
      var s = lobby(e, [
        endgamer('Ana', ecos: [testEco])
      ]);
      s = e.setAtlas(s, ['gratis', 'gratis2']).state;
      final log = <SessionEvent>[];
      s = openEco(e, s, log: log);
      expect(s.eco!.mods, hasLength(3));
      expect(s.eco!.mods.first, testEco.mods.first);
      expect(log.whereType<SystemMessageEvent>().map((m) => m.text),
          contains('Atlas: +2 modificadores gratis.'));
    });
  });

  group('completar y fallar', () {
    test('completar: evento para el Atlas de cada uno y un Eco nuevo', () {
      final e = sessionEngine(zones: true, ecoRandom: () => 0.9);
      var s = lobby(e, [
        endgamer('Ana', ecos: [testEco]),
        endgamer('Bo')
      ]);
      final log = <SessionEvent>[];
      s = openEco(e, s, log: log);
      s = beatBoss(e, s, log);
      expect(s.result!.success, isTrue);
      expect(s.result!.missionId, 'eco');
      expect(s.result!.unlocked, isEmpty, reason: 'un Eco no desbloquea zonas');
      final done = log.whereType<EcoCompletedEvent>().single;
      expect(done.playerIds, ['p0', 'p1']);
      expect(done.tier, 2);
      expect(done.zone, 1);
      expect(done.boss, 1);
      for (final id in ['p0', 'p1']) {
        final ecos = s.players[id]!.profile.ecos;
        expect(ecos, hasLength(1), reason: id);
        expect(ecos.single.tier, 2, reason: '0.9: mismo tier');
      }
      expect(
          log
              .whereType<LootDropEvent>()
              .where((d) => d.drop.isEco && d.source == LootSource.mission),
          hasLength(2));
      // Vuelta al pueblo: se limpia el Eco de la sala.
      s = act(e, s, 'p0', const BackToLobbyAction());
      expect(s.eco, isNull);
      expect(s.ecoOwner, isNull);
    });

    test('fallar consume el Eco y no da nada', () {
      final e = sessionEngine(zones: true);
      var s = lobby(e, [
        endgamer('Ana', ecos: [testEco])
      ]);
      final log = <SessionEvent>[];
      s = openEco(e, s, log: log);
      final boss = s.mission!.enemies.singleWhere((x) => x.boss);
      s = wait(e, s, s.graceLeft + 0.1);
      s = moveTo(e, s, 'p0', boss.x, boss.y);
      s = e.tick(s, 0.05).state;
      for (final c in s.battle!.state.party) {
        c.hp = 1;
      }
      for (final en in s.battle!.state.enemies) {
        en
          ..hp = 999999
          ..maxHp = 999999
          ..attack = 999999;
      }
      s = runBattle(e, s, until: (x) => x.mode == SessionMode.result, log: log);
      expect(s.result!.success, isFalse);
      expect(log.whereType<EcoCompletedEvent>(), isEmpty);
      expect(s.players['p0']!.profile.ecos, isEmpty);
    });
  });

  group('batalla y loot dentro del Eco', () {
    test('la batalla es del nivel del tier y aplica los mods', () {
      final e = sessionEngine(zones: true);
      var s = lobby(e, [
        endgamer('Ana', ecos: [testEco])
      ]);
      s = openEco(e, s);
      s = wait(e, s, s.graceLeft + 0.1);
      final en = s.mission!.enemy(normalEnemy(s))!;
      s = moveTo(e, s, 'p0', en.x, en.y);
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.battle);
      expect(s.battle!.level, 52);
      final first = s.battle!.state.enemies.first;
      final base = zoneProgression.catalog.enemies[first.enemyType]!.hp;
      // Solo: vida × 0.9 (combo_balance.md § 3.3).
      expect(first.maxHp, greaterThan(base * 9),
          reason: 'nivel 52 y +30% de vida');
    });

    test('la cantidad repite las tiradas; co-op suma 10% por jugador', () {
      // Azar del campo 0.0: todo sale y la repetición extra también.
      final e = sessionEngine(zones: true, fieldFallback: 0.0);
      var s = lobby(e, [
        endgamer('Ana', ecos: [testEco]),
        endgamer('Bo'),
        endgamer('Cy'),
      ]);
      s = openEco(e, s);
      final b = EcoRules.lootBonus(s.eco!, players: 3);
      expect(b.quantity,
          closeTo(0.08 + EcoRules.tierBonus(s.eco!) + 0.20, 1e-9));
      final log = <SessionEvent>[];
      s = winFight(e, s, normalEnemy(s), log: log);
      // 2 repeticiones × (1 arma + 3 materiales) por jugador.
      final p0 = log
          .whereType<LootDropEvent>()
          .where((d) => d.playerId == 'p0' && d.source == LootSource.battle);
      expect(p0.where((d) => d.drop.isItem), hasLength(2));
    });
  });

  group('Devorador y portal', () {
    test('vencer la zona 10 activa el portal y da un Eco T1', () {
      final e = sessionEngine(zones: true);
      var s = inField(e, 'z10', profiles: [endgamer('Ana', unlocked: false)]);
      final log = <SessionEvent>[];
      // Al último piso y al jefe.
      final last = s.mission!.floors - 1;
      while (s.mission!.floor < last) {
        final f = e.mapFor(s).floor(s.mission!.floor)!;
        s = moveTo(e, s, 'p0', f.stairsDown!.x, f.stairsDown!.y);
        s = e.tick(s, 0.05).state;
      }
      // El Devorador tiene 2 fases: `winBattle` deja las dos a 1 de vida.
      s = beatBoss(e, s, log);
      expect(s.result?.success, isTrue);
      final p = s.players['p0']!.profile;
      expect(p.ecosUnlocked, isTrue);
      expect(p.ecos.single.tier, 1);
      expect(log.whereType<EcosUnlockedEvent>().single.playerId, 'p0');
    });
  });

  group('desarrollo', () {
    test('DevGrantEcoAction solo con devTools', () {
      final off = sessionEngine(zones: true);
      var s = lobby(off, [endgamer('Ana', unlocked: false)]);
      expect(off.apply(s, 'p0', const DevGrantEcoAction(8)), isNull);
      final on = sessionEngine(zones: true, devTools: true);
      s = lobby(on, [endgamer('Ana', unlocked: false)]);
      s = act(on, s, 'p0', const DevGrantEcoAction(8));
      final p = s.players['p0']!.profile;
      expect(p.ecosUnlocked, isTrue);
      expect(p.ecos.single.tier, 8);
      expect(p.ecos.single.rarity, Rarity.raro);
    });
  });

  group('crafteo en la sala', () {
    test('en el pueblo sí; el Eco en votación no', () {
      final e = sessionEngine(zones: true);
      final p = endgamer('Ana', ecos: [testEco])
          .copyWith(materials: {CraftMaterial.ancla: 2});
      var s = lobby(e, [p]);
      final uid = s.players['p0']!.profile.ecos.single.uid;
      s = act(e, s, 'p0', EcoCraftAction(uid, EcoCraftOp.tier));
      expect(s.players['p0']!.profile.ecos.single.tier, 3);
      s = act(e, s, 'p0', ProposeEcoAction(uid));
      expect(e.apply(s, 'p0', EcoCraftAction(uid, EcoCraftOp.tier)), isNull);
    });
  });

  group('Maestría', () {
    test('en el 50 la XP llena la Maestría (+1 punto de árbol)', () {
      final p = endgamer('Ana');
      final g = zoneProgression.gainXp(p, 12000);
      expect(g.profile.level, 50);
      expect(g.profile.mastery, 1);
      expect(g.masteryGained, 1);
      expect(g.profile.xp, 0);
      expect(g.profile.treeLevel, 51);
      expect(ProgressionRules.masteryNeed(0), 12000);
      expect(ProgressionRules.masteryNeed(19), 69000);
      expect(ProgressionRules.totalMasteryXp, 810000);
    });

    test('tope 20 y la XP deja de acumularse', () {
      final g = zoneProgression.gainXp(endgamer('Ana'), 5000000);
      expect(g.profile.mastery, PlayerProfile.maxMastery);
      expect(g.masteryGained, 20);
      expect(g.profile.xp, 0);
      expect(zoneProgression.gainXp(g.profile, 100).profile.xp, 0);
    });

    test('del 49 al 50 y el sobrante va a la Maestría', () {
      final p = zoneProgression
          .normalize(PlayerProfile(name: 'A', classId: 'maga', level: 49));
      final g =
          zoneProgression.gainXp(p, ProgressionRules.xpNeed(49) + 12000 + 5);
      expect(g.profile.level, 50);
      expect(g.levelsGained, 1);
      expect(g.profile.mastery, 1);
      expect(g.profile.xp, 5);
    });

    test('la Maestría deja tomar nodos de más y normalize los conserva', () {
      var p = endgamer('Ana').copyWith(mastery: 2);
      final rules = zoneProgression.treeRules;
      final free = rules.pointsAvailable(p.treePoints, p.passiveProgress);
      // 1 punto por nivel y por Maestría (progresión v2): 49 + 2.
      expect(free, 51);
      expect(zoneProgression.normalize(p).mastery, 2);
      // Sin nivel 50 no hay Maestría.
      expect(
          zoneProgression
              .normalize(PlayerProfile(name: 'A', level: 10, mastery: 5))
              .mastery,
          0);
    });

    test('la sala avisa la Maestría al ganar una batalla', () {
      final e = sessionEngine(zones: true);
      var s = lobby(e, [
        endgamer('Ana', ecos: [testEco], xp: 11999)
      ]);
      s = openEco(e, s);
      final log = <SessionEvent>[];
      s = winFight(e, s, normalEnemy(s), log: log);
      expect(log.whereType<MasteryUpEvent>().single.mastery, 1);
      expect(s.players['p0']!.profile.mastery, 1);
      expect(s.mode, SessionMode.field, reason: 'no pausa la sala');
    });
  });

  test('snapshot con Eco, dueño y Atlas: ida y vuelta', () {
    final e = sessionEngine(zones: true);
    var s = lobby(e, [
      endgamer('Ana', ecos: [testEco])
    ]);
    s = e.setAtlas(s, ['gratis']).state;
    s = openEco(e, s);
    final j = const SessionJson().toJson(s);
    final back =
        const SessionJson().fromJson(asJson(jsonDecode(jsonEncode(j))));
    expect(jsonEncode(const SessionJson().toJson(back)), jsonEncode(j));
    expect(back.eco, s.eco);
    expect(back.ecoOwner, 'p0');
    expect(back.atlas, ['gratis']);
    expect(e.mapFor(back).rows, e.mapFor(s).rows);
  });
}
