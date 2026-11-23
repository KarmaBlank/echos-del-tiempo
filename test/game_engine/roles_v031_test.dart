import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_fisher_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_time_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Roles de exploración (v0.31.0): bestiario, Herrería, poder de
/// aventurero, pescador nativo, tamaño en órdenes y topes guardados.
void main() {
  test('bestiario, Herrería y topes del día viajan en JSON', () {
    final life = LifeSkills(smithXp: 500, smithTree: const ['h_a1'])
        .logCatch(kForestFish.first, 30)
        .logCatch(kForestFish.first, 20);
    expect(life.log[kForestFish.first], 30);
    final back = LifeSkills.fromJson(life.toJson());
    expect(back, life);
    const town = TownState(daily: {'Ana:3': 120});
    expect(TownState.fromJson(town.toJson()).daily['Ana:3'], 120);
  });

  test('Herrería sube, sus nodos dan descuento y poder de aventurero', () {
    var p = newProfile('Ana', 'guerrero');
    p = SmithRules.gain(p, 5000);
    expect(SmithRules.level(p), greaterThan(1));
    p = LifeTreeRules.take(p, LifeSkillKind.herreria, 'h_a1')!;
    p = LifeTreeRules.take(p, LifeSkillKind.herreria, 'h_b1')!;
    expect(SmithRules.forgeDiscount(p), greaterThan(0));
    expect(LifeTreeRules.power(p, LifeFx.hp), greaterThan(0));
    expect(ResidentRules.forgeDiscount(p, const TownState()),
        SmithRules.forgeDiscount(p));
  });

  test('pescador nativo: pide un pez de su lago y se entrega una vez', () {
    final req = BiomeFisherRules.request(kBosque, 4, 1)!;
    expect(bosqueLayout.fish, contains(req.species));
    var p = newProfile('Ana', 'guerrero');
    expect(BiomeFisherRules.cannot(p, const TownState(), kBosque, 4),
        isNotNull);
    p = p.copyWith(
        life: p.life
            .addFish(req.species, req.n)
            .logCatch(req.species, req.cm));
    final r = BiomeFisherRules.deliver(p, const TownState(), kBosque, 4)!;
    expect(r.$1.life.count(req.species), 0);
    expect(BiomeFisherRules.cannot(r.$1.copyWith(
            life: r.$1.life.addFish(req.species, req.n)), r.$2, kBosque, 4),
        'Ya le entregaste hoy');
  });

  test('órdenes de pescado con tamaño usan el récord', () {
    final sp = kForestFish.first;
    final cm = ResidentRules.orderCm(sp, 2);
    expect(cm, greaterThan(kFish[sp]!.minCm));
    final p = newProfile('Ana', 'guerrero');
    final have = p.copyWith(life: p.life.addFish(sp, 2));
    expect(ResidentRules.orderHave(have, sp, 2), 0);
    expect(
        ResidentRules.orderHave(
            have.copyWith(life: have.life.logCatch(sp, cm)), sp, 2),
        2);
  });

  test('cada pescador nativo es de un bioma con lago', () {
    for (final f in kBiomeFishers.values) {
      expect(biomeLayout(f.biome), isNotNull);
    }
  });

  test('horarios de peces y afinidad de cultivos', () {
    const s = SkyState();
    for (final id in kForestFish) {
      expect(LifeTimeRules.activeTable([id], s, () => 1), [id]);
    }
    final common = kForestFish.firstWhere(
        (id) => kFish[id]!.rarity == FishRarity.comun);
    expect(LifeTimeRules.fishActive(common, s), isTrue);
    expect(LifeTimeRules.cropGrowth('nope', s), 1);
  });
}
