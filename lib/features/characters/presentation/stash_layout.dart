import '../../../core/layout/layout_doc.dart';
import '../../../core/layout/layout_spec.dart';

/// Layout del ALIJO como datos (docs/specs/editor_layout.md § 4, piloto).
/// Regiones del template: `header` (arriba, todo el ancho), `left` (lado
/// del personaje), `right` (lado del alijo), `footer` (pie). La lógica
/// de lado a lado / apilado y la escala de las casillas
/// (`stashLayout`) siguen en el código del template.
abstract final class StashLayout {
  static const screen = 'stash';

  static const title = 'stash.title';
  static const equipped = 'stash.equipped';
  static const inventoryLabel = 'stash.inventory_label';
  static const searchChar = 'stash.search_char';
  static const inventoryGrid = 'stash.inventory_grid';
  static const stacks = 'stash.stacks';
  static const stashHeader = 'stash.stash_header';
  static const stashTabs = 'stash.stash_tabs';
  static const searchStash = 'stash.search_stash';
  static const stashGrid = 'stash.stash_grid';
  static const ecoNote = 'stash.eco_note';
  static const actions = 'stash.actions';
  static const transfer = 'stash.actions.transfer';
  static const moveAll = 'stash.actions.move_all';
  static const pick = 'stash.actions.pick';
  static const status = 'stash.status';

  static const _main = {'header', 'left', 'right', 'footer'};

  static final spec = LayoutScreenSpec(
    screen: screen,
    title: 'ALIJO',
    regions: const [
      LayoutRegionSpec('header', axis: LayoutAxis.wrap, label: 'Encabezado'),
      LayoutRegionSpec('left', label: 'Lado del personaje'),
      LayoutRegionSpec('right', label: 'Lado del alijo'),
      LayoutRegionSpec('footer', label: 'Pie'),
    ],
    slots: const [
      LayoutSlotSpec(title,
          label: 'Nombre del personaje', hideable: true, allowedRegions: _main),
      LayoutSlotSpec(equipped,
          label: 'Equipada y créditos', interactive: true, allowedRegions: _main),
      LayoutSlotSpec(inventoryLabel,
          label: 'Rótulo INVENTARIO', hideable: true, allowedRegions: _main),
      LayoutSlotSpec(searchChar,
          label: 'Buscador del inventario',
          interactive: true,
          gap: 'xs',
          allowedRegions: _main),
      LayoutSlotSpec(inventoryGrid,
          label: 'Grilla del inventario', movable: false),
      LayoutSlotSpec(stacks,
          label: 'Consumibles y materiales',
          interactive: true,
          allowedRegions: _main),
      LayoutSlotSpec(stashHeader,
          label: 'Rótulo ALIJO y ocupación', allowedRegions: _main),
      LayoutSlotSpec(stashTabs,
          label: 'Pestañas del alijo',
          interactive: true,
          gap: 'xs',
          allowedRegions: _main),
      LayoutSlotSpec(searchStash,
          label: 'Buscador del alijo',
          interactive: true,
          gap: 'xs',
          allowedRegions: _main),
      LayoutSlotSpec(stashGrid, label: 'Grilla del alijo', movable: false),
      LayoutSlotSpec(ecoNote,
          label: 'Nota de la pestaña ECOS',
          hideable: true,
          gap: 'xs',
          allowedRegions: _main),
      LayoutSlotSpec(actions,
          label: 'Fila de acciones',
          group: true,
          interactive: true,
          allowedRegions: _main),
      LayoutSlotSpec(transfer,
          label: 'AL ALIJO > / < AL INVENTARIO',
          interactive: true,
          allowedRegions: {..._main, actions}),
      LayoutSlotSpec(moveAll,
          label: 'MOVER TODO AL ALIJO',
          interactive: true,
          allowedRegions: {..._main, actions}),
      LayoutSlotSpec(pick,
          label: 'ELEGIR', interactive: true, allowedRegions: {..._main, actions}),
      LayoutSlotSpec(status,
          label: 'Línea de estado', allowedRegions: {'header', 'footer'}),
    ],
    defaults: LayoutDoc(screen: screen, slots: const [
      SlotPlacement(title, 'left', 0),
      SlotPlacement(equipped, 'left', 1),
      SlotPlacement(inventoryLabel, 'left', 2),
      SlotPlacement(searchChar, 'left', 3),
      SlotPlacement(inventoryGrid, 'left', 4),
      SlotPlacement(stacks, 'left', 5),
      SlotPlacement(stashHeader, 'right', 0),
      SlotPlacement(stashTabs, 'right', 1),
      SlotPlacement(searchStash, 'right', 2),
      SlotPlacement(stashGrid, 'right', 3),
      SlotPlacement(ecoNote, 'right', 4),
      SlotPlacement(actions, 'footer', 0),
      SlotPlacement(transfer, actions, 0),
      SlotPlacement(moveAll, actions, 1),
      SlotPlacement(pick, actions, 2),
      SlotPlacement(status, 'footer', 1),
    ]),
  );
}
