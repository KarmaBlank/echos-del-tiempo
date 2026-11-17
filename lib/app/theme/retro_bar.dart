import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';

/// Barra `.bar` del prototipo (docs/specs/ui_style.md § "Barras"): fondo
/// `#222a48`, sin borde, relleno sólido sin degradé.
class RetroBar extends StatelessWidget {
  const RetroBar({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    this.height = 6,
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
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: ProtoColors.barBg,
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
