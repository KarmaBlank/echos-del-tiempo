import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

PlayerProfile _withItems(String name,
        {int extra = 1, Map<CraftMaterial, int> mats = const {}}) =>
    progression.normalize(PlayerProfile(
      name: name,
      classId: 'guerrero',
      materials: mats,
      inventory: ['espada_bronce', for (var i = 0; i < extra; i++) 'espada_ignea'],
    ));

LootDrop _sword([int il = 1]) => LootDrop.item(
    ItemInstance(uid: 'nuevo', baseId: 'espada_ignea', itemLevel: il));

void main() {
  group('grilla', () {
    test('8×5, la equipada no ocupa, pilas en 1 casilla', () {
      final p = _withItems('A', extra: 2,
          mats: const {CraftMaterial.esquirla: 5});
      final l = InventoryRules.layout(p);
      expect(l.cells, hasLength(40));
      // 2 Ígneas + pociones + maná + Esquirlas (la de Bronce está equipada).
      expect(l.cells.whereType<String>().toList(),
          ['espada_ignea', 'espada_ignea#2', 'pot', 'eter', 'mat:esquirla']);
      expect(InventoryRules.freeCells(p), 35);
      expect(l.overflow, isEmpty);
    });

    test('mover respeta posiciones y lo nuevo llena el primer hueco', () {
      var p = _withItems('A', extra: 2);
      p = InventoryRules.move(p, 0, 10)!;
      expect(InventoryRules.layout(p).cells[10], 'espada_ignea');
      expect(InventoryRules.layout(p).cells[0], isNull);
      p = InventoryRules.receive(p, _sword())!;
      final cells = InventoryRules.layout(p).cells;
      expect(cells[0], startsWith('i'), reason: 'arma nueva en el hueco 0');
      expect(cells[10], 'espada_ignea');
      expect(InventoryRules.move(p, 3, 3), isNull);
      expect(InventoryRules.move(p, 39, 2), isNull, reason: 'casilla vacía');
    });

    test('lleno: no recibe armas ni pilas nuevas; apila hasta el tope', () {
      var p = _withItems('A', extra: 37);
      expect(InventoryRules.freeCells(p), 1);
      p = InventoryRules.receive(p, const LootDrop.stack(StackKind.cristal, 2))!;
      expect(InventoryRules.freeCells(p), 0);
      expect(InventoryRules.cannotReceive(p, _sword()), 'Inventario lleno');
      expect(InventoryRules.cannotReceive(p, const LootDrop.stack(StackKind.prisma, 1)),
          'Inventario lleno');
      // Una pila que ya existe no necesita casilla.
      p = InventoryRules.receive(p, const LootDrop.stack(StackKind.cristal, 97))!;
      expect(p.material(CraftMaterial.cristal), 99);
      expect(InventoryRules.cannotReceive(p, const LootDrop.stack(StackKind.cristal, 1)),
          'Máximo 99');
      expect(InventoryRules.cannotReceive(p, const LootDrop.stack(StackKind.potion, 7)),
          'Máximo 9');
    });

    test('perfil viejo con más de 40 armas: desborda y no recibe', () {
      final p = progression.normalize(PlayerProfile(
          classId: 'guerrero',
          inventory: [for (var i = 0; i < 45; i++) 'espada_ignea']));
      final l = InventoryRules.layout(p);
      expect(l.overflow, isNotEmpty);
      expect(InventoryRules.cannotReceive(p, _sword()), 'Inventario lleno');
    });

    test('uids nuevos únicos', () {
      var p = _withItems('A');
      for (var i = 0; i < 3; i++) {
        p = InventoryRules.receive(p, _sword())!;
      }
      final uids = p.items.map((i) => i.uid).toList();
      expect(uids.toSet(), hasLength(uids.length));
      expect(p.itemSeq, 3);
    });
  });

  group('dar, soltar y levantar (host)', () {
    (SessionEngine, GameSession) room({PlayerProfile? a, PlayerProfile? b}) {
      final e = sessionEngine();
      var s = e.addPlayer(e.create(), 'p0', a ?? _withItems('A',
          mats: const {CraftMaterial.esquirla: 3}))!.state;
      s = e.addPlayer(s, 'p1', b ?? _withItems('B', extra: 0))!.state;
      return (e, s);
    }

    test('dar un arma y una pila a un compañero', () {
      final (e, s) = room();
      final step = e.apply(s, 'p0', const GiveItemAction('p1', 'espada_ignea'))!;
      var a = step.state.players['p0']!.profile;
      var b = step.state.players['p1']!.profile;
      expect(a.itemByUid('espada_ignea'), isNull);
      expect(b.items.map((i) => i.baseId), contains('espada_ignea'));
      expect(step.events.whereType<ItemGivenEvent>().single.toId, 'p1');
      final s2 = e.apply(step.state, 'p0',
          const GiveItemAction('p1', 'mat:esquirla', count: 2))!.state;
      a = s2.players['p0']!.profile;
      b = s2.players['p1']!.profile;
      expect(a.material(CraftMaterial.esquirla), 1);
      expect(b.material(CraftMaterial.esquirla), 2);
    });

    test('rechazos: equipada, inicial, a sí mismo, en batalla, sin lugar', () {
      final (e, s) = room();
      expect(e.apply(s, 'p0', const GiveItemAction('p1', 'espada_bronce')), isNull);
      expect(e.apply(s, 'p0', const GiveItemAction('p0', 'espada_ignea')), isNull);
      expect(e.apply(s, 'p0', const GiveItemAction('nadie', 'espada_ignea')), isNull);
      expect(e.apply(s, 'p0', const GiveItemAction('p1', 'mat:esquirla', count: 9)),
          isNull);
      final (e2, full) = room(b: _withItems('B', extra: 38));
      expect(e2.apply(full, 'p0', const GiveItemAction('p1', 'espada_ignea')),
          isNull, reason: 'el otro no tiene lugar');
      expect(full.players['p0']!.profile.itemByUid('espada_ignea'), isNotNull,
          reason: 'nada cambió');
      s.mode = SessionMode.battle;
      expect(e.apply(s, 'p0', const GiveItemAction('p1', 'espada_ignea')), isNull);
    });

    test('soltar al piso (compartido) y levantar con E', () {
      final (e, s) = room();
      final dropped = e.apply(s, 'p0', const DropItemAction('espada_ignea'))!.state;
      final g = dropped.ground.single;
      expect(g.ownerId, isNull);
      expect(g.drop.item!.baseId, 'espada_ignea');
      expect(dropped.groundFor('p1'), hasLength(1));
      // Lejos: no.
      final far = moveTo(e, dropped, 'p1', g.x + 200, g.y);
      expect(e.apply(far, 'p1', PickUpAction(g.id)), isNull);
      final near = moveTo(e, dropped, 'p1', g.x + 5, g.y);
      final step = e.apply(near, 'p1', PickUpAction(g.id))!;
      expect(step.state.ground, isEmpty);
      expect(step.state.players['p1']!.profile.items.map((i) => i.baseId),
          contains('espada_ignea'));
      expect(step.events.whereType<LootPickedEvent>().single.playerId, 'p1');
    });

    test('el loot con dueño solo lo levanta su dueño', () {
      final (e, s) = room();
      s.ground.add(GroundLoot(
          id: 1, drop: _sword(), x: s.players['p1']!.x, y: s.players['p1']!.y,
          ownerId: 'p0'));
      expect(s.groundFor('p1'), isEmpty);
      expect(e.apply(s, 'p1', const PickUpAction(1)), isNull);
    });

    test('mover casillas y guardar el filtro', () {
      final (e, s) = room();
      final m = e.apply(s, 'p0', const MoveInventoryAction(0, 5))!.state;
      expect(InventoryRules.layout(m.players['p0']!.profile).cells[5],
          'espada_ignea');
      final f = e.apply(m, 'p0', const SetLootFilterAction('Ocultar\n  Rareza Común\n'))!
          .state;
      expect(f.players['p0']!.profile.lootFilter, startsWith('Ocultar'));
      final d = e.apply(f, 'p0', const SetLootFilterAction(null))!.state;
      expect(d.players['p0']!.profile.lootFilter, isNull);
      expect(
          e.apply(s, 'p0', SetLootFilterAction('x' * 9000)), isNull);
    });
  });

  group('loot en el mapa (groundLoot)', () {
    SessionEngine groundEngine() => SessionEngine(
          battles: BattleEngine(stats: statsCalc, random: () => 0.99),
          progression: progression,
          random: () => 0.0,
          seeds: () => 500000000,
          groundLoot: true,
        );

    test('el drop cae al piso con dueño y se levanta al pasar encima', () {
      final e = groundEngine();
      var s = wait(e, inField(e, 'm1', profiles: [_withItems('A')]), 2.6);
      final en = s.mission!.enemy(0)!;
      s = moveTo(e, s, 'p0', en.x, en.y);
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.battle);
      final log = <SessionEvent>[];
      s = runBattle(e, s, log: log);
      expect(s.mode, SessionMode.field);
      final drops = log.whereType<LootDropEvent>().toList();
      expect(drops, isNotEmpty);
      expect(drops.every((d) => d.groundId != null), isTrue);
      expect(s.ground.every((g) => g.ownerId == 'p0'), isTrue);
      final before = s.players['p0']!.profile.items.length;
      // El jugador está encima: el próximo tick levanta lo que esté a < 14 px.
      final p = s.players['p0']!;
      s = moveTo(e, s, 'p0', s.ground.first.x, s.ground.first.y);
      final step = e.tick(s, 0.05);
      expect(step.events.whereType<LootPickedEvent>(), isNotEmpty);
      expect(step.state.players['p0']!.profile.items.length +
              step.state.players['p0']!.profile.materials.length,
          greaterThan(before));
      expect(p.id, 'p0');
    });

    test('sin groundLoot: lo que el filtro oculta queda en el piso', () {
      final e = sessionEngine(fieldFallback: 0.0);
      // Nivel 30 en m1: zona 30, Común de nivel 30 → visible.
      var s = inField(e, 'm1', profiles: [_withItems('A')]);
      final p = s.players['p0']!;
      // Ocultar todo lo Común.
      s = act(e, s, 'p0', const SetLootFilterAction('Ocultar\n  Rareza Común\n'));
      s.ground.clear();
      expect(e.lootVerdict(s.players['p0']!.profile, _sword()).visible, isFalse);
      // Un drop oculto del piso no se levanta solo.
      s.ground.add(GroundLoot(id: 99, drop: _sword(), x: p.x, y: p.y, ownerId: 'p0'));
      s = e.tick(s, 0.05).state;
      expect(s.ground.where((g) => g.id == 99), hasLength(1));
      // PickUp manual sí.
      s = act(e, s, 'p0', const PickUpAction(99));
      expect(s.ground.where((g) => g.id == 99), isEmpty);
    });

    test('el piso se vacía al volver al lobby', () {
      final e = sessionEngine();
      final s = inField(e, 'm3');
      s.ground.add(GroundLoot(id: 1, drop: _sword(), x: 0, y: 0));
      s.mode = SessionMode.result;
      final back = act(e, s, 'p0', const BackToLobbyAction());
      expect(back.mode, SessionMode.lobby);
      expect(back.ground, isEmpty);
    });
  });
}
