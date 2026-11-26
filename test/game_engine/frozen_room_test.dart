import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/profession_gear_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// v0.49.32 frozen room (session.md § "Tick a prueba de fallos",
/// farming.md § 8.2): a ripe living weapon plot in a farmer's area threw
/// in every helper round, every tick was thrown away and the room clock
/// stopped: helper countdown stuck, nothing could be worked, and the
/// dungeon entry grace never ran out.
void main() {
  (WorldEngine, SessionWorld) world({required bool weaponPlot}) {
    final we = WorldEngine(sessionEngine(freeMovement: true));
    final w = we.create(we.engine.create());
    we.addPlayer(w, 'p0', newProfile('Ana', 'guerrero'));
    var b = kBaseFarm.copyWith(helper: 1);
    final (x, y) = TownRules.helperArea(b, 0).first;
    final (x2, y2) = TownRules.helperArea(b, 0)[1];
    b = b.copyWith(plots: {
      if (weaponPlot)
        plotKey(x, y): const FarmPlot(seed: 'ws_baston', grow: 1e7),
      plotKey(x2, y2): const FarmPlot(seed: 'nabo_claro', grow: 1e7),
    });
    we.setAll(w, (s) => s..town = s.town.withBuild(b));
    return (we, w);
  }

  for (final weaponPlot in [false, true]) {
    test('helper rounds and dungeon grace keep running '
        '(weapon plot: $weaponPlot)', () {
      final errors = <String>[];
      SessionEngine.onRuleError = (r, e, _) => errors.add('$r: $e');
      addTearDown(() => SessionEngine.onRuleError = null);
      final (we, w) = world(weaponPlot: weaponPlot);
      final period = TownRules.t.d('helperEverySec');
      // Two helper rounds in town.
      for (var i = 0; i < (period * 2.2 / 0.5).ceil(); i++) {
        we.tick(w, 0.5);
      }
      final t0 = w.town.time;
      expect(t0, greaterThan(period * 2));
      final b = w.town.town.build('h0')!;
      expect(b.chestTotal, greaterThan(0), reason: 'the crop was harvested');
      final left = b.plots.values.where((p) => p.seed == 'ws_baston');
      expect(left, hasLength(weaponPlot ? 1 : 0),
          reason: 'living weapons are left for a player');
      // Dungeon entry: the grace runs out and actions work.
      expect(we.apply(w, 'p0', const ProposeMissionAction('m1')), isNotNull);
      final d = w.roomOf('p0')!;
      expect(w.rooms[d]!.graceLeft, greaterThan(0));
      for (var i = 0; i < 20; i++) {
        we.tick(w, 0.5);
      }
      expect(w.rooms[d]!.mode, SessionMode.field);
      expect(w.rooms[d]!.graceLeft, 0);
      expect(w.town.time, greaterThan(t0));
      expect(errors, isEmpty);
    });
  }

  test('load repair: unknown seeds go back to tilled, items are kept', () {
    final b = kBaseFarm.copyWith(plots: {
      '0,0': const FarmPlot(seed: 'no_such_seed', wet: 5),
      '1,0': const FarmPlot(seed: 'ws_baston', grow: 3),
      '2,0': const FarmPlot(seed: 'nabo_claro'),
    });
    final t = GearRules.repairPlots(const TownState().withBuild(b));
    final ps = t.build('h0')!.plots;
    expect(ps['0,0']!.seed, isNull);
    expect(ps['0,0']!.wet, 5);
    expect(ps['1,0']!.seed, 'ws_baston');
    expect(ps['2,0']!.seed, 'nabo_claro');
  });
}
