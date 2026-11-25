import 'package:echos_del_tiempo/game_engine/models/game_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Regression: crops stalled at "brote" while a party member was on a
// mission/run (farming.md § 2.3: the town clock always runs while the room
// is open).
void main() {
  test('crops and the world clock keep running during a run', () {
    final e = SessionEngine(
      battles: BattleEngine(stats: statsCalc, random: () => 0.5),
      progression: zoneProgression,
      random: mulberry32(5),
      seeds: () => 4242,
      achievementsEnabled: false,
      gameMode: GameModeKind.travesia,
    );
    var s = e.create();
    s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
    s.town = s.town.copyWith(builds: [
      kBaseFarm.copyWith(plots: {
        '0,0': FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!,
      }),
    ]);
    s = act(e, s, 'p0', const RunStartAction());
    expect(s.run, isNotNull);
    final day0 = s.town.sky;
    for (var i = 0; i < 120; i++) {
      s = e.tick(s, 0.5).state;
    }
    final p = s.town.plots.values.single;
    expect(p.grow, greaterThan(0), reason: 'growth must not pause in a run');
    expect(s.town.sky, isNot(day0), reason: 'the sky clock keeps running');
  });

  test('pausedReason explains an off-season stall', () {
    final p = FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!;
    expect(FarmingRules.growthPaused(p, 0), isTrue);
    expect(FarmingRules.growthPaused(p, 1), isFalse);
  });
}
