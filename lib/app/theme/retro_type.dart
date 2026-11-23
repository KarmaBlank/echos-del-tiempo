import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/settings/game_settings.dart' show ReadingFont;
import 'ui_theme.dart';

/// Escala tipográfica de la UI (docs/specs/ui_style.md § "Tipografía").
///
/// Dos papeles:
/// - **Texto de lectura** ([bodyFamily]): tooltips, fichas, chat,
///   descripciones, ayudas, log y menú de batalla, HUD. Tokens [small] /
///   [body]. VT323 por defecto; Press Start 2P en CLÁSICA; Atkinson
///   Hyperlegible en ATKINSON (accessibility.md § 9).
/// - **Títulos** ([titleFamily]): títulos, botones, pestañas, cifras de
///   las barras y etiquetas cortas. Tokens [label], [title], [heading],
///   [display]. Press Start 2P, o la fuente de lectura con "Títulos con
///   la fuente de lectura" ([readingTitles]).
///
/// Los tamaños son **nominales**: [RetroTextScaler] (aplicado una sola vez
/// en `MaterialApp.builder` → [RetroTextScale]) los convierte al tamaño
/// real según el ajuste "Tamaño del texto" y la escala de la pantalla,
/// siempre en px enteros (Press Start 2P en su grilla de 8). Por eso el
/// tamaño nominal decide la grilla: [small] y [body] siempre van con
/// [bodyFamily]; el resto con [titleFamily]. Usar [style] / [familyFor]
/// para no mezclarlos.
abstract final class RetroType {
  /// "Fuente de lectura" (settings.md § 3.7). La pone `RetroTextScale`
  /// (ajuste del jugador); al cambiar, la app se reconstruye entera.
  static ReadingFont font = ReadingFont.vt323;

  /// "Fuente de lectura" CLÁSICA (Press Start 2P, como v0.4).
  static bool get classic => font == ReadingFont.classic;
  static set classic(bool v) =>
      font = v ? ReadingFont.classic : ReadingFont.vt323;

  /// "Títulos con la fuente de lectura" (accessibility.md § 9.2): títulos,
  /// botones y pestañas en [bodyFamily] en vez de Press Start 2P. Con
  /// CLÁSICA no cambia nada (ya es Press Start). Lo pone `RetroTextScale`.
  static bool readingTitles = false;

  /// "Espaciado entre letras" AMPLIO (accessibility.md § 9.4): +0.08 em
  /// en el texto de lectura. Lo pone `RetroTextScale`.
  static bool wideLetters = false;

  /// Tamaño real (px lógicos) del texto de lectura con el escalador
  /// activo; lo anota `RetroTextScale` para [letterSpacing].
  static double readingPx = 20;

  /// Densidad de la pantalla activa (para redondear [letterSpacing]).
  static double devicePixelRatio = 1;

  /// Vuelve los estáticos de texto a los de por defecto (tests).
  static void reset() {
    font = ReadingFont.vt323;
    readingTitles = false;
    wideLetters = false;
    readingPx = 20;
    devicePixelRatio = 1;
  }

  /// VT323 (`pubspec.yaml`).
  static const vt323Family = 'VT323';

  /// Atkinson Hyperlegible (`pubspec.yaml`, OFL).
  static const atkinsonFamily = 'AtkinsonHyperlegible';

  /// Familia del texto de lectura según [font].
  static String get bodyFamily => familyOf(font);

  /// Familia de lectura de [f].
  static String familyOf(ReadingFont f) => switch (f) {
        ReadingFont.vt323 => vt323Family,
        ReadingFont.classic => pixelFamily,
        ReadingFont.atkinson => atkinsonFamily,
      };

  /// Los títulos van en la fuente de lectura (no en Press Start 2P).
  static bool get titlesInReading => readingTitles && !classic;

  /// Familia de títulos, botones, pestañas y cifras: Press Start 2P, o la
  /// de lectura con [readingTitles].
  static String get titleFamily => titlesInReading ? bodyFamily : pixelFamily;

  /// Press Start 2P (`pubspec.yaml`). Las etiquetas del mundo, la banda
  /// del log de batalla, las cifras en casillas fijas y los símbolos
  /// ([glyph]) la usan siempre.
  static const pixelFamily = 'PressStart2P';

  /// Lo que a VT323 / Atkinson le falta (→ ★ ♥ ▶ ▲ ▼ ½ ♦) sale de Press
  /// Start 2P. Va en todo estilo que nombre [bodyFamily]: un `TextSpan`
  /// con familia propia no hereda el respaldo.
  static const bodyFallback = [pixelFamily];

  /// Texto de lectura. Mínimo legible: nada de cuerpo por debajo.
  /// Nominal: el real es [bodySize] × factor en px enteros.
  static const small = 10.0;

  /// Texto de lectura destacado (misma grilla que [small]). Nominal 11
  /// para no chocar con los 12 / 14 px de Press Start 2P.
  static const body = 11.0;

  /// Etiquetas cortas (botón compacto, cifras de las barras de batalla):
  /// 10 px buscados en la grilla de 8.
  static const label = 9.0;

  /// Símbolos de Press Start 2P dentro del texto de lectura (→ ★ ▲ …,
  /// `symbolSpans`): se escalan como [label] pero siempre en Press Start
  /// (también con [readingTitles]).
  static const glyph = 8.5;

  /// Títulos de panel (`h2`), botones grandes, avisos.
  static const title = 16.0;

  /// Encabezados de pantalla.
  static const heading = 24.0;

  /// Carteles (`¡VICTORIA!`, título del juego).
  static const display = 32.0;

  /// Tamaño real del texto de lectura en Normal a 100 % por fuente:
  /// VT323 a 20 px (mayúsculas de 11 px, 8 px por letra); CLÁSICA, el
  /// texto chico de Press Start (10); Atkinson a 18 px (mayúsculas de
  /// 12 px, ≈ 8 px por letra: entra en las mismas cajas que VT323).
  static double bodySizeOf(ReadingFont f) => switch (f) {
        ReadingFont.vt323 => 20.0,
        ReadingFont.classic => small,
        ReadingFont.atkinson => 18.0,
      };

  /// [bodySizeOf] de la fuente activa.
  static double get bodySize => bodySizeOf(font);

  /// Avance medio de cada letra (em): VT323 400 / 1000 (monoespaciada);
  /// Press Start 1; Atkinson ≈ 0.45 en texto corrido.
  static double get bodyAdvance => switch (font) {
        ReadingFont.vt323 => 0.4,
        ReadingFont.classic => 1.0,
        ReadingFont.atkinson => 0.45,
      };

  /// Avance de las letras de los títulos (casi siempre mayúsculas):
  /// Press Start 1; VT323 0.4; Atkinson ≈ 0.64.
  static double get titleAdvance => !titlesInReading
      ? 1.0
      : font == ReadingFont.atkinson
          ? 0.64
          : 0.4;

  /// Interlineado del texto de lectura (VT323: ascenso + descenso = 1 em;
  /// Press Start: 1.6; Atkinson: 1.2).
  /// ESPACIADO AMPLIO (accessibility.md § 8.3): 1.25 / 1.9 / 1.45.
  static double get line => switch (font) {
        ReadingFont.vt323 => UiTheme.wide ? 1.25 : 1.0,
        ReadingFont.classic => UiTheme.wide ? 1.9 : 1.6,
        ReadingFont.atkinson => UiTheme.wide ? 1.45 : 1.2,
      };

  /// Interlineado compacto (chips).
  static double get lineTight => switch (font) {
        ReadingFont.vt323 => 1.0,
        ReadingFont.classic => 1.3,
        ReadingFont.atkinson => 1.1,
      };

  /// Interlineado de Press Start 2P.
  static const pixelLine = 1.5;

  /// Interlineado de los títulos ([titleFamily]): 1.5 en Press Start;
  /// 1.0 en VT323, 1.15 en Atkinson.
  static double get titleLine => !titlesInReading
      ? pixelLine
      : font == ReadingFont.atkinson
          ? 1.15
          : 1.0;

  /// Espaciado entre letras del texto de lectura (px lógicos): `null`
  /// en NORMAL; en AMPLIO 0.08 em del tamaño real ([readingPx]) en px
  /// físicos enteros (mínimo 1).
  static double? get letterSpacing {
    if (!wideLetters) return null;
    final dpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    final phys = math.max(1.0, (readingPx * 0.08 * dpr).roundToDouble());
    return phys / dpr;
  }

  /// Familia que corresponde a un tamaño nominal.
  static String familyFor(double size) => isBody(size)
      ? bodyFamily
      : size == glyph
          ? pixelFamily
          : titleFamily;

  /// [size] es de texto de lectura.
  static bool isBody(double size) => size == small || size == body;

  /// Estilo con la familia y el interlineado de [size].
  static TextStyle style(double size,
          {Color? color, FontWeight? fontWeight, double? height}) =>
      TextStyle(
        fontFamily: familyFor(size),
        // VT323 / Atkinson no tienen → ★ ♥ ▶ ▲ ▼ ♦: los toman de Press
        // Start 2P.
        fontFamilyFallback:
            isBody(size) || titlesInReading ? bodyFallback : null,
        fontSize: size,
        height: height ?? (isBody(size) ? line : titleLine),
        letterSpacing: isBody(size) ? letterSpacing : null,
        color: color,
        fontWeight: fontWeight,
      );

  /// Estilo base del texto de lectura (sin color: lo hereda).
  static TextStyle get smallStyle => TextStyle(
      fontFamily: bodyFamily,
      fontFamilyFallback: bodyFallback,
      fontSize: small,
      height: line,
      letterSpacing: letterSpacing);

  /// Estilo de un título de [size] en [titleFamily] (sin interlineado
  /// propio salvo [height]).
  static TextStyle titleStyle(double size,
          {Color? color, double? height, List<Shadow>? shadows}) =>
      TextStyle(
          fontFamily: titleFamily,
          fontFamilyFallback: titlesInReading ? bodyFallback : null,
          fontSize: size,
          height: height,
          shadows: shadows,
          color: color);

  /// Cuánto más grande se ve el texto de lectura que en Normal a 100 %
  /// (1 = VT323 a 20 px). Para anchos de cajas.
  static double factorOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(small) / bodySize;

  /// Ancho de [n] caracteres de [size] ya escalado: Press Start 2P es
  /// monoespaciada (1 em por glifo), VT323 también (0.4 em) y Atkinson
  /// se toma por su avance medio.
  static double em(BuildContext context, num n, {double size = label}) {
    final px = MediaQuery.textScalerOf(context).scale(size);
    return n *
        px *
        (isBody(size)
            ? bodyAdvance
            : size == glyph
                ? 1
                : titleAdvance);
  }

  /// El factor de TAMAÑO DEL TEXTO (sin el de la ventana): 1 / 1.25 /
  /// 1.5 / 2. Con ENORME (≥ 2) algunas filas se apilan en dos líneas.
  static double settingFactor(BuildContext context) =>
      factorOf(context) /
      RetroTextScale.windowFactor(MediaQuery.sizeOf(context));

  /// [base] px (pensados para Normal a 100 %) agrandados como el texto:
  /// anchos de tooltips, tarjetas y cajas con texto adentro. Nunca achica.
  static double width(BuildContext context, double base) {
    final f = factorOf(context);
    return base * (f < 1 ? 1 : f);
  }

  /// El escalador activo sin el factor de ventana de [RetroTextScale]
  /// (solo el "Tamaño del texto"): para contenido que ya se escala con la
  /// ventana por su cuenta (`DsScreenView`, screen_editor.md § 2.1).
  static TextScaler withoutWindow(BuildContext context) {
    final s = MediaQuery.textScalerOf(context);
    if (s is! RetroTextScaler) return s;
    final w = RetroTextScale.windowFactor(MediaQuery.sizeOf(context));
    if (w == 1) return s;
    return RetroTextScaler(s.factor / w,
        devicePixelRatio: s.devicePixelRatio,
        font: s.font,
        readingTitles: s.readingTitles);
  }

  /// Escalador para texto que no debe crecer con el ajuste (números dentro
  /// de casillas de tamaño fijo, siempre en Press Start 2P) pero sí quedar
  /// nítido.
  static TextScaler fixedScaler(BuildContext context) => RetroTextScaler(1,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context), font: font);
}

/// "Tamaño del texto" (docs/specs/settings.md § 3.6) + nitidez de las
/// fuentes (docs/specs/ui_style.md § "Tipografía").
///
/// **Texto de lectura** ([RetroType.small] / [RetroType.body]):
/// [RetroType.bodySizeOf] (VT323 20, Atkinson 18) × factor (Normal 1,
/// Grande 1.25, Muy grande 1.5, Enorme 2), llevado a px físicos enteros.
/// VT323 tiene filas de 40/1000 em (exacta a 25 px) y columnas "corridas"
/// a propósito (imita el CRT): no tiene una grilla horizontal exacta.
/// Atkinson no es pixel: solo px enteros.
///
/// **Press Start 2P** (el resto): grilla de 8 × 8. Tamaño buscado: el
/// texto < 16 px × factor ([RetroType.label] busca 10); los títulos
/// (≥ 16) + 8 × (factor − 1). Se lleva al múltiplo de 8 px físicos de
/// arriba con 2 px físicos de tolerancia (mínimo 8 físicos).
///
/// **Títulos en la fuente de lectura** ([readingTitles], no CLÁSICA): el
/// tamaño buscado de Press Start × [titleRatio] (para que se vea del
/// mismo porte), en px enteros, sin la grilla de 8. [RetroType.glyph]
/// sigue siempre en Press Start.
@immutable
class RetroTextScaler extends TextScaler {
  const RetroTextScaler(this.factor,
      {this.devicePixelRatio = 1,
      bool classicReading = false,
      ReadingFont? font,
      this.readingTitles = false})
      : font = font ??
            (classicReading ? ReadingFont.classic : ReadingFont.vt323);

  final double factor;
  final double devicePixelRatio;

  /// Fuente de lectura (settings.md § 3.7).
  final ReadingFont font;

  /// "Títulos con la fuente de lectura".
  final bool readingTitles;

  /// "Fuente de lectura" CLÁSICA: el texto de lectura es Press Start 2P y
  /// va en su grilla de 8 (8 / 16 / 16 / 16 a 100 %).
  bool get classicReading => font == ReadingFont.classic;

  bool get _titlesInReading => readingTitles && !classicReading;

  /// Desde este tamaño el texto es un título: crece menos.
  static const titleFrom = RetroType.title;

  /// Grilla de Press Start 2P en px físicos.
  static const grid = 8.0;

  /// Cuántos px físicos se tolera quedar por debajo del tamaño buscado.
  static const tolerance = 2.0;

  double get _dpr => devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;

  /// Tamaño buscado de Press Start 2P (antes de la grilla).
  double target(double fontSize) {
    final f = fontSize == RetroType.label || fontSize == RetroType.glyph
        ? RetroType.small
        : fontSize;
    return f < titleFrom ? f * factor : f + titleFrom * (factor - 1) / 2;
  }

  /// Cuánto más grande va un título en la fuente de lectura [f] que en
  /// Press Start 2P para verse del mismo porte (alto de mayúsculas):
  /// VT323 ×1.6 las etiquetas / ×1.5 los títulos; Atkinson ×1.3 / ×1.25.
  static double titleRatio(ReadingFont f, double fontSize) {
    final isTitle = fontSize >= titleFrom;
    return switch (f) {
      ReadingFont.vt323 => isTitle ? 1.5 : 1.6,
      ReadingFont.atkinson => isTitle ? 1.25 : 1.3,
      ReadingFont.classic => 1,
    };
  }

  /// [logical] px de Press Start 2P llevados al múltiplo de 8 físico.
  static double snap(double logical, double devicePixelRatio) {
    final dpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    final steps = ((logical * dpr - tolerance) / grid).ceil();
    return (steps < 1 ? 1 : steps) * grid / dpr;
  }

  double _whole(double logical) => (logical * _dpr).roundToDouble() / _dpr;

  @override
  double scale(double fontSize) {
    if (fontSize <= 0) return fontSize;
    if (fontSize == RetroType.glyph) return snap(target(fontSize), _dpr);
    if (RetroType.isBody(fontSize) && !classicReading) {
      final f = factor < 1 ? 1.0 : factor;
      return _whole(RetroType.bodySizeOf(font) * f);
    }
    if (!RetroType.isBody(fontSize) && _titlesInReading) {
      return _whole(target(fontSize) * titleRatio(font, fontSize));
    }
    return snap(target(fontSize), _dpr);
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => factor;

  @override
  bool operator ==(Object other) =>
      other is RetroTextScaler &&
      other.factor == factor &&
      other.devicePixelRatio == devicePixelRatio &&
      other.font == font &&
      other.readingTitles == readingTitles;

  @override
  int get hashCode =>
      Object.hash(factor, devicePixelRatio, font, readingTitles);

  @override
  String toString() =>
      'RetroTextScaler($factor, dpr $devicePixelRatio, ${font.name}'
      '${readingTitles ? ', títulos de lectura' : ''})';
}

/// Aplica [factor] a todo lo que está debajo (incluidos los overlays si
/// envuelve al `Navigator`, como en `MaterialApp.builder`). Reemplaza el
/// escalado del sistema operativo: la UI está armada para estos tamaños.
/// También fija la fuente de lectura, los títulos en la fuente de lectura
/// y el espaciado entre letras (estáticos de [RetroType]).
class RetroTextScale extends StatefulWidget {
  const RetroTextScale(
      {super.key,
      required this.factor,
      required this.child,
      this.classic = false,
      ReadingFont? font,
      this.readingTitles = false,
      this.wideLetters = false})
      : font = font ?? (classic ? ReadingFont.classic : ReadingFont.vt323);

  final double factor;

  /// "Fuente de lectura" CLÁSICA (Press Start 2P). Atajo de [font].
  final bool classic;

  /// "Fuente de lectura".
  final ReadingFont font;

  /// "Títulos con la fuente de lectura".
  final bool readingTitles;

  /// "Espaciado entre letras" AMPLIO.
  final bool wideLetters;
  final Widget child;

  /// La UI está pensada para 1280×720 lógicos: en una ventana más grande
  /// (en las dos direcciones) todo el texto crece en la misma proporción,
  /// de a 0.25 y hasta ×2 (1920×1080 → ×1.5: VT323 a 30 px). Así a
  /// 1080p se ve como a 720p, no diminuto (docs/specs/accessibility.md
  /// § 1, "Ventanas grandes"). Los anchos que usan `RetroType.width` /
  /// `em` crecen igual, así que el armado es el mismo que a 1280×720.
  static double windowFactor(Size logical) {
    if (logical.width <= 0 || logical.height <= 0) return 1;
    final k = math.min(logical.width / 1280, logical.height / 720);
    if (k <= 1) return 1;
    return math.min(2.0, (k * 4).floor() / 4);
  }

  @override
  State<RetroTextScale> createState() => _RetroTextScaleState();
}

class _RetroTextScaleState extends State<RetroTextScale> {
  bool _scheduled = false;

  /// Los estilos se arman en el build de cada widget con los estáticos de
  /// `RetroType`: se reconstruye todo el árbol (sin perder estado) para
  /// que tomen la fuente / el espaciado nuevos.
  void _reassemble() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      // ignore: invalid_use_of_protected_member
      PaintingBinding.instance.handleSystemMessage(
          const <String, Object?>{'type': 'fontsChange'});
      WidgetsBinding.instance.reassembleApplication();
    });
  }

  @override
  void didUpdateWidget(RetroTextScale old) {
    super.didUpdateWidget(old);
    if (old.font != widget.font ||
        old.readingTitles != widget.readingTitles ||
        old.wideLetters != widget.wideLetters) {
      _reassemble();
    }
  }

  @override
  Widget build(BuildContext context) {
    RetroType.font = widget.font;
    RetroType.readingTitles = widget.readingTitles;
    RetroType.wideLetters = widget.wideLetters;
    final mq = MediaQuery.of(context);
    final scaler = RetroTextScaler(
        widget.factor * RetroTextScale.windowFactor(mq.size),
        devicePixelRatio: mq.devicePixelRatio,
        font: widget.font,
        readingTitles: widget.readingTitles);
    final px = scaler.scale(RetroType.small);
    // El espaciado entre letras depende del tamaño real: si cambió (otro
    // tamaño del texto, otra ventana), se vuelve a armar todo.
    if (widget.wideLetters &&
        (px != RetroType.readingPx ||
            mq.devicePixelRatio != RetroType.devicePixelRatio)) {
      _reassemble();
    }
    RetroType.readingPx = px;
    RetroType.devicePixelRatio = mq.devicePixelRatio;
    return MediaQuery(
      data: mq.copyWith(textScaler: scaler),
      child: widget.child,
    );
  }
}
