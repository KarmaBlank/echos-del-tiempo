import 'dart:math' as math;

import '../data/life_tree_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/player_profile.dart';
import 'farming_rules.dart';
import 'fishing_rules.dart';

export '../data/life_tree_catalog.dart';

/// Reglas de los árboles de oficios (docs/specs/life_skill_trees.md):
/// puntos por nivel, tomar con vecino tomado y sin choque de grupo
/// excluyente, reinicio gratis y la suma de efectos que leen las reglas
/// de Pesca y Cultivo. Puras: el host las aplica.
abstract final class LifeTreeRules {
  static TuningDef get t => tuning(TuningId.lifeTree);

  static int level(PlayerProfile p, LifeSkillKind k) => switch (k) {
        LifeSkillKind.pesca => FishingRules.level(p),
        LifeSkillKind.cultivo => FarmingRules.level(p),
        LifeSkillKind.herreria => SmithRules.level(p),
      };

  static List<String> taken(PlayerProfile p, LifeSkillKind k) =>
      switch (k) {
        LifeSkillKind.pesca => p.life.fishTree,
        LifeSkillKind.cultivo => p.life.farm.tree,
        LifeSkillKind.herreria => p.life.smithTree,
      };

  static String rootOf(LifeSkillKind k) =>
      kLifeTrees[k]!.firstWhere((n) => n.root).id;

  /// Puntos ganados: `(nivel − 1) × pointsPerLevel`.
  static int earned(PlayerProfile p, LifeSkillKind k) =>
      math.max(0, (level(p, k) - 1) * t.i('pointsPerLevel'));

  static int spent(PlayerProfile p, LifeSkillKind k) {
    var s = 0;
    for (final id in taken(p, k)) {
      s += lifeTreeNode(k, id)?.cost ?? 0;
    }
    return s;
  }

  static int free(PlayerProfile p, LifeSkillKind k) =>
      earned(p, k) - spent(p, k);

  /// Los dos oficios (para la insignia de PERSONAJE).
  static int freeTotal(PlayerProfile p) => [
        for (final k in LifeSkillKind.values) math.max(0, free(p, k)),
      ].fold(0, (a, b) => a + b);

  static bool has(PlayerProfile p, LifeSkillKind k, String id) =>
      id == rootOf(k) || taken(p, k).contains(id);

  /// Por qué no se puede tomar [id] (o `null`).
  static String? cannotTake(PlayerProfile p, LifeSkillKind k, String id) {
    final n = lifeTreeNode(k, id);
    if (n == null) return 'Nodo desconocido';
    if (has(p, k, id)) return 'Ya lo tenés';
    final f = free(p, k);
    if (f < n.cost) return 'Faltan puntos ($f/${n.cost})';
    if (!n.links.any((l) => has(p, k, l))) return 'No está conectado';
    final ex = n.exclusive;
    if (ex != null) {
      for (final o in taken(p, k)) {
        final on = lifeTreeNode(k, o);
        if (on != null && on.exclusive == ex) return 'Elegiste ${on.name}';
      }
    }
    return null;
  }

  static PlayerProfile _with(
          PlayerProfile p, LifeSkillKind k, List<String> nodes) =>
      switch (k) {
        LifeSkillKind.pesca =>
          p.copyWith(life: p.life.copyWith(fishTree: nodes)),
        LifeSkillKind.cultivo => p.copyWith(
            life: p.life.copyWith(farm: p.life.farm.copyWith(tree: nodes))),
        LifeSkillKind.herreria =>
          p.copyWith(life: p.life.copyWith(smithTree: nodes)),
      };

  static PlayerProfile? take(PlayerProfile p, LifeSkillKind k, String id) {
    if (cannotTake(p, k, id) != null) return null;
    return _with(p, k, [...taken(p, k), id]);
  }

  /// Reinicio gratis (como la ascensión): devuelve todos los puntos.
  static PlayerProfile? reset(PlayerProfile p, LifeSkillKind k) =>
      taken(p, k).isEmpty ? null : _with(p, k, const []);

  /// Deja lo guardado válido (nodos que existen, conectados, sin choque y
  /// con puntos alcanzando), en orden.
  static PlayerProfile sanitize(PlayerProfile p) {
    var out = p;
    for (final k in LifeSkillKind.values) {
      final want = taken(p, k);
      out = _with(out, k, const []);
      for (final id in want) {
        out = take(out, k, id) ?? out;
      }
    }
    return out;
  }

  /// Suma del efecto [fx] en el árbol [k] de [p] (raíz incluida).
  static double fx(PlayerProfile p, LifeSkillKind k, String fx) {
    var v = 0.0;
    for (final n in kLifeTrees[k]!) {
      if (!has(p, k, n.id)) continue;
      final key = n.effects[fx];
      if (key != null) v += t.d(key);
    }
    return v;
  }

  static double fish(PlayerProfile p, String f) =>
      fx(p, LifeSkillKind.pesca, f);
  static double farm(PlayerProfile p, String f) =>
      fx(p, LifeSkillKind.cultivo, f);
  static double smith(PlayerProfile p, String f) =>
      fx(p, LifeSkillKind.herreria, f);

  /// Poder de aventurero (roles.md § 5): suma de [LifeFx.hp] o
  /// [LifeFx.atk] en los tres árboles.
  static double power(PlayerProfile p, String f) => [
        for (final k in LifeSkillKind.values) fx(p, k, f),
      ].fold(0.0, (a, b) => a + b);
}

/// Herrería (roles.md § 6): XP por forjar, encargos de forja y condensar.
abstract final class SmithRules {
  static TuningDef get t => LifeTreeRules.t;

  static int get maxLevel => math.max(1, t.i('smithMaxLevel'));

  static int xpNeed(int l) =>
      (t.d('smithXpBase') * math.pow(l, t.d('smithXpExp'))).round();

  static int levelFor(int xp) {
    var l = 1, rest = xp;
    while (l < maxLevel && rest >= xpNeed(l)) {
      rest -= xpNeed(l);
      l++;
    }
    return l;
  }

  static int level(PlayerProfile p) => levelFor(p.life.smithXp);

  static (int, int) progress(int xp) {
    var l = 1, rest = xp;
    while (l < maxLevel && rest >= xpNeed(l)) {
      rest -= xpNeed(l);
      l++;
    }
    return l >= maxLevel ? (0, 0) : (rest, xpNeed(l));
  }

  /// Suma [base] de XP de Herrería (con el bonus de XP del árbol).
  static PlayerProfile gain(PlayerProfile p, int base) {
    if (base <= 0) return p;
    final xp = (base * (1 + LifeTreeRules.smith(p, LifeFx.xp))).round();
    return p.copyWith(life: p.life.copyWith(smithXp: p.life.smithXp + xp));
  }

  /// Descuento de la forja del árbol (tope `smithForgeCap`).
  static double forgeDiscount(PlayerProfile p) => LifeTreeRules.smith(
          p, LifeFx.forge)
      .clamp(0.0, t.d('smithForgeCap'))
      .toDouble();
}
