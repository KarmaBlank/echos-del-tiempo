import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:yaml/yaml.dart';

/// Lee `assets/sprites/sprite_manifest.yaml` y resuelve id lógico ->
/// `Sprite` de Flame. Es la ÚNICA clase que sabe que los sprites viven
/// como archivos; todo lo demás pide sprites por id ("guerrero.idle") y
/// no le importa si mañana cambian a Aseprite, a un atlas distinto, o lo
/// que sea.
///
/// Cambiar un sprite = reemplazar el PNG (y el manifest si cambia el
/// path). Nunca hace falta recompilar lógica de juego.
///
/// Todo es pixel art: los `Sprite` salen con `FilterQuality.none`
/// (vecino más cercano). Formato y animaciones: docs/specs/sprites.md.
class SpriteCatalog {
  SpriteCatalog._(this._manifest, this._bundle);

  /// Ruta del manifest dentro del bundle.
  static const manifestPath = 'assets/sprites/sprite_manifest.yaml';

  /// Prefijo de todas las rutas del manifest.
  static const spritesRoot = 'assets/sprites/';

  final YamlMap _manifest;
  final AssetBundle _bundle;

  /// Cache de imágenes decodificadas (guarda el `Future` para que dos
  /// pedidos simultáneos del mismo archivo lo carguen una sola vez).
  final _cache = <String, Future<ui.Image>>{};

  /// Carga el manifest. [bundle] permite inyectar otro `AssetBundle`
  /// (tests); por defecto usa `rootBundle`.
  static Future<SpriteCatalog> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final raw = await b.loadString(manifestPath);
    return SpriteCatalog._(loadYaml(raw) as YamlMap, b);
  }

  /// Ids de clase con sprites (`characters:` del manifest).
  Iterable<String> get characterIds => _section('characters').keys.cast<String>();

  /// Ids de enemigo con sprites (`enemies:` del manifest).
  Iterable<String> get enemyIds => _section('enemies').keys.cast<String>();

  /// Animaciones disponibles de una clase (hoy solo `idle`).
  Iterable<String> characterAnimations(String classId) =>
      (_section('characters')[classId] as YamlMap?)?.keys.cast<String>() ?? const [];

  Future<Sprite> character(String classId, String animation) async {
    final path = characterPath(classId, animation);
    if (path == null) {
      throw StateError('No hay sprite para $classId.$animation en sprite_manifest.yaml');
    }
    return _pixelSprite(await _loadImage('$spritesRoot$path'));
  }

  Future<Sprite> enemy(String enemyId) async {
    final path = enemyPath(enemyId);
    if (path == null) {
      throw StateError('No hay sprite para el enemigo $enemyId en sprite_manifest.yaml');
    }
    return _pixelSprite(await _loadImage('$spritesRoot$path'));
  }

  /// Escala de dibujo del enemigo (`sc` del prototipo; 1 si no figura).
  /// El multiplicador de élite (×1.45) lo aplica quien dibuja.
  double enemyScale(String enemyId) {
    final entry = _section('enemies')[enemyId];
    final scale = entry is YamlMap ? entry['scale'] : null;
    return scale is num ? scale.toDouble() : 1.0;
  }

  /// Ruta (relativa a [spritesRoot]) del sprite de una clase, o `null`.
  String? characterPath(String classId, String animation) {
    final entry = _section('characters')[classId];
    return entry is YamlMap ? entry[animation] as String? : null;
  }

  /// Ruta (relativa a [spritesRoot]) del frame `idle` de un enemigo, o
  /// `null`.
  String? enemyPath(String enemyId) {
    final entry = _section('enemies')[enemyId];
    return entry is YamlMap ? entry['idle'] as String? : null;
  }

  /// Precarga todas las imágenes del manifest (útil antes de entrar a
  /// batalla para no decodificar en el primer frame).
  Future<void> preloadAll() async {
    final paths = [
      for (final c in characterIds)
        for (final a in characterAnimations(c)) characterPath(c, a),
      for (final e in enemyIds) enemyPath(e),
    ].whereType<String>();
    await Future.wait(paths.map((p) => _loadImage('$spritesRoot$p')));
  }

  /// `Paint` para dibujar pixel art a mano (`canvas.drawImageRect`):
  /// vecino más cercano, sin suavizado.
  static ui.Paint pixelPaint() => ui.Paint()..filterQuality = ui.FilterQuality.none;

  Sprite _pixelSprite(ui.Image image) =>
      Sprite(image)..paint.filterQuality = ui.FilterQuality.none;

  YamlMap _section(String name) => _manifest[name] as YamlMap? ?? YamlMap();

  Future<ui.Image> _loadImage(String assetPath) {
    return _cache.putIfAbsent(assetPath, () async {
      try {
        final data = await _bundle.load(assetPath);
        final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      } catch (_) {
        _cache.remove(assetPath); // no cachear fallos: permite reintentar
        rethrow;
      }
    });
  }
}
