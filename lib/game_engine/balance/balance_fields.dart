import '../models/attributes.dart';
import '../models/item.dart';
import '../models/passive_mechanic.dart';
import '../models/skill.dart';
import '../models/status.dart';
import '../models/weapon.dart';

/// Tipo de un campo editable de balance (docs/specs/balance_admin.md § 1.1).
/// Cada tipo tiene su codificación JSON, su validación y su editor.
enum BalanceFieldType {
  integer,
  decimal,

  /// Fracción (0.15) que la UI muestra como porcentaje (15%).
  fraction,
  flag,

  /// `StatusApplication?`: `{"kind":"burn","stacks":2,"chance":0.3}`.
  status,
  statusList,

  /// `PartyBuff?`: `{"stat":"attack","value":0.2,"turns":2}`.
  buff,
  buffList,

  /// `Map<Attribute, int>`: `{"fue":18}`.
  attributes,

  /// `PowerFormula?`: `{"base":16,"fue":0.85}`.
  formula,

  /// Ids de habilidades.
  idList,

  /// Tiers de un afijo.
  tiers,

  /// Efectos numéricos de un nodo del árbol: `{"atk":0.05}`.
  numberMap,

  /// Efectos de una mecánica (`ProcEffect`).
  procEffects,

  /// `StatusKind?` suelto (filtro de una mecánica).
  statusKind,
  text,
}

/// Un campo editable de una entidad.
class BalanceField {
  const BalanceField(
    this.key,
    this.label,
    this.type, {
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.nullable = false,
  });

  final String key;

  /// Etiqueta en castellano ("Poder", "Crítico extra").
  final String label;
  final BalanceFieldType type;

  /// Rango de los números del campo (también los de adentro de un estado
  /// o un buff usan sus propios rangos fijos, ver [validateBalanceValue]).
  final double min, max;

  /// Paso de los botones ±.
  final double step;

  /// Admite `null` (sin estado, sin MAG, sin buff propio).
  final bool nullable;

  bool get numeric =>
      type == BalanceFieldType.integer ||
      type == BalanceFieldType.decimal ||
      type == BalanceFieldType.fraction;
}

/// Datos de referencia para validar (ids que existen, claves válidas).
class BalanceContext {
  const BalanceContext({required this.skillIds, required this.nodeEffectKeys});

  final Set<String> skillIds;
  final Set<String> nodeEffectKeys;
}

// ---------------------------------------------------------------------
// Codificación (modelo → JSON canónico)
// ---------------------------------------------------------------------

Object? encodeStatus(StatusApplication? s) => s == null
    ? null
    : {
        'kind': s.kind.name,
        'stacks': s.stacks,
        if (s.chance != null) 'chance': s.chance,
      };

List<Object?> encodeStatusList(List<StatusApplication> l) =>
    [for (final s in l) encodeStatus(s)];

Object? encodeBuff(PartyBuff? b) => b == null
    ? null
    : {'stat': b.stat.name, 'value': b.value, 'turns': b.turns};

List<Object?> encodeBuffList(List<PartyBuff> l) => [for (final b in l) encodeBuff(b)];

Map<String, Object?> encodeAttributes(Map<Attribute, int> m) => {
      for (final a in Attribute.values)
        if (m.containsKey(a)) a.name: m[a],
    };

Object? encodeFormula(PowerFormula? f) => f == null
    ? null
    : {
        'base': f.base,
        for (final a in Attribute.values)
          if (f.coefficients.containsKey(a)) a.name: f.coefficients[a],
      };

List<Object?> encodeTiers(List<AffixTier> l) => [
      for (final t in l)
        {
          'tier': t.tier,
          'minLevel': t.minLevel,
          'min': t.min,
          'max': t.max,
          'weight': t.weight,
        },
    ];

List<Object?> encodeProcEffects(List<ProcEffect> l) => [
      for (final e in l)
        {
          'kind': e.kind.name,
          'value': e.value,
          'turns': e.turns,
          'stat': e.stat?.name,
          'status': e.status?.name,
        },
    ];

// ---------------------------------------------------------------------
// Decodificación (JSON ya validado → modelo)
// ---------------------------------------------------------------------

StatusApplication? decodeStatus(Object? v) {
  if (v is! Map) return null;
  return StatusApplication(
    StatusKind.values.byName(v['kind'] as String),
    (v['stacks'] as num).toInt(),
    chance: (v['chance'] as num?)?.toDouble(),
  );
}

List<StatusApplication> decodeStatusList(Object? v) => [
      for (final x in (v as List? ?? const [])) decodeStatus(x)!,
    ];

PartyBuff? decodeBuff(Object? v) {
  if (v is! Map) return null;
  return PartyBuff(BuffStat.values.byName(v['stat'] as String),
      (v['value'] as num).toDouble(), (v['turns'] as num).toInt());
}

List<PartyBuff> decodeBuffList(Object? v) => [
      for (final x in (v as List? ?? const [])) decodeBuff(x)!,
    ];

Map<Attribute, int> decodeAttributes(Object? v) => {
      for (final e in (v as Map? ?? const {}).entries)
        Attribute.values.byName(e.key as String): (e.value as num).toInt(),
    };

PowerFormula? decodeFormula(Object? v) {
  if (v is! Map) return null;
  return PowerFormula(
    base: (v['base'] as num).toDouble(),
    coefficients: {
      for (final e in v.entries)
        if (e.key != 'base')
          Attribute.values.byName(e.key as String): (e.value as num).toDouble(),
    },
  );
}

List<AffixTier> decodeTiers(Object? v) => [
      for (final t in (v as List? ?? const []))
        AffixTier(
          ((t as Map)['tier'] as num).toInt(),
          (t['minLevel'] as num).toInt(),
          (t['min'] as num).toInt(),
          (t['max'] as num).toInt(),
          (t['weight'] as num).toInt(),
        ),
    ];

List<ProcEffect> decodeProcEffects(Object? v) => [
      for (final e in (v as List? ?? const []))
        ProcEffect(
          ProcEffectKind.values.byName((e as Map)['kind'] as String),
          value: (e['value'] as num? ?? 0).toDouble(),
          turns: (e['turns'] as num? ?? 0).toInt(),
          stat: e['stat'] == null
              ? null
              : BuffStat.values.byName(e['stat'] as String),
          status: e['status'] == null
              ? null
              : StatusKind.values.byName(e['status'] as String),
        ),
    ];

Map<String, num> decodeNumberMap(Object? v) => {
      for (final e in (v as Map? ?? const {}).entries)
        e.key as String: e.value as num,
    };

StatusKind? decodeStatusKind(Object? v) =>
    v is String ? StatusKind.values.byName(v) : null;

// ---------------------------------------------------------------------
// Validación + normalización
// ---------------------------------------------------------------------

/// Resultado de validar un valor: el valor normalizado (enteros como
/// `int`, mapas en orden canónico) o el error en castellano.
class BalanceValueCheck {
  const BalanceValueCheck.ok(this.value) : error = null;
  const BalanceValueCheck.fail(this.error) : value = null;

  final Object? value;
  final String? error;
  bool get ok => error == null;
}

bool _isInt(Object? v) => v is num && v.isFinite && v == v.roundToDouble();
bool _isNum(Object? v) => v is num && v.isFinite;

Set<String> _names(List<Enum> values) => {for (final v in values) v.name};

final _statusNames = _names(StatusKind.values);
final _buffNames = _names(BuffStat.values);
final _attrNames = _names(Attribute.values);
final _procNames = _names(ProcEffectKind.values);

String _fmtRange(num a, num b) => '${_trim(a)}..${_trim(b)}';
String _trim(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Valida [v] para [f] y lo devuelve normalizado.
BalanceValueCheck validateBalanceValue(
    BalanceField f, Object? v, BalanceContext ctx) {
  String? rangeErr(num x, num lo, num hi) =>
      x < lo || x > hi ? 'fuera de rango (${_fmtRange(lo, hi)})' : null;

  if (v == null) {
    return f.nullable || f.type == BalanceFieldType.statusKind
        ? const BalanceValueCheck.ok(null)
        : const BalanceValueCheck.fail('no puede ser vacío');
  }

  BalanceValueCheck status(Object? s) {
    if (s is! Map) return const BalanceValueCheck.fail('estado inválido');
    final extra = s.keys.where((k) => !{'kind', 'stacks', 'chance'}.contains(k));
    if (extra.isNotEmpty) {
      return BalanceValueCheck.fail('estado: clave desconocida "${extra.first}"');
    }
    final kind = s['kind'];
    if (kind is! String || !_statusNames.contains(kind)) {
      return BalanceValueCheck.fail('estado desconocido "$kind"');
    }
    final stacks = s['stacks'];
    if (!_isInt(stacks) || (stacks as num) < 1 || stacks > 99) {
      return const BalanceValueCheck.fail('stacks: entero 1..99');
    }
    final chance = s['chance'];
    if (chance != null && (!_isNum(chance) || (chance as num) < 0 || chance > 1)) {
      return const BalanceValueCheck.fail('probabilidad: 0..1');
    }
    return BalanceValueCheck.ok({
      'kind': kind,
      'stacks': stacks.toInt(),
      if (chance != null) 'chance': chance,
    });
  }

  BalanceValueCheck buff(Object? b) {
    if (b is! Map) return const BalanceValueCheck.fail('buff inválido');
    final stat = b['stat'];
    if (stat is! String || !_buffNames.contains(stat)) {
      return BalanceValueCheck.fail('stat desconocida "$stat"');
    }
    final value = b['value'];
    if (!_isNum(value) || (value as num) < -5 || value > 5) {
      return const BalanceValueCheck.fail('valor del buff: -5..5');
    }
    final turns = b['turns'];
    if (!_isInt(turns) || (turns as num) < 0 || turns > 20) {
      return const BalanceValueCheck.fail('turnos del buff: entero 0..20');
    }
    return BalanceValueCheck.ok(
        {'stat': stat, 'value': value, 'turns': turns.toInt()});
  }

  BalanceValueCheck list(Object? l, BalanceValueCheck Function(Object?) item,
      {int max = 8}) {
    if (l is! List) return const BalanceValueCheck.fail('se esperaba una lista');
    if (l.length > max) return BalanceValueCheck.fail('máximo $max elementos');
    final out = <Object?>[];
    for (var i = 0; i < l.length; i++) {
      final c = item(l[i]);
      if (!c.ok) return BalanceValueCheck.fail('[${i + 1}] ${c.error}');
      out.add(c.value);
    }
    return BalanceValueCheck.ok(out);
  }

  switch (f.type) {
    case BalanceFieldType.integer:
      if (!_isInt(v)) return const BalanceValueCheck.fail('se esperaba un entero');
      final e = rangeErr(v as num, f.min, f.max);
      return e == null ? BalanceValueCheck.ok(v.toInt()) : BalanceValueCheck.fail(e);
    case BalanceFieldType.decimal:
    case BalanceFieldType.fraction:
      if (!_isNum(v)) return const BalanceValueCheck.fail('se esperaba un número');
      final e = rangeErr(v as num, f.min, f.max);
      return e == null ? BalanceValueCheck.ok(v) : BalanceValueCheck.fail(e);
    case BalanceFieldType.flag:
      return v is bool
          ? BalanceValueCheck.ok(v)
          : const BalanceValueCheck.fail('se esperaba true/false');
    case BalanceFieldType.status:
      return status(v);
    case BalanceFieldType.statusList:
      return list(v, status, max: 6);
    case BalanceFieldType.buff:
      return buff(v);
    case BalanceFieldType.buffList:
      return list(v, buff, max: 6);
    case BalanceFieldType.attributes:
      if (v is! Map) return const BalanceValueCheck.fail('se esperaba un mapa de atributos');
      final out = <String, Object?>{};
      for (final a in Attribute.values) {
        if (!v.containsKey(a.name)) continue;
        final x = v[a.name];
        if (!_isInt(x) || (x as num) < 0 || x > 300) {
          return BalanceValueCheck.fail('${a.name}: entero 0..300');
        }
        out[a.name] = x.toInt();
      }
      final bad = v.keys.where((k) => !_attrNames.contains(k));
      if (bad.isNotEmpty) return BalanceValueCheck.fail('atributo desconocido "${bad.first}"');
      return BalanceValueCheck.ok(out);
    case BalanceFieldType.formula:
      if (v is! Map) return const BalanceValueCheck.fail('fórmula inválida');
      final base = v['base'];
      if (!_isNum(base) || (base as num) < 0 || base > 500) {
        return const BalanceValueCheck.fail('base: 0..500');
      }
      final out = <String, Object?>{'base': base};
      for (final a in Attribute.values) {
        if (!v.containsKey(a.name)) continue;
        final x = v[a.name];
        if (!_isNum(x) || (x as num) < 0 || x > 10) {
          return BalanceValueCheck.fail('coeficiente ${a.name}: 0..10');
        }
        out[a.name] = x;
      }
      final bad = v.keys.where((k) => k != 'base' && !_attrNames.contains(k));
      if (bad.isNotEmpty) return BalanceValueCheck.fail('atributo desconocido "${bad.first}"');
      return BalanceValueCheck.ok(out);
    case BalanceFieldType.idList:
      if (v is! List) return const BalanceValueCheck.fail('se esperaba una lista de ids');
      if (v.length > 8) return const BalanceValueCheck.fail('máximo 8 habilidades');
      final seen = <String>{};
      for (final id in v) {
        if (id is! String || !ctx.skillIds.contains(id)) {
          return BalanceValueCheck.fail('habilidad inexistente "$id"');
        }
        if (!seen.add(id)) return BalanceValueCheck.fail('habilidad repetida "$id"');
      }
      return BalanceValueCheck.ok(List<String>.from(v));
    case BalanceFieldType.tiers:
      if (v is! List || v.isEmpty) {
        return const BalanceValueCheck.fail('se esperaba al menos un tier');
      }
      if (v.length > 10) return const BalanceValueCheck.fail('máximo 10 tiers');
      final tiers = <int>{};
      final out = <Object?>[];
      for (final t in v) {
        if (t is! Map) return const BalanceValueCheck.fail('tier inválido');
        final keys = ['tier', 'minLevel', 'min', 'max', 'weight'];
        for (final k in keys) {
          if (!_isInt(t[k])) return BalanceValueCheck.fail('tier: "$k" debe ser entero');
        }
        final tier = (t['tier'] as num).toInt();
        final minLevel = (t['minLevel'] as num).toInt();
        final lo = (t['min'] as num).toInt();
        final hi = (t['max'] as num).toInt();
        final w = (t['weight'] as num).toInt();
        if (tier < 1 || tier > 10) return const BalanceValueCheck.fail('tier: 1..10');
        if (!tiers.add(tier)) return BalanceValueCheck.fail('T$tier repetido');
        if (minLevel < 1 || minLevel > 100) {
          return BalanceValueCheck.fail('T$tier: nivel mínimo 1..100');
        }
        if (lo < -1000 || hi > 10000) return BalanceValueCheck.fail('T$tier: valores fuera de rango');
        if (hi < lo) return BalanceValueCheck.fail('T$tier: máximo ($hi) menor que mínimo ($lo)');
        if (w < 0 || w > 100000) return BalanceValueCheck.fail('T$tier: peso 0..100000');
        out.add({'tier': tier, 'minLevel': minLevel, 'min': lo, 'max': hi, 'weight': w});
      }
      return BalanceValueCheck.ok(out);
    case BalanceFieldType.numberMap:
      if (v is! Map) return const BalanceValueCheck.fail('se esperaba un mapa de efectos');
      final out = <String, Object?>{};
      for (final e in v.entries) {
        final k = e.key;
        if (k is! String || !ctx.nodeEffectKeys.contains(k)) {
          return BalanceValueCheck.fail('efecto desconocido "$k"');
        }
        if (!_isNum(e.value) || (e.value as num).abs() > 1000) {
          return BalanceValueCheck.fail('$k: número -1000..1000');
        }
        out[k] = e.value;
      }
      return BalanceValueCheck.ok(out);
    case BalanceFieldType.procEffects:
      return list(v, (e) {
        if (e is! Map) return const BalanceValueCheck.fail('efecto inválido');
        final kind = e['kind'];
        if (kind is! String || !_procNames.contains(kind)) {
          return BalanceValueCheck.fail('tipo de efecto desconocido "$kind"');
        }
        final value = e['value'] ?? 0;
        if (!_isNum(value) || (value as num) < -100 || value > 1000) {
          return const BalanceValueCheck.fail('valor: -100..1000');
        }
        final turns = e['turns'] ?? 0;
        if (!_isInt(turns) || (turns as num) < 0 || turns > 20) {
          return const BalanceValueCheck.fail('turnos: entero 0..20');
        }
        final stat = e['stat'];
        if (stat != null && (stat is! String || !_buffNames.contains(stat))) {
          return BalanceValueCheck.fail('stat desconocida "$stat"');
        }
        final st = e['status'];
        if (st != null && (st is! String || !_statusNames.contains(st))) {
          return BalanceValueCheck.fail('estado desconocido "$st"');
        }
        return BalanceValueCheck.ok({
          'kind': kind,
          'value': value,
          'turns': turns.toInt(),
          'stat': stat,
          'status': st,
        });
      });
    case BalanceFieldType.statusKind:
      return v is String && _statusNames.contains(v)
          ? BalanceValueCheck.ok(v)
          : BalanceValueCheck.fail('estado desconocido "$v"');
    case BalanceFieldType.text:
      if (v is! String) return const BalanceValueCheck.fail('se esperaba texto');
      if (v.length > 600) return const BalanceValueCheck.fail('máximo 600 caracteres');
      return BalanceValueCheck.ok(v);
  }
}

// ---------------------------------------------------------------------
// Igualdad y forma canónica de valores JSON
// ---------------------------------------------------------------------

/// Igualdad profunda de valores JSON (`1 == 1.0`).
bool balanceJsonEquals(Object? a, Object? b) {
  if (a is num && b is num) return (a - b).abs() < 1e-9;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!balanceJsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    final keys = {...a.keys, ...b.keys};
    for (final k in keys) {
      if (!balanceJsonEquals(a[k], b[k])) return false;
    }
    return true;
  }
  return a == b;
}

/// Texto JSON canónico: claves ordenadas, números enteros sin decimales y
/// el resto con hasta 6 decimales (igual en la VM y en web).
String canonicalJson(Object? v) {
  if (v == null) return 'null';
  if (v is bool) return v ? 'true' : 'false';
  if (v is num) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    var s = v.toStringAsFixed(6);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
  if (v is String) {
    final b = StringBuffer('"');
    for (final c in v.runes) {
      if (c == 0x22) {
        b.write(r'\"');
      } else if (c == 0x5C) {
        b.write(r'\\');
      } else if (c < 0x20) {
        b.write('\\u${c.toRadixString(16).padLeft(4, '0')}');
      } else {
        b.writeCharCode(c);
      }
    }
    b.write('"');
    return b.toString();
  }
  if (v is List) return '[${v.map(canonicalJson).join(',')}]';
  if (v is Map) {
    final keys = [for (final k in v.keys) k.toString()]..sort();
    return '{${keys.map((k) => '${canonicalJson(k)}:${canonicalJson(v[k])}').join(',')}}';
  }
  return canonicalJson(v.toString());
}
