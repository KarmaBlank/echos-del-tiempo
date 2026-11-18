import 'dart:io';

/// Registro chico de errores de carga y guardado (`ecos.log` en la carpeta
/// de datos) para que un jugador pueda mandarlo si algo no se guardó.
/// Ver docs/specs/characters.md § 1.5.
///
/// Rota solo: si pasa de [maxBytes], el actual pasa a `ecos.log.1` (se
/// pisa el anterior) y se empieza uno nuevo. Nunca tira: si no se puede
/// escribir, se pierde la línea y nada más.
class EcosLog {
  EcosLog._();

  static const fileName = 'ecos.log';
  static const maxBytes = 256 * 1024;

  static File? _file;

  /// Las últimas líneas (también sin archivo: tests, plataformas sin
  /// carpeta de datos).
  static final recent = <String>[];
  static const _keep = 100;

  /// El archivo actual, o `null` si no se inicializó con una carpeta.
  static File? get file => _file;

  /// Empieza a escribir en `[directory]/ecos.log`.
  static void init(String directory) {
    _file = File('$directory${Platform.pathSeparator}$fileName');
  }

  /// Deja de escribir a disco (tests).
  static void reset() {
    _file = null;
    recent.clear();
  }

  static void info(String message) => _write('INFO', message);

  static void error(String message, [Object? error]) =>
      _write('ERROR', error == null ? message : '$message: $error');

  static void _write(String level, String message) {
    final line = '${DateTime.now().toIso8601String()} $level $message';
    recent.add(line);
    if (recent.length > _keep) recent.removeAt(0);
    final f = _file;
    if (f == null) return;
    try {
      f.parent.createSync(recursive: true);
      if (f.existsSync() && f.lengthSync() > maxBytes) {
        f.renameSync('${f.path}.1');
      }
      f.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } on Object {
      // El registro nunca rompe el juego.
    }
  }
}
