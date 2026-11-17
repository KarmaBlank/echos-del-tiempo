import 'package:echos_del_tiempo/features/combat/domain/turn_order.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter_test/flutter_test.dart';

Combatant _c(String id, bool player, double speed, double nt,
        {int hp = 10, int freeze = 0}) =>
    Combatant(
      id: id,
      name: id,
      isPlayer: player,
      hp: hp,
      maxHp: 10,
      speed: speed,
      attack: 1,
      critChance: 0,
      nextTurn: nt,
      statuses: {if (freeze > 0) StatusKind.freeze: freeze},
    );

/// Estado conocido: IV p1 = 10, p2 = 20, e0 = 12.5, e1 = 100/8.8
/// (congelación 1), e2 caído. Resultado calculado a mano con el
/// `predictTurns` del prototipo.
BattleState _state({String? current, double clock = 0}) => BattleState(
      party: [_c('p1', true, 10, 5), _c('p2', true, 5, 12)],
      enemies: [
        _c('e0', false, 8, 6),
        _c('e1', false, 10, 5, freeze: 1),
        _c('e2', false, 20, 0, hp: 0),
      ],
      currentId: current,
      clock: clock,
    );

void main() {
  test('sin turno en curso: el menor nt, empate → jugadores primero', () {
    expect(predictTurns(_state(), 10),
        ['p1', 'e1', 'e0', 'p2', 'p1', 'e1', 'e0', 'p1', 'e1', 'e0']);
  });

  test('con turno en curso: va primero y avanza desde max(nt, reloj)', () {
    expect(predictTurns(_state(current: 'e0', clock: 6), 10),
        ['e0', 'p1', 'e1', 'p2', 'p1', 'e1', 'e0', 'p1', 'e1', 'e0']);
  });

  test('no modifica el estado y respeta n', () {
    final s = _state();
    expect(predictTurns(s, 3), hasLength(3));
    expect(s.party.first.nextTurn, 5);
    expect(turnInterval(s.enemies[1]), closeTo(100 / 8.8, 1e-9));
  });
}
