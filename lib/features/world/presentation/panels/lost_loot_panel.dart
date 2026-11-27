import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/proto_markup.dart';
import '../../../../game_engine/models/attributes.dart';
import '../../../../game_engine/models/loot.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/progression_rules.dart';
import '../../../inventory/domain/item_text.dart';
import '../../../inventory/presentation/item_grid.dart';
import '../../../inventory/presentation/item_hover_tip.dart';
import '../../../inventory/presentation/item_widgets.dart' hide PixelIcon;
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';

/// Aviso fijo del panel (missions.md § "Loot perdido"), en es-AR; el
/// que se muestra es `ui.world.lost_loot.notice`.
const kLostLootNotice = 'Se borra al empezar la próxima misión.';

/// The INVENTARIO cell content of a mission drop (item, Eco or stack).
CellContent dropCellContent(LootDrop d) => d.item != null
    ? CellContent.item(d.item!)
    : d.eco != null
        ? CellContent.eco(d.eco!)
        : CellContent.stack(d.stack!, d.count);

/// Panel LOOT PERDIDO de la torrecita del pueblo: lo que quedó en el piso
/// al volver de la misión, compartido por toda la sala. Grilla de
/// casillas como INVENTARIO ([DsItemGrid], ficha del mouse de siempre) y
/// a la derecha el detalle de la elegida con TOMAR; TOMAR TODO abajo
/// (lo valida el anfitrión). Ver missions.md § "Loot perdido".
class LostLootPanel extends StatefulWidget {
  const LostLootPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<LostLootPanel> createState() => _LostLootPanelState();
}

class _LostLootPanelState extends State<LostLootPanel> {
  /// Id del [GroundLoot] elegido.
  int? _sel;

  static CellContent _content(LootDrop d) => dropCellContent(d);

  String _markup(ProgressionRules rules, LootDrop d, PlayerProfile? viewer,
      PlayerAttributes attrs) {
    if (d.item case final it?) {
      return itemTooltipMarkup(rules, it,
          skillDetails: true, level: viewer?.level ?? 1, attributes: attrs);
    }
    if (d.eco case final e?) {
      return ecoTooltipMarkup(rules, e,
          atlas: widget.controller.engine.atlasOf(widget.view.session),
          players: widget.view.session.players.length);
    }
    return stackTooltipMarkup(d.stack!, d.count);
  }

  void _takeAll(List<GroundLoot> pool) {
    for (final id in [for (final g in pool) g.id]) {
      widget.controller.takeLostLoot(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view, controller = widget.controller;
    final pool = view.session.lostLoot;
    final rules = controller.engine.progression;
    final viewer = view.me?.profile;
    final attrs = viewer?.attributes ?? const PlayerAttributes({});
    final sel = pool.where((g) => g.id == _sel).firstOrNull ??
        pool.firstOrNull;

    Widget tip(int i, Widget child, bool focused) {
      final d = pool[i].drop;
      if (d.item case final it? when viewer != null) {
        return itemHoverTip(
            rules: rules,
            viewer: viewer,
            item: it,
            attributes: attrs,
            focused: focused,
            child: child);
      }
      return RetroTooltip(
          message: _markup(rules, d, viewer, attrs),
          keyboardFocus: focused,
          child: child);
    }

    Widget cell(BuildContext context, int i, double size) {
      final g = pool[i];
      return tip(
          i,
          GestureDetector(
            key: ValueKey('lost-cell-${g.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _sel = g.id),
            onDoubleTap: () => controller.takeLostLoot(g.id),
            child: ItemSlot(
                rules: rules,
                size: size,
                data: ItemSlotData(
                    content: _content(g.drop), selected: g == sel)),
          ),
          false);
    }

    final detail = sel == null
        ? const SizedBox.shrink()
        : DsDetailPane(
            key: const ValueKey('lost-detail'),
            body: ProtoText(_markup(rules, sel.drop, viewer, attrs)),
            actions: DsButton(context.t('ui.world.lost_loot.take'),
                key: ValueKey('lost-take-${sel.id}'),
                kind: DsButtonKind.primary,
                onPressed: () => controller.takeLostLoot(sel.id)),
          );

    return PanelFrame(
      key: const ValueKey('panel-lost-loot'),
      title: context.t('ui.world.lost_loot.title'),
      width: 1000,
      fill: true,
      onClose: controller.closePanel,
      actions: [
        PanelButton(context.t('ui.world.lost_loot.take_all'),
            key: const ValueKey('lost-take-all'),
            onPressed: pool.isEmpty ? null : () => _takeAll(pool)),
        PanelButton(context.t('ui.world.lost_loot.close'),
            key: const ValueKey('lost-close'), onPressed: controller.closePanel),
      ],
      // INVENTARIO grid (design_system.md § DsGridDetailLayout): 6 cells
      // top-left, the detail with TOMAR takes the rest of the width.
      child: DsGridDetailLayout(
        keyPrefix: 'lost',
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(context.t('ui.world.lost_loot.header'),
                  style: DsText.subtitle()),
              SizedBox(width: DsSpace.sm),
              DsBadge(pool.length.toString(),
                  key: const ValueKey('lost-count')),
            ]),
            SizedBox(height: DsSpace.xs),
            Text(context.t('ui.world.lost_loot.notice'),
                key: const ValueKey('lost-notice'), style: DsText.detail()),
          ],
        ),
        count: pool.length,
        empty: Text(context.t('ui.world.lost_loot.empty'),
            key: const ValueKey('lost-empty'), style: DsText.detail()),
        cell: cell,
        detail: pool.isEmpty ? null : detail,
      ),
    );
  }
}
