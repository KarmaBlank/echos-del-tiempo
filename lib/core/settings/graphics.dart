import 'dart:math' as math;
import 'dart:ui';

/// Ajustes gráficos (docs/specs/settings.md § "PANTALLA"). Dart puro de
/// `dart:ui`: los usan el mapa, la escena de batalla y el filtro CRT.

/// Cómo se agranda el mundo pixelado (§ 3.1).
enum ScaleMode {
  /// Factor entero (el mayor que entra), centrado con barras negras.
  pixelPerfect,

  /// Lo más grande que entra manteniendo la proporción (fraccional).
  fit;

  static ScaleMode fromName(Object? v, ScaleMode def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// Intensidad del filtro CRT (§ 3.2).
enum CrtLevel {
  off,
  soft,
  normal,
  strong;

  static CrtLevel fromName(Object? v, CrtLevel def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// Cantidad de partículas (§ 3.3).
enum ParticleLevel {
  low(0.3),
  medium(0.6),
  high(1);

  const ParticleLevel(this.factor);

  /// Multiplica la cantidad de partículas.
  final double factor;

  static ParticleLevel fromName(Object? v, ParticleLevel def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// Water reflection quality (water_reflections.md § 6).
enum ReflectionLevel {
  /// No reflections at all.
  off,

  /// Shore props, lights and sky only; fewer actors, 2 px strips.
  low,

  /// Everything, 1 px strips.
  high;

  static ReflectionLevel fromName(Object? v, ReflectionLevel def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// Tope de cuadros por segundo (§ 3.4).
enum FpsLimit {
  fps30(30),
  fps60(60),
  none(null);

  const FpsLimit(this.fps);

  /// Cuadros por segundo; `null` = sin límite (lo que dé el monitor).
  final int? fps;

  /// Como se guarda en `game.json` (0 = sin límite).
  int get json => fps ?? 0;

  static FpsLimit fromJson(Object? v, FpsLimit def) =>
      values.firstWhere((m) => m.json == v, orElse: () => def);
}

/// `n` escalado por [factor] sin hacer desaparecer una ráfaga: al menos 1
/// si [n] > 0.
int scaledCount(num n, double factor) {
  if (n <= 0) return 0;
  if (factor >= 1) return n.round();
  return math.max(1, (n * factor).round());
}

/// Dónde va (en px de pantalla) una imagen virtual de [virtual] dentro de
/// [screen]: centrada, con vecino más cercano, factor entero con
/// [ScaleMode.pixelPerfect] (mínimo 1) o fraccional con [ScaleMode.fit].
Rect mapViewRect(Size screen, Size virtual, ScaleMode mode) {
  var s = math.min(screen.width / virtual.width, screen.height / virtual.height);
  if (mode == ScaleMode.pixelPerfect) s = math.max(1, s.floorToDouble());
  if (!s.isFinite || s <= 0) s = 1;
  final w = virtual.width * s, h = virtual.height * s;
  return Rect.fromLTWH(((screen.width - w) / 2).roundToDouble(),
      ((screen.height - h) / 2).roundToDouble(), w.roundToDouble(), h.roundToDouble());
}
