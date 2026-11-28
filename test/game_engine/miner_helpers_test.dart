import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/mine_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/helper_motion.dart';
import 'package:echos_del_tiempo/game_engine/rules/mine_work_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Miner helpers: reservations and smooth motion
/// (docs/specs/mining_smithing.md § 1.7).
void main() {
  final step = tuning(TuningId.smithing).d('minerStepSec');
  final lvl =
      MiningRules.level(MiningRules.placeOf(kBosque, 0, 0), worldId: 'w1')!;

  test('3 miners never share a target or a tile', () {
    // All hired one after another: each spawns on its own tile.
    var st = const MineLevelState(station: true);
    for (var i = 0; i < 3; i++) {
      final (x, y) = MineWorkRules.minerSpawn(lvl, st);
      st = st.copyWith(miners: [...st.miners, MinerState(x, y)]);
    }
    // Even stacked on one tile (old saves), the first step spreads them.
    final (sx, sy) = MineWorkRules.minerSpawn(lvl);
    final stacked = MineLevelState(
        station: true,
        miners: [MinerState(sx, sy), MinerState(sx, sy), MinerState(sx, sy)]);
    for (final start in [st, stacked]) {
      var cur = start;
      var now = 0.0;
      for (var i = 0; i < 400 && cur.cart.phase == CartPhase.mine; i++) {
        // Targets claimed this step must be distinct.
        final claimed = <int>{};
        final blocked = <int>{};
        for (final m in cur.miners) {
          final r = MineWorkRules.route(lvl, cur, m.x, m.y,
              tier: m.tier, claimed: claimed, blocked: blocked);
          if (r != null) {
            expect(claimed.add(r.target), isTrue);
          }
        }
        now += step;
        cur = MineWorkRules.minerStep(lvl, cur, now, () => 0.5);
        final tiles = {for (final m in cur.miners) (m.x, m.y)};
        expect(tiles.length, cur.miners.length,
            reason: 'step $i: two miners on one tile');
      }
    }
  });

  test('miner position interpolates smoothly between tiles', () {
    const m = MinerState(6, 5, fx: 5, fy: 5, at: 10);
    final xs = [
      for (var k = 0; k <= 20; k++)
        MineWorkRules.minerPos(m, 10 + step * k / 20).x
    ];
    expect(xs.first, 5.0);
    expect(xs.last, 6.0);
    for (var k = 1; k < xs.length; k++) {
      expect(xs[k], greaterThanOrEqualTo(xs[k - 1]));
      // No jump: each 5 % of the step moves at most a fraction of a tile.
      expect(xs[k] - xs[k - 1], lessThan(0.2));
    }
    // Walking first (no swing), then digging.
    expect(MineWorkRules.minerPos(m, 10 + step * 0.1).work, isFalse);
    expect(MineWorkRules.minerPos(m, 10 + step * 0.9).work, isTrue);
    // Same curve as the farmer helpers.
    final farm = HelperMotion.workThenWalk((0, 0), (1, 0), 0.8);
    expect(farm.x, closeTo(0.5, 1e-9));
    // JSON keeps the step.
    expect(MinerState.fromJson(m.toJson())!.toJson(), m.toJson());
  });
}
