import 'dart:math' as math;

import 'ult_cinematic.dart';

/// Cinemática de los DÚOS (v0.8.3, docs/specs/battle_presentation.md
/// § "Dúos"): usa la misma tubería que las ULT (`FxKind.ult`, cámara,
/// oscurecido, hit-stop, adelantar con pasos en cola) con su propio guion
/// y su tarjeta partida. Datos puros: los usan la escena, el pintor y el
/// sonido para caer en el mismo ms.

/// Guion de todos los dúos: 1.6 s.
/// - 0–650 ms: entran los dos retratos (izquierda / derecha) y el cartel
///   `DÚO · <nombre>`.
/// - 650–1000 ms: dos estelas salen de los dos y convergen en los
///   objetivos.
/// - 1000 ms: impacto doble (destello, sacudida, hit-stop corto); los
///   demás objetivos cada 50 ms.
/// - 1300–1600 ms: regreso (el remate del color del elemento se apaga).
const UltScript kDuoScript = UltScript(
  style: UltStyle.duo,
  buildMs: 650,
  releaseMs: 650,
  returnMs: 300,
  impactMs: 1000,
  staggerMs: 50,
  hitStopMs: 90,
  shake: 9,
  focus: UltFocus.targets,
);

/// Cuánto dura la tarjeta partida (entra con la preparación y se va al
/// empezar la descarga).
const kDuoCardMs = 800;

/// Cuánto tarda en entrar cada mitad de la tarjeta.
const kDuoSlideMs = 260;

/// La mitad derecha entra un poco después.
const kDuoSlideLagMs = 60;

/// Pose de la tarjeta partida a una edad.
class DuoCardPose {
  const DuoCardPose({
    required this.left,
    required this.right,
    required this.alpha,
    required this.banner,
    required this.speedLines,
  });

  /// Avance de entrada de cada mitad: 0 = afuera de la pantalla, 1 = en
  /// su lugar. La izquierda (quien hace el dúo) entra desde la izquierda;
  /// la derecha (el compañero), desde la derecha.
  final double left, right;

  /// Opacidad de toda la tarjeta (0..1).
  final double alpha;

  /// Opacidad del cartel `DÚO · <nombre>` (0..1).
  final double banner;

  /// Líneas de velocidad en las bandas.
  final bool speedLines;

  /// No se dibuja nada.
  bool get hidden => alpha <= 0;

  static const none = DuoCardPose(
      left: 0, right: 0, alpha: 0, banner: 0, speedLines: false);
}

double _easeOut(double x) {
  final t = x.clamp(0.0, 1.0);
  return 1 - math.pow(1 - t, 3).toDouble();
}

/// Pose de la tarjeta a la edad [a] (ms desde que empieza el dúo). Con
/// [reduceMotion] (REDUCIR MOVIMIENTO) las mitades no se deslizan: están
/// en su lugar y la tarjeta aparece con un fundido corto, sin líneas de
/// velocidad.
DuoCardPose duoCardPose(double a, {bool reduceMotion = false}) {
  if (a < 0 || a >= kDuoCardMs) return DuoCardPose.none;
  final fadeOut = ((kDuoCardMs - a) / 200).clamp(0.0, 1.0);
  if (reduceMotion) {
    final fadeIn = (a / 150).clamp(0.0, 1.0);
    return DuoCardPose(
      left: 1,
      right: 1,
      alpha: math.min(fadeIn, fadeOut),
      banner: math.min(fadeIn, fadeOut),
      speedLines: false,
    );
  }
  return DuoCardPose(
    left: _easeOut(a / kDuoSlideMs),
    right: _easeOut((a - kDuoSlideLagMs) / kDuoSlideMs),
    alpha: fadeOut,
    banner: math.min(((a - 180) / 180).clamp(0.0, 1.0), fadeOut),
    speedLines: true,
  );
}

/// Avance de las dos estelas (0 = salen de los dos, 1 = llegan al
/// objetivo en el impacto), con aceleración.
double duoTrailProgress(double a, [UltScript s = kDuoScript]) {
  final k = (a - s.buildMs) / (s.impactMs - s.buildMs);
  final t = k.clamp(0.0, 1.0);
  return t * t;
}
