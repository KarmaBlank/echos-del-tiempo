import '../../../core/layout/layout_doc.dart';
import '../../../core/layout/layout_spec.dart';

/// Layout del INVENTARIO como datos (docs/specs/editor_layout.md § 4,
/// fase 4). Regiones del template: `toolbar` (barra de arriba), `head`
/// (arriba de la grilla; en ancho, arriba de la columna del costado),
/// `grid` (notas y grilla, fija) y `foot` (debajo de la grilla; en
/// ancho, debajo de `head`). La lógica de modos (ancho / medio /
/// angosto), la escala de las casillas y la franja de CAMBIOS siguen en
/// el código del template.
abstract final class InventoryTabLayout {
  static const screen = 'inventory';

  static const owners = 'inv.owners';
  static const search = 'inv.search';
  static const searchClear = 'inv.search_clear';
  static const tools = 'inv.tools';
  static const sort = 'inv.tools.sort';
  static const clean = 'inv.tools.clean';
  static const stash = 'inv.tools.stash';
  static const notes = 'inv.notes';
  static const grid = 'inv.grid';
  static const equipped = 'inv.equipped';
  static const stacks = 'inv.stacks';
  static const summary = 'inv.summary';
  static const selection = 'inv.selection';
  static const cleanMenu = 'inv.clean_menu';

  static const _main = {'toolbar', 'head', 'foot'};
  static const _side = {'head', 'foot'};

  static final spec = LayoutScreenSpec(
    screen: screen,
    title: 'INVENTARIO',
    regions: const [
      LayoutRegionSpec('toolbar',
          axis: LayoutAxis.wrap, label: 'Barra', spacing: 'xs'),
      LayoutRegionSpec('head', label: 'Arriba / costado'),
      LayoutRegionSpec('grid', label: 'Grilla (fija)'),
      LayoutRegionSpec('foot', label: 'Abajo / costado'),
    ],
    slots: const [
      LayoutSlotSpec(owners,
          label: 'De quién (TÚ / compañeros)',
          interactive: true,
          allowedRegions: _main),
      LayoutSlotSpec(search,
          label: 'Buscador', interactive: true, lead: 'md', allowedRegions: _main),
      LayoutSlotSpec(searchClear,
          label: 'Borrar la búsqueda', interactive: true, allowedRegions: _main),
      LayoutSlotSpec(tools,
          label: 'ORDENAR / LIMPIAR / ALIJO',
          group: true,
          interactive: true,
          lead: 'md',
          groupGap: 'xs',
          allowedRegions: _main),
      LayoutSlotSpec(sort,
          label: 'ORDENAR', interactive: true, allowedRegions: {..._main, tools}),
      LayoutSlotSpec(clean,
          label: 'LIMPIAR', interactive: true, allowedRegions: {..._main, tools}),
      LayoutSlotSpec(stash,
          label: 'ALIJO', interactive: true, allowedRegions: {..._main, tools}),
      LayoutSlotSpec(notes,
          label: 'Aviso (MOVER / COMPARAR / solo lectura)', movable: false),
      LayoutSlotSpec(grid,
          label: 'Grilla del inventario', movable: false, gap: 'xs'),
      LayoutSlotSpec(equipped,
          label: 'EQUIPADA', interactive: true, allowedRegions: _side),
      LayoutSlotSpec(stacks,
          label: 'Consumibles y materiales',
          interactive: true,
          allowedRegions: _side),
      LayoutSlotSpec(summary,
          label: 'Casillas y créditos', gap: '6', allowedRegions: _side),
      LayoutSlotSpec(selection,
          label: 'Barra de la elegida',
          interactive: true,
          gap: 'none',
          allowedRegions: _side),
      LayoutSlotSpec(cleanMenu,
          label: 'Menú de LIMPIAR',
          interactive: true,
          gap: 'xs',
          allowedRegions: _side),
    ],
    defaults: LayoutDoc(screen: screen, slots: const [
      SlotPlacement(owners, 'toolbar', 0),
      SlotPlacement(search, 'toolbar', 1),
      SlotPlacement(searchClear, 'toolbar', 2),
      SlotPlacement(tools, 'toolbar', 3),
      SlotPlacement(sort, tools, 0),
      SlotPlacement(clean, tools, 1),
      SlotPlacement(stash, tools, 2),
      SlotPlacement(notes, 'grid', 0),
      SlotPlacement(grid, 'grid', 1),
      SlotPlacement(equipped, 'head', 0),
      SlotPlacement(stacks, 'foot', 0),
      SlotPlacement(summary, 'foot', 1),
      SlotPlacement(selection, 'foot', 2),
      SlotPlacement(cleanMenu, 'foot', 3),
    ]),
  );
}
