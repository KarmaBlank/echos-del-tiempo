import 'dart:convert';

import '../data/game_catalog.dart';
import '../models/abyss.dart';
import '../models/class_def.dart';
import '../models/elements.dart';
import '../models/enemy_def.dart';
import '../models/skill.dart';
import '../models/weapon.dart';
import '../rules/mulberry32.dart' show imul32;
import 'balance_codecs.dart';
import 'balance_fields.dart';
import 'balance_registries.dart';

/// Versión del formato de `balance.json` que entiende este código.
const kBalanceSchema = 1;

/// Hash de balance sin parche (docs/specs/balance_admin.md § 4).
const kBaseBalanceHash = GameCatalog.baseBalanceHash;

/// Un problema de un `balance.json` (ruta `skill.sismo.power`).
class BalanceIssue {
  const BalanceIssue(this.path, this.message, {this.error = true});

  final String path;
  final String message;

  /// Error (la entrada se descarta) o aviso (se aplica igual).
  final bool error;

  @override
  String toString() => '${error ? 'ERROR' : 'AVISO'} $path: $message';
}

/// Resultado de leer un `balance.json`: el parche ya filtrado (solo lo
/// válido) y los problemas encontrados.
class BalanceParseResult {
  const BalanceParseResult(this.patch, this.issues);

  final BalancePatch patch;
  final List<BalanceIssue> issues;

  bool get hasErrors => issues.any((i) => i.error);
}

/// Overrides por tipo → id → campo → valor (JSON canónico).
typedef BalanceOverrides = Map<BalanceKind, Map<String, Map<String, Object?>>>;

/// Un parche de balance (docs/specs/balance_admin.md § 1). Inmutable:
/// las ediciones del admin devuelven uno nuevo.
class BalancePatch {
  const BalancePatch({
    this.schema = kBalanceSchema,
    this.basedOn = '',
    this.overrides = const {},
  });

  static const empty = BalancePatch();

  final int schema;

  /// Versión del juego con la que se armó (informativo).
  final String basedOn;
  final BalanceOverrides overrides;

  bool get isEmpty => overrides.values
      .every((byId) => byId.values.every((fields) => fields.isEmpty));

  /// Los overrides de una entidad (vacío si no tiene).
  Map<String, Object?> fieldsOf(BalanceKind kind, String id) =>
      overrides[kind]?[id] ?? const {};

  /// Cantidad de entidades tocadas.
  int get entityCount => overrides.values
      .fold(0, (n, byId) => n + byId.values.where((f) => f.isNotEmpty).length);

  // ------------------------------------------------------------------
  // Lectura y validación
  // ------------------------------------------------------------------

  /// Lee el texto de un `balance.json`. Nunca lanza: lo inválido se
  /// descarta y queda en [BalanceParseResult.issues] (§ 2).
  static BalanceParseResult parse(String text, BalanceBase base) {
    if (text.trim().isEmpty) return const BalanceParseResult(empty, []);
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (e) {
      return BalanceParseResult(
          empty, [BalanceIssue('balance.json', 'JSON inválido: ${e.message}')]);
    }
    return fromJson(json, base);
  }

  static BalanceParseResult fromJson(Object? json, BalanceBase base) {
    final issues = <BalanceIssue>[];
    BalanceParseResult fail(String msg) =>
        BalanceParseResult(empty, [BalanceIssue('balance.json', msg)]);

    if (json is! Map) return fail('la raíz debe ser un objeto');
    final schema = json['schema'] ?? kBalanceSchema;
    if (schema is! int || schema < 1 || schema > kBalanceSchema) {
      return fail('schema "$schema" no soportado (este juego entiende hasta '
          '$kBalanceSchema): actualizá el juego');
    }
    final basedOn = json['basedOn'] is String ? json['basedOn'] as String : '';
    final raw = json['overrides'] ?? const {};
    if (raw is! Map) return fail('"overrides" debe ser un objeto');

    final out = <BalanceKind, Map<String, Map<String, Object?>>>{};
    for (final kindEntry in raw.entries) {
      final kindKey = '${kindEntry.key}';
      final kind = BalanceKind.byJsonKey(kindKey);
      if (kind == null) {
        issues.add(BalanceIssue(kindKey, 'tipo de entidad desconocido'));
        continue;
      }
      final entries = kindEntry.value;
      if (entries is! Map) {
        issues.add(BalanceIssue(kindKey, 'debe ser un objeto id → campos'));
        continue;
      }
      final entities = base.entities(kind);
      final codec = codecOf(kind);
      for (final e in entries.entries) {
        final id = '${e.key}';
        final path = '$kindKey.$id';
        final entity = entities[id];
        if (entity == null) {
          issues.add(BalanceIssue(path, 'no existe en el catálogo'));
          continue;
        }
        final fields = e.value;
        if (fields is! Map) {
          issues.add(BalanceIssue(path, 'debe ser un objeto campo → valor'));
          continue;
        }
        final current = codec.read(entity);
        final valid = <String, Object?>{};
        for (final f in fields.entries) {
          final key = '${f.key}';
          final spec = codec.field(key);
          if (spec == null) {
            issues.add(BalanceIssue('$path.$key',
                key == 'disabled'
                    ? '${kind.plural} no se pueden desactivar'
                    : 'campo desconocido o no editable'));
            continue;
          }
          final check = validateBalanceValue(spec, f.value, base.context);
          if (!check.ok) {
            issues.add(BalanceIssue('$path.$key', check.error!));
            continue;
          }
          // Igual al código: no es un cambio (forma canónica mínima).
          if (balanceJsonEquals(check.value, current[key])) continue;
          valid[key] = check.value;
        }
        issues.addAll(warningsFor(kind, id, entity, current, valid));
        if (valid.isNotEmpty) (out[kind] ??= {})[id] = valid;
      }
    }
    return BalanceParseResult(
        BalancePatch(basedOn: basedOn, overrides: _freeze(out)), issues);
  }

  /// Avisos que no descartan nada (§ 2).
  static List<BalanceIssue> warningsFor(BalanceKind kind, String id,
      Object entity, Map<String, Object?> current, Map<String, Object?> patch) {
    final merged = {...current, ...patch};
    final path = '${kind.jsonKey}.$id';
    final out = <BalanceIssue>[];
    if ((kind == BalanceKind.skill || kind == BalanceKind.ultimate) &&
        entity is SkillDef &&
        entity.dealsDamage &&
        (merged['power'] as num) <= 0) {
      out.add(BalanceIssue('$path.power', 'habilidad de daño con poder 0',
          error: false));
    }
    if (kind == BalanceKind.weapon && (merged['skillIds'] as List).isEmpty) {
      out.add(BalanceIssue('$path.skillIds', 'arma sin habilidades', error: false));
    }
    if (kind == BalanceKind.mechanic &&
        !patch.containsKey('description') &&
        patch.keys.any((k) => k != 'disabled')) {
      out.add(BalanceIssue('$path.description',
          'cambiaron los números pero no la descripción', error: false));
    }
    return out;
  }

  static BalanceOverrides _freeze(BalanceOverrides o) => Map.unmodifiable({
        for (final k in o.entries)
          if (k.value.isNotEmpty)
            k.key: Map<String, Map<String, Object?>>.unmodifiable({
              for (final e in k.value.entries)
                if (e.value.isNotEmpty) e.key: Map<String, Object?>.unmodifiable(e.value),
            }),
      });

  // ------------------------------------------------------------------
  // Escritura
  // ------------------------------------------------------------------

  Map<String, Object?> toJson() => {
        'schema': schema,
        'basedOn': basedOn,
        'overrides': {
          for (final kind in BalanceKind.values)
            if (overrides[kind]?.isNotEmpty ?? false)
              kind.jsonKey: {
                for (final id in (overrides[kind]!.keys.toList()..sort()))
                  if (overrides[kind]![id]!.isNotEmpty)
                    id: {
                      for (final f in (overrides[kind]![id]!.keys.toList()..sort()))
                        f: overrides[kind]![id]![f],
                    },
              },
        },
      };

  /// El archivo tal como se guarda: con sangría y salto final.
  String toPrettyJson() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  /// Hash del contenido (§ 4): `"base"` sin cambios; si no, FNV-1a de 32
  /// bits del JSON canónico de los overrides.
  String get hash {
    if (isEmpty) return kBaseBalanceHash;
    var h = 0x811C9DC5;
    for (final byte in utf8.encode(canonicalJson(toJson()['overrides']))) {
      h = imul32(h ^ byte, 0x01000193);
    }
    return 'b$schema-${h.toRadixString(16).padLeft(8, '0')}';
  }

  // ------------------------------------------------------------------
  // Edición (admin)
  // ------------------------------------------------------------------

  /// Con el campo [key] de [kind]/[id] en [value]; si [value] es igual al
  /// del código ([baseValue]), se quita (la entrada queda mínima).
  BalancePatch withField(BalanceKind kind, String id, String key, Object? value,
      {required Object? baseValue}) {
    final next = _mutable();
    final fields = (next[kind] ??= {})[id] ??= {};
    if (balanceJsonEquals(value, baseValue)) {
      fields.remove(key);
    } else {
      fields[key] = value;
    }
    return BalancePatch(schema: schema, basedOn: basedOn, overrides: _freeze(next));
  }

  /// Sin ningún override de [kind]/[id].
  BalancePatch withoutEntity(BalanceKind kind, String id) {
    final next = _mutable();
    next[kind]?.remove(id);
    return BalancePatch(schema: schema, basedOn: basedOn, overrides: _freeze(next));
  }

  BalancePatch withBasedOn(String version) =>
      BalancePatch(schema: schema, basedOn: version, overrides: overrides);

  BalanceOverrides _mutable() => {
        for (final k in overrides.entries)
          k.key: {
            for (final e in k.value.entries) e.key: Map.of(e.value),
          },
      };

  // ------------------------------------------------------------------
  // Aplicación
  // ------------------------------------------------------------------

  /// Los valores efectivos (código + override) de una entidad.
  Map<String, Object?> effectiveFields(
          BalanceBase base, BalanceKind kind, String id) =>
      {
        ...codecOf(kind).read(base.entities(kind)[id]!),
        ...fieldsOf(kind, id),
      };

  /// [catalog] con este parche (§ 3). Vacío → el mismo objeto.
  GameCatalog applyTo(GameCatalog catalog) {
    if (isEmpty) return catalog;
    Map<String, T> patched<T extends Object>(
        BalanceKind kind, Map<String, T> src) {
      final o = overrides[kind];
      if (o == null || o.isEmpty) return src;
      final codec = codecOf(kind);
      return Map.unmodifiable({
        for (final e in src.entries)
          e.key: o[e.key] == null || o[e.key]!.isEmpty
              ? e.value
              : codec.write(e.value,
                  BalanceFieldReader({...codec.read(e.value), ...o[e.key]!})) as T,
      });
    }

    var weapons = patched<WeaponDef>(BalanceKind.weapon, catalog.weapons);
    final disabled = {
      for (final e in (overrides[BalanceKind.skill] ?? const {}).entries)
        if (e.value['disabled'] == true) e.key,
    };
    if (disabled.isNotEmpty) {
      weapons = Map.unmodifiable({
        for (final e in weapons.entries)
          e.key: e.value.skillIds.any(disabled.contains)
              ? weaponWithSkills(e.value,
                  [for (final s in e.value.skillIds) if (!disabled.contains(s)) s])
              : e.value,
      });
    }
    return GameCatalog(
      classes: patched<ClassDef>(BalanceKind.classDef, catalog.classes),
      weapons: weapons,
      skills: patched<SkillDef>(BalanceKind.skill, catalog.skills),
      ultimates: patched<SkillDef>(BalanceKind.ultimate, catalog.ultimates),
      duals: patched<DualDef>(BalanceKind.dual, catalog.duals),
      enemies: patched<EnemyDef>(BalanceKind.enemy, catalog.enemies),
      enemyUlts: patched<EnemyUltDef>(BalanceKind.enemyUlt, catalog.enemyUlts),
      missions: catalog.missions,
      zones: catalog.zones,
      balanceHash: hash,
      reactions: patched<ReactionDef>(BalanceKind.reaction, catalog.reactions),
      elementStatuses: patched<ElementStatusDef>(
          BalanceKind.elementStatus, catalog.elementStatuses),
      abyssBosses: {
        for (final e in patched<AbyssBossDef>(BalanceKind.abyssBoss, {
          for (final b in catalog.abyssBosses.entries) '${b.key}': b.value,
        }).entries)
          int.parse(e.key): e.value,
      },
      fragmentDrops: patched<FragmentDropDef>(
          BalanceKind.fragmentDrop, catalog.fragmentDrops),
    );
  }

  /// Instala la parte de registros globales (afijos, nodos, mecánicas).
  void installRegistries() => BalanceRegistries.install(overrides);
}
