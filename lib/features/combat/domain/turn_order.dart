import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/passive_mechanic.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/battle_engine.dart';

/// `IVa`: tiempo entre turnos con la congelación y los efectos de
/// velocidad aplicados (el mismo cálculo que `BattleEngine.interval`).
double turnInterval(Combatant a) =>
    100 /
    (a.speed *
        (1 + a.effectTotal(BuffStat.speed)) *
        (1 - BattleEngine.freezeSlowPerStack * a.stacks(StatusKind.freeze)));

/// Invocación sin turno (cristales de la Sierpe).
bool isPassiveAdd(Combatant c) =>
    !c.isPlayer && (kEnemies[c.enemyType]?.passive ?? false);

/// Cuántos turnos mirar para el `T+n` de cada tarjeta: 10 (el prototipo)
/// o más con un grupo grande, así todos los vivos aparecen (v0.13).
int turnWindow(BattleState state) {
  final n = state.party.length + state.enemies.length + 2;
  return n > 10 ? n : 10;
}

/// `predictTurns(v, n)` del prototipo: los ids de los próximos [n] turnos
/// según el timeline actual. Ver docs/specs/battle_presentation.md
/// § "predictTurns". Puro: no modifica [state].
List<String> predictTurns(BattleState state, int n) {
  final actors = <_Slot>[
    for (final p in state.party)
      if (p.alive) _Slot(p.id, p.nextTurn, turnInterval(p)),
    for (final e in state.enemies)
      if (e.alive && !isPassiveAdd(e))
        _Slot(e.id, e.nextTurn, turnInterval(e)),
  ];
  final out = <String>[];
  if (actors.isEmpty) return out;
  final curId = state.currentId;
  if (curId != null) {
    for (final c in actors) {
      if (c.id == curId) {
        out.add(c.id);
        c.nt = (c.nt > state.clock ? c.nt : state.clock) + c.iv;
        break;
      }
    }
  }
  while (out.length < n) {
    var m = actors.first;
    for (final x in actors) {
      if (x.nt < m.nt) m = x;
    }
    out.add(m.id);
    m.nt += m.iv;
  }
  return out;
}

class _Slot {
  _Slot(this.id, this.nt, this.iv);
  final String id;
  double nt;
  final double iv;
}
