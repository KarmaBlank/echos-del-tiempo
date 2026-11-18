import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'window_mode.dart';

/// Destellos de pantalla completa en batalla (accesibilidad): el rojo de
/// "te pegaron fuerte", el blanco de los golpes brutales y del quiebre y
/// el tinte de "tiempo detenido". Ver docs/specs/settings.md § "PANTALLA".
enum FlashLevel {
  normal(1),
  reduced(0.35),
  off(0);

  const FlashLevel(this.factor);

  /// Multiplica el alfa de cada destello.
  final double factor;
}

/// Ajustes de pantalla y de juego (todo lo que no es audio). Se guardan
/// en `game.json` junto al perfil. Ver docs/specs/settings.md.
class GameSettings {
  const GameSettings({
    this.fullscreen = false,
    this.screenShake = true,
    this.flashes = FlashLevel.normal,
    this.battleSpeed = 1,
    this.damageNumbers = true,
    this.confirmDrop = true,
  });

  /// Velocidades de animación de batalla que se ofrecen.
  static const battleSpeeds = [1.0, 1.5, 2.0];

  /// Pantalla completa sin bordes (solo Windows; ver `WindowMode`).
  final bool fullscreen;

  /// Sacudida de la escena de batalla en golpes fuertes.
  final bool screenShake;
  final FlashLevel flashes;

  /// Multiplicador del reloj de animación de la escena de batalla (y de
  /// los retrasos de sus sonidos). No cambia los turnos: los marca el host.
  final double battleSpeed;

  /// Números de daño / cura flotantes en la escena de batalla.
  final bool damageNumbers;

  /// Pedir confirmación antes de tirar un objeto al piso.
  final bool confirmDrop;

  GameSettings copyWith({
    bool? fullscreen,
    bool? screenShake,
    FlashLevel? flashes,
    double? battleSpeed,
    bool? damageNumbers,
    bool? confirmDrop,
  }) =>
      GameSettings(
        fullscreen: fullscreen ?? this.fullscreen,
        screenShake: screenShake ?? this.screenShake,
        flashes: flashes ?? this.flashes,
        battleSpeed: _speed(battleSpeed ?? this.battleSpeed),
        damageNumbers: damageNumbers ?? this.damageNumbers,
        confirmDrop: confirmDrop ?? this.confirmDrop,
      );

  /// La velocidad ofrecida más cercana a [v].
  static double _speed(double v) {
    var best = battleSpeeds.first;
    for (final s in battleSpeeds) {
      if ((s - v).abs() < (best - v).abs()) best = s;
    }
    return best;
  }

  Map<String, Object?> toJson() => {
        'fullscreen': fullscreen,
        'shake': screenShake,
        'flashes': flashes.name,
        'battleSpeed': battleSpeed,
        'damageNumbers': damageNumbers,
        'confirmDrop': confirmDrop,
      };

  /// Valores inválidos o ausentes caen al de por defecto.
  factory GameSettings.fromJson(Map<String, Object?> json) {
    const d = GameSettings();
    bool flag(Object? v, bool def) => v is bool ? v : def;
    final speed = json['battleSpeed'];
    return GameSettings(
      fullscreen: flag(json['fullscreen'], d.fullscreen),
      screenShake: flag(json['shake'], d.screenShake),
      flashes: FlashLevel.values.firstWhere((f) => f.name == json['flashes'],
          orElse: () => d.flashes),
      battleSpeed:
          speed is num && speed.isFinite ? _speed(speed.toDouble()) : 1,
      damageNumbers: flag(json['damageNumbers'], d.damageNumbers),
      confirmDrop: flag(json['confirmDrop'], d.confirmDrop),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameSettings &&
      other.fullscreen == fullscreen &&
      other.screenShake == screenShake &&
      other.flashes == flashes &&
      other.battleSpeed == battleSpeed &&
      other.damageNumbers == damageNumbers &&
      other.confirmDrop == confirmDrop;

  @override
  int get hashCode => Object.hash(fullscreen, screenShake, flashes,
      battleSpeed, damageNumbers, confirmDrop);

  @override
  String toString() => 'GameSettings(${toJson()})';
}

/// Dónde se guardan los ajustes de juego.
abstract interface class GameSettingsStore {
  Future<GameSettings?> load();
  Future<void> save(GameSettings settings);
}

/// En memoria (tests, plataformas sin carpeta de datos conocida).
class InMemoryGameSettingsStore implements GameSettingsStore {
  InMemoryGameSettingsStore([this.saved]);

  GameSettings? saved;

  @override
  Future<GameSettings?> load() async => saved;

  @override
  Future<void> save(GameSettings settings) async => saved = settings;
}

/// `game.json` junto al perfil (escritura atómica), al lado de
/// `audio.json` (que sigue siendo el de los volúmenes).
class JsonFileGameSettingsStore implements GameSettingsStore {
  JsonFileGameSettingsStore(this.file);

  JsonFileGameSettingsStore.inDirectory(String dir)
      : file = File('$dir${Platform.pathSeparator}$fileName');

  static const fileName = 'game.json';

  final File file;

  @override
  Future<GameSettings?> load() async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, Object?> ? GameSettings.fromJson(json) : null;
    } catch (_) {
      return null; // corrupto: por defecto
    }
  }

  @override
  Future<void> save(GameSettings settings) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}

/// Los ajustes de juego vivos: cada cambio se aplica (la ventana; el
/// resto lo leen la batalla y el inventario del provider) y se guarda.
class GameSettingsController extends StateNotifier<GameSettings> {
  GameSettingsController({
    required this.store,
    this.window = const WindowMode.unsupported(),
    GameSettings initial = const GameSettings(),
  }) : super(initial);

  final GameSettingsStore store;
  final WindowMode window;

  /// Carga lo guardado (si hay) y lo aplica (p. ej. arranca en pantalla
  /// completa si así quedó).
  Future<void> load() async {
    GameSettings? s;
    try {
      s = await store.load();
    } catch (_) {
      s = null;
    }
    if (s == null || !mounted) return;
    state = s;
    if (s.fullscreen) await window.setFullscreen(true);
  }

  /// Cambia, aplica y guarda.
  Future<void> update(GameSettings s) async {
    if (s == state) return;
    final old = state;
    state = s;
    if (s.fullscreen != old.fullscreen) {
      await window.setFullscreen(s.fullscreen);
    }
    try {
      await store.save(s);
    } catch (_) {
      // Sin disco: se usa igual en esta ejecución.
    }
  }
}
