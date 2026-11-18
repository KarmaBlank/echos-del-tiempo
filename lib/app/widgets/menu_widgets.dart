import 'package:material_ui/material_ui.dart';

import '../theme/panel_frame.dart';
import '../theme/proto_colors.dart';
import '../theme/proto_markup.dart';
import '../theme/retro_text.dart';
import '../theme/retro_theme.dart';
import 'menu_focus.dart';
import '../theme/ui_theme.dart';

/// Piezas de los menús "lista + detalle" compactos (docs/specs/ui_style.md
/// § "Menús: lista + detalle"): filas de una línea con el valor alineado
/// a la derecha, grupos con la etiqueta a un costado, pasos con migas,
/// selector ‹ valor › y la línea de teclas. Todo con los tokens del tema:
/// el tamaño sale del ajuste "Tamaño del texto".

/// Fila elegible de **una línea**: [label] (markup, se corta con "…") a la
/// izquierda y [value] (markup) alineado a la derecha: costo, nivel,
/// "EQUIPADA" o el motivo en rojo si no se puede. Borde `gold` elegida,
/// `sky` con foco o mouse; clic / `Enter` / `Espacio` la eligen. Con
/// [onHover] el detalle puede seguir al mouse o al foco.
class MenuRow extends StatefulWidget {
  const MenuRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.value,
    this.valueKey,
    this.onHover,
    this.dimmed = false,
    this.indent = 0,
    this.description,
    this.wrap = false,
    this.autofocus = false,
    this.onFocus,
  });

  /// El cursor del teclado llegó a la fila (las flechas): para que el
  /// detalle siga al cursor sin tener que apretar `Enter`.
  final VoidCallback? onFocus;

  /// Toma el foco al aparecer (la fila elegida de una lista recién
  /// abierta).
  final bool autofocus;

  final String label;

  /// Explicación corta (`dim`) entre la etiqueta y el valor.
  final String? description;

  /// Sin "…": la etiqueta, la explicación y el valor pasan a otra línea
  /// si no entran (la fila crece en alto).
  final bool wrap;
  final String? value;

  /// Clave del texto de [value] (para las pruebas).
  final Key? valueKey;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<bool>? onHover;

  /// Fila no disponible: el texto en `dim` (sigue siendo elegible para
  /// ver el motivo en el detalle).
  final bool dimmed;

  /// Sangría izquierda (filas que dependen de la de arriba).
  final double indent;

  @override
  State<MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<MenuRow> {
  bool _hover = false, _focus = false;

  bool get _hot => _hover || _focus;

  void _set({bool? hover, bool? focus}) {
    final was = _hot;
    setState(() {
      _hover = hover ?? _hover;
      _focus = focus ?? _focus;
    });
    if (_hot != was) widget.onHover?.call(_hot);
    if (focus == true) widget.onFocus?.call();
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.selected
        ? ProtoColors.gold
        : _hot
            ? ProtoColors.sky
            : ProtoColors.panelBorder;
    final style =
        widget.dimmed ? const TextStyle(color: ProtoColors.dim) : null;
    return Padding(
      padding: EdgeInsets.only(
          left: widget.indent, bottom: UiTheme.wide ? 4 : 2),
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (v) => _set(focus: v),
        onShowHoverHighlight: (v) => _set(hover: v),
        actions: {
          ActivateIntent:
              CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap()),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: FocusRing(
            focused: _focus,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: UiTheme.space(8), vertical: UiTheme.wide ? 6 : 3),
              decoration: BoxDecoration(
                color: widget.selected
                    ? ProtoColors.button.withValues(alpha: 0.5)
                    : null,
                border: Border.all(
                    color: border, width: RetroTheme.thinBorderWidth),
              ),
              child: widget.wrap ? _wrapped(style) : _oneLine(style),
            ),
          ),
        ),
      ),
    );
  }

  /// La etiqueta manda (ancho natural, hasta 75 %): el valor usa lo que
  /// queda y es el que se corta con "…".
  Widget _oneLine(TextStyle? style) => LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: box.maxWidth.isFinite
                      ? box.maxWidth * 0.75
                      : double.infinity),
              child: ProtoText(widget.label,
                  style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: widget.value == null
                  ? const SizedBox.shrink()
                  : KeyedSubtree(
                      key: widget.valueKey,
                      child: ProtoText(widget.value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right),
                    ),
            ),
          ],
        ),
      );

  /// Nada se corta: etiqueta (ancho natural, hasta 45 %), explicación en
  /// el medio y valor a la derecha (hasta 40 %), cada uno en varias
  /// líneas si hace falta.
  Widget _wrapped(TextStyle? style) => LayoutBuilder(
        builder: (context, box) {
          // Ancho útil sin los dos huecos de 12 px: los máximos suman 100 %.
          final w = (box.maxWidth.isFinite ? box.maxWidth : 1000.0) - 24;
          final hasDesc = widget.description != null;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: hasDesc ? w * 0.4 : w * 0.55),
                child: ProtoText(widget.label, style: style),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: widget.description == null
                    ? const SizedBox.shrink()
                    : ProtoText(widget.description!,
                        style: const TextStyle(color: ProtoColors.dim)),
              ),
              if (widget.value != null) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: hasDesc ? w * 0.35 : w * 0.45),
                  child: KeyedSubtree(
                    key: widget.valueKey,
                    child: ProtoText(widget.value!, textAlign: TextAlign.right),
                  ),
                ),
              ],
            ],
          );
        },
      );
}

/// Grupo de filas con la etiqueta en una columna a la izquierda (no
/// ocupa una línea propia): `MEJORAR │ fila / fila / fila`.
class MenuGroup extends StatelessWidget {
  const MenuGroup({
    super.key,
    required this.label,
    required this.children,
    this.labelEms = 9,
    this.color = ProtoColors.gold,
  });

  final String label;
  final List<Widget> children;

  /// Ancho de la etiqueta en letras de [RetroType.label].
  final double labelEms;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: RetroType.em(context, labelEms),
            child: Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: Text(retroText(label),
                  style: TextStyle(
                      fontFamily: RetroType.pixelFamily,
                      fontSize: RetroType.label,
                      height: RetroType.pixelLine,
                      color: color)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de una lista (una línea, `gold`).
class MenuHeader extends StatelessWidget {
  const MenuHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2),
        child: ProtoText(text,
            style: const TextStyle(color: ProtoColors.title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      );
}

/// Migas de un asistente por pasos: `1 ARMA › 2 ACCIÓN › 3 CONFIRMAR`.
/// Se puede volver a cualquier paso; los de más adelante también se
/// pueden tocar si [reachable] lo permite.
class StepCrumbs extends StatelessWidget {
  const StepCrumbs({
    super.key,
    required this.steps,
    required this.current,
    required this.onStep,
    this.keyPrefix = 'step-crumb-',
  });

  final List<String> steps;
  final int current;
  final ValueChanged<int> onStep;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const Text('›', style: TextStyle(color: ProtoColors.dim)),
          PanelButton('${i + 1} ${steps[i]}',
              key: ValueKey('$keyPrefix$i'),
              selected: i == current,
              accent: i == current ? ProtoColors.gold : null,
              onPressed: () => onStep(i)),
        ],
      ],
    );
  }
}

/// Selector compacto de una opción entre varias: `Familia ‹ MAGA ›`. Las
/// flechas recorren [options] en círculo (clic o `Enter` sobre ellas).
class ChoiceCycler<T> extends StatelessWidget {
  const ChoiceCycler({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.display,
    required this.onChanged,
    this.keyPrefix = 'cycler-',
  });

  final String label;
  final List<T> options;
  final T value;
  final String Function(T) display;
  final ValueChanged<T> onChanged;
  final String keyPrefix;

  void _step(int d) {
    if (options.isEmpty) return;
    final i = options.indexOf(value);
    onChanged(options[(i + d) % options.length]);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(retroText(label), style: const TextStyle(color: ProtoColors.dim)),
        const SizedBox(width: 6),
        PanelButton('‹',
            key: ValueKey('${keyPrefix}prev'), onPressed: () => _step(-1)),
        const SizedBox(width: 4),
        Flexible(
          child: KeyedSubtree(
            key: ValueKey('${keyPrefix}value'),
            child: Text(retroText(display(value)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ProtoColors.gold)),
          ),
        ),
        const SizedBox(width: 4),
        PanelButton('›',
            key: ValueKey('${keyPrefix}next'), onPressed: () => _step(1)),
      ],
    );
  }
}

/// Línea de teclas al pie de un detalle: `Enter Confirmar · Esc Volver`.
class KeyHints extends StatelessWidget {
  const KeyHints({super.key, this.confirm = 'Confirmar', this.back = 'Volver'});

  final String? confirm;
  final String? back;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (confirm != null) '<span class="k">Enter</span> $confirm',
      if (back != null) '<span class="k">Esc</span> $back',
    ];
    return ProtoText(parts.join(' · '),
        style: const TextStyle(color: ProtoColors.dim),
        maxLines: 1,
        overflow: TextOverflow.ellipsis);
  }
}

/// `Etiqueta  valor`: la etiqueta en una columna fija (`sky`) y el valor
/// en markup al lado, para alinear las líneas de una ficha.
class InfoLine extends StatelessWidget {
  const InfoLine(this.label, this.markup,
      {super.key, this.labelEms = 10, this.color = ProtoColors.sky});

  final String label;
  final String markup;
  final double labelEms;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: UiTheme.wide ? 4 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: RetroType.em(context, labelEms, size: RetroType.small),
            child: Text(retroText(label), style: TextStyle(color: color)),
          ),
          Expanded(child: ProtoText(markup)),
        ],
      ),
    );
  }
}
