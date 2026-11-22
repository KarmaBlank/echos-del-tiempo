import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Guerrero de nivel [level] con los puntos repartidos en VIT y FUE.
PlayerProfile _strong(int level, {int vit = 18, String name = 'Fuerte'}) {
  final pts = (level - 1) * 3;
  return progression.normalize(PlayerProfile.fromJson({
    'name': name,
    'cls': 'guerrero',
    'lvl': level,
    'st': {'VIT': 10 + vit, 'ESP': 4, 'AGI': 6, 'FUE': 12 + pts - vit, 'DES': 6},
    'pts': 0,
  }));
}

/// Pasa la gracia del inicio con el jugador quieto en el spawn.
GameSession _afterGrace(SessionEngine e, GameSession s) => wait(e, s, 2.6);

/// Pone a p0 encima del enemigo [id] y avanza un tick: empieza la batalla.
GameSession _touch(SessionEngine e, GameSession s, int id,
    {List<SessionEvent>? log}) {
  final en = s.mission!.enemy(id)!;
  s = moveTo(e, s, 'p0', en.x, en.y);
  final step = e.tick(s, 0.05);
  log?.addAll(step.events);
  return step.state;
}

void main() {
  group('lobby', () {
    test('entra hasta el máximo de jugadores, sin ids repetidos', () {
      final e = sessionEngine(maxPlayers: 4);
      var s = e.create();
      for (var i = 0; i < 4; i++) {
        final step = e.addPlayer(s, 'p$i', newProfile('J$i', 'maga'))!;
        expect(step.events.whereType<PlayerJoinedEvent>(), hasLength(1));
        s = step.state;
      }
      expect(e.addPlayer(s, 'p9', newProfile('X', 'maga')), isNull);
      expect(e.addPlayer(s, 'p0', newProfile('X', 'maga')), isNull);
      // spawnPos(i) en el pueblo (v0.21.0): (272, 232) ± 7 en cuadrícula
      // de 2 × 2.
      expect([for (final p in s.playerList) '${p.x},${p.y}'],
          ['265.0,225.0', '279.0,225.0', '265.0,239.0', '279.0,239.0']);
      final p0 = s.players['p0']!;
      expect(p0.hp, p0.maxHp);
      expect(p0.mp, p0.maxMp);
    });

    for (final max in const [8, 12]) {
      test('máximo $max: entran $max con lugares distintos, no uno más', () {
        final e = sessionEngine(maxPlayers: max);
        var s = e.create();
        for (var i = 0; i < max; i++) {
          s = e.addPlayer(s, 'p$i', newProfile('J$i', 'maga'))!.state;
        }
        expect(s.players.length, max);
        expect(e.addPlayer(s, 'px', newProfile('X', 'maga')), isNull);
        expect({for (final p in s.playerList) '${p.x},${p.y}'}, hasLength(max));
      });
    }

    test('nombre vacío entra como Héroe', () {
      final e = sessionEngine();
      final s = e.addPlayer(e.create(), 'h', PlayerProfile())!.state;
      expect(s.players['h']!.name, 'Héroe');
    });

    test('votación: un no la cancela; todos sí → preparación', () {
      final e = sessionEngine();
      var s = e.create();
      s = e.addPlayer(s, 'a', newProfile('A', 'guerrero'))!.state;
      s = e.addPlayer(s, 'b', newProfile('B', 'maga'))!.state;
      expect(e.apply(s, 'a', const ProposeMissionAction('m9')), isNull);
      s = act(e, s, 'a', const ProposeMissionAction('m1'));
      expect(s.vote!.yes, {'a'});
      expect(e.apply(s, 'b', const ProposeMissionAction('m2')), isNull);
      s = act(e, s, 'b', const VoteMissionAction(false));
      expect(s.vote, isNull);
      s = act(e, s, 'a', const ProposeMissionAction('m1'));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.lobby, reason: 'falta el voto de b');
      s = act(e, s, 'b', const VoteMissionAction(true));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.prep);
      expect(s.prep!.missionId, 'm1');
      s = act(e, s, 'a', const ReadyAction(true));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.prep, reason: 'falta b');
      s = act(e, s, 'b', const CancelPrepAction());
      expect(s.mode, SessionMode.lobby);
    });

    test('tienda y clase según el modo', () {
      final e = sessionEngine();
      var s = e.create();
      s = e.addPlayer(s, 'a', newProfile('A', 'guerrero').copyWith(credits: 100))!.state;
      s = act(e, s, 'a', const BuyItemAction(BattleItem.potion));
      expect(s.players['a']!.profile.potions, 4);
      expect(s.players['a']!.profile.credits, 70);
      s = act(e, s, 'a', const ChangeClassAction('maga'));
      final a = s.players['a']!;
      expect(a.profile.classId, 'maga');
      expect(a.hp, a.maxHp);
      expect(a.mp, a.maxMp);

      final f = inField(sessionEngine(), 'm1');
      final e2 = sessionEngine();
      expect(e2.apply(f, 'p0', const BuyItemAction(BattleItem.potion)), isNull);
      expect(e2.apply(f, 'p0', const ChangeClassAction('maga')), isNull);
      // Reiniciar es gratis y se puede fuera del lobby (freeRespec), pero
      // en el campo no llena vida y maná.
      final hurt = f.players['p0']!..hp = 5;
      final r = e2.apply(f, 'p0', const RespecAction())!.state.players['p0']!;
      expect(r.hp, hurt.hp);
      expect(e2.apply(f, 'p0', const ResetTreeAction()), isNotNull);
    });
  });

  group('movimiento', () {
    test('MoveAction exige la época actual y modo lobby/campo', () {
      final e = sessionEngine();
      var s = e.addPlayer(e.create(), 'a', newProfile('A', 'tirador'))!.state;
      final ep = s.players['a']!.epoch;
      expect(e.apply(s, 'a', MoveAction(50, 60, epoch: ep - 1)), isNull);
      s = act(e, s, 'a', MoveAction(50, 60, epoch: ep, dir: -3, moving: true));
      expect(s.players['a']!.x, 50);
      expect(s.players['a']!.dir, -1);
      expect(s.players['a']!.moving, isTrue);
      s = act(e, s, 'a', MoveAction(0, 70, epoch: ep));
      expect(s.players['a']!.x, 50, reason: 'x = 0 se ignora (`+d.x || p.x`)');
      expect(s.players['a']!.y, 70);
    });
  });

  group('campo', () {
    test('cofre: créditos, poción y loot v2 según el azar', () {
      // m2 es rango B (tier 2), cofre común (loot.md § 23). Azar: créditos
      // 0.5 → 20 + 15 + 20 = 55; 0.1 < 0.30 → consumible, 0.3 < 0.6 → poción;
      // 0.05 < 0.45 → arma; rareza 0.0 → Común; base
      // 0.0 → la primera (Espada de Bronce); materiales 0.99 → nada.
      final e = sessionEngine(fieldRolls: [0.5, 0.1, 0.3, 0.05, 0.0, 0.0]);
      var s = inField(e, 'm2');
      // Zona de m2: recomendado 4 + rango B = 5.
      expect(s.mission!.zoneLevel, 5);
      final chest = s.mission!.items.firstWhere((i) => i.kind == MissionItemKind.chest);
      s = moveTo(e, s, 'p0', chest.x, chest.y);
      final step = e.tick(s, 0.05);
      s = step.state;
      final p = s.players['p0']!.profile;
      expect(p.credits, 55);
      expect(p.potions, 4);
      expect(p.items, hasLength(2));
      final got = p.items.last;
      expect(got.baseId, 'espada_bronce');
      expect(got.rarity, Rarity.comun);
      expect(got.itemLevel, 5);
      expect(got.uid, isNot('espada_bronce'), reason: 'uid nuevo');
      expect(s.mission!.items.firstWhere((i) => i.id == chest.id).done, isTrue);
      final ev = step.events.whereType<ChestOpenedEvent>().single;
      expect(ev.credits, 55);
      expect(ev.item, BattleItem.potion);
      expect(ev.weaponId, 'espada_bronce');
      final loot = step.events.whereType<LootDropEvent>().single;
      expect(loot.source, LootSource.chest);
      expect(loot.uid, got.uid);
      expect(loot.groundId, isNull, reason: 'sin loot en el piso: inventario');
    });

    test('fragmentos se recogen al pasar por encima', () {
      final e = sessionEngine();
      var s = inField(e, 'm3');
      final frag = s.mission!.items.firstWhere((i) => i.kind == MissionItemKind.fragment);
      s = moveTo(e, s, 'p0', frag.x + 10, frag.y);
      s = e.tick(s, 0.05).state;
      expect(s.mission!.objective(ObjectiveKind.fragments)!.count, 1);
    });

    test('sellos: a menos de 30 px; con todo cumplido se abre la barrera', () {
      final e = sessionEngine();
      var s = inField(e, 'm1');
      final seals =
          s.mission!.items.where((i) => i.kind == MissionItemKind.seal).toList();
      s = moveTo(e, s, 'p0', seals[0].x + 31, seals[0].y);
      expect(e.apply(s, 'p0', ActivateSealAction(seals[0].id)), isNull);
      s = moveTo(e, s, 'p0', seals[0].x + 20, seals[0].y);
      s = act(e, s, 'p0', ActivateSealAction(seals[0].id));
      expect(e.apply(s, 'p0', ActivateSealAction(seals[0].id)), isNull,
          reason: 'ya activado');
      s.mission!.kills = 7; // como si ya hubiera derrotado los 7 grupos
      s = moveTo(e, s, 'p0', seals[1].x, seals[1].y);
      final step = e.apply(s, 'p0', ActivateSealAction(seals[1].id))!;
      expect(step.state.mission!.open, isTrue);
      expect(step.state.gateOpen, isTrue);
      expect(step.events.whereType<GateOpenedEvent>(), hasLength(1));
    });

    test('regenera vida y maná en el campo', () {
      final e = sessionEngine();
      var s = inField(e, 'm1');
      s.players['p0']!
        ..hp = 10
        ..mp = 1;
      s = e.tick(s, 1).state;
      final p = s.players['p0']!;
      expect(p.hp, closeTo(10 + p.maxHp * 0.008, 1e-9));
      expect(p.mp, closeTo(1.4, 1e-9));
    });

    test('IA: persigue a 34 px/s cuando no está calmo y el jugador está cerca', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = _afterGrace(e, inField(e, 'm1'));
      final en = s.mission!.enemy(0)!;
      s = moveTo(e, s, 'p0', en.x + 40, en.y);
      s = e.tick(s, 0.05).state;
      final after = s.mission!.enemy(0)!;
      expect(after.aggro, isTrue);
      expect(after.vx, closeTo(34, 1e-6));
      expect(after.vy.abs(), lessThan(1e-6));
      expect(after.dir, 1);
    });

    test('durante la gracia no hay contacto ni persecución', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = inField(e, 'm1');
      final en = s.mission!.enemy(0)!;
      s = moveTo(e, s, 'p0', en.x, en.y);
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.field);
      expect(s.mission!.enemy(0)!.aggro, isFalse);
    });
  });

  group('batalla', () {
    test('contacto → batalla; victoria → XP, créditos, kills y vuelta al campo', () {
      final e = sessionEngine(fieldFallback: 0.0);
      final log = <SessionEvent>[];
      var s = _afterGrace(e, inField(e, 'm1'));
      final epoch = s.players['p0']!.epoch;
      s = _touch(e, s, 0, log: log);
      expect(s.mode, SessionMode.battle);
      expect(s.battle!.fieldEnemyId, 0);
      expect(s.players['p0']!.epoch, epoch + 1);
      expect(log.whereType<BattleStartedEvent>().single.fieldEnemyId, 0);
      expect(e.apply(s, 'p0', const BuyItemAction(BattleItem.potion)), isNull);
      // Pausa inicial de 1 s: todavía no se puede actuar.
      expect(e.apply(s, 'p0', const BattleAction(AttackCommand())), isNull);

      s = runBattle(e, s, log: log);
      expect(s.mode, SessionMode.field);
      expect(log.whereType<BattleFinishedEvent>().single.victory, isTrue);
      final m = s.mission!;
      expect(m.enemy(0)!.alive, isFalse);
      expect(m.kills, 1);
      expect(m.objective(ObjectiveKind.kills)!.count, 1);
      expect(m.xp, 12); // 2 slimes × 6
      expect(m.credits, 10);
      final p = s.players['p0']!;
      expect(p.profile.xp, 12);
      expect(p.profile.credits, 10);
      expect(p.hp, greaterThan(0));
      expect(s.battle, isNull);
      expect(s.graceLeft, closeTo(3.5, 1e-9));
      // calmEnemies: los vivos a menos de 120 px vuelven a casa.
      for (final en in m.enemies.where((x) => x.alive && !x.boss)) {
        final d = (en.x - p.x) * (en.x - p.x) + (en.y - p.y) * (en.y - p.y);
        if (d < 120 * 120) expect(en.x, en.homeX);
      }
    });

    test('subida de nivel: pausa en levelUp hasta repartir los puntos', () {
      final e = sessionEngine(fieldFallback: 0.0);
      final log = <SessionEvent>[];
      var s = _afterGrace(
          e, inField(e, 'm1', profiles: [newProfile('A', 'guerrero').copyWith(xp: 17)]));
      final before = s.players['p0']!.maxHp;
      s = _touch(e, s, 0);
      s = runBattle(e, s, log: log);
      expect(log.whereType<LevelUpEvent>().single.level, 2);
      expect(s.mode, SessionMode.levelUp);
      expect(s.mustAllocate('p0'), isTrue);
      final p = s.players['p0']!;
      expect(p.profile.level, 2);
      expect(p.profile.points, 1);
      expect(p.profile.xp, 29 - 18);
      expect(p.maxHp, greaterThan(before));
      // El reloj de la misión no corre en levelUp.
      final elapsed = s.mission!.elapsed;
      s = wait(e, s, 1);
      expect(s.mode, SessionMode.levelUp);
      expect(s.mission!.elapsed, elapsed);
      final hp = s.players['p0']!.hp;
      final maxHp = s.players['p0']!.maxHp;
      s = act(e, s, 'p0', const AllocateStatsAction({Attribute.vit: 1}));
      // VIT +3 → +12 de vida base, × 1.05 del nodo inicial (redondeado).
      final gained = s.players['p0']!.maxHp - maxHp;
      expect(gained, 13);
      expect(s.players['p0']!.hp, hp + gained);
      expect(s.players['p0']!.levelUpPending, isFalse);
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.field);
    });

    test('élite: cuenta élites, 1 arma segura + 50% de otra y materiales ×3',
        () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = _afterGrace(e, inField(e, 'm1', profiles: [_strong(10)]));
      final elite = s.mission!.enemies.firstWhere((x) => x.elite);
      s = _touch(e, s, elite.id);
      expect(s.battle!.elite, isTrue);
      expect(s.battle!.state.enemies.first.elite, isTrue);
      final log = <SessionEvent>[];
      s = runBattle(e, s, log: log);
      expect(s.mode, SessionMode.field);
      final m = s.mission!;
      expect(m.elites, 1);
      expect(m.kills, 0, reason: 'los élites no cuentan como grupo');
      // Azar 0.0: todo sale, Común y la primera base.
      expect(m.eliteDrops.single.weaponId, 'espada_bronce');
      final p = s.players['p0']!.profile;
      expect(p.items, hasLength(3));
      expect(p.items.skip(1).every((i) => i.itemLevel == m.zoneLevel + 1),
          isTrue);
      for (final mat in LootRules.materialChance.keys) {
        expect(p.material(mat), 1, reason: mat.name);
      }
      // El Ancla Temporal solo cae dentro de los Ecos (ecos_atlas.md § 3).
      expect(p.material(CraftMaterial.ancla), 0);
      expect(log.whereType<LootDropEvent>().where((x) => x.source == LootSource.elite),
          hasLength(5));
      expect(log.whereType<WeaponDropEvent>().single.source, 'elite');
    });

    test('derrota → misión fallida (rango D) y vuelta al lobby', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = _afterGrace(e, inField(e, 'm3'));
      s = _touch(e, s, 0); // ghost + ghost contra un guerrero nivel 1
      s = runBattle(e, s);
      expect(s.result, isNotNull);
      final r = s.result!;
      expect(r.success, isFalse);
      expect(r.rank, MissionRank.d);
      expect(r.kos, greaterThanOrEqualTo(1));
      expect(s.players['p0']!.hp, 1);
      s = backToLobby(e, s);
      expect(s.mode, SessionMode.lobby);
      expect(s.mission, isNull);
      expect(s.players['p0']!.hp, s.players['p0']!.maxHp);
    });

    test('jefe: victoria → rango S, bonus 50% y arma de la misión', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = _afterGrace(e, inField(e, 'm1', profiles: [_strong(50, vit: 60)]));
      final boss = s.mission!.enemies.firstWhere((x) => x.boss);
      final log = <SessionEvent>[];
      s = _touch(e, s, boss.id);
      expect(s.battle!.boss, isTrue);
      s = runBattle(e, s, log: log);
      expect(s.result, isNotNull);
      final r = s.result!;
      expect(r.success, isTrue);
      expect(r.rank, MissionRank.s);
      // Solo, el jefe pelea sin escolta (combo_balance.md § 3.3): 80.
      expect(r.credits, 80);
      expect(r.bonus, 40);
      expect(r.drops, {'p0': 'espada_bronce'});
      expect(s.players['p0']!.profile.credits, 80 + 40);
      // Jefe: 2 armas + materiales ×5 (+1 Esquirla); fin de misión: 1 arma
      // + materiales ×2. Todo al inventario.
      final p = s.players['p0']!.profile;
      expect(p.items, hasLength(1 + 2 + 1));
      expect(p.material(CraftMaterial.esquirla), 3);
      expect(p.material(CraftMaterial.cristal), 2);
      expect(p.material(CraftMaterial.prisma), 2);
      // Zona: el promedio del grupo (50) manda sobre la misión (1).
      expect(p.items.last.itemLevel, 50, reason: 'fin de misión: zona + 1, tope 50');
      expect(log.whereType<MissionEndedEvent>(), hasLength(1));
      // v0.20.22: sin regreso automático; el grupo sigue en el área.
      s = wait(e, s, SessionEngine.resultSeconds + 0.1);
      expect(s.victoryLap, isTrue);
      s = backToLobby(e, s);
      expect(s.mode, SessionMode.lobby);
    });

    test('rango A si tarda más que sTime pero menos de 1.5×', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = _afterGrace(e, inField(e, 'm1', profiles: [_strong(50, vit: 60)]));
      s.mission!.elapsed = 500; // sTime de m1 = 420

      s = _touch(e, s, s.mission!.enemies.firstWhere((x) => x.boss).id);
      s = runBattle(e, s);
      expect(s.result!.rank, MissionRank.a);
      expect(s.result!.bonus, 20); // round(80 × 0.25), jefe sin escolta
    });

    test('a los 30 s sin actuar el jugador se defiende solo', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = _afterGrace(e, inField(e, 'm1'));
      s = _touch(e, s, 0);
      s = runBattle(e, s, until: (x) => x.battle!.waitingForPlayer);
      s = wait(e, s, 30.1);
      expect(s.battle!.state.log, contains('Tiempo agotado'));
      expect(s.battle!.state.party.first.defending, isTrue);
    });

    test('un jugador que entra a mitad de batalla se suma; uno que sale, se va', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = _afterGrace(e, inField(e, 'm1'));
      s = _touch(e, s, 0);
      s = e.addPlayer(s, 'p1', newProfile('Nuevo', 'maga'))!.state;
      expect([for (final c in s.battle!.state.party) c.id], ['p0', 'p1']);
      s = e.removePlayer(s, 'p1')!.state;
      expect([for (final c in s.battle!.state.party) c.id], ['p0']);
      expect(s.players.keys, ['p0']);
    });

    test('los comandos de batalla pasan por BattleEngine y respetan el turno', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = _afterGrace(e, inField(e, 'm1', classes: ['guerrero', 'maga']));
      s = _touch(e, s, 0);
      s = runBattle(e, s, until: (x) => x.battle!.waitingForPlayer);
      final cur = s.battle!.state.currentId!;
      final other = cur == 'p0' ? 'p1' : 'p0';
      expect(e.apply(s, other, const BattleAction(DefendCommand())), isNull);
      final step = e.apply(s, cur, const BattleAction(DefendCommand()))!;
      expect(step.state.battle!.state.byId(cur)!.defending, isTrue);
      expect(step.state.battle!.state.currentId, isNull);
      expect(step.state.battle!.wait, closeTo(0.8, 1e-9));
    });

    // Pulso, precondiciones e Instante (combo_balance.md § 5.2).
    test('el host rechaza Quebrar sin objetivo Fisurado', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = _afterGrace(e, inField(e, 'm1'));
      s = _touch(e, s, 0);
      s = runBattle(e, s, until: (x) => x.battle!.waitingForPlayer);
      expect(
          e.apply(s, 'p0',
              const BattleAction(SkillCommand('quebrar', targetId: 'e0'))),
          isNull);
    });

    test('Instante: el turno sigue y el reloj de 30 s cuenta el turno entero',
        () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = _afterGrace(e, inField(e, 'm1'));
      s = _touch(e, s, 0);
      s = runBattle(e, s, until: (x) => x.battle!.waitingForPlayer);
      s = wait(e, s, 10);
      final before = s.battle!.turnTime;
      final step = e.apply(s, 'p0',
          const BattleAction(SkillCommand('brasaEco', targetId: 'e0')))!;
      s = step.state;
      expect(s.battle!.state.currentId, 'p0');
      expect(s.battle!.state.byId('p0')!.chained, isTrue);
      // Después de la pausa de la animación, sigue el mismo turno.
      s = wait(e, s, 1);
      expect(s.battle!.waitingForPlayer, isTrue);
      expect(s.battle!.turnTime, greaterThanOrEqualTo(before));
      // 30 s del turno entero (no 30 desde la Instante).
      s = wait(e, s, 30 - s.battle!.turnTime + 0.1);
      expect(s.battle!.state.log, contains('Tiempo agotado'));
    });
  });
}
