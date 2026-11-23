import 'package:material_ui/material_ui.dart';

import '../../theme/retro_type.dart';

import '../../../core/screen_layout/screen_bindings.dart';
import '../../../core/screen_layout/screen_layout.dart';
import 'ds_registry.dart';

/// Handler de una acción con nombre (`null` = deshabilitado, gris).
class ScreenAction {
  const ScreenAction(this.onPressed, {this.tooltip});
  final VoidCallback? onPressed;
  final String? tooltip;
}

/// Lo que una pantalla entrega a su layout en tiempo de ejecución: solo
/// por nombre (docs/specs/screen_editor.md § 4).
class ScreenRuntimeBindings {
  const ScreenRuntimeBindings({
    this.actions = const {},
    this.data = const {},
    this.slots = const {},
  });

  final Map<String, ScreenAction> actions;
  final Map<String, List<ScreenDataEntry>> data;
  final Map<String, Widget> slots;
}

TextAlign textAlignOf(ScreenAlign a) => switch (a) {
      ScreenAlign.start => TextAlign.start,
      ScreenAlign.center => TextAlign.center,
      ScreenAlign.end => TextAlign.end,
    };

/// Dibuja un elemento con su componente del registro. [preview] = en el
/// editor: datos de ejemplo de [spec] y huecos como marcadores.
Widget buildScreenElement(
  BuildContext context,
  ScreenElement e, {
  DsRegistry? registry,
  ScreenRuntimeBindings bindings = const ScreenRuntimeBindings(),
  ScreenBindingSpec? spec,
  bool preview = false,
}) {
  final c = (registry ?? DsRegistry.instance)[e.component];
  if (c == null) return const SizedBox.shrink();
  // En el juego, un hueco que la pantalla no llenó (sin avisos, sin
  // estado de red) no se ve; el marcador es solo del editor.
  if (!preview &&
      c.props.contains(DsProp.slot) &&
      bindings.slots[e.slot] == null) {
    return const SizedBox.shrink();
  }
  final action = bindings.actions[e.action];
  final data = preview
      ? spec?.dataSource(e.dataSource)?.sample ?? const <ScreenDataEntry>[]
      : bindings.data[e.dataSource] ?? const <ScreenDataEntry>[];
  return c.build(
    context,
    DsElementContext(
      text: e.text ?? c.defaultText ?? '',
      variant: c.hasVariant(e.variant) ? e.variant : c.defaultVariant,
      size: e.size ?? c.defaultSizeId,
      textStyle: DsTextStyleInfo.parse(e.textStyle) ?? c.defaultTextStyle,
      align: textAlignOf(e.align),
      // En el editor los botones se ven habilitados si tienen acción.
      onPressed: preview
          ? (spec?.action(e.action) != null ? () {} : null)
          : action?.onPressed,
      tooltip: action?.tooltip ??
          (preview ? spec?.action(e.action)?.label : null),
      data: data,
      slot: preview ? null : bindings.slots[e.slot],
      slotLabel: spec?.slot(e.slot)?.label.toUpperCase(),
      preview: preview,
    ),
  );
}

/// Pantalla armada desde un [ScreenLayout] (lo que el juego dibuja).
class DsScreenView extends StatelessWidget {
  const DsScreenView({
    super.key,
    required this.layout,
    this.bindings = const ScreenRuntimeBindings(),
    this.registry,
    this.spec,
    this.preview = false,
  });

  final ScreenLayout layout;
  final ScreenRuntimeBindings bindings;
  final DsRegistry? registry;
  final ScreenBindingSpec? spec;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final reg = registry ?? DsRegistry.instance;
    return LayoutBuilder(builder: (context, box) {
      final window = Size(
          box.maxWidth.isFinite ? box.maxWidth : layout.width,
          box.maxHeight.isFinite ? box.maxHeight : layout.height);
      // El texto adentro va sin el factor de ventana: la escala `s` ya lo
      // agranda con la ventana (screen_editor.md § 2.1).
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: RetroType.withoutWindow(context)),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            for (final e in layout.elements)
              if (reg[e.component] != null)
                _place(context, reg, e, layout.place(e, window)),
          ]),
        ),
      );
    });
  }

  Widget _place(BuildContext context, DsRegistry reg, ScreenElement e,
      ScreenPlacement p) {
    final s = p.scale <= 0 ? 1.0 : p.scale;
    Widget child = SizedBox(
      width: p.rect.width / s,
      height: p.rect.height / s,
      child: buildScreenElement(context, e,
          registry: reg, bindings: bindings, spec: spec, preview: preview),
    );
    if (e.focusOrder != null) {
      child = FocusTraversalOrder(
          order: NumericFocusOrder(e.focusOrder!.toDouble()), child: child);
    }
    return Positioned(
      key: ValueKey(e.id),
      left: p.rect.left,
      top: p.rect.top,
      width: p.rect.width,
      height: p.rect.height,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.scale(
            scale: s, alignment: Alignment.topLeft, child: child),
      ),
    );
  }
}
