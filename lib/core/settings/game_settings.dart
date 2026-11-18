import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'frame_limiter.dart';
import 'graphics.dart';
import 'window_mode.dart';

export 'graphics.dart';

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
    this.damageNumbers = true,
    this.confirmDrop = true,
    this.scale = ScaleMode.fit,
    this.crt = CrtLevel.normal,
    this.particles = ParticleLevel.high,
    this.fpsLimit = FpsLimit.fps60,
  });

  /// Pantalla completa sin bordes (solo Windows; ver `WindowMode`).
  final bool fullscreen;

  /// Sacudida de la escena de batalla en golpes fuertes.
  final bool screenShake;
  final FlashLevel flashes;

  /// Números de daño / cura flotantes en la escena de batalla.
  final bool damageNumbers;

  /// Pedir confirmación antes de tirar un objeto al piso.
  final bool confirmDrop;

  /// Escalado del mundo pixelado (mapa y batalla).
  final ScaleMode scale;

  /// Filtro retro CRT sobre toda la pantalla.
  final CrtLevel crt;

  /// Cantidad de partículas.
  final ParticleLevel particles;

  /// Tope de cuadros por segundo.
  final FpsLimit fpsLimit;

  GameSettings copyWith({
    bool? fullscreen,
    bool? screenShake,
    FlashLevel? flashes,
    bool? damageNumbers,
    bool? confirmDrop,
    ScaleMode? scale,
    CrtLevel? crt,
    ParticleLevel? particles,
    FpsLimit? fpsLimit,
  }) =>
      GameSettings(
        fullscreen: fullscreen ?? this.fullscreen,
        screenShake: screenShake ?? this.screenShake,
        flashes: flashes ?? this.flashes,
        damageNumbers: damageNumbers ?? this.damageNumbers,
        confirmDrop: confirmDrop ?? this.confirmDrop,
        scale: scale ?? this.scale,
        crt: crt ?? this.crt,
        particles: particles ?? this.particles,
        fpsLimit: fpsLimit ?? this.fpsLimit,
      );

  Map<String, Object?> toJson() => {
        'fullscreen': fullscreen,
        'shake': screenShake,
        'flashes': flashes.name,
        'damageNumbers': damageNumbers,
        'confirmDrop': confirmDrop,
        'scale': scale.name,
        'crt': crt.name,
        'particles': particles.name,
        'fpsLimit': fpsLimit.json,
      };

  /// Valores inválidos o ausentes caen al de por defecto. Claves viejas
  /// (`battleSpeed` de v0.2.1) se ignoran.
  factory GameSettings.fromJson(Map<String, Object?> json) {
    const d = GameSettings();
    bool flag(Object? v, bool def) => v is bool ? v : def;
    return GameSettings(
      fullscreen: flag(json['fullscreen'], d.fullscreen),
      screenShake: flag(json['shake'], d.screenShake),
      flashes: FlashLevel.values.firstWhere((f) => f.name == json['flashes'],
          orElse: () => d.flashes),
      damageNumbers: flag(json['damageNumbers'], d.damageNumbers),
      confirmDrop: flag(json['confirmDrop'], d.confirmDrop),
      scale: ScaleMode.fromName(json['scale'], d.scale),
      crt: CrtLevel.fromName(json['crt'], d.crt),
      particles: ParticleLevel.fromName(json['particles'], d.particles),
      fpsLimit: FpsLimit.fromJson(json['fpsLimit'], d.fpsLimit),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameSettings &&
      other.fullscreen == fullscreen &&
      other.screenShake == screenShake &&
      other.flashes == flashes &&
      other.damageNumbers == damageNumbers &&
      other.confirmDrop == confirmDrop &&
      other.scale == scale &&
      other.crt == crt &&
      other.particles == particles &&
      other.fpsLimit == fpsLimit;

  @override
  int get hashCode => Object.hash(fullscreen, screenShake, flashes,
      damageNumbers, confirmDrop, scale, crt, particles, fpsLimit);

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

/// Los ajustes de juego vivos: cada cambio se aplica (la ventana y el
/// límite de FPS; el resto lo leen el mapa, la batalla, el filtro CRT y
/// el inventario del provider) y se guarda.
class GameSettingsController extends StateNotifier<GameSettings> {
  GameSettingsController({
    required this.store,
    this.window = const WindowMode.unsupported(),
    this.frameLimiter,
    GameSettings initial = const GameSettings(),
  }) : super(initial) {
    frameLimiter?.fps = initial.fpsLimit.fps;
  }

  final GameSettingsStore store;
  final WindowMode window;

  /// El limitador de cuadros de la app (`null` en tests: no hay binding).
  final FrameLimiter? frameLimiter;

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
    frameLimiter?.fps = s.fpsLimit.fps;
    if (s.fullscreen) await window.setFullscreen(true);
  }

  /// Cambia, aplica y guarda.
  Future<void> update(GameSettings s) async {
    if (s == state) return;
    final old = state;
    state = s;
    frameLimiter?.fps = s.fpsLimit.fps;
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
