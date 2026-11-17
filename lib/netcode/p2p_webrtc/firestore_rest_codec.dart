/// Codificación de valores de la API REST v1 de Firestore ("typed values":
/// `{"stringValue": "x"}`, `{"integerValue": "3"}`, `{"mapValue": ...}`).
/// Dart puro, sin dependencias. Ver docs/specs/netcode.md § "Señalización
/// REST en escritorio".
abstract final class FirestoreRestCodec {
  /// Un valor Dart → valor tipado de Firestore.
  static Map<String, Object?> encodeValue(Object? v) => switch (v) {
        null => {'nullValue': null},
        bool b => {'booleanValue': b},
        int i => {'integerValue': '$i'},
        double d => {'doubleValue': d},
        String s => {'stringValue': s},
        DateTime t => {'timestampValue': t.toUtc().toIso8601String()},
        Map<Object?, Object?> m => {
            'mapValue': {'fields': encodeFields(m)},
          },
        Iterable<Object?> l => {
            'arrayValue': {
              'values': [for (final e in l) encodeValue(e)]
            },
          },
        _ =>
          throw ArgumentError.value(v, 'v', 'tipo no soportado por Firestore'),
      };

  /// `{campo: valor}` → `{campo: valorTipado}` (el `fields` de un documento).
  static Map<String, Object?> encodeFields(Map<Object?, Object?> m) => {
        for (final e in m.entries) '${e.key}': encodeValue(e.value),
      };

  /// Valor tipado de Firestore → valor Dart. Lo desconocido (referencias,
  /// geopuntos, bytes) se devuelve tal cual llegó.
  static Object? decodeValue(Object? v) {
    if (v is! Map) return null;
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('booleanValue')) return v['booleanValue'] == true;
    if (v.containsKey('integerValue')) {
      final i = v['integerValue'];
      return i is num ? i.toInt() : int.tryParse('$i');
    }
    if (v.containsKey('doubleValue')) {
      final d = v['doubleValue'];
      // `NaN`/`Infinity` llegan como texto.
      return d is num ? d.toDouble() : double.tryParse('$d');
    }
    if (v.containsKey('stringValue')) return v['stringValue'] as String?;
    if (v.containsKey('timestampValue')) {
      return DateTime.tryParse('${v['timestampValue']}');
    }
    if (v.containsKey('mapValue')) {
      final m = v['mapValue'];
      return decodeFields(m is Map ? m['fields'] : null);
    }
    if (v.containsKey('arrayValue')) {
      final a = v['arrayValue'];
      final values = a is Map ? a['values'] : null;
      return [
        if (values is List)
          for (final e in values) decodeValue(e)
      ];
    }
    return Map<String, dynamic>.from(v);
  }

  /// El `fields` de un documento → `{campo: valor}`.
  static Map<String, dynamic> decodeFields(Object? fields) => {
        if (fields is Map)
          for (final e in fields.entries) '${e.key}': decodeValue(e.value),
      };
}
