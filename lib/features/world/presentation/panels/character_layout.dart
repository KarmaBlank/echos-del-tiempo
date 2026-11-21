import '../../../../core/layout/layout_doc.dart';
import '../../../../core/layout/layout_spec.dart';

/// PERSONAJE como datos (docs/specs/editor_layout.md § 6, fase 5).
/// Regiones del template: `toolbar` (barra de arriba del contenido; hoy
/// solo con ATRIBUTOS) y `actions` (pie del marco, a la derecha). El
/// título, la fila de pestañas y el contenido de cada pestaña son del
/// template (fijos).
abstract final class CharacterLayout {
  static const screen = 'character';

  static const points = 'char.points';
  static const attrActions = 'char.attr_actions';
  static const respec = 'char.attr_actions.respec';
  static const undo = 'char.attr_actions.undo';
  static const confirm = 'char.attr_actions.confirm';
  static const reason = 'char.attr_reason';
  static const close = 'char.close';

  static const _all = {'toolbar', 'actions'};

  static final spec = LayoutScreenSpec(
    screen: screen,
    title: 'PERSONAJE',
    regions: const [
      LayoutRegionSpec('toolbar',
          axis: LayoutAxis.wrap, label: 'Barra (ATRIBUTOS)', spacing: 'sm'),
      LayoutRegionSpec('actions',
          axis: LayoutAxis.wrap,
          label: 'Pie del marco',
          spacing: '8',
          runSpacing: '8',
          align: LayoutAlign.end),
    ],
    slots: const [
      LayoutSlotSpec(points, label: 'Puntos libres', allowedRegions: _all),
      LayoutSlotSpec(attrActions,
          label: 'REINICIAR / DESHACER / CONFIRMAR',
          group: true,
          interactive: true,
          lead: 'md',
          allowedRegions: _all),
      LayoutSlotSpec(respec,
          label: 'REINICIAR PUNTOS',
          interactive: true,
          allowedRegions: {..._all, attrActions}),
      LayoutSlotSpec(undo,
          label: 'DESHACER',
          interactive: true,
          allowedRegions: {..._all, attrActions}),
      LayoutSlotSpec(confirm,
          label: 'CONFIRMAR PUNTOS',
          interactive: true,
          allowedRegions: {..._all, attrActions}),
      LayoutSlotSpec(reason,
          label: 'Motivo de CONFIRMAR', allowedRegions: _all),
      LayoutSlotSpec(close,
          label: 'CERRAR / VOLVER', interactive: true, allowedRegions: _all),
    ],
    defaults: LayoutDoc(screen: screen, slots: const [
      SlotPlacement(points, 'toolbar', 0),
      SlotPlacement(attrActions, 'toolbar', 1),
      SlotPlacement(respec, attrActions, 0),
      SlotPlacement(undo, attrActions, 1),
      SlotPlacement(confirm, attrActions, 2),
      SlotPlacement(reason, 'toolbar', 2),
      SlotPlacement(close, 'actions', 0),
    ]),
  );
}
