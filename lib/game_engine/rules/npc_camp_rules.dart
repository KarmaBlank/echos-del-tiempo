import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/light_catalog.dart';
import '../data/npc_camp_catalog.dart';
import 'light_rules.dart';

/// Where a biome resident is and what they are doing.
typedef NpcCampState = ({double x, double y, bool busy, bool walking});

/// Pure rules of a resident's camp and wander (overworld_biomes.md
/// § 9.2). Everything is derived from the room clock, so every client
/// sees the same thing with no network traffic.
abstract final class NpcCampRules {
  /// Length of one wander segment (s).
  static const double segment = 6;

  /// Walking part at the start of each segment (s).
  static const double walk = 2;

  /// Wander radius around the center of the home tile (tiles).
  static const double radius = 1.25;

  /// One in [busyEvery] segments does the trade activity while idle.
  static const int busyEvery = 3;

  static int _hash(String id, int k) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    h = ((h ^ (k & 0x7fffffff)) * 0x01000193) & 0x7fffffff;
    h ^= h >> 13;
    h = (h * 0x5bd1e995) & 0x7fffffff;
    return h ^ (h >> 15);
  }

  /// Target of segment [k], in px (inside the wander disc).
  static (double, double) target(BiomeNpcDef npc, int k) {
    final (tx, ty) = npc.tile;
    final h = _hash(npc.id, k);
    final a = (h & 0xffff) / 0x10000 * 2 * math.pi;
    final r = radius * math.sqrt(((h >> 16) & 0x7fff) / 0x8000);
    return (
      (tx + 0.5 + r * math.cos(a)) * 16,
      (ty + 0.5 + r * math.sin(a)) * 16,
    );
  }

  /// Position (px) and pose at room time [time] (s).
  static NpcCampState state(BiomeNpcDef npc, double time) {
    final t = time.isFinite && time > 0 ? time : 0.0;
    final k = (t / segment).floor();
    final local = t - k * segment;
    final (bx, by) = target(npc, k);
    if (local < walk) {
      final (ax, ay) = target(npc, k - 1);
      final f = local / walk;
      return (
        x: ax + (bx - ax) * f,
        y: ay + (by - ay) * f,
        busy: false,
        walking: true,
      );
    }
    return (
      x: bx,
      y: by,
      busy: _hash(npc.id, k + 7919) % busyEvery == 0,
      walking: false,
    );
  }

  /// Campfire tile of [npc] (null if it has no camp).
  static (int, int)? fireTile(BiomeNpcDef npc) {
    final c = kNpcCamps[npc.id];
    if (c == null) return null;
    final (tx, ty) = npc.tile;
    return (tx + c.fire.$1, ty + c.fire.$2);
  }

  /// Prop tile of [npc] (null if it has no camp).
  static (int, int)? propTile(BiomeNpcDef npc) {
    final c = kNpcCamps[npc.id];
    if (c == null) return null;
    final (tx, ty) = npc.tile;
    return (tx + c.propAt.$1, ty + c.propAt.$2);
  }

  /// Campfire light of [npc] when its tile is inside [x0, x1) × [y0, y1)
  /// grown by the light radius, so only camps near the view cost.
  static LightSource? light(BiomeNpcDef npc, int x0, int y0, int x1, int y1) {
    final f = fireTile(npc);
    final def = kLightDefs[LightId.campfire];
    if (f == null || def == null) return null;
    final m = def.radius.ceil();
    if (f.$1 < x0 - m || f.$1 >= x1 + m || f.$2 < y0 - m || f.$2 >= y1 + m) {
      return null;
    }
    return LightSource(f.$1 + 0.5, f.$2 + 0.6, def);
  }
}
