import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/cozy_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Lightning rod (docs/specs/cozy_life.md § 2.1).
void main() {
  final t = kTuningDefaults[TuningId.regions]!;
  final r = t.i('lightningRodRadius');
  const town = TownState();
  final (ox, oy) = town.origin;

  TownState withRods(List<(int, int)> mapTiles) => town.copyWith(decor: [
        for (final (x, y) in mapTiles) ('lightning_rod', x - ox, y - oy),
      ]);

  test('protects plots within the radius', () {
    final s = withRods([(30, 30)]);
    expect(CozyRules.lightningRodFor(s, 30, 30), (30, 30));
    expect(CozyRules.lightningRodFor(s, 30 + r, 30), (30, 30));
    expect(CozyRules.lightningRodFor(s, 30 + 3, 30 + 4), r >= 5 ? (30, 30) : null);
  });

  test('no protection outside the radius (nor from a scarecrow)', () {
    final s = withRods([(30, 30)]);
    expect(CozyRules.lightningRodFor(s, 30 + r + 1, 30), isNull);
    expect(CozyRules.lightningRodFor(s, 30 + r, 30 + 1), isNull);
    final crow = town.copyWith(decor: [('scarecrow', 30 - ox, 30 - oy)]);
    expect(CozyRules.lightningRodFor(crow, 30, 31), isNull);
  });

  test('multiple rods: the nearest one catches the bolt', () {
    final s = withRods([(30, 30), (40, 30)]);
    expect(CozyRules.lightningRodFor(s, 32, 30), (30, 30));
    expect(CozyRules.lightningRodFor(s, 38, 30), (40, 30));
    expect(CozyRules.lightningRodFor(s, 50, 30), isNull);
    // The area of the editor mark matches the rule.
    final area = CozyRules.lightningRodArea(30, 30).toSet();
    expect(area.contains((30 + r, 30)), isTrue);
    expect(area.contains((30 + r + 1, 30)), isFalse);
  });

  test('needs the Cultivo level and gold to place', () {
    var p = newProfile('Ana', 'guerrero').copyWith(credits: 1000);
    expect(CozyRules.decorLocked(p, 'scarecrow'), isNull);
    final need = t.i('lightningRodLevel');
    if (need > 1) {
      expect(CozyRules.decorLocked(p, 'lightning_rod'), isNotNull);
      expect(CozyRules.placeDecor(p, town, 'lightning_rod', 30, 30), isNull);
    }
    var xp = 0;
    for (var l = 1; l < need; l++) {
      xp += FarmingRules.xpNeed(l);
    }
    p = p.copyWith(
        life: p.life.copyWith(farm: p.life.farm.copyWith(xp: xp)));
    expect(FarmingRules.level(p), need);
    expect(CozyRules.decorLocked(p, 'lightning_rod'), isNull);
  });

  test('saves keep the rods; the redirect event round-trips', () {
    final s = withRods([(30, 30), (40, 30)]);
    final back = TownState.fromJson(s.toJson());
    expect(back.decor, s.decor);
    expect(CozyRules.lightningRodFor(back, 32, 30), (30, 30));
    const json = EventJson();
    final e = json.fromJson(
            json.toJson(const LightningEvent(30, 30, from: (32, 30))))
        as LightningEvent;
    expect(e.redirected, isTrue);
    expect(e.from, (32, 30));
    final plain =
        json.fromJson(json.toJson(const LightningEvent(5, 6, lost: true)))
            as LightningEvent;
    expect(plain.redirected, isFalse);
    expect(plain.lost, isTrue);
  });
}
