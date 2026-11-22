import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/fish_line.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_minigame.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_fishing.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Pesca en el mapa (fishing.md § 4, v0.22.2) y botín del agua (§ 8).
void main() {
  final town = MapGenerator.town();
  // El lago ocupa x 3..10, y 14..19: parado en (11, 16) mirando al oeste.
  const sx = 11.5 * 16, sy = 16.5 * 16;

  SessionAction rt(SessionAction a) => ActionJson.fromJson(
      (jsonDecode(jsonEncode(ActionJson.toJson(a))) as Map).cast<String, Object?>());

  void runFor(MapFishing f, double s) {
    for (var t = 0.0; t < s; t += 0.05) {
      f.tick(0.05);
    }
  }

  group('estado de la pesca en el mapa', () {
    test('saca la caña en la orilla y no en tierra firme', () {
      expect(MapFishing.start(town, sx, sy, -1, 0, rand: () => 0.5),
          isNotNull);
      expect(FishingCast.facingWater(town, sx, sy, -1, 0), isTrue);
      expect(FishingCast.facingWater(town, sx, sy, 1, 0), isFalse);
      // Mirando al revés igual encuentra el agua al costado.
      expect(MapFishing.start(town, sx, sy, 1, 0, rand: () => 0.5)!.dir,
          (-1, 0));
      // En el medio del pueblo no hay orilla.
      expect(MapFishing.start(town, 17 * 16, 14.5 * 16, 1, 0, rand: () => 0.5),
          isNull);
    });

    test('cargar, soltar: la boya cae en un tile del lago', () {
      final f = MapFishing.start(town, sx, sy, -1, 0, rand: () => 0.5)!;
      expect(f.line.stage, FishLineStage.rod);
      f.press();
      expect(f.phase, FishPhase.charging);
      expect(f.line.stage, FishLineStage.charging);
      runFor(f, 0.5);
      f.release();
      expect(f.phase, FishPhase.flying);
      final tgt = f.target!;
      expect(FishingCast.isWater(town, tgt.$1, tgt.$2), isTrue);
      runFor(f, 0.6);
      expect(f.phase, FishPhase.waiting);
      expect(f.line.stage, FishLineStage.line);
      expect(FishingCast.plausibleBobber(town, sx, sy, f.line.bx, f.line.by),
          isTrue);
    });

    test('un lance que pasa el lago cae en la orilla y se pierde', () {
      kTuning[TuningId.fishing] = TuningDef('Pesca', {
        ...kTuningDefaults[TuningId.fishing]!.values,
        'maxCastTiles': 12,
      });
      addTearDown(() =>
          kTuning[TuningId.fishing] = kTuningDefaults[TuningId.fishing]!);
      final f = MapFishing.start(town, sx, sy, -1, 0, rand: () => 0.5)!;
      f.press();
      runFor(f, 1.5);
      f.release();
      expect(f.onWater, isFalse);
      runFor(f, 0.6);
      expect(f.phase, FishPhase.lost);
      expect(f.game.lostReason, contains('orilla'));
      expect(f.line.stage, FishLineStage.rod);
    });

    test('cancelar (moverse o Esc) guarda la caña', () {
      final f = MapFishing.start(town, sx, sy, -1, 0, rand: () => 0.5)!;
      f.press();
      f.cancel();
      expect(f.ended, isTrue);
      f.release();
      runFor(f, 1);
      expect(f.target, isNull);
    });

    test('fLn viaja por la red', () {
      const l = FishLine(FishLineStage.bite, bx: 100, by: 250);
      final back = rt(const FishLineAction(l))
          as FishLineAction;
      expect(back.line, l);
      final off = rt(const FishLineAction(null)) as FishLineAction;
      expect(off.line, isNull);
    });
  });

  group('botín del agua', () {
    test('casi siempre pez; pity da cofre o arma; legendarios con nivel y caña',
        () {
      final p = newProfile('Ana', 'guerrero');
      expect(FishingRules.rollLoot(() => 0.99, p), WaterLootKind.fish);
      // Pasa la chance y la segunda tirada cae en la basura (primer peso).
      final seq = [0.0, 0.0];
      var i = 0;
      expect(FishingRules.rollLoot(() => seq[i++], p), WaterLootKind.basura);
      final dry = p.copyWith(
          life: LifeSkills(dry: FishingRules.t.i('lootPityAfter')));
      expect(FishingRules.rollLoot(() => 0.1, dry), WaterLootKind.cofre);
      expect(FishingRules.markDry(dry, WaterLootKind.cofre).life.dry, 0);
      expect(FishingRules.markDry(p, WaterLootKind.basura).life.dry, 1);
      expect(FishingRules.legendEligible(p), isFalse);
      final pro = p.copyWith(
          life: LifeSkills(
              fishXp: 1000000, rods: const ['cana_eco'], rod: 'cana_eco'));
      expect(FishingRules.legendEligible(pro), isTrue);
      expect(kWaterJunk.every((id) => kFish[id] != null), isTrue);
      expect(kTownLakeDefault, isNot(contains(kWaterBundle)));
    });
  });
}
