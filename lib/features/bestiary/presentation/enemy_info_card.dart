import 'package:material_ui/material_ui.dart';

import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/bestiary.dart';
import '../domain/bestiary_text.dart';

/// Ficha flotante de un enemigo al pasar el mouse en la batalla
/// (docs/specs/bestiary.md § 3): con la caja del `#tip`. Si todavía no
/// se lo mató, "???" y "Derrotalo para agregarlo al bestiario".
class EnemyInfoCard extends StatelessWidget {
  const EnemyInfoCard({
    super.key,
    required this.enemy,
    required this.bestiary,
    this.level,
  });

  final Combatant enemy;
  final BestiaryProgress bestiary;
  final int? level;

  /// El markup que muestra (tests).
  static String markupFor(Combatant enemy, BestiaryProgress bestiary,
      {int? level}) {
    final def = kEnemies[enemy.enemyType];
    if (def == null) return protoEsc(enemy.name);
    return enemyInfoMarkup(def, bestiary, level: level, elite: enemy.elite);
  }

  @override
  Widget build(BuildContext context) {
    final known = bestiary.knows(enemy.enemyType);
    return Container(
      key: ValueKey(known ? 'enemy-info-known' : 'enemy-info-unknown'),
      padding: RetroHoverCard.padding,
      constraints: BoxConstraints(
          maxWidth: RetroType.width(context, RetroHoverCard.textWidth) +
              RetroHoverCard.padding.horizontal),
      decoration: BoxDecoration(
        color: ProtoColors.bg.withValues(alpha: 0xF5 / 0xFF),
        border: Border.all(
            color: ProtoColors.gold, width: RetroTheme.thinBorderWidth),
        boxShadow: const [
          BoxShadow(
              color: Color(0xAA000000), offset: Offset(0, 4), blurRadius: 18),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: RetroHoverCard.textStyle,
        child: ProtoText(markupFor(enemy, bestiary, level: level)),
      ),
    );
  }
}

/// Pone [child] junto al puntero [at] sin salirse del área: a la derecha
/// y abajo; si no entra, del otro lado.
class PointerCardLayout extends SingleChildLayoutDelegate {
  PointerCardLayout(this.at, {this.gap = 14, this.margin = 4});

  final Offset at;
  final double gap;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(
          (constraints.maxWidth - 2 * margin).clamp(0, double.infinity),
          (constraints.maxHeight - 2 * margin).clamp(0, double.infinity)));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = at.dx + gap;
    if (x + childSize.width > size.width - margin) {
      x = at.dx - gap - childSize.width;
    }
    var y = at.dy + gap;
    if (y + childSize.height > size.height - margin) {
      y = size.height - margin - childSize.height;
    }
    final maxX = size.width - margin - childSize.width;
    return Offset(x.clamp(margin, maxX < margin ? margin : maxX),
        y < margin ? margin : y);
  }

  @override
  bool shouldRelayout(PointerCardLayout old) => old.at != at;
}
