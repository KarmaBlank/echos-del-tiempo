import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';
import 'retro_bar.dart';
import 'retro_theme.dart';

/// Caja de un jugador (`.pbox` del prototipo, docs/specs/ui_style.md §
/// "Caja de jugador"): fondo `#121936`, borde 2 px `#2e3b6b` (`#ffd166`
/// el jugador local), padding 6, texto [RetroType.small] con interlineado
/// 1.6, ancho [defaultWidth] agrandado con el tamaño del texto y
/// opacidad 0.5 si está K.O. El contenido lo arma quien la usa (HUD del
/// mapa o batalla).
class PartyBox extends StatelessWidget {
  const PartyBox({
    super.key,
    required this.children,
    this.local = false,
    this.knockedOut = false,
    this.width,
  });

  /// 170 px en el HTML con texto de 7-8 px; acá el texto mínimo es 10
  /// (en Normal; crece con el tamaño del texto, ver [widthOf]).
  static const defaultWidth = 230.0;

  /// Ancho de una caja con el tamaño del texto de [context].
  static double widthOf(BuildContext context) =>
      RetroType.width(context, defaultWidth);

  final List<Widget> children;
  final bool local;
  final bool knockedOut;

  /// Ancho fijo; `null` = [widthOf].
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: knockedOut ? 0.5 : 1,
      child: Container(
        width: width ?? PartyBox.widthOf(context),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: ProtoColors.panel,
          border: Border.all(
            color: local ? ProtoColors.gold : ProtoColors.panelBorder,
            width: 2,
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
              fontFamily: RetroType.bodyFamily,
              letterSpacing: RetroType.letterSpacing,
              fontFamilyFallback: RetroType.bodyFallback,
              fontSize: RetroType.small,
              height: RetroType.line,
              color: ProtoColors.ink),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// `bar('hp', ...)`: barra de vida `#2ed573` de 6 px.
Widget hpBar(num value, num max) =>
    RetroBar(value: value, max: max, color: ProtoColors.hp);

/// `bar('mp', ...)`: barra de maná `#1e90ff` de 6 px.
Widget mpBar(num value, num max) =>
    RetroBar(value: value, max: max, color: ProtoColors.mp);

/// Barra de ULT de 5 px: `#a29bfe` cargando, `#e84393` al 100%.
Widget ultBar(double ult) => RetroBar(
    value: ult.floorToDouble(),
    max: 100,
    height: 5,
    color: ult >= 100 ? ProtoColors.pink : ProtoColors.violet);
