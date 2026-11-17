import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Todas las rutas (relativas a assets/sprites/) que nombra el manifest.
List<String> manifestPaths(YamlMap manifest) {
  final paths = <String>[];
  void walk(Object? node) {
    if (node is YamlMap) {
      node.values.forEach(walk);
    } else if (node is String && node.endsWith('.png')) {
      paths.add(node);
    }
  }

  walk(manifest);
  return paths;
}

void main() {
  final manifest =
      loadYaml(File('assets/sprites/sprite_manifest.yaml').readAsStringSync()) as YamlMap;
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final assetDirs =
      ((pubspec['flutter'] as YamlMap)['assets'] as YamlList).cast<String>().toSet();

  test('toda entrada del manifest apunta a un archivo existente', () {
    final paths = manifestPaths(manifest);
    expect(paths, isNotEmpty);
    for (final p in paths) {
      expect(File('assets/sprites/$p').existsSync(), isTrue, reason: p);
    }
  });

  test('cada carpeta de sprite está listada en pubspec.yaml (no recursivo)', () {
    for (final p in manifestPaths(manifest)) {
      final dir = 'assets/sprites/${p.substring(0, p.lastIndexOf('/') + 1)}';
      expect(assetDirs, contains(dir), reason: p);
    }
  });

  test('hay sprite idle para cada clase y cada enemigo del juego', () {
    final chars = manifest['characters'] as YamlMap;
    final enemies = manifest['enemies'] as YamlMap;
    for (final c in kClasses.keys) {
      expect((chars[c] as YamlMap?)?['idle'], isNotNull, reason: c);
    }
    for (final e in kEnemies.keys) {
      expect((enemies[e] as YamlMap?)?['idle'], isNotNull, reason: e);
    }
  });

  testWidgets('SpriteCatalog carga y cachea imágenes desde el bundle', (tester) async {
    await tester.runAsync(() async {
      final catalog = await SpriteCatalog.load();
      expect(catalog.characterIds, containsAll(['guerrero', 'maga', 'paladin', 'tirador']));
      expect(catalog.characterAnimations('guerrero'), ['idle']);

      final hero = await catalog.character('guerrero', 'idle');
      expect(hero.image.width, 14);
      expect(hero.image.height, 18);
      expect(hero.paint.filterQuality, ui.FilterQuality.none);

      final boss = await catalog.enemy('devorador');
      expect(boss.image.width, 16);
      expect(catalog.enemyScale('devorador'), 2.4);
      expect(catalog.enemyScale('reyLimo'), 2.0);
      expect(catalog.enemyScale('slime'), 1.0);
      expect(catalog.enemyFloats('bat'), isTrue);
      expect(catalog.enemyFloats('devorador'), isTrue);
      expect(catalog.enemyFloats('slime'), isFalse);

      // Mismo archivo → misma imagen (cache).
      final again = await catalog.enemy('devorador');
      expect(identical(again.image, boss.image), isTrue);

      await catalog.preloadAll();
      await expectLater(catalog.enemy('noExiste'), throwsStateError);
    });
  });
}
