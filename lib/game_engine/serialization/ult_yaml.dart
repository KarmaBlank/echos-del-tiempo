import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../balance/balance_codecs.dart'
    show BalanceFieldReader, enemyUltCodec, ultimateCodec;
import '../models/elements.dart';
import '../models/enemy_def.dart';
import '../models/skill.dart';
import '../models/ult_def.dart';

/// Datos de las ULT en YAML (docs/specs/ultimates_v2.md § 5.1): un
/// archivo por ULT (`assets/data/ults/<id>.ult.yaml`, enemigas en
/// `assets/data/enemy_ults/<id>.eult.yaml`) y un índice por carpeta. La
/// animación vive aparte (FXA, campo `fx`). Dart puro: lo usan el
/// cargador de assets, el Editor, el script de exportación y los tests.
///
/// Los campos de la habilidad son los del parche de balance (mismos
/// nombres que `SkillDef` / `EnemyUltDef`); solo se escriben los que no
/// están en su valor por defecto.
abstract final class UltYaml {
  static const schema = 1;
  static const playerDir = 'assets/data/ults/';
  static const enemyDir = 'assets/data/enemy_ults/';
  static const playerManifest = '${playerDir}ult_manifest.yaml';
  static const enemyManifest = '${enemyDir}eult_manifest.yaml';

  // ------------------------------------------------------------------
  // Jugador
  // ------------------------------------------------------------------

  static String playerToYaml(UltDef u) {
    final skill = _diff(ultimateCodec.read(u.skill),
        ultimateCodec.read(SkillDef(id: u.id, name: u.name, kind: u.skill.kind)))
      ..remove('pulse');
    return [
      'schema: $schema',
      'id: ${u.id}',
      'name: ${_s(u.name)}',
      'source: {kind: ${u.source.key}, ref: ${_s(u.ref)}}',
      'weapons: ${_list(u.weapons)}',
      'classes: ${_list(u.classes)}',
      'element: ${u.element.name}',
      'pulse: ${u.skill.pulse}',
      'skill:',
      '  kind: ${u.skill.kind.name}',
      for (final e in skill.entries) '  ${e.key}: ${jsonEncode(e.value)}',
      'fx: ${u.fx}',
      '',
    ].join('\n');
  }

  /// Lee una ULT de jugador. Lanza [FormatException] si falta lo esencial.
  static UltDef playerFromYaml(String raw) {
    final doc = _map(loadYaml(raw), 'ULT');
    _schema(doc);
    final id = _str(doc, 'id');
    final name = _str(doc, 'name');
    final src = _map(doc['source'], 'source');
    final source = UltSource.byKey(src['kind'] as String?) ??
        (throw FormatException('fuente desconocida', src['kind']));
    final sk = _map(doc['skill'], 'skill');
    final kind = SkillKind.values.asNameMap()[sk['kind']] ??
        (throw FormatException('kind desconocido', sk['kind']));
    final base = SkillDef(id: id, name: name, kind: kind);
    final values = {
      ...ultimateCodec.read(base),
      for (final e in sk.entries)
        // `ultCost` / `cost` de datos viejos: se ignoran (toda ULT
        // cuesta la barra llena).
        if (e.key != 'kind' && e.key != 'ultCost') '${e.key}': _plain(e.value),
      'pulse': (doc['pulse'] as num?)?.toInt() ?? 0,
    };
    final skill = ultimateCodec.write(base, BalanceFieldReader(values)) as SkillDef;
    return UltDef(
      skill: skill,
      source: source,
      ref: '${src['ref'] ?? ''}',
      element: GameElement.values.asNameMap()[doc['element']] ??
          GameElement.fisico,
      weapons: _strings(doc['weapons']),
      classes: _strings(doc['classes']),
    );
  }

  // ------------------------------------------------------------------
  // Enemigas
  // ------------------------------------------------------------------

  static String enemyToYaml(EnemyUltDef u, {String? owner, bool elite = false}) {
    final f = _diff(enemyUltCodec.read(u),
        enemyUltCodec.read(EnemyUltDef(id: u.id, name: u.name, power: 0)));
    return [
      'schema: $schema',
      'id: ${u.id}',
      'name: ${_s(u.name)}',
      if (owner != null) 'owner: $owner',
      'elite: $elite',
      'extra: ${u.extra.name}',
      'ult:',
      for (final e in f.entries) '  ${e.key}: ${jsonEncode(e.value)}',
      'fx: ${u.id}',
      '',
    ].join('\n');
  }

  static EnemyUltDef enemyFromYaml(String raw) {
    final doc = _map(loadYaml(raw), 'ULT enemiga');
    _schema(doc);
    final id = _str(doc, 'id');
    final name = _str(doc, 'name');
    final extra = EnemyUltExtra.values.asNameMap()[doc['extra']] ??
        EnemyUltExtra.none;
    final base = EnemyUltDef(id: id, name: name, power: 0, extra: extra);
    final u = _map(doc['ult'] ?? const {}, 'ult');
    final values = {
      ...enemyUltCodec.read(base),
      for (final e in u.entries) '${e.key}': _plain(e.value),
    };
    return enemyUltCodec.write(base, BalanceFieldReader(values)) as EnemyUltDef;
  }

  // ------------------------------------------------------------------
  // Índices
  // ------------------------------------------------------------------

  static String manifestToYaml(String key, Map<String, String> files) => [
        '# Índice de ULT en datos (docs/specs/ultimates_v2.md § 5.1).',
        'schema: $schema',
        '$key:',
        for (final e in files.entries) '  ${e.key}: ${e.value}',
        '',
      ].join('\n');

  /// id → archivo (relativo a la carpeta del índice).
  static Map<String, String> manifestFromYaml(String raw, String key) {
    final doc = loadYaml(raw);
    final m = doc is YamlMap ? doc[key] : null;
    return {
      if (m is YamlMap)
        for (final e in m.entries)
          if (e.value is String) '${e.key}': e.value as String,
    };
  }

  // ------------------------------------------------------------------

  static Map<String, Object?> _diff(
          Map<String, Object?> v, Map<String, Object?> def) =>
      {
        for (final e in v.entries)
          if (jsonEncode(e.value) != jsonEncode(def[e.key])) e.key: e.value,
      }..remove('disabled');

  static String _s(String v) => jsonEncode(v);
  static String _list(List<String> l) => '[${l.map(_s).join(', ')}]';

  static void _schema(Map doc) {
    final v = doc['schema'];
    if (v is num && v > schema) {
      throw FormatException('schema $v más nuevo que $schema');
    }
  }

  static Map _map(Object? v, String what) =>
      v is Map ? v : throw FormatException('$what: no es un mapa', v);

  static String _str(Map doc, String key) {
    final v = doc[key];
    if (v is String && v.isNotEmpty) return v;
    throw FormatException('falta $key', v);
  }

  static List<String> _strings(Object? v) =>
      v is List ? [for (final e in v) '$e'] : const [];

  /// YAML → valores planos (mapas y listas de Dart).
  static Object? _plain(Object? v) => switch (v) {
        YamlMap() => {for (final e in v.entries) '${e.key}': _plain(e.value)},
        YamlList() => [for (final e in v) _plain(e)],
        _ => v,
      };
}
