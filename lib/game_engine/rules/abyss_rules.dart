import 'dart:math' as math;

import '../data/abyss_catalog.dart';
import '../data/game_catalog.dart';
import '../data/uniques_catalog.dart';
import '../models/atlas.dart';
import '../models/battle_state.dart';
import '../models/eco.dart';
import '../models/item.dart';
import '../models/loot.dart';
import '../models/mission_def.dart';
import '../models/player_profile.dart';
import '../models/zone_def.dart';
import 'battle_engine.dart' show RandomSource;
import 'loot_rules.dart';

/// Reglas de los Jefes del Abismo fuera de la batalla
/// (docs/specs/abyss_bosses.md § 1 y § 3): Fragmentos, abrir, consumir,
/// marcas de vencidos y recompensas. Puras. Las mecánicas en batalla
/// viven en `battle_engine_abyss.dart`; las funciones de lectura de
/// batalla de acá las comparten el motor y el HUD.
class AbyssRules {
  const AbyssRules({this.catalog = GameCatalog.standard});

  final GameCatalog catalog;

  /// `missionId` de las peleas del Abismo (votación, preparación, sesión).
  static const missionId = 'abismo';

  /// El jefe secreto.
  static const secretNumber = 5;

  AbyssBossDef? def(int? n) => n == null ? null : catalog.abyssBosses[n];

  // ------------------------------------------------------------------
  // Abrir (§ 1.2)
  // ------------------------------------------------------------------

  /// Lo que cuesta abrir [d].
  Map<CraftMaterial, int> cost(AbyssBossDef d) => d.fragment == null
      ? {for (final f in kFragments) f: 1}
      : {d.fragment!: d.fragmentCost};

  /// [p] venció a los 4 Jefes del Abismo (requisito del secreto).
  static bool beatAllFour(PlayerProfile p) =>
      p.abyssKills.containsAll(const [1, 2, 3, 4]);

  /// [p] ya vio (venció) a [d]: la UI muestra su nombre.
  static bool known(PlayerProfile p, AbyssBossDef d) =>
      p.abyssKills.contains(d.number);

  /// El secreto se muestra recién al vencer a los 4.
  static bool visible(PlayerProfile p, AbyssBossDef d) =>
      !d.secret || beatAllFour(p);

  /// Por qué [p] no puede abrir [d] (o `null`). No mira el modo de la
  /// sala (eso lo hace el host / la UI).
  String? cannotOpen(PlayerProfile p, AbyssBossDef d) {
    if (!p.ecosUnlocked) return 'Vencé al Devorador de Eras';
    if (d.secret && !beatAllFour(p)) return 'Vencé a los 4 Jefes del Abismo';
    for (final e in cost(d).entries) {
      final have = p.material(e.key);
      if (have < e.value) {
        return 'Faltan ${e.key.label} ($have/${e.value})';
      }
    }
    return null;
  }

  /// El perfil sin el costo de [d] (`null` si no le alcanza).
  PlayerProfile? consume(PlayerProfile p, AbyssBossDef d) {
    final mats = {...p.materials};
    for (final e in cost(d).entries) {
      final have = mats[e.key] ?? 0;
      if (have < e.value) return null;
      mats[e.key] = have - e.value;
    }
    return p.copyWith(materials: mats);
  }

  /// Texto del costo: `5 Fragmento del Reloj` / `1 de cada Fragmento`.
  String costText(AbyssBossDef d) => d.fragment == null
      ? '1 de cada Fragmento'
      : '${d.fragmentCost} ${d.fragment!.label}';

  // ------------------------------------------------------------------
  // Vencidos (§ 1.3)
  // ------------------------------------------------------------------

  /// El perfil con los vencidos de la cuenta (`x1`..`x5` del Atlas).
  static PlayerProfile withAccount(PlayerProfile p, AtlasProgress atlas) {
    final fromAccount = {
      for (final k in atlas.done)
        if (k.length == 2 && k[0] == 'x')
          if (int.tryParse(k.substring(1)) case final n?
              when n >= 1 && n <= 5)
            n,
    };
    if (p.abyssKills.containsAll(fromAccount)) return p;
    return p.copyWith(abyssKills: {...p.abyssKills, ...fromAccount});
  }

  /// Anota en la cuenta la victoria sobre el jefe [n] (primera vez: da
  /// puntos de Atlas). Devuelve el Atlas nuevo y los puntos.
  ({AtlasProgress progress, int points}) recordAccount(
      AtlasProgress atlas, int n) {
    final key = 'x$n';
    if (atlas.done.contains(key)) return (progress: atlas, points: 0);
    return (
      progress: atlas.copyWith(done: {...atlas.done, key}),
      points: catalog.abyssBosses[n]?.atlasPoints ?? 2,
    );
  }

  // ------------------------------------------------------------------
  // Misión (§ 2)
  // ------------------------------------------------------------------

  /// La zona sintética de [d]: el generador y el tema de su zona base
  /// (el secreto, los del Corazón del Tiempo), 1 piso a su nivel.
  ZoneDef zoneDef(AbyssBossDef d) {
    final z = catalog.zone(d.arenaZone == 0 ? 10 : d.arenaZone) ??
        catalog.zones.last;
    return ZoneDef(
      index: z.index,
      id: missionId,
      name: d.name,
      gen: z.gen,
      minLevel: d.level,
      maxLevel: d.level,
      floors: 1,
      bossId: d.enemyId,
      bossName: d.name,
      theme: z.theme,
      missionId: missionId,
    );
  }

  /// La misión de [d]: solo el jefe.
  MissionDef missionDef(AbyssBossDef d) {
    final z = zoneDef(d);
    return MissionDef(
      id: missionId,
      name: d.name,
      type: 'Abismo',
      rank: 'S',
      recommendedLevel: 50,
      theme: z.theme,
      goal: 0,
      groups: [
        [d.enemyId]
      ],
      boss: [d.enemyId],
      sTime: 300,
      elite: d.enemyId,
      extra: 0,
      zone: z.index,
      floors: 1,
      floorGoal: 0,
    );
  }

  // ------------------------------------------------------------------
  // Fragmentos (§ 1.1)
  // ------------------------------------------------------------------

  /// Chance de que [src] suelte un Fragmento dentro de [eco] (0 si el
  /// tier no llega).
  double fragmentChance(EcoItem eco, LootSource src) {
    final c = catalog.fragmentDrop;
    if (eco.tier < c.minTier) return 0;
    var p = c.base(src) *
        (1 + c.perTier * (eco.tier - c.minTier)) *
        (1 + c.perRarity * eco.rarity.index + c.perMod * eco.mods.length);
    final match = matchOf(eco) != null;
    if (match && (src == LootSource.boss || src == LootSource.mission)) {
      p *= c.matchChance;
    }
    return math.min(c.cap, p);
  }

  /// El Jefe del Abismo cuyo jefe base es el del Eco (o `null`).
  AbyssBossDef? matchOf(EcoItem eco) {
    for (final d in catalog.abyssBosses.values) {
      if (d.matchBoss != 0 && d.matchBoss == eco.boss) return d;
    }
    return null;
  }

  /// Una tirada de Fragmento: `null` si no cae.
  CraftMaterial? rollFragment(RandomSource rng, EcoItem eco, LootSource src) {
    final chance = fragmentChance(eco, src);
    if (chance <= 0 || rng() >= chance) return null;
    final match = matchOf(eco)?.fragment;
    final c = catalog.fragmentDrop;
    final weights = [
      for (final f in kFragments) f == match ? c.matchWeight : 1.0,
    ];
    final total = weights.fold(0.0, (a, w) => a + w);
    var x = rng() * total;
    for (var i = 0; i < kFragments.length; i++) {
      x -= weights[i];
      if (x < 0) return kFragments[i];
    }
    return kFragments.last;
  }

  // ------------------------------------------------------------------
  // Recompensas (§ 3)
  // ------------------------------------------------------------------

  /// Lo exclusivo de vencer a [d] para un jugador con el perfil [p]
  /// (antes de anotar la victoria): el legendario (seguro la primera
  /// vez) y las Esencias.
  List<LootDrop> rewards(RandomSource rng, AbyssBossDef d, PlayerProfile p,
      LootRules loot) {
    final out = <LootDrop>[];
    final first = !p.abyssKills.contains(d.number);
    final ids = [
      for (final id in d.legendaryIds)
        if (kUniques[id] case final u?
            when catalog.weapons.containsKey(u.baseId))
          id,
    ];
    if (ids.isNotEmpty && (first || rng() < d.legendaryChance)) {
      final u = kUniques[ids[(rng() * ids.length).floor()]]!;
      out.add(LootDrop.item(loot.generateUnique(rng, u, LootRules.maxLevel)));
    }
    var n = d.essence;
    if (d.essenceExtra > 0 && rng() < d.essenceExtra) n++;
    if (n > 0) out.add(LootDrop.stack(StackKind.esencia, n));
    return out;
  }

  // ------------------------------------------------------------------
  // Lectura de la batalla (motor y HUD)
  // ------------------------------------------------------------------

  /// Índice (desde 0) de la fase actual de [e].
  static int phaseIndex(AbyssBossDef d, Combatant e) =>
      (math.max(1, e.phase) - 1).clamp(0, d.phases.length - 1);

  static AbyssPhaseDef phaseOf(AbyssBossDef d, Combatant e) =>
      d.phases[phaseIndex(d, e)];

  /// El movimiento de la próxima acción de [e] (el de la rotación).
  static AbyssMoveDef nextMove(AbyssBossDef d, Combatant e) {
    final moves = phaseOf(d, e).moves;
    return moves[e.actions % moves.length];
  }

  /// Turnos propios que faltan para la furia (0 = ya está).
  static int enrageIn(AbyssBossDef d, Combatant e) =>
      e.abyssEnraged ? 0 : math.max(0, d.enrageTurns - e.abyssTurns);

  /// El primer sello de [d] (para sus números).
  static AbyssMoveDef? sealMove(AbyssBossDef d) {
    for (final ph in d.phases) {
      for (final m in ph.moves) {
        if (m.kind == AbyssMoveKind.seal) return m;
      }
    }
    return null;
  }
}
