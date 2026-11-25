import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_strings.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/waystone_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// "No puedo entrar a las minas" (mining_smithing.md § 1.1): from every
/// biome exterior, on a few world seeds, each mine entrance is reachable
/// on foot, shows its prompt and E takes the player to level 1.
void main() {
  /// Tiles reachable on foot from the biome spawn.
  Set<(int, int)> reachable(List<String> rows, (int, int) from) {
    final open = <(int, int)>{};
    final todo = [from];
    while (todo.isNotEmpty) {
      final (x, y) = todo.removeLast();
      if (y < 0 || y >= rows.length || x < 0 || x >= rows[y].length) continue;
      if (!Tile.isWalkable(rows[y][x]) || !open.add((x, y))) continue;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        todo.add((x + dx, y + dy));
      }
    }
    return open;
  }

  for (final seed in [0, 1, 42, 12345]) {
    test('semilla $seed: cada boca de mina se alcanza y E entra', () async {
      final c = SessionController(
        engine: sessionEngine(zones: true),
        store: InMemoryProfileStore(progression.normalize(PlayerProfile(
            name: 'Ana', classId: 'guerrero', level: 40, unlockedZone: 10))),
        clock: const SessionClock(autoStart: false),
      );
      addTearDown(c.dispose);
      await c.start();
      c.debugTown((t) => t.copyWith(sky: t.sky.copyWith(seed: seed)));
      for (final id in kBiomeBases.keys) {
        c.closePanel();
        expect(c.travelPlace(id), isTrue, reason: '$seed $id');
        expect(c.session!.place, id);
        final lay = biomeLayout(id)!;
        expect(lay.seed, seed);
        final rows = lay.rows(const {});
        final sp = lay.spawn;
        final walk =
            reachable(rows, ((sp.x / 16).floor(), (sp.y / 16).floor()));
        final spots = MiningRules.entrances(lay);
        expect(spots, isNotEmpty);
        for (var i = 0; i < spots.length; i++) {
          final (mx, my) = spots[i];
          final why = 'semilla $seed, $id, mina $i en ($mx, $my)';
          expect(rows[my][mx], Tile.mineEntrance, reason: why);
          // The tile in front of the mouth is open and reached on foot.
          expect(walk, contains((mx, my + 1)), reason: why);
          final f = MiningRules.entranceFront(id, i);
          c.teleport(f.x, f.y);
          expect(c.nearMineEntrance, i, reason: why);
          expect(c.view!.promptText,
              worldFallbackStrings().t('ui.world.mine.prompt_enter'),
              reason: why);
          c.interact();
          expect(c.session!.place, MiningRules.placeOf(id, i), reason: why);
          expect(c.session!.mode, SessionMode.lobby);
          // Back out to the biome, in front of the same mouth.
          c.closePanel();
          expect(c.travelMine(null), isTrue, reason: why);
          expect(c.session!.place, id);
        }
        // The mine waystones stay usable from their own front.
        for (var k = 0; k < lay.waystones.length; k++) {
          final w = lay.waystones[k];
          final px = (w.ax + 0.5) * 16, py = (w.ay + 0.5) * 16;
          if (WaystoneRules.near(lay, px, py) != k) continue;
          c.teleport(px, py);
          if (c.nearMineEntrance != null) continue;
          expect(c.nearWaystone, k, reason: '$seed $id piedra $k');
        }
      }
    });
  }
}
