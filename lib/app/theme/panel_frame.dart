import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/points_badge.dart';
import 'proto_colors.dart';
import 'proto_markup.dart';
import 'retro_hover_card.dart';
import 'retro_panel.dart';
import 'retro_text.dart';
import 'retro_theme.dart';
import 'ui_theme.dart';

/// Marco común de los paneles sobre el mapa (`#board` del prototipo):
/// `RetroPanel` centrado, título de 16 px con la ayuda `[?]`, contenido
/// con scroll y los botones compactos abajo (secundarios a la izquierda
/// en [leading], el resto a la derecha con el primario último). Atrapa
/// el foco del teclado: `Esc` cierra ([onClose]), `Tab` / flechas mueven
/// el foco y `Enter` / `Espacio` activan. Ver docs/specs/ui_style.md §
/// "Panel sobre el mapa" y docs/specs/panels.md § "Marco común".
class PanelFrame extends StatelessWidget {
  const PanelFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.leading = const [],
    this.width = 760,
    this.header,
    this.help,
    this.titleTrailing,
    this.onClose,
    this.fill = false,
  });

  final String title;
  final Widget child;

  /// Botones de abajo a la derecha; el último es el primario.
  final List<Widget> actions;

  /// Botones de abajo a la izquierda (reiniciar, cancelar misión...).
  final List<Widget> leading;
  final double width;

  /// Fila fija entre el título y el contenido con scroll (p. ej. pestañas).
  final Widget? header;

  /// Ayuda de la pantalla (markup) en el `[?]` junto al título.
  final String? help;

  /// Algo a la derecha del título (p. ej. los créditos).
  final Widget? titleTrailing;

  /// `Esc` cierra el panel. Sin [onClose] el `Esc` sigue de largo.
  final VoidCallback? onClose;

  /// Ocupa el alto máximo y [child] llena el espacio sin scroll propio
  /// (para lista + detalle con scroll cada uno).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall!;
    return LayoutBuilder(
      builder: (context, box) {
        final maxH = box.maxHeight * 0.86;
        final column = Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // El título toma lo que necesita; lo de la derecha queda
                // pegado al borde.
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(retroText(title),
                            style: TextStyle(
                                fontFamily: RetroType.titleFamily,
                                fontSize: RetroType.title,
                                color: ProtoColors.title)),
                      ),
                      if (help != null) ...[
                        const SizedBox(width: 12),
                        _HelpChip(help!),
                      ],
                    ],
                  ),
                ),
                if (titleTrailing != null) ...[
                  const SizedBox(width: 16),
                  titleTrailing!,
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (header != null) ...[header!, const SizedBox(height: 8)],
            if (fill)
              Expanded(child: child)
            else
              Flexible(child: SingleChildScrollView(child: child)),
            if (actions.isNotEmpty || leading.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: leading),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: actions,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Con texto más grande el panel se ensancha (hasta la
              // pantalla); el alto queda igual y el contenido scrollea.
              maxWidth:
                  RetroType.width(context, width).clamp(0, box.maxWidth - 32),
              maxHeight: maxH,
            ),
            child: _PanelKeys(
              onClose: onClose,
              child: SizedBox(
                height: fill ? maxH : null,
                child: RetroPanel(
                  // `.panel`: borde `#5b74c9`.
                  child: DefaultTextStyle.merge(
                    style: small.copyWith(height: RetroType.line),
                    child: column,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `[?]` del título: la ayuda en un [RetroTooltip].
class _HelpChip extends StatelessWidget {
  const _HelpChip(this.help);

  final String help;

  @override
  Widget build(BuildContext context) {
    return RetroTooltip(
      message: help,
      child: Container(
        key: const ValueKey('panel-help'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(
              color: ProtoColors.buttonBorder,
              width: RetroTheme.thinBorderWidth),
        ),
        child: Text('?',
            style: TextStyle(
                fontFamily: RetroType.titleFamily,
                fontSize: RetroType.label,
                color: ProtoColors.sky)),
      ),
    );
  }
}

/// Teclado común de los paneles. Un [FocusScope] que se enfoca solo al
/// abrir el panel: así `Tab` no se escapa al chat ni al mapa.
class _PanelKeys extends StatefulWidget {
  const _PanelKeys({required this.child, this.onClose});

  final Widget child;
  final VoidCallback? onClose;

  @override
  State<_PanelKeys> createState() => _PanelKeysState();
}

class _PanelKeysState extends State<_PanelKeys> {
  final _scope = FocusScopeNode(debugLabel: 'panel');

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  static final _dirs = {
    LogicalKeyboardKey.arrowUp: TraversalDirection.up,
    LogicalKeyboardKey.arrowDown: TraversalDirection.down,
    LogicalKeyboardKey.arrowLeft: TraversalDirection.left,
    LogicalKeyboardKey.arrowRight: TraversalDirection.right,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus;
    final ctx = focused?.context;
    // Escribiendo en un campo: las teclas son del campo.
    if (ctx != null &&
        ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      if (widget.onClose == null || e is! KeyDownEvent) {
        return KeyEventResult.ignored;
      }
      widget.onClose!();
      return KeyEventResult.handled;
    }
    final inside = focused != null && focused != _scope;
    if (k == LogicalKeyboardKey.tab) {
      // Ctrl+Tab cambia de pestaña (`MenuTabKeys`, afuera del marco).
      if (HardwareKeyboard.instance.isControlPressed) {
        return KeyEventResult.ignored;
      }
      final back = HardwareKeyboard.instance.isShiftPressed;
      final from = inside ? focused : _scope;
      back ? from.previousFocus() : from.nextFocus();
      return KeyEventResult.handled;
    }
    if (_dirs[k] case final dir?) {
      // Ctrl+←/→ cambia de miembro de la party (`PartyMemberKeys`, afuera
      // del marco; solo_party.md § 6.2).
      if (HardwareKeyboard.instance.isControlPressed) {
        return KeyEventResult.ignored;
      }
      if (!inside) {
        _scope.nextFocus();
      } else if (!focused.focusInDirection(dir)) {
        dir == TraversalDirection.up || dir == TraversalDirection.left
            ? focused.previousFocus()
            : focused.nextFocus();
      }
      return KeyEventResult.handled;
    }
    if (inside &&
        e is KeyDownEvent &&
        (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space)) {
      Actions.maybeInvoke(ctx!, const ActivateIntent());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _scope,
      autofocus: true,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}

/// Botón compacto del tema ([RetroType.small]). [onPressed] `null` = deshabilitado.
///
/// Con [reason] el botón queda deshabilitado y el motivo se escribe en
/// `dim` a su izquierda (docs/specs/panels.md § "Botones con motivo").
/// [selected] pinta el borde `gold` (opción elegida de una lista).
class PanelButton extends StatelessWidget {
  const PanelButton(
    this.label, {
    super.key,
    this.onPressed,
    this.accent,
    this.reason,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Color de texto alternativo (p. ej. verde para "¡LISTO!").
  final Color? accent;

  /// Por qué no se puede: deshabilita el botón y se muestra al lado.
  final String? reason;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = reason == null ? onPressed : null;
    var style = RetroTheme.compactButton().copyWith(
      foregroundColor: accent == null || enabled == null
          ? null
          : WidgetStatePropertyAll(accent),
    );
    if (selected) {
      style = style.copyWith(
        side: WidgetStatePropertyAll(BorderSide(
            color: ProtoColors.gold, width: UiTheme.buttonBorderWidth)),
      );
    }
    final button = ElevatedButton(
      style: style,
      onPressed: enabled,
      child: Text(retroText(label)),
    );
    if (reason == null) return button;
    // Con texto ENORME el motivo va arriba del botón (al lado no entra).
    final big = RetroType.settingFactor(context) >= 1.9;
    return Flex(
      direction: big ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          big ? CrossAxisAlignment.end : CrossAxisAlignment.center,
      children: [
        // Sin `Flexible`: el botón suele ir en filas de ancho libre.
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: RetroType.width(context, 220)),
          child: Text(retroText(reason!),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontFamily: RetroType.bodyFamily,
                  letterSpacing: RetroType.letterSpacing,
                  fontFamilyFallback: RetroType.bodyFallback,
                  fontSize: RetroType.small,
                  color: ProtoColors.dim)),
        ),
        const SizedBox(width: 8, height: 4),
        button,
      ],
    );
  }
}

/// Aviso de lo que todavía no existe.
class ComingSoon extends StatelessWidget {
  const ComingSoon(this.what, {super.key});

  final String what;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(retroText('$what: próximamente.'),
          style: const TextStyle(color: ProtoColors.dim)),
    );
  }
}

/// Subtítulo de una sección de panel (`h2` de 10 px del prototipo,
/// [RetroType.small]): `#ffd166`, margen de arriba.
class PanelSection extends StatelessWidget {
  const PanelSection(this.title, {super.key, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: UiTheme.space(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AMPLIO: un separador arriba de cada sección (§ 8.3).
          if (UiTheme.wide)
            Container(
                height: 1,
                margin: const EdgeInsets.only(bottom: 8),
                color: ProtoColors.panelBorder),
          Text(retroText(title),
              style: const TextStyle(color: ProtoColors.title)),
          SizedBox(height: UiTheme.space(8)),
          child,
        ],
      ),
    );
  }
}

/// Fila enmarcada de una lista (`.mrow`): borde `#2e3b6b` de 2 px,
/// padding 8, contenido a la izquierda y [trailing] a la derecha.
class PanelRow extends StatelessWidget {
  const PanelRow({super.key, required this.child, this.trailing, this.tooltip});

  final Widget child;
  final Widget? trailing;

  /// Detalle al pasar el mouse (`data-tip` del prototipo), en markup
  /// (`ProtoMarkup`).
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget row = Container(
      margin: EdgeInsets.symmetric(vertical: UiTheme.space(6)),
      padding: EdgeInsets.all(UiTheme.space(8)),
      decoration: BoxDecoration(
        border: Border.all(
            color: ProtoColors.panelBorder, width: RetroTheme.thinBorderWidth),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
    if (tooltip != null) row = RetroTooltip(message: tooltip!, child: row);
    return row;
  }
}

/// Tooltip `#tip` del prototipo: caja `#0b0e1a` (alfa `f5`) con borde
/// `#ffd166` de 2 px, padding 8×10, texto [RetroType.small] `#e8ecff` con
/// interlineado 1.6, ancho máximo [RetroHoverCard.textWidth] (crece con
/// el tamaño del texto) y sombra. [message] es markup (`<b>` dorado,
/// `class="k"` `#9fb4ff`, `<span style="color:...">`). Aparece debajo
/// (o arriba) sin espera, nunca se sale de la pantalla y, si es más alto
/// que ella, se reparte en columnas (docs/specs/ui_style.md § "Tooltips").
///
/// Tooltips cortos (v0.9.7, ui_style.md § "Tooltips cortos"): con
/// [foldAfter] solo se ven las primeras líneas y el resto queda plegado
/// en "▸ Más detalle" ([foldTitle]); la caja se fija al pasar el mouse
/// encima para poder desplegarlo.
class RetroTooltip extends StatelessWidget {
  const RetroTooltip(
      {super.key,
      required this.message,
      required this.child,
      this.foldAfter,
      this.foldTitle = 'Más detalle'});

  final String message;
  final Widget child;
  final int? foldAfter;
  final String foldTitle;

  static TextStyle get textStyle => RetroHoverCard.textStyle;

  /// (resumen, resto) de [message] cortado en la línea [n] (`<br>`);
  /// resto vacío si no hay más líneas.
  static (String, String) splitAt(String message, int n) {
    final lines = protoSplitLines(message);
    if (lines.length <= n) return (message, '');
    return (lines.take(n).join('<br>'), lines.skip(n).join('<br>'));
  }

  @override
  Widget build(BuildContext context) {
    final n = foldAfter;
    final parts = n == null ? null : splitAt(message, n);
    final fold = parts != null && parts.$2.isNotEmpty;
    return RetroHoverCard(
      placement: RetroTipPlacement.below,
      gap: 4,
      interactive: fold,
      builder: (ctx) {
        final w = RetroType.width(ctx, RetroHoverCard.textWidth);
        if (!fold) return RetroTipText(message, maxWidth: w);
        return RetroTipFolds(
            summary: parts.$1, sections: [(foldTitle, parts.$2)], maxWidth: w);
      },
      child: child,
    );
  }
}

/// Pestañas de un panel: una fila de [PanelButton] con la elegida en
/// `gold`. [badges]: insignia `+N` (quieta) sobre la pestaña `i`, p. ej.
/// puntos sin usar en ÁRBOL / ATRIBUTOS (passive_tree_v4.md § 7).
class PanelTabs extends StatelessWidget {
  const PanelTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.badges = const {},
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    Widget tab(int i) {
      final button = PanelButton(labels[i],
          key: ValueKey('tab-$i'),
          selected: i == index,
          accent: i == index ? RetroPalette.gold : null,
          onPressed: () => onChanged(i));
      final n = badges[i] ?? 0;
      if (n <= 0) return button;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -13,
            right: -8,
            child: IgnorePointer(
                child: PointsBadge(
                    key: ValueKey('tab-badge-$i'), count: n, pulse: false)),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (var i = 0; i < labels.length; i++) tab(i)],
    );
  }
}
