import 'dart:typed_data';

import '../data/biomes_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/fog_of_war.dart';
import '../models/world_save.dart';

/// What the overworld map marks (biome_exploration.md § 11).
enum OverworldMarkKind {
  /// Mandatory: dungeon entrance (story goal).
  portal,

  /// Mandatory: Eco portal (endgame goal).
  echo,
  waystone,
  shrine,
  chest,
  mine,
  dock,
  resident,
}

/// One mark of the overworld map, in tiles.
class OverworldMark {
  const OverworldMark(this.kind, this.x, this.y, {this.zone, this.index});
  final OverworldMarkKind kind;
  final int x, y;

  /// Zone of a portal / Eco portal.
  final int? zone;

  /// Index in its layout list (waystones).
  final int? index;

  /// Story goal (mandatory) vs optional content.
  bool get goal =>
      kind == OverworldMarkKind.portal || kind == OverworldMarkKind.echo;
}

/// Overworld discovery (biome_exploration.md § 11.4): the region is split
/// in [cell] × [cell] tile cells; the party reveals them by walking. Saved
/// in `TownState.discovery` (biome → packed bits, like `FogOfWar.pack`).
abstract final class MapDiscoveryRules {
  static TuningDef get t => tuning(TuningId.regions);

  /// Tiles per cell side (code constant: it changes the saved format).
  static const cell = 4;

  static int get cols => (BiomeLayout.width + cell - 1) ~/ cell;
  static int get rows => (BiomeLayout.height + cell - 1) ~/ cell;

  /// Every mark of [lay] (goals first).
  static List<OverworldMark> marks(BiomeLayout lay) => [
        for (final (z, x, y) in lay.entrances)
          OverworldMark(OverworldMarkKind.portal, x, y, zone: z),
        for (final (z, x, y) in lay.ecoPortals)
          OverworldMark(OverworldMarkKind.echo, x, y, zone: z),
        for (var i = 0; i < lay.waystones.length; i++)
          OverworldMark(OverworldMarkKind.waystone, lay.waystones[i].x,
              lay.waystones[i].y,
              index: i),
        for (final (x, y) in lay.shrines)
          OverworldMark(OverworldMarkKind.shrine, x, y),
        for (final (x, y) in lay.chestSpots)
          OverworldMark(OverworldMarkKind.chest, x, y),
        for (final (x, y) in lay.mines)
          OverworldMark(OverworldMarkKind.mine, x, y),
        for (final (x, y) in lay.docks)
          OverworldMark(OverworldMarkKind.dock, x, y),
        OverworldMark(
            OverworldMarkKind.resident, lay.npc.tile.$1, lay.npc.tile.$2),
      ];

  static final _base = <String, (int, Uint8List)>{};

  /// Cells known from the start (not saved): around the arrival and the
  /// goals, `mapStartRadius` tiles.
  static Uint8List startCells(BiomeLayout lay) {
    final r = t.d('mapStartRadius');
    final key = lay.id;
    final hit = _base[key];
    final stamp = Object.hash(lay.seed, r);
    if (hit != null && hit.$1 == stamp) return hit.$2;
    final out = Uint8List(cols * rows);
    _reveal(out, lay.spawn.x / 16, lay.spawn.y / 16, r);
    for (final m in marks(lay)) {
      if (m.goal) _reveal(out, m.x + 0.5, m.y + 0.5, r);
    }
    _base[key] = (stamp, out);
    return out;
  }

  /// Marks the cells whose center is within [r] tiles of ([tx], [ty]);
  /// true if any was new.
  static bool _reveal(Uint8List bits, double tx, double ty, double r) {
    var changed = false;
    final c0 = ((tx - r) / cell).floor().clamp(0, cols - 1);
    final c1 = ((tx + r) / cell).floor().clamp(0, cols - 1);
    final r0 = ((ty - r) / cell).floor().clamp(0, rows - 1);
    final r1 = ((ty + r) / cell).floor().clamp(0, rows - 1);
    for (var cy = r0; cy <= r1; cy++) {
      for (var cx = c0; cx <= c1; cx++) {
        final dx = (cx + 0.5) * cell - tx, dy = (cy + 0.5) * cell - ty;
        if (dx * dx + dy * dy > r * r) continue;
        final i = cy * cols + cx;
        if (bits[i] == 0) {
          bits[i] = 1;
          changed = true;
        }
      }
    }
    return changed;
  }

  static final _decoded = <String, (String, Uint8List)>{};

  /// The saved cells of [biome] in [town] (all zero if none / stale).
  static Uint8List saved(TownState town, String biome) {
    final raw = town.discovery[biome];
    if (raw == null) return Uint8List(cols * rows);
    final hit = _decoded[biome];
    if (hit != null && identical(hit.$1, raw)) return hit.$2;
    if (hit != null && hit.$1 == raw) return hit.$2;
    final bits = FogOfWar.unpack(raw, cols, rows) ?? Uint8List(cols * rows);
    _decoded[biome] = (raw, bits);
    return bits;
  }

  /// [town] with the cells around [players] (px) revealed in [lay]; the
  /// same instance when nothing new.
  static TownState reveal(
      TownState town, BiomeLayout lay, Iterable<(double, double)> players) {
    final r = t.d('mapRevealRadius');
    final cur = saved(town, lay.id);
    Uint8List? next;
    for (final (x, y) in players) {
      final probe = next ?? Uint8List.fromList(cur);
      if (_reveal(probe, x / 16, y / 16, r)) next = probe;
    }
    if (next == null) return town;
    final enc = FogOfWar.pack(next, cols, rows);
    _decoded[lay.id] = (enc, next);
    return town.copyWith(discovery: {...town.discovery, lay.id: enc});
  }

  /// Cell (cx, cy) of [lay] is known (start area or discovered).
  static bool knownCell(TownState town, BiomeLayout lay, int cx, int cy) {
    if (cx < 0 || cy < 0 || cx >= cols || cy >= rows) return false;
    final i = cy * cols + cx;
    return startCells(lay)[i] != 0 || saved(town, lay.id)[i] != 0;
  }

  /// Tile ([tx], [ty]) of [lay] is known.
  static bool knownTile(TownState town, BiomeLayout lay, int tx, int ty) =>
      knownCell(town, lay, tx ~/ cell, ty ~/ cell);

  /// Start area ∪ discovered, one byte per cell (for the map mask).
  static Uint8List known(TownState town, BiomeLayout lay) {
    final a = startCells(lay), b = saved(town, lay.id);
    final out = Uint8List(a.length);
    for (var i = 0; i < out.length; i++) {
      out[i] = a[i] | b[i];
    }
    return out;
  }
}
