import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sprite_catalog.dart';

/// Los sprites del juego, cargados una vez por app (los tests lo pisan
/// con sprites ya decodificados dentro de `tester.runAsync`).
final gameSpritesProvider = FutureProvider<GameSprites>(
    (ref) async => GameSprites.load(await SpriteCatalog.load()));

/// Todos los sprites del manifest ya decodificados, para dibujar sin
/// `await` (el mapa Flame y los widgets de batalla los piden en cada
/// frame). Se arma una sola vez con [load] a partir de [SpriteCatalog],
/// que sigue siendo el único que sabe dónde están los archivos.
class GameSprites {
  GameSprites._(this._heroes, this._enemies, this._scales, this._floats);

  final Map<String, Sprite> _heroes;
  final Map<String, Sprite> _enemies;
  final Map<String, double> _scales;
  final Set<String> _floats;

  static Future<GameSprites> load(SpriteCatalog catalog) async {
    final heroes = <String, Sprite>{};
    final enemies = <String, Sprite>{};
    final scales = <String, double>{};
    final floats = <String>{};
    await Future.wait([
      for (final c in catalog.characterIds)
        catalog.character(c, 'idle').then((s) => heroes[c] = s),
      for (final e in catalog.enemyIds)
        catalog.enemy(e).then((s) => enemies[e] = s),
    ]);
    for (final e in catalog.enemyIds) {
      scales[e] = catalog.enemyScale(e);
      if (catalog.enemyFloats(e)) floats.add(e);
    }
    return GameSprites._(heroes, enemies, scales, floats);
  }

  /// Frame `idle` de una clase, o `null` si el manifest no la tiene.
  ui.Image? hero(String classId) => _heroes[classId]?.image;

  /// Frame `idle` de un tipo de enemigo, o `null`.
  ui.Image? enemy(String enemyType) => _enemies[enemyType]?.image;

  /// `sc` del prototipo (sin el ×1.45 de élite).
  double enemyScale(String enemyType) => _scales[enemyType] ?? 1;

  bool enemyFloats(String enemyType) => _floats.contains(enemyType);
}
