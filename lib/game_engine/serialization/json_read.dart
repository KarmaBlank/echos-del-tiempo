/// Lectura estricta de JSON para los mensajes de red (docs/specs/netcode.md).
///
/// A diferencia de `PlayerProfile.fromJson` (tolerante, para un archivo
/// guardado), lo que llega por red y no tiene la forma esperada lanza
/// [FormatException]: la capa de red descarta ese mensaje entero.
library;

typedef Json = Map<String, Object?>;

Never _bad(String what, Object? v) =>
    throw FormatException('JSON inválido: se esperaba $what', v);

Json asJson(Object? v) {
  if (v is Map<String, Object?>) return v;
  if (v is Map) {
    final out = <String, Object?>{};
    for (final e in v.entries) {
      final k = e.key;
      if (k is! String) _bad('clave texto', k);
      out[k] = e.value;
    }
    return out;
  }
  _bad('objeto', v);
}

List<Object?> asList(Object? v) => v is List ? v : _bad('lista', v);

extension JsonRead on Json {
  Object? _req(String k) {
    if (!containsKey(k)) throw FormatException('JSON inválido: falta "$k"');
    return this[k];
  }

  String str(String k) {
    final v = _req(k);
    return v is String ? v : _bad('texto en "$k"', v);
  }

  String? strOrNull(String k) {
    final v = this[k];
    return v == null ? null : (v is String ? v : _bad('texto en "$k"', v));
  }

  int integer(String k) {
    final v = _req(k);
    return v is num && v.isFinite ? v.toInt() : _bad('entero en "$k"', v);
  }

  int? intOrNull(String k) {
    final v = this[k];
    if (v == null) return null;
    return v is num && v.isFinite ? v.toInt() : _bad('entero en "$k"', v);
  }

  double dbl(String k) {
    final v = _req(k);
    return v is num && v.isFinite ? v.toDouble() : _bad('número en "$k"', v);
  }

  double? dblOrNull(String k) {
    final v = this[k];
    if (v == null) return null;
    return v is num && v.isFinite ? v.toDouble() : _bad('número en "$k"', v);
  }

  bool boolean(String k) {
    final v = _req(k);
    return v is bool ? v : _bad('booleano en "$k"', v);
  }

  /// Booleano opcional (ausente = `false`).
  bool flag(String k) {
    final v = this[k];
    return v == null ? false : (v is bool ? v : _bad('booleano en "$k"', v));
  }

  Json obj(String k) => asJson(_req(k));

  Json? objOrNull(String k) {
    final v = this[k];
    return v == null ? null : asJson(v);
  }

  List<Object?> list(String k) => asList(_req(k));

  List<String> strings(String k) => [
        for (final e in list(k)) e is String ? e : _bad('texto en "$k"', e),
      ];

  E enumByName<E extends Enum>(String k, List<E> values) {
    final name = str(k);
    for (final v in values) {
      if (v.name == name) return v;
    }
    _bad('uno de ${values.map((e) => e.name).join('/')} en "$k"', name);
  }

  E? enumOrNull<E extends Enum>(String k, List<E> values) =>
      this[k] == null ? null : enumByName(k, values);
}

/// Mapa `nombre de enum → entero` (estados, bonus de estados).
Map<E, int> enumIntMap<E extends Enum>(Object? raw, List<E> values) {
  final m = asJson(raw);
  final out = <E, int>{};
  for (final e in m.entries) {
    final kind = values.where((v) => v.name == e.key).firstOrNull ??
        _bad('uno de ${values.map((v) => v.name).join('/')}', e.key);
    final v = e.value;
    out[kind] = v is num && v.isFinite ? v.toInt() : _bad('entero', v);
  }
  return out;
}

Map<String, Object?> enumIntMapToJson<E extends Enum>(Map<E, int> m) =>
    {for (final e in m.entries) e.key.name: e.value};
