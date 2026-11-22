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

  /// Ocarina suave (pesca en el pueblo): ataque lento, un poco más de
  /// soplo, vibrato leve y tardío, sin scoop marcado.
  static const ocarinaSoft = Instrument(
    voice: Voice.ocarina,
    volume: 0.26,
    attack: 0.08,
    decay: 0.25,
    sustain: 0.78,
    release: 0.22,
    gate: 0.97,
    vibratoRate: 4.6,
    vibratoDepth: 0.004,
    vibratoDelay: 0.3,
    breath: 0.08,
    scoop: 0.12,
  );

  /// Bajo punteado muy suave (triángulo corto y bajo).
  static const bassPluck = Instrument(
    voice: Voice.triangle,
    volume: 0.13,
    attack: 0.004,
    decay: 0.35,
    sustain: 0.25,
    release: 0.2,
    gate: 0.8,
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

  /// Charango: pulso 25 % brillante y corto, acordes rasgueados (las
  /// cuerdas entran escalonadas cada 11 ms, bajada / subida).
  static const charango = Instrument(
    voice: Voice.pulse25,
    volume: 0.034,
    attack: 0.001,
    decay: 0.11,
    sustain: 0.22,
    release: 0.06,
    gate: 0.7,
    lowpass: 5600,
    strum: 0.011,
  );

  /// Zampoña / sikus: la misma voz de la ocarina pero sin vibrato, con
  /// mucho más soplo y un scoop corto (caña soplada de costado).
  static const zampona = Instrument(
    voice: Voice.ocarina,
    volume: 0.2,
    attack: 0.045,
    decay: 0.2,
    sustain: 0.72,
    release: 0.12,
    gate: 0.92,
    breath: 0.16,
    scoop: 0.15,
  );

  /// Zampoña lejana (llamadas y respuestas en hoquetus, con eco).
  static const zamponaEcho = Instrument(
    voice: Voice.ocarina,
    volume: 0.18,
    attack: 0.05,
    decay: 0.2,
    sustain: 0.7,
    release: 0.14,
    gate: 0.9,
    breath: 0.17,
    scoop: 0.15,
    echoSteps: 6,
    echoGain: 0.35,
  );
}
