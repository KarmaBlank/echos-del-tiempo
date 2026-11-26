import 'package:material_ui/material_ui.dart';

import '../design/ds_tokens.dart';
import '../theme/proto_colors.dart';
import '../theme/retro_text.dart';
import '../theme/retro_theme.dart';
import 'pixel_icon.dart';

/// Una parte de un costo: ícono, texto (`50`, `1 Esquirla`) y si alcanza.
class CostPart {
  const CostPart(this.icon, this.text,
      {this.iconColor = ProtoColors.gold, this.ok = true});

  final PixelIconKind icon;
  final Color iconColor;
  final String text;
  final bool ok;
}

/// Chip de costo al pie de una tarjeta: `[moneda 50] [esquirla 1 Esquirla]`
/// con el borde y el texto en verde si alcanza todo, en rojo lo que falta.
/// [CostChip.blocked] muestra un candado y el motivo (completo, en varias
/// líneas si hace falta); [CostChip.note] un texto neutro.
class CostChip extends StatelessWidget {
  const CostChip(this.parts, {super.key})
      : reason = null,
        note = null;

  const CostChip.blocked(String this.reason, {super.key})
      : parts = const [],
        note = null;

  const CostChip.note(String this.note, {super.key})
      : parts = const [],
        reason = null;

  final List<CostPart> parts;
  final String? reason;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final icon = RetroType.width(context, 16);
    Color border;
    Widget child;
    if (reason != null) {
      // Bloqueado = gris, como todo lo deshabilitado (no es un error).
      border = ProtoColors.dim;
      child = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: PixelIcon(PixelIconKind.lock,
                size: icon, color: ProtoColors.dim),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(retroText(reason!),
                style: const TextStyle(color: DsColors.textMuted)),
          ),
        ],
      );
    } else if (note != null || parts.isEmpty) {
      border = ProtoColors.panelBorder;
      child = Text(retroText(note ?? 'Gratis'),
          style: TextStyle(
              color: note == null ? ProtoColors.green : ProtoColors.sky));
    } else {
      final ok = parts.every((p) => p.ok);
      border = ok ? ProtoColors.green : ProtoColors.red;
      child = Wrap(
        spacing: 10,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final p in parts)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PixelIcon(p.icon, size: icon, color: p.iconColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(retroText(p.text),
                      style: TextStyle(
                          color: p.ok ? ProtoColors.green : ProtoColors.red)),
                ),
              ],
            ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ProtoColors.bg.withValues(alpha: 0.6),
        border: Border.all(color: border, width: RetroTheme.thinBorderWidth),
      ),
      child: child,
    );
  }
}
