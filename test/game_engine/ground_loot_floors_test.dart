import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// El loot del suelo queda en el piso donde cayó (loot.md § 14.1).
void main() {
  LootDrop sword(String uid) => LootDrop.item(ItemInstance(
      uid: uid, baseId: 'espada_ignea', rarity: Rarity.raro, itemLevel: 2));

  /// Usa la escalera ([down]) del piso actual y devuelve el paso.
  ({GameSession state, List<SessionEvent> events}) stairs(
      SessionEngine e, GameSession s, {required bool down}) {
    final m = s.mission!;
    final f = e.mapFor(s).floor(m.floor)!;
    final at = down ? f.stairsDown! : f.stairsUp!;
    m.opened.add(m.floor);
    s = moveTo(e, s, 'p0', at.x, at.y - 8);
    final step = e.apply(s, 'p0', UseStairsAction(down: down))!;
    return (state: step.state, events: step.events);
  }

  test('cae en el piso 1, bajan: el piso 2 no ve nada del 1, no se puede '
      'levantar, hay aviso y al volver sigue ahí', () {
    final e = sessionEngine(zones: true);
    var s = inField(e, 'm1');
    expect(s.mission!.floors, 2);
    final p = s.players['p0']!;
    // Una poción soltada (compartida) y un arma propia, en el piso 1.
    s = act(e, s, 'p0', const DropItemAction('pot'));
    s.ground.add(GroundLoot(
        id: 900, drop: sword('a'), x: p.x + 40, y: p.y, ownerId: 'p0'));
    expect(s.ground.map((g) => g.floor), [0, 0]);
    expect(s.groundFor('p0'), hasLength(2));

    final down = stairs(e, s, down: true);
    s = down.state;
    expect(s.mission!.floor, 1);
    // Nada del piso 1 en lo visible del piso 2 (lo que dibuja el cliente).
    expect(s.groundHere, isEmpty);
    expect(s.groundFor('p0'), isEmpty);
    // Sigue guardado en su piso.
    expect(s.ground.map((g) => g.floor), [0, 0]);
    // Aviso de lo que quedó atrás.
    final msgs =
        down.events.whereType<SystemMessageEvent>().map((m) => m.text).toList();
    expect(msgs.first, startsWith('Bajaron al piso 2/2.'));
    expect(msgs, contains('Quedan 2 objetos en el piso 1.'));

    // Levantar lo del otro piso: rechazado, aun parado en sus coordenadas.
    final stale = s.ground.firstWhere((g) => g.id == 900);
    s.players['p0']!
      ..x = stale.x
      ..y = stale.y;
    expect(e.apply(s, 'p0', const PickUpAction(900)), isNull);
    // Ni el auto-levantar.
    final t = e.tick(s, 0.05);
    expect(t.events.whereType<LootPickedEvent>(), isEmpty);
    s = t.state;
    expect(s.ground.where((g) => g.id == 900), hasLength(1));

    // Lo que cae en el piso 2 es del piso 2.
    s = act(e, s, 'p0', const DropItemAction('eter'));
    final here = s.groundHere.single;
    expect(here.floor, 1);

    // Al subir vuelve a verse lo del piso 1 (y no lo del 2).
    final up = stairs(e, s, down: false);
    s = up.state;
    expect(s.mission!.floor, 0);
    expect(s.groundFor('p0').map((g) => g.floor), everyElement(0));
    expect(s.groundFor('p0'), hasLength(2));
    expect(
        up.events
            .whereType<SystemMessageEvent>()
            .map((m) => m.text)
            .where((x) => x.startsWith('Queda')),
        ['Queda 1 objeto en el piso 2.']);
    final mine = s.ground.firstWhere((g) => g.id == 900);
    s = moveTo(e, s, 'p0', mine.x, mine.y);
    s = act(e, s, 'p0', const PickUpAction(900));
    expect(s.ground.where((g) => g.id == 900), isEmpty);
  });

  test('sin loot pendiente no hay aviso; lo oculto por el filtro no cuenta',
      () {
    final e = sessionEngine(zones: true);
    var s = inField(e, 'm1');
    s = act(e, s, 'p0', const SetLootFilterAction('Ocultar\n  Rareza Raro\n'));
    final p = s.players['p0']!;
    s.ground.add(GroundLoot(
        id: 901, drop: sword('b'), x: p.x + 40, y: p.y, ownerId: 'p0'));
    // De otro jugador: no lo ve, no cuenta.
    s.ground.add(GroundLoot(
        id: 902, drop: sword('c'), x: p.x + 40, y: p.y, ownerId: 'otro'));
    final down = stairs(e, s, down: true);
    expect(
        down.events
            .whereType<SystemMessageEvent>()
            .where((m) => m.text.startsWith('Queda')),
        isEmpty);
  });

  test('serialización: el piso de cada objeto viaja (y falta = 0)', () {
    const json = SessionJson();
    final s = GameSession(ground: [
      GroundLoot(id: 1, drop: sword('x'), x: 1, y: 2, ownerId: 'p0'),
      const GroundLoot(
          id: 2, drop: LootDrop.stack(StackKind.potion, 1), x: 3, y: 4, floor: 2),
    ], groundSeq: 2);
    final raw = json.toJson(s);
    final grounds = (raw['ground']! as List).cast<Map<String, Object?>>();
    expect(grounds[0].containsKey('f'), isFalse, reason: 'piso 0: se omite');
    expect(grounds[1]['f'], 2);
    final back = json.fromJson(asJson(jsonDecode(jsonEncode(raw))));
    expect(back.ground.map((g) => g.floor), [0, 2]);
    expect(jsonEncode(json.toJson(back)), jsonEncode(raw));
    // Sin misión el piso actual es el 0: solo se ve el primero.
    expect(back.groundFor('p0').map((g) => g.id), [1]);
  });
}
