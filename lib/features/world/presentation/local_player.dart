import '../../../game_engine/models/game_map.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/rules/world_rules.dart';

/// El jugador local tal como lo mueve este dispositivo (`me` del
/// prototipo). Se mueve sin esperar al host y cada tanto le manda su
/// posición; cuando el host lo teletransporta (sube la época) adopta la
/// posición del snapshot. Ver docs/specs/exploration.md § "Jugador local".
class LocalPlayer {
  double x = 0;
  double y = 0;
  int dir = 1;

  /// Hacia dónde mira en cuatro direcciones (la última tecla): para
  /// pescar mirando al agua (fishing.md § 4).
  int fx = 1, fy = 0;
  bool moving = false;

  /// Época de posición adoptada (`me.ep`); -1 = todavía ninguna.
  int epoch = -1;

  /// Adopta la posición del snapshot si cambió la época.
  void sync(SessionPlayer sp) {
    if (sp.epoch != epoch) {
      x = sp.x;
      y = sp.y;
      epoch = sp.epoch;
    }
  }

  /// `updateMe`: un paso con la entrada [ix], [iy] (-1..1). Si [canMove]
  /// es falso (panel abierto, caído, fuera de lobby/campo) solo frena.
  void step(GameMap map, double ix, double iy, double dt,
      {required bool canMove, required bool gateOpen, double speedMult = 1}) {
    if (!canMove) {
      moving = false;
      return;
    }
    moving = ix != 0 || iy != 0;
    if (!moving) return;
    final p = WorldRules.stepPlayer(map, x, y, ix, iy, dt,
        gateOpen: gateOpen, speedMult: speedMult);
    x = p.x;
    y = p.y;
    if (ix != 0) dir = ix > 0 ? 1 : -1;
    if (ix.abs() >= iy.abs()) {
      fx = ix > 0 ? 1 : -1;
      fy = 0;
    } else {
      fx = 0;
      fy = iy > 0 ? 1 : -1;
    }
  }
}
