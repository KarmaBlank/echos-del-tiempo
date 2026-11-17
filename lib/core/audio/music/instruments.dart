import 'music_score.dart';

/// Instrumentos de la banda chiptune (docs/specs/music.md § 1). Las
/// piezas usan estos o un `copyWith` propio.
abstract final class Inst {
  /// La melodía: ocarina de 8 bits (seno con soplo, scoop y vibrato
  /// retrasado).
  static const ocarina = Instrument(
    voice: Voice.ocarina,
    volume: 0.34,
    attack: 0.03,
    decay: 0.15,
    sustain: 0.82,
    release: 0.09,
    gate: 0.96,
    vibratoRate: 5.3,
    vibratoDepth: 0.006,
    vibratoDelay: 0.18,
    breath: 0.05,
    scoop: 0.3,
  );

  /// Ocarina con eco (bosque, cavernas).
  static const ocarinaEcho = Instrument(
    voice: Voice.ocarina,
    volume: 0.32,
    attack: 0.035,
    decay: 0.15,
    sustain: 0.8,
    release: 0.12,
    gate: 0.95,
    vibratoRate: 5,
    vibratoDepth: 0.007,
    vibratoDelay: 0.2,
    breath: 0.06,
    scoop: 0.3,
    echoSteps: 3,
    echoGain: 0.33,
  );

  /// Arpegio fino de pulso 12.5 %.
  static const arp = Instrument(
    voice: Voice.pulse12,
    volume: 0.1,
    attack: 0.002,
    decay: 0.09,
    sustain: 0.35,
    release: 0.03,
    gate: 0.8,
    lowpass: 5200,
  );

  /// Acordes / armonía de pulso 25 %.
  static const harmony = Instrument(
    voice: Voice.pulse25,
    volume: 0.085,
    attack: 0.003,
    decay: 0.2,
    sustain: 0.45,
    release: 0.04,
    gate: 0.85,
    lowpass: 4200,
  );

  /// Colchón suave de cuadrada (ataque lento).
  static const pad = Instrument(
    voice: Voice.square,
    volume: 0.05,
    attack: 0.35,
    decay: 0.4,
    sustain: 0.7,
    release: 0.45,
    gate: 0.97,
    lowpass: 1800,
  );

  /// Bajo de triángulo del NES.
  static const bass = Instrument(
    voice: Voice.triangle,
    volume: 0.24,
    attack: 0.003,
    decay: 0.05,
    sustain: 0.9,
    release: 0.03,
    gate: 0.9,
  );

  /// Bajo corto (staccato) para ostinatos rápidos.
  static const bassStaccato = Instrument(
    voice: Voice.triangle,
    volume: 0.26,
    attack: 0.002,
    decay: 0.06,
    sustain: 0.8,
    release: 0.02,
    gate: 0.7,
  );

  /// Campanita (gotas de hielo, destellos).
  static const chime = Instrument(
    voice: Voice.sine,
    volume: 0.09,
    attack: 0.002,
    decay: 0.5,
    sustain: 0,
    release: 0.3,
    echoSteps: 4,
    echoGain: 0.4,
  );

  /// Cuadrada que dobla la melodía una octava abajo (batalla, jefe).
  static const leadDouble = Instrument(
    voice: Voice.square,
    volume: 0.05,
    attack: 0.01,
    decay: 0.1,
    sustain: 0.7,
    release: 0.05,
    gate: 0.9,
    lowpass: 2600,
    transpose: -12,
  );

  /// Pulso brillante de fanfarria (jingles, metales de la fortaleza).
  static const brass = Instrument(
    voice: Voice.pulse25,
    volume: 0.08,
    attack: 0.01,
    decay: 0.12,
    sustain: 0.6,
    release: 0.06,
    gate: 0.88,
    lowpass: 3800,
  );
}
