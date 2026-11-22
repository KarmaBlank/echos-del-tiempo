import '../../../core/layout/layout_doc.dart';
import '../../../core/layout/layout_spec.dart';

/// CONDENSAR como datos (docs/specs/editor_layout.md § 6, fase 4).
/// Regiones del template: `head` (título y explicación), `recipes` (las
/// tarjetas de receta, fijas) y `confirm` (dentro de la tarjeta de
/// confirmación, solo con una elección pendiente).
abstract final class CondenseLayout {
  static const screen = 'craft.condense';

  static const title = 'condense.title';
  static const intro = 'condense.intro';
  static const recipes = 'condense.recipes';
  static const summary = 'condense.summary';
  static const error = 'condense.error';
  static const actions = 'condense.actions';
  static const go = 'condense.actions.go';
  static const cancel = 'condense.actions.cancel';

  static const _text = {'head', 'confirm'};

  static final spec = LayoutScreenSpec(
    screen: screen,
    title: 'CONDENSAR',
    regions: const [
      LayoutRegionSpec('head', label: 'Arriba'),
      LayoutRegionSpec('recipes', label: 'Recetas (fijas)'),
      LayoutRegionSpec('confirm', label: 'Confirmación'),
    ],
    slots: const [
      LayoutSlotSpec(title,
          label: 'Título y ‹ VOLVER', interactive: true, allowedRegions: _text),
      LayoutSlotSpec(intro,
          label: 'Explicación', gap: 'none', allowedRegions: _text),
      LayoutSlotSpec(recipes, label: 'Recetas', movable: false),
      LayoutSlotSpec(summary,
          label: 'Lo que gastas y obtienes', allowedRegions: _text),
      LayoutSlotSpec(error,
          label: 'Motivo si no se puede', gap: 'none', allowedRegions: _text),
      LayoutSlotSpec(actions,
          label: 'CONDENSAR / CANCELAR',
          group: true,
          interactive: true,
          gap: 'xs',
          allowedRegions: _text),
      LayoutSlotSpec(go,
          label: 'CONDENSAR',
          interactive: true,
          gap: 'xs',
          allowedRegions: {..._text, actions}),
      LayoutSlotSpec(cancel,
          label: 'CANCELAR',
          interactive: true,
          gap: 'xs',
          allowedRegions: {..._text, actions}),
    ],
    defaults: LayoutDoc(screen: screen, slots: const [
      SlotPlacement(title, 'head', 0),
      SlotPlacement(intro, 'head', 1),
      SlotPlacement(recipes, 'recipes', 0),
      SlotPlacement(summary, 'confirm', 0),
      SlotPlacement(error, 'confirm', 1),
      SlotPlacement(actions, 'confirm', 2),
      SlotPlacement(go, actions, 0),
      SlotPlacement(cancel, actions, 1),
    ]),
  );
}

/// FUSIÓN (mesa de 3 pasos) como datos (editor_layout.md § 6). Regiones
/// del template: `crumbs`, `summary` y `materials` (la barra de arriba:
/// en fila, o una debajo de la otra con texto ENORME) y `footer` (pie
/// del detalle en el paso 1 ARMA). Las grillas y las tarjetas de los
/// pasos son fijas (código del template).
abstract final class FuseLayout {
  static const screen = 'craft.fuse';

  static const crumbs = 'fuse.crumbs';
  static const summary = 'fuse.summary';
  static const materials = 'fuse.materials';
  static const keys = 'fuse.keys';
  static const actions = 'fuse.actions';
  static const condense = 'fuse.actions.condense';
  static const next = 'fuse.actions.next';

  static const _all = {'crumbs', 'summary', 'materials', 'footer'};

  static final spec = LayoutScreenSpec(
    screen: screen,
    title: 'FUSIÓN',
    regions: const [
      LayoutRegionSpec('crumbs', label: 'Arriba: pasos'),
      LayoutRegionSpec('summary', label: 'Arriba: lo elegido'),
      LayoutRegionSpec('materials',
          label: 'Arriba: materiales', align: LayoutAlign.end),
      LayoutRegionSpec('footer',
          axis: LayoutAxis.wrap,
          label: 'Pie del paso ARMA',
          spacing: '8',
          runSpacing: '8',
          align: LayoutAlign.end),
    ],
    slots: const [
      LayoutSlotSpec(crumbs,
          label: '1 DESTINO › 2 ACCIÓN › 3 PREVIA',
          interactive: true,
          allowedRegions: _all),
      LayoutSlotSpec(summary,
          label: 'Arma y acción elegidas', allowedRegions: _all),
      LayoutSlotSpec(materials, label: 'Materiales', allowedRegions: _all),
      LayoutSlotSpec(keys, label: 'Teclas', allowedRegions: _all),
      LayoutSlotSpec(actions,
          label: 'CONDENSAR / ELEGIR ›',
          group: true,
          interactive: true,
          groupGap: '8',
          groupRunSpacing: '8',
          allowedRegions: _all),
      LayoutSlotSpec(condense,
          label: 'CONDENSAR',
          interactive: true,
          allowedRegions: {..._all, actions}),
      LayoutSlotSpec(next,
          label: 'ELEGIR ›',
          interactive: true,
          allowedRegions: {..._all, actions}),
    ],
    defaults: LayoutDoc(screen: screen, slots: const [
      SlotPlacement(crumbs, 'crumbs', 0),
      SlotPlacement(summary, 'summary', 0),
      SlotPlacement(materials, 'materials', 0),
      SlotPlacement(keys, 'footer', 0),
      SlotPlacement(actions, 'footer', 1,
          rule: SlotRule(align: LayoutAlign.end)),
      SlotPlacement(condense, actions, 0),
      SlotPlacement(next, actions, 1),
    ]),
  );
}

/// FORJA como datos (editor_layout.md § 6). Regiones del template:
/// `detail` (columna del detalle) y `footer` (pie del detalle). La
/// grilla de armas y las tarjetas de forja son fijas.
abstract final class ForgeLayout {
  static const screen = 'craft.forge';

  static const title = 'forge.title';
  static const skills = 'forge.skills';
  static const upgrades = 'forge.upgrades';
  static const actions = 'forge.actions';
  static const keys = 'forge.actions.keys';
  static const equipped = 'forge.actions.equipped';
  static const equip = 'forge.actions.equip';

  static const _all = {'detail', 'footer'};

  static final spec = LayoutScreenSpec(
    screen: screen,
    title: 'FORJA',
    regions: const [
      LayoutRegionSpec('detail', label: 'Detalle'),
      LayoutRegionSpec('footer',
          axis: LayoutAxis.wrap,
          label: 'Pie del detalle',
          spacing: '8',
          runSpacing: '8',
          align: LayoutAlign.end),
    ],
    slots: const [
      LayoutSlotSpec(title, label: 'Nombre y ★', allowedRegions: _all),
      LayoutSlotSpec(skills,
          label: 'Habilidades', gap: 'none', allowedRegions: _all),
      LayoutSlotSpec(upgrades,
          label: 'Tarjetas de forja', movable: false, gap: '4'),
      LayoutSlotSpec(actions,
          label: 'Teclas / EQUIPAR',
          group: true,
          interactive: true,
          groupGap: '8',
          groupRunSpacing: '8',
          allowedRegions: _all),
      LayoutSlotSpec(keys,
          label: 'Teclas', allowedRegions: {..._all, actions}),
      LayoutSlotSpec(equipped,
          label: 'EQUIPADA (aviso)', allowedRegions: {..._all, actions}),
      LayoutSlotSpec(equip,
          label: 'EQUIPAR',
          interactive: true,
          allowedRegions: {..._all, actions}),
    ],
    defaults: LayoutDoc(screen: screen, slots: const [
      SlotPlacement(title, 'detail', 0),
      SlotPlacement(skills, 'detail', 1),
      SlotPlacement(upgrades, 'detail', 2),
      SlotPlacement(actions, 'footer', 0,
          rule: SlotRule(align: LayoutAlign.end)),
      SlotPlacement(keys, actions, 0),
      SlotPlacement(equipped, actions, 1),
      SlotPlacement(equip, actions, 2),
    ]),
  );
}
