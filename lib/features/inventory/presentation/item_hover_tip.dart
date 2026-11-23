import 'package:material_ui/material_ui.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/retro_type.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../domain/item_text.dart';
import 'weapon_compare_view.dart';

/// Ayuda al pie de la ficha del mouse (ui_style.md § "Tooltips cortos").
const itemTipHint = 'Alt: detalle · Shift: comparar · clic: fijar';

/// Ficha del mouse de un arma, la MISMA en el inventario y en el alijo
/// (ui_style.md § "Tooltips cortos"; characters.md § 3): la que usás
/// [viewer] va con resumen + secciones plegables; cualquier otra, una
/// columna angosta [HoverCompareCard] (Shift: la equipada) + [footer].
/// Atravesable, Alt detalle, clic fija. [note] (markup) se agrega al
/// resumen de la equipada y, si no hay [footer], va de pie en la otra.
Widget itemHoverTip({
  required ProgressionRules rules,
  required PlayerProfile viewer,
  required ItemInstance item,
  required PlayerAttributes attributes,
  required Widget child,
  String? ownerName,
  bool equipped = false,
  bool focused = false,
  String? note,
  String summaryExtra = '',
  Widget? footer,
}) {
  final using = rules.equippedItem(viewer)?.uid;
  if (ownerName == null && item.uid == using) {
    final parts = itemTipParts(rules, item,
        level: viewer.level, attributes: attributes, equipped: equipped);
    return RetroHoverCard(
      placement: RetroTipPlacement.below,
      gap: 4,
      interactive: true,
      pinOnClick: true,
      hint: itemTipHint,
      keyboardFocus: focused,
      builder: (ctx) => RetroTipFolds(
          key: const ValueKey('inv-tip-folds'),
          summary:
              parts.summary + summaryExtra + (note == null ? '' : '<br>$note'),
          // En RESUMIDO trae su MÁS DETALLE (ui_minimal.md § 8.4).
          sections: parts.sections,
          maxWidth: RetroType.width(ctx, RetroHoverCard.textWidth)),
      child: child,
    );
  }
  final foot = footer ??
      (note == null
          ? null
          : Container(
              key: const ValueKey('item-tip-note'),
              padding: const EdgeInsets.all(6),
              color: ProtoColors.bg,
              child: ProtoText(note),
            ));
  final card = HoverCompareCard(
      rules: rules,
      viewer: viewer,
      item: item,
      attributes: attributes,
      ownerName: ownerName,
      footer: foot);
  return RetroHoverCard(
    interactive: true,
    pinOnClick: true,
    hint: itemTipHint,
    keyboardFocus: focused,
    builder: (_) => card,
    child: child,
  );
}
