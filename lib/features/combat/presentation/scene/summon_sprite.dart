import 'dart:math' as math;
import 'dart:ui';

import '../../../../app/theme/proto_colors.dart';
import '../../../../game_engine/data/summoner_catalog.dart';
import '../../../../game_engine/models/battle_state.dart';
import '../../../../game_engine/rules/summon_rules.dart';

// Invocaciones en la escena (docs/specs/summoner.md § 8): sprites
// procedurales chicos (elemental, Gólem, Espíritu) teñidos con el color
// de su elemento, con barra de vida y turnos que le quedan. Sin arte
// nuevo: el dueño los reemplaza por sprites del manifiesto cuando haya.

/// Tipo de una invocación (`Combatant.summonKind`).
SummonKind? summonKindOf(Combatant c) =>
    SummonKind.values.asNameMap()[c.summonKind];

/// Color de cada invocación (tokens de la paleta).
Color summonColor(SummonKind k) => switch (k) {
      SummonKind.fuego => ProtoColors.burn,
      SummonKind.agua => ProtoColors.sky,
      SummonKind.electro => ProtoColors.amber,
      SummonKind.hielo => ProtoColors.ice,
      SummonKind.golem => ProtoColors.common,
      SummonKind.espiritu => ProtoColors.holy,
    };

/// Texto de los turnos que le quedan (`∞` con Pacto Eterno).
String summonTurnsText(Combatant c) =>
    c.summonTurns >= kSummonForever ? '∞' : '${c.summonTurns}';

/// Dibuja [s] con los pies en [pos] (px del mundo). [t]: reloj en ms.
/// [text] dibuja un texto centrado (la pluma de la escena).
void paintSummon(Canvas c, Combatant s, Offset pos, double t,
    void Function(String text, double x, double y, Color color, double size)
        text) {
  final k = summonKindOf(s);
  if (k == null) return;
  final col = summonColor(k);
  final dark = Color.lerp(col, ProtoColors.shadow, 0.45)!;
  final light = Color.lerp(col, ProtoColors.white, 0.45)!;
  final p = Paint();
  void px(double x, double y, double w, double h, Color color) {
    p.color = color;
    c.drawRect(Rect.fromLTWH(pos.dx + x, pos.dy + y, w, h), p);
  }

  final bob = (math.sin(t / 260 + pos.dx) * 1.2).roundToDouble();
  // Sombra.
  px(-5, -1, 10, 2, ProtoColors.shadow);
  switch (k) {
    case SummonKind.golem:
      px(-5, -12, 10, 11, dark);
      px(-4, -11, 8, 9, col);
      px(-6, -9, 2, 5, dark);
      px(4, -9, 2, 5, dark);
      px(-2, -9, 1, 1, ProtoColors.gold);
      px(1, -9, 1, 1, ProtoColors.gold);
    case SummonKind.espiritu:
      final y = -13 + bob;
      px(-3, y, 6, 6, light);
      px(-4, y + 1, 8, 4, col);
      px(-2, y + 6, 4, 2, col);
      px(-1, y + 8, 2, 2, light);
      px(-2, y + 2, 1, 1, ProtoColors.shadow);
      px(1, y + 2, 1, 1, ProtoColors.shadow);
    default:
      // Elemental: una llama / gota que titila.
      final y = -12 + bob;
      final flick = ((t / 120).floor() % 2) == 0 ? 0.0 : 1.0;
      px(-1, y - 2 - flick, 2, 2, light);
      px(-3, y, 6, 3, col);
      px(-4, y + 3, 8, 5, col);
      px(-3, y + 8, 6, 2, dark);
      px(-2, y + 4, 1, 2, ProtoColors.shadow);
      px(1, y + 4, 1, 2, ProtoColors.shadow);
      px(-2, y + 1, 4, 1, light);
  }
  // Barra de vida y turnos.
  final frac = (s.hp / math.max(1, s.maxHp)).clamp(0.0, 1.0);
  px(-6, -18, 12, 2, ProtoColors.barBg);
  px(-6, -18, (12 * frac).roundToDouble(), 2, ProtoColors.hp);
  text(summonTurnsText(s), pos.dx + 8, pos.dy - 20, col, 5);
}
