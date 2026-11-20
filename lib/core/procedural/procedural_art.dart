import 'package:yaml/yaml.dart';

/// Arte procedural con perillas (docs/specs/game_editor.md § 7.5): los
/// parámetros de cada generador como datos (`procedural.yaml`), por
/// familia (sección del manifest, p. ej. `items`) o por entrada
/// (`items.espada`). Dart puro.

/// Tipo de una perilla.
enum ProcKnobKind { color, number, toggle }

/// Una perilla de un generador: clave, tipo, valor por defecto (= aspecto
/// actual) y rango.
class ProcKnob {
  const ProcKnob(this.key, this.label, this.kind, this.byDefault,
      {this.min = 0, this.max = 1, this.step = 0.1, this.allowEmpty = false});
  final String key;
  final String label;
  final ProcKnobKind kind;
  final Object byDefault;
  final double min, max, step;

  /// Color que admite `''` (= el que decide el juego: rareza, material).
  final bool allowEmpty;

  /// [v] normalizado al tipo de la perilla, o `null` si no sirve.
  Object? coerce(Object? v) {
    switch (kind) {
      case ProcKnobKind.color:
        if (v is! String) return null;
        final s = v.trim().toLowerCase();
        if (s.isEmpty) return allowEmpty ? '' : null;
        return RegExp(r'^#[0-9a-f]{6}$').hasMatch(s) ? s : null;
      case ProcKnobKind.number:
        if (v is! num) return null;
        return v.toDouble().clamp(min, max);
      case ProcKnobKind.toggle:
        return v is bool ? v : null;
    }
  }
}

/// Generador `item_icon`: ícono pixel 8×8 de armas e ítems.
const kItemIconKnobs = <ProcKnob>[
  ProcKnob('metal', 'METAL', ProcKnobKind.color, '#c8d2ff'),
  ProcKnob('handle', 'MANGO', ProcKnobKind.color, '#a0703c'),
  ProcKnob('accent', 'ACENTO', ProcKnobKind.color, '', allowEmpty: true),
  ProcKnob('string', 'CUERDA', ProcKnobKind.color, '#e8ecff'),
  ProcKnob('paper', 'PAPEL', ProcKnobKind.color, '#e8dcc0'),
  ProcKnob('cover', 'TAPA', ProcKnobKind.color, '#8e3b46'),
  ProcKnob('glass', 'VIDRIO', ProcKnobKind.color, '#dde6ff'),
  ProcKnob('shine', 'BRILLO', ProcKnobKind.number, 0.0,
      min: -0.5, max: 0.5, step: 0.05),
  ProcKnob('highlight', 'REFLEJO', ProcKnobKind.toggle, false),
  ProcKnob('outline', 'CONTORNO', ProcKnobKind.toggle, false),
  ProcKnob('outline_color', 'COLOR CONTORNO', ProcKnobKind.color, '#14101e'),
  ProcKnob('gem', 'GEMA', ProcKnobKind.toggle, false),
  ProcKnob('mirror', 'ESPEJO', ProcKnobKind.toggle, false),
  ProcKnob('scale', 'PROPORCIÓN', ProcKnobKind.number, 1.0,
      min: 0.5, max: 1, step: 0.125),
  // Identidad del arma (weapon_identity.md § 3): solo se ven en armas
  // concretas (con elemento, rareza, ULT o uid).
  ProcKnob('aura', 'AURA', ProcKnobKind.number, 0.5,
      min: 0, max: 1, step: 0.05),
  ProcKnob('aura_particles', 'PARTÍCULAS AURA', ProcKnobKind.toggle, true),
  ProcKnob('sparkle', 'DESTELLO LEGENDARIO', ProcKnobKind.toggle, true),
  ProcKnob('ult_mark', 'MARCA ULT', ProcKnobKind.toggle, true),
  ProcKnob('variation', 'VARIACIÓN POR ARMA', ProcKnobKind.toggle, true),
];

/// Perillas de cada familia (sección del manifest) con generador.
const kProcKnobs = <String, List<ProcKnob>>{'items': kItemIconKnobs};

/// Parámetros ya resueltos de una entrada.
class ProcParams {
  const ProcParams(this.values);
  final Map<String, Object> values;

  String color(String k) => values[k]! as String;
  double number(String k) => values[k]! as double;
  bool flag(String k) => values[k]! as bool;
}

/// Un documento `procedural.yaml`: perillas por familia y por entrada.
class ProcDoc {
  ProcDoc({Map<String, Map<String, Object>>? families, Map<String, Map<String, Object>>? entries})
      : families = families ?? {},
        entries = entries ?? {};

  final Map<String, Map<String, Object>> families;
  final Map<String, Map<String, Object>> entries;

  bool get isEmpty =>
      families.values.every((m) => m.isEmpty) &&
      entries.values.every((m) => m.isEmpty);

  static const schema = 1;

  /// Lee el texto; perillas desconocidas o inválidas se ignoran (nunca
  /// rompe el juego). [FormatException] si no es YAML de este esquema.
  static ProcDoc parse(String? raw) {
    final d = ProcDoc();
    if (raw == null || raw.trim().isEmpty) return d;
    final Object? doc;
    try {
      doc = loadYaml(raw);
    } catch (_) {
      throw const FormatException('procedural.yaml no es YAML válido.');
    }
    if (doc == null) return d;
    if (doc is! YamlMap || (doc['schema'] as num? ?? 1) > schema) {
      throw const FormatException('procedural.yaml no soportado.');
    }
    void read(Object? m, Map<String, Map<String, Object>> out, String Function(String) family) {
      if (m is! YamlMap) return;
      for (final MapEntry(:key, :value) in m.entries) {
        final id = '$key';
        final knobs = kProcKnobs[family(id)];
        if (knobs == null || value is! YamlMap) continue;
        final p = <String, Object>{};
        for (final k in knobs) {
          final v = k.coerce(value[k.key]);
          if (v != null) p[k.key] = v;
        }
        if (p.isNotEmpty) out[id] = p;
      }
    }

    read(doc['families'], d.families, (id) => id);
    read(doc['entries'], d.entries, (id) => id.split('.').first);
    return d;
  }

  /// Texto YAML estable (claves ordenadas).
  String encode() {
    String val(Object v) => v is String ? "'$v'" : '$v';
    String map(Map<String, Object> m) {
      final ks = m.keys.toList()..sort();
      return '{ ${ks.map((k) => '$k: ${val(m[k]!)}').join(', ')} }';
    }

    final b = StringBuffer('# Perillas del arte procedural '
        '(docs/specs/game_editor.md § 7.5).\nschema: $schema\n');
    for (final (name, m) in [('families', families), ('entries', entries)]) {
      final ids = m.keys.where((k) => m[k]!.isNotEmpty).toList()..sort();
      if (ids.isEmpty) {
        b.writeln('$name: {}');
        continue;
      }
      b.writeln('$name:');
      for (final id in ids) {
        b.writeln('  $id: ${map(m[id]!)}');
      }
    }
    return b.toString();
  }

  /// [other] encima de este (cada perilla de [other] pisa).
  ProcDoc merged(ProcDoc other) {
    Map<String, Map<String, Object>> mix(
        Map<String, Map<String, Object>> a, Map<String, Map<String, Object>> b) => {
          for (final k in {...a.keys, ...b.keys}) k: {...?a[k], ...?b[k]},
        };
    return ProcDoc(
        families: mix(families, other.families),
        entries: mix(entries, other.entries));
  }

  ProcDoc copy() => ProcDoc(
      families: {for (final e in families.entries) e.key: {...e.value}},
      entries: {for (final e in entries.entries) e.key: {...e.value}});
}

/// Registro de los parámetros que usa el juego al dibujar: repo
/// (`assets/sprites/procedural.yaml`) + override local + borrador del
/// Editor (vista previa en tiempo real).
class ProceduralArt {
  ProceduralArt._();

  /// La instancia que leen los pintores del juego.
  static final instance = ProceduralArt._();

  ProcDoc repo = ProcDoc();
  ProcDoc override = ProcDoc();

  /// Borrador del Editor: perillas sin guardar de una entrada o familia.
  ({String id, Map<String, Object> values})? draft;

  /// Cambia con cada carga/borrador (los pintores comparan esto).
  int revision = 0;

  void setRepo(ProcDoc d) {
    repo = d;
    revision++;
  }

  void setOverride(ProcDoc d) {
    override = d;
    revision++;
  }

  void setDraft(String? id, [Map<String, Object>? values]) {
    draft = id == null ? null : (id: id, values: {...?values});
    revision++;
  }

  /// Vuelve todo a los valores por defecto (tests).
  void reset() {
    repo = ProcDoc();
    override = ProcDoc();
    draft = null;
    revision++;
  }

  /// Familia de una entrada `items.espada` → `items`.
  static String familyOf(String entryId) => entryId.split('.').first;

  /// Hay generador con perillas para [entryId] (`items.espada`).
  static bool hasKnobs(String entryId) => kProcKnobs.containsKey(familyOf(entryId));

  /// Parámetros resueltos de [entryId] (`items.espada`): defecto ←
  /// familia/entrada del repo ← familia/entrada del override ← borrador.
  ProcParams resolve(String entryId) {
    final fam = familyOf(entryId);
    final knobs = kProcKnobs[fam] ?? const <ProcKnob>[];
    final v = <String, Object>{for (final k in knobs) k.key: k.byDefault};
    for (final d in [repo, override]) {
      v.addAll(d.families[fam] ?? const {});
      v.addAll(d.entries[entryId] ?? const {});
    }
    final dr = draft;
    if (dr != null && (dr.id == entryId || dr.id == fam)) {
      if (dr.id == fam) {
        // Borrador de familia: va debajo de lo propio de la entrada.
        v.addAll(dr.values);
        v.addAll(repo.entries[entryId] ?? const {});
        v.addAll(override.entries[entryId] ?? const {});
      } else {
        v.addAll(dr.values);
      }
    }
    return ProcParams(v);
  }
}
