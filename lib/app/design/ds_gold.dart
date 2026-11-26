import 'package:material_ui/material_ui.dart';

import '../theme/retro_text.dart';
import '../widgets/pixel_icon.dart';
import 'ds_tokens.dart';

/// Átomo: monto de oro (design_system.md § 6, DsGold). Moneda pixel a la
/// izquierda del número, en el color de recompensa; rojo si no alcanza.
/// El arte es el sprite `ui.icono_oro` del manifest (procedural 8×8).
class DsGold extends StatelessWidget {
  const DsGold(this.amount,
      {super.key, this.affordable = true, this.style, this.iconSize});

  /// Id del sprite en `sprite_manifest.yaml` (sección `ui`).
  static const spriteId = 'ui.icono_oro.idle';

  /// Key de la moneda (tests).
  static const coinKey = ValueKey('ds-gold-coin');

  final int amount;
  final bool affordable;

  /// Estilo del número (por defecto Cuerpo).
  final TextStyle? style;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final st = style ?? DsText.body(affordable ? null : DsColors.danger);
    return Text.rich(
      TextSpan(children: [
        DsGoldText.coinSpan(st, iconSize),
        TextSpan(text: '$amount'),
      ]),
      maxLines: 1,
      style: st,
    );
  }
}

/// Molécula: texto donde cada `₵N` se dibuja como [DsGold] (moneda + N).
/// El resto pasa por `retroText` como cualquier texto de la UI.
class DsGoldText extends StatelessWidget {
  const DsGoldText(this.text,
      {super.key, this.style, this.maxLines, this.textAlign});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;

  /// El texto tiene un monto de oro.
  static bool hasGold(String s) => s.contains('₵');

  /// La moneda como `WidgetSpan`, del alto de la fuente de [st].
  static InlineSpan coinSpan(TextStyle? st, [double? size]) {
    final fs = st?.fontSize ?? 11;
    final sz = size ?? (fs < 8 ? 8.0 : fs.roundToDouble());
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: EdgeInsets.only(right: DsSpace.xs / 2),
        child: SizedBox.square(
          dimension: sz < 8 ? 8 : sz,
          child: Center(
              child: PixelIcon(PixelIconKind.coin,
                  key: DsGold.coinKey,
                  size: sz < 8 ? 8 : sz,
                  color: DsColors.reward)),
        ),
      ),
    );
  }

  /// Spans de [s]: cada `₵` es una moneda; lo demás, texto.
  static List<InlineSpan> spans(String s, TextStyle? st) {
    final parts = s.split('₵');
    return [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0) coinSpan(st),
        if (parts[i].isNotEmpty) TextSpan(text: retroText(parts[i])),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final st = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(TextSpan(children: spans(text, st)),
        style: style, maxLines: maxLines, textAlign: textAlign);
  }
}
