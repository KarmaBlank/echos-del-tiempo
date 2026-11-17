/// Forma de onda de un oscilador (`OscillatorNode.type` del prototipo).
enum Waveform { square, sawtooth, triangle, sine }

/// Un `beep(f, d, type, vol)` del prototipo, con el retraso del
/// `setTimeout` que lo encadena. Ver docs/specs/audio.md.
class SfxTone {
  const SfxTone(
    this.frequency,
    this.duration, {
    this.wave = Waveform.square,
    this.volume = 0.05,
    this.delay = 0,
  });

  /// Hz.
  final double frequency;

  /// Segundos hasta que la ganancia llega a 0.0001 y el tono se corta.
  final double duration;
  final Waveform wave;

  /// Ganancia inicial (0..1). El prototipo usa 0.05 por defecto.
  final double volume;

  /// Segundos desde el inicio del efecto.
  final double delay;

  double get end => delay + duration;
}

/// Los efectos de sonido del juego (cada llamada a `beep(` del prototipo).
enum Sfx {
  /// Empieza tu turno (línea 1200).
  myTurn,

  /// Cuenta regresiva del turno con ≤ 5 s (línea 1231).
  turnTick,

  /// Cinemática de ULT (línea 1461).
  ultimate,

  /// Número verde: curación (línea 1469).
  heal,

  /// Número rojo claro: daño normal a un jugador (línea 1469).
  hurt,

  /// Cualquier otro número (línea 1469).
  hit,

  /// Destello de pantalla (línea 1469).
  flash,

  /// `¡NIVEL N!` (línea 1469).
  levelUp,
}

/// Retraso del impacto de la ULT (`ULT_DL`, 1150 ms).
const double kUltImpactDelay = 1.15;

/// El catálogo de sonidos: frecuencia, duración, onda, volumen y retraso
/// de cada tono, copiados de las llamadas a `beep(` del prototipo.
const Map<Sfx, List<SfxTone>> kSfxCatalog = {
  Sfx.myTurn: [
    SfxTone(523, 0.08),
    SfxTone(784, 0.12, delay: 0.09),
  ],
  Sfx.turnTick: [SfxTone(1200, 0.04)],
  Sfx.ultimate: [
    SfxTone(196, 0.5, wave: Waveform.sawtooth, volume: 0.05),
    SfxTone(392, 0.4, volume: 0.04, delay: 0.3),
    SfxTone(98, 0.6,
        wave: Waveform.sawtooth, volume: 0.07, delay: kUltImpactDelay),
  ],
  Sfx.heal: [SfxTone(880, 0.08)],
  Sfx.hurt: [SfxTone(160, 0.08)],
  Sfx.hit: [SfxTone(420, 0.08)],
  Sfx.flash: [SfxTone(220, 0.3, wave: Waveform.sawtooth, volume: 0.04)],
  Sfx.levelUp: [
    SfxTone(660, 0.1),
    SfxTone(990, 0.15, delay: 0.1),
  ],
};
