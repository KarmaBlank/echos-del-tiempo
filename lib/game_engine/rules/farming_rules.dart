import 'dart:math' as math;

import '../data/farming_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/farm_plot.dart';
import '../models/item.dart' show CraftMaterial;
import '../models/player_profile.dart';
import 'life_tree_rules.dart';

export '../data/farming_catalog.dart';
export '../models/farm_plot.dart';

/// Etapa visible de una parcela (farming.md § 2.3).
enum CropStage { arada, semilla, brote, crecido, maduro }

/// Qué sale de una cosecha además del cultivo (farming.md § 5).
enum FarmLootKind { none, semilla, materiales, legendaria }

/// Una cosecha: cultivo, calidad, cantidad y el hallazgo.
typedef Harvest = ({
  CropDef crop,
  CropQuality quality,
  int count,
  int seeds,
  FarmLootKind loot,
});

/// Resultado de vender cosechas.
typedef CropSale = ({PlayerProfile profile, int credits, int esquirlas, int sold});

/// Reglas de Cultivo y de la huerta (docs/specs/farming.md). Puras: los
/// números salen de `kTuning[TuningId.farming]` (Editor → Balance →
/// Cultivo).
abstract final class FarmingRules {
  static TuningDef get t => tuning(TuningId.farming);

  // ---------------- nivel ----------------

  static int get maxLevel => t.i('maxLevel');

  static int xpNeed(int l) =>
      math.max(1, (t.d('xpBase') * math.pow(l, t.d('xpExp'))).round());

  static int levelFor(int xp) {
    var l = 1, rest = xp;
    while (l < maxLevel && rest >= xpNeed(l)) {
      rest -= xpNeed(l);
      l++;
    }
    return l;
  }

  static int level(PlayerProfile p) => levelFor(p.life.farm.xp);

  static (int, int) progress(int xp) {
    var l = 1, rest = xp;
    while (l < maxLevel && rest >= xpNeed(l)) {
      rest -= xpNeed(l);
      l++;
    }
    return l >= maxLevel ? (0, 0) : (rest, xpNeed(l));
  }

  // ---------------- herramientas ----------------

  static double effectiveness(int level, int reqLevel) {
    final ratio = (level / math.max(1, reqLevel)).clamp(0.0, 1.0);
    final floor = t.d('bonusFloor').clamp(0.0, 1.0);
    return floor + (1 - floor) * math.pow(ratio, t.d('bonusCurve'));
  }

  static FarmToolDef hoeOf(PlayerProfile p) =>
      kFarmTools[p.life.farm.hoe] ?? kFarmTools[kStarterHoe]!;
  static FarmToolDef canOf(PlayerProfile p) =>
      kFarmTools[p.life.farm.can] ?? kFarmTools[kStarterCan]!;

  /// Bonus efectivos de una herramienta con el nivel de [p].
  static ({double quality, int area, double extra}) toolBonus(
      PlayerProfile p, FarmToolDef d) {
    final k = effectiveness(level(p), d.reqLevel);
    return (
      quality: d.quality * k,
      area: (d.area * k + 1e-6).floor(),
      extra: d.extra * k,
    );
  }

  /// Tiles que alcanza una labor con área [area] en (tx, ty).
  static List<(int, int)> areaTiles(int tx, int ty, int area) => [
        (tx, ty),
        if (area >= 1) ...[
          (tx + 1, ty),
          (tx - 1, ty),
          (tx, ty + 1),
          (tx, ty - 1),
        ],
        if (area >= 2) ...[
          (tx + 1, ty + 1),
          (tx - 1, ty - 1),
          (tx + 1, ty - 1),
          (tx - 1, ty + 1),
        ],
      ];

  // ---------------- crecimiento ----------------

  static double growSec(String crop) => kCrops[crop]?.growSec ?? 300;

  /// 0..1 del crecimiento.
  static double ratio(FarmPlot p) =>
      p.seed == null ? 0 : (p.grow / growSec(p.seed!)).clamp(0.0, 1.0);

  static bool ripe(FarmPlot p) => p.seed != null && ratio(p) >= 1;

  static CropStage stage(FarmPlot p) {
    if (p.seed == null) return CropStage.arada;
    final r = ratio(p);
    if (r >= 1) return CropStage.maduro;
    if (r >= 0.55) return CropStage.crecido;
    if (r >= 0.2) return CropStage.brote;
    return CropStage.semilla;
  }

  static double fertSpeed(String? fert) {
    final d = kFertilizers[fert];
    return d == null ? 1.0 : t.d('fert${d.key}Speed');
  }

  static double fertBias(String? fert) {
    final d = kFertilizers[fert];
    return d == null ? 0.0 : t.d('fert${d.key}Bias');
  }

  /// Avanza [dt] segundos (con el árbol de quien plantó, `boost`, y el
  /// ritmo del último riego, `waterRate`).
  static FarmPlot grow(FarmPlot p, double dt) {
    if (p.seed == null) {
      return p.wet > 0 ? p.copyWith(wet: math.max(0, p.wet - dt)) : p;
    }
    if (ripe(p)) return p.wet > 0 ? p.copyWith(wet: 0) : p;
    final wet = p.wet > 0;
    final rate = (wet ? p.waterRate : t.d('dryRate')) *
        fertSpeed(p.fert) *
        (1 + p.boost);
    final g = dt * rate;
    return p.copyWith(
        grow: p.grow + g,
        wetGrow: wet ? p.wetGrow + g : p.wetGrow,
        wet: math.max(0, p.wet - dt));
  }

  /// Misión ganada: cada cultivo suma `missionGrowSec` (regado si lo
  /// estaba al salir).
  static FarmPlot missionGrow(FarmPlot p) {
    if (p.seed == null || ripe(p)) return p;
    final g = t.d('missionGrowSec') * fertSpeed(p.fert);
    return p.copyWith(
        grow: p.grow + g, wetGrow: p.wet > 0 ? p.wetGrow + g : p.wetGrow);
  }

  // ---------------- aportes (farming.md § 2.4) ----------------

  /// Puntaje de una persona con una herramienta: nivel, herramienta y el
  /// «quality» de su árbol.
  static double personScore(PlayerProfile p, FarmToolDef tool) =>
      t.d('pBase') +
      (level(p) - 1) * t.d('pPerLevel') +
      toolBonus(p, tool).quality +
      LifeTreeRules.farm(p, LifeFx.quality);

  // ---------------- labores ----------------

  static FarmPlot till() => const FarmPlot();

  /// Plantar: el potencial sale de quien planta (azada, nivel, árbol).
  static FarmPlot? plant(FarmPlot p, String crop, [PlayerProfile? who]) =>
      p.seed != null || !kCrops.containsKey(crop)
          ? null
          : FarmPlot(
              seed: crop,
              wet: p.wet,
              boost: who == null ? 0 : LifeTreeRules.farm(who, LifeFx.grow),
              potential: who == null ? 0 : personScore(who, hoeOf(who)),
              planter: who?.name);

  /// Ritmo de crecimiento del riego de [who]: un regador de nivel bajo
  /// riega más lento (`waterRateMin` con nivel 1, 1 desde el nivel 10).
  static double waterRate(PlayerProfile who) {
    final min = t.d('waterRateMin').clamp(0.0, 1.0);
    return min + (1 - min) * math.min(1.0, (level(who) - 1) / 9);
  }

  /// Riego con la regadera de [who]: dura según la regadera y el árbol;
  /// el ritmo y la calidad del riego, según su nivel y su regadera.
  static FarmPlot water(FarmPlot p, PlayerProfile who) {
    final can = canOf(who);
    final b = toolBonus(who, can);
    final sec = t.d('waterSec') *
        (1 + b.extra) *
        (1 + LifeTreeRules.farm(who, LifeFx.water));
    final n = p.waterings + 1;
    return p.copyWith(
        wet: math.max(p.wet, sec),
        waterRate: waterRate(who),
        waterQ: (p.waterQ * p.waterings + personScore(who, can)) / n,
        waterings: n,
        waterer: who.name);
  }

  static FarmPlot? fertilize(FarmPlot p, String fert, PlayerProfile who) =>
      p.seed == null || p.fert != null || !kFertilizers.containsKey(fert)
          ? null
          : p.copyWith(fert: fert, fertBy: who.name);

  // ---------------- cosecha ----------------

  /// Puntaje S de la cosecha si la levanta [harvester]: lo que puso quien
  /// plantó, los riegos, el abono y (lo que más pesa) quien cosecha.
  static double score(PlayerProfile harvester, FarmPlot plot) {
    final wetFrac =
        plot.grow <= 0 ? 0.0 : (plot.wetGrow / plot.grow).clamp(0.0, 1.0);
    return math.max(
        0,
        plot.potential * t.d('sPlant') +
            plot.waterQ * wetFrac * t.d('sWater') +
            fertBias(plot.fert) +
            personScore(harvester, hoeOf(harvester)) * t.d('sHarvest'));
  }

  /// Chances de cada calidad si cosecha [harvester] (suman 1).
  static Map<CropQuality, double> odds(PlayerProfile harvester, FarmPlot plot) {
    final s = score(harvester, plot);
    final w = {
      for (final q in CropQuality.values)
        q: t.d('wQ${q.key}') * math.pow(1 + s, q.index).toDouble(),
    };
    final total = w.values.fold(0.0, (a, b) => a + b);
    return {
      for (final e in w.entries) e.key: total <= 0 ? 0.0 : e.value / total
    };
  }

  static CropQuality quality(
      PlayerProfile harvester, FarmPlot plot, double roll) {
    var x = roll.clamp(0.0, 0.999999);
    for (final e in odds(harvester, plot).entries) {
      if (x < e.value) return e.key;
      x -= e.value;
    }
    return CropQuality.normal;
  }

  /// El hallazgo de la cosecha, con los dos pity.
  static FarmLootKind rollLoot(double Function() rand, PlayerProfile p) {
    final f = p.life.farm;
    final legendAfter = t.i('legendPityAfter');
    if (legendAfter > 0 && f.pity >= legendAfter) return FarmLootKind.legendaria;
    final after = t.i('lootPityAfter');
    if (after > 0 && f.dry >= after) {
      return rand() < 0.5 ? FarmLootKind.semilla : FarmLootKind.materiales;
    }
    final lv = t.d('lootLevelBonus') * (level(p) - 1);
    final tree = 1 + LifeTreeRules.farm(p, LifeFx.seed);
    if (rand() >= t.d('lootChance') * (1 + lv) * tree) return FarmLootKind.none;
    final w = {
      FarmLootKind.semilla: t.d('lootSemilla'),
      FarmLootKind.materiales: t.d('lootMateriales'),
      FarmLootKind.legendaria: t.d('lootLegendaria') * (1 + lv),
    };
    final total = w.values.fold(0.0, (a, b) => a + b);
    var x = rand().clamp(0.0, 0.999999) * total;
    for (final e in w.entries) {
      if (x < e.value) return e.key;
      x -= e.value;
    }
    return FarmLootKind.semilla;
  }

  /// La cosecha de [plot] (madura) por [p]. [helper]: la levanta el
  /// ayudante (calidad normal, sin hallazgos).
  static Harvest? harvest(double Function() rand, PlayerProfile p, FarmPlot plot,
      {bool helper = false}) {
    if (!ripe(plot)) return null;
    final crop = kCrops[plot.seed]!;
    final q = helper ? CropQuality.normal : quality(p, plot, rand());
    final extra = helper
        ? 0.0
        : toolBonus(p, hoeOf(p)).extra + LifeTreeRules.farm(p, LifeFx.extra);
    final count = 1 + (rand() < extra ? 1 : 0);
    final seeds = crop.rarity != FishRarity.legendario &&
            rand() < t.d('seedDropChance')
        ? 1
        : 0;
    return (
      crop: crop,
      quality: q,
      count: count,
      seeds: seeds,
      loot: helper ? FarmLootKind.none : rollLoot(rand, p),
    );
  }

  static int cropXp(CropDef c, CropQuality q) => math.max(
      1,
      (c.xp * t.d('xp${c.rarity.key}') * t.d('qualityMult${q.key}')).round());

  static int charXp(CropDef c) => t.i('charXp${c.rarity.key}');

  /// Suma la cosecha a [p] (bolsa, semillas, XP de Cultivo y los pity).
  static PlayerProfile addHarvest(PlayerProfile p, Harvest h, {double xpMult = 1}) {
    var f = p.life.farm.addCrop(cropKey(h.crop.id, h.quality), h.count);
    if (h.seeds > 0) f = f.addSeed(h.crop.id, h.seeds);
    final xp = (cropXp(h.crop, h.quality) *
            xpMult *
            (1 + LifeTreeRules.farm(p, LifeFx.xp)))
        .round();
    f = f.copyWith(
        xp: f.xp + xp,
        pity: h.loot == FarmLootKind.legendaria ? 0 : f.pity + 1,
        dry: h.loot == FarmLootKind.none ? f.dry + 1 : 0);
    return p.copyWith(life: p.life.copyWith(farm: f));
  }

  /// XP chica por una labor (arar, plantar, regar).
  static PlayerProfile workXp(PlayerProfile p) {
    final n = t.i('workXp');
    if (n <= 0) return p;
    final f = p.life.farm;
    return p.copyWith(life: p.life.copyWith(farm: f.copyWith(xp: f.xp + n)));
  }

  /// Una semilla al azar de la rareza [min] o mejor (sin legendarias).
  static String rareSeed(double Function() rand) {
    final pool = [
      for (final c in kCrops.values)
        if (c.rarity == FishRarity.raro || c.rarity == FishRarity.epico) c.id
    ];
    return pool[(rand() * pool.length).floor().clamp(0, pool.length - 1)];
  }

  static String legendarySeed(double Function() rand) {
    final pool = [
      for (final c in kCrops.values)
        if (c.rarity == FishRarity.legendario) c.id
    ];
    return pool[(rand() * pool.length).floor().clamp(0, pool.length - 1)];
  }

  // ---------------- comerciante ----------------

  static int unitPrice(PlayerProfile p, CropDef c, CropQuality q) =>
      (c.price *
              t.d('qualityMult${q.key}') *
              (1 + LifeTreeRules.farm(p, LifeFx.sell)))
          .round();

  /// Vende [key] (todas), o con `key == null` todo menos los legendarios.
  static CropSale? sell(PlayerProfile p, {String? key, bool materials = false}) {
    final f = p.life.farm;
    final bag = {...f.crops};
    var value = 0, sold = 0;
    void take(String k, int n) {
      final c = parseCropKey(k);
      if (c == null || n <= 0) return;
      bag[k] = (bag[k] ?? 0) - n;
      value += unitPrice(p, c.$1, c.$2) * n;
      sold += n;
    }

    if (key == null) {
      for (final e in f.crops.entries) {
        if (parseCropKey(e.key)?.$1.rarity != FishRarity.legendario) {
          take(e.key, e.value);
        }
      }
    } else {
      take(key, f.cropCount(key));
    }
    if (sold == 0) return null;
    var credits = value, esq = 0;
    if (materials) {
      final v = (value * t.d('matRate')).round();
      final per = math.max(1, t.i('matValue'));
      esq = v ~/ per;
      credits = v - esq * per;
    }
    final mats = {...p.materials};
    if (esq > 0) {
      mats[CraftMaterial.esquirla] = (mats[CraftMaterial.esquirla] ?? 0) + esq;
    }
    return (
      profile: p.copyWith(
          credits: p.credits + credits,
          materials: mats,
          life: p.life.copyWith(farm: f.copyWith(crops: bag))),
      credits: credits,
      esquirlas: esq,
      sold: sold,
    );
  }

  /// Canje de una cosecha legendaria (cualquier calidad).
  static PlayerProfile? exchangeLegendary(PlayerProfile p, String key) {
    final c = parseCropKey(key);
    final f = p.life.farm;
    if (c == null || c.$1.rarity != FishRarity.legendario || f.cropCount(key) < 1) {
      return null;
    }
    final mats = {...p.materials};
    mats[CraftMaterial.cristal] =
        (mats[CraftMaterial.cristal] ?? 0) + t.i('legendCristales');
    mats[CraftMaterial.prisma] =
        (mats[CraftMaterial.prisma] ?? 0) + t.i('legendPrismas');
    return p.copyWith(
        materials: mats,
        life: p.life.copyWith(
            farm: f.copyWith(crops: {...f.crops, key: f.cropCount(key) - 1})));
  }

  static PlayerProfile? buySeed(PlayerProfile p, String crop, [int n = 1]) {
    final c = kCrops[crop];
    if (c == null || c.seedPrice <= 0 || n <= 0) return null;
    final cost = c.seedPrice * n;
    if (p.credits < cost) return null;
    return p.copyWith(
        credits: p.credits - cost,
        life: p.life.copyWith(farm: p.life.farm.addSeed(crop, n)));
  }

  static PlayerProfile? buyFert(PlayerProfile p, String id, [int n = 1]) {
    final d = kFertilizers[id];
    if (d == null || n <= 0) return null;
    final cost = d.price * n;
    if (p.credits < cost) return null;
    final f = p.life.farm;
    return p.copyWith(
        credits: p.credits - cost,
        life: p.life.copyWith(
            farm: f.copyWith(ferts: {...f.ferts, id: f.fertCount(id) + n})));
  }

  static PlayerProfile? buyTool(PlayerProfile p, String id) {
    final d = kFarmTools[id];
    final f = p.life.farm;
    if (d == null || d.price <= 0 || p.credits < d.price) return null;
    final owned = d.kind == FarmToolKind.azada ? f.hoes : f.cans;
    if (owned.contains(id)) return null;
    return p.copyWith(
        credits: p.credits - d.price,
        life: p.life.copyWith(
            farm: d.kind == FarmToolKind.azada
                ? f.copyWith(hoes: [...f.hoes, id])
                : f.copyWith(cans: [...f.cans, id])));
  }

  static PlayerProfile? equipTool(PlayerProfile p, String id) {
    final d = kFarmTools[id];
    final f = p.life.farm;
    if (d == null) return null;
    if (d.kind == FarmToolKind.azada) {
      if (!f.hoes.contains(id) || f.hoe == id) return null;
      return p.copyWith(life: p.life.copyWith(farm: f.copyWith(hoe: id)));
    }
    if (!f.cans.contains(id) || f.can == id) return null;
    return p.copyWith(life: p.life.copyWith(farm: f.copyWith(can: id)));
  }

  static PlayerProfile? selectSeed(PlayerProfile p, String crop) {
    final f = p.life.farm;
    if (f.seedCount(crop) <= 0 || f.seed == crop) return null;
    return p.copyWith(life: p.life.copyWith(farm: f.copyWith(seed: crop)));
  }

  /// La semilla siguiente de las que tiene (para la tecla Q).
  static String? nextSeed(PlayerProfile p) {
    final f = p.life.farm;
    final have = [for (final c in kCrops.keys) if (f.seedCount(c) > 0) c];
    if (have.isEmpty) return null;
    final i = have.indexOf(f.activeSeed ?? '');
    return have[(i + 1) % have.length];
  }
}
