import 'package:material_ui/material_ui.dart';

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
            selected: true,
            child: DefaultTextStyle.merge(
              style: small,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(retroText(title),
                      style: const TextStyle(
                          fontSize: 16, color: RetroPalette.gold)),
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
/// `muted` a su izquierda (docs/specs/panels.md § "Botones con motivo").
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
            color: RetroPalette.gold, width: RetroTheme.thinBorderWidth)),
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
              style: const TextStyle(fontSize: 8, color: RetroPalette.muted)),
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
          style: const TextStyle(color: RetroPalette.muted)),
    );
  }
}

/// Subtítulo de una sección de panel (`h2` chico del prototipo): 8 px
/// `gold` con una línea `night` debajo.
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
          Container(
            padding: const EdgeInsets.only(bottom: 4),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: RetroPalette.night,
                    width: RetroTheme.thinBorderWidth),
              ),
            ),
            child: Text(retroText(title),
                style: const TextStyle(color: RetroPalette.gold)),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Fila enmarcada de una lista (`.mrow`): borde `night` de 2 px, padding
/// 8, contenido a la izquierda y [trailing] a la derecha.
class PanelRow extends StatelessWidget {
  const PanelRow({super.key, required this.child, this.trailing, this.tooltip});

  final Widget child;
  final Widget? trailing;

  /// Detalle al pasar el mouse (`data-tip` del prototipo).
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
            color: RetroPalette.night, width: RetroTheme.thinBorderWidth),
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

/// Tooltip del tema (`#tip` del prototipo): caja `night` con borde `gold`
/// y texto de 8 px.
class RetroTooltip extends StatelessWidget {
  const RetroTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: retroText(message),
      waitDuration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: RetroPalette.night,
        border: Border.all(
            color: RetroPalette.gold, width: RetroTheme.thinBorderWidth),
      ),
      textStyle: const TextStyle(
          fontFamily: RetroTheme.fontFamily,
          fontSize: 8,
          height: 1.8,
          color: RetroPalette.ink),
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
