import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_text.dart';
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
    this.onMenu,
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

  /// Menú de acciones (v0.9.9): clic derecho sobre la pila ([at] = el
  /// cursor) o `Enter` sobre la ya elegida ([at] = `null`).
  final void Function(String token, Offset? at)? onMenu;

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
        onSecondaryTapUp: onMenu == null || n == 0
            ? null
            : (d) => onMenu!(k.token, d.globalPosition),
        child: w,
      ),
    );
  }

  Widget _group(String title, String id, List<StackKind> kinds) => Column(
        key: ValueKey('inv-stacks-$id'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(retroText(title), style: DsText.subtitle()),
          SizedBox(height: gap),
          FocusGrid(
            count: kinds.length,
            columns: kinds.length,
            spacing: gap,
            keyPrefix: 'inv-stack-focus-$id-',
            cell: (_, i, __) => _cell(kinds[i]),
            onFocusCell: onSelect == null ? null : (i) => _pick(kinds[i]),
            onActivate: onSelect == null
                ? null
                : (i) => onMenu != null &&
                        selected == kinds[i].token &&
                        _count(kinds[i]) > 0
                    ? onMenu!(kinds[i].token, null)
                    : _pick(kinds[i]),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Wrap(
        key: const ValueKey('inv-stacks'),
        spacing: DsSpace.lg,
        runSpacing: DsSpace.xs,
        children: [
          if (consumables)
            _group('CONSUMIBLES', 'consumables', InventoryRules.consumables),
          if (materials)
            _group('MATERIALES', 'materials', [
              for (final k in InventoryRules.materials)
                if (!_abyss.contains(k)) k,
            ]),
          // Jefes del Abismo (v0.8): Fragmentos y Esencia, solo cuando
          // hay alguno (no ocupan lugar antes del endgame).
          if (materials && _abyss.any((k) => _count(k) > 0))
            _group('ABISMO', 'abyss', _abyss),
        ],
      );

  static const _abyss = [
    StackKind.fragReloj,
    StackKind.fragEco,
    StackKind.fragCorona,
    StackKind.fragEras,
    StackKind.esencia,
  ];
}
