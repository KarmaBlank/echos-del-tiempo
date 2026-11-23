import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/export_npc_sprites.dart';

/// Habitantes con cuerpo de personaje jugable (sprites.md § Habitantes).
void main() {
  test('cada habitante tiene sprite y retrato propios en el manifest', () {
    final manifest =
        File('assets/sprites/sprite_manifest.yaml').readAsStringSync();
    for (final n in kBiomeNpcs) {
      expect(npcLooks.containsKey(n.id), isTrue, reason: n.id);
      for (final id in ['vida_${n.sprite}', 'vida_${n.portrait}']) {
        expect(manifest, contains('$id: { idle: items/$id.png'), reason: id);
        expect(File('assets/sprites/items/$id.png').existsSync(), isTrue);
      }
      final img = npcSprite(n.id);
      expect((img.width, img.height), (14, 18));
    }
  });
}
