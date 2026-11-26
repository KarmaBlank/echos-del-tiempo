import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_strings.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/mine_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/action_targeting.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_portal_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/npc_camp_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/wild_loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// The action cursor over every interactable (controls.md § Cursor de
/// acción): each kind is selectable, E acts on the selection, two
/// neighbours of different kinds switch with the mouse / WASD and the
/// prompt always describes the selection.
void main() {
  final tr = worldFallbackStrings();
  tearDown(() => BiomeRegions.bind(0));

  Future<SessionController> world({int seed = 3}) async {
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: InMemoryProfileStore(progression.normalize(PlayerProfile(
          name: 'Ana', classId: 'guerrero', level: 40, unlockedZone: 10))),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(c.dispose);
    await c.start();
    c.debugTown((t) => t.copyWith(sky: t.sky.copyWith(seed: seed, day: 1)));
    return c;
  }

  /// Stand on tile ([x], [y]) and point the mouse at [aim].
  void standAim(SessionController c, (int, int) at, (int, int) aim) {
    c.teleport((at.$1 + 0.5) * 16, (at.$2 + 0.5) * 16);
    c.aimHover(aim);
    c.advance(0.02);
  }

  /// A walkable tile next to [t] (in [rows]), nearest first.
  (int, int)? besideOf(List<String> rows, (int, int) t) {
    for (final (dx, dy) in const [
      (0, 1),
      (1, 0),
      (-1, 0),
      (0, -1),
      (1, 1),
      (-1, 1),
    ]) {
      final x = t.$1 + dx, y = t.$2 + dy;
      if (y < 0 || y >= rows.length || x < 0 || x >= rows[y].length) continue;
      if (Tile.isWalkable(rows[y][x])) return (x, y);
    }
    return null;
  }

  test('town places: the armory is outlined, E opens it', () async {
    final c = await world();
    final map = c.map;
    final (ox, oy) = map.townOrigin;
    final l = (map.townMarks ?? TownLayout.landmarks)
        .firstWhere((l) => l.spot == TownSpot.armory);
    final front = (l.x + ox + l.w ~/ 2, l.y + oy + l.h);
    c.teleport((front.$1 + 0.5) * 16, (front.$2 + 0.3) * 16);
    c.advance(0.02);
    final t = c.actionTarget;
    expect(t?.key, 'spot:armory');
    expect(t!.outline, isTrue);
    expect(ActionTargeting.tone(t), CursorTone.none);
    c.interact();
    expect(c.view!.panel, WorldPanel.armory);
  });

  test('biome: waystone, wilds chest, eco portal and the NPC', () async {
    final c = await world();
    expect(c.travelPlace(kBosque), isTrue);
    final lay = biomeLayout(kBosque)!;
    final rows = lay.rows(const {});

    // Waystone: tile cursor, E opens its menu.
    final w = lay.waystones.first;
    standAim(c, (w.ax, w.ay), (w.x, w.y));
    expect(c.actionTarget?.kind, ActionTargetKind.waystone);
    // Painted into its tile: outlined, no tile cursor.
    expect(c.actionTarget!.outline, isTrue);
    expect(ActionTargeting.tone(c.actionTarget), CursorTone.none);
    expect(
        c.view!.promptLabel,
        tr.t(c.waystoneActive(0)
            ? 'ui.world.way.prompt_use'
            : 'ui.world.way.prompt_activate'));
    c.interact();
    expect(c.view!.panel, WorldPanel.waystone);
    c.closePanel();

    // Wilds chest.
    if (lay.chestSpots.isNotEmpty) {
      final ch = lay.chestSpots.first;
      final at = besideOf(rows, ch)!;
      standAim(c, at, ch);
      expect(c.actionTarget?.kind, ActionTargetKind.chest);
      expect(c.view!.promptLabel, tr.t('ui.world.wild.prompt_chest'));
      c.interact();
      c.advance(0.02);
      expect(WildLootRules.taken(c.town, 'Ana', lay.id, 0), isTrue);
      expect(c.view!.promptLabel, tr.t('ui.world.wild.prompt_done'));
    }

    // Eco portal of this exterior.
    final portal =
        EcoPortalRules.all.where((p) => p.biome == kBosque).firstOrNull;
    if (portal != null) {
      standAim(c, (portal.x, portal.y + 1), (portal.x, portal.y));
      expect(c.actionTarget?.kind, ActionTargetKind.portal);
      c.interact();
      expect(c.view!.panel, WorldPanel.ecoZone);
      c.closePanel();
    }

    // The biome NPC: outlined, "talk" prompt, E opens its screen.
    final at = NpcCampRules.state(lay.npc, c.session!.time);
    final npcTile = ((at.x / 16).floor(), (at.y / 16).floor());
    c.teleport(at.x, at.y + 12);
    c.aimHover(npcTile);
    c.advance(0.02);
    expect(c.actionTarget?.key, 'npc:${lay.npc.id}');
    expect(c.actionTarget!.outline, isTrue);
    expect(c.view!.promptLabel,
        tr.t('ui.world.ctl.prompt_talk', {'name': lay.npc.name}));
    c.interact();
    expect(c.view!.panel, WorldPanel.biomeNpc);
  });

  test('mine: the miner and a rock side by side switch with hover / WASD',
      () async {
    final c = await world();
    // A biome whose first mine level has its NPC.
    String? biome;
    for (final id in kBiomeBases.keys) {
      final lay = biomeLayout(id)!;
      if (MiningRules.entrances(lay).isEmpty) continue;
      final lvl = MiningRules.level(MiningRules.placeOf(id, 0));
      if (lvl?.npc != null) {
        biome = id;
        break;
      }
    }
    expect(biome, isNotNull);
    expect(c.travelPlace(biome!), isTrue);
    expect(c.travelMine(0), isTrue);
    final lvl = c.mineLevel!;
    final (id, nx, ny) = lvl.npc!;
    // A floor tile next to her with a rock on another side.
    (int, int)? stand, rock;
    for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
      final sx = nx + dx, sy = ny + dy;
      if (MiningRules.tileAt(lvl, c.mineState, sx, sy) != Tile.floor) continue;
      for (final (rx, ry) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
        final r = (sx + rx, sy + ry);
        if (r == (nx, ny)) continue;
        final code = MiningRules.tileAt(lvl, c.mineState, r.$1, r.$2);
        if (code == Tile.floor || code == MineTile.torch) continue;
        stand = (sx, sy);
        rock = r;
        break;
      }
      if (stand != null) break;
    }
    expect(stand, isNotNull, reason: 'no rock next to the miner');
    final name = tr.t('ui.world.mine.npc.$id.name');
    final talk = tr.t('ui.world.ctl.prompt_talk', {'name': name});

    // Mouse on her: she is selected, the prompt talks, E talks.
    standAim(c, stand!, (nx, ny));
    expect(c.actionTarget?.key, 'minenpc:$id');
    expect(c.view!.promptLabel, talk);
    // Mouse on the rock: the rock, and the prompt is not hers.
    c.aimHover(rock);
    c.advance(0.02);
    expect(c.actionTarget?.tile, rock);
    expect(c.actionTarget!.outline, isFalse);
    expect(c.view!.promptLabel, isNot(talk));
    // Keyboard: walking toward one picks it (the mouse stops ruling).
    c.aimHover(null);
    c.local
      ..fx = (nx - stand.$1)
      ..fy = (ny - stand.$2);
    c.advance(0.02);
    expect(c.actionTarget?.key, 'minenpc:$id');
    c.local
      ..fx = (rock!.$1 - stand.$1)
      ..fy = (rock.$2 - stand.$2);
    c.advance(0.02);
    expect(c.actionTarget?.tile, rock);
    // Back to her: E talks once, and holding it does not repeat.
    c.local
      ..fx = (nx - stand.$1)
      ..fy = (ny - stand.$2);
    c.advance(0.02);
    c.interact();
    expect(c.view!.panel, WorldPanel.mineNpc);
  });

  test('town: the fountain is selected and E opens it',
      () async {
    final c = await world();
    final map = c.map;
    final (ox, oy) = map.townOrigin;
    final l = (map.townMarks ?? TownLayout.landmarks)
        .firstWhere((l) => l.spot == TownSpot.fountain);
    final front = (l.x + ox + l.w ~/ 2, l.y + oy + l.h);
    c.teleport((front.$1 + 0.5) * 16, (front.$2 + 0.3) * 16);
    c.advance(0.02);
    expect(c.actionTarget?.kind, ActionTargetKind.fountain);
    expect(c.view!.prompt, isNotNull);
    expect(WorldRules.townSpot(c.local.x, c.local.y, map: map),
        TownSpot.fountain);
    c.interact();
    expect(c.view!.panel, WorldPanel.fountain);
  });
}
