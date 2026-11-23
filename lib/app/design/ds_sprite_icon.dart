import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'ds_tokens.dart';

/// Átomo: un sprite chico (ícono de ítem) en pixel art, escalado entero
/// sin suavizar, en una casilla de [size] px. Sin imagen dibuja una
/// casilla hundida vacía (quien lo usa elige el sprite; acá no hay
/// lógica de juego).
class DsSpriteIcon extends StatelessWidget {
  const DsSpriteIcon(this.image, {super.key, this.size = 24});

  final ui.Image? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final img = image;
    return SizedBox.square(
      dimension: size,
      child: img == null
          ? Container(
              decoration: BoxDecoration(
                  color: DsColors.surfaceSunken,
                  border: Border.all(color: DsColors.border)))
          : RawImage(
              image: img,
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none),
    );
  }
}
