import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';

/// Espera la gracia del campo y pone al jugador encima del primer grupo
/// normal: el host arranca la batalla en el siguiente tick.
void startBattleWithFirstGroup(SessionController c) {
  final s = c.session!;
  final graceLeft = s.graceLeft;
  if (graceLeft > 0) c.advance(graceLeft + 0.1);
  final en = c.session!.mission!.enemies
      .firstWhere((e) => e.alive && !e.boss && !e.elite);
  c.teleport(en.x, en.y);
  c.advance(0.05);
}

/// Avanza hasta que le toque al jugador local (o termine la batalla).
void waitForMyTurn(SessionController c, {int maxTicks = 2000}) {
  for (var i = 0;
      i < maxTicks &&
          c.view!.mode == SessionMode.battle &&
          !c.view!.myTurn;
      i++) {
    c.advance(0.05);
  }
}

/// Juega solo hasta el resultado: ataca en cada turno, reparte puntos en
/// VIT al subir de nivel y, en el campo, va directo al jefe.
void playUntilResult(SessionController c, {int maxTicks = 40000}) {
  for (var i = 0; i < maxTicks && c.view!.mode != SessionMode.result; i++) {
    final v = c.view!;
    switch (v.mode) {
      case SessionMode.battle when v.myTurn:
        c.battleCommand(const AttackCommand());
      case SessionMode.levelUp when v.mustAllocate:
        c.allocate({Attribute.vit: v.me!.profile.points});
      case SessionMode.field when v.session.graceLeft <= 0:
        final boss = v.session.mission!.enemies.firstWhere((e) => e.boss);
        c.teleport(boss.x, boss.y);
      default:
        break;
    }
    c.advance(0.05);
  }
}
