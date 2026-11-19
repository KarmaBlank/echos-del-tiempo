import 'package:material_ui/material_ui.dart';

import '../theme/panel_frame.dart';
import '../theme/proto_colors.dart';
import '../theme/retro_text.dart';
import '../theme/retro_theme.dart';
import 'menu_focus.dart';
import 'pixel_icon.dart';
import '../theme/ui_theme.dart';

/// Sección enmarcada de un menú: franja de encabezado (ícono + título +
/// una línea de explicación) y el contenido debajo, separada de las demás.
/// Es una [NavSection]: `Tab` salta de una sección a la siguiente.
class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.color = ProtoColors.title,
    this.trailing,
    this.titleKey,
    this.tooltip,
  });

  /// Tooltip (markup) de la franja del encabezado (mouse / foco adentro).
  final String? tooltip;

  /// Clave del título (pruebas).
  final Key? titleKey;

  final PixelIconKind icon;
  final String title;
  final String? subtitle;
  final Color color;
  final List<Widget> children;

  /// A la derecha de la franja (p. ej. las teclas).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return NavSection(
        child: Container(
      margin: EdgeInsets.only(bottom: UiTheme.space(10)),
      decoration: BoxDecoration(
        color: ProtoColors.bg.withValues(alpha: 0.35),
        border: Border.all(
            color: ProtoColors.panelBorder, width: RetroTheme.thinBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _withTip(Container(
            padding: EdgeInsets.symmetric(
                horizontal: UiTheme.space(8), vertical: UiTheme.space(4)),
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
                  child: Text.rich(
                      key: titleKey,
                      TextSpan(children: [
                        TextSpan(
                            text: retroText(title),
                            style: TextStyle(
                                fontFamily: RetroType.titleFamily,
                                fontSize: RetroType.label,
                                height: RetroType.titleLine,
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
          )),
          Padding(
            padding: EdgeInsets.all(UiTheme.space(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    ));
  }

  Widget _withTip(Widget header) => tooltip == null
      ? header
      : RetroTooltip(message: tooltip!, child: header);
}
