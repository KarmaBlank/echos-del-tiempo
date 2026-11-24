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

/// Casillas por fila de la grilla del Loot perdido.
const kLostLootColumns = 8;

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

  static CellContent _content(LootDrop d) => d.item != null
      ? CellContent.item(d.item!)
      : d.eco != null
          ? CellContent.eco(d.eco!)
          : CellContent.stack(d.stack!, d.count);

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

    final grid = DsItemGrid(
      rules: rules,
      count: pool.length,
      columns: kLostLootColumns,
      width: kLostLootColumns * 48.0,
      focusKeyPrefix: 'lost-focus-',
      cellKey: (i) => ValueKey('lost-cell-${pool[i].id}'),
      slot: (i) => ItemSlotData(
          content: _content(pool[i].drop), selected: pool[i] == sel),
      tip: tip,
      onTap: (i) => setState(() => _sel = pool[i].id),
      onFocusCell: (i) => setState(() => _sel = pool[i].id),
      onActivate: (i) => controller.takeLostLoot(pool[i].id),
    );

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
      width: 720,
      fill: true,
      onClose: controller.closePanel,
      actions: [
        PanelButton(context.t('ui.world.lost_loot.take_all'),
            key: const ValueKey('lost-take-all'),
            onPressed: pool.isEmpty ? null : () => _takeAll(pool)),
        PanelButton(context.t('ui.world.lost_loot.close'),
            key: const ValueKey('lost-close'), onPressed: controller.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(context.t('ui.world.lost_loot.header'), style: DsText.subtitle()),
            const SizedBox(width: 8),
            DsBadge(pool.length.toString(), key: const ValueKey('lost-count')),
          ]),
          const SizedBox(height: 4),
          Text(context.t('ui.world.lost_loot.notice'),
              key: const ValueKey('lost-notice'), style: DsText.detail()),
          const SizedBox(height: 6),
          if (pool.isEmpty)
            Text(context.t('ui.world.lost_loot.empty'),
                key: const ValueKey('lost-empty'), style: DsText.detail())
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(child: grid),
                  SizedBox(width: DsSpace.md),
                  Expanded(child: detail),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
