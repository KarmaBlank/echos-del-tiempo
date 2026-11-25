import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/procedural/item_icons.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/game_engine/data/profession_gear_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/rules/profession_gear_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import 'dart:io';

void main() {
  test('profession weapons resolve to their own manifest sprite', () {
    final manifest =
        loadYaml(File('assets/sprites/sprite_manifest.yaml').readAsStringSync())
            as YamlMap;
    final items = manifest['items'] as YamlMap;
    for (final g in kProfessionGear.values) {
      final it = ItemInstance.common(GearRules.uidFor(g.id), 'x');
      expect(gearSpriteOf(it), g.sprite);
      expect(items.containsKey('vida_${g.sprite}'), isTrue, reason: g.id);
    }
    expect(gearSpriteOf(ItemInstance.common('plain-1', 'x')), isNull);
  });

  test('a loaded gear sprite replaces the procedural icon', () async {
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(const ui.Rect.fromLTWH(0, 0, 16, 16),
        ui.Paint()..color = const ui.Color(0xFF00FF00));
    final img = await rec.endRecording().toImage(16, 16);
    ItemIconImages.putGear('gear_vivo_baston', img);
    final p = ItemIconPainter(kItemIconRows['espada']!,
        const ui.Color(0xFFFFFFFF), 'items')
      ..gearSprite = 'gear_vivo_baston';
    final r2 = ui.PictureRecorder();
    p.paint(ui.Canvas(r2), const ui.Size(32, 32));
    final out = await r2.endRecording().toImage(32, 32);
    final bytes = (await out.toByteData())!;
    // Center pixel is the sprite's green.
    final o = (16 * 32 + 16) * 4;
    expect([bytes.getUint8(o), bytes.getUint8(o + 1), bytes.getUint8(o + 2)],
        [0, 255, 0]);
    ItemIconImages.clear();
  });
}
