/// Formato de partitura de la música (tracker de texto). Ver
/// docs/specs/music.md § 1 y § 2.
library;

import 'dart:math' as math;

/// Voz de un canal (estilo consola de 8 bits).
enum Voice {
  /// Seno con soplo, vibrato retrasado y "scoop": la melodía.
  ocarina,

  /// Pulso 50 %.
  square,

  /// Pulso 25 %.
  pulse25,

  /// Pulso 12.5 %.
  pulse12,

  /// Triángulo cuantizado a 16 niveles (canal triángulo del NES).
  triangle,

  /// Seno puro (campanitas).
  sine,

  /// Kit de batería (tokens `k s h o t T c r q`).
  drums,
}

/// Cómo suena un canal.
class Instrument {
  const Instrument({
    required this.voice,
    this.volume = 0.2,
    this.attack = 0.005,
    this.decay = 0.1,
    this.sustain = 0.7,
    this.release = 0.05,
    this.gate = 1,
    this.vibratoRate = 0,
    this.vibratoDepth = 0,
    this.vibratoDelay = 0,
    this.breath = 0,
    this.scoop = 0,
    this.lowpass = 0,
    this.echoSteps = 0,
    this.echoGain = 0,
    this.transpose = 0,
  });

  final Voice voice;

  /// Ganancia pico de una nota.
  final double volume;

  /// ADSR lineal (s; [sustain] es nivel 0..1).
  final double attack, decay, sustain, release;

  /// Fracción de la nota que se sostiene antes del release (articula
  /// notas repetidas).
  final double gate;

  /// Vibrato: `f·(1 + depth·sin(2π·rate·t))`, entra a partir de
  /// [vibratoDelay] s en 0.2 s.
  final double vibratoRate, vibratoDepth, vibratoDelay;

  /// Soplo (ruido filtrado) de la ocarina, relativo a la nota.
  final double breath;

  /// Semitonos por debajo con los que entra la nota (sube en 50 ms).
  final double scoop;

  /// Pasabajos de un polo sobre la onda (Hz). 0: apagado.
  final double lowpass;

  /// Eco: retraso en pasos y ganancia de la primera repetición (3
  /// repeticiones: g, g², g³). 0: sin eco.
  final int echoSteps;
  final double echoGain;

  /// Semitonos que se suman a cada nota (doblar una melodía 8va abajo).
  final int transpose;

  /// El mismo instrumento con algunos parámetros cambiados.
  Instrument copyWith({
    double? volume,
    double? attack,
    double? decay,
    double? sustain,
    double? release,
    double? gate,
    double? vibratoRate,
    double? vibratoDepth,
    double? vibratoDelay,
    double? breath,
    double? scoop,
    double? lowpass,
    double? echoGain,
    int? echoSteps,
    int? transpose,
  }) =>
      Instrument(
        voice: voice,
        volume: volume ?? this.volume,
        attack: attack ?? this.attack,
        decay: decay ?? this.decay,
        sustain: sustain ?? this.sustain,
        release: release ?? this.release,
        gate: gate ?? this.gate,
        vibratoRate: vibratoRate ?? this.vibratoRate,
        vibratoDepth: vibratoDepth ?? this.vibratoDepth,
        vibratoDelay: vibratoDelay ?? this.vibratoDelay,
        breath: breath ?? this.breath,
        scoop: scoop ?? this.scoop,
        lowpass: lowpass ?? this.lowpass,
        echoGain: echoGain ?? this.echoGain,
        echoSteps: echoSteps ?? this.echoSteps,
        transpose: transpose ?? this.transpose,
      );

  /// Lo que puede sonar después del final de una nota (s).
  double get tail => release + 0.01;

  /// Texto estable con todos los parámetros (para la firma de la pieza).
  String get signature => '$voice/$volume/$attack/$decay/$sustain/$release/'
      '$gate/$vibratoRate/$vibratoDepth/$vibratoDelay/$breath/$scoop/'
      '$lowpass/$echoSteps/$echoGain/$transpose';
}

/// Un evento de la partitura: [midi] (nota) o [drum] (golpe), desde el
/// paso [start] durante [length] pasos.
class NoteEvent {
  const NoteEvent(this.start, this.length, {this.midi, this.drum});

  final int start;
  final int length;
  final int? midi;
  final String? drum;

  @override
  String toString() => 'NoteEvent($start, $length, ${midi ?? drum})';

  @override
  bool operator ==(Object other) =>
      other is NoteEvent &&
      other.start == start &&
      other.length == length &&
      other.midi == midi &&
      other.drum == drum;

  @override
  int get hashCode => Object.hash(start, length, midi, drum);
}

/// Golpes del kit de batería.
const kDrumTokens = {'k', 's', 'h', 'o', 't', 'T', 'c', 'r', 'q'};

const _pitchClass = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
final _noteRe = RegExp(r'^([A-G])([#b]?)(-?\d)$');

/// MIDI de un nombre de nota (`C4` = 60, `F#3`, `Bb5`). `null` si no es
/// una nota.
int? noteToMidi(String name) {
  final m = _noteRe.firstMatch(name);
  if (m == null) return null;
  final acc = switch (m.group(2)) { '#' => 1, 'b' => -1, _ => 0 };
  return 12 * (int.parse(m.group(3)!) + 1) + _pitchClass[m.group(1)]! + acc;
}

const _sharpNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' //
];

/// Nombre (con sostenidos) de un MIDI.
String midiToNote(int midi) => '${_sharpNames[midi % 12]}${midi ~/ 12 - 1}';

/// Frecuencia (Hz) de un MIDI, La4 = 440.
double midiToHz(num midi) => 440.0 * math.pow(2, (midi - 69) / 12);

/// Pasos y eventos de un texto de partitura (§ 2 de music.md). Lanza
/// [FormatException] con el token culpable.
({int steps, List<NoteEvent> events}) parseScore(String score,
    {bool drums = false}) {
  final events = <NoteEvent>[];
  var step = 0;
  // Índices (en events) de las notas del último token sonoro, para ligar.
  var last = <int>[];
  for (final raw in score.split(RegExp(r'\s+'))) {
    if (raw.isEmpty || raw == '|') continue;
    var token = raw;
    var n = 1;
    final colon = raw.lastIndexOf(':');
    if (colon > 0) {
      token = raw.substring(0, colon);
      n = int.tryParse(raw.substring(colon + 1)) ??
          (throw FormatException('duración inválida', raw));
      if (n <= 0) throw FormatException('duración inválida', raw);
    }
    if (token == '.') {
      last = [];
    } else if (token == '-') {
      if (last.isEmpty && !drums) {
        throw FormatException('liga sin nota', raw);
      }
      for (final i in last) {
        final e = events[i];
        events[i] = NoteEvent(e.start, e.length + n, midi: e.midi, drum: e.drum);
      }
    } else {
      last = [];
      for (final part in token.split('+')) {
        if (drums) {
          if (!kDrumTokens.contains(part)) {
            throw FormatException('golpe desconocido', raw);
          }
          last.add(events.length);
          events.add(NoteEvent(step, n, drum: part));
        } else {
          final midi = noteToMidi(part) ??
              (throw FormatException('nota desconocida', raw));
          last.add(events.length);
          events.add(NoteEvent(step, n, midi: midi));
        }
      }
    }
    step += n;
  }
  return (steps: step, events: events);
}

/// Un canal de la pieza: instrumento + partitura ya leída.
class Track {
  Track(String name, Instrument instrument, String score, {double gain = 1})
      : this._(name, instrument, parseScore(score), gain);

  /// Pista de batería.
  Track.drums(String name, String score, {double gain = 1})
      : this._(name, const Instrument(voice: Voice.drums, volume: 1),
            parseScore(score, drums: true), gain);

  Track._(this.name, this.instrument,
      ({int steps, List<NoteEvent> events}) parsed, this.gain)
      : steps = parsed.steps,
        events = List.unmodifiable(parsed.events);

  final String name;
  final Instrument instrument;
  final double gain;

  /// Largo en pasos.
  final int steps;

  /// Eventos en orden de inicio.
  final List<NoteEvent> events;

  bool get isDrums => instrument.voice == Voice.drums;

  String get signature =>
      '$name|${instrument.signature}|$gain|$steps|${events.join(',')}';
}

/// Una pieza: tempo, pistas y si es un bucle o un jingle.
class Song {
  Song({
    required this.id,
    required this.title,
    required this.bpm,
    this.stepsPerBeat = 4,
    this.beatsPerBar = 4,
    required this.tracks,
    this.loop = true,
    this.peak = 0.5,
  }) : steps = tracks.isEmpty ? 0 : tracks.first.steps {
    for (final t in tracks) {
      if (t.steps != steps) {
        throw ArgumentError(
            '$id: la pista ${t.name} mide ${t.steps} pasos y '
            '${tracks.first.name} $steps');
      }
    }
  }

  final String id;
  final String title;
  final double bpm;

  /// Pasos por pulso (4 = semicorcheas en 4/4; 3 en 6/8; 2 en 3/4).
  final int stepsPerBeat;
  final int beatsPerBar;
  final List<Track> tracks;

  /// Bucle (fondo) o jingle (una vez).
  final bool loop;

  /// Pico de la mezcla normalizada.
  final double peak;

  /// Largo en pasos (todas las pistas miden lo mismo).
  final int steps;

  int get stepsPerBar => stepsPerBeat * beatsPerBar;
  int get bars => steps ~/ stepsPerBar;

  /// Segundos por paso (nominal).
  double get stepSeconds => 60 / bpm / stepsPerBeat;

  /// Muestras por paso a [sampleRate] (entero: bucles exactos).
  int samplesPerStep(int sampleRate) => (stepSeconds * sampleRate).round();

  /// Largo nominal (s) de la partitura (sin colas).
  double get seconds => steps * stepSeconds;

  /// La misma pieza con solo la pista [name] (para medir niveles).
  Song solo(String name) => Song(
        id: id,
        title: title,
        bpm: bpm,
        stepsPerBeat: stepsPerBeat,
        beatsPerBar: beatsPerBar,
        tracks: [for (final t in tracks) if (t.name == name) t],
        loop: loop,
        peak: peak,
      );

  /// Texto estable de toda la partitura (cambia si cambia cualquier
  /// nota o parámetro).
  String get signature => '$id|$bpm|$stepsPerBeat|$loop|$peak|'
      '${tracks.map((t) => t.signature).join('#')}';

  /// Hash FNV-1a de 32 bits de [signature], en hex (nombre de caché).
  String get hash {
    var h = 0x811c9dc5;
    for (final c in signature.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}
