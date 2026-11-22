import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/run_boons.dart';
import '../data/tuning_catalog.dart';
import '../models/attributes.dart';
import '../models/item.dart';
import '../models/player_profile.dart';
import '../models/run_state.dart';
import 'battle_engine.dart' show RandomSource;
import 'inventory_rules.dart';
import 'js_math.dart';
import 'loot_rules.dart';
import 'mulberry32.dart';
import 'progression_rules.dart';
import 'run_map_generator.dart';
import 'run_tuning.dart';
import 'ult_rules.dart';
import 'zone_rules.dart';

/// Reglas de la Travesía que no dependen de la sesión (docs/specs/
/// roguelike.md): camino, votación, enemigos por piso, personaje de la
/// run y aplicación de recompensas.
class RunRules {
  const RunRules({required this.catalog});

  final GameCatalog catalog;

  static const generator = RunMapGenerator();

  // Cache por semilla: el mapa sale siempre igual de la semilla.
  static final _maps = <int, RunMap>{};

  /// El mapa de [seed] (se arma una vez).
  static RunMap mapOf(int seed) {
    if (_maps.length > 8) _maps.clear();
    return _maps.putIfAbsent(seed, () => generator.generate(seed));
  }

  static RunFloor floorOf(RunState r) => mapOf(r.seed).floors[r.floor];

  /// Nodos que se pueden votar desde donde está el grupo.
  static List<int> reachable(RunState r) {
    final f = floorOf(r);
    final at = r.node;
    if (at == null) return [for (final n in f.entry) n.id];
    return f.node(at).next;
  }

  /// Ganador de la votación: la mayoría; empate → sorteo con la semilla
  /// de la run, el piso y el nodo de partida (igual en todos).
  static int resolveVote(Map<String, int> votes,
      {required int seed, required int floor, int? from}) {
    final count = <int, int>{};
    for (final v in votes.values) {
      count[v] = (count[v] ?? 0) + 1;
    }
    final best = count.values.fold<int>(0, math.max);
    final tied = [
      for (final e in count.entries)
        if (e.value == best) e.key
    ]..sort();
    if (tied.length == 1) return tied.first;
    final rnd = mulberry32(
        (seed ^ ((floor + 1) * 7919) ^ (((from ?? -1) + 2) * 104729)) &
            0xFFFFFFFF);
    return tied[(rnd() * tied.length).floor()];
  }

  /// Nivel de los enemigos del nodo [n] del piso [floor].
  static int enemyLevel(int floor, RunNode n) {
    var l = RunTuning.levelBase +
        floor * RunTuning.levelPerFloor +
        (n.layer * RunTuning.levelPerLayer).floor();
    if (n.type == RunNodeType.elite) l += RunTuning.eliteLevelBonus;
    if (n.type == RunNodeType.jefe) l += RunTuning.bossLevelBonus;
    return l;
  }

  /// Zonas jugables en orden de dificultad (`minLevel`).
  List<int> playableZones() {
    final zs = [
      for (final z in catalog.zones)
        if (z.playable && catalog.mission(z.missionId!) != null) z
    ]..sort((a, b) => a.minLevel.compareTo(b.minLevel));
    return [for (final z in zs) z.index];
  }

  /// Zona de cada piso: la más difícil cuyo nivel mínimo no pasa el de
  /// la entrada del piso (y nunca una anterior a la del piso de antes).
  /// Con [unlocked] solo entran las primeras `zonesStart + unlocked`
  /// zonas (§ 8.3); `null` = todas.
  List<int> floorZones({int? unlocked}) {
    var zs = playableZones();
    if (unlocked != null) {
      zs = zs
          .take(math.max(1,
              tuning(TuningId.travesia).i('zonesStart') + unlocked))
          .toList();
    }
    if (zs.isEmpty) return List.filled(RunTuning.floors, 0);
    final out = <int>[];
    var at = 0;
    for (var f = 0; f < RunTuning.floors; f++) {
      final lvl = RunTuning.levelBase + f * RunTuning.levelPerFloor;
      for (var i = at; i < zs.length; i++) {
        if (catalog.zone(zs[i])!.minLevel <= lvl) at = i;
      }
      out.add(zs[at]);
    }
    return out;
  }

  /// Élite del nodo: la de la zona o una ya vencida antes (el pool crece
  /// al vencerlas, § 8.3).
  String eliteOf(int zone, Map<String, int> beaten, RandomSource rnd) {
    final z = catalog.zone(zone);
    final own = catalog.mission(z?.missionId ?? '')?.elite;
    final pool = <String>{
      if (own != null) own,
      for (final e in beaten.keys)
        if (catalog.enemies.containsKey(e)) e,
    }.toList()
      ..sort();
    if (pool.isEmpty) return 'slime';
    return pool[(rnd() * pool.length).floor()];
  }

  /// Niveles extra de una élite ya vencida [wins] veces.
  static int eliteRepeatLevels(int wins) =>
      wins * tuning(TuningId.travesia).i('eliteRepeatLevel');

  /// Grupo de enemigos del nodo [n] con el pool de la zona [zone]. Con
  /// [elite], esa es la élite (si no, la de la zona).
  List<String> enemyGroup(int zone, int floorIndex, RunNode n, RandomSource rnd,
      {String? elite}) {
    final z = catalog.zone(zone);
    final m = z == null ? null : catalog.mission(z.missionId ?? '');
    if (m == null) return [ZoneRules.resolveEnemy('slime', catalog)];
    List<String> res(List<String> g) => ZoneRules.resolveGroup(g, catalog);
    // El pool del último piso de la zona para el jefe; si no, uno al azar.
    final groups = m.groupsFor(
        n.type == RunNodeType.jefe ? m.floors - 1 : (rnd() * m.floors).floor());
    final g = groups.isEmpty ? m.groups : groups;
    List<String> any() => g[(rnd() * g.length).floor()];
    return switch (n.type) {
      RunNodeType.jefe => res(m.boss),
      RunNodeType.elite => res([elite ?? m.elite, any().first]),
      _ => res(any()),
    };
  }

  // ---------------- personaje de la run ----------------

  /// El personaje descartable de la run: misma clase y nombre, arma
  /// inicial, atributos base, árbol vacío y [RunTuning.startGold] de oro.
  /// Nunca se guarda (§ 8.5).
  static PlayerProfile runProfile(ProgressionRules rules, PlayerProfile base) =>
      rules.normalize(PlayerProfile(
        name: base.name,
        classId: base.classId,
        credits: RunTuning.startGold,
      ));

  /// Agrega [nodeId] al árbol sin pedir puntos ni adyacencia (las
  /// recompensas de la Travesía). `null` si ya lo tiene o no existe.
  static PlayerProfile? grantNode(
      ProgressionRules rules, PlayerProfile p, String nodeId) {
    if (p.tree.contains(nodeId) ||
        !rules.treeRules.catalog.nodes.containsKey(nodeId)) {
      return null;
    }
    return p.copyWith(tree: [...p.tree, nodeId]);
  }

  /// Aplica lo elegido de [offer] (`null` = saltar esa fila). `null` si
  /// algún índice no es válido.
  static PlayerProfile? applyReward(
      ProgressionRules rules, PlayerProfile p, RunOffer offer,
      {int? tree, int? weapon, int? extra, int? ult}) {
    bool bad(int? i, int len) => i != null && (i < 0 || i >= len);
    if (bad(tree, offer.nodes.length) ||
        bad(weapon, offer.weapons.length) ||
        bad(extra, offer.extras.length) ||
        bad(ult, offer.ults.length)) {
      return null;
    }
    var next = p;
    if (ult != null) {
      // La ULT nueva queda aprendida y activa (se cambia desde PERSONAJE).
      final id = offer.ults[ult];
      next = UltRules.learn(next, id).copyWith(ultSel: () => id);
    }
    if (tree != null) {
      next = grantNode(rules, next, offer.nodes[tree]) ?? next;
    }
    if (weapon != null) {
      final w = rules.catalog.weapons[offer.weapons[weapon]];
      if (w != null && InventoryRules.freeCells(next) > 0) {
        next = InventoryRules.addItem(
            next,
            ItemInstance.common(LootRules.newUid, w.id,
                itemLevel: w.level)).$1;
      }
    }
    if (extra != null) {
      final x = offer.extras[extra];
      const cap = ProgressionRules.maxItems;
      next = switch (x.kind) {
        RunExtraKind.oro => next.copyWith(credits: next.credits + x.amount),
        RunExtraKind.pocion =>
          next.copyWith(potions: math.min(cap, next.potions + x.amount)),
        RunExtraKind.eter =>
          next.copyWith(ethers: math.min(cap, next.ethers + x.amount)),
        RunExtraKind.atributo => next.copyWith(
            attributes: next.attributes
                .add({x.attribute ?? Attribute.vit: x.amount})),
        // La mejora vive en `RunState.boons` y la habilidad en
        // `RunState.loadout` (las suma la sesión).
        RunExtraKind.mejora || RunExtraKind.habilidad => next,
      };
    }
    return next;
  }

  /// Modificadores de arma de las mejoras [boons] (§ 4).
  static List<ItemMod> boonMods(List<String> boons, {required bool eliteFight}) => [
        for (final id in boons)
          ...?RunBoon.byName(id)?.mods(eliteFight: eliteFight),
      ];

  /// Poder × de cada habilidad mejorada ([ups]: un id por nivel).
  static Map<String, double> skillScale(List<String> ups) {
    final out = <String, double>{};
    for (final s in ups) {
      out[s] = (out[s] ?? 1) + RunTuning.skillUpPower;
    }
    return out;
  }

  /// Pulso extra al empezar la pelea por las mejoras [boons].
  static int boonPulse(List<String> boons) => [
        for (final id in boons)
          if (RunBoon.byName(id) == RunBoon.pulso) RunBoon.pulso.value,
      ].fold(0, (a, b) => a + b);

  /// Vida o maná tras el descanso.
  static double rested(double now, int max) =>
      math.min(max.toDouble(), now + jsRound(max * RunTuning.restHeal));
}
