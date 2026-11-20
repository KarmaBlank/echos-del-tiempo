import 'dart:math' as math;

import 'package:yaml/yaml.dart';

/// Formato FXA ("efecto animado", docs/specs/game_editor.md § 2.1): una
/// animación es una línea de tiempo con duración y pistas; cada pista
/// tiene keyframes (`keys`, valores interpolados) o disparos (`fire`,
/// eventos puntuales). Dart puro: sin Flutter, testeable.
///
/// El modelo es genérico a propósito: cada key/disparo guarda sus
/// valores como mapa (`t` y `ease` aparte). Quien reproduce (`FxPlayer`)
/// sabe qué significa cada campo de cada tipo de pista; las pistas
/// desconocidas se conservan (y se reescriben al guardar) pero no se
/// reproducen.

/// Versión del formato que entiende este código.
const kFxSchema = 1;

/// Tope de seguridad de `duration` (ms; § 4.3).
const kFxMaxDurationMs = 6000;

/// Tope de diseño de las ULT de jugador (§ 5.1, aprobado: ~2.6 s).
const kUltMaxDurationMs = 2600;

/// Categorías de la lista del editor (§ 3.2), en orden.
const kFxCategories = [
  'ult',
  'duo',
  'skill',
  'attack',
  'enemy_ult',
  'status',
  'death',
  'proc',
  'map_move',
  'ui',
];

/// Tipos de pista que reproduce el `FxPlayer` (§ 2.1 + `echo`).
const kFxTrackTypes = {
  'camera',
  'dim',
  'letterbox',
  'title_card',
  'actor',
  'echo',
  'sprite',
  'particles',
  'trail',
  'shape',
  'shake',
  'flash',
  'hitstop',
  'tint',
  'impact',
  'damage_style',
  'sound',
  'legacy',
};

/// Curva entre un keyframe y el siguiente (la del keyframe de llegada).
enum FxEase {
  linear,
  smooth,
  easeIn,
  easeOut,
  snap,
  back;

  String get yamlName => switch (this) {
        easeIn => 'in',
        easeOut => 'out',
        _ => name,
      };

  static FxEase parse(Object? v) => switch (v) {
        'linear' => linear,
        'in' => easeIn,
        'out' => easeOut,
        'snap' => snap,
        'back' => back,
        _ => smooth,
      };

  /// Aplica la curva a [x] en [0, 1].
  double apply(double x) {
    final t = x.clamp(0.0, 1.0);
    return switch (this) {
      linear => t,
      smooth => t * t * (3 - 2 * t),
      easeIn => t * t,
      easeOut => 1 - (1 - t) * (1 - t),
      snap => t < 1 ? 0 : 1,
      back => 1 + 2.2 * math.pow(t - 1, 3) + 1.2 * math.pow(t - 1, 2),
    };
  }
}

/// Un keyframe o un disparo: tiempo (ms), curva y el resto de los valores.
class FxKey {
  FxKey(this.t, [Map<String, Object?>? data, this.ease = FxEase.smooth])
      : data = Map.unmodifiable(data ?? const {});

  final int t;
  final FxEase ease;

  /// Los campos además de `t` y `ease` (números, textos, listas, mapas).
  final Map<String, Object?> data;

  num? n(String k) => switch (data[k]) { final num v => v, _ => null };
  double d(String k, double fallback) => n(k)?.toDouble() ?? fallback;
  String? s(String k) => switch (data[k]) { final String v => v, _ => null };
  bool b(String k) => data[k] == true;

  FxKey copyWith({int? t, FxEase? ease, Map<String, Object?>? data}) =>
      FxKey(t ?? this.t, data ?? this.data, ease ?? this.ease);

  /// Copia con el campo [k] cambiado (`null` lo borra).
  FxKey withField(String k, Object? v) =>
      copyWith(data: {...data, k: v}..removeWhere((_, x) => x == null));
}

/// Una pista: tipo, propiedades propias (`who`, `count`, `each_target`…),
/// keyframes y disparos.
class FxTrack {
  FxTrack(this.type,
      {Map<String, Object?>? props,
      List<FxKey>? keys,
      List<FxKey>? fires})
      : props = Map.unmodifiable(props ?? const {}),
        keys = List.unmodifiable([...?keys]..sort((a, b) => a.t - b.t)),
        fires = List.unmodifiable([...?fires]..sort((a, b) => a.t - b.t));

  final String type;
  final Map<String, Object?> props;
  final List<FxKey> keys;
  final List<FxKey> fires;

  bool get known => kFxTrackTypes.contains(type);

  num? n(String k) => switch (props[k]) { final num v => v, _ => null };
  String? s(String k) => switch (props[k]) { final String v => v, _ => null };
  bool b(String k) => props[k] == true;

  /// Cada disparo se repite por objetivo, separado [stagger] ms (§ 5.2).
  bool get eachTarget => b('each_target');
  int get stagger => n('stagger')?.toInt() ?? 0;

  /// Valor numérico [field] interpolado a los [t] ms (con la curva del
  /// keyframe de llegada). `null` si ningún keyframe lo tiene.
  double? numAt(String field, double t) {
    FxKey? prev;
    for (final k in keys) {
      final v = k.n(field);
      if (v == null) continue;
      if (k.t >= t) {
        if (prev == null) return v.toDouble();
        final p = prev.n(field)!.toDouble();
        final span = k.t - prev.t;
        final q = span <= 0 ? 1.0 : k.ease.apply((t - prev.t) / span);
        return p + (v.toDouble() - p) * q;
      }
      prev = k;
    }
    return prev?.n(field)?.toDouble();
  }

  /// Valor de texto [field] vigente a los [t] ms (el del último keyframe
  /// que lo tiene con `t` ≤ [t]; antes del primero, el del primero).
  String? textAt(String field, double t) {
    String? out;
    for (final k in keys) {
      final v = k.s(field);
      if (v == null) continue;
      if (k.t > t) return out ?? v;
      out = v;
    }
    return out;
  }

  FxTrack copyWith(
          {Map<String, Object?>? props,
          List<FxKey>? keys,
          List<FxKey>? fires}) =>
      FxTrack(type,
          props: props ?? this.props,
          keys: keys ?? this.keys,
          fires: fires ?? this.fires);
}

/// Fases (cámara, tarjeta, letterbox, sonido de la ULT): preparación,
/// descarga, regreso (ms).
class FxPhases {
  const FxPhases(this.build, this.release, this.recover);
  final int build, release, recover;
  int get total => build + release + recover;
}

/// Una animación completa.
class FxTimeline {
  FxTimeline({
    required this.id,
    this.schema = kFxSchema,
    this.category = 'ult',
    String? name,
    this.tags = const [],
    required int duration,
    FxPhases? phases,
    this.targets = 'single',
    this.tracks = const [],
    this.legacy = false,
    this.warnings = const [],
  })  : name = name ?? id,
        duration = duration.clamp(0, kFxMaxDurationMs),
        phases = phases ?? _defaultPhases(duration.clamp(0, kFxMaxDurationMs));

  static FxPhases _defaultPhases(int d) {
    final build = (d * 0.35).round(), recover = math.min(400, d ~/ 5);
    return FxPhases(build, d - build - recover, recover);
  }

  final int schema;
  final String id;
  final String category;
  final String name;
  final List<String> tags;

  /// ms; la fuente de verdad para las esperas (§ 4.3).
  final int duration;
  final FxPhases phases;

  /// single | all | self | allies | line
  final String targets;
  final List<FxTrack> tracks;

  /// Construida por el `LegacyFxAdapter` desde el código (solo lectura en
  /// el editor; § 2.3).
  final bool legacy;

  /// Avisos del parser (pistas desconocidas, valores recortados).
  final List<String> warnings;

  Iterable<FxTrack> ofType(String type) => tracks.where((t) => t.type == type);

  /// La primera pista de [type], o `null`.
  FxTrack? track(String type) {
    for (final t in tracks) {
      if (t.type == type) return t;
    }
    return null;
  }

  /// Disparos de `impact` que conectan con la lógica (sin `pre: true`).
  List<FxKey> get impacts =>
      [for (final f in track('impact')?.fires ?? const <FxKey>[]) if (!f.b('pre')) f];

  /// Golpes previos solo visuales/sonoros (`impact` con `pre: true`).
  List<int> get preHits => [
        for (final f in track('impact')?.fires ?? const <FxKey>[])
          if (f.b('pre')) f.t
      ];

  FxTimeline copyWith({
    String? id,
    String? name,
    String? category,
    List<String>? tags,
    int? duration,
    FxPhases? phases,
    String? targets,
    List<FxTrack>? tracks,
    bool? legacy,
  }) =>
      FxTimeline(
        id: id ?? this.id,
        schema: schema,
        category: category ?? this.category,
        name: name ?? this.name,
        tags: tags ?? this.tags,
        duration: duration ?? this.duration,
        phases: phases ?? this.phases,
        targets: targets ?? this.targets,
        tracks: tracks ?? this.tracks,
        legacy: legacy ?? this.legacy,
      );

  /// Reemplaza la pista número [i].
  FxTimeline withTrack(int i, FxTrack t) =>
      copyWith(tracks: [...tracks]..[i] = t);

  // ------------------------------------------------------------ parser

  /// Lee un `.fx.yaml`. Lanza [FormatException] si no es una animación
  /// válida (falta `id`/`duration`, `schema` mayor al soportado).
  static FxTimeline parse(String yaml, {String? fallbackId}) {
    final Object? doc;
    try {
      doc = loadYaml(yaml);
    } on YamlException catch (e) {
      throw FormatException('YAML inválido: ${e.message}');
    }
    if (doc is! YamlMap) throw const FormatException('No es un mapa YAML.');
    final m = _plain(doc) as Map<String, Object?>;
    final schema = (m['schema'] as num?)?.toInt() ?? kFxSchema;
    if (schema > kFxSchema) {
      throw FormatException('schema $schema no soportado (máx. $kFxSchema).');
    }
    final id = m['id'] as String? ?? fallbackId;
    if (id == null) throw const FormatException('Falta id.');
    final dur = m['duration'];
    if (dur is! num) throw FormatException('$id: falta duration.');
    final warnings = <String>[];
    if (dur > kFxMaxDurationMs) {
      warnings.add('duration $dur recortada a $kFxMaxDurationMs ms');
    }
    FxPhases? phases;
    if (m['phases'] case final Map<String, Object?> p) {
      int g(String k) => (p[k] as num?)?.toInt() ?? 0;
      phases = FxPhases(g('build'), g('release'), g('recover'));
    }
    final tracks = <FxTrack>[];
    for (final raw in (m['tracks'] as List?) ?? const []) {
      if (raw is! Map<String, Object?>) continue;
      final type = raw['type'] as String? ?? '?';
      if (!kFxTrackTypes.contains(type)) {
        warnings.add('pista desconocida "$type" (se ignora)');
      }
      tracks.add(FxTrack(type,
          props: {
            for (final e in raw.entries)
              if (!const {'type', 'keys', 'fire'}.contains(e.key))
                e.key: e.value,
          },
          keys: [for (final k in (raw['keys'] as List?) ?? const []) _key(k)],
          fires: [for (final k in (raw['fire'] as List?) ?? const []) _key(k)]));
    }
    return FxTimeline(
      id: id,
      schema: schema,
      category: m['category'] as String? ?? 'ult',
      name: m['name'] as String?,
      tags: [for (final t in (m['tags'] as List?) ?? const []) '$t'],
      duration: dur.toInt(),
      phases: phases,
      targets: m['targets'] as String? ?? 'single',
      tracks: tracks,
      warnings: warnings,
    );
  }

  static FxKey _key(Object? raw) {
    if (raw is! Map<String, Object?>) return FxKey(0);
    return FxKey(
      (raw['t'] as num?)?.toInt() ?? 0,
      {
        for (final e in raw.entries)
          if (e.key != 't' && e.key != 'ease') e.key: e.value,
      },
      FxEase.parse(raw['ease']),
    );
  }

  static Object? _plain(Object? v) => switch (v) {
        YamlMap() => <String, Object?>{
            for (final e in v.entries) '${e.key}': _plain(e.value),
          },
        YamlList() => [for (final x in v) _plain(x)],
        _ => v,
      };

  // ------------------------------------------------------------ escritor

  /// YAML ordenado y estable (diffs chicos; § 2.1).
  String toYaml() {
    final b = StringBuffer()
      ..writeln('schema: $schema')
      ..writeln('id: ${_scalar(id)}')
      ..writeln('category: ${_scalar(category)}')
      ..writeln('name: ${_scalar(name)}');
    if (tags.isNotEmpty) b.writeln('tags: ${_flow(tags)}');
    b
      ..writeln('duration: $duration')
      ..writeln('phases: { build: ${phases.build}, release: ${phases.release}, '
          'recover: ${phases.recover} }')
      ..writeln('targets: ${_scalar(targets)}')
      ..writeln('tracks:');
    for (final t in tracks) {
      b.writeln('  - type: ${_scalar(t.type)}');
      for (final e in t.props.entries) {
        b.writeln('    ${e.key}: ${_flow(e.value)}');
      }
      void list(String name, List<FxKey> l) {
        if (l.isEmpty) return;
        b.writeln('    $name:');
        for (final k in l) {
          final m = <String, Object?>{
            't': k.t,
            ...k.data,
            if (name == 'keys' && k.ease != FxEase.smooth) 'ease': k.ease.yamlName,
          };
          b.writeln('      - ${_flow(m)}');
        }
      }

      list('keys', t.keys);
      list('fire', t.fires);
    }
    return b.toString();
  }

  static String _flow(Object? v) => switch (v) {
        final Map<String, Object?> m =>
          '{ ${[for (final e in m.entries) '${e.key}: ${_flow(e.value)}'].join(', ')} }',
        final List<Object?> l => '[${l.map(_flow).join(', ')}]',
        final double d when d == d.roundToDouble() && d.abs() < 1e9 =>
          '${d.toInt()}',
        final num n => '$n',
        final bool x => '$x',
        null => 'null',
        _ => _scalar('$v'),
      };

  static final _plainText = RegExp(r'^[A-Za-zÁÉÍÓÚÑáéíóúñü_][A-Za-z0-9ÁÉÍÓÚÑáéíóúñü_.+ ]*$');

  static String _scalar(String s) {
    final reserved = {'true', 'false', 'null', 'yes', 'no', 'on', 'off', '~'};
    if (_plainText.hasMatch(s) &&
        !reserved.contains(s.toLowerCase()) &&
        !s.endsWith(' ')) {
      return s;
    }
    return "'${s.replaceAll("'", "''")}'";
  }
}
