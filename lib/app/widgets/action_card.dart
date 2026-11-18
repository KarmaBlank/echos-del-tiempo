import 'package:material_ui/material_ui.dart';

import '../theme/proto_colors.dart';
import '../theme/proto_markup.dart';
import '../theme/retro_text.dart';
import '../theme/retro_theme.dart';
import 'cost_chip.dart';
import 'menu_focus.dart';
import 'pixel_icon.dart';

/// Tarjeta elegible de un menú (acciones de la fusión, armas…): ícono en
/// una cajita, título en negrita, 1-2 líneas de explicación y un pie (el
/// [CostChip] o lo que sea). Con mouse / foco se levanta 2 px con borde
/// `sky` y, si hay [preview], la explicación muestra el efecto
/// (`Mods 4/6 → 5/6`); elegida = borde `gold`; [disabled] = atenuada con
/// candado (sigue elegible para ver el motivo). [band] pinta una franja de
/// color a la izquierda con [bandLabel] (p. ej. la rareza). [badge] es un
/// hueco arriba a la derecha (p. ej. `BuildFitBadge`). Clic / `Enter` /
/// `Espacio` = [onTap]; las flechas mueven el foco entre tarjetas
/// (`PanelFrame`) y el foco de teclado dibuja el aro dorado ([FocusRing]).
/// Con [reason] queda bloqueada y, si no hay [footer], el pie es el
/// candado con el motivo completo ([CostChip.blocked]).
class ActionCard extends StatefulWidget {
  const ActionCard({
    super.key,
    required this.title,
    required this.onTap,
    this.icon,
    this.description,
    this.preview,
    this.footer,
    this.selected = false,
    this.disabled = false,
    this.band,
    this.bandLabel,
    this.badge,
    this.reason,
    this.autofocus = false,
    this.focusNode,
  });

  /// Por qué no se puede (bloquea la tarjeta y se lee entero en el pie).
  final String? reason;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Markup.
  final String title;
  final Widget? icon;

  /// Markup, `dim`.
  final String? description;

  /// Markup, `sky`: reemplaza a [description] con mouse / foco.
  final String? preview;
  final Widget? footer;
  final bool selected;
  final bool disabled;
  final Color? band;
  final String? bandLabel;
  final Widget? badge;
  final VoidCallback onTap;

  @override
  State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
  bool _hover = false, _focus = false;

  bool get _hot => _hover || _focus;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final border = w.selected
        ? ProtoColors.gold
        : _hot
            ? ProtoColors.sky
            : ProtoColors.panelBorder;
    final disabled = w.disabled || w.reason != null;
    final footer =
        w.footer ?? (w.reason == null ? null : CostChip.blocked(w.reason!));
    final fade = disabled ? 0.55 : 1.0;
    final showPreview = _hot && w.preview != null;
    final text = showPreview ? w.preview : w.description;
    final iconBox = RetroType.width(context, 36);
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (w.icon != null) ...[
          Opacity(
            opacity: fade,
            child: Container(
              width: iconBox,
              height: iconBox,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ProtoColors.input,
                border: Border.all(
                    color: ProtoColors.buttonBorder,
                    width: RetroTheme.thinBorderWidth),
              ),
              child: w.icon,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Opacity(
                      opacity: fade,
                      child: ProtoText(w.title),
                    ),
                  ),
                  if (disabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: PixelIcon(PixelIconKind.lock,
                          size: RetroType.width(context, 16),
                          color: ProtoColors.dim),
                    ),
                  if (w.badge != null) ...[const SizedBox(width: 4), w.badge!],
                ],
              ),
              if (text != null)
                ProtoText(text,
                    style: TextStyle(
                        color:
                            showPreview ? ProtoColors.sky : ProtoColors.dim)),
              if (footer != null) ...[
                const SizedBox(height: 4),
                footer,
              ],
            ],
          ),
        ),
      ],
    );
    return FocusableActionDetector(
      autofocus: w.autofocus,
      focusNode: w.focusNode,
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {
        ActivateIntent:
            CallbackAction<ActivateIntent>(onInvoke: (_) => w.onTap()),
      },
      // El mouse con un MouseRegion propio: se levanta siempre (no depende
      // del modo de resaltado del foco).
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: w.onTap,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Transform.translate(
              offset: Offset(0, _hot ? -2 : 0),
              child: FocusRing(
                focused: _focus,
                pointer: false,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  decoration: BoxDecoration(
                    color: w.selected
                        ? ProtoColors.button.withValues(alpha: 0.75)
                        : _hot
                            ? ProtoColors.buttonHover.withValues(alpha: 0.5)
                            : ProtoColors.panel,
                    border: Border.all(
                        color: border,
                        width: w.selected || _hot
                            ? 3
                            : RetroTheme.thinBorderWidth),
                    boxShadow: _hot
                        ? const [
                            BoxShadow(
                                color: Color(0xAA000000), offset: Offset(0, 3))
                          ]
                        : null,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (w.band != null)
                          Container(
                            width: RetroType.width(context, 18),
                            color: w.band,
                            alignment: Alignment.center,
                            child: w.bandLabel == null
                                ? null
                                : Text(retroText(w.bandLabel!),
                                    style: const TextStyle(
                                        fontFamily: RetroType.pixelFamily,
                                        fontSize: RetroType.label,
                                        color: ProtoColors.bg)),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grilla adaptable: tantas columnas de al menos [minWidth] (crece con
/// el texto) como entren, todas del mismo ancho.
class CardGrid extends StatelessWidget {
  const CardGrid(
      {super.key, required this.children, this.minWidth = 240, this.gap = 8});

  final List<Widget> children;
  final double minWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final min = RetroType.width(context, minWidth);
      final w = box.maxWidth;
      final cols = ((w + gap) / (min + gap)).floor().clamp(1, 99);
      final cw = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        children: [
          for (final c in children) SizedBox(width: cw, child: c),
        ],
      );
    });
  }
}

/// Botón grande de confirmar con su costo al lado del verbo (p. ej.
/// `TRAER HABILIDAD` + el chip de costo). Con [reason] queda deshabilitado
/// y el motivo se lee entero arriba, en rojo.
class ConfirmButton extends StatelessWidget {
  const ConfirmButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.reason,
    this.cost,
  });

  final String label;
  final VoidCallback onPressed;
  final String? reason;
  final Widget? cost;

  @override
  Widget build(BuildContext context) {
    final enabled = reason == null;
    final button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: enabled ? ProtoColors.button : ProtoColors.panel,
        side: BorderSide(
            color: enabled ? ProtoColors.green : ProtoColors.panelBorder,
            width: 3),
        shape: const RoundedRectangleBorder(),
      ),
      onPressed: enabled ? onPressed : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelIcon(enabled ? PixelIconKind.check : PixelIconKind.lock,
              size: RetroType.width(context, 16),
              color: enabled ? ProtoColors.green : ProtoColors.dim),
          const SizedBox(width: 8),
          Text(retroText(label),
              style: TextStyle(
                  fontFamily: RetroType.pixelFamily,
                  fontSize: RetroType.title,
                  color: enabled ? ProtoColors.green : ProtoColors.dim)),
          if (cost != null) ...[const SizedBox(width: 10), cost!],
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!enabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(retroText('No se puede: $reason'),
                textAlign: TextAlign.right,
                style: const TextStyle(color: ProtoColors.red)),
          ),
        button,
      ],
    );
  }
}
