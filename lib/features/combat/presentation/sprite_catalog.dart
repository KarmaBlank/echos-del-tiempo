import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

/// Lee `assets/sprites/sprite_manifest.yaml` y resuelve id lógico ->
/// `Sprite`/`SpriteAnimation` de Flame. Es la ÚNICA clase que sabe que
/// los sprites viven como archivos; todo lo demás pide sprites por id
/// ("guerrero.idle") y no le importa si mañana cambian a Aseprite,
/// a un atlas distinto, o lo que sea.
///
/// Cambiar un sprite = reemplazar el PNG (y el manifest si cambia el
/// path). Nunca hace falta recompilar lógica de juego.
class SpriteCatalog {
  SpriteCatalog._(this._manifest);

  final YamlMap _manifest;
  final _cache = <String, ui.Image>{};

  static Future<SpriteCatalog> load() async {
    final raw = await rootBundle.loadString('assets/sprites/sprite_manifest.yaml');
    return SpriteCatalog._(loadYaml(raw) as YamlMap);
  }

  Future<Sprite> character(String classId, String animation) async {
    final path = _manifest['characters']?[classId]?[animation] as String?;
    if (path == null) {
      throw StateError('No hay sprite para $classId.$animation en sprite_manifest.yaml');
    }
    return Sprite(await _loadImage('assets/sprites/$path'));
  }

  Future<Sprite> enemy(String enemyId) async {
    final path = _manifest['enemies']?[enemyId] as String?;
    if (path == null) {
      throw StateError('No hay sprite para el enemigo $enemyId en sprite_manifest.yaml');
    }
    return Sprite(await _loadImage('assets/sprites/$path'));
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    return _cache.putIfAbsent(
      assetPath,
      () => throw UnimplementedError('TODO: cargar $assetPath con Flame.images.load'),
    );
  }
}
