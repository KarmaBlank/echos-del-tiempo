import 'dart:math' as math;

import '../data/climate_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/profession_gear_catalog.dart'
    show kRegrowItem, kRegrowPrefix, kWeaponSeeds;
import '../data/tuning_catalog.dart';
import '../models/farm_plot.dart';
import '../models/item.dart' show CraftMaterial;
import '../models/player_profile.dart';
import 'life_time_rules.dart';
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

  /// Seconds to ripen; a living weapon seed uses `livingGrowSec`
  /// (profession_gear.md § 3.2).
  static double growSec(String crop) =>
      kCrops[crop]?.growSec ??
      (kWeaponSeeds.containsKey(crop) || crop.startsWith(kRegrowPrefix)
          ? tuning(TuningId.gear).d('livingGrowSec')
          : 300);

  /// 0..1 del crecimiento.
  static double ratio(FarmPlot p) =>
      p.seed == null ? 0 : (p.grow / growSec(p.seed!)).clamp(0.0, 1.0);

  static bool ripe(FarmPlot p) => p.seed != null && ratio(p) >= 1;

  /// Ripe and allowed to be picked in [season] (farming.md § 15): winter
  /// crops are only harvested in winter. `null` season = no gate.
  /// What a farm helper may pick (farming.md § 8.2): a harvestable
  /// regular crop. Living weapon plots (`ws_*`, profession_gear.md § 3)
  /// are left for a player: [harvest] has no crop for them.
  static bool helperHarvestable(FarmPlot p, Season? season) =>
      kCrops.containsKey(p.seed) && harvestable(p, season);

  static bool harvestable(FarmPlot p, Season? season) =>
      ripe(p) &&
      (season == null ||
          !(kCropSeasonOverrides[p.seed] ?? kCrops[p.seed]?.seasons ?? kAllSeasons)
              .every((s) => s == Season.winter) ||
          season == Season.winter);

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
  static FarmPlot grow(FarmPlot p, double dt, {double mult = 1}) {
    if (p.seed == null) {
      return p.wet > 0 ? p.copyWith(wet: math.max(0, p.wet - dt)) : p;
    }
    if (ripe(p)) return p.wet > 0 ? p.copyWith(wet: 0) : p;
    final wet = p.wet > 0;
    final rate = (wet ? p.waterRate : t.d('dryRate')) *
        fertSpeed(p.fert) *
        (1 + p.boost) *
        mult;
    final g = dt * rate;
    return p.copyWith(
        grow: p.grow + g,
        wetGrow: wet ? p.wetGrow + g : p.wetGrow,
        wet: math.max(0, p.wet - dt));
  }

  /// A planted, unripe crop that does not grow at all with growth
  /// multiplier [mult] (`LifeTimeRules.cropGrowth`; 0 = out of season,
  /// farming.md § 15). The plot tooltip explains it.
  static bool growthPaused(FarmPlot p, double mult) =>
      p.planted && !ripe(p) && mult <= 0;

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

  /// La lluvia (day_night_weather.md § 3.2): mientras llueve lo plantado
  /// sin madurar queda regado a ritmo pleno, sin tocar la calidad de los
  /// riegos de la gente.
  static FarmPlot rain(FarmPlot p) {
    if (!p.planted || ripe(p) || p.wet >= 3) return p;
    return p.copyWith(wet: 5, waterRate: 1, waterer: 'Lluvia');
  }

  static FarmPlot? fertilize(FarmPlot p, String fert, PlayerProfile who) =>
      p.seed == null || p.fert != null || !kFertilizers.containsKey(fert)
          ? null
          : p.copyWith(fert: fert, fertBy: who.name);

  // ---------------- cosecha ----------------

  /// Puntaje S de la cosecha si la levanta [harvester]: lo que puso quien
  /// plantó, los riegos, el abono y (lo que más pesa) quien cosecha.
  static double score(PlayerProfile harvester, FarmPlot plot,
      {double bias = 0}) {
    final wetFrac =
        plot.grow <= 0 ? 0.0 : (plot.wetGrow / plot.grow).clamp(0.0, 1.0);
    return math.max(
        0,
        plot.potential * t.d('sPlant') +
            plot.waterQ * wetFrac * t.d('sWater') +
            fertBias(plot.fert) +
            bias +
            personScore(harvester, hoeOf(harvester)) * t.d('sHarvest'));
  }

  /// Chances de cada calidad si cosecha [harvester] (suman 1).
  static Map<CropQuality, double> odds(PlayerProfile harvester, FarmPlot plot,
      {double bias = 0}) {
    final s = score(harvester, plot, bias: bias);
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
      PlayerProfile harvester, FarmPlot plot, double roll,
      {double bias = 0}) {
    var x = roll.clamp(0.0, 0.999999);
    for (final e in odds(harvester, plot, bias: bias).entries) {
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
      {bool helper = false, double bias = 0}) {
    if (!ripe(plot)) return null;
    // Living weapons are harvested by GearRules (profession_gear.md § 3).
    final crop = kCrops[plot.seed];
    if (crop == null) return null;
    final q = helper ? CropQuality.normal : quality(p, plot, rand(), bias: bias);
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
      // Solo las del pueblo: las de cada bioma salen de su exterior
      // (overworld_biomes.md § 3.3).
      for (final c in kCrops.values)
        if (c.biome == kFarmStartBiome &&
            (c.rarity == FishRarity.raro || c.rarity == FishRarity.epico))
          c.id
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

  // ---------------- agropecuario ----------------

  /// [season]: the season now (farming.md § 16: seasonal crops in their
  /// season sell × `seasonPriceMult`).
  static int unitPrice(PlayerProfile p, CropDef c, CropQuality q,
          [Season? season]) =>
      (c.price *
              t.d('qualityMult${q.key}') *
              (season == null ? 1 : LifeTimeRules.seasonPrice(c.id, season)) *
              (1 + LifeTreeRules.farm(p, LifeFx.sell)))
          .round();

  /// Vende [key] (todas), o con `key == null` todo menos los legendarios.
  static CropSale? sell(PlayerProfile p,
      {String? key, bool materials = false, Season? season}) {
    final f = p.life.farm;
    final bag = {...f.crops};
    var value = 0, sold = 0;
    void take(String k, int n) {
      final c = parseCropKey(k);
      if (c == null || n <= 0) return;
      bag[k] = (bag[k] ?? 0) - n;
      value += unitPrice(p, c.$1, c.$2, season) * n;
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

  /// [price]: precio del habitante de bioma (overworld_biomes.md § 9.1)
  /// para semillas que el agropecuario no vende.
  static PlayerProfile? buySeed(PlayerProfile p, String crop,
      [int n = 1, int? price]) {
    final c = kCrops[crop];
    final unit = price ?? c?.seedPrice ?? 0;
    if (c == null || unit <= 0 || n <= 0) return null;
    final cost = unit * n;
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

  /// What [p] can plant, in carousel order: crop seeds, weapon seeds and
  /// the living weapons of the bag to replant (`item:<uid>`,
  /// profession_gear.md § 3.5; the equipped one stays out).
  static List<String> plantables(PlayerProfile p) {
    final f = p.life.farm;
    return [
      for (final c in kCrops.keys)
        if (f.seedCount(c) > 0) c,
      for (final w in kWeaponSeeds.keys)
        if (f.wseedCount(w) > 0) w,
      for (final i in p.items)
        if (i.uid.startsWith('gear-vivo_') && i.uid != p.equippedUid)
          '$kRegrowItem${i.uid}',
    ];
  }

  /// The seed [p] plants with: the chosen one while it lasts, else the
  /// first plantable.
  static String? activeSeed(PlayerProfile p) {
    final have = plantables(p);
    final s = p.life.farm.seed;
    if (s != null && have.contains(s)) return s;
    return have.firstOrNull;
  }

  static PlayerProfile? selectSeed(PlayerProfile p, String crop) {
    final f = p.life.farm;
    if (!plantables(p).contains(crop) || f.seed == crop) return null;
    return p.copyWith(life: p.life.copyWith(farm: f.copyWith(seed: crop)));
  }

  /// La semilla siguiente de las que tiene (para la tecla Q).
  static String? nextSeed(PlayerProfile p) {
    final have = plantables(p);
    if (have.isEmpty) return null;
    final i = have.indexOf(activeSeed(p) ?? '');
    return have[(i + 1) % have.length];
  }

  /// La semilla anterior a la elegida (carrusel del HUD, farming.md § 4).
  static String? prevSeed(PlayerProfile p) {
    final have = plantables(p);
    if (have.isEmpty) return null;
    final i = have.indexOf(activeSeed(p) ?? '');
    return have[(i <= 0 ? have.length : i) - 1];
  }
}
