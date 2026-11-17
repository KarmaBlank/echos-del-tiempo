import 'package:echos_del_tiempo/features/combat/presentation/battle_hud.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chips del árbol v2: buffs, marca, escudo, aturdido +1 y Último Aliento',
      () {
    final c = Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      hp: 20,
      maxHp: 100,
      speed: 10,
      attack: 20,
      critChance: 0,
      mechanics: {'ultimoAliento'},
      effects: const [
        TimedEffect(
            sourceId: 'frenesi', stat: BuffStat.speed, value: 0.2, turns: 2),
        TimedEffect(
            sourceId: 'debilitar',
            stat: BuffStat.attack,
            value: -0.15,
            turns: 1),
        TimedEffect(
            sourceId: 'marcaCazador',
            stat: BuffStat.damageTaken,
            value: 0.15,
            turns: 3),
        TimedEffect(
            sourceId: 'manoSanadora',
            stat: BuffStat.shield,
            value: 7,
            turns: 3),
        TimedEffect(
            sourceId: 'martilloBendito',
            stat: BuffStat.stunLock,
            value: 1,
            turns: 1),
      ],
    );
    final chips = combatantChips(c);
    expect(chips.map((x) => x.long).toList(), [
      '▲VEL +20%',
      '▼ATQ −15%',
      'Marca +15%',
      'Escudo 7',
      'Aturdido +1',
      'Último Aliento',
    ]);
    expect(chips.first.tip, contains('Frenesí · 2 turnos'));
    expect(chips[1].tip, contains('Debilitar · 1 turno'));
    expect(chips[3].tip, contains('Mano Sanadora'));

    c.hp = 80;
    expect(combatantChips(c).map((x) => x.long),
        isNot(contains('Último Aliento')));
  });
}
