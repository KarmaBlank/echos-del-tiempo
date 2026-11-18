import 'dart:async';

import 'ecos_log.dart';

/// Lo que hay que guardar antes de que se cierre la aplicación (la sesión
/// en curso, la cuenta). Lo llaman el cierre de la ventana
/// (`installExitOnClose`), SALIR DEL JUEGO y el auto-actualizador. Dart
/// puro. Ver docs/specs/characters.md § 1.4.
class ExitGuard {
  ExitGuard._();

  static final _flushers = <Object, Future<void> Function()>{};

  /// Los que escriben a disco lo que dejaron los demás (la cuenta): van
  /// al final.
  static final _last = <Object, Future<void> Function()>{};

  /// Tope de espera al cerrar (un disco colgado no deja la ventana abierta).
  static const timeout = Duration(seconds: 4);

  /// Registra [flush] con la clave [owner] (reemplaza el anterior). Con
  /// [last] corre después de todos los demás.
  static void register(Object owner, Future<void> Function() flush,
          {bool last = false}) =>
      (last ? _last : _flushers)[owner] = flush;

  static void unregister(Object owner) {
    _flushers.remove(owner);
    _last.remove(owner);
  }

  /// Corre todos los guardados registrados (la sesión antes que la
  /// cuenta) con un tope de [timeout]. Nunca tira.
  static Future<void> flushAll({Duration timeout = timeout}) async {
    Future<void> run() async {
      for (final f in [..._flushers.values, ..._last.values]) {
        try {
          await f();
        } on Object catch (e) {
          EcosLog.error('Guardado al salir', e);
        }
      }
    }

    try {
      await run().timeout(timeout);
    } on TimeoutException {
      EcosLog.error('Guardado al salir: tiempo agotado');
    }
  }
}
