import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';
import 'ui_theme.dart';

/// Caja `.panel` del prototipo (ver docs/specs/ui_style.md § "Caja"):
/// fondo `#121936` opaco (el prototipo usa alfa `ee`), borde de 3 px `#5b74c9` (dorado
/// `#ffd166` si está seleccionada), esquinas rectas.
class RetroPanel extends StatelessWidget {
  const RetroPanel({
    super.key,
    required this.child,
    this.selected = false,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.borderWidth,
  });

  final Widget child;

  /// Borde dorado: el panel tiene el foco o está seleccionado.
  final bool selected;
  final EdgeInsetsGeometry padding;

  /// Borde propio (gana sobre [selected]).
  final Color? borderColor;
  /// `null`: el del tema (3 px; 4 en ALTO CONTRASTE).
  final double? borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        // Opaco (v0.5.1): con el alfa `ee` del prototipo se leía el texto
        // del mapa detrás de los menús.
        color: ProtoColors.panel,
        border: Border.all(
          color: borderColor ??
              (selected ? ProtoColors.gold : ProtoColors.buttonBorder),
          width: borderWidth ?? UiTheme.panelBorderWidth,
        ),
      ),
      child: child,
    );
  }
}
