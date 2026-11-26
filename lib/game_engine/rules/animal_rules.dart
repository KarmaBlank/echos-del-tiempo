import 'dart:math' as math;

import '../data/animals_catalog.dart';
import '../data/construction_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/farm_animal.dart';
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'farming_rules.dart' show FarmingRules;

export '../data/animals_catalog.dart';
export '../models/farm_animal.dart';

/// What E does on an animal now (animals.md § 4.2): the first missing
/// step in the order collect → feed → pet.
enum AnimalCare { collect, feed, pet, done }

/// Why a care step cannot happen (the grey button's reason).
enum AnimalBlock { noTool, noHay, fedToday, pettedToday, nothingReady }

/// Farm animals of the Cultivo profession (docs/specs/animals.md). Pure:
/// the host applies the results; numbers in `kTuning['animals']`.
abstract final class AnimalRules {
  static TuningDef get t => tuning(TuningId.animals);

  static int get affMax => math.max(100, t.i('affMax'));
  static int get maxHearts => affMax ~/ 100;

  static int hearts(int aff) => aff.clamp(0, affMax) ~/ 100;

  // ---------------- quality (§ 4.3) ----------------

  /// Odds of each quality for an animal with [h] hearts (never legendary).
  static Map<CropQuality, double> odds(int h) {
    final raro = (t.d('qRaroPerHeart') * h).clamp(0.0, 1.0);
    final epico =
        (t.d('qEpicoPerHeart') * math.max(0, h - 2)).clamp(0.0, 1.0 - raro);
    return {
      CropQuality.normal: 1 - raro - epico,
      CropQuality.raro: raro,
      CropQuality.epico: epico,
    };
  }

  /// Quality of a product from a roll [r] in [0, 1).
  static CropQuality roll(double r, int h) {
    final o = odds(h);
    if (r < o[CropQuality.epico]!) return CropQuality.epico;
    if (r < o[CropQuality.epico]! + o[CropQuality.raro]!) {
      return CropQuality.raro;
    }
    return CropQuality.normal;
  }

  /// Expected price multiplier of [h] hearts (parity and the panel).
  static double expectedMult(int h) => odds(h)
      .entries
      .fold(0.0, (a, e) => a + e.value * qualityMult(e.key));

  static double qualityMult(CropQuality q) =>
      FarmingRules.t.d('qualityMult${q.key}');

  // ---------------- buildings (§ 3) ----------------

  static AnimalHomeDef? homeOf(TownBuild b) => kAnimalHomes[b.kind];

  /// The house rectangle of [b] (town coordinates, top-left of the
  /// footprint).
  static TownRect houseOf(TownBuild b) {
    final h = homeOf(b)!;
    final bb = b.bounds;
    return TownRect(bb.x, bb.y, h.houseW, h.houseH);
  }

  /// Yard tiles of [b] (town coordinates): the footprint minus the house.
  static List<(int, int)> yardTiles(TownBuild b) {
    final bb = b.bounds;
    final house = houseOf(b);
    return [
      for (var y = bb.y; y < bb.bottom; y++)
        for (var x = bb.x; x < bb.right; x++)
          if (b.contains(x, y) && !house.contains(x, y)) (x, y),
    ];
  }

  static bool _edge(TownBuild b, int x, int y) {
    final bb = b.bounds;
    return x == bb.x || y == bb.y || x == bb.right - 1 || y == bb.bottom - 1;
  }

  /// The pasture: yard tiles inside the fence, where the animals roam.
  static List<(int, int)> pastureTiles(TownBuild b) {
    final inner = [
      for (final t in yardTiles(b))
        if (!_edge(b, t.$1, t.$2)) t
    ];
    return inner.isEmpty ? yardTiles(b) : inner;
  }

  /// The gate: the middle tile of the bottom row (town coordinates).
  static (int, int) gateOf(TownBuild b) {
    final bb = b.bounds;
    return (bb.x + bb.w ~/ 2, bb.bottom - 1);
  }

  /// Fence tiles (town coordinates): the yard's border without the gate.
  static Set<(int, int)> fenceTiles(TownBuild b) {
    final g = gateOf(b);
    return {
      for (final t in yardTiles(b))
        if (_edge(b, t.$1, t.$2) && t != g) t
    };
  }

  static int _h(int a, int b) => ((a * 73856093) ^ (b * 19349663)) & 0x7fffffff;

  /// Where [a] of [b] is at room second [time] (town tile coordinates,
  /// fractional; the same on every peer). [asleep]: inside the house.
  static ({double x, double y, bool walk, int dx}) animalPos(
      TownBuild b, FarmAnimal a, double time, {bool asleep = false}) {
    final house = houseOf(b);
    if (asleep) {
      final i = b.animals.indexOf(a).clamp(0, 99);
      return (
        x: house.x + 0.5 + (i % house.w),
        y: house.y + 0.5 + (i ~/ house.w) % house.h,
        walk: false,
        dx: 1
      );
    }
    final yard = pastureTiles(b);
    if (yard.isEmpty) {
      return (x: house.x + 0.5, y: house.y + 0.5, walk: false, dx: 1);
    }
    final k = time / 6 + a.uid * 1.37;
    final seg = k.floor();
    final from = yard[_h(a.uid + 1, seg) % yard.length];
    final to = yard[_h(a.uid + 1, seg + 1) % yard.length];
    final f = k - seg;
    // Grazes the first 60 %, then walks to the next tile.
    final m = f < 0.6 ? 0.0 : (f - 0.6) / 0.4;
    final dx = (to.$1 - from.$1).sign;
    return (
      x: from.$1 + 0.5 + (to.$1 - from.$1) * m,
      y: from.$2 + 0.5 + (to.$2 - from.$2) * m,
      walk: f >= 0.6 && to != from,
      dx: dx == 0 ? (a.uid.isEven ? 1 : -1) : dx,
    );
  }

  /// The nest tile of [a] (town coordinates): where its egg / jug / wool
  /// waits on the floor of the yard.
  static (int, int) nestOf(TownBuild b, FarmAnimal a) {
    final yard = pastureTiles(b);
    if (yard.isEmpty) {
      final h = houseOf(b);
      return (h.x, h.bottom);
    }
    return yard[b.animals.indexOf(a).clamp(0, 99) % yard.length];
  }

  /// Why [p] cannot place the ranch building [defId] (or `null`).
  static String? cannotBuild(PlayerProfile p, String defId) {
    final h = animalHomeById(defId);
    if (h == null) return null;
    final lv = FarmingRules.level(p);
    if (lv < h.level) return 'Necesitás Cultivo nivel ${h.level}';
    if (p.credits < h.price) return 'Falta oro (${p.credits}/${h.price})';
    return null;
  }

  /// [p] after paying for [defId] (`null`: cannot).
  static PlayerProfile? payBuild(PlayerProfile p, String defId) {
    final h = animalHomeById(defId);
    if (h == null || cannotBuild(p, defId) != null) return null;
    return p.copyWith(credits: p.credits - h.price);
  }

  /// A ranch building with animals cannot be removed (§ 3).
  static String? cannotRemove(TownBuild b) =>
      b.kind.ranch && b.animals.isNotEmpty
          ? 'Tiene animales: no se pueden echar'
          : null;

  // ---------------- buying animals (§ 4.1) ----------------

  /// The first building for [species] with room.
  static TownBuild? homeFor(TownState s, String species) {
    final d = kAnimals[species];
    if (d == null) return null;
    for (final b in s.builds) {
      if (b.kind != d.home) continue;
      if (b.animals.length < kAnimalHomes[b.kind]!.cap) return b;
    }
    return null;
  }

  static String? cannotBuy(PlayerProfile p, TownState s, String species) {
    final d = kAnimals[species];
    if (d == null) return 'No existe';
    if (!s.builds.any((b) => b.kind == d.home)) {
      return d.home == BuildKind.gallinero
          ? 'Primero construí un gallinero (EDITAR PUEBLO)'
          : 'Primero construí un establo (EDITAR PUEBLO)';
    }
    if (homeFor(s, species) == null) return 'No hay lugar: construí otro';
    if (FarmingRules.level(p) < d.level) {
      return 'Necesitás Cultivo nivel ${d.level}';
    }
    if (p.credits < d.price) return 'Falta oro (${p.credits}/${d.price})';
    return null;
  }

  static (PlayerProfile, TownState)? buy(
      PlayerProfile p, TownState s, String species) {
    if (cannotBuy(p, s, species) != null) return null;
    final d = kAnimals[species]!;
    final b = homeFor(s, species)!;
    final uid = b.animals.fold(0, (a, x) => math.max(a, x.uid + 1));
    return (
      p.copyWith(credits: p.credits - d.price),
      s.withBuild(b.copyWith(animals: [...b.animals, FarmAnimal(uid, species)])),
    );
  }

  /// Default name of [a] (Spanish source; the UI asks i18n by index).
  static int nameIndex(FarmAnimal a) =>
      a.uid % (kAnimalNames[a.species]?.length ?? 1);

  static String name(FarmAnimal a) =>
      kAnimalNames[a.species]?[nameIndex(a)] ?? a.def.name;

  // ---------------- daily care (§ 4.2) ----------------

  static int _gain(int aff, int n) => (aff + n).clamp(0, affMax);

  /// What E does on [a] for [p] today.
  static AnimalCare next(PlayerProfile p, TownBuild b, FarmAnimal a, int day) {
    if (a.ready != null) return AnimalCare.collect;
    if (a.fed != day && (p.life.farm.hay > 0 || b.hay > 0)) {
      return AnimalCare.feed;
    }
    if (a.pet != day) return AnimalCare.pet;
    if (a.fed != day) return AnimalCare.feed;
    return AnimalCare.done;
  }

  static AnimalBlock? feedBlock(
      PlayerProfile p, TownBuild b, FarmAnimal a, int day) {
    if (a.fed == day) return AnimalBlock.fedToday;
    if (p.life.farm.hay <= 0 && b.hay <= 0) return AnimalBlock.noHay;
    return null;
  }

  static AnimalBlock? petBlock(FarmAnimal a, int day) =>
      a.pet == day ? AnimalBlock.pettedToday : null;

  static AnimalBlock? collectBlock(PlayerProfile p, FarmAnimal a) {
    if (a.ready == null) return AnimalBlock.nothingReady;
    final tool = a.def.tool;
    if (tool != null && !p.life.farm.hasTool(tool)) return AnimalBlock.noTool;
    return null;
  }

  static TownBuild _with(TownBuild b, FarmAnimal a) => b.copyWith(
      animals: [for (final x in b.animals) x.uid == a.uid ? a : x]);

  static PlayerProfile _xp(PlayerProfile p, int n) {
    if (n <= 0) return p;
    final f = p.life.farm;
    return p.copyWith(life: p.life.copyWith(farm: f.copyWith(xp: f.xp + n)));
  }

  /// Feeds [uid] of [b] with a bale of [p]'s bag (or the building store).
  /// Returns the new profile, building and the XP earned.
  static (PlayerProfile, TownBuild, int)? feed(
      PlayerProfile p, TownBuild b, int uid, int day) {
    final a = b.animal(uid);
    if (a == null || feedBlock(p, b, a, day) != null) return null;
    var prof = p;
    var build = b;
    if (p.life.farm.hay > 0) {
      prof = p.copyWith(
          life: p.life
              .copyWith(farm: p.life.farm.copyWith(hay: p.life.farm.hay - 1)));
    } else {
      build = b.copyWith(hay: b.hay - 1);
    }
    build = _with(build, a.copyWith(fed: day, aff: _gain(a.aff, t.i('feedGain'))));
    return (prof, build, t.i('feedXp'));
  }

  static (TownBuild, int)? pet(TownBuild b, int uid, int day) {
    final a = b.animal(uid);
    if (a == null || petBlock(a, day) != null) return null;
    return (
      _with(b, a.copyWith(pet: day, aff: _gain(a.aff, t.i('petGain')))),
      t.i('petXp')
    );
  }

  /// Collects the product of [uid]: the goods key, the building and the
  /// XP (product XP × quality).
  static (TownBuild, String, int)? collect(
      PlayerProfile p, TownBuild b, int uid) {
    final a = b.animal(uid);
    if (a == null || collectBlock(p, a) != null) return null;
    final q = a.ready!;
    final d = a.def.productDef;
    return (
      _with(b, a.copyWith(clearReady: true)),
      animalGoodsKey(d.id, q),
      (d.xp * qualityMult(q)).round(),
    );
  }

  /// XP left under the daily cap: [used] XP already earned today.
  static int capXp(int used, int xp) =>
      math.max(0, math.min(xp, t.i('xpDayCap') - used));

  static PlayerProfile grantXp(PlayerProfile p, int xp) => _xp(p, xp);

  /// The world day turned to [day] (animals.md § 4.2): what happened on
  /// `day − 1` makes the product and the affection decay. [rand] rolls
  /// the quality.
  static TownBuild onDay(TownBuild b, int day, double Function() rand) {
    if (!b.kind.ranch || b.animals.isEmpty) return b;
    final y = day - 1;
    return b.copyWith(animals: [
      for (final a in b.animals) _dayOf(a, y, rand),
    ]);
  }

  static FarmAnimal _dayOf(FarmAnimal a, int y, double Function() rand) {
    var aff = a.aff;
    var cycle = a.cycle;
    var ready = a.ready;
    if (a.fed == y) {
      cycle++;
      if (cycle >= a.def.every) {
        cycle = 0;
        ready ??= roll(rand(), hearts(aff));
      }
    } else {
      aff -= t.i('unfedDecay');
    }
    if (a.pet != y) aff -= t.i('unpetDecay');
    return FarmAnimal(a.uid, a.species,
        aff: aff.clamp(0, affMax),
        fed: a.fed,
        pet: a.pet,
        cycle: cycle,
        ready: ready);
  }

  /// Puts every bale of [p]'s bag into the store of [id] (up to
  /// `siloMax`).
  static (PlayerProfile, TownState)? depositHay(
      PlayerProfile p, TownState s, String id) {
    final b = s.build(id);
    if (b == null || !b.kind.ranch) return null;
    final room = math.max(0, t.i('siloMax') - b.hay);
    final n = math.min(room, p.life.farm.hay);
    if (n <= 0) return null;
    return (
      p.copyWith(
          life: p.life
              .copyWith(farm: p.life.farm.copyWith(hay: p.life.farm.hay - n))),
      s.withBuild(b.copyWith(hay: b.hay + n)),
    );
  }

  // ---------------- helpers (§ 6) ----------------

  static int get helperCap => math.max(0, t.i('helperPerHome'));
  static int get helperLevel => t.i('helperLevel');

  /// Ceiling of the affection a helper raises (points).
  static int get helperAffCap =>
      (t.i('helperHeartCap') * 100).clamp(0, affMax);

  /// One helper round on [b] during [day]: feeds from the store, pets
  /// (capped) and collects to the chest. [chestRoom] keys added go
  /// through [addToChest].
  static TownBuild helperCare(TownBuild b, int day,
      TownBuild Function(TownBuild b, String key) addToChest) {
    if (!b.kind.ranch || b.helper <= 0) return b;
    var out = b;
    final cap = helperAffCap;
    int up(int aff, int n) => aff >= cap ? aff : math.min(cap, aff + n);
    for (final a0 in b.animals) {
      var a = out.animal(a0.uid)!;
      if (a.fed != day && out.hay > 0) {
        out = out.copyWith(hay: out.hay - 1);
        a = a.copyWith(fed: day, aff: up(a.aff, t.i('feedGain')));
      }
      if (a.pet != day) {
        a = a.copyWith(pet: day, aff: up(a.aff, t.i('helperPetGain')));
      }
      if (a.ready case final q?) {
        final key = animalGoodsKey(a.def.product, q);
        final before = out.chestTotal;
        final next = addToChest(_with(out, a), key);
        if (next.chestTotal > before) {
          out = next;
          a = a.copyWith(clearReady: true);
        }
      }
      out = _with(out, a);
    }
    return out;
  }

  // ---------------- shop (§ 2, § 8) ----------------

  static int get hayPrice => math.max(0, t.i('hayPrice'));

  static PlayerProfile? buyHay(PlayerProfile p, int n) {
    if (n <= 0) return null;
    final cost = hayPrice * n;
    final f = p.life.farm;
    if (p.credits < cost || f.hay + n > t.i('hayBagMax')) return null;
    return p.copyWith(
        credits: p.credits - cost,
        life: p.life.copyWith(farm: f.copyWith(hay: f.hay + n)));
  }

  static String? cannotBuyTool(PlayerProfile p, RanchTool tool) {
    if (p.life.farm.hasTool(tool)) return 'Ya la tenés';
    if (p.credits < tool.price) return 'Falta oro (${p.credits}/${tool.price})';
    return null;
  }

  static PlayerProfile? buyTool(PlayerProfile p, String id) {
    final tool = RanchTool.fromId(id);
    if (tool == null || cannotBuyTool(p, tool) != null) return null;
    final f = p.life.farm;
    return p.copyWith(
        credits: p.credits - tool.price,
        life: p.life.copyWith(farm: f.copyWith(rtools: [...f.rtools, tool.id])));
  }

  /// PICAR FARDOS: [n] of the crop [key] become `hayPerCrop` bales each.
  static PlayerProfile? makeHay(PlayerProfile p, String key, int n) {
    final f = p.life.farm;
    if (n <= 0 || f.cropCount(key) < n) return null;
    final int bales = n * math.max(1, t.i('hayPerCrop')).toInt();
    if (f.hay + bales > t.i('hayBagMax')) return null;
    final crops = {...f.crops, key: f.cropCount(key) - n};
    return p.copyWith(
        life: p.life.copyWith(farm: f.copyWith(crops: crops, hay: f.hay + bales)));
  }

  static int unitPrice(String key) {
    final pk = parseAnimalGoodsKey(key);
    if (pk == null) return 0;
    return (pk.$1.price * qualityMult(pk.$2)).round();
  }

  /// Sells [key] (all of it) or, with `null`, every product of the bag.
  static ({PlayerProfile profile, int sold, int gold})? sell(
      PlayerProfile p, String? key) {
    final f = p.life.farm;
    final keys = key == null ? f.goods.keys.toList() : [key];
    var sold = 0, gold = 0;
    final goods = {...f.goods};
    for (final k in keys) {
      final n = goods[k] ?? 0;
      if (n <= 0 || parseAnimalGoodsKey(k) == null) continue;
      sold += n;
      gold += unitPrice(k) * n;
      goods.remove(k);
    }
    if (sold <= 0) return null;
    return (
      profile: p.copyWith(
          credits: p.credits + gold,
          life: p.life.copyWith(farm: f.copyWith(goods: goods))),
      sold: sold,
      gold: gold,
    );
  }

  /// Construction id of a ranch kind (palette and tests).
  static String constructionOf(BuildKind k) =>
      kConstructions.firstWhere((c) => c.kind == k).id;
}
