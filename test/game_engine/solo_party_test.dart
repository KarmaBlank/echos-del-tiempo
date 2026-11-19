import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/inventory_sort.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Party jugando solo (docs/specs/solo_party.md § 3).
GameSession _party(SessionEngine e, int companions,
    {List<String> classes = const ['maga', 'tirador', 'guerrero']}) {
  var s = e.addPlayer(e.create(), 'local', newProfile('Líder', 'guerrero'))!
      .state;
  for (var i = 0; i < companions; i++) {
    s = e
        .addCompanion(s, 'local-c${i + 2}', newProfile('C$i', classes[i]),
            leaderId: 'local')!
        .state;
  }
  return s;
}

/// La party en el campo de [mission]: solo el líder propone y se prepara.
GameSession _inField(SessionEngine e, GameSession s, String mission) {
  s = act(e, s, 'local', ProposeMissionAction(mission));
  s = e.tick(s, 0.05).state;
  expect(s.mode, SessionMode.prep, reason: 'los compañeros no votan');
  s = act(e, s, 'local', const ReadyAction(true));
  s = e.tick(s, 0.05).state;
  expect(s.mode, SessionMode.field, reason: 'los compañeros no se preparan');
  return s;
}

void main() {
  group('compañeros en la sala', () {
    for (final n in [1, 2, 3]) {
      test('party de ${n + 1}: entran como jugadores con su líder', () {
        final e = sessionEngine();
        final s = _party(e, n);
        expect(s.players.length, n + 1);
        for (final p in s.playerList.skip(1)) {
          expect(p.leaderId, 'local');
          expect(p.isCompanion, isTrue);
        }
        expect(s.players['local']!.isCompanion, isFalse);
      });
    }

    test('máximo 3 compañeros y 4 en total; ids únicos', () {
      final e = sessionEngine();
      final s = _party(e, 3);
      expect(
          e.addCompanion(s, 'local-c9', newProfile('X', 'maga'),
              leaderId: 'local'),
          isNull);
      final two = _party(e, 2);
      expect(
          e.addCompanion(two, 'local-c2', newProfile('X', 'maga'),
              leaderId: 'local'),
          isNull,
          reason: 'id repetido');
      expect(
          e.addCompanion(two, 'x', newProfile('X', 'maga'),
              leaderId: 'local-c2'),
          isNull,
          reason: 'un compañero no es líder');
      expect(
          e.addCompanion(two, 'x', newProfile('X', 'maga'), leaderId: 'nadie'),
          isNull);
    });

    test('solo en el pueblo sin votación: fuera de ahí no se cambia', () {
      final e = sessionEngine();
      var s = _party(e, 1);
      s = act(e, s, 'local', const ProposeMissionAction('m1'));
      expect(SessionEngine.canChangeParty(s), isFalse);
      expect(e.removeCompanion(s, 'local-c2'), isNull);
      s = e.tick(s, 0.05).state; // preparación
      expect(
          e.addCompanion(s, 'local-c3', newProfile('X', 'maga'),
              leaderId: 'local'),
          isNull);
      final lobby = _party(e, 1);
      final out = e.removeCompanion(lobby, 'local-c2')!;
      expect(out.state.players.keys, ['local']);
      expect(e.removeCompanion(lobby, 'local'), isNull,
          reason: 'removeCompanion solo saca compañeros');
    });
  });

  group('quién actúa', () {
    test('el líder actúa por su compañero; nadie más', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = e.addPlayer(_party(e, 1), 'p1', newProfile('Otro', 'maga'))!
          .state;
      const cmd = BattleAction(AttackCommand());
      // Fuera de batalla el comando no vale, pero el control se valida
      // antes: un no-líder es rechazado siempre.
      expect(e.applyFor(s, 'p1', 'local-c2', cmd), isNull);
      expect(
          e.applyFor(s, 'p1', 'local-c2', const SetLootFilterAction('x')),
          isNull);
      final ok =
          e.applyFor(s, 'local', 'local-c2', const SetLootFilterAction('x'));
      expect(ok, isNotNull);
      expect(ok!.state.players['local-c2']!.profile.lootFilter, 'x');
      expect(ok.state.players['local']!.profile.lootFilter, isNull);
      // Un compañero no camina, no vota ni compra por su cuenta.
      s = ok.state;
      final c = s.players['local-c2']!;
      expect(
          e.applyFor(s, 'local', 'local-c2',
              MoveAction(c.x + 5, c.y, epoch: c.epoch)),
          isNull);
      expect(
          e.applyFor(s, 'local', 'local-c2', const ProposeMissionAction('m1')),
          isNull);
      expect(e.apply(s, 'local-c2', const PauseAction(true)), isNull);
    });

    test('en batalla: cada uno en su turno; un id no controlado se rechaza',
        () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = wait(e, _inField(e, _party(e, 2), 'm1'), 2.6);
      final en = s.mission!.enemy(0)!;
      s = moveTo(e, s, 'local', en.x, en.y);
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.battle);
      expect(s.battle!.state.party.map((c) => c.id),
          ['local', 'local-c2', 'local-c3']);
      // Hasta el turno de un compañero.
      for (var i = 0; i < 4000; i++) {
        final b = s.battle!;
        if (b.waitingForPlayer && b.state.currentId != 'local') break;
        if (b.waitingForPlayer) {
          s = e.applyFor(s, 'local', 'local',
                  const BattleAction(DefendCommand()))!
              .state;
          continue;
        }
        s = e.tick(s, 0.05).state;
      }
      final cur = s.battle!.state.currentId!;
      expect(cur, startsWith('local-c'));
      const cmd = BattleAction(AttackCommand());
      expect(e.applyFor(s, 'p9', cur, cmd), isNull);
      final other = cur == 'local-c2' ? 'local-c3' : 'local-c2';
      expect(e.applyFor(s, 'local', other, cmd), isNull,
          reason: 'no es su turno');
      expect(e.applyFor(s, 'local', cur, cmd), isNotNull);
    });
  });

  // v0.8.3: el líder maneja el personaje de sus compañeros (§ 3.2, § 6).
  group('compañero: su personaje desde el líder', () {
    /// Ana (líder) con Leo de compañero, rico y con puntos, en el pueblo;
    /// y otro humano `p1` (no es líder de nadie).
    GameSession rich(SessionEngine e) {
      var s = e.addPlayer(e.create(), 'local', newProfile('Ana', 'guerrero'))!
          .state;
      final leo = progression.normalize(newProfile('Leo', 'guerrero').copyWith(
          level: 30,
          credits: 50000,
          points: 6,
          potions: 0,
          ascension: const AscensionProgress(trials: {1})));
      s = e.addCompanion(s, 'local-c2', leo, leaderId: 'local')!.state;
      return e.addPlayer(s, 'p1', newProfile('Otro', 'maga'))!.state;
    }

    PlayerProfile prof(GameSession s, String id) => s.players[id]!.profile;

    /// Aplica como líder por Leo: cambia Leo, nunca Ana; `p1` no puede.
    GameSession forLeo(SessionEngine e, GameSession s, SessionAction a) {
      final ana = prof(s, 'local').toJson().toString();
      expect(e.applyFor(s, 'p1', 'local-c2', a), isNull,
          reason: 'p1 no controla a Leo: $a');
      final step = e.applyFor(s, 'local', 'local-c2', a);
      expect(step, isNotNull, reason: 'rechazada: $a');
      expect(prof(step!.state, 'local').toJson().toString(), ana,
          reason: '$a no toca al líder');
      return step.state;
    }

    test('la lista de acciones de un compañero', () {
      for (final a in <SessionAction>[
        const AllocateStatsAction({Attribute.vit: 1}),
        const RespecAction(),
        const ChangeClassAction('maga'),
        const TakeNodeAction('x'),
        const ResetTreeAction(),
        const ChooseAscensionAction('berserker'),
        const TakeAscensionNodeAction('x'),
        const ResetAscensionAction(),
        const EquipAction('x'),
        const MoveInventoryAction(0, 1),
        const SortInventoryAction(InventorySortKey.rarity),
        const CraftAction(CraftOp.addAffix, 'x'),
        const FuseAction('a', 'b', 'c'),
        const UpgradeAction('a', UpgradeStat.pow),
        const BuyWeaponAction('x'),
        const BuyItemAction(BattleItem.potion),
        const EcoCraftAction('x', EcoCraftOp.tier),
        const GiveItemAction('local', 'x'),
        const DropItemAction('x'),
        const BattleAction(AttackCommand()),
        const SetLootFilterAction('x'),
      ]) {
        expect(SessionEngine.companionAction(a), isTrue, reason: '$a');
      }
      for (final a in <SessionAction>[
        const ProposeMissionAction('m1'),
        const VoteMissionAction(true),
        const ReadyAction(true),
        const CancelPrepAction(),
        const PickUpAction(1),
        const PauseAction(true),
        const ChatAction('hola'),
        const ProposeEcoAction('x'),
        const ProposeTrialAction(1),
        const ProposeAbyssAction(1),
        const DevGrantEcoAction(1),
        const UseStairsAction(down: true),
        const BackToLobbyAction(),
      ]) {
        expect(SessionEngine.companionAction(a), isFalse, reason: '$a');
      }
    });

    test('atributos, árbol y reinicios: van a Leo, no a Ana', () {
      final e = sessionEngine();
      var s = rich(e);
      final pts = prof(s, 'local-c2').points;
      expect(pts, greaterThanOrEqualTo(2));
      s = forLeo(e, s, const AllocateStatsAction({Attribute.vit: 2}));
      expect(prof(s, 'local-c2').points, pts - 2);
      final node = progression.treeRules.catalog.nodes.keys.firstWhere(
          (id) => progression.takeNode(prof(s, 'local-c2'), id) != null);
      s = forLeo(e, s, TakeNodeAction(node));
      expect(prof(s, 'local-c2').tree, contains(node));
      expect(prof(s, 'local').tree, isNot(contains(node)));
      s = forLeo(e, s, const ResetTreeAction());
      expect(prof(s, 'local-c2').tree, isEmpty);
      s = forLeo(e, s, const RespecAction());
      expect(prof(s, 'local-c2').points, pts);
    });

    test('ascensión: elegir y volver a la clase base por Leo (pueblo)', () {
      final e = sessionEngine();
      var s = rich(e);
      s = forLeo(e, s, const ChooseAscensionAction('berserker'));
      expect(prof(s, 'local-c2').ascension.id, 'berserker');
      expect(prof(s, 'local').ascension.id, isNull);
      s = forLeo(e, s, const ResetAscensionAction(full: true));
      expect(prof(s, 'local-c2').ascension.id, isNull);
    });

    test('tienda, equipar, inventario, dar y vender: por Leo', () {
      final e = sessionEngine();
      var s = rich(e);
      final leo0 = prof(s, 'local-c2');
      final w = progression.catalog.weapons.values.firstWhere((w) =>
          w.classId == 'guerrero' && progression.buyWeapon(leo0, w.id) != null);
      s = forLeo(e, s, BuyWeaponAction(w.id));
      final bought = prof(s, 'local-c2').items.last;
      expect(bought.baseId, w.id);
      expect(prof(s, 'local-c2').credits, 50000 - w.price);
      s = forLeo(e, s, const BuyItemAction(BattleItem.potion));
      expect(prof(s, 'local-c2').potions, 1);
      if (progression.equip(prof(s, 'local-c2'), bought.uid) != null) {
        s = forLeo(e, s, EquipAction(bought.uid));
        expect(prof(s, 'local-c2').equippedUid, bought.uid);
      }
      s = forLeo(e, s, const SortInventoryAction(InventorySortKey.rarity));
      // Vender (LIMPIAR) por Leo un arma suya que no tenga equipada.
      final spare = prof(s, 'local-c2')
          .items
          .where((i) => i.uid != prof(s, 'local-c2').equippedUid)
          .firstOrNull;
      if (spare != null) {
        final credits = prof(s, 'local-c2').credits;
        s = forLeo(
            e, s, CraftAction.selected(CraftOp.sellSelected, [spare.uid]));
        expect(prof(s, 'local-c2').itemByUid(spare.uid), isNull);
        expect(prof(s, 'local-c2').credits, greaterThan(credits));
      }
      // Dar al líder: la poción pasa de Leo a Ana.
      final anaPotions = prof(s, 'local').potions;
      final give = e.applyFor(
          s, 'local', 'local-c2', const GiveItemAction('local', 'pot'))!;
      s = give.state;
      expect(prof(s, 'local').potions, anaPotions + 1);
      expect(prof(s, 'local-c2').potions, 0);
    });

    test('mismas reglas que el líder: modo y pueblo; ids ajenos no', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = rich(e);
      s = e.removePlayer(s, 'p1')!.state;
      s = _inField(e, s, 'm1');
      // En el campo no se compra ni se elige ascensión (como el líder).
      expect(
          e.applyFor(
              s, 'local', 'local-c2', const BuyItemAction(BattleItem.potion)),
          isNull);
      expect(
          e.applyFor(s, 'local', 'local-c2',
              const ChooseAscensionAction('berserker')),
          isNull);
      // Repartir puntos sí (fuera de batalla), también en el campo.
      expect(
          e.applyFor(s, 'local', 'local-c2',
              const AllocateStatsAction({Attribute.fue: 1})),
          isNotNull);
      // Un compañero no maneja al líder ni a un id que no existe.
      expect(
          e.applyFor(s, 'local-c2', 'local',
              const AllocateStatsAction({Attribute.fue: 1})),
          isNull);
      expect(
          e.applyFor(s, 'local', 'local-c9',
              const AllocateStatsAction({Attribute.fue: 1})),
          isNull);
    });
  });

  group('escalado y progreso por miembro', () {
    test('la vida de los enemigos escala con la party entera', () {
      int hpWith(int companions) {
        final e = sessionEngine(fieldFallback: 0.0);
        var s = wait(e, _inField(e, _party(e, companions), 'm1'), 2.6);
        final en = s.mission!.enemy(0)!;
        s = moveTo(e, s, 'local', en.x, en.y);
        s = e.tick(s, 0.05).state;
        return s.battle!.state.enemies.first.maxHp;
      }

      final solo = hpWith(0);
      expect(hpWith(1), greaterThan(solo));
      expect(hpWith(3), greaterThan(hpWith(1)));
      // 0.6 + 0.3 × n, como en co-op (combo_balance.md § 3.3).
      expect(hpWith(3) / solo, closeTo((0.6 + 0.3 * 4) / 0.9, 0.1));
    });

    test('XP, créditos y loot propio para cada miembro', () {
      final e = sessionEngine(fieldFallback: 0.0);
      final log = <SessionEvent>[];
      var s = wait(e, _inField(e, _party(e, 2), 'm1'), 2.6);
      final en = s.mission!.enemy(0)!;
      s = moveTo(e, s, 'local', en.x, en.y);
      s = e.tick(s, 0.05).state;
      s = runBattle(e, s, log: log);
      expect(log.whereType<BattleFinishedEvent>().single.victory, isTrue);
      for (final id in ['local', 'local-c2', 'local-c3']) {
        final p = s.players[id]!.profile;
        expect(p.xp, greaterThan(0), reason: id);
        expect(p.credits, greaterThan(newProfile('x', p.classId).credits),
            reason: id);
      }
      // Cada uno con sus tiradas.
      final drops = log.whereType<LootDropEvent>().map((d) => d.playerId);
      expect(drops.toSet(), containsAll(['local', 'local-c2', 'local-c3']));
    });

    test('la subida de nivel espera solo a los humanos', () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = e.addPlayer(e.create(), 'local', newProfile('L', 'guerrero'))!
          .state;
      s = e
          .addCompanion(
              s, 'local-c2', newProfile('C', 'maga').copyWith(xp: 17),
              leaderId: 'local')!
          .state;
      s = wait(e, _inField(e, s, 'm1'), 2.6);
      final en = s.mission!.enemy(0)!;
      s = moveTo(e, s, 'local', en.x, en.y);
      s = e.tick(s, 0.05).state;
      s = runBattle(e, s);
      expect(s.players['local-c2']!.profile.level, 2);
      expect(s.mode, SessionMode.field,
          reason: 'el compañero guarda sus puntos sin pausar');
      expect(s.players['local-c2']!.profile.points, 3);
    });
  });

  group('mapa: fila detrás del líder', () {
    test('los compañeros siguen el rastro a 18 px de camino cada uno', () {
      final e = sessionEngine();
      var s = _party(e, 2);
      final l = s.players['local']!;
      final x0 = l.x, y0 = l.y;
      // El líder camina 80 px a la derecha, de a 2 px por tick.
      for (var i = 1; i <= 40; i++) {
        s = moveTo(e, s, 'local', x0 + i * 2, y0);
        s = e.tick(s, 0.05).state;
      }
      final c2 = s.players['local-c2']!, c3 = s.players['local-c3']!;
      final lx = s.players['local']!.x;
      expect(c2.y, closeTo(y0, 1e-6));
      expect(lx - c2.x, closeTo(SessionEngine.followGap, 4.01));
      expect(lx - c3.x, closeTo(2 * SessionEngine.followGap, 4.01));
      expect(c2.dir, 1);
      // Quieto: no se mueven.
      final before = (c2.x, c3.x);
      s = wait(e, s, 0.5);
      expect((s.players['local-c2']!.x, s.players['local-c3']!.x), before);
      expect(s.players['local-c2']!.moving, isFalse);
    });

    test('las interacciones son del líder: un compañero no levanta '
        'fragmentos ni toca escaleras', () {
      final e = sessionEngine();
      var s = _inField(e, _party(e, 1), 'm3');
      final frag = s.mission!.items
          .firstWhere((it) => it.kind == MissionItemKind.fragment);
      // Solo el compañero encima del fragmento.
      s.players['local-c2']!
        ..x = frag.x
        ..y = frag.y;
      s = e.tick(s, 0.05).state;
      expect(s.mission!.items.firstWhere((it) => it.id == frag.id).done,
          isFalse);
      s = moveTo(e, s, 'local', frag.x + 10, frag.y);
      s = e.tick(s, 0.05).state;
      expect(s.mission!.objective(ObjectiveKind.fragments)!.count, 1);
    });
  });

  test('mensajes de la party', () {
    final e = sessionEngine();
    final s = e.addPlayer(e.create(), 'local', newProfile('L', 'guerrero'))!
        .state;
    final step = e.addCompanion(s, 'local-c2', newProfile('Leo', 'maga'),
        leaderId: 'local')!;
    expect(
        step.events
            .whereType<SystemMessageEvent>()
            .map((m) => m.text)
            .single,
        'Leo se unió a la party.');
    final out = e.removeCompanion(step.state, 'local-c2')!;
    expect(out.events.whereType<SystemMessageEvent>().single.text,
        'Leo dejó la party.');
  });
}
