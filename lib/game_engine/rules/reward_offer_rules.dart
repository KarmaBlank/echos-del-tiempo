import '../data/branch_ults_catalog.dart' show kBranchUltList, kBranchUltPathTypes;
import '../data/game_catalog.dart';
import '../data/run_boons.dart';
import '../data/tuning_catalog.dart';
import '../models/attributes.dart';
import '../models/passive_tree.dart';
import '../models/player_profile.dart';
import '../models/run_state.dart';
import '../models/skill.dart';
import 'battle_engine.dart' show RandomSource;
import 'mulberry32.dart';
import 'run_tuning.dart';

/// Ofertas de recompensa de la Travesía (docs/specs/roguelike.md § 4):
/// tres filas (Árbol / Arma / Extra) de [RunTuning.offerSize] opciones,
/// propias de cada jugador.
///
/// Árbol: nodos de **cualquier** parte de las ramas de su clase (las de la
/// clase y los puentes que la incluyen), sin pedir adyacencia, sin
/// duplicados ni keystones excluidas por lo que ya tiene. Tendencia
/// (§ 4.1): normalmente una opción sale de la rama principal (la que más
/// pesa en lo tomado), otra de una rama con sinergia (vecina en el árbol)
/// y el resto libres; con [RunTuning.pityAfter] ofertas seguidas sin la
/// principal, la siguiente la garantiza.
class RewardOfferRules {
  const RewardOfferRules({required this.tree, required this.catalog});

  final PassiveTreeCatalog tree;
  final GameCatalog catalog;

  /// Ramas que se le ofrecen a [classId].
  List<String> classPaths(String classId) => [
        for (final p in tree.paths.values)
          if (p.kind != 'grupo' &&
              (p.classId == classId || p.classId.split('+').contains(classId)))
            p.id,
      ];

  /// [nodeId] queda bloqueado por una exclusión con algo de [taken].
  bool excluded(String nodeId, Iterable<String> taken) {
    final set = taken.toSet();
    final ex = tree.exclusions[nodeId];
    if (ex != null && set.contains(ex)) return true;
    for (final t in set) {
      if (tree.exclusions[t] == nodeId) return true;
    }
    return false;
  }

  /// Nodos que se le pueden ofrecer a [p] ahora.
  List<String> candidates(PlayerProfile p) {
    final paths = classPaths(p.classId).toSet();
    final taken = p.tree.toSet();
    return [
      for (final n in tree.nodes.values)
        if (n.kind != 'st' &&
            n.pathId != null &&
            paths.contains(n.pathId) &&
            !taken.contains(n.id) &&
            !excluded(n.id, taken))
          n.id,
    ]..sort();
  }

  /// Peso de cada rama según lo tomado (notables y keystones pesan más).
  Map<String, int> trend(PlayerProfile p) {
    final out = <String, int>{};
    for (final id in p.tree) {
      final n = tree.nodes[id];
      final path = n?.pathId;
      if (n == null || path == null) continue;
      out[path] = (out[path] ?? 0) +
          switch (n.kind) {
            'k' => 3,
            'n' => 2,
            _ => 1,
          };
    }
    return out;
  }

  /// La rama principal de [p] (`null` si todavía no tomó nada).
  String? mainPath(PlayerProfile p) {
    final t = trend(p);
    if (t.isEmpty) return null;
    final keys = t.keys.toList()..sort();
    var best = keys.first;
    for (final k in keys) {
      if (t[k]! > t[best]!) best = k;
    }
    return best;
  }

  /// Ramas vecinas de [pathId] (alguna arista del árbol las une).
  Set<String> synergyPaths(String pathId) {
    final out = <String>{};
    for (final n in tree.nodes.values) {
      if (n.pathId != pathId) continue;
      for (final l in n.links) {
        final o = tree.nodes[l]?.pathId;
        if (o != null && o != pathId) out.add(o);
      }
    }
    for (final n in tree.nodes.values) {
      if (n.pathId == null || n.pathId == pathId) continue;
      if (n.links.any((l) => tree.nodes[l]?.pathId == pathId)) {
        out.add(n.pathId!);
      }
    }
    return out;
  }

  /// La fila Árbol. Devuelve también si incluye la rama principal (para
  /// la racha).
  (List<String>, bool) treeOffer(
      PlayerProfile p, RandomSource rnd, int missStreak) {
    final pool = candidates(p);
    final main = mainPath(p);
    final out = <String>[];
    String? from(bool Function(String id) where) {
      final opts = [
        for (final id in pool)
          if (!out.contains(id) && where(id)) id
      ];
      if (opts.isEmpty) return null;
      return opts[(rnd() * opts.length).floor()];
    }

    if (main != null) {
      final pity = missStreak >= RunTuning.pityAfter;
      if (pity || rnd() < RunTuning.trendChance) {
        final id = from((id) => tree.nodes[id]!.pathId == main);
        if (id != null) out.add(id);
      }
      final syn = synergyPaths(main);
      if (syn.isNotEmpty && rnd() < RunTuning.synergyChance) {
        final id = from((id) => syn.contains(tree.nodes[id]!.pathId));
        if (id != null) out.add(id);
      }
    }
    while (out.length < RunTuning.offerSize) {
      final id = from((_) => true);
      if (id == null) break;
      out.add(id);
    }
    final hit =
        main != null && out.any((id) => tree.nodes[id]!.pathId == main);
    return (out, hit);
  }

  /// La fila Arma: bases de los tipos de su clase hasta
  /// [RunTuning.weaponLevelAhead] niveles por encima de los enemigos de la
  /// entrada del piso [floor] (sin nivel del personaje, § 5).
  List<String> weaponOffer(PlayerProfile p, RandomSource rnd, {int floor = 0}) {
    final cap = RunTuning.levelBase +
        floor * RunTuning.levelPerFloor +
        RunTuning.weaponLevelAhead;
    final cls = catalog.classes[p.classId];
    if (cls == null) return const [];
    final types = cls.allowedWeaponTypes.toSet();
    final owned = {for (final i in p.items) i.baseId};
    final all = [
      for (final w in catalog.weapons.values)
        if (w.price > 0 &&
            types.contains(w.type) &&
            w.level <= cap)
          w.id,
    ]..sort();
    final fresh = [for (final id in all) if (!owned.contains(id)) id];
    final pool = fresh.length >= RunTuning.offerSize ? fresh : all;
    return _take(pool, rnd, RunTuning.offerSize);
  }

  /// La fila Extra: oro, consumible, +atributo (sin Agilidad, § 5) o
  /// mejora directa (las del grupo de ajustes «Travesía»).
  /// Habilidades libres que se le pueden ofrecer a [p]: las de las armas
  /// de su clase hasta el nivel de la fila Arma, sin provocaciones, sin
  /// las que ya tiene ([owned]) ni las de su arma.
  List<String> skillCandidates(PlayerProfile p, int floor,
      {List<String> owned = const []}) {
    final cls = catalog.classes[p.classId];
    if (cls == null) return const [];
    final types = cls.allowedWeaponTypes.toSet();
    final cap = RunTuning.levelBase +
        floor * RunTuning.levelPerFloor +
        RunTuning.weaponLevelAhead;
    final eq = catalog.weapons[p.equippedItem?.baseId ?? cls.startWeaponId];
    final skip = {...owned, ...?eq?.skillIds, ...cls.kitSkillIds};
    final out = <String>{};
    for (final w in catalog.weapons.values) {
      if (w.price <= 0 || !types.contains(w.type) || w.level > cap) continue;
      for (final s in w.skillIds) {
        final sk = catalog.skills[s];
        if (sk == null || sk.kind == SkillKind.taunt || skip.contains(s)) {
          continue;
        }
        out.add(s);
      }
    }
    return out.toList()..sort();
  }

  List<RunExtra> extraOffer(int floor, RandomSource rnd,
      {PlayerProfile? player, List<String> owned = const []}) {
    const attrs = [Attribute.vit, Attribute.fue, Attribute.esp, Attribute.des];
    final pool = <RunExtra>[
      RunExtra(RunExtraKind.oro,
          RunTuning.extraGoldBase + floor * RunTuning.extraGoldPerFloor),
      const RunExtra(RunExtraKind.pocion, RunTuning.extraPotions),
      const RunExtra(RunExtraKind.eter, RunTuning.extraEthers),
      for (final a in _take(attrs, rnd, 2))
        RunExtra(RunExtraKind.atributo, RunTuning.extraAttribute, attribute: a),
      for (final b in _take(RunBoon.values,
          rnd, tuning(TuningId.travesia).i('boonsInExtra')))
        RunExtra(RunExtraKind.mejora, 1, boon: b.name),
      if (player != null)
        for (final s in _take(skillCandidates(player, floor, owned: owned),
            rnd, tuning(TuningId.travesia).i('skillsInExtra')))
          RunExtra(RunExtraKind.habilidad, 1, skill: s),
    ];
    return _take(pool, rnd, RunTuning.offerSize);
  }

  /// ULT de rama de las ramas de su clase que usa con algún arma de su
  /// clase y que todavía no aprendió.
  List<String> ultCandidates(PlayerProfile p) {
    final paths = classPaths(p.classId).toSet();
    final types = catalog.classes[p.classId]?.allowedWeaponTypes.toSet() ??
        const <String>{};
    return [
      for (final (path, sk, _) in kBranchUltList)
        if (paths.contains(path) &&
            !p.ultKnown.contains(sk.id) &&
            (kBranchUltPathTypes[path] ?? const []).any(types.contains))
          sk.id,
    ]..sort();
  }

  /// La fila ULT: [RunTuning.ultOfferSize] ULT de rama (§ 4: jefe
  /// siempre, élite a veces).
  List<String> ultOffer(PlayerProfile p, RandomSource rnd, [int? n]) =>
      _take(ultCandidates(p), rnd, n ?? RunTuning.ultOfferSize);

  /// Surtido de ULT de la tienda del nodo [node] para [p]: siempre el
  /// mismo para la misma run, piso y nodo (§ 12.2).
  List<String> shopUlts(PlayerProfile p,
          {required int seed, required int floor, required int node}) =>
      _take(
          ultCandidates(p),
          mulberry32((seed ^ ((floor + 1) * 15485863) ^ ((node + 3) * 7919)) &
              0xFFFFFFFF),
          RunTuning.shopUlts);

  /// La oferta completa y si el árbol trajo la rama principal. Con
  /// [ults] suma la fila ULT.
  (RunOffer, bool) offer(PlayerProfile p,
      {required int floor,
      required RandomSource rnd,
      int missStreak = 0,
      bool ults = false,
      int? ultCount,
      List<String> ownedSkills = const []}) {
    final (nodes, hit) = treeOffer(p, rnd, missStreak);
    return (
      RunOffer(
        nodes: List.unmodifiable(nodes),
        weapons: List.unmodifiable(weaponOffer(p, rnd, floor: floor)),
        extras: List.unmodifiable(
            extraOffer(floor, rnd, player: p, owned: ownedSkills)),
        ults: ults ? List.unmodifiable(ultOffer(p, rnd, ultCount)) : const [],
      ),
      hit,
    );
  }

  static List<T> _take<T>(List<T> from, RandomSource rnd, int n) {
    final pool = [...from];
    final out = <T>[];
    while (out.length < n && pool.isNotEmpty) {
      out.add(pool.removeAt((rnd() * pool.length).floor()));
    }
    return out;
  }
}
