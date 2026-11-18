import 'package:material_ui/material_ui.dart';

import '../theme/proto_colors.dart';
import '../theme/retro_text.dart';
import '../theme/retro_theme.dart';
import 'pixel_icon.dart';

/// Sección enmarcada de un menú: franja de encabezado (ícono + título +
/// una línea de explicación) y el contenido debajo, separada de las demás.
class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.color = ProtoColors.gold,
    this.trailing,
  });

  final PixelIconKind icon;
  final String title;
  final String? subtitle;
  final Color color;
  final List<Widget> children;

  /// A la derecha de la franja (p. ej. las teclas).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ProtoColors.bg.withValues(alpha: 0.35),
        border: Border.all(
            color: ProtoColors.panelBorder, width: RetroTheme.thinBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: ProtoColors.button.withValues(alpha: 0.7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: PixelIcon(icon,
                      size: RetroType.width(context, 16), color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: retroText(title),
                        style: TextStyle(
                            fontFamily: RetroType.pixelFamily,
                            fontSize: RetroType.label,
                            height: RetroType.pixelLine,
                            color: color)),
                    if (subtitle != null)
                      TextSpan(
                          text: retroText('  $subtitle'),
                          style: const TextStyle(color: ProtoColors.sky)),
                  ])),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
