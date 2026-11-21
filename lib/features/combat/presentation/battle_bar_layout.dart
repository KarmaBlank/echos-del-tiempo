import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/design/ds_layout_host.dart';
import '../../../app/theme/retro_type.dart';
import '../../../core/layout/layout_doc.dart';
import '../../../core/layout/layout_spec.dart';

/// BATALLA como datos (docs/specs/editor_layout.md § 6, fase 6 y
/// battle_presentation.md § "Barra de abajo"): la barra de abajo en una
/// sola fila, de izquierda a derecha, con cuatro lugares del template
/// (`card`, `categories`, `actions`, `description`). Cada slot se puede
/// mover a cualquier lugar; dos slots en el mismo lugar se apilan
/// (mitad y mitad). La escena y el grupo de compañeros son fijos.
///
/// Además, las perillas de la escena (§ 2.8): cuánto se aleja la cámara
/// y el margen de arriba de los textos flotantes.
abstract final class BattleBarLayout {
  static const screen = 'battle';

  static const card = 'battle.card';
  static const categories = 'battle.categories';
  static const actions = 'battle.actions';
  static const description = 'battle.description';
  static const waiting = 'battle.waiting';

  /// Pasos de zoom (enteros) que se aleja la cámara del encuadre base.
  static const cameraZoomOut = 'camera_zoom_out';

  /// Margen (unidades de etiqueta) entre el borde de arriba de la escena
  /// y el texto flotante más alto.
  static const floatTopMargin = 'float_top_margin';

  /// Los lugares de la fila, de izquierda a derecha (`top` va arriba).
  static const places = ['card', 'categories', 'actions', 'description'];

  static final spec = LayoutScreenSpec(
    screen: screen,
    title: 'BATALLA',
    regions: const [
      LayoutRegionSpec('top', label: 'Arriba de la fila (angosto)'),
      LayoutRegionSpec('card', label: 'Izquierda (tarjeta)'),
      LayoutRegionSpec('categories', label: 'Categorías'),
      LayoutRegionSpec('actions', label: 'Centro (acciones)'),
      LayoutRegionSpec('description', label: 'Derecha (descripción)'),
    ],
    slots: const [
      LayoutSlotSpec(card, label: 'Tarjeta del personaje (vida, maná, ULT, pulso)'),
      LayoutSlotSpec(categories,
          label: 'Categorías de acción', interactive: true),
      LayoutSlotSpec(actions, label: 'Lista de acciones', interactive: true),
      LayoutSlotSpec(description, label: 'Descripción de la acción'),
      LayoutSlotSpec(waiting, label: 'De quién es el turno (fuera del tuyo)'),
    ],
    // Angosto (< 60 tx: ventanas chicas o texto grande): la tarjeta
    // sube arriba de la fila y le deja el ancho al menú.
    defaults: LayoutDoc(screen: screen, slots: const [
      SlotPlacement(card, 'card', 0),
      SlotPlacement(categories, 'categories', 0),
      SlotPlacement(actions, 'actions', 0),
      SlotPlacement(waiting, 'actions', 1),
      SlotPlacement(description, 'description', 0),
    ], breakpoints: const {
      LayoutBreakpoint.narrow: {card: SlotRule(region: 'top')},
    }),
    params: const [
      LayoutParamSpec(cameraZoomOut,
          label: 'Cámara: alejar (pasos de zoom)',
          defaultValue: 0,
          min: 0,
          max: 3,
          help: 'Cuántos pasos enteros se aleja la cámara del encuadre '
              'automático. 0 = el de siempre.'),
      LayoutParamSpec(floatTopMargin,
          label: 'Textos flotantes: margen de arriba',
          defaultValue: 4,
          min: 0,
          max: 40,
          help: 'Distancia mínima entre el borde de arriba de la escena y '
              'los números, estados y carteles flotantes.'),
    ],
  );

  /// Ancho de la tarjeta a texto Normal (px lógicos).
  static const cardWidth = 250.0;

  /// Ancho de las categorías a texto Normal.
  static const categoriesWidth = 170.0;

  /// Peso de los lugares que se estiran.
  static const flex = {'actions': 5, 'description': 4};
}

/// La fila de la barra de abajo armada por datos. [slots] arma cada
/// pieza (`null` = no va ahora). Las piezas del menú (todo menos la
/// tarjeta) van dentro del borde de la ventana de comandos.
class BattleBarRow extends StatelessWidget {
  const BattleBarRow({
    super.key,
    required this.slots,
    this.layout,
    this.hooks,
    this.menuBorder = true,
  });

  final Map<String, DsSlotBuilder> slots;
  final LayoutDoc? layout;
  final DsLayoutHooks? hooks;

  /// Con la ventana de comandos (borde dorado); fuera del turno, sin.
  final bool menuBorder;

  /// Tope de ancho de la fila a texto Normal.
  static const maxWidth = 1240.0 + BattleBarLayout.cardWidth;

  @override
  Widget build(BuildContext context) => DsLayoutHost(
        spec: BattleBarLayout.spec,
        doc: layout,
        hooks: hooks,
        slots: slots,
        frame: _frame,
      );

  Widget _frame(BuildContext context, BoxConstraints box, DsRegions r) {
    final l = r.layout;
    final h = hooks;
    // Un lugar: sus slots apilados, cada uno con su parte del alto.
    Widget? place(String id) {
      final ids = l.of(id);
      final kids = <Widget>[];
      for (var i = 0; i < ids.length; i++) {
        final w = slots[ids[i]]?.call(context);
        if (w == null && h == null) continue;
        final child = w ?? const SizedBox.shrink();
        kids.add(Expanded(
            child: h == null ? child : h.slot(context, ids[i], id, i, child)));
      }
      if (kids.isEmpty && h == null) return null;
      Widget out = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < kids.length; i++) ...[
              if (i > 0) SizedBox(height: DsSpace.xs),
              kids[i],
            ],
          ]);
      if (h != null) out = h.container(context, id, LayoutAxis.column, ids, out);
      return out;
    }

    final w = math.min(box.maxWidth, RetroType.width(context, BattleBarRow.maxWidth));
    // La tarjeta: hasta 30 % del ancho; las categorías, hasta 20 %.
    double fixed(String id) => id == 'card'
        ? math.min(RetroType.width(context, BattleBarLayout.cardWidth), w * 0.3)
        : math.min(RetroType.width(context, BattleBarLayout.categoriesWidth),
            w * 0.2);
    Widget sized(String id, Widget child) {
      final f = BattleBarLayout.flex[id];
      return f == null
          ? SizedBox(width: fixed(id), child: child)
          : Expanded(flex: f, child: child);
    }

    // Arriba: cada slot a su alto natural, hasta 45 % del alto.
    Widget? top;
    final topIds = l.of('top');
    if (topIds.isNotEmpty || h != null) {
      final kids = <Widget>[
        for (var i = 0; i < topIds.length; i++)
          if (slots[topIds[i]]?.call(context) case final w?)
            h == null ? w : h.slot(context, topIds[i], 'top', i, w),
      ];
      if (kids.isNotEmpty || h != null) {
        Widget t = ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: box.maxHeight * 0.45, minHeight: h == null ? 0 : 12),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final k in kids) Flexible(fit: FlexFit.loose, child: k),
              ]),
        );
        if (h != null) {
          t = h.container(context, 'top', LayoutAxis.column, topIds, t);
        }
        top = t;
      }
    }

    final card = place('card');
    final menu = <Widget>[];
    for (final id in BattleBarLayout.places.skip(1)) {
      final p = place(id);
      if (p == null) continue;
      if (menu.isNotEmpty) menu.add(SizedBox(width: DsSpace.xs));
      menu.add(sized(id, p));
    }
    // Sin nada estirable en el menú, el último lugar se estira.
    if (menu.isNotEmpty && menu.last is SizedBox) {
      menu[menu.length - 1] =
          Expanded(child: (menu.last as SizedBox).child!);
    }
    Widget menuBox = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: menu);
    if (menuBorder) {
      // Las filas no toman el foco: las teclas las maneja la batalla.
      menuBox = ExcludeFocus(
        child: Container(
          key: const ValueKey('battle-menu'),
          padding: EdgeInsets.all(DsSpace.xs),
          decoration: BoxDecoration(
            color: DsColors.surface,
            border: Border.all(color: DsColors.selected, width: 2),
          ),
          child: DefaultTextStyle.merge(style: DsText.body(), child: menuBox),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: w,
        height: box.maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (top != null) ...[top, SizedBox(height: DsSpace.xs)],
            Expanded(
              child: Row(
                key: const ValueKey('battle-bar-row'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (card != null) ...[
                    SizedBox(width: fixed('card'), child: card),
                    if (menu.isNotEmpty) SizedBox(width: DsSpace.xs),
                  ],
                  if (menu.isNotEmpty) Expanded(child: menuBox),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
