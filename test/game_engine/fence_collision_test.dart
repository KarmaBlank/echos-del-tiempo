// Placed fences block movement; gates and gaps do not
// (town_editor.md § 5.1).
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

void main() {
  // A free grass row of the base town, far from the landmarks.
  (int, int) freeCell(TownState t) {
    final m = MapGenerator.townOf(t);
    final (ox, oy) = m.townOrigin;
    for (var y = 2; y < m.height - 2; y++) {
      for (var x = 2; x < m.width - 6; x++) {
        var ok = true;
        for (var dx = -1; dx <= 4 && ok; dx++) {
          for (var dy = -1; dy <= 1 && ok; dy++) {
            ok = !WorldRules.isSolid(m, x + dx, y + dy);
          }
        }
        if (ok) return (x - ox, y - oy);
      }
    }
    throw StateError('no free cell');
  }

  test('a fence blocks, a gate and a gap let you through', () {
    const base = TownState();
    final (x, y) = freeCell(base);
    final t = base.copyWith(decor: [
      ('fence', x, y),
      ('fence_gate', x + 1, y),
      ('fence', x + 3, y), // x + 2 is a gap
    ]);
    final m = MapGenerator.townOf(t);
    final (ox, oy) = m.townOrigin;
    double cx(int tx) => (tx + ox) * 16 + 8.0;
    final cy = (y + oy) * 16 + 8.0;
    expect(WorldRules.isSolid(m, x + ox, y + oy), isTrue);
    expect(WorldRules.isSolid(m, x + 1 + ox, y + oy), isFalse);
    expect(WorldRules.isSolid(m, x + 2 + ox, y + oy), isFalse);
    expect(WorldRules.isSolid(m, x + 3 + ox, y + oy), isTrue);
    expect(WorldRules.hitsFence(m, cx(x), cy), isTrue);
    expect(WorldRules.hitsFence(m, cx(x + 1), cy), isFalse);

    // Client prediction: walking down from above stops at the fence...
    var p = (cx(x), cy - 16);
    for (var i = 0; i < 60; i++) {
      final n = WorldRules.stepPlayer(m, p.$1, p.$2, 0, 1, 1 / 60);
      p = (n.x, n.y);
    }
    expect(p.$2, lessThan(cy - 8));
    // ...and through the gate.
    p = (cx(x + 1), cy - 16);
    for (var i = 0; i < 60; i++) {
      final n = WorldRules.stepPlayer(m, p.$1, p.$2, 0, 1, 1 / 60);
      p = (n.x, n.y);
    }
    expect(p.$2, greaterThan(cy + 8));
  });

  test('without fences the map is unchanged', () {
    const t = TownState();
    expect(MapGenerator.townOf(t).blocked, isEmpty);
  });

  test('the host refuses a step into a fence', () {
    final e = sessionEngine();
    var s =
        e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!.state;
    final (x, y) = freeCell(s.town);
    s.town = s.town.copyWith(decor: [('fence', x, y)]);
    final m = e.mapFor(s);
    final (ox, oy) = m.townOrigin;
    final cx = (x + ox) * 16 + 8.0, cy = (y + oy) * 16 + 8.0;
    s = moveTo(e, s, 'p0', cx, cy - 20);
    final ep = s.players['p0']!.epoch;
    expect(e.apply(s, 'p0', MoveAction(cx, cy, epoch: ep, moving: true)),
        isNull);
    final ok =
        e.apply(s, 'p0', MoveAction(cx, cy - 22, epoch: ep, moving: true));
    expect(ok, isNotNull);
  });
}
