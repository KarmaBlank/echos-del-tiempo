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
    // Los sprites de las ascensiones y sus auras son opcionales: si el
    // archivo falla, se dibuja la clase base (docs/specs/ascension.md § 5).
    Future<void> hero(String c) async {
      try {
        heroes[c] = await catalog.character(c, 'idle');
      } catch (_) {
        if (!c.contains('_')) rethrow;
      }
    }

    await Future.wait([
      for (final c in catalog.characterIds) hero(c),
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

  /// El héroe de [classId] con su ascensión: `<clase>_<ascensión>` si el
  /// manifest lo tiene, si no la clase base (docs/specs/ascension.md § 5).
  ui.Image? heroFor(String? classId, String? ascensionId) {
    if (classId == null) return null;
    if (ascensionId != null) {
      final img = _heroes['${classId}_$ascensionId']?.image;
      if (img != null) return img;
    }
    return _heroes[classId]?.image;
  }

  /// El aura de una ascensión (`aura_<ascensión>`, 24 × 26), o `null`
  /// (quien dibuja usa entonces el aura pintada).
  ui.Image? aura(String? ascensionId) =>
      ascensionId == null ? null : _heroes['aura_$ascensionId']?.image;

  /// Frame `idle` de un tipo de enemigo, o `null`.
  ui.Image? enemy(String enemyType) => _enemies[enemyType]?.image;

  /// `sc` del prototipo (sin el ×1.45 de élite).
  double enemyScale(String enemyType) => _scales[enemyType] ?? 1;

  bool enemyFloats(String enemyType) => _floats.contains(enemyType);
}

/// Sprite de un enemigo según su fase (docs/specs/bosses.md § "v0.3"): el
/// Devorador transformado usa `<tipo>Fase2` si el manifest lo tiene.
extension EnemySpriteId on GameSprites? {
  String enemySpriteId(String enemyType, int phase) {
    final s = this;
    if (phase >= 2 && s != null && s.enemy('${enemyType}Fase2') != null) {
      return '${enemyType}Fase2';
    }
    return enemyType;
  }
}
