import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Escala tipográfica de la UI (docs/specs/ui_style.md § "Tipografía").
///
/// Dos fuentes pixel:
/// - **VT323** ([bodyFamily]) para el texto de lectura: tooltips,
///   fichas, chat, descripciones, ayudas, log y menú de batalla, HUD.
///   Tokens [small] / [body].
/// - **Press Start 2P** ([pixelFamily]) para títulos, botones, cifras de
///   las barras y etiquetas cortas. Tokens [label], [title], [heading],
///   [display].
///
/// Los tamaños son **nominales**: [RetroTextScaler] (aplicado una sola vez
/// en `MaterialApp.builder` → [RetroTextScale]) los convierte al tamaño
/// real según el ajuste "Tamaño del texto" y la escala de la pantalla,
/// siempre en px enteros (Press Start 2P en su grilla de 8). Por eso el
/// tamaño nominal decide la grilla: [small] y [body] siempre van con
/// [bodyFamily]; el resto con [pixelFamily]. Usar [style] / [familyFor]
/// para no mezclarlos.
abstract final class RetroType {
  /// "Fuente de lectura" CLÁSICA (Press Start 2P, como v0.4) en vez de
  /// VT323. La pone `RetroTextScale` (ajuste del jugador, settings.md
  /// § 3.7); al cambiar, la app se reconstruye entera.
  static bool classic = false;

  /// VT323 (`pubspec.yaml`).
  static const vt323Family = 'VT323';

  /// Familia del texto de lectura: VT323, o Press Start 2P en CLÁSICA.
  static String get bodyFamily => classic ? pixelFamily : vt323Family;

  /// Familia de títulos, botones y cifras (Press Start 2P).
  static const pixelFamily = 'PressStart2P';

  /// Lo que a VT323 le falta (→ ★ ♥ ▶ ▲ ▼ ½ ♦) sale de Press Start 2P.
  /// Va en todo estilo que nombre [bodyFamily]: un `TextSpan` con familia
  /// propia no hereda el respaldo.
  static const bodyFallback = [pixelFamily];

  /// Texto de lectura (VT323). Mínimo legible: nada de cuerpo por
  /// debajo. Nominal: el real es [bodySize] × factor en px enteros.
  static const small = 10.0;

  /// Texto de lectura destacado (misma grilla que [small]). Nominal 11
  /// para no chocar con los 12 / 14 px de Press Start 2P.
  static const body = 11.0;

  /// Etiquetas cortas en Press Start 2P (botón compacto, cifras de las
  /// barras de batalla): 10 px buscados en la grilla de 8.
  static const label = 9.0;

  /// Títulos de panel (`h2`), botones grandes, avisos.
  static const title = 16.0;

  /// Encabezados de pantalla.
  static const heading = 24.0;

  /// Carteles (`¡VICTORIA!`, título del juego).
  static const display = 32.0;

  /// Tamaño real del texto de lectura en Normal a 100 %: VT323 a 20 px
  /// (mayúsculas de 11 px, 8 px por letra). VT323 es monoespaciada.
  /// En CLÁSICA, la referencia es el texto chico de Press Start (10).
  static double get bodySize => classic ? small : 20.0;

  /// Avance de cada letra de VT323 (400 / 1000 por em); Press Start: 1.
  static double get bodyAdvance => classic ? 1 : 0.4;

  /// Interlineado del texto de lectura (VT323: ascenso + descenso = 1 em;
  /// Press Start: 1.6).
  static double get line => classic ? 1.6 : 1.0;

  /// Interlineado compacto (chips).
  static double get lineTight => classic ? 1.3 : 1.0;

  /// Interlineado de Press Start 2P.
  static const pixelLine = 1.5;

  /// Familia que corresponde a un tamaño nominal.
  static String familyFor(double size) =>
      isBody(size) ? bodyFamily : pixelFamily;

  /// [size] es de texto de lectura (VT323).
  static bool isBody(double size) => size == small || size == body;

  /// Estilo con la familia y el interlineado de [size].
  static TextStyle style(double size,
          {Color? color, FontWeight? fontWeight, double? height}) =>
      TextStyle(
        fontFamily: familyFor(size),
        // VT323 no tiene → ★ ♥ ▶ ▲ ▼ ♦: los toma de Press Start 2P.
        fontFamilyFallback: isBody(size) ? bodyFallback : null,
        fontSize: size,
        height: height ?? (isBody(size) ? line : pixelLine),
        color: color,
        fontWeight: fontWeight,
      );

  /// Estilo base del texto de lectura (sin color: lo hereda).
  static TextStyle get smallStyle => TextStyle(
      fontFamily: bodyFamily,
      fontFamilyFallback: bodyFallback,
      fontSize: small,
      height: line);

  /// Cuánto más grande se ve el texto de lectura que en Normal a 100 %
  /// (1 = VT323 a 20 px). Para anchos de cajas.
  static double factorOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(small) / bodySize;

  /// Ancho de [n] caracteres de [size] ya escalado: Press Start 2P es
  /// monoespaciada (1 em por glifo) y VT323 también (0.4 em).
  static double em(BuildContext context, num n, {double size = label}) {
    final px = MediaQuery.textScalerOf(context).scale(size);
    return n * px * (isBody(size) ? bodyAdvance : 1);
  }

  /// [base] px (pensados para Normal a 100 %) agrandados como el texto:
  /// anchos de tooltips, tarjetas y cajas con texto adentro. Nunca achica.
  static double width(BuildContext context, double base) {
    final f = factorOf(context);
    return base * (f < 1 ? 1 : f);
  }

  /// Escalador para texto que no debe crecer con el ajuste (números dentro
  /// de casillas de tamaño fijo) pero sí quedar nítido.
  static TextScaler fixedScaler(BuildContext context) => RetroTextScaler(1,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      classicReading: classic);
}

/// "Tamaño del texto" (docs/specs/settings.md § 3.6) + nitidez de las
/// fuentes pixel (docs/specs/ui_style.md § "Tipografía").
///
/// **Texto de lectura** ([RetroType.small] / [RetroType.body], VT323):
/// [RetroType.bodySize] (20) × factor (Normal 1 → 20, Grande 1.25 → 25,
/// Muy grande 1.5 → 30), llevado a px físicos enteros. VT323 tiene filas
/// de 40/1000 em (exacta a 25 px) y columnas "corridas" a propósito
/// (imita el CRT): no tiene una grilla horizontal exacta.
///
/// **Press Start 2P** (el resto): grilla de 8 × 8. Tamaño buscado: el
/// texto < 16 px × factor ([RetroType.label] busca 10); los títulos
/// (≥ 16) + 8 × (factor − 1). Se lleva al múltiplo de 8 px físicos de
/// arriba con 2 px físicos de tolerancia (mínimo 8 físicos).
@immutable
class RetroTextScaler extends TextScaler {
  const RetroTextScaler(this.factor,
      {this.devicePixelRatio = 1, this.classicReading = false});

  final double factor;
  final double devicePixelRatio;

  /// "Fuente de lectura" CLÁSICA: el texto de lectura es Press Start 2P y
  /// va en su grilla de 8 (8 / 16 / 16 a 100 %).
  final bool classicReading;

  /// Desde este tamaño el texto es un título: crece menos.
  static const titleFrom = RetroType.title;

  /// Grilla de Press Start 2P en px físicos.
  static const grid = 8.0;

  /// Cuántos px físicos se tolera quedar por debajo del tamaño buscado.
  static const tolerance = 2.0;

  double get _dpr => devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;

  /// Tamaño buscado de Press Start 2P (antes de la grilla).
  double target(double fontSize) {
    final f = fontSize == RetroType.label ? RetroType.small : fontSize;
    return f < titleFrom ? f * factor : f + titleFrom * (factor - 1) / 2;
  }

  /// [logical] px de Press Start 2P llevados al múltiplo de 8 físico.
  static double snap(double logical, double devicePixelRatio) {
    final dpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    final steps = ((logical * dpr - tolerance) / grid).ceil();
    return (steps < 1 ? 1 : steps) * grid / dpr;
  }

  @override
  double scale(double fontSize) {
    if (fontSize <= 0) return fontSize;
    if (RetroType.isBody(fontSize) && !classicReading) {
      final f = factor < 1 ? 1.0 : factor;
      return (RetroType.bodySize * f * _dpr).roundToDouble() / _dpr;
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
      other.classicReading == classicReading;

  @override
  int get hashCode => Object.hash(factor, devicePixelRatio, classicReading);

  @override
  String toString() => 'RetroTextScaler($factor, dpr $devicePixelRatio)';
}

/// Aplica [factor] a todo lo que está debajo (incluidos los overlays si
/// envuelve al `Navigator`, como en `MaterialApp.builder`). Reemplaza el
/// escalado del sistema operativo: la UI está armada para estos tres
/// tamaños.
class RetroTextScale extends StatefulWidget {
  const RetroTextScale(
      {super.key,
      required this.factor,
      required this.child,
      this.classic = false});

  final double factor;

  /// "Fuente de lectura" CLÁSICA (Press Start 2P).
  final bool classic;
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
  @override
  void didUpdateWidget(RetroTextScale old) {
    super.didUpdateWidget(old);
    if (old.classic != widget.classic) {
      // Los estilos de lectura se arman en el build de cada widget con
      // `RetroType.bodyFamily`: se reconstruye todo el árbol (sin perder
      // estado) para que tomen la fuente nueva.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) WidgetsBinding.instance.reassembleApplication();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    RetroType.classic = widget.classic;
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
          textScaler: RetroTextScaler(
              widget.factor * RetroTextScale.windowFactor(mq.size),
              devicePixelRatio: mq.devicePixelRatio,
              classicReading: widget.classic)),
      child: widget.child,
    );
  }
}
