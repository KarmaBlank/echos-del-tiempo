import 'package:echos_del_tiempo/game_engine/models/town_build.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Fish only ever live in the life bag (fishing.md § 2.4).

void main() {
  test('a manual catch goes to the life bag', () {
    final p = newProfile('Ana', 'guerrero');
    final out = FishingRules.addCatch(p, const FishCatch('mojarra_claro', 10));
    expect(out.life.count('mojarra_claro'), 1);
  });

  test('lake fishers catch straight into the owner bag; old lake chests '
      'empty into it once', () {
    final e = sessionEngine();
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!.state;
    // An older save: fish waiting in the lake chest, no helper.
    final lake = s.town.builds.firstWhere((b) => b.kind == BuildKind.lago);
    s.town = s.town.withBuild(lake.copyWith(chest: {'mojarra_claro': 3}));
    s = wait(e, s, 1.2);
    expect(s.players['p0']!.profile.life.count('mojarra_claro'), 3);
    expect(s.town.build(lake.id)!.chest, isEmpty);
    // Idempotent: more ticks add nothing.
    s = wait(e, s, 2.2);
    expect(s.players['p0']!.profile.life.count('mojarra_claro'), 3);

    // A hired fisher: after its rounds the chest stays empty and the bag
    // grows.
    s.town = s.town.withBuild(s.town.build(lake.id)!.copyWith(helper: 1));
    final period = TownRules.helperPeriod([s.players['p0']!.profile]);
    s = wait(e, s, period * 2 + 1.2);
    expect(s.town.build(lake.id)!.chest, isEmpty);
    expect(s.players['p0']!.profile.life.bagTotal, greaterThan(3));
  });
}
