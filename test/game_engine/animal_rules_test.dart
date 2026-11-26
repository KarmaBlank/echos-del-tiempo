import 'dart:convert';
import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/farm_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/animal_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Farm animals (docs/specs/animals.md).
TownBuild coop({List<FarmAnimal> animals = const [], int hay = 0}) =>
    TownBuild('g0', BuildKind.gallinero, const [TownRect(0, 0, 5, 4)],
        animals: animals, hay: hay);

TownBuild barn({List<FarmAnimal> animals = const [], int hay = 0}) =>
    TownBuild('e0', BuildKind.establo, const [TownRect(0, 0, 7, 5)],
        animals: animals, hay: hay);

PlayerProfile farmer({int level = 10, int gold = 10000, int hay = 0}) {
  final b = newProfile('Ana', 'guerrero');
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += FarmingRules.xpNeed(l);
  }
  return b.copyWith(
      credits: gold,
      life: b.life.copyWith(farm: b.life.farm.copyWith(xp: xp, hay: hay)));
}

/// A valid coop / barn spot in [s] (map tile of the corner).
(int, int) spot(TownState s, String defId) {
  for (var y = 0; y < 60; y++) {
    for (var x = 0; x < 60; x++) {
      if (TownRules.place(s, defId, x, y).town != null) return (x, y);
    }
  }
  throw StateError('no spot for $defId');
}

double rnd(math.Random r) => r.nextDouble();

void main() {
  final t = AnimalRules.t;

  group('catalog', () {
    test('every animal, product and home reads its numbers from Balance', () {
      for (final a in kAnimals.values) {
        expect(a.price, greaterThan(0), reason: a.id);
        expect(a.every, greaterThan(0), reason: a.id);
        expect(a.productDef.price, greaterThan(0), reason: a.id);
        expect(a.productDef.xp, greaterThan(0), reason: a.id);
        expect(kAnimalHomes[a.home], isNotNull, reason: a.id);
      }
      for (final h in kAnimalHomes.values) {
        expect(construction(h.id)!.w, h.w);
        expect(construction(h.id)!.h, h.h);
        expect(h.cap, greaterThan(0));
      }
      expect(kTuning[TuningId.animals], isNotNull);
    });

    test('initial catalog matches the spec', () {
      expect(kAnimals['gallina']!.every, 1);
      expect(kAnimals['pato']!.every, 2);
      expect(kAnimals['vaca']!.every, 1);
      expect(kAnimals['cabra']!.every, 2);
      expect(kAnimals['oveja']!.every, 3);
      expect(kAnimals['oveja']!.tool, RanchTool.tijeras);
      expect(kAnimals['vaca']!.tool, RanchTool.cubeta);
      expect(kAnimals['gallina']!.tool, isNull);
    });
  });

  group('daily production cycle', () {
    test('fed every day → one egg a day; a duck every 2 days', () {
      final r = math.Random(1);
      var b = coop(animals: const [FarmAnimal(0, 'gallina'), FarmAnimal(1, 'pato')], hay: 50);
      var p = farmer();
      var eggs = 0, duck = 0;
      for (var day = 1; day <= 6; day++) {
        for (final uid in [0, 1]) {
          final a = b.animal(uid)!;
          if (a.ready != null) {
            final c = AnimalRules.collect(p, b, uid)!;
            b = c.$1;
            if (c.$2.startsWith('huevo_pato')) {
              duck++;
            } else {
              eggs++;
            }
          }
          final f = AnimalRules.feed(p, b, uid, day)!;
          p = f.$1;
          b = f.$2;
        }
        b = AnimalRules.onDay(b, day + 1, () => rnd(r));
      }
      // Days 1..6 fed → ready on mornings 2..7; collected on 2..6.
      expect(eggs, 5);
      expect(duck, 2);
      expect(b.hay, 50 - 12);
    });

    test('unfed: no product, affection drops slowly, never dies', () {
      var b = coop(animals: const [FarmAnimal(0, 'gallina', aff: 250)]);
      for (var day = 2; day < 40; day++) {
        b = AnimalRules.onDay(b, day, () => 0.5);
      }
      final a = b.animals.single;
      expect(a.ready, isNull);
      expect(a.aff, 0);
      expect(b.animals, hasLength(1));
    });

    test('an uncollected product does not stack', () {
      var b = coop(animals: const [FarmAnimal(0, 'gallina', ready: CropQuality.normal)], hay: 9);
      final p = farmer();
      b = AnimalRules.feed(p, b, 0, 1)!.$2;
      b = AnimalRules.onDay(b, 2, () => 0.0);
      expect(b.animals.single.ready, CropQuality.normal);
    });
  });

  group('feeding, petting and affection', () {
    test('E order: collect → feed → pet → done', () {
      final p = farmer(hay: 3);
      var b = coop(animals: const [FarmAnimal(0, 'gallina', ready: CropQuality.raro)]);
      var a = b.animals.single;
      expect(AnimalRules.next(p, b, a, 1), AnimalCare.collect);
      b = AnimalRules.collect(p, b, 0)!.$1;
      a = b.animals.single;
      expect(AnimalRules.next(p, b, a, 1), AnimalCare.feed);
      final f = AnimalRules.feed(p, b, 0, 1)!;
      expect(f.$1.life.farm.hay, 2, reason: 'bag hay first');
      b = f.$2;
      expect(AnimalRules.next(f.$1, b, b.animals.single, 1), AnimalCare.pet);
      b = AnimalRules.pet(b, 0, 1)!.$1;
      expect(AnimalRules.next(f.$1, b, b.animals.single, 1), AnimalCare.done);
      expect(AnimalRules.pet(b, 0, 1), isNull, reason: 'once a day');
      expect(AnimalRules.feed(f.$1, b, 0, 1), isNull, reason: 'once a day');
      expect(b.animals.single.aff, t.i('feedGain') + t.i('petGain'));
    });

    test('no hay anywhere: feeding is blocked with a reason', () {
      final p = farmer();
      final b = coop(animals: const [FarmAnimal(0, 'gallina')]);
      expect(AnimalRules.feedBlock(p, b, b.animals.single, 1), AnimalBlock.noHay);
      expect(AnimalRules.feed(p, b, 0, 1), isNull);
    });

    test('milk and wool need their tool', () {
      var p = farmer();
      final b = barn(animals: const [
        FarmAnimal(0, 'vaca', ready: CropQuality.normal),
        FarmAnimal(1, 'oveja', ready: CropQuality.epico),
      ]);
      expect(AnimalRules.collectBlock(p, b.animal(0)!), AnimalBlock.noTool);
      expect(AnimalRules.collect(p, b, 1), isNull);
      p = AnimalRules.buyTool(p, 'cubeta')!;
      p = AnimalRules.buyTool(p, 'tijeras')!;
      expect(AnimalRules.collect(p, b, 0)!.$2, 'leche@0');
      final wool = AnimalRules.collect(p, b, 1)!;
      expect(wool.$2, 'lana@2');
      expect(wool.$3, (t.i('lanaXp') * 1.8).round());
    });

    test('hearts raise the quality odds (never legendary)', () {
      final o0 = AnimalRules.odds(0), o5 = AnimalRules.odds(5);
      expect(o0[CropQuality.normal], 1);
      expect(o5[CropQuality.raro], closeTo(0.5, 1e-9));
      expect(o5[CropQuality.epico], closeTo(0.24, 1e-9));
      expect(AnimalRules.expectedMult(5), greaterThan(AnimalRules.expectedMult(3)));
      for (var i = 0; i < 100; i++) {
        expect(AnimalRules.roll(i / 100, 5), isNot(CropQuality.legendario));
      }
      expect(AnimalRules.roll(0.0, 5), CropQuality.epico);
      expect(AnimalRules.roll(0.3, 5), CropQuality.raro);
      expect(AnimalRules.roll(0.9, 5), CropQuality.normal);
    });
  });

  group('helpers', () {
    test('a helper feeds from the store, pets up to its heart cap and '
        'collects to the chest', () {
      var b = coop(animals: const [FarmAnimal(0, 'gallina')], hay: 40)
          .copyWith(helper: 1);
      final r = math.Random(3);
      for (var day = 1; day <= 40; day++) {
        b = AnimalRules.helperCare(b, day, (bb, k) => TownRules.addToChest(bb, k, 1));
        b = AnimalRules.onDay(b, day + 1, () => rnd(r));
      }
      final a = b.animals.single;
      expect(a.aff, lessThanOrEqualTo(AnimalRules.helperAffCap));
      expect(AnimalRules.hearts(a.aff), t.i('helperHeartCap'));
      expect(b.hay, 0, reason: 'one bale a day from the store');
      expect(b.chestTotal, greaterThanOrEqualTo(38));
      // Without hay the helper still pets, but nothing is made.
      final chest = b.chestTotal;
      for (var day = 41; day <= 45; day++) {
        b = AnimalRules.helperCare(b, day, (bb, k) => TownRules.addToChest(bb, k, 1));
        b = AnimalRules.onDay(b, day + 1, () => rnd(r));
      }
      expect(b.chestTotal, chest + 1, reason: 'only the product of day 40');
    });

    test('ranch helper hire asks for its own Cultivo level', () {
      final s = const TownState().copyWith(builds: [coop()]);
      final low = farmer(level: AnimalRules.helperLevel - 1);
      expect(TownRules.cannotHire(low, s, 'g0'),
          'Necesitás subir tu oficio de Cultivo a nivel ${AnimalRules.helperLevel} '
          '(ahora: nivel ${AnimalRules.helperLevel - 1})');
      final ok = farmer(level: AnimalRules.helperLevel);
      final h = TownRules.hire(ok.copyWith(life: ok.life.copyWith(
          crafts: {...ok.life.crafts, 'fibra': 99})), s, 'g0');
      expect(h, isNotNull);
      expect(TownRules.cannotHire(ok, h!.$2, 'g0'), 'Ya tiene su granjero de corral');
    });

    test('the chest gives products and a share of the XP', () {
      final s = const TownState().copyWith(
          builds: [coop().copyWith(chest: {'huevo@1': 3})]);
      final p = farmer(level: 1);
      final r = TownRules.collectChest(p, s, 'g0')!;
      expect(r.$1.life.farm.goodsCount('huevo@1'), 3);
      expect(r.$1.life.farm.xp, greaterThan(p.life.farm.xp));
      expect(r.$2.build('g0')!.chest, isEmpty);
    });
  });

  group('shop', () {
    test('buy a building on placement, then animals, hay and tools', () {
      var s = const TownState();
      final (x, y) = spot(s, 'gallinero');
      expect(AnimalRules.cannotBuild(farmer(level: 1), 'gallinero'),
          'Necesitás Cultivo nivel ${t.i('coopLevel')}');
      var p = AnimalRules.payBuild(farmer(gold: 3000), 'gallinero')!;
      expect(p.credits, 3000 - t.i('coopPrice'));
      s = TownRules.place(s, 'gallinero', x, y).town!;
      expect(s.builds.where((b) => b.kind == BuildKind.gallinero), hasLength(1));
      expect(AnimalRules.cannotBuy(p, s, 'vaca'),
          'Primero construí un establo (EDITAR PUEBLO)');
      final r = AnimalRules.buy(p, s, 'gallina')!;
      p = r.$1;
      s = r.$2;
      expect(p.credits, 3000 - t.i('coopPrice') - t.i('gallinaPrice'));
      final home = s.builds.firstWhere((b) => b.kind == BuildKind.gallinero);
      expect(home.animals.single.species, 'gallina');
      p = AnimalRules.buyHay(p, 10)!;
      expect(p.life.farm.hay, 10);
      expect(AnimalRules.buyTool(p, 'cubeta')!.life.farm.hasTool(RanchTool.cubeta), isTrue);
      // A full coop sends the next buyer to build another one.
      for (var i = 1; i < AnimalRules.homeOf(home)!.cap; i++) {
        s = AnimalRules.buy(farmer(), s, 'gallina')!.$2;
      }
      expect(AnimalRules.cannotBuy(farmer(), s, 'gallina'),
          'No hay lugar: construí otro');
      // A coop with animals cannot be removed (they never leave).
      expect(TownRules.remove(p, s, home.id), isNull);
    });

    test('chop crops into hay and sell products by quality', () {
      var p = farmer();
      p = p.copyWith(
          life: p.life.copyWith(
              farm: p.life.farm.copyWith(crops: {'nabo_claro@0': 4})));
      p = AnimalRules.makeHay(p, 'nabo_claro@0', 3)!;
      expect(p.life.farm.hay, 3 * t.i('hayPerCrop'));
      expect(p.life.farm.cropCount('nabo_claro@0'), 1);
      p = p.copyWith(
          life: p.life.copyWith(
              farm: p.life.farm.copyWith(goods: {'huevo@0': 2, 'huevo@2': 1})));
      final gold0 = p.credits;
      final r = AnimalRules.sell(p, null)!;
      expect(r.sold, 3);
      expect(r.gold, t.i('huevoPrice') * 2 + (t.i('huevoPrice') * 1.8).round());
      expect(r.profile.credits, gold0 + r.gold);
      expect(r.profile.life.farm.goods, isEmpty);
    });
  });

  group('save, migration and co-op', () {
    test('town and profile round-trip through JSON', () {
      const a = FarmAnimal(3, 'oveja', aff: 320, fed: 7, pet: 7, cycle: 2,
          ready: CropQuality.raro);
      final b = barn(animals: const [a], hay: 12).copyWith(helper: 1);
      final s = const TownState().copyWith(builds: [b]);
      final back = TownState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      final bb = back.build('e0')!;
      expect(bb.kind, BuildKind.establo);
      expect(bb.animals.single, a);
      expect(bb.hay, 12);
      final f = FarmSkills(
          goods: const {'leche@1': 4}, rtools: const ['cubeta'], hay: 9);
      final fb = FarmSkills.fromJson(jsonDecode(jsonEncode(f.toJson())));
      expect(fb, f);
    });

    test('old saves (before protocol 99) load without animals', () {
      final old = {'xp': 120, 'hoes': ['azada_madera'], 'cans': ['regadera_lata']};
      final f = FarmSkills.fromJson(old);
      expect(f.goods, isEmpty);
      expect(f.rtools, isEmpty);
      expect(f.hay, 0);
      final b = TownBuild.fromJson({
        'id': 'h0',
        'k': 'huerta',
        'p': [[19, 18, 4, 3]]
      })!;
      expect(b.animals, isEmpty);
      expect(b.hay, 0);
      // Unknown species / products are dropped on load.
      final odd = TownBuild.fromJson({
        'id': 'g0',
        'k': 'gallinero',
        'p': [[0, 0, 5, 4]],
        'an': [{'u': 0, 's': 'dragon'}, {'u': 1, 's': 'gallina', 'r': 3}],
      })!;
      expect(odd.animals.single.species, 'gallina');
      expect(odd.animals.single.ready, isNull, reason: 'never legendary');
      expect(FarmSkills.fromJson({'ag': {'nope@0': 2, 'huevo@1': 1}}).goods,
          {'huevo@1': 1});
    });

    test('co-op: the session snapshot carries coops, animals and bags', () {
      final e = sessionEngine();
      var s = e.create();
      s = e.addPlayer(s, 'p0', farmer(hay: 5))!.state;
      s.town = s.town.copyWith(builds: [
        ...s.town.builds,
        coop(animals: const [FarmAnimal(0, 'gallina', aff: 120, ready: CropQuality.raro)], hay: 3),
      ]);
      const j = SessionJson();
      final back = j.fromJson(asJson(jsonDecode(jsonEncode(j.toJson(s)))));
      final b = back.town.build('g0')!;
      expect(b.animals.single.ready, CropQuality.raro);
      expect(b.hay, 3);
      expect(back.players['p0']!.profile.life.farm.hay, 5);
    });
  });

  group('host flow', () {
    GameSession room() {
      final e = sessionEngine();
      var s = e.create();
      s = e.addPlayer(s, 'p0', farmer(hay: 2))!.state;
      final (x, y) = spot(s.town, 'gallinero');
      s.town = TownRules.place(s.town, 'gallinero', x, y).town!;
      final b = s.town.builds.firstWhere((b) => b.kind == BuildKind.gallinero);
      s.town = s.town.withBuild(b.copyWith(
          animals: const [FarmAnimal(0, 'gallina', ready: CropQuality.normal)]));
      final (ox, oy) = s.town.origin;
      final p = s.players['p0']!;
      p.x = (b.bounds.x + ox + 2.5) * 16;
      p.y = (b.bounds.bottom + oy + 0.5) * 16;
      return s;
    }

    test('E on a hen: collect pops an egg, feed, pet; XP for Cultivo', () {
      final e = sessionEngine();
      var s = room();
      final id = s.town.builds.firstWhere((b) => b.kind.ranch).id;
      final xp0 = s.players['p0']!.profile.life.farm.xp;
      s = act(e, s, 'p0', TownAction(TownOp.animalCollect, target: id, n: 0));
      expect(s.players['p0']!.profile.life.farm.goodsCount('huevo@0'), 1);
      s = act(e, s, 'p0', TownAction(TownOp.animalFeed, target: id, n: 0));
      s = act(e, s, 'p0', TownAction(TownOp.animalPet, target: id, n: 0));
      expect(e.apply(s, 'p0', TownAction(TownOp.animalPet, target: id, n: 0)),
          isNull);
      final prof = s.players['p0']!.profile;
      expect(prof.life.farm.hay, 1);
      expect(prof.life.farm.xp,
          xp0 + t.i('huevoXp') + t.i('feedXp') + t.i('petXp'));
    });

    test('too far from the coop: the host rejects the care', () {
      final e = sessionEngine();
      final s = room();
      s.players['p0']!
        ..x = 2 * 16
        ..y = 2 * 16;
      final id = s.town.builds.firstWhere((b) => b.kind.ranch).id;
      expect(e.apply(s, 'p0', TownAction(TownOp.animalPet, target: id, n: 0)),
          isNull);
    });

    test('buying through the host pays and adds the animal', () {
      final e = sessionEngine();
      var s = room();
      final gold = s.players['p0']!.profile.credits;
      s = act(e, s, 'p0', const TownAction(TownOp.buyAnimal, id: 'pato'));
      expect(s.players['p0']!.profile.credits, gold - t.i('patoPrice'));
      expect(s.town.builds.firstWhere((b) => b.kind.ranch).animals, hasLength(2));
      s = act(e, s, 'p0', const FarmShopAction(FarmShopOp.buyHay, n: 4));
      expect(s.players['p0']!.profile.life.farm.hay, 6);
    });
  });
}
