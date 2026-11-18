import 'dart:ui' show AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/service_locator.dart';
import 'game_settings.dart';
import 'window_mode.dart';

/// Ventana / pantalla completa (en tests: sin soporte, salvo override).
final windowModeProvider = Provider<WindowMode>((ref) =>
    sl.isRegistered<WindowMode>() ? sl<WindowMode>() : const WindowMode.unsupported());

/// Ajustes de pantalla y de juego vivos (docs/specs/settings.md). En el
/// juego, el controlador del service locator (ya cargado de `game.json`);
/// en tests, uno en memoria.
final gameSettingsProvider =
    StateNotifierProvider<GameSettingsController, GameSettings>((ref) {
  if (sl.isRegistered<GameSettingsController>()) {
    return sl<GameSettingsController>();
  }
  return GameSettingsController(
    store: InMemoryGameSettingsStore(),
    window: ref.watch(windowModeProvider),
  );
});

/// Cerrar la aplicación (SALIR DEL JUEGO). En escritorio le pide al
/// motor que cierre la ventana; los tests lo reemplazan.
final appExitProvider = Provider<Future<void> Function()>((ref) => () async {
      await ServicesBinding.instance.exitApplication(AppExitType.required);
    });
