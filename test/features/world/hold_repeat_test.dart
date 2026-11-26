import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/mine_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart'
    show FarmOp;
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Hold = repeat (cozy_life.md § 3): a held E / click keeps working the
/// next valid target without a new press; talking stays single-press.
void main() {
  tearDown(() => BiomeRegions.bind(0));

  Future<SessionController> make({PlayerProfile? p}) async {
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: InMemoryProfileStore(p ??
          progression.normalize(PlayerProfile(
              name: 'Ana', classId: 'guerrero', level: 40, unlockedZone: 10))),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(c.dispose);
    await c.start();
    return c;
  }

  Future<void> wait(SessionController c, int ms) async {
    for (var t = 0; t < ms; t += 50) {
      c.advance(0.05);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void face(SessionController c, double x, double y) {
    c.teleport(x, y);
    c.local
      ..fx = 1
      ..fy = 0;
  }

  /// Into the first mine of the first biome with a level-1 NPC.
  Future<SessionController> inMineWithNpc() async {
    final c = await make();
    for (final id in kBiomeBases.keys) {
      c.closePanel();
      expect(c.travelPlace(id), isTrue);
      final lay = biomeLayout(id)!;
      for (var i = 0; i < MiningRules.entrances(lay).length; i++) {
        final f = MiningRules.entranceFront(id, i);
        c.teleport(f.x, f.y);
        c.interact();
        if (c.mineLevel?.npc != null) return c;
        c.closePanel();
        c.travelMine(null);
      }
    }
    fail('no mine with an NPC');
  }

  /// Floor tiles with a breakable rock to their right (the faced tile).
  List<((int, int), (int, int))> rockSpots(SessionController c) {
    final lvl = c.mineLevel!;
    final tool = MiningRules.tool(c.session!.players[c.localId]!.profile);
    final out = <((int, int), (int, int))>[];
    for (var y = 3; y < lvl.rows.length - 3; y++) {
      for (var x = 3; x < lvl.width - 3; x++) {
        final here = MiningRules.tileAt(lvl, c.mineState, x, y);
        final r = MiningRules.tileAt(lvl, c.mineState, x + 1, y);
        if (!Tile.isWalkable(here) || r != '#' && r != 'r') continue;
        if (MiningRules.cannotBreak(r, lvl.level, tool) != null) continue;
        out.add(((x, y), (x + 1, y)));
      }
    }
    return out;
  }

  bool broken(SessionController c, (int, int) t) =>
      !MineTile.breakable.contains(
          MiningRules.tileAt(c.mineLevel!, c.mineState, t.$1, t.$2));

  Future<void> mineUntil(SessionController c, (int, int) t) async {
    for (var i = 0; i < 300 && !broken(c, t); i++) {
      await wait(c, 50);
    }
    expect(broken(c, t), isTrue, reason: 'rock $t broke');
  }

  ((int, int), (int, int), (int, int), (int, int)) twoRocks(
      SessionController c) {
    final spots = rockSpots(c);
    expect(spots.length, greaterThan(4));
    final a = spots.first;
    final b = spots.firstWhere((s) =>
        (s.$2.$1 - a.$2.$1).abs() + (s.$2.$2 - a.$2.$2).abs() > 3 &&
        s.$1 != a.$2);
    return (a.$1, a.$2, b.$1, b.$2);
  }

  test('holding E across two rocks mines both', () async {
    final c = await inMineWithNpc();
    final (p1, r1, p2, r2) = twoRocks(c);
    face(c, (p1.$1 + 0.5) * 16, (p1.$2 + 0.5) * 16);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    c.holdStart();
    await mineUntil(c, r1);
    // Walk to the next rock, E still held.
    face(c, (p2.$1 + 0.5) * 16, (p2.$2 + 0.5) * 16);
    await mineUntil(c, r2);
    c.holdRelease();
    expect(c.holding, isFalse);
  });

  test('holding the click across two rocks mines both', () async {
    final c = await inMineWithNpc();
    final (p1, r1, p2, r2) = twoRocks(c);
    face(c, (p1.$1 + 0.5) * 16, (p1.$2 + 0.5) * 16);
    c.mineUse(at: r1);
    c.holdStart(tile: r1, pointer: true);
    await mineUntil(c, r1);
    face(c, (p2.$1 + 0.5) * 16, (p2.$2 + 0.5) * 16);
    c.holdAim(r2);
    await mineUntil(c, r2);
    c.holdRelease();
  });

  test('holding E by the mine NPC talks once (pick in hand)', () async {
    final c = await inMineWithNpc();
    final n = c.mineLevel!.npc!;
    expect(c.activeTool, ActiveTool.mine);
    expect(c.mineHand, MineHand.pick);
    c.teleport((n.$2 + 1.5) * 16, (n.$3 + 0.5) * 16);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    c.holdStart();
    expect(c.view!.panel, WorldPanel.mineNpc);
    expect(c.talkMineNpcId, n.$1);
    // A click on her talks too, not a swing.
    expect(c.mineNpcAt(n.$2, n.$3), n.$1);
    c.closePanel();
    // Still holding E: the dialogue does not reopen.
    await wait(c, 800);
    expect(c.view!.panel, isNull);
    c.holdRelease();
  });

  test('holding E across a row of tilled plots plants both', () async {
    final c = await make(p: newProfile('Ana', 'guerrero'));
    const bf = TownLayout.baseFarm;
    final y = (bf.y + 1.5) * 16;
    final xa = (bf.x + 0.5) * 16, xb = (bf.x + 1.5) * 16;
    // Till two plots with single presses.
    face(c, xa, y);
    final ta = c.farmTile!;
    expect(c.farmWork(), isTrue);
    c.advance(0.5);
    face(c, xb, y);
    final tb = c.farmTile!;
    expect(tb, isNot(ta));
    expect(c.farmWork(), isTrue);
    c.advance(0.5);
    // Back to the first: hold E, plant, walk to the next.
    face(c, xa, y);
    expect(c.farmOp, FarmOp.plant);
    c.handleKey(LogicalKeyboardKey.keyE);
    c.holdStart();
    expect(c.view!.panel, isNull);
    c.advance(0.05);
    expect(c.plotAt(ta.$1, ta.$2)!.planted, isTrue);
    face(c, xb, y);
    await wait(c, 600);
    expect(c.plotAt(tb.$1, tb.$2)!.planted, isTrue);
    // The first plot was not watered on its own by the hold.
    expect(c.plotAt(ta.$1, ta.$2)!.waterer, isNull);
    c.holdRelease();
  });

  test('holding E gathers two bushes in a row', () async {
    final c = await make(p: newProfile('Ana', 'guerrero'));
    c.debugTown((t) => t.copyWith(sky: t.sky.copyWith(seed: 3, day: 1)));
    expect(c.travelPlace(kBosque), isTrue);
    BiomeRegions.bind(3);
    final lay = biomeLayout(kBosque)!;
    (double, double)? spot(int i) {
      final f = lay.forage[i];
      for (final (dx, dy) in const [(14.0, 0.0), (-14.0, 0.0), (0.0, 14.0)]) {
        final x = (f.x + 0.5) * 16 + dx, y = (f.y + 0.5) * 16 + dy;
        c.teleport(x, y);
        c.advance(0.01);
        if (c.nearForage == i &&
            c.facingTree == null &&
            c.nearWaystone == null &&
            c.nearWildLoot == null &&
            c.nearMineEntrance == null &&
            c.nearNpc == null) {
          return (x, y);
        }
      }
      return null;
    }

    final found = <(int, (double, double))>[];
    for (var i = 0; i < lay.forage.length && found.length < 2; i++) {
      if (spot(i) case final s?) found.add((i, s));
    }
    expect(found.length, 2);
    final (i0, s0) = found[0];
    final (i1, s1) = found[1];
    c.teleport(s0.$1, s0.$2);
    c.handleKey(LogicalKeyboardKey.keyE);
    c.holdStart();
    final ms = (c.gatherSec * 1000).round() + 400;
    await wait(c, ms);
    expect(BiomeRules.regrowIn(c.town, kBosque, i0, c.session!.time),
        greaterThan(0));
    c.teleport(s1.$1, s1.$2);
    await wait(c, ms + 300);
    expect(BiomeRules.regrowIn(c.town, kBosque, i1, c.session!.time),
        greaterThan(0));
    c.holdRelease();
  });
}
