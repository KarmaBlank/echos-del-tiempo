import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/tile_target.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/action_targeting.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/cozy_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// The action cursor in a biome (controls.md § Cursor de acción): the
/// searchable tree is selected from any side and E works it.
void main() {
  tearDown(() => BiomeRegions.bind(0));

  Future<SessionController> inForest() async {
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: InMemoryProfileStore(newProfile('Ana', 'guerrero')),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(c.dispose);
    await c.start();
    c.debugTown((t) => t.copyWith(sky: t.sky.copyWith(seed: 3, day: 1)));
    expect(c.travelPlace(kBosque), isTrue);
    BiomeRegions.bind(3);
    return c;
  }

  /// A searchable tree and its walkable neighbours with nothing else
  /// actionable in reach.
  ((int, int), List<(int, int)>)? lonelyTree(SessionController c) {
    final map = c.map;
    final lay = biomeLayout(kBosque)!;
    bool other(int x, int y, (int, int) tree) {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final p = (x + dx, y + dy);
          if (p == tree) continue;
          if (CozyRules.searchable(map, lay.id, 1, p.$1, p.$2)) return true;
          if (lay.forage.any((f) => (f.x, f.y) == p)) return true;
        }
      }
      return false;
    }

    for (var y = 2; y < map.height - 2; y++) {
      for (var x = 2; x < map.width - 2; x++) {
        if (!CozyRules.searchable(map, lay.id, 1, x, y)) continue;
        final sides = <(int, int)>[
          for (final (dx, dy) in const [(-1, 0), (1, 0), (0, -1), (0, 1)])
            if (Tile.isWalkable(map.tileAt(x + dx, y + dy)) &&
                !other(x + dx, y + dy, (x, y)))
              (x + dx, y + dy)
        ];
        if (sides.length >= 2) return ((x, y), sides);
      }
    }
    return null;
  }

  test('a searchable tree is the target from any side, facing away',
      () async {
    final c = await inForest();
    final found = lonelyTree(c);
    expect(found, isNotNull);
    final (tree, sides) = found!;
    for (final (sx, sy) in sides) {
      c.teleport((sx + 0.5) * 16, (sy + 0.5) * 16);
      // Facing away from the tree.
      c.local
        ..fx = sx - tree.$1
        ..fy = sy - tree.$2;
      c.advance(0.02);
      expect(c.facingTree, tree, reason: 'from ($sx, $sy)');
      expect(ActionTargeting.tone(c.gatherTarget), CursorTone.ok);
    }
  });

  test('E on the selection starts the search on that tree', () async {
    final c = await inForest();
    final (tree, sides) = lonelyTree(c)!;
    final (sx, sy) = sides.first;
    c.teleport((sx + 0.5) * 16, (sy + 0.5) * 16);
    c.local
      ..fx = sx - tree.$1
      ..fy = sy - tree.$2;
    c.advance(0.02);
    c.interact();
    expect(c.gatherProgress?.$1, tree);
    c.gatherHoldEnd();
  });

  test('mouse hover in reach selects, far click does nothing', () async {
    final c = await inForest();
    final (tree, sides) = lonelyTree(c)!;
    final (sx, sy) = sides.first;
    c.teleport((sx + 0.5) * 16, (sy + 0.5) * 16);
    c.advance(0.02);
    c.aimHover(tree);
    expect(c.gatherTarget?.tile, tree);
    expect(c.gatherPress((sx + 8, sy + 8)), isFalse);
    expect(c.gatherPress(tree), isTrue);
    expect(c.gatherProgress?.$1, tree);
    c.gatherHoldEnd();
  });

  test('preview: action cursor states', () async {
    if (Platform.environment['PREVIEW_SHOTS'] == null) return;
    const ts = 16.0, scale = 6.0;
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec);
    cv.scale(scale);
    cv.drawRect(const Rect.fromLTWH(0, 0, 9 * ts, 3 * ts),
        Paint()..color = const Color(0xFF3B5D2E));
    // Player, green target, orange target.
    cv.drawRect(const Rect.fromLTWH(1 * ts + 4, 1 * ts + 2, 8, 12),
        Paint()..color = const Color(0xFFE0C090));
    cv.drawRect(const Rect.fromLTWH(2 * ts + 2, 1 * ts + 1, 12, 14),
        Paint()..color = const Color(0xFF1E4A20));
    drawTileTarget(cv, [(2, 1)], true);
    cv.drawRect(const Rect.fromLTWH(5 * ts + 4, 1 * ts + 2, 8, 12),
        Paint()..color = const Color(0xFFE0C090));
    cv.drawRect(const Rect.fromLTWH(6 * ts + 2, 1 * ts + 1, 12, 14),
        Paint()..color = const Color(0xFF1E4A20));
    drawTileTarget(cv, [(6, 1)], false);
    final img = await rec
        .endRecording()
        .toImage((9 * ts * scale).round(), (3 * ts * scale).round());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('docs/preview/action_cursor.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
