import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/mine_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mine_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/mine_work_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Minería y herrería (docs/specs/mining_smithing.md).
void main() {
  TuningDef t() => tuning(TuningId.smithing);

  /// Smith XP for level [lv].
  int xpFor(int lv) {
    var xp = 0;
    for (var l = 1; l < lv; l++) {
      xp += SmithRules.xpNeed(l);
    }
    return xp;
  }

  PlayerProfile smith(int lv, {int level = 40, Map<String, int> ores = const {}}) {
    final p = newProfile('Ana', 'guerrero');
    return p.copyWith(
        level: level,
        credits: 100000,
        life: p.life.copyWith(smithXp: xpFor(lv), ores: ores));
  }

  MineLevel level0([String biome = kBosque, int i = 0, int lv = 0]) =>
      MiningRules.level(MiningRules.placeOf(biome, i, lv), worldId: 'w1')!;

  /// Tiles reachable on foot from the spawn.
  Set<(int, int)> walk(MineLevel a, MineLevelState st) {
    final open = <(int, int)>{};
    final todo = [a.spawn];
    while (todo.isNotEmpty) {
      final (x, y) = todo.removeLast();
      if (!open.add((x, y))) continue;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final ch = MiningRules.tileAt(a, st, x + dx, y + dy);
        if (Tile.isWalkable(ch) && !open.contains((x + dx, y + dy))) {
          todo.add((x + dx, y + dy));
        }
      }
    }
    return open;
  }

  /// A session in the mine [place] (entered from its biome).
  (SessionEngine, GameSession) inMine(String biome, int i,
      {PlayerProfile? profile}) {
    final e = sessionEngine(zones: true);
    var s = e.addPlayer(e.create(), 'p0', profile ?? smith(1))!.state;
    s = act(e, s, 'p0', TravelAction(biome));
    s = act(e, s, 'p0', TravelAction(MiningRules.placeOf(biome, i)));
    return (e, s);
  }

  void standNextTo(GameSession s, int x, int y) {
    s.players['p0']!
      ..x = (x + 0.5) * 16
      ..y = (y + 1.5) * 16;
  }

  group('minas v2: niveles', () {
    test('generación determinista, borde de roca madre y salida a pie', () {
      final a = MineGenerator.generate(kBosque, 0, 0, 1234);
      final b = MineGenerator.generate(kBosque, 0, 0, 1234);
      final c = MineGenerator.generate(kBosque, 0, 0, 999);
      expect(a.rows, b.rows);
      expect(a.spawn, b.spawn);
      expect(a.shaft, b.shaft);
      expect(a.rows, isNot(c.rows));
      // Bedrock all around (2 tiles).
      for (var x = 0; x < a.width; x++) {
        for (final y in [0, 1, a.height - 2, a.height - 1]) {
          expect(a.rows[y][x], MineTile.bedrock, reason: '($x, $y)');
        }
      }
      for (var y = 0; y < a.height; y++) {
        expect(a.rows[y][0], MineTile.bedrock);
        expect(a.rows[y][a.width - 1], MineTile.bedrock);
      }
      // The exit is reachable from the spawn; there are veins to dig.
      final open = walk(a, const MineLevelState());
      final (ex, ey) = a.exit;
      expect(
          open.contains((ex, ey)) || open.contains((ex, ey + 1)), isTrue);
      expect(a.rows.join().split('').where(MineTile.veins.contains),
          isNotEmpty);
    });

    test('dig-first: sin caminos hechos, cámaras chicas selladas', () {
      for (final b in kBiomeOres.keys) {
        for (var lv = 0; lv < MiningRules.levels; lv++) {
          final a = level0(b, 0, lv);
          // On foot only the entry chamber (7 × 4) and its stairs.
          expect(walk(a, const MineLevelState()).length, lessThanOrEqualTo(30),
              reason: '$b $lv');
          // Veins sit in the walls (the player picks where to tunnel).
          expect(a.rows.join().split('').where(MineTile.veins.contains).length,
              greaterThan(10));
          // Little open ground in all: chambers are small.
          final open = a.rows.join().split('').where((c) => c == '.').length;
          expect(open, lessThan(a.width * a.height ~/ 12), reason: '$b $lv');
          if (lv < MiningRules.levels - 1) expect(a.shaft, isNotNull);
        }
      }
    });

    test('más hondo: más golpes, mejor pico y vetas más ricas', () {
      expect(MiningRules.levels, inInclusiveRange(3, 5));
      expect(MiningRules.hits(Tile.wall, 2),
          greaterThan(MiningRules.hits(Tile.wall, 0)));
      expect(MiningRules.reqTier(MiningRules.levels - 1),
          greaterThan(MiningRules.reqTier(0)));
      final w0 = MiningRules.weights(kBosque, 0);
      final w3 = MiningRules.weights(kBosque, 3);
      double rare(Map<String, double> w) =>
          ((w[MineTile.deep] ?? 0) + (w[MineTile.gem] ?? 0)) /
          w.values.fold(0.0, (a, b) => a + b);
      expect(rare(w3), greaterThan(rare(w0)));
      // Levels link one by one; the first one to its biome.
      final p0 = MiningRules.placeOf(kBosque, 0);
      final p1 = MiningRules.placeOf(kBosque, 0, 1);
      expect(MiningRules.canTravel(kBosque, p0), isTrue);
      expect(MiningRules.canTravel(p0, p1), isTrue);
      expect(MiningRules.canTravel(kBosque, p1), isFalse);
      expect(MiningRules.parse(p1), (kBosque, 0, 1));
    });

    test('cada bioma: bocas de mina desde el único punto de entrada', () {
      for (final lay in kBiomeLayouts.values) {
        final spots = MiningRules.entrances(lay);
        expect(spots, isNotEmpty);
        final rows = lay.rows(const {});
        for (final (x, y) in spots) {
          expect(rows[y][x], Tile.mineEntrance);
        }
      }
    });

    test('roca madre: no se rompe; pico de nivel bajo no alcanza', () {
      final pick = mineTool(kStarterPick)!;
      expect(MiningRules.cannotBreak(MineTile.bedrock, 0, pick), 'bedrock');
      expect(MiningRules.cannotBreak(Tile.wall, 0, pick), isNull);
      final deep = MiningRules.levels - 1;
      expect(MiningRules.cannotBreak(Tile.wall, deep, pick), 'tier');
      final best = kMineTools.last;
      expect(MiningRules.cannotBreak(Tile.wall, deep, best), isNull);
      // A bomb never takes bedrock.
      final lvl = level0();
      final tiles = MiningRules.bombTiles(lvl, const MineLevelState(), 2, 2);
      for (final (x, y) in tiles) {
        expect(lvl.at(x, y), isNot(MineTile.bedrock));
      }
    });
  });

  group('minas v2: picar', () {
    test('picar túnel: golpes, persistencia y JSON', () {
      final (e, s0) = inMine(kBosque, 0);
      var s = s0;
      final place = MiningRules.placeOf(kBosque, 0);
      expect(s.place, place);
      expect(s.battle, isNull);
      final lvl = MiningRules.level(place, worldId: s.worldId)!;
      // A rock next to the walkable area near the spawn.
      final open = walk(lvl, s.town.mine(place));
      final (rx, ry) = [
        for (final (x, y) in open)
          for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1)])
            if (lvl.at(x + dx, y + dy) == Tile.wall) (x + dx, y + dy)
      ].first;
      standNextTo(s, rx, ry - 1);
      s.players['p0']!
        ..x = (rx + 0.5) * 16
        ..y = (ry + 0.5) * 16 - 16;
      var swings = 0;
      while (MiningRules.tileAt(lvl, s.town.mine(place), rx, ry) == Tile.wall &&
          swings < 20) {
        final next = e.apply(s, 'p0', MineAction(MineOp.dig, x: rx, y: ry));
        if (next != null) s = next.state;
        s = e.tick(s, 0.5).state;
        swings++;
      }
      expect(swings, MiningRules.hits(Tile.wall, 0));
      final st = s.town.mine(place);
      expect(st.dug, contains(lvl.idx(rx, ry)));
      expect(MiningRules.tileAt(lvl, st, rx, ry), Tile.floor);
      expect(e.mapFor(s).rows[ry][rx], Tile.floor);
      // Saved with the town (and synced to clients).
      final back = TownState.fromJson(s.town.toJson());
      expect(back.mine(place).dug, st.dug);
      expect(minesFromJson(minesToJson(s.town.mines))[place]!.dug, st.dug);
      // Leave: back in front of the entrance.
      s = act(e, s, 'p0', const TravelAction(kBosque));
      expect(s.place, kBosque);
      expect(s.town.mine(place).dug, st.dug);
    });

    test('bomba: radio, mecha y nunca roca madre', () {
      final lvl = level0();
      final r = t().i('bombRadius');
      // A spot of plain rock at least r tiles from the border.
      (int, int)? spot;
      for (var y = r + 2; y < lvl.height - r - 2 && spot == null; y++) {
        for (var x = r + 2; x < lvl.width - r - 2 && spot == null; x++) {
          var all = true;
          for (var dy = -r; dy <= r && all; dy++) {
            for (var dx = -r; dx <= r && all; dx++) {
              all = MineTile.breakable.contains(lvl.at(x + dx, y + dy));
            }
          }
          if (all) spot = (x, y);
        }
      }
      final (bx, by) = spot!;
      final tiles =
          MiningRules.bombTiles(lvl, const MineLevelState(), bx, by);
      for (final (x, y) in tiles) {
        final dx = x - bx, dy = y - by;
        expect(dx * dx + dy * dy, lessThanOrEqualTo(r * r + r));
      }
      expect(tiles, contains((bx + r, by)));
      expect(tiles, isNot(contains((bx + r, by + r))));
      expect(tiles.length, 21); // radius 2: a round blast
    });

    test('aceite de veta: más mineral mientras dura', () {
      for (final code in [Tile.ore, MineTile.rich]) {
        final plain = MiningRules.veinYield(() => 0.0, kBosque, code: code);
        final oiled =
            MiningRules.veinYield(() => 0.0, kBosque, code: code, boosted: true);
        int sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);
        expect(sum(oiled), greaterThan(sum(plain)), reason: code);
      }
      final (e, s0) = inMine(kBosque, 0,
          profile: smith(1, ores: {kVeinOil: 1}));
      final s = act(e, s0, 'p0', const MineAction(MineOp.boost));
      expect(s.players['p0']!.profile.life.ore(kVeinOil), 0);
      expect(e.apply(s, 'p0', const MineAction(MineOp.boost)), isNull);
    });

    test('cofre de mina: reusa el botín de cofres', () {
      // The first mine level (any biome) with a chest in it.
      for (final lay in kBiomeLayouts.entries) {
        for (var i = 0; i < MiningRules.entrances(lay.value).length; i++) {
          final (e, s0) = inMine(lay.key, i);
          var s = s0;
          final place = MiningRules.placeOf(lay.key, i);
          final lvl = MiningRules.level(place, worldId: s.worldId)!;
          final at = lvl.rows.join().indexOf(MineTile.chest);
          if (at < 0) continue;
          final (cx, cy) = lvl.xy(at);
          s.players['p0']!
            ..x = (cx + 0.5) * 16
            ..y = (cy + 1.5) * 16;
          final gold = s.players['p0']!.profile.credits;
          s = act(e, s, 'p0', MineAction(MineOp.use, x: cx, y: cy));
          final p = s.players['p0']!.profile;
          expect(p.credits, greaterThan(gold));
          expect(s.town.mine(place).opened, contains(lvl.idx(cx, cy)));
          expect(MiningRules.tileAt(lvl, s.town.mine(place), cx, cy),
              MineTile.chestOpen);
          // Once.
          expect(e.apply(s, 'p0', MineAction(MineOp.use, x: cx, y: cy)),
              isNull);
          return;
        }
      }
      fail('no mine level has a chest');
    });
  });

  group('minas v2: vetas que vuelven', () {
    test('una veta picada vuelve solo donde nadie mira', () {
      final lvl = level0();
      final at = lvl.rows.join().indexOf(Tile.ore);
      final (vx, vy) = lvl.xy(at);
      var st = MiningRules.dig(lvl, const MineLevelState(), vx, vy, 0);
      expect(st.regrow.keys, [at]);
      final due = t().d('regrowSec');
      // Someone looking at it: nothing grows.
      final seen = MineWorkRules.regrowTick(
          lvl, st, due + 1, [(vx.toDouble(), vy.toDouble())], () => 0.3);
      expect(seen.grown, isEmpty);
      expect(seen.regrow, st.regrow);
      // Not yet due: nothing.
      expect(MineWorkRules.regrowTick(lvl, st, due - 1, const [], () => 0.3),
          same(st));
      // Nobody around: it grows back in hidden rock near where it was.
      st = MineWorkRules.regrowTick(lvl, st, due + 1, const [], () => 0.3);
      expect(st.regrow, isEmpty);
      expect(st.grown.length, 1);
      final (gx, gy) = lvl.xy(st.grown.keys.first);
      expect((gx - vx).abs(), lessThanOrEqualTo(t().i('regrowRadius')));
      expect((gy - vy).abs(), lessThanOrEqualTo(t().i('regrowRadius')));
      expect(MineTile.veins.contains(MiningRules.tileAt(lvl, st, gx, gy)),
          isTrue);
      // The tunnel stays open.
      expect(MiningRules.tileAt(lvl, st, vx, vy), Tile.floor);
      expect(MineWorkRules.unseen(gx, gy, [(gx.toDouble(), gy.toDouble())], const []),
          isFalse);
      expect(MineWorkRules.unseen(gx, gy, const [], [(gx, gy)]), isFalse);
    });
  });

  group('minas v2: vetas que brillan y se descubren', () {
    test('las vetas brillan apenas, más las raras', () {
      final lvl = level0(kAbismo, 0, MiningRules.levels - 1);
      final map = MiningRules.mapOf(lvl, const MineLevelState());
      final lights = LightRules.tileEmitters(map, 0, 0, map.width, map.height);
      final glow = {
        for (final l in lights)
          if (l.def == kLightDefs[LightId.veta])
            map.rows[l.y.floor()][l.x.floor()]: l.scale
      };
      expect(glow[Tile.ore], isNotNull);
      for (final c in [MineTile.rich, MineTile.deep, MineTile.gem]) {
        if (glow[c] case final k?) expect(k, greaterThan(glow[Tile.ore]!));
      }
      expect(kLightDefs[LightId.veta]!.intensity, lessThan(0.6),
          reason: 'still dim');
    });

    test('vetas descubiertas: por jugador, guardadas, y la que vuelve se '
        'redescubre', () {
      final lvl = level0();
      final at = lvl.rows.join().indexOf(Tile.ore);
      final (vx, vy) = lvl.xy(at);
      var st = const MineLevelState();
      // Far away and behind rock: not known.
      st = MineWorkRules.discover(lvl, st, 'Ana',
          (vx + 30) % lvl.width + 0.5, 3.5);
      expect(st.knownBy('Ana'), isNot(contains(at)));
      // Close by: its glow is seen.
      st = MineWorkRules.discover(lvl, st, 'Ana', vx + 0.5, vy + 2.5);
      expect(st.knownBy('Ana'), contains(at));
      expect(st.knownBy('Beto'), isEmpty, reason: 'per player');
      expect(MineWorkRules.knownVeins(lvl, st, 'Ana').map((v) => (v.$1, v.$2)),
          contains((vx, vy)));
      expect(MineLevelState.fromJson(st.toJson()).knownBy('Ana'),
          st.knownBy('Ana'));
      // Mined: off the minimap; it grows back elsewhere unknown.
      st = MiningRules.dig(lvl, st, vx, vy, 0);
      expect(MineWorkRules.knownVeins(lvl, st, 'Ana').map((v) => (v.$1, v.$2)),
          isNot(contains((vx, vy))));
      st = MineWorkRules.regrowTick(
          lvl, st, t().d('regrowSec') + 1, const [], () => 0.3);
      final g = st.grown.keys.single;
      expect(st.knownBy('Ana'), isNot(contains(g)));
      final (gx, gy) = lvl.xy(g);
      st = MineWorkRules.discover(lvl, st, 'Ana', gx + 0.5, gy + 1.5);
      expect(st.knownBy('Ana'), contains(g));
    });
  });

  group('minas v2: mineros y vagonetas', () {
    test('un minero cava hacia una veta encerrada y llena la vagoneta', () {
      final lvl = level0();
      // Only veins sealed in rock count: dig nothing reachable on foot.
      final open = walk(lvl, const MineLevelState());
      final first = MineWorkRules.nextStep(
          lvl, const MineLevelState(), lvl.station.$1, lvl.station.$2);
      expect(first, isNotNull);
      final (mx, my) = MineWorkRules.minerSpawn(lvl);
      var st = MineLevelState(station: true, miners: [MinerState(mx, my)]);
      var now = 0.0;
      var dugRock = false;
      for (var i = 0; i < 4000 && st.cart.phase == CartPhase.mine; i++) {
        now += t().d('minerStepSec');
        st = MineWorkRules.minerStep(lvl, st, now, () => 0.5);
        dugRock = dugRock ||
            st.dug.any((k) => !open.contains(lvl.xy(k)) &&
                lvl.rows[lvl.xy(k).$2][lvl.xy(k).$1] == Tile.wall);
      }
      expect(dugRock, isTrue, reason: 'it tunnels when there is no path');
      expect(st.cart.phase, CartPhase.toTown);
      expect(st.cart.total, greaterThanOrEqualTo(t().i('cartCap')));
      expect(st.torches, isNotEmpty, reason: 'miners light their tunnels');
      // JSON round trip of miners and cart.
      final back = MineLevelState.fromJson(st.toJson());
      expect(back.toJson(), st.toJson());
    });

    test('pico del minero: nivel, mejora y rinde menos que un jugador', () {
      // Deepest level: a tier-0 miner cannot break anything there.
      final deep = level0(kBosque, 0, MiningRules.levels - 1);
      final (mx, my) = MineWorkRules.minerSpawn(deep);
      expect(MineWorkRules.nextStep(deep, const MineLevelState(), mx, my),
          isNull);
      expect(
          MineWorkRules.nextStep(
              deep, const MineLevelState(), mx, my, tier: kMineTools.last.tier),
          isNotNull);
      // Deep and gem veins need one tier more.
      expect(MiningRules.reqTierOf(MineTile.deep, 0),
          MiningRules.reqTierOf(Tile.wall, 0) + 1);
      // Upgrade at the station: gold + ingots of that tier.
      final (e, s0) = inMine(kBosque, 0,
          profile: smith(1, ores: {'ingot_copper': 20}));
      var s = s0;
      final place = MiningRules.placeOf(kBosque, 0);
      s.town = s.town.withMine(place,
          const MineLevelState(station: true, miners: [MinerState(5, 5)]));
      final c = MineWorkRules.upgradeCost(1)!;
      expect(c.ingot, 'ingot_copper');
      final gold = s.players['p0']!.profile.credits;
      s = act(e, s, 'p0', const MineAction(MineOp.upgrade, n: 0));
      expect(s.town.mine(place).miners.single.tier, 1);
      expect(s.players['p0']!.profile.credits, gold - c.gold);
      expect(s.players['p0']!.profile.life.ore('ingot_copper'), 20 - c.n);
      expect(MinerState.fromJson(s.town.mine(place).miners.single.toJson())!
          .tier, 1);
      expect(MineWorkRules.upgradeCost(kMineTools.last.tier + 1), isNull);
      // Yield: always less than a player on average.
      var i = 0;
      double r() => ((i++ * 7919) % 1000) / 1000;
      var player = 0, miner = 0;
      for (var k = 0; k < 400; k++) {
        player += MiningRules.veinYield(r, kBosque, code: MineTile.rich)
            .values
            .fold(0, (a, b) => a + b);
        miner += MineWorkRules.minerYield(r, kBosque, MineTile.rich)
            .values
            .fold(0, (a, b) => a + b);
      }
      expect(miner, lessThan(player));
      expect(miner, greaterThan(0));
    });

    test('la vagoneta llega al pueblo, se descarga y vuelve', () {
      final place = MiningRules.placeOf(kBosque, 0);
      final ore = kBiomeOres[kBosque]!.ore;
      final e = sessionEngine(zones: true);
      var s = e.addPlayer(e.create(), 'p0', smith(1))!.state;
      s.town = s.town.withMine(
          place,
          MineLevelState(
              station: true,
              cart: MineCart(
                  phase: CartPhase.toTown, t: s.time, load: {ore: 30})));
      expect(e.apply(s, 'p0', MineAction(MineOp.unload, id: place)), isNull,
          reason: 'still on the rails');
      final travel = t().d('cartTravelSec');
      for (var i = 0; i < (travel / 1).ceil() + 1; i++) {
        s = e.tick(s, 1).state;
      }
      expect(s.town.mine(place).cart.phase, CartPhase.town);
      expect(MineWorkRules.townCarts(s.town.mines).single.$1, place);
      // Synced in the town block.
      expect(TownState.fromJson(s.town.toJson()).mine(place).cart.load,
          {ore: 30});
      final had = s.players['p0']!.profile.life.ore(ore);
      s = act(e, s, 'p0', MineAction(MineOp.unload, id: place));
      expect(s.players['p0']!.profile.life.ore(ore), had + 30);
      expect(s.town.mine(place).cart.phase, CartPhase.back);
      for (var i = 0; i < t().d('cartBackSec').ceil() + 1; i++) {
        s = e.tick(s, 1).state;
      }
      expect(s.town.mine(place).cart.phase, CartPhase.mine);
      expect(s.town.mine(place).cart.total, 0);
    });

    test('acciones de mina: JSON ida y vuelta', () {
      for (final a in [
        const MineAction(MineOp.dig, x: 3, y: 9),
        const MineAction(MineOp.bomb, x: 1, y: 2),
        const MineAction(MineOp.unload, id: 'mine:bosque:0:2'),
        const MineAction(MineOp.craft, id: 'pick_copper', mat: 'ore_copper'),
        const MineAction(MineOp.sell, id: 'ingot_copper', n: 4),
      ]) {
        final j = ActionJson.toJson(a);
        expect(ActionJson.toJson(ActionJson.fromJson(j)), j);
      }
    });
  });

  group('minas v2: herramientas y comercio', () {
    test('herramientas: compra, fabricación y el mejor pico', () {
      final e = sessionEngine(zones: true);
      var s = e.addPlayer(e.create(), 'p0', smith(1))!.state;
      final p0 = s.players['p0']!.profile;
      expect(MiningRules.tool(p0).id, kStarterPick);
      s = act(e, s, 'p0', const MineAction(MineOp.buy, id: 'pick_copper'));
      final p1 = s.players['p0']!.profile;
      expect(MiningRules.tool(p1).id, 'pick_copper');
      expect(p1.credits, p0.credits - MiningRules.price('pick_copper'));
      // Only one of each tool.
      expect(e.apply(s, 'p0', const MineAction(MineOp.buy, id: 'pick_copper')),
          isNull);
      // Torches come in batches from the smith.
      final rec = MiningRules.recipe(kMineTorch, 'ore_copper')!;
      s.players['p0']!.profile =
          MiningRules.give(s.players['p0']!.profile, rec.mats);
      s = act(e, s, 'p0',
          const MineAction(MineOp.craft, id: kMineTorch, mat: 'ore_copper'));
      expect(s.players['p0']!.profile.life.ore(kMineTorch), rec.n);
    });

    test('un lingote vale más que sus menas más la fundición', () {
      for (final b in kBiomeOres.values) {
        final (ores, gold) = SmithCraftRules.smeltCost(b.ore)!;
        expect(
            SmithCraftRules.sellPrice(b.ingot),
            greaterThan(SmithCraftRules.sellPrice(b.ore) * ores + gold),
            reason: b.ingot);
      }
      final e = sessionEngine(zones: true);
      var s = e.addPlayer(
              e.create(), 'p0', smith(1, ores: {'ingot_copper': 3}))!
          .state;
      final gold = s.players['p0']!.profile.credits;
      s = act(e, s, 'p0',
          const MineAction(MineOp.sell, id: 'ingot_copper', n: 3));
      expect(s.players['p0']!.profile.credits,
          gold + 3 * SmithCraftRules.sellPrice('ingot_copper'));
      expect(e.apply(s, 'p0',
              const MineAction(MineOp.sell, id: 'ingot_copper', n: 1)),
          isNull);
    });

    test('pedido de herrería: lingotes, se entrega y paga', () {
      // Some (npc, day) gets a smithing order.
      (String, int, String, int)? found;
      for (final n in kBiomeNpcs) {
        for (var day = 1; day < 60 && found == null; day++) {
          if (ResidentRules.smithOrder(n.id, day, 10) case (final o, final c)?) {
            found = (n.id, day, o, c);
          }
        }
        if (found != null) break;
      }
      final (npc, day, ingot, count) = found!;
      expect(kSmithMaterials[ingot]!.kind, SmithMatKind.ingot);
      expect(count, inInclusiveRange(t().i('smithOrderMin'), t().i('smithOrderMax')));
      expect(ResidentRules.smithOrder(npc, day, 0), isNull,
          reason: 'only when someone smiths');
      var town = const TownState().withResident(
          ResidentState(npc, order: ingot, orderN: count, orderDay: day));
      final p = smith(10, ores: {ingot: count});
      final r = ResidentRules.deliverOrder(p, town, npc, 999)!;
      expect(r.$1.life.ore(ingot), 0);
      expect(r.$1.credits, greaterThan(p.credits));
      town = r.$2;
      expect(town.resident(npc).order, isNull);
      expect(ResidentRules.unitValue(ingot),
          greaterThan(SmithCraftRules.sellPrice(ingot)));
    });
  });

  group('herrería', () {
    test('fundir', () {
      final p = smith(1, ores: {'ore_copper': 7});
      expect(SmithCraftRules.smeltMax(p, 'ore_copper'), 2);
      expect(SmithCraftRules.cannotSmelt(p, 'ore_copper', 3), SmithBlock.noOre);
      expect(SmithCraftRules.cannotSmelt(p, 'ingot_copper', 1),
          SmithBlock.notOre);
      final q = SmithCraftRules.smelt(p, 'ore_copper', 2, day: 3)!;
      expect(q.life.ore('ore_copper'), 1);
      expect(q.life.ore('ingot_copper'), 2);
      expect(q.credits, p.credits - 2 * t().i('smeltGoldPerTier'));
      expect(q.life.oreLog['ingot_copper'], const OreFind(3, 'smelt', 2));
    });

    test('FUNDIR en 0: por falta de menas o de oro', () {
      final short = smith(1, ores: {'ore_copper': 2});
      expect(SmithCraftRules.smeltMax(short, 'ore_copper'), 0);
      expect(SmithCraftRules.cannotSmelt(short, 'ore_copper', 1),
          SmithBlock.noOre);
      final broke = smith(1, ores: {'ore_copper': 9}).copyWith(credits: 0);
      expect(SmithCraftRules.smeltMax(broke, 'ore_copper'), 0);
      expect(SmithCraftRules.cannotSmelt(broke, 'ore_copper', 1),
          SmithBlock.noGold);
    });

    test('forjar: nivel de Herrería y rareza', () {
      final e = sessionEngine();
      final base = e.catalog.weapons.values.firstWhere((w) => w.level <= 5);
      final ores = {'ingot_frost': 50, 'rare_rime': 10};
      for (final (lv, r, ok) in [
        (1, Rarity.comun, true),
        (1, Rarity.magico, false),
        (t().i('lvMagico'), Rarity.magico, true),
        (t().i('lvRaro') - 1, Rarity.raro, false),
        (t().i('lvRaro'), Rarity.raro, true),
        (t().i('lvEpico'), Rarity.epico, true),
        (t().i('lvEpico'), Rarity.legendario, false),
      ]) {
        final p = smith(lv, ores: ores);
        expect(SmithRules.level(p), lv);
        final why = SmithCraftRules.cannotForge(p, base, 'ingot_frost', r,
            maxRarity: SmithCraftRules.maxRarity(lv));
        expect(why == null, ok, reason: '$lv $r $why');
      }
      // Crafted weapons stay below the character (loot keeps the top).
      final c = SmithCraftRules.cost(40, 'ingot_frost', Rarity.epico)!;
      expect(c.itemLevel, lessThan(40));
      expect(c.itemLevel,
          lessThanOrEqualTo(t().i('ingotIlPerTier') * 3));
      expect(c.ingots * t().i('smeltOre'),
          greaterThanOrEqualTo(t().i('ingotsEpico') * t().i('smeltOre')));
      // The session forges it at the town forge.
      var s = e.addPlayer(e.create(), 'p0', smith(t().i('lvRaro'), ores: ores))!
          .state;
      s = act(e, s, 'p0',
          SmithAction(SmithOp.forge, 'ingot_frost',
              base: base.id, rarity: Rarity.raro.index));
      final p = s.players['p0']!.profile;
      expect(p.items.any((i) => i.baseId == base.id && i.rarity == Rarity.raro),
          isTrue);
      expect(p.life.ore('ingot_frost'), 50 - t().i('ingotsRaro'));
      expect(p.life.ore('rare_rime'), 10 - t().i('rareRaro'));
    });

    test('legendario: pide Plano antiguo o Núcleo de guardián', () {
      final e = sessionEngine();
      final base = e.catalog.weapons.values.firstWhere((w) => w.level <= 5);
      final ores = {'ingot_echo': 50, 'rare_sand': 10};
      final lv = t().i('lvLegend');
      final cap = SmithCraftRules.maxRarity(lv);
      expect(cap, Rarity.legendario);
      final p = smith(lv, ores: ores);
      expect(
          SmithCraftRules.cannotForge(p, base, 'ingot_echo', Rarity.legendario,
              maxRarity: cap),
          SmithBlock.noRecipe);
      for (final key in [kSchematic, kGuardianCore]) {
        final q = smith(lv, ores: {...ores, key: 1});
        expect(
            SmithCraftRules.cannotForge(
                q, base, 'ingot_echo', Rarity.legendario,
                maxRarity: cap),
            isNull);
        final paid = SmithCraftRules.pay(q, 'ingot_echo', Rarity.legendario)!;
        expect(paid.life.ore(key), 0);
      }
    });

    test('encargo a Brann: con Brann en casa, por oro, rareza de su encargo',
        () {
      final e = sessionEngine();
      final base = e.catalog.weapons.values.firstWhere((w) => w.level <= 5);
      final prof = smith(1, ores: {'ingot_copper': 10});
      var s = e.addPlayer(e.create(), 'p0', prof)!.state;
      const a = SmithAction(SmithOp.brann, 'ingot_copper',
          base: null, rarity: 1);
      final withBase = SmithAction(SmithOp.brann, 'ingot_copper',
          base: base.id, rarity: a.rarity);
      expect(e.apply(s, 'p0', withBase), isNull, reason: 'Brann no vive acá');
      s.town = s.town.withResident(const ResidentState('brann',
          invited: true, house: 1));
      // Smith level 1 cannot forge Mágico alone, Brann can.
      expect(
          e.apply(s, 'p0',
              SmithAction(SmithOp.forge, 'ingot_copper',
                  base: base.id, rarity: 1)),
          isNull);
      s = act(e, s, 'p0', withBase);
      final p = s.players['p0']!.profile;
      final c = SmithCraftRules.cost(prof.level, 'ingot_copper', Rarity.magico,
          brann: true)!;
      expect(p.credits, prof.credits - c.gold);
      expect(c.gold, t().i('brannGoldPerIl') * c.itemLevel);
      final forged = p.items.firstWhere(
          (i) => i.baseId == base.id && i.rarity == Rarity.magico);
      // Forged weapons sell above loot of the same rarity.
      expect(forged.uid, startsWith(CraftRules.forgedPrefix));
    });
  });

  group('colección y guardado', () {
    test('JSON ida y vuelta de materiales y colección', () {
      final life = LifeSkills.initial
          .addOres({'ore_copper': 4, 'schematic': 1, 'basura': 3})
          .logOres({'ore_copper': 4}, 'mine:$kBosque', 2)
          .logOres({'ore_copper': 1}, 'dungeon:3', 5);
      expect(life.ore('basura'), 0);
      expect(life.oreLog['ore_copper'], const OreFind(2, 'mine:$kBosque', 5));
      final back = LifeSkills.fromJson(life.toJson());
      expect(back, life);
      expect(back.ores, {'ore_copper': 4, 'schematic': 1});
      for (final a in [
        const SmithAction(SmithOp.smelt, 'ore_copper', n: 5),
        const SmithAction(SmithOp.brann, 'ingot_echo',
            base: 'espada', rarity: 4),
      ]) {
        final j = ActionJson.toJson(a);
        expect(ActionJson.toJson(ActionJson.fromJson(j)), j);
      }
    });

    test('entradas de la colección: descubiertos y "?"', () {
      var p = newProfile('Ana', 'guerrero');
      p = MiningRules.give(p, {'ore_copper': 2},
          source: MiningRules.mineSource(kBosque), day: 4);
      final all = SmithCollection.entries(p);
      expect(all.length,
          kSmithMaterials.values.where((d) => d.kind != SmithMatKind.tool && d.kind != SmithMatKind.supply).length);
      final cu = all.firstWhere((x) => x.id == 'ore_copper');
      expect(cu.discovered, isTrue);
      expect(cu.icon, 'vida_ore_copper');
      expect(cu.rows.map((r) => r.$1), contains('ui.inventory.smith.col.use.smelt'));
      expect(cu.rows.first.$2['source'], 'mine:$kBosque');
      final hidden = all.firstWhere((x) => x.id == 'rare_sand');
      expect(hidden.discovered, isFalse);
      expect(hidden.rows, isEmpty);
      for (final d in kSmithMaterials.values) {
        if (d.kind == SmithMatKind.tool || d.kind == SmithMatKind.supply) {
          continue;
        }
        expect(SmithCollection.usesOf(d.id), isNotEmpty, reason: d.id);
      }
    });
  });
}
