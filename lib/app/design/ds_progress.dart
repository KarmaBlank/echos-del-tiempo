import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/retro_text.dart';
import '../theme/retro_theme.dart';
import 'ds_button.dart';
import 'ds_focus.dart';
import 'ds_tokens.dart';

// Átomos de BUILD v2 (docs/specs/build_planner_v2.md § 4.2): slider de
// nivel, línea de tiempo y porcentaje. Presentacionales y cuadrados.

/// Slider entero cuadrado con marcas (átomo). Flechas: de a 1; Inicio /
/// Fin: al mínimo / máximo; clic o arrastre en la pista. Foco de teclado
/// con el aro del sistema.
class DsSlider extends StatefulWidget {
  const DsSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.marks = const {},
    this.semanticLabel = 'Nivel',
    this.focusNode,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;

  /// Marcas en la pista: valor → color.
  final Map<int, Color> marks;
  final String semanticLabel;
  final FocusNode? focusNode;

  @override
  State<DsSlider> createState() => _DsSliderState();
}

class _DsSliderState extends State<DsSlider> {
  bool _focus = false;
  FocusNode? _own;

  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _set(int v) {
    final c = v.clamp(widget.min, widget.max);
    if (c != widget.value) widget.onChanged?.call(c);
  }

  void _at(double dx, double width) {
    if (width <= 0) return;
    final f = (dx / width).clamp(0.0, 1.0);
    _set(widget.min + (f * (widget.max - widget.min)).round());
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowUp) {
      _set(widget.value + 1);
    } else if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowDown) {
      _set(widget.value - 1);
    } else if (k == LogicalKeyboardKey.home) {
      _set(widget.min);
    } else if (k == LogicalKeyboardKey.end) {
      _set(widget.max);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final span = (widget.max - widget.min).clamp(1, 1 << 20);
    final h = RetroType.width(context, 24);
    final thumbW = RetroType.width(context, 10);
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: '${widget.value}',
      increasedValue: '${(widget.value + 1).clamp(widget.min, widget.max)}',
      decreasedValue: '${(widget.value - 1).clamp(widget.min, widget.max)}',
      onIncrease: () => _set(widget.value + 1),
      onDecrease: () => _set(widget.value - 1),
      child: Focus(
        focusNode: _node,
        onKeyEvent: _key,
        onFocusChange: (f) => setState(() => _focus = f),
        child: DsFocusRing(
          focused: _focus,
          child: MouseRegion(
            cursor: widget.onChanged == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth.isFinite ? box.maxWidth : 300.0;
              final track = w - thumbW;
              double x(int v) => track * (v - widget.min) / span;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  // Clic: toma el foco (después se sigue con el teclado).
                  _node.requestFocus();
                  _at(d.localPosition.dx - thumbW / 2, track);
                },
                onHorizontalDragUpdate: (d) =>
                    _at(d.localPosition.dx - thumbW / 2, track),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned(
                      left: thumbW / 2,
                      right: thumbW / 2,
                      top: h / 2 - 3,
                      height: 6,
                      child: Container(
                        decoration: BoxDecoration(
                            color: DsColors.surfaceSunken,
                            border: Border.all(
                                color: DsColors.borderControl, width: 1)),
                      ),
                    ),
                    Positioned(
                      left: thumbW / 2,
                      top: h / 2 - 3,
                      height: 6,
                      width: x(widget.value).clamp(0, track),
                      child: const ColoredBox(color: DsColors.actionPrimary),
                    ),
                    for (final e in widget.marks.entries)
                      if (e.key >= widget.min && e.key <= widget.max)
                        Positioned(
                          left: thumbW / 2 + x(e.key) - 1,
                          top: 2,
                          width: 2,
                          height: h / 2 - 5,
                          child: ColoredBox(color: e.value),
                        ),
                    Positioned(
                      left: x(widget.value),
                      top: h / 2 - 8,
                      width: thumbW,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                            color: DsColors.surfaceRaised,
                            border: Border.all(
                                color: _focus
                                    ? DsColors.focus
                                    : DsColors.actionPrimary,
                                width: 2)),
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Una marca de [DsTimeline].
class DsTimelineMark {
  const DsTimelineMark(this.value, this.label, {required this.color, this.key});
  final int value;
  final String label;
  final Color color;
  final Key? key;
}

/// Fila horizontal de marcas cliqueables (molécula): cada una es un botón
/// compacto con su color; la elegida va marcada. Desplazable si no entra.
class DsTimeline extends StatelessWidget {
  const DsTimeline({
    super.key,
    required this.marks,
    required this.onSelect,
    this.selected,
  });

  final List<DsTimelineMark> marks;
  final ValueChanged<int> onSelect;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < marks.length; i++) ...[
          if (i > 0)
            Container(width: DsSpace.sm, height: 2, color: DsColors.border),
          DsButton(marks[i].label,
              key: marks[i].key,
              size: DsButtonSize.compact,
              kind: DsButtonKind.ghost,
              accent: marks[i].color,
              selected: marks[i].value == selected,
              onPressed: () => onSelect(marks[i].value)),
        ],
      ]),
    );
  }
}

/// Porcentaje en una línea: el número y una barra (átomo). El lector de
/// pantalla lee "[label], 72 por ciento".
class DsPercent extends StatelessWidget {
  const DsPercent(this.percent,
      {super.key, this.label = '', this.barWidth = 64, this.color});

  final int percent;
  final String label;
  final double barWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ??
        (percent >= 100
            ? DsColors.success
            : percent > 0
                ? DsColors.reward
                : DsColors.textSecondary);
    final f = (percent / 100).clamp(0.0, 1.0);
    final w = RetroType.width(context, barWidth);
    return Semantics(
      label: '${label.isEmpty ? '' : '$label, '}$percent por ciento',
      excludeSemantics: true,
      // Con ancho acotado, la barra se achica para no pasarse del borde
      // (tarjetas de OFICIOS, v0.25.4).
      child: LayoutBuilder(builder: (context, box) => Row(
          mainAxisSize: MainAxisSize.min, children: [
        Text(retroText('$percent%'), maxLines: 1, style: DsText.body(c)),
        SizedBox(width: DsSpace.xs),
        if (box.hasBoundedWidth)
          Flexible(child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: w), child: _bar(f, c, w)))
        else
          _bar(f, c, w),
      ])),
    );
  }

  Widget _bar(double f, Color c, double w) => Container(
          width: w,
          height: 6,
          decoration: BoxDecoration(
              color: DsColors.surfaceSunken,
              border: Border.all(color: DsColors.borderControl, width: 1)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
              widthFactor: f, heightFactor: 1, child: ColoredBox(color: c)),
        );
}
