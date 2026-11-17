import 'package:material_ui/material_ui.dart';

import 'retro_theme.dart';

/// Barra pixelada de vida/maná/ULT (docs/specs/ui_style.md § "Barras"):
/// fondo `night`, borde `ink` de 2 px y relleno sólido sin degradé.
class RetroBar extends StatelessWidget {
  const RetroBar({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    this.height = 16,
  });

  final num value;
  final num max;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = max <= 0 ? 0.0 : (value / max).clamp(0, 1).toDouble();
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: RetroPalette.night,
        border: Border.all(
            color: RetroPalette.ink, width: RetroTheme.thinBorderWidth),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: f,
          heightFactor: 1,
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}
