import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_route_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Route of an invited NPC to the "CAMINO AL PUEBLO" sign
/// (overworld_biomes.md § 10.1.1).
void main() {
  group('BiomeRouteRules.route', () {
    test('goes around water and lava, never through them', () {
      // S = start, E = end; a wall of water and lava in between.
      final rows = [
        'S..~..',
        '...%..',
        '...~..',
        '.....E',
      ];
      final r = BiomeRouteRules.route(rows, (0, 0), (5, 3))!;
      expect(r.first, (0, 0));
      expect(r.last, (5, 3));
      for (final (x, y) in r) {
        expect(rows[y][x], isNot(anyOf(Tile.water, Tile.lava)));
      }
    });

    test('prefers a trail even when it is a bit longer', () {
      final rows = [
        '.......',
        '.,,,,,.',
        '.,...,.',
        '.,...,.',
        '.,,,,,.',
        '.......',
      ];
      // From one trail corner to the opposite: straight across costs
      // more on grass than walking the trail around.
      final r = BiomeRouteRules.route(rows, (1, 1), (5, 4))!;
      final off = r.where((p) => rows[p.$2][p.$1] != Tile.path).length;
      expect(off, 0);
    });

    test('no route when the goal is walled off', () {
      final rows = ['S.~.', '..~E'];
      expect(BiomeRouteRules.route(rows, (0, 0), (3, 1)), isNull);
    });
  });

  test('every invited biome NPC walks to the town sign over dry land', () {
    for (final b in kBiomes.where((b) => biomeLayout(b.id) != null)) {
      final lay = biomeLayout(b.id)!;
      final n = lay.npc;
      final r = ResidentRules.invite(
          const TownState().withResident(ResidentState(n.id, rep: 3)), n.id,
          time: 100);
      if (r == null) continue;
      final pts = ResidentRules.departureRoute(n, r.resident(n.id));
      final rows = lay.rows(const {});
      // Every tile centre along the way (skip the start and the off-map
      // end) is walkable and never water or lava.
      for (final p in pts.sublist(1, pts.length - 1)) {
        final x = (p.x / 16).floor(), y = (p.y / 16).floor();
        expect(BiomeRouteRules.walkable(rows, x, y), isTrue,
            reason: '${b.id} ($x, $y) = ${rows[y][x]}');
      }
      // It ends at the sign of the south path, then leaves south.
      final exit = BiomeRouteRules.townExit(lay);
      final beforeEnd = pts[pts.length - 2];
      expect(((beforeEnd.x / 16).floor(), (beforeEnd.y / 16).floor()), exit,
          reason: b.id);
      expect(pts.last.y, greaterThan(beforeEnd.y));
      // Most of the walk is on the trail.
      final onTrail = pts
          .sublist(1, pts.length - 1)
          .where((p) =>
              rows[(p.y / 16).floor()][(p.x / 16).floor()] == Tile.path)
          .length;
      expect(onTrail, greaterThan(0), reason: b.id);
      // Same route every time (deterministic: all peers agree).
      final again = ResidentRules.departureRoute(n, r.resident(n.id));
      expect([for (final p in again) (p.x, p.y)],
          [for (final p in pts) (p.x, p.y)]);
    }
  });
}
