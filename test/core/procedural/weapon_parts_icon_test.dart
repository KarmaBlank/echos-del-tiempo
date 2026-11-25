import 'dart:io';

import 'package:echos_del_tiempo/core/procedural/item_icon_rows.dart';
import 'package:echos_del_tiempo/core/procedural/weapon_look.dart';
import 'package:echos_del_tiempo/core/procedural/weapon_parts.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/png_decode.dart';

/// profession_gear_v2.md § 6: same shape, colours by material; the
/// default materials reproduce today's icons pixel for pixel.
void main() {
  String key(String shape) => shape.replaceAll('á', 'a');
  List<int> png(String name) =>
      decodePng(File('assets/sprites/items/$name.png').readAsBytesSync()).$3;

  test('default ramps reproduce every icon exactly (25 shapes)', () {
    expect(kItemIconRows.length, 25);
    for (final shape in kItemIconRows.keys) {
      final k = key(shape);
      final base = png(k);
      final copy = [...base];
      recolor(copy, png('${k}_head'), png('${k}_grip'),
          rampOf(kDefaultMetal), rampOf(kDefaultHandle));
      expect(copy, base, reason: k);
      // The layers are exactly what the tool derives from the PNG.
      final (h, g) = splitLayers(base);
      expect(png('${k}_head'), h, reason: '$k head');
      expect(png('${k}_grip'), g, reason: '$k grip');
    }
  });

  test('a material recolours only its region', () {
    final base = png('espada');
    final head = png('espada_head');
    final copy = [...base];
    recolor(copy, head, null, rampOf(materialColor('ingot_ember')!), null);
    var changed = 0;
    for (var o = 0; o < base.length; o += 4) {
      final inHead = head[o + 3] != 0;
      final same = copy[o] == base[o] &&
          copy[o + 1] == base[o + 1] &&
          copy[o + 2] == base[o + 2];
      if (!inHead) expect(same, isTrue);
      if (!same) changed++;
    }
    expect(changed, greaterThan(0));
  });

  test('items without v2 parts keep the default look', () {
    const plain = ItemInstance(uid: 'u', baseId: 'b');
    final l = WeaponLook.of(plain);
    expect([l.headColor, l.gripColor], [null, null]);
    const v1 = ItemInstance(uid: 'gear-vivo_arco-1', baseId: 'b',
        parts: ['v1', 'fuego']);
    expect(WeaponLook.of(v1).headColor, isNull);
    const forged = ItemInstance(uid: 'gear-parts_espada-1', baseId: 'b',
        parts: ['ingot_ember', 'ingot_frost', 'fp_pez_paradoja_bone']);
    final f = WeaponLook.of(forged);
    expect(f.headColor, kIngotColor['ingot_frost']);
    expect(f.gripColor, isNotNull);
  });
}
