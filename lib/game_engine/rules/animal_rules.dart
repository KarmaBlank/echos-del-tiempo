import 'dart:math' as math;

import '../data/animals_catalog.dart';
import '../data/construction_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/life_tree_catalog.dart' show LifeFx;
import '../data/tuning_catalog.dart';
import '../models/farm_animal.dart';
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'farming_rules.dart' show FarmingRules;
import 'life_tree_rules.dart' show LifeTreeRules;

export '../data/animals_catalog.dart';
export '../models/farm_animal.dart';

/// What E does on an animal now (animals.md § 4.2): the first missing
/// step in the order collect → feed → pet.
enum AnimalCare { collect, feed, pet, done }

/// Why a care step cannot happen (the grey button's reason).
enum AnimalBlock { noTool, noHay, fedToday, pettedToday, nothingReady }

/// Why a machine cannot run (animals.md § 11).
enum MachineBlock { noMachine, level, nothing, notProcessable }

/// The ANIMALES tree bonuses that act on a building when no single
/// player does the action (the new world day): the best of the players
/// in town (animals.md § 8).
typedef AnimalBonus = ({double part, double quality, double legend});

const AnimalBonus kNoAnimalBonus = (part: 0, quality: 0, legend: 0);

/// What one collect gave (animals.md § 4.2, § 9, § 10): bag keys of
/// products (and legendary products), smithing part ids and the XP.
typedef AnimalPickup = ({
  TownBuild build,
  List<String> goods,
  List<String> parts,
  int xp,
});

/// Farm animals of the Granjero profession, ANIMALES branch
/// (docs/specs/animals.md). Pure: the host applies the results; numbers
/// in `kTuning['animals']`.
abstract final class AnimalRules {
  static TuningDef get t => tuning(TuningId.animals);

  static int get affMax => math.max(100, t.i('affMax'));
  static int get maxHearts => affMax ~/ 100;

  static int hearts(int aff) => aff.clamp(0, affMax) ~/ 100;

  // ---------------- tree (§ 8) ----------------

  /// The ANIMALES bonuses of [p].
  static AnimalBonus bonusOf(PlayerProfile p) => (
        part: LifeTreeRules.farm(p, LifeFx.partDrop),
        quality: LifeTreeRules.farm(p, LifeFx.animalQuality),
        legend: LifeTreeRules.farm(p, LifeFx.animalLegend),
      );

  /// The best bonuses among [players] (the new world day).
  static AnimalBonus bestBonus(Iterable<PlayerProfile> players) {
    var out = kNoAnimalBonus;
    for (final p in players) {
      final b = bonusOf(p);
      out = (
        part: math.max(out.part, b.part),
        quality: math.max(out.quality, b.quality),
        legend: math.max(out.legend, b.legend),
      );
    }
    return out;
  }

  /// Hay store size of a building for [p] (`siloMax` + the tree).
  static int siloMax([PlayerProfile? p]) =>
      t.i('siloMax') +
      (p == null ? 0 : LifeTreeRules.farm(p, LifeFx.haySilo).round());

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

  /// [q] one step up with chance [chance] (never past épica).
  static CropQuality bump(CropQuality q, double chance, double r) =>
      r < chance && q.index < CropQuality.epico.index
          ? CropQuality.values[q.index + 1]
          : q;

  /// Expected price multiplier of [h] hearts (parity and the panel).
  static double expectedMult(int h) => odds(h)
      .entries
      .fold(0.0, (a, e) => a + e.value * qualityMult(e.key));

  static double qualityMult(CropQuality q) =>
      FarmingRules.t.d('qualityMult${q.key}');

  // ---------------- parts and legends (§ 9, § 10) ----------------

  /// Chance of a part per event for an animal with [h] hearts and the
  /// tree bonus [bonus] (× 1 + bonus).
  static double partChance(int h, [double bonus = 0]) =>
      ((t.d('partBase') + t.d('partPerHeart') * h) * (1 + bonus))
          .clamp(0.0, 1.0)
          .toDouble();

  /// Chance of a legendary product per production at full hearts.
  static double legendChance([double bonus = 0]) =>
      (t.d('legendChance') + bonus).clamp(0.0, 1.0).toDouble();

  /// The part [a] sheds on the floor of its home (feathers in the coop,
  /// horn in the barn), or `null` (sheep leave theirs to the shears).
  static AnimalPart? floorPart(AnimalDef a) => a.parts.contains(
          AnimalPart.feather)
      ? AnimalPart.feather
      : a.parts.contains(AnimalPart.horn)
          ? AnimalPart.horn
          : null;

  /// Quality (0..1) of a part as a forge material.
  static double partQ(int q) => switch (q) {
        0 => t.d('partQNormal'),
        1 => t.d('partQRaro'),
        _ => t.d('partQEpico'),
      };

  static String _part(
          AnimalDef d, AnimalPart part, int h, double quality, double Function() r) =>
      animalPartId(d.id, part, bump(roll(r(), h), quality, r()).index);

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
  /// and its drops wait on the floor of the yard.
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
    if (lv < h.level) return 'Necesitás Granjero nivel ${h.level}';
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
      return 'Necesitás Granjero nivel ${d.level}';
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
    if (a.hasPickup && collectBlock(p, a) == null) return AnimalCare.collect;
    if (a.fed != day && (p.life.farm.hay > 0 || b.hay > 0)) {
      return AnimalCare.feed;
    }
    if (a.pet != day) return AnimalCare.pet;
    if (a.fed != day) return AnimalCare.feed;
    if (a.hasPickup) return AnimalCare.collect;
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

  /// Drops can always be picked up; the product may need its tool.
  static AnimalBlock? collectBlock(PlayerProfile p, FarmAnimal a) {
    if (!a.hasPickup) return AnimalBlock.nothingReady;
    final tool = a.def.tool;
    if (a.drops.isEmpty &&
        tool != null &&
        !p.life.farm.hasTool(tool)) {
      return AnimalBlock.noTool;
    }
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

  /// Pets [uid] (no tree, no brushing: tests and the helpers' model).
  static (TownBuild, int)? pet(TownBuild b, int uid, int day) {
    final r = petBy(null, b, uid, day, () => 1);
    return r == null ? null : (r.$1, r.$2);
  }

  /// [p] pets [uid] (animals.md § 4.2): affection × (1 + Mano tibia);
  /// a cow or a goat is brushed and may leave shed fur (§ 9). Returns the
  /// building, the XP and the part ids for [p].
  static (TownBuild, int, List<String>)? petBy(PlayerProfile? p, TownBuild b,
      int uid, int day, double Function() rand) {
    final a = b.animal(uid);
    if (a == null || petBlock(a, day) != null) return null;
    final care = p == null ? 0.0 : LifeTreeRules.farm(p, LifeFx.petCare);
    final gain = (t.i('petGain') * (1 + care)).round();
    final parts = <String>[];
    if (p != null && a.def.parts.contains(AnimalPart.fur)) {
      final bonus = bonusOf(p);
      if (rand() < partChance(a.hearts, bonus.part)) {
        parts.add(_part(a.def, AnimalPart.fur, a.hearts, bonus.quality, rand));
      }
    }
    return (
      _with(b, a.copyWith(pet: day, aff: _gain(a.aff, gain))),
      t.i('petXp'),
      parts,
    );
  }

  /// Collects the product of [uid]: the goods key, the building and the
  /// XP (product XP × quality). No tree, no drops (helpers and tests).
  static (TownBuild, String, int)? collect(
      PlayerProfile p, TownBuild b, int uid) {
    final a = b.animal(uid);
    if (a == null || a.ready == null || collectBlock(p, a) != null) {
      return null;
    }
    final q = a.ready!;
    final d = a.def.productDef;
    return (
      _with(b, a.copyWith(clearReady: true)),
      animalGoodsKey(d.id, q),
      (d.xp * qualityMult(q)).round(),
    );
  }

  /// [p] picks up everything [uid] left (animals.md § 4.2, § 9, § 10):
  /// the product (if [p] has its tool; Ojo de pastor may raise its
  /// quality and the second sub-path may double it), the drops on the
  /// floor and, shearing a sheep with `woolHearts` hearts, fine wool.
  static AnimalPickup? collectBy(
      PlayerProfile p, TownBuild b, int uid, double Function() rand) {
    final a = b.animal(uid);
    if (a == null || collectBlock(p, a) != null) return null;
    final goods = <String>[];
    final parts = <String>[];
    var xp = 0;
    var next = a.copyWith(drops: const []);
    final tool = a.def.tool;
    final q0 = a.ready;
    if (q0 != null && (tool == null || p.life.farm.hasTool(tool))) {
      final bonus = bonusOf(p);
      final q = bump(q0, bonus.quality, rand());
      final d = a.def.productDef;
      final n =
          rand() < LifeTreeRules.farm(p, LifeFx.animalDouble) ? 2 : 1;
      for (var i = 0; i < n; i++) {
        goods.add(animalGoodsKey(d.id, q));
      }
      xp += (d.xp * qualityMult(q)).round() * n;
      next = next.copyWith(clearReady: true);
      if (a.def.parts.contains(AnimalPart.wool) &&
          a.hearts >= t.i('woolHearts') &&
          rand() < partChance(a.hearts, bonus.part)) {
        parts.add(_part(a.def, AnimalPart.wool, a.hearts, bonus.quality, rand));
      }
    }
    for (final x in a.drops) {
      if (parseAnimalPart(x) != null) {
        parts.add(x);
      } else {
        goods.add(x);
      }
    }
    return (build: _with(b, next), goods: goods, parts: parts, xp: xp);
  }

  /// XP left under the daily cap: [used] XP already earned today
  /// (`xpDayCap` 0 = no cap).
  static int capXp(int used, int xp) {
    final cap = t.i('xpDayCap');
    if (cap <= 0) return math.max(0, xp);
    return math.max(0, math.min(xp, cap - used));
  }

  /// Grants [xp] Granjero XP with the tree's XP bonus (like a harvest).
  static PlayerProfile grantXp(PlayerProfile p, int xp) =>
      _xp(p, (xp * (1 + LifeTreeRules.farm(p, LifeFx.xp))).round());

  /// The world day turned to [day] (animals.md § 4.2): what happened on
  /// `day − 1` makes the product, the floor drops (§ 9, § 10) and the
  /// affection decay. [rand] rolls; [bonus] = the best ANIMALES tree of
  /// the players in town.
  static TownBuild onDay(TownBuild b, int day, double Function() rand,
      {AnimalBonus bonus = kNoAnimalBonus}) {
    if (!b.kind.ranch || b.animals.isEmpty) return b;
    final y = day - 1;
    return b.copyWith(animals: [
      for (final a in b.animals) _dayOf(a, y, rand, bonus),
    ]);
  }

  static FarmAnimal _dayOf(
      FarmAnimal a, int y, double Function() rand, AnimalBonus bonus) {
    var aff = a.aff;
    var cycle = a.cycle;
    var ready = a.ready;
    final drops = [...a.drops];
    void drop(String x) {
      if (drops.length < kMaxAnimalDrops) drops.add(x);
    }

    final h = hearts(aff);
    if (a.fed == y) {
      cycle++;
      if (cycle >= a.def.every) {
        cycle = 0;
        ready ??= roll(rand(), h);
        // § 10: at full hearts, sometimes a legendary product.
        if (h >= maxHearts && rand() < legendChance(bonus.legend)) {
          drop(animalGoodsKey(a.def.legend, CropQuality.legendario));
        }
      }
      // § 9: a fed animal sheds on the floor of its home.
      if (floorPart(a.def) case final part?) {
        if (rand() < partChance(h, bonus.part)) {
          drop(_part(a.def, part, h, bonus.quality, rand));
        }
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
        ready: ready,
        drops: drops);
  }

  /// Puts every bale of [p]'s bag into the store of [id] (up to
  /// [siloMax] of [p]).
  static (PlayerProfile, TownState)? depositHay(
      PlayerProfile p, TownState s, String id) {
    final b = s.build(id);
    if (b == null || !b.kind.ranch) return null;
    final room = math.max(0, siloMax(p) - b.hay);
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
  /// (capped) and collects the product to the chest. The drops stay on
  /// the floor for the players (§ 9). [addToChest] adds a key.
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
    if (tool.machine && FarmingRules.level(p) < t.i('machineLevel')) {
      return 'Necesitás Granjero nivel ${t.i('machineLevel')}';
    }
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
  /// Legendary products are never sold (§ 10).
  static ({PlayerProfile profile, int sold, int gold})? sell(
      PlayerProfile p, String? key) {
    final f = p.life.farm;
    final keys = key == null ? f.goods.keys.toList() : [key];
    var sold = 0, gold = 0;
    final goods = {...f.goods};
    for (final k in keys) {
      final n = goods[k] ?? 0;
      final pk = parseAnimalGoodsKey(k);
      if (n <= 0 || pk == null || pk.$1.legend) continue;
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

  // ---------------- machines (§ 11) ----------------

  /// Why [p] cannot put [key] through its machine (`null` = can).
  static MachineBlock? cannotProcess(PlayerProfile p, String key, int n) {
    final pk = parseAnimalGoodsKey(key);
    final out = pk == null ? null : processedOf(pk.$1.id);
    if (out == null) return MachineBlock.notProcessable;
    if (!p.life.farm.hasTool(machineFor(out)!)) return MachineBlock.noMachine;
    if (FarmingRules.level(p) < t.i('machineLevel')) return MachineBlock.level;
    if (n <= 0 || p.life.farm.goodsCount(key) < n) return MachineBlock.nothing;
    return null;
  }

  /// The bag key a machine makes from [key] (same quality).
  static String? processedKey(String key) {
    final pk = parseAnimalGoodsKey(key);
    final out = pk == null ? null : processedOf(pk.$1.id);
    return out == null ? null : animalGoodsKey(out.id, pk!.$2);
  }

  /// [n] of [key] through the machine: the profile and the XP.
  static (PlayerProfile, int)? process(PlayerProfile p, String key, int n) {
    if (cannotProcess(p, key, n) != null) return null;
    final f = p.life.farm;
    final out = processedKey(key)!;
    final goods = {...f.goods, key: f.goodsCount(key) - n};
    goods[out] = (goods[out] ?? 0) + n;
    return (
      p.copyWith(life: p.life.copyWith(farm: f.copyWith(goods: goods))),
      t.i('processXp') * n,
    );
  }

  /// Construction id of a ranch kind (palette and tests).
  static String constructionOf(BuildKind k) =>
      kConstructions.firstWhere((c) => c.kind == k).id;
}
