import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/npc_camp_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/npc_camp_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// overworld_biomes.md § 9.2 and lighting.md § 3 (campfire).
void main() {
  test('every biome resident has a camp', () {
    for (final n in kBiomeNpcs) {
      expect(kNpcCamps[n.id], isNotNull, reason: n.id);
    }
  });

  test('wander stays within the radius of the home tile', () {
    for (final n in kBiomeNpcs) {
      final (tx, ty) = n.tile;
      final cx = (tx + 0.5) * 16, cy = (ty + 0.5) * 16;
      for (var t = 0.0; t < 600; t += 0.37) {
        final s = NpcCampRules.state(n, t);
        final d = math.sqrt(math.pow(s.x - cx, 2) + math.pow(s.y - cy, 2));
        expect(d, lessThanOrEqualTo(NpcCampRules.radius * 16 + 1e-6),
            reason: '${n.id} at $t');
      }
    }
  });

  test('wander is deterministic and actually moves', () {
    final n = kBiomeNpcs.first;
    final seen = <(double, double)>{};
    for (var t = 0.0; t < 120; t += 1.3) {
      final a = NpcCampRules.state(n, t), b = NpcCampRules.state(n, t);
      expect((a.x, a.y, a.busy, a.walking), (b.x, b.y, b.busy, b.walking));
      seen.add((a.x, a.y));
    }
    expect(seen.length, greaterThan(5));
  });

  test('wander is continuous across segment edges', () {
    final n = kBiomeNpcs.first;
    const e = 1e-6;
    const edge = NpcCampRules.segment * 4;
    final a = NpcCampRules.state(n, edge - e), b = NpcCampRules.state(n, edge);
    expect((a.x - b.x).abs() + (a.y - b.y).abs(), lessThan(0.01));
  });

  test('residents do their activity sometimes, only while idle', () {
    for (final n in kBiomeNpcs) {
      var busy = 0;
      for (var t = 0.0; t < 600; t += 0.5) {
        final s = NpcCampRules.state(n, t);
        if (s.busy) {
          busy++;
          expect(s.walking, isFalse);
        }
      }
      expect(busy, greaterThan(0), reason: n.id);
    }
  });

  test('camp props do not sit on obstacles or the resident tile', () {
    for (final lay in kBiomeLayouts.values) {
      final blocked = {
        ...lay.obstacles,
        ...lay.docks,
        for (final f in lay.forage) (f.x, f.y),
        for (final e in lay.entrances) (e.$2, e.$3),
        lay.npc.tile,
      };
      expect(blocked.contains(NpcCampRules.fireTile(lay.npc)), isFalse,
          reason: lay.id);
      expect(blocked.contains(NpcCampRules.propTile(lay.npc)), isFalse,
          reason: lay.id);
    }
  });

  test('campfire emits a flickering light near the view only', () {
    final def = kLightDefs[LightId.campfire]!;
    expect(def.flicker, greaterThan(0));
    for (final n in kBiomeNpcs) {
      final (fx, fy) = NpcCampRules.fireTile(n)!;
      final l = NpcCampRules.light(n, fx - 2, fy - 2, fx + 2, fy + 2);
      expect(l, isNotNull, reason: n.id);
      expect(l!.def, same(def));
      expect(l.x, fx + 0.5);
      expect(NpcCampRules.light(n, fx + 40, fy + 40, fx + 60, fy + 60),
          isNull);
    }
  });
}
