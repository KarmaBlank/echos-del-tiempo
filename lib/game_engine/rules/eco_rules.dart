import 'dart:math' as math;

import '../data/tuning_catalog.dart';
import '../data/eco_catalog.dart';
import '../data/game_catalog.dart';
import '../models/atlas.dart';
import '../models/battle_state.dart';
import '../models/eco.dart';
import '../models/item.dart';
import '../models/loot.dart';
import '../models/mission_def.dart';
import '../models/player_profile.dart';
import '../models/status.dart';
import '../models/zone_def.dart';
import 'battle_engine.dart' show RandomSource;
import 'inventory_rules.dart';
import 'js_math.dart';
import 'loot_rules.dart';

/// Resultado de un crafteo de Eco: el perfil nuevo o el motivo.
class EcoCraftResult {
  const EcoCraftResult(PlayerProfile this.profile, EcoItem this.after)
      : error = null;
  const EcoCraftResult.fail(String this.error)
      : profile = null,
        after = null;

  final PlayerProfile? profile;
  final EcoItem? after;
  final String? error;

  bool get ok => error == null;
}

/// Bonus de loot de un Eco (fracciones: 0.34 = +34%).
typedef EcoBonus = ({double quantity, double rarity});

/// Reglas de los Ecos (docs/specs/ecos_atlas.md): generación, drops,
/// mazmorra, batalla, loot y crafteo. Puras.
class EcoRules {
  const EcoRules({this.catalog = GameCatalog.standard});

  final GameCatalog catalog;

  /// `missionId` de las misiones de Eco (votación, preparación, sesión).
  static const missionId = 'eco';

  /// Nivel de monstruo desde el que caen Ecos (§ 3).
  static const dropMinLevel = 45;

  /// Bonus de cantidad por jugador extra (§ 7).
  static double get partyQuantity => tuning(TuningId.ecoTier).d('partyQuantity');

  /// Bonus de cantidad por tier sobre T1 (materials_economy.md § 4.4):
  /// el riesgo alto paga (T8 +21%, T16 +45%).
  static double get tierQuantity => tuning(TuningId.ecoTier).d('tierQuantity');

  /// Cantidad que suma el tier de [e].
  static double tierBonus(EcoItem e) =>
      tierQuantity * math.max(0, e.tier - EcoItem.minTier);

  // ------------------------------------------------------------------
  // Texto
  // ------------------------------------------------------------------

  ZoneDef? zoneOf(EcoItem e) => catalog.zone(e.zone);
  ZoneDef? bossZoneOf(EcoItem e) => catalog.zone(e.boss);

  /// `Eco de Bosque Hondo · T5` (o el nombre generado).
  String displayName(EcoItem e) => e.name ?? 'Eco de ${zoneOf(e)?.name ?? '?'}';

  String fullName(EcoItem e) => '${displayName(e)} · T${e.tier}';

  String bossName(EcoItem e) => bossZoneOf(e)?.bossName ?? '?';

  /// Texto de un mod tirado (con Templado si [tempered] > 0).
  static String modText(EcoModRoll m) => kEcoMods[m.id]?.text(m.value) ?? m.id;

  // ------------------------------------------------------------------
  // Bonus de loot (§ 2.2)
  // ------------------------------------------------------------------

  /// Cantidad y rareza que suman los mods (con Potencia).
  static EcoBonus modBonus(EcoItem e, {double modPower = 0}) {
    var q = 0, r = 0;
    for (final m in e.mods) {
      final d = kEcoMods[m.id];
      if (d == null) continue;
      q += d.quantity;
      r += d.rarity;
    }
    final k = 1 + modPower;
    return (quantity: q / 100 * k, rarity: r / 100 * k);
  }

  /// Bonus total dentro del Eco: mods + tier ([tierBonus]) + Atlas + 10%
  /// por jugador extra.
  static EcoBonus lootBonus(EcoItem e,
      {AtlasEffects atlas = AtlasEffects.none, int players = 1}) {
    final m = modBonus(e, modPower: atlas.modPower);
    return (
      quantity: m.quantity +
          tierBonus(e) +
          atlas.quantity +
          partyQuantity * math.max(0, players - 1),
      rarity: m.rarity + atlas.rarity,
    );
  }

  /// Cuántas veces se repite una tirada de loot con cantidad [q]:
  /// `⌊1 + q⌋` y una más con probabilidad `frac(1 + q)`.
  static int rollRepeats(RandomSource rng, double q) {
    final t = 1 + math.max(0.0, q);
    final n = t.floor();
    final frac = t - n;
    return frac > 0 && rng() < frac ? n + 1 : n;
  }

  // ------------------------------------------------------------------
  // Generación (§ 2, § 3)
  // ------------------------------------------------------------------

  static int _pick(RandomSource rng, int n) =>
      (rng() * n).floor().clamp(0, n - 1);

  /// Tipo de zona: peso 1 cada una; las del Atlas ×3.
  int rollZone(RandomSource rng, {AtlasEffects atlas = AtlasEffects.none}) {
    final zones = [for (final z in catalog.zones) z.index];
    return LootRules.pickWeighted<int>(
            rng, zones, (z) => atlas.zones.contains(z) ? 3.0 : 1.0) ??
        1;
  }

  /// [n] mods distintos que no estén en [exclude].
  static List<EcoModRoll> rollMods(RandomSource rng, int n,
      {Iterable<String> exclude = const []}) {
    final pool = [
      for (final d in kEcoMods.values)
        if (!exclude.contains(d.id)) d
    ];
    final out = <EcoModRoll>[];
    for (var i = 0; i < n && pool.isNotEmpty; i++) {
      final d = pool.removeAt(_pick(rng, pool.length));
      out.add(EcoModRoll(d.id, LootRules.rollValue(rng, d.min, d.max)));
    }
    return out;
  }

  static String rareName(RandomSource rng) =>
      '${kEcoNamesA[_pick(rng, kEcoNamesA.length)]} '
      '${kEcoNamesB[_pick(rng, kEcoNamesB.length)]}';

  /// Un Eco nuevo de [tier]. Sin [rarity] la tira como las armas.
  EcoItem generate(
    RandomSource rng, {
    required int tier,
    Rarity? rarity,
    LootSource source = LootSource.battle,
    AtlasEffects atlas = AtlasEffects.none,
    String uid = LootRules.newUid,
  }) {
    final r =
        rarity ?? const LootRules()
            .rollRarity(rng, LootRules.maxLevel, source, eco: true);
    final zone = rollZone(rng, atlas: atlas);
    final boss = catalog.zones[_pick(rng, catalog.zones.length)].index;
    final floors = 1 + _pick(rng, EcoItem.maxFloors);
    final seed = (rng() * 1000000000).floor();
    final mods = rollMods(rng, ecoModRange(r).$1);
    return EcoItem(
      uid: uid,
      tier: tier.clamp(EcoItem.minTier, EcoItem.maxTier),
      zone: zone,
      boss: boss,
      rarity: r,
      mods: mods,
      floors: floors,
      seed: seed,
      name: r.index >= Rarity.raro.index ? rareName(rng) : null,
    );
  }

  /// Chance base de que caiga un Eco por fuente.
  static double dropChance(LootSource s) => switch (s) {
        LootSource.battle => 0.02,
        LootSource.chest => 0.04,
        LootSource.elite => 0.10,
        LootSource.boss => 0.30,
        LootSource.mission => 0.0,
      };

  /// Tier de un Eco que cae dentro de [current] (o 1 fuera de un Eco):
  /// 70% igual, 20% +1, 10% −1.
  static int dropTier(RandomSource rng, EcoItem? current) {
    if (current == null) return 1;
    final r = rng();
    final t = r < 0.70
        ? current.tier
        : r < 0.90
            ? current.tier + 1
            : current.tier - 1;
    return t.clamp(EcoItem.minTier, EcoItem.maxTier);
  }

  /// Un Eco que cae de [source] con enemigos de nivel [level], o `null`.
  EcoItem? rollDrop(RandomSource rng,
      {required int level,
      required LootSource source,
      EcoItem? current,
      AtlasEffects atlas = AtlasEffects.none}) {
    if (level < dropMinLevel) return null;
    final c = dropChance(source) * (1 + atlas.ecoDrop);
    if (c <= 0 || rng() >= c) return null;
    return generate(rng,
        tier: dropTier(rng, current), source: source, atlas: atlas);
  }

  /// Chance de Ancla Temporal por fuente (solo dentro de Ecos).
  static double anchorChance(LootSource s) => switch (s) {
        LootSource.battle => 0.03,
        LootSource.chest => 0.06,
        LootSource.elite => 0.12,
        LootSource.boss => 0.40,
        LootSource.mission => 0.25,
      };

  static bool rollAnchor(RandomSource rng, LootSource s,
          {AtlasEffects atlas = AtlasEffects.none}) =>
      rng() < math.min(0.95, anchorChance(s) * (1 + atlas.anchor));

  /// Lo que deja el fin de un Eco completado a un jugador: 1 Eco (65%
  /// mismo tier, 35% +1) y, con Resonancia, chance de otro.
  List<EcoItem> completionDrops(RandomSource rng, EcoItem done,
      {AtlasEffects atlas = AtlasEffects.none}) {
    EcoItem one() {
      final up = rng() < 0.35 + atlas.tierUp;
      return generate(rng,
          tier: done.tier + (up ? 1 : 0),
          source: LootSource.mission,
          atlas: atlas);
    }

    return [
      one(),
      if (atlas.extraEco > 0 && rng() < atlas.extraEco) one(),
    ];
  }

  /// Agrega [n] mods gratis (Atlas) al Eco que se abre (no al objeto).
  static EcoItem withFreeMods(RandomSource rng, EcoItem e, int n) => n <= 0
      ? e
      : e.copyWith(mods: [
          ...e.mods,
          ...rollMods(rng, n, exclude: [for (final m in e.mods) m.id]),
        ]);

  /// Deja un Eco válido: mods conocidos, sin repetir, con su valor en
  /// rango y hasta el tope de su rareza + 2 (los gratis no se guardan).
  static EcoItem sanitize(EcoItem e) {
    final seen = <String>{};
    final mods = [
      for (final m in e.mods)
        if (kEcoMods[m.id] case final d? when seen.add(m.id))
          EcoModRoll(m.id, m.value.clamp(d.min, d.max)),
    ];
    final cap = ecoModRange(e.rarity).$2;
    return e.copyWith(mods: mods.length > cap ? mods.sublist(0, cap) : mods);
  }

  // ------------------------------------------------------------------
  // Mazmorra (§ 4)
  // ------------------------------------------------------------------

  /// La zona sintética del Eco: generador y tema de su zona, pisos del
  /// Eco, todo al nivel de monstruo del tier.
  ZoneDef zoneDef(EcoItem e) {
    final z = zoneOf(e) ?? catalog.zones.first;
    final b = bossZoneOf(e) ?? z;
    final l = e.monsterLevel;
    return ZoneDef(
      index: z.index,
      id: 'eco',
      name: z.name,
      gen: z.gen,
      minLevel: l,
      maxLevel: l,
      floors: e.floors.clamp(1, EcoItem.maxFloors),
      bossId: b.bossId,
      bossName: b.bossName,
      theme: z.theme,
      missionId: missionId,
    );
  }

  /// La misión del Eco: grupos del último piso de la misión de su zona y
  /// el grupo del jefe de la misión de la zona del jefe.
  MissionDef missionDef(EcoItem e) {
    final z = zoneDef(e);
    final zm =
        catalog.mission(zoneOf(e)?.missionId ?? '') ?? catalog.missions.first;
    final bm = catalog.mission(bossZoneOf(e)?.missionId ?? '') ?? zm;
    return MissionDef(
      id: missionId,
      name: fullName(e),
      type: 'Eco',
      rank: 'A',
      recommendedLevel: 50,
      theme: z.theme,
      goal: 4 * z.floors,
      groups: zm.groupsFor(zm.floors - 1),
      boss: bm.boss,
      sTime: 300 * z.floors,
      elite: zm.elite,
      extra: 0,
      zone: z.index,
      floors: z.floors,
      floorGoal: 4 + e.modValue('horda'),
    );
  }

  // ------------------------------------------------------------------
  // Batalla (§ 2.1)
  // ------------------------------------------------------------------

  /// Aplica los mods a una batalla recién creada (después de
  /// `ZoneRules.scaleBattle`). Muta [state].
  static void applyBattle(BattleState state, EcoItem e,
      {AtlasEffects atlas = AtlasEffects.none, bool boss = false}) {
    final k = 1 - atlas.tempered.clamp(0.0, 0.9);
    double pct(String id) => e.modValue(id) / 100 * k;
    final hp = pct('vida'), atk = pct('furia'), spd = pct('prisa');
    final brk = pct('coraza'), tyrant = pct('tirano');
    final burn = e.modValue('brasas');
    for (final en in state.enemies) {
      final hf = 1 + hp + (boss && en.boss ? tyrant : 0);
      if (hf != 1) {
        final v = math.max(1, jsRound(en.maxHp * hf));
        en
          ..maxHp = v
          ..hp = v;
      }
      if (atk > 0) en.attack = jsRound(en.attack * (1 + atk));
      if (spd > 0) en.speed = en.speed * (1 + spd);
      if (brk > 0) en.breakBase = en.breakBase * (1 + brk);
      if (burn > 0 && en.inflicts == null) {
        en.inflicts = StatusApplication(StatusKind.burn, burn, chance: 0.3);
      }
    }
    final heal = pct('herida');
    if (heal > 0) {
      for (final c in state.party) {
        c.healReceived -= heal;
      }
    }
  }

  /// Sin regeneración del campo (`sequia`).
  static bool noRegen(EcoItem e) => e.hasMod('sequia');

  // ------------------------------------------------------------------
  // Crafteo (§ 4.1)
  // ------------------------------------------------------------------

  /// Prismas para subir de [r] a la siguiente (hasta Épico).
  static int? prismCost(Rarity r) => switch (r) {
        Rarity.comun => 1,
        Rarity.magico => 2,
        Rarity.raro => 4,
        _ => null,
      };

  /// Material y cantidad que pide [op] sobre [e], o `null` si no se puede.
  static (CraftMaterial, int)? cost(EcoItem e, EcoCraftOp op) => switch (op) {
        EcoCraftOp.reroll => (CraftMaterial.esquirla, 1),
        EcoCraftOp.addMod => (CraftMaterial.cristal, 1),
        EcoCraftOp.rarity => switch (prismCost(e.rarity)) {
            final n? => (CraftMaterial.prisma, n),
            null => null,
          },
        EcoCraftOp.tier => (CraftMaterial.ancla, 1),
      };

  /// Por qué no se puede [op] sobre [e] (sin mirar materiales).
  static String? blocked(EcoItem e, EcoCraftOp op) => switch (op) {
        EcoCraftOp.reroll => e.mods.isEmpty ? 'No tiene modificadores' : null,
        EcoCraftOp.addMod => e.mods.length >= ecoModRange(e.rarity).$2
            ? 'Máximo de modificadores'
            : null,
        EcoCraftOp.rarity =>
          prismCost(e.rarity) == null ? 'Rareza máxima (Épico)' : null,
        EcoCraftOp.tier =>
          e.tier >= EcoItem.maxTier ? 'Tier máximo (16)' : null,
      };

  /// Por qué [p] no puede [op] sobre el Eco [uid], o `null`.
  static String? cannotCraft(PlayerProfile p, String uid, EcoCraftOp op) {
    final e = p.ecoByUid(uid);
    if (e == null) return 'No tienes ese Eco';
    final b = blocked(e, op);
    if (b != null) return b;
    final c = cost(e, op)!;
    if (p.material(c.$1) < c.$2) return 'Falta ${c.$1.label}';
    return null;
  }

  /// Aplica el crafteo [op] al Eco [uid] de [p].
  EcoCraftResult craft(
      PlayerProfile p, String uid, EcoCraftOp op, RandomSource rng) {
    final why = cannotCraft(p, uid, op);
    if (why != null) return EcoCraftResult.fail(why);
    final e = p.ecoByUid(uid)!;
    final (mat, n) = cost(e, op)!;
    final EcoItem after;
    switch (op) {
      case EcoCraftOp.reroll:
        after = e.copyWith(mods: rollMods(rng, e.mods.length));
      case EcoCraftOp.addMod:
        after = e.copyWith(mods: [
          ...e.mods,
          ...rollMods(rng, 1, exclude: [for (final m in e.mods) m.id]),
        ]);
      case EcoCraftOp.rarity:
        final r = Rarity.values[e.rarity.index + 1];
        final need = math.max(0, ecoModRange(r).$1 - e.mods.length);
        after = e.copyWith(
          rarity: r,
          mods: [
            ...e.mods,
            ...rollMods(rng, need, exclude: [for (final m in e.mods) m.id]),
          ],
          name: e.name ?? (r.index >= Rarity.raro.index ? rareName(rng) : null),
        );
      case EcoCraftOp.tier:
        after = e.copyWith(tier: e.tier + 1);
    }
    final paid =
        p.copyWith(materials: {...p.materials, mat: p.material(mat) - n});
    return EcoCraftResult(
        InventoryRules.relayout(InventoryRules.replaceEco(paid, after)), after);
  }

  // ------------------------------------------------------------------
  // Fusión (§ 4.2)
  // ------------------------------------------------------------------

  /// Ecos del mismo tier que pide una fusión (Balance, mínimo 2).
  static int get fuseCount =>
      math.max(2, tuning(TuningId.ecoTier).i('fuseCount'));

  /// Anclas Temporales extra que cuesta una fusión (Balance, 0 = gratis).
  static int get fuseAnchors =>
      math.max(0, tuning(TuningId.ecoTier).i('fuseAnchors'));

  /// Qué saldría de fusionar [ecos] (sin tirar nada): tier + 1, la mayor
  /// rareza y la zona (una sola si coinciden; si no, una al azar de estas).
  static EcoFusePreview fusePreview(List<EcoItem> ecos) {
    var r = Rarity.comun;
    for (final e in ecos) {
      if (e.rarity.index > r.index) r = e.rarity;
    }
    final zones = <int>[];
    for (final e in ecos) {
      if (!zones.contains(e.zone)) zones.add(e.zone);
    }
    final tier = ecos.isEmpty ? EcoItem.minTier : ecos.first.tier + 1;
    return EcoFusePreview(
        tier: tier.clamp(EcoItem.minTier, EcoItem.maxTier),
        rarity: r,
        zones: zones);
  }

  /// Por qué [p] no puede fusionar los Ecos [uids], o `null`.
  static EcoFuseBlock? cannotFuse(PlayerProfile p, List<String> uids) {
    if (uids.length != fuseCount) return EcoFuseBlock.count;
    if (uids.toSet().length != uids.length) return EcoFuseBlock.duplicate;
    final ecos = <EcoItem>[];
    for (final u in uids) {
      final e = p.ecoByUid(u);
      if (e == null) return EcoFuseBlock.missing;
      ecos.add(e);
    }
    if (ecos.any((e) => e.tier != ecos.first.tier)) {
      return EcoFuseBlock.mixedTier;
    }
    if (ecos.first.tier >= EcoItem.maxTier) return EcoFuseBlock.maxTier;
    if (p.material(CraftMaterial.ancla) < fuseAnchors) {
      return EcoFuseBlock.material;
    }
    return null;
  }

  /// Fusiona los Ecos [uids] de [p] en uno de tier + 1 (§ 4.2). El
  /// resultado es un Eco nuevo (uid nuevo) generado como un drop de la
  /// rareza mayor: mods recién tirados hasta el mínimo de esa rareza.
  EcoCraftResult fuse(PlayerProfile p, List<String> uids, RandomSource rng) {
    final why = cannotFuse(p, uids);
    if (why != null) return EcoCraftResult.fail(why.name);
    final ecos = [for (final u in uids) p.ecoByUid(u)!];
    final pre = fusePreview(ecos);
    final zone = pre.zones.length == 1
        ? pre.zones.single
        : pre.zones[_pick(rng, pre.zones.length)];
    final made =
        generate(rng, tier: pre.tier, rarity: pre.rarity).copyWith(zone: zone);
    var next = p;
    for (final u in uids) {
      next = InventoryRules.removeEco(next, u);
    }
    final cost = fuseAnchors;
    if (cost > 0) {
      next = next.copyWith(materials: {
        ...next.materials,
        CraftMaterial.ancla: next.material(CraftMaterial.ancla) - cost,
      });
    }
    final (got, uid) = InventoryRules.addEco(next, made);
    return EcoCraftResult(got, got.ecoByUid(uid)!);
  }
}

/// Lo que saldría de una fusión (§ 4.2).
class EcoFusePreview {
  const EcoFusePreview(
      {required this.tier, required this.rarity, required this.zones});

  final int tier;
  final Rarity rarity;

  /// Una zona: se queda; varias: una al azar de estas.
  final List<int> zones;
}

/// Por qué no se puede fusionar (la UI lo traduce).
enum EcoFuseBlock { count, duplicate, missing, mixedTier, maxTier, material }
