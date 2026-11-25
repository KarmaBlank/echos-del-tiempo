import '../data/bait_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/life_tree_catalog.dart';
import '../data/smithing_catalog.dart' show kSmithMaterials;
import 'farm_skills.dart';
import 'player_stall.dart';

export 'farm_skills.dart';
export 'player_stall.dart';

/// Materiales de oficio (v0.27.0): fibra vegetal, cebo prensado y tabla
/// tratada. Se hacen en el TALLER DE OFICIOS y pagan contratar y mejorar ayudantes.
const kLifeMaterialIds = ['fibra', 'cebo', 'tabla'];

/// Habilidades de vida del personaje (town_loop.md § 11c, fishing.md § 3):
/// Pesca (XP total; el nivel sale de la curva), cañas, la bolsa de
/// Pescados y el pity de legendarios. JSON `life` del perfil.
class LifeSkills {
  LifeSkills({
    this.fishXp = 0,
    List<String> rods = const [kStarterRod],
    String? rod,
    Map<String, int> bag = const {},
    this.pity = 0,
    this.dry = 0,
    FarmSkills? farm,
    List<String> fishTree = const [],
    Map<String, int> crafts = const {},
    this.smithXp = 0,
    List<String> smithTree = const [],
    Map<String, int> log = const {},
    Map<String, int> ores = const {},
    Map<String, OreFind> oreLog = const {},
    Map<String, int> baits = const {},
    String? bait,
    Set<String> claimed = const {},
    PlayerStall? stall,
  })  : stall = stall ?? PlayerStall.empty,
        claimed = Set.unmodifiable(claimed),
        oreLog = Map.unmodifiable({
          for (final e in oreLog.entries)
            if (kSmithMaterials.containsKey(e.key)) e.key: e.value,
        }),
        ores = Map.unmodifiable({
          for (final e in ores.entries)
            if (e.value > 0 && kSmithMaterials.containsKey(e.key))
              e.key: e.value,
        }),
        baits = Map.unmodifiable({
          for (final e in baits.entries)
            if (e.value > 0 && kBaits.containsKey(e.key)) e.key: e.value,
        }),
        bait = bait != null && kBaits.containsKey(bait) ? bait : null,
        farm = farm ?? FarmSkills.initial,
        crafts = Map.unmodifiable({
          for (final e in crafts.entries)
            if (e.value > 0 && kLifeMaterialIds.contains(e.key)) e.key: e.value,
        }),
        fishTree = List.unmodifiable(fishTree.toSet()),
        smithTree = List.unmodifiable(smithTree.toSet()),
        log = Map.unmodifiable({
          for (final e in log.entries)
            if (e.value >= 0 && kFish.containsKey(e.key)) e.key: e.value,
        }),
        rods = List.unmodifiable(
            {kStarterRod, ...rods.where(kRods.containsKey)}),
        rod = rod != null && kRods.containsKey(rod) &&
                (rods.contains(rod) || rod == kStarterRod)
            ? rod
            : kStarterRod,
        bag = Map.unmodifiable({
          for (final e in bag.entries)
            if (e.value > 0 &&
                kFish.containsKey(e.key) &&
                e.key != kWaterBundle)
              e.key: e.value,
        });

  /// Todo personaje nuevo o migrado: caña de rama equipada.
  static final initial = LifeSkills();

  /// XP total de Pesca.
  final int fishXp;

  /// Cañas propias (siempre incluye la de rama) y la equipada (espacio de
  /// herramienta, aparte de las armas).
  final List<String> rods;
  final String rod;

  /// Bolsa de Pescados: especie → cantidad (apilable).
  final Map<String, int> bag;

  /// Capturas sin legendario desde el último (fishing.md § 2.3).
  final int pity;

  /// Capturas sin cofre ni arma del agua (pity del botín, fishing.md § 8).
  final int dry;

  /// Cultivo (farming.md § 3).
  final FarmSkills farm;

  /// Nodos tomados del árbol de Pesca (life_skill_trees.md).
  final List<String> fishTree;

  /// Materiales de oficio condensados (v0.27.0, farming.md § 8.5): id de
  /// [kLifeMaterialIds] → cantidad.
  final Map<String, int> crafts;

  int craft(String id) => crafts[id] ?? 0;

  /// The player's own stall (player_shop.md). JSON `ps`.
  final PlayerStall stall;

  /// XP total de Herrería (roles.md § 6).
  final int smithXp;

  /// Nodos tomados del árbol de Herrería.
  final List<String> smithTree;

  /// Life tree nodes whose one-time rewards were already delivered
  /// (life_trees_v2.md § 4). JSON `lc`.
  final Set<String> claimed;

  /// Bestiario de pesca (fishing.md § 10): especie → récord en cm.
  /// Una especie está descubierta si tiene entrada.
  final Map<String, int> log;

  /// Smithing materials (mining_smithing.md § 2): id of
  /// `kSmithMaterials` → amount. JSON `ore`.
  final Map<String, int> ores;

  int ore(String id) => ores[id] ?? 0;

  /// Material collection (mining_smithing.md § 2.1): id → first find,
  /// where and how many were found in total. JSON `ol`.
  final Map<String, OreFind> oreLog;

  /// [oreLog] with the positive amounts of [got] found at [source] on
  /// world day [day].
  LifeSkills logOres(Map<String, int> got, String source, int day) {
    final next = {...oreLog};
    for (final e in got.entries) {
      if (e.value <= 0 || !kSmithMaterials.containsKey(e.key)) continue;
      final f = next[e.key];
      next[e.key] = f == null
          ? OreFind(day, source, e.value)
          : OreFind(f.day, f.source, f.count + e.value);
    }
    return copyWith(oreLog: next);
  }

  /// [ores] plus [delta] of each id (negative takes), clamped to 0..[cap].
  LifeSkills addOres(Map<String, int> delta, {int cap = 999}) => copyWith(
          ores: {
        ...ores,
        for (final e in delta.entries)
          e.key: (ore(e.key) + e.value).clamp(0, cap),
      });

  bool discovered(String species) => log.containsKey(species);

  /// Baits (fishing.md § 14): id → count, and the one picked on the
  /// CEBO slot (`null` = the best owned).
  final Map<String, int> baits;
  final String? bait;
  int baitCount(String id) => baits[id] ?? 0;
  LifeSkills addBait(String id, [int n = 1]) {
    final left = baitCount(id) + n;
    return copyWith(baits: {...baits, id: left < 0 ? 0 : left});
  }

  int count(String species) => bag[species] ?? 0;
  int get bagTotal => bag.values.fold(0, (a, b) => a + b);

  LifeSkills copyWith({
    int? fishXp,
    List<String>? rods,
    String? rod,
    Map<String, int>? bag,
    int? pity,
    int? dry,
    FarmSkills? farm,
    List<String>? fishTree,
    Map<String, int>? crafts,
    int? smithXp,
    List<String>? smithTree,
    Map<String, int>? log,
    Map<String, int>? ores,
    Map<String, OreFind>? oreLog,
    Map<String, int>? baits,
    String? bait,
    Set<String>? claimed,
    PlayerStall? stall,
  }) =>
      LifeSkills(
          stall: stall ?? this.stall,
          claimed: claimed ?? this.claimed,
          fishXp: fishXp ?? this.fishXp,
          rods: rods ?? this.rods,
          rod: rod ?? this.rod,
          bag: bag ?? this.bag,
          pity: pity ?? this.pity,
          dry: dry ?? this.dry,
          farm: farm ?? this.farm,
          fishTree: fishTree ?? this.fishTree,
          crafts: crafts ?? this.crafts,
          smithXp: smithXp ?? this.smithXp,
          smithTree: smithTree ?? this.smithTree,
          log: log ?? this.log,
          ores: ores ?? this.ores,
          oreLog: oreLog ?? this.oreLog,
          baits: baits ?? this.baits,
          bait: bait ?? this.bait);

  /// Anota la captura en el bestiario (récord de tamaño).
  LifeSkills logCatch(String species, int cm) =>
      (log[species] ?? -1) >= cm ? this : copyWith(log: {...log, species: cm});

  LifeSkills addFish(String species, [int n = 1]) =>
      copyWith(bag: {...bag, species: count(species) + n});

  Map<String, Object?> toJson() => {
        if (fishXp > 0) 'fx': fishXp,
        'rods': rods,
        'rod': rod,
        if (bag.isNotEmpty) 'bag': bag,
        if (pity > 0) 'pity': pity,
        if (dry > 0) 'dry': dry,
        'farm': farm.toJson(),
        if (fishTree.isNotEmpty) 'ft': fishTree,
        if (crafts.isNotEmpty) 'cf': crafts,
        if (smithXp > 0) 'sx': smithXp,
        if (smithTree.isNotEmpty) 'st': smithTree,
        if (log.isNotEmpty) 'lg': log,
        if (ores.isNotEmpty) 'ore': ores,
        if (oreLog.isNotEmpty)
          'ol': {for (final e in oreLog.entries) e.key: e.value.toJson()},
        if (baits.isNotEmpty) 'bt': baits,
        if (bait != null) 'bs': bait,
        if (claimed.isNotEmpty) 'lc': [...claimed]..sort(),
        if (!stall.isEmpty) 'ps': stall.toJson(),
      };

  /// Tolerante; sin `life` (saves de antes de v0.22.0) → [initial]: así
  /// todo personaje recibe la caña de rama.
  static LifeSkills fromJson(Object? raw) {
    if (raw is! Map) return initial;
    int n(Object? v) => v is num && v.isFinite ? v.truncate() : 0;
    final rods = raw['rods'];
    final bag = raw['bag'];
    return LifeSkills(
      fishXp: n(raw['fx']),
      rods: rods is List ? [for (final r in rods) if (r is String) r] : const [],
      rod: raw['rod'] is String ? raw['rod'] as String : null,
      bag: bag is Map
          ? {for (final e in bag.entries) '${e.key}': n(e.value)}
          : const {},
      pity: n(raw['pity']),
      dry: n(raw['dry']),
      farm: FarmSkills.fromJson(raw['farm']),
      // life_trees_v2.md § 6: v1 ids are dropped (full refund).
      fishTree: raw['ft'] is List
          ? [
              for (final x in raw['ft'] as List)
                if (x is String && isLifeTreeNode(LifeSkillKind.pesca, x)) x
            ]
          : const [],
      crafts: raw['cf'] is Map
          ? {
              for (final e in (raw['cf'] as Map).entries)
                '${e.key}': n(e.value)
            }
          : const {},
      smithXp: n(raw['sx']),
      smithTree: raw['st'] is List
          ? [
              for (final x in raw['st'] as List)
                if (x is String && isLifeTreeNode(LifeSkillKind.herreria, x))
                  x
            ]
          : const [],
      log: raw['lg'] is Map
          ? {
              for (final e in (raw['lg'] as Map).entries)
                '${e.key}': n(e.value)
            }
          : const {},
      oreLog: raw['ol'] is Map
          ? {
              for (final e in (raw['ol'] as Map).entries)
                if (OreFind.fromJson(e.value) case final f?) '${e.key}': f
            }
          : const {},
      ores: raw['ore'] is Map
          ? {
              for (final e in (raw['ore'] as Map).entries)
                '${e.key}': n(e.value)
            }
          : const {},
      baits: raw['bt'] is Map
          ? {
              for (final e in (raw['bt'] as Map).entries)
                '${e.key}': n(e.value)
            }
          : const {},
      bait: raw['bs'] is String ? raw['bs'] as String : null,
      claimed: raw['lc'] is List
          ? {for (final x in raw['lc'] as List) if (x is String) x}
          : const {},
      stall: PlayerStall.fromJson(raw['ps']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LifeSkills &&
      other.fishXp == fishXp &&
      other.rod == rod &&
      other.pity == pity &&
      other.dry == dry &&
      other.farm == farm &&
      other.fishTree.join(',') == fishTree.join(',') &&
      other.rods.join(',') == rods.join(',') &&
      other.bag.length == bag.length &&
      bag.entries.every((e) => other.bag[e.key] == e.value) &&
      other.smithXp == smithXp &&
      other.smithTree.join(',') == smithTree.join(',') &&
      other.claimed.length == claimed.length &&
      other.claimed.containsAll(claimed) &&
      other.log.length == log.length &&
      log.entries.every((e) => other.log[e.key] == e.value) &&
      other.crafts.length == crafts.length &&
      crafts.entries.every((e) => other.crafts[e.key] == e.value) &&
      other.ores.length == ores.length &&
      ores.entries.every((e) => other.ores[e.key] == e.value) &&
      other.oreLog.length == oreLog.length &&
      oreLog.entries.every((e) => other.oreLog[e.key] == e.value) &&
      other.bait == bait &&
      other.stall == stall &&
      other.baits.length == baits.length &&
      baits.entries.every((e) => other.baits[e.key] == e.value);

  @override
  int get hashCode => Object.hash(fishXp, rod, pity, rods.length, bag.length);
}

/// First find of a smithing material: world [day], [source]
/// (`mine:<biome>`, `dungeon:<zone>`, `boss`, `smelt`) and total [count].
class OreFind {
  const OreFind(this.day, this.source, this.count);
  final int day;
  final String source;
  final int count;

  List<Object> toJson() => [day, source, count];

  static OreFind? fromJson(Object? raw) {
    if (raw is! List || raw.length != 3) return null;
    final (d, s, c) = (raw[0], raw[1], raw[2]);
    if (d is! num || s is! String || c is! num) return null;
    return OreFind(d.toInt(), s, c.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is OreFind &&
      other.day == day &&
      other.source == source &&
      other.count == count;

  @override
  int get hashCode => Object.hash(day, source, count);
}
