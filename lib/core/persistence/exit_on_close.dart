import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';

import 'exit_guard.dart';

AppLifecycleListener? _listener;

/// Al cerrar la ventana (Windows le pregunta al framework con
/// `System.requestAppExit`) guarda todo lo pendiente ([ExitGuard]) antes
/// de salir. Llamar después de inicializar el binding; idempotente. Ver
/// docs/specs/characters.md § 1.4.
void installExitOnClose() {
  _listener ??= AppLifecycleListener(onExitRequested: () async {
    await ExitGuard.flushAll();
    return AppExitResponse.exit;
  });
}
