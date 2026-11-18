import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_type.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/inventory_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../domain/item_text.dart';
import 'item_widgets.dart' show CellContent, ItemCell;

/// Secciones fijas de pilas del inventario (v0.5.1, loot.md § 17.1,
/// panels.md § "Inventario"): `CONSUMIBLES` (poción de vida y de maná) y
/// `MATERIALES` (Esquirla, Cristal, Prisma, Ancla). No ocupan casilla de
/// la grilla: cada pila tiene su lugar aunque esté en 0 (atenuada, no se
/// elige). Clic o el cursor con las flechas la eligen ([onSelect]);
/// `Enter` / `Espacio` también. Sin [onSelect]: solo se ven (inventario
/// de un compañero o vista previa).
class InventoryStacksBar extends StatelessWidget {
  const InventoryStacksBar({
    super.key,
    required this.rules,
    required this.profile,
    this.selected,
    this.onSelect,
    this.consumables = true,
    this.materials = true,
    this.cell = 44,
    this.gap = 4,
  });

  final ProgressionRules rules;
  final PlayerProfile profile;

  /// Token elegido (`pot`, `mat:cristal`...), para el borde dorado.
  final String? selected;
  final ValueChanged<String>? onSelect;

  /// Qué secciones se muestran (el alijo solo usa MATERIALES).
  final bool consumables;
  final bool materials;
  final double cell;
  final double gap;

  int _count(StackKind k) => InventoryRules.stackCount(profile, k);

  void _pick(StackKind k) {
    if (_count(k) > 0) onSelect?.call(k.token);
  }

  Widget _cell(StackKind k) {
    final n = _count(k);
    Widget w = ItemCell(
      rules: rules,
      size: cell,
      content: CellContent.stack(k, n),
      selected: selected == k.token && n > 0,
    );
    if (n == 0) w = Opacity(opacity: 0.4, child: w);
    w = RetroTooltip(message: stackTooltipMarkup(k, n), child: w);
    return KeyedSubtree(
      key: ValueKey('inv-stack-${k.token}'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect == null ? null : () => _pick(k),
        child: w,
      ),
    );
  }

  Widget _group(String title, String id, List<StackKind> kinds) => Column(
        key: ValueKey('inv-stacks-$id'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(retroText(title),
              style: const TextStyle(
                  color: ProtoColors.gold, fontSize: RetroType.small)),
          SizedBox(height: gap),
          FocusGrid(
            count: kinds.length,
            columns: kinds.length,
            spacing: gap,
            keyPrefix: 'inv-stack-focus-$id-',
            cell: (_, i, __) => _cell(kinds[i]),
            onFocusCell: onSelect == null ? null : (i) => _pick(kinds[i]),
            onActivate: onSelect == null ? null : (i) => _pick(kinds[i]),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Wrap(
        key: const ValueKey('inv-stacks'),
        spacing: 20,
        runSpacing: 6,
        children: [
          if (consumables)
            _group('CONSUMIBLES', 'consumables', InventoryRules.consumables),
          if (materials)
            _group('MATERIALES', 'materials', InventoryRules.materials),
        ],
      );
}
