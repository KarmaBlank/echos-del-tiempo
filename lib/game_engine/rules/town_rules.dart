import 'dart:math' as math;

import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/item.dart' show CraftMaterial;
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'farming_rules.dart';
import 'life_tree_rules.dart';

/// Costo de una ampliación del pueblo.
typedef ExpansionCost = ({int gold, int esquirlas, int cristales});

/// Reglas del pueblo del mundo (docs/specs/farming.md § 6–8):
/// ampliaciones y sus espacios (LAGO / HUERTA), peces soltados en el lago
/// (capacidad, sesgo de la tabla, cría) y el ayudante de la huerta. Puras;
/// los números en `kTuning[TuningId.town]` (Editor → Balance → Pueblo).
abstract final class TownRules {
  static TuningDef get t => tuning(TuningId.town);

  /// Espacios por ampliación (fijo: cada franja tiene norte y sur).
  static const slotsPerExpansion = 2;

  static int get maxExpansions => t.i('maxExpansions').clamp(0, 4);

  static int slots(TownState s) => s.expansions * slotsPerExpansion;
  static int freeSlots(TownState s) =>
      math.max(0, slots(s) - s.zones.length);

  /// Costo de la ampliación número [n] (1 = la primera).
  static ExpansionCost cost(int n) => (
        gold: (t.d('expGoldBase') * math.pow(t.d('expGoldMult'), n - 1))
            .round(),
        esquirlas: t.i('expEsquirlas') * n,
        cristales: n >= 2 ? t.i('expCristales') * (n - 1) : 0,
      );

  static String costText(ExpansionCost c) => [
        '${c.gold} de oro',
        if (c.esquirlas > 0) '${c.esquirlas} Esquirlas',
        if (c.cristales > 0) '${c.cristales} Cristales de Era',
      ].join(' · ');

  /// Por qué [p] no puede pagar la próxima ampliación (o `null`).
  static String? cannotExpand(PlayerProfile p, TownState s) {
    if (s.expansions >= maxExpansions) return 'El pueblo ya está al máximo';
    if (freeSlots(s) > 0) return 'Primero elegí qué va en el espacio libre';
    final c = cost(s.expansions + 1);
    if (p.credits < c.gold) return 'Falta oro (${p.credits}/${c.gold})';
    final esq = p.materials[CraftMaterial.esquirla] ?? 0;
    if (esq < c.esquirlas) return 'Faltan Esquirlas ($esq/${c.esquirlas})';
    final cr = p.materials[CraftMaterial.cristal] ?? 0;
    if (cr < c.cristales) return 'Faltan Cristales de Era ($cr/${c.cristales})';
    return null;
  }

  static (PlayerProfile, TownState)? expand(PlayerProfile p, TownState s) {
    if (cannotExpand(p, s) != null) return null;
    final c = cost(s.expansions + 1);
    final mats = {...p.materials};
    mats[CraftMaterial.esquirla] =
        (mats[CraftMaterial.esquirla] ?? 0) - c.esquirlas;
    mats[CraftMaterial.cristal] =
        (mats[CraftMaterial.cristal] ?? 0) - c.cristales;
    return (
      p.copyWith(credits: p.credits - c.gold, materials: mats),
      s.copyWith(expansions: s.expansions + 1),
    );
  }

  static TownState? assign(TownState s, TownZoneKind k) =>
      freeSlots(s) <= 0 ? null : s.copyWith(zones: [...s.zones, k]);

  // ---------------- lago ----------------

  static int lakeCapacity(TownState s) =>
      t.i('lakeBase') + t.i('lakePerZone') * s.zoneCount(TownZoneKind.lago);

  /// Suelta un [species] de la bolsa de [p] en el lago.
  static (PlayerProfile, TownState)? stock(
      PlayerProfile p, TownState s, String species) {
    final f = kFish[species];
    if (f == null || f.biome == kWaterJunkBiome || p.life.count(species) < 1) {
      return null;
    }
    if (s.stockTotal >= lakeCapacity(s)) return null;
    return (
      p.copyWith(
          life: p.life
              .copyWith(bag: {...p.life.bag, species: p.life.count(species) - 1})),
      s.copyWith(stock: {...s.stock, species: (s.stock[species] ?? 0) + 1}),
    );
  }

  /// Las especies para la tirada: las del lago más las soltadas, y cada
  /// soltada repetida (más peso dentro de su rareza).
  static List<String> lakeRoll(TownState s) {
    final base = s.lake ?? kTownLakeDefault;
    final w = t.i('stockWeight');
    final cap = t.i('stockWeightCap');
    return [
      ...base,
      for (final e in s.stock.entries)
        if (kFish.containsKey(e.key)) ...[
          if (!base.contains(e.key)) e.key,
          for (var i = 0; i < math.min(cap, e.value * w); i++) e.key,
        ],
    ];
  }

  /// Bonus de rareza del lago: zonas de LAGO y especies criando (≥ 2).
  static double lakeRare(TownState s) {
    final breeding = s.stock.values.where((n) => n >= 2).length;
    return t.d('lakeZoneRare') * s.zoneCount(TownZoneKind.lago) +
        math.min(t.d('breedRareCap'), t.d('breedRare') * breeding);
  }

  /// Misión ganada: las especies con pareja pueden criar (+1).
  static TownState breed(double Function() rand, TownState s) {
    final out = {...s.stock};
    var total = s.stockTotal;
    final cap = lakeCapacity(s);
    for (final e in s.stock.entries) {
      if (e.value < 2 || total >= cap) continue;
      if (rand() < t.d('breedChance')) {
        out[e.key] = e.value + 1;
        total++;
      }
    }
    return s.copyWith(stock: out);
  }

  // ---------------- ayudante ----------------

  static int helperCost(int nextLevel) => t.i('helperCost') * nextLevel;

  static String? cannotHire(PlayerProfile p, TownState s) {
    if (s.helper >= t.i('helperMax')) return 'El ayudante ya está al máximo';
    final need = t.i('helperLevel') * (s.helper + 1);
    final lvl = FarmingRules.level(p);
    if (lvl < need) return 'Necesitás Cultivo nivel $need';
    final c = helperCost(s.helper + 1);
    if (p.credits < c) return 'Falta oro (${p.credits}/$c)';
    return null;
  }

  static (PlayerProfile, TownState)? hire(PlayerProfile p, TownState s) {
    if (cannotHire(p, s) != null) return null;
    return (
      p.copyWith(credits: p.credits - helperCost(s.helper + 1)),
      s.copyWith(helper: s.helper + 1),
    );
  }

  /// Parcelas que atiende el ayudante; [boost]: el mejor «Capataz» de los
  /// que están en el pueblo.
  static int helperPlots(TownState s, {double boost = 0}) =>
      (t.i('helperPlots') * s.helper * (1 + boost)).round();

  /// El mejor efecto de ayudante de [ps] (árbol de Cultivo).
  static double helperBoost(Iterable<PlayerProfile> ps) => ps.fold(
      0.0, (a, p) => math.max(a, LifeTreeRules.farm(p, LifeFx.helper)));

  /// Recoge el granero en la bolsa de [p] (con un poco de XP).
  static (PlayerProfile, TownState)? collectSilo(PlayerProfile p, TownState s) {
    if (s.silo.isEmpty) return null;
    var f = p.life.farm;
    var xp = 0;
    for (final e in s.silo.entries) {
      f = f.addCrop(e.key, e.value);
      final c = parseCropKey(e.key);
      if (c != null) {
        xp += (FarmingRules.cropXp(c.$1, c.$2) * e.value * t.d('helperXpShare'))
            .round();
      }
    }
    return (
      p.copyWith(life: p.life.copyWith(farm: f.copyWith(xp: f.xp + xp))),
      s.copyWith(silo: const {}),
    );
  }
}
