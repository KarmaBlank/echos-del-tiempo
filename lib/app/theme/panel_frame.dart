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
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;

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
class PanelButton extends StatelessWidget {
  const PanelButton(this.label, {super.key, this.onPressed, this.accent});

  final String label;
  final VoidCallback? onPressed;

  /// Color de texto alternativo (p. ej. verde para "¡LISTO!").
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: RetroTheme.compactButton().copyWith(
        foregroundColor: accent == null || onPressed == null
            ? null
            : WidgetStatePropertyAll(accent),
      ),
      onPressed: onPressed,
      child: Text(retroText(label)),
    );
  }
}

/// Aviso de lo que todavía no existe (fase 5).
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
