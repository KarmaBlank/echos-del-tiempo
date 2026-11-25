import 'package:echos_del_tiempo/game_engine/data/town_dressing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/renown.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_dressing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/town_dressing_map.dart';

void main() {
  test('one dressing per town tier; paths go dirt, gravel, cobble', () {
    expect(kTownTierDressing.length, 4);
    expect(TownDressingRules.tierDressing(-1).path, PathMaterial.dirt);
    expect(TownDressingRules.tierDressing(1).path, PathMaterial.gravel);
    expect(TownDressingRules.tierDressing(3).path, PathMaterial.cobble);
    expect(TownDressingRules.tierDressing(9).path, PathMaterial.cobble);
    for (var i = 1; i < 4; i++) {
      final a = kTownTierDressing[i - 1], b = kTownTierDressing[i];
      expect(b.lampPosts, greaterThanOrEqualTo(a.lampPosts));
      expect(b.roofVariant, greaterThanOrEqualTo(a.roofVariant));
    }
  });

  test('the event on today picks its dressing; festival beats tournament',
      () {
    const cfg = RenownConfig(events: [
      TownEventDef(id: 't', kind: TownEventKind.tournament, proposer: 'a'),
      TownEventDef(id: 'f', kind: TownEventKind.festival, proposer: 'b'),
    ]);
    TownState on(Map<String, int> s) =>
        TownState(renown: RenownState(scheduled: s));
    expect(TownDressingRules.eventToday(on({}), 5, cfg), isNull);
    expect(TownDressingRules.eventToday(on({'t': 6}), 5, cfg), isNull);
    expect(TownDressingRules.eventToday(on({'t': 5}), 5, cfg),
        TownEventKind.tournament);
    expect(TownDressingRules.eventToday(on({'t': 5, 'f': 5}), 5, cfg),
        TownEventKind.festival);
    final d = TownDressingRules.of(0, TownEventKind.festival);
    expect(d.event!.centerpiece, EventCenterpiece.bonfire);
    expect(TownDressingRules.of(0, TownEventKind.tournament).event!.centerpiece,
        EventCenterpiece.stage);
  });

  test('layout grows with the tier and never covers path or solid tiles', () {
    final map = dressingTestMap();
    var lastLamps = -1;
    for (var i = 0; i < 4; i++) {
      final l = TownDressingRules.layout(map, TownDressingRules.of(i, null));
      expect(l.lamps.length, greaterThanOrEqualTo(lastLamps));
      lastLamps = l.lamps.length;
      expect(l.well != null, kTownTierDressing[i].well);
      expect(l.plaza.isNotEmpty, kTownTierDressing[i].plaza);
      for (final p in [...l.lamps, ...l.fences, if (l.well case final w?) w, if (l.board case final b?) b]) {
        expect(map.tileAt(p.$1, p.$2), Tile.grass, reason: '$p');
      }
    }
    for (final k in TownEventKind.values) {
      final l = TownDressingRules.layout(map, TownDressingRules.of(3, k));
      expect(l.centre, isNotNull);
      expect(l.garlands, isNotEmpty);
      expect(l.crowd.length, kTownEventDressing[k]!.crowd);
      expect(l.stalls.length, kTownEventDressing[k]!.stalls);
    }
    expect(TownDressingRules.layout(map, TownDressingRules.of(3, null)).crowd,
        isEmpty);
  });
}
