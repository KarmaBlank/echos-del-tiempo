import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'ds_tokens.dart';

// Diálogo de personaje y ventanas de menú (ui_minimal.md § 10). Todo es
// visual: quien lo usa arma las opciones y decide qué hace cada una.

/// Átomo: cursor ▶ dibujado (no depende de la fuente).
class DsCursor extends StatelessWidget {
  const DsCursor({super.key, this.visible = true, this.size = 10});

  final bool visible;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: visible
            ? CustomPaint(painter: _CursorPainter(DsColors.selected))
            : null,
      );
}

class _CursorPainter extends CustomPainter {
  _CursorPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(s.width, s.height / 2)
          ..lineTo(0, s.height)
          ..close(),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CursorPainter o) => o.color != color;
}

/// Átomo: barra cuadrada [value] / [max] con su color.
class DsMeter extends StatelessWidget {
  const DsMeter(this.value, this.max,
      {super.key, required this.color, this.height = 8});

  final int value;
  final int max;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = max <= 0 ? 1.0 : (value / max).clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
          color: DsColors.surfaceSunken,
          border: Border.all(color: DsColors.border)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
          widthFactor: f, child: Container(color: color)),
    );
  }
}

/// Una opción del menú de diálogo. Sin [onSelected] va gris y, si tiene
/// [reason], la muestra al pasar el cursor.
class DsChoice {
  const DsChoice(this.label,
      {this.onSelected, this.reason, this.key, this.dimmed = false});

  final String label;

  /// Already seen (e.g. a question already asked): drawn dimmer but still
  /// selectable.
  final bool dimmed;
  final VoidCallback? onSelected;
  final String? reason;
  final Key? key;

  bool get enabled => onSelected != null;
}

/// Molécula: lista vertical de opciones con cursor ▶. Flechas mueven,
/// Enter / Espacio eligen; el mouse mueve el cursor al pasar y elige con
/// clic. Debajo, una línea con el motivo si la opción marcada está gris.
class DsChoiceMenu extends StatefulWidget {
  const DsChoiceMenu(this.choices,
      {super.key,
      this.onCancel,
      this.autofocus = true,
      this.enabled = true,
      this.focusNode});

  final List<DsChoice> choices;

  /// False while the dialogue line is still typing: every option is drawn
  /// grey and ignores keys and clicks, but keeps its place.
  final bool enabled;
  final FocusNode? focusNode;

  /// Esc.
  final VoidCallback? onCancel;
  final bool autofocus;

  @override
  State<DsChoiceMenu> createState() => _DsChoiceMenuState();
}

class _DsChoiceMenuState extends State<DsChoiceMenu> {
  int _at = 0;

  void _move(int d) {
    final n = widget.choices.length;
    if (n == 0) return;
    setState(() => _at = (_at + d) % n);
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (!widget.enabled || (e is! KeyDownEvent && e is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.numpadEnter) {
      if (e is KeyDownEvent) widget.choices[_at].onSelected?.call();
    } else if (k == LogicalKeyboardKey.escape && widget.onCancel != null) {
      widget.onCancel!();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final at = _at.clamp(0, widget.choices.length - 1);
    final cur = widget.choices.isEmpty ? null : widget.choices[at];
    final on = widget.enabled;
    return Focus(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onKeyEvent: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.choices.length; i++)
            MouseRegion(
              cursor: on && widget.choices[i].enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              onEnter: (_) {
                if (on) setState(() => _at = i);
              },
              child: GestureDetector(
                key: widget.choices[i].key,
                behavior: HitTestBehavior.opaque,
                onTap: on ? widget.choices[i].onSelected : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: DsSpace.xs),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    DsCursor(visible: on && i == at),
                    SizedBox(width: DsSpace.sm),
                    Flexible(
                      child: Text(widget.choices[i].label,
                          style: DsText.body(!on || !widget.choices[i].enabled
                              ? DsColors.textDisabled
                              : i == at
                                  ? DsColors.selected
                                  : widget.choices[i].dimmed
                                      ? DsColors.textSecondary
                                      : DsColors.text)),
                    ),
                  ]),
                ),
              ),
            ),
          SizedBox(
            height: DsSpace.lg,
            child: on && cur != null && !cur.enabled && cur.reason != null
                ? Padding(
                    padding: EdgeInsets.only(top: DsSpace.xs),
                    child: Text(cur.reason!,
                        key: const ValueKey('ds-choice-reason'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.detail(DsColors.textSecondary)),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// Organismo: cuadro de diálogo abajo de la pantalla. Retrato grande a
/// la izquierda, placa con el nombre, la frase escrita letra a letra
/// (clic, Enter o Espacio la completan) y, al terminar, el menú de
/// opciones a la derecha.
class DsDialogueBox extends StatefulWidget {
  const DsDialogueBox({
    super.key,
    required this.portrait,
    required this.name,
    required this.text,
    required this.choices,
    required this.skipLabel,
    this.role,
    this.onCancel,
    this.charDelay = const Duration(milliseconds: 18),
  });

  /// Retrato (quien lo usa elige el sprite), en una casilla cuadrada.
  final Widget portrait;
  final String name;
  final String? role;
  final String text;
  final List<DsChoice> choices;
  final VoidCallback? onCancel;
  final Duration charDelay;

  /// Label of the skip button shown while the line types (i18n text).
  final String skipLabel;

  static const portraitSize = 128.0;

  /// Fixed outer height: the box never resizes while typing, when the
  /// line finishes or when the option list changes.
  static const height = 272.0;
  static const choicesWidth = 260.0;

  @override
  State<DsDialogueBox> createState() => _DsDialogueBoxState();
}

class _DsDialogueBoxState extends State<DsDialogueBox> {
  int _shown = 0;
  Timer? _timer;
  final _menuFocus = FocusNode(debugLabel: 'ds-dialogue-menu');

  bool get _done => _shown >= widget.text.length;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(DsDialogueBox old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _start();
  }

  void _start() {
    _timer?.cancel();
    _shown = widget.charDelay == Duration.zero ? widget.text.length : 0;
    if (_done) {
      _focusMenu();
      return;
    }
    _timer = Timer.periodic(widget.charDelay, (t) {
      if (!mounted) return t.cancel();
      setState(() => _shown++);
      if (_done) {
        t.cancel();
        _focusMenu();
      }
    });
  }

  void _skip() {
    if (_done) return;
    _timer?.cancel();
    setState(() => _shown = widget.text.length);
    _focusMenu();
  }

  void _focusMenu() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _done) _menuFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _menuFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent || _done) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.escape) {
      _skip();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(
        color: DsColors.surface,
        border: Border.all(color: DsColors.border, width: 2));
    return Focus(
      autofocus: true,
      onKeyEvent: _key,
      child: GestureDetector(
        key: const ValueKey('ds-dialogue'),
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Container(
          height: DsDialogueBox.height,
          decoration: box,
          padding: EdgeInsets.all(DsSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: DsDialogueBox.portraitSize,
                height: DsDialogueBox.portraitSize,
                decoration: BoxDecoration(
                    color: DsColors.surfaceSunken,
                    border: Border.all(color: DsColors.borderControl)),
                child: widget.portrait,
              ),
              SizedBox(width: DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: DsSpace.sm, vertical: DsSpace.xs),
                      decoration: BoxDecoration(
                          color: DsColors.surfaceRaised,
                          border: Border.all(color: DsColors.borderControl)),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: widget.name.toUpperCase(),
                            style: DsText.title(DsColors.textTitle)),
                        if (widget.role != null)
                          TextSpan(
                              text: '  ${widget.role!.toUpperCase()}',
                              style: DsText.detail(DsColors.textSecondary)),
                      ])),
                    ),
                    SizedBox(height: DsSpace.sm),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(widget.text.substring(0, _shown),
                            key: const ValueKey('ds-dialogue-text'),
                            softWrap: true,
                            style: DsText.body(DsColors.text)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Visibility(
                        visible: !_done,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            key: const ValueKey('ds-dialogue-skip'),
                            onTap: _skip,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: DsSpace.sm,
                                  vertical: DsSpace.xs),
                              decoration: BoxDecoration(
                                  color: DsColors.surfaceRaised,
                                  border: Border.all(
                                      color: DsColors.borderControl)),
                              child: Text(widget.skipLabel,
                                  style:
                                      DsText.detail(DsColors.textSecondary)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: DsSpace.md),
              SizedBox(
                key: const ValueKey('ds-dialogue-choices'),
                width: DsDialogueBox.choicesWidth,
                child: SingleChildScrollView(
                  child: DsChoiceMenu(widget.choices,
                      autofocus: false,
                      enabled: _done,
                      focusNode: _menuFocus,
                      onCancel: widget.onCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una celda de [DsStatusStrip]: etiqueta arriba, valor abajo.
class DsStatusCell {
  const DsStatusCell(this.label, this.value, {this.flex = 1, this.key});

  final String label;
  final Widget value;
  final int flex;
  final Key? key;
}

/// Molécula: franja de estado con celdas separadas por borde (cada dato
/// en su sección, con su etiqueta).
class DsStatusStrip extends StatelessWidget {
  const DsStatusStrip(this.cells, {super.key});

  final List<DsStatusCell> cells;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: DsColors.surfaceSunken,
            border: Border.all(color: DsColors.border)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) Container(width: 1, color: DsColors.border),
                Expanded(
                  key: cells[i].key,
                  flex: cells[i].flex,
                  child: Padding(
                    padding: EdgeInsets.all(DsSpace.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cells[i].label.toUpperCase(),
                            style: DsText.detail(DsColors.textSecondary)),
                        SizedBox(height: DsSpace.xs),
                        cells[i].value,
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Molécula: casilla de mercancía de tienda: ícono, nombre, precio
/// alineado a la derecha y cuántos tenés.
class DsGoodsCell extends StatelessWidget {
  const DsGoodsCell({
    super.key,
    required this.icon,
    required this.name,
    required this.price,
    required this.owned,
    required this.selected,
    required this.affordable,
    required this.onTap,
    this.nameColor,
  });

  final Widget icon;
  final String name;
  final String price;
  final int owned;
  final bool selected;
  final bool affordable;
  final VoidCallback onTap;
  final Color? nameColor;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(DsSpace.sm),
            decoration: BoxDecoration(
                color: selected ? DsColors.surfaceRaised : DsColors.surface,
                border: Border.all(
                    color: selected ? DsColors.selected : DsColors.border,
                    width: selected ? 2 : 1)),
            child: Row(children: [
              icon,
              SizedBox(width: DsSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.body(nameColor ?? DsColors.text)),
                    Text('Tenés $owned',
                        style: DsText.detail(DsColors.textSecondary)),
                  ],
                ),
              ),
              SizedBox(width: DsSpace.sm),
              Text(price,
                  style: DsText.body(
                      affordable ? DsColors.reward : DsColors.textDisabled)),
            ]),
          ),
        ),
      );
}

/// Átomo: selector de cantidad − N +, entre [min] y [max].
class DsQuantity extends StatelessWidget {
  const DsQuantity(
      {super.key,
      required this.value,
      required this.max,
      required this.onChanged,
      this.min = 1});

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  Widget _btn(String t, Key k, VoidCallback? f) => MouseRegion(
        cursor: f == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          key: k,
          onTap: f,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: DsColors.surfaceRaised,
                border: Border.all(color: DsColors.borderControl)),
            child: Text(t,
                style: DsText.body(
                    f == null ? DsColors.textDisabled : DsColors.text)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn('-', const ValueKey('ds-qty-minus'),
              value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 48,
            child: Text('$value',
                key: const ValueKey('ds-qty-value'),
                textAlign: TextAlign.center,
                style: DsText.body(DsColors.text)),
          ),
          _btn('+', const ValueKey('ds-qty-plus'),
              value < max ? () => onChanged(value + 1) : null),
        ],
      );
}
