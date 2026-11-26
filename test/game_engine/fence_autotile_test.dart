// Fence autotile (docs/specs/town_editor.md § 5.1).
import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/cozy_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/autotile.dart';
import 'package:echos_del_tiempo/game_engine/rules/cozy_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _n = Autotile.n, _e = Autotile.e, _s = Autotile.s, _w = Autotile.w;

/// Sprite of the piece at ([x], [y]) of [t].
String _at(TownState t, int x, int y) {
  final d = t.decor.firstWhere((d) => d.$2 == x && d.$3 == y);
  return CozyRules.decorSprite(d.$1, x, y, CozyRules.fenceCells(t));
}

void main() {
  test('all 16 neighbour masks map to their piece and shape', () {
    const shapes = {
      0: AutotileShape.post,
      _n: AutotileShape.end,
      _e: AutotileShape.end,
      _s: AutotileShape.end,
      _w: AutotileShape.end,
      _n | _s: AutotileShape.straight,
      _e | _w: AutotileShape.straight,
      _n | _e: AutotileShape.corner,
      _e | _s: AutotileShape.corner,
      _s | _w: AutotileShape.corner,
      _w | _n: AutotileShape.corner,
      _n | _e | _s: AutotileShape.tee,
      _e | _s | _w: AutotileShape.tee,
      _s | _w | _n: AutotileShape.tee,
      _w | _n | _e: AutotileShape.tee,
      _n | _e | _s | _w: AutotileShape.cross,
    };
    expect(shapes.length, 16);
    for (final MapEntry(key: m, value: shape) in shapes.entries) {
      expect(Autotile.shape(m), shape, reason: 'mask $m');
      // A fence at (5,5) with fences on exactly the bits of m.
      final cells = <(int, int)>{
        (5, 5),
        if (m & _n != 0) (5, 4),
        if (m & _e != 0) (6, 5),
        if (m & _s != 0) (5, 6),
        if (m & _w != 0) (4, 5),
      };
      expect(CozyRules.fenceMask(cells, 5, 5), m);
      expect(CozyRules.decorSprite('fence', 5, 5, cells), 'decor_fence_$m');
    }
  });

  test('diagonals and other decorations do not connect', () {
    const t = TownState(decor: [
      ('fence', 5, 5),
      ('fence', 6, 6),
      ('pot', 6, 5),
      ('lamp', 5, 4),
    ]);
    expect(_at(t, 5, 5), 'decor_fence_0');
    expect(_at(t, 6, 5), 'decor_pot');
  });

  test('gate picks its run from its neighbours', () {
    const h = TownState(decor: [
      ('fence', 4, 5),
      ('fence_gate', 5, 5),
      ('fence', 6, 5),
    ]);
    expect(_at(h, 5, 5), 'decor_fence_gate_h');
    expect(_at(h, 4, 5), 'decor_fence_${Autotile.e}');
    const v = TownState(decor: [
      ('fence', 5, 4),
      ('fence_gate', 5, 5),
      ('fence', 5, 6),
    ]);
    expect(_at(v, 5, 5), 'decor_fence_gate_v');
    expect(_at(v, 5, 4), 'decor_fence_${Autotile.s}');
    expect(kFarmDecos.containsKey('fence_gate'), isTrue);
  });

  test('placing and removing a piece updates its neighbours', () {
    var t = const TownState(decor: [('fence', 4, 5), ('fence', 6, 5)]);
    expect(_at(t, 4, 5), 'decor_fence_0');
    t = t.copyWith(decor: [...t.decor, ('fence', 5, 5)]);
    expect(_at(t, 4, 5), 'decor_fence_$_e');
    expect(_at(t, 5, 5), 'decor_fence_${_e | _w}');
    expect(_at(t, 6, 5), 'decor_fence_$_w');
    t = CozyRules.removeDecor(t, TownState.decorId(5, 5))!;
    expect(_at(t, 4, 5), 'decor_fence_0');
    expect(_at(t, 6, 5), 'decor_fence_0');
  });

  test('save / load keeps the enclosure connected the same way', () {
    final t = TownState(decor: [
      for (var x = 0; x <= 4; x++) ('fence', x, 0),
      for (var x = 0; x <= 4; x++) (x == 2 ? 'fence_gate' : 'fence', x, 3),
      for (var y = 1; y <= 2; y++) ('fence', 0, y),
      for (var y = 1; y <= 2; y++) ('fence', 4, y),
      ('fence', 2, 1),
    ]);
    final back = TownState.fromJson(t.toJson());
    expect(back.decor, t.decor);
    for (final (_, x, y) in t.decor) {
      expect(_at(back, x, y), _at(t, x, y));
    }
    expect(_at(t, 0, 0), 'decor_fence_${_e | _s}');
    expect(_at(t, 2, 0), 'decor_fence_${_e | _s | _w}');
    expect(_at(t, 2, 3), 'decor_fence_gate_h');
  });

  test('every fence piece and the workshop are in the manifest', () {
    final yaml = File('assets/sprites/sprite_manifest.yaml').readAsStringSync();
    for (final id in [
      for (var m = 0; m < 16; m++) 'vida_decor_fence_$m',
      'vida_decor_fence_gate',
      'vida_decor_fence_gate_h',
      'vida_decor_fence_gate_v',
    ]) {
      final line =
          RegExp('  $id: \\{ idle: items/([a-z0-9_]+\\.png)').firstMatch(yaml);
      expect(line, isNotNull, reason: id);
      expect(
          File('assets/sprites/items/${line!.group(1)}').existsSync(), isTrue);
    }
  });
}
