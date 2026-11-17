import 'package:material_ui/material_ui.dart';

import 'retro_theme.dart';

/// Caja de diálogo estilo JRPG clásico (ver docs/specs/ui_style.md §
/// "Caja de diálogo"): fondo `panel`, borde exterior `ink`, línea
/// interior `night` y sombra dura desplazada, sin difuminado.
class RetroPanel extends StatelessWidget {
  const RetroPanel({
    super.key,
    required this.child,
    this.selected = false,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;

  /// Borde dorado: el panel tiene el foco o está seleccionado.
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RetroPalette.panel,
        border: Border.all(
          color: selected ? RetroPalette.gold : RetroPalette.ink,
          width: RetroTheme.borderWidth,
        ),
        boxShadow: const [
          BoxShadow(color: RetroPalette.panelDark, offset: Offset(4, 4)),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(
            color: RetroPalette.night,
            width: RetroTheme.thinBorderWidth,
          ),
        ),
        child: child,
      ),
    );
  }
}
