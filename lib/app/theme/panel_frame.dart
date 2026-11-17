import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';
import 'proto_markup.dart';
import 'retro_panel.dart';
import 'retro_text.dart';
import 'retro_theme.dart';

/// Marco común de los paneles sobre el mapa (`#board` del prototipo):
/// `RetroPanel` centrado, título de 16 px, contenido con scroll y una
/// fila de botones compactos abajo a la derecha. Ver
/// docs/specs/ui_style.md § "Panel sobre el mapa".
class PanelFrame extends StatelessWidget {
  const PanelFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.width = 760,
    this.header,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;

  /// Fila fija entre el título y el contenido con scroll (p. ej. pestañas).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall!;
    return LayoutBuilder(
      builder: (context, box) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width.clamp(0, box.maxWidth - 32),
            maxHeight: box.maxHeight * 0.86,
          ),
          child: RetroPanel(
            // `.panel`: borde `#5b74c9`.
            child: DefaultTextStyle.merge(
              style: small.copyWith(height: 1.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(retroText(title),
                      style: const TextStyle(
                          fontSize: 16, color: ProtoColors.gold)),
                  const SizedBox(height: 16),
                  if (header != null) ...[header!, const SizedBox(height: 8)],
                  Flexible(child: SingleChildScrollView(child: child)),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón compacto del tema (8 px). [onPressed] `null` = deshabilitado.
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
        side: const WidgetStatePropertyAll(BorderSide(
            color: ProtoColors.gold, width: RetroTheme.thinBorderWidth)),
      );
    }
    final button = ElevatedButton(
      style: style,
      onPressed: enabled,
      child: Text(retroText(label)),
    );
    if (reason == null) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sin `Flexible`: el botón suele ir en filas de ancho libre.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(retroText(reason!),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 8, color: ProtoColors.dim)),
        ),
        const SizedBox(width: 8),
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

/// Subtítulo de una sección de panel (`h2` de 10 px del prototipo, acá
/// 8 px): `#ffd166`, margen de arriba.
class PanelSection extends StatelessWidget {
  const PanelSection(this.title, {super.key, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(retroText(title),
              style: const TextStyle(color: ProtoColors.gold)),
          const SizedBox(height: 8),
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
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(8),
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
/// `#ffd166` de 2 px, padding 8×10, texto de 8 px `#e8ecff` con
/// interlineado 1.8, ancho máximo 360 y sombra. [message] es markup
/// (`<b>` dorado, `class="k"` `#9fb4ff`, `<span style="color:...">`).
class RetroTooltip extends StatelessWidget {
  const RetroTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  static const textStyle = TextStyle(
      fontFamily: RetroTheme.fontFamily,
      fontSize: 8,
      height: 1.8,
      color: ProtoColors.ink);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      richMessage: protoSpan(message, boldColor: ProtoColors.gold),
      waitDuration: Duration.zero,
      exitDuration: Duration.zero,
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ProtoColors.bg.withValues(alpha: 0xF5 / 0xFF),
        border: Border.all(
            color: ProtoColors.gold, width: RetroTheme.thinBorderWidth),
        boxShadow: const [
          BoxShadow(
              color: Color(0xAA000000), offset: Offset(0, 4), blurRadius: 18),
        ],
      ),
      textStyle: textStyle,
      child: child,
    );
  }
}

/// Pestañas de un panel: una fila de [PanelButton] con la elegida en
/// `gold`.
class PanelTabs extends StatelessWidget {
  const PanelTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          PanelButton(labels[i],
              key: ValueKey('tab-$i'),
              selected: i == index,
              accent: i == index ? RetroPalette.gold : null,
              onPressed: () => onChanged(i)),
      ],
    );
  }
}
