import 'build_plan.dart';
import 'item.dart';
import 'weapon.dart';

/// Qué parte del plan cumple un arma (condición `Build` del filtro de
/// loot; docs/specs/loot.md § 13 y build_planner.md § 6).
enum BuildMatch {
  /// Base o tipo de arma del plan.
  base('Base', 'base o tipo'),

  /// Un mod del plan con tier suficiente.
  mod('Mod', 'mod'),

  /// La pasiva de arma del plan.
  pasiva('Pasiva', 'pasiva'),

  /// Una habilidad del plan.
  habilidad('Habilidad', 'habilidad');

  const BuildMatch(this.word, this.label);

  /// Palabra del filtro de texto (`Build Mod Pasiva`).
  final String word;

  /// Texto corto para la UI.
  final String label;
}

/// Resumen compacto de un [BuildPlan] con **solo** lo que hace falta para
/// saber si un arma le sirve (lo mismo que mira `BuildPlanRules.itemFit`):
/// tipos y bases de arma, mods con tier mínimo, pasiva y habilidades.
/// Sin nombre, notas, checklist, atributos ni árbol.
///
/// Cada cliente se lo manda al anfitrión (`SetBuildWantsAction`) para que
/// el motor evalúe la condición `Build` del filtro con el plan de cada
/// jugador. El host lo guarda en la sesión (`SessionPlayer.buildWants`),
/// nunca lo difunde ni lo persiste. Docs/specs/build_planner.md § 6.
class BuildWants {
  const BuildWants({
    this.weaponTypes = const [],
    this.weaponBases = const [],
    this.mods = const [],
    this.weaponPassive,
    this.skills = const [],
    this.target,
    this.best = 0,
  });

  static const none = BuildWants();

  /// Topes al leerlo de la red (un plan real usa muchos menos).
  static const maxEntries = 24;
  static const maxIdLength = 48;

  final List<String> weaponTypes;
  final List<String> weaponBases;
  final List<ModGoal> mods;
  final String? weaponPassive;
  final List<String> skills;

  /// Objetivo de arma principal del plan v2 (condición `BuildMejora`,
  /// build_planner_v2.md § 1.4): sin estadísticas mínimas (el anfitrión
  /// no conoce el perfil del plan).
  final WeaponTarget? target;

  /// % de la mejor candidata del jugador (inventario + alijo) contra
  /// [target], calculado sin estadísticas: un drop `BuildMejora` lo supera.
  final int best;

  /// Lo que un plan quiere de un arma; [best]: el % de tu mejor candidata
  /// (`WeaponTargetRules.score`).
  factory BuildWants.fromPlan(BuildPlan plan, {int best = 0}) {
    final t = plan.mainTarget;
    return BuildWants(
      weaponTypes: List.unmodifiable(plan.weaponTypes),
      weaponBases: List.unmodifiable(plan.weaponBases),
      mods: List.unmodifiable(plan.mods),
      weaponPassive: plan.weaponPassive,
      skills: List.unmodifiable(plan.skills),
      target: t == null || t.isEmpty ? null : t.copyWith(stats: const {}),
      best: best.clamp(0, 100),
    );
  }

  bool get isEmpty =>
      weaponTypes.isEmpty &&
      weaponBases.isEmpty &&
      mods.isEmpty &&
      weaponPassive == null &&
      skills.isEmpty &&
      target == null;

  /// Qué cumple [it] (con su base [w]). Misma regla que
  /// `BuildPlanRules.itemFit`: base o tipo del plan, mod con tier ≤ el
  /// mínimo (los fijos de un legendario, tier 0, siempre cumplen), la
  /// pasiva del plan y las habilidades de la base o fusionadas.
  Set<BuildMatch> matches(ItemInstance it, WeaponDef? w) {
    if (isEmpty) return const {};
    final out = <BuildMatch>{};
    if (weaponBases.contains(it.baseId) ||
        (w != null && weaponTypes.contains(w.type))) {
      out.add(BuildMatch.base);
    }
    for (final m in mods) {
      if (it.affixes.any((a) => a.affixId == m.affixId && m.accepts(a.tier))) {
        out.add(BuildMatch.mod);
        break;
      }
    }
    if (weaponPassive != null && it.passiveId == weaponPassive) {
      out.add(BuildMatch.pasiva);
    }
    if (skills.any(
        (s) => (w?.skillIds.contains(s) ?? false) || it.extraSkills.contains(s))) {
      out.add(BuildMatch.habilidad);
    }
    return out;
  }

  // ------------------------------------------------------------------
  // JSON (mismas claves que el plan: `types`, `bases`, `mods`, `wp`, `skills`)
  // ------------------------------------------------------------------

  Map<String, Object?> toJson() => {
        if (weaponTypes.isNotEmpty) 'types': weaponTypes,
        if (weaponBases.isNotEmpty) 'bases': weaponBases,
        if (mods.isNotEmpty) 'mods': [for (final m in mods) m.toJson()],
        if (weaponPassive != null) 'wp': weaponPassive,
        if (skills.isNotEmpty) 'skills': skills,
        if (target != null) 'wt': target!.toJson(),
        if (target != null) 'best': best,
      };

  /// Lectura tolerante y acotada (viene de la red): lo que no es del tipo
  /// esperado se ignora; como mucho [maxEntries] por lista e ids de hasta
  /// [maxIdLength] caracteres.
  static BuildWants fromJson(Object? raw) {
    if (raw is! Map) return none;
    bool ok(Object? v) =>
        v is String && v.isNotEmpty && v.length <= maxIdLength;
    List<String> strings(Object? v) {
      if (v is! List) return const [];
      final out = <String>[];
      for (final e in v) {
        if (out.length >= maxEntries) break;
        if (ok(e) && !out.contains(e)) out.add(e as String);
      }
      return List.unmodifiable(out);
    }

    final mods = <ModGoal>[];
    final rawMods = raw['mods'];
    if (rawMods is List) {
      for (final m in rawMods) {
        if (mods.length >= maxEntries) break;
        final g = ModGoal.fromJson(m);
        if (g != null &&
            g.affixId.length <= maxIdLength &&
            !mods.any((x) => x.affixId == g.affixId)) {
          mods.add(g);
        }
      }
    }
    final wp = raw['wp'];
    // Objetivo v2: acotado como lo demás (viene de la red).
    var t = WeaponTarget.fromJson(raw['wt']);
    if (t != null) {
      bool fine(String? v) => v == null || ok(v);
      t = t.copyWith(
        base: () => fine(t!.base) ? t.base : null,
        type: () => fine(t!.type) ? t.type : null,
        passive: () => fine(t!.passive) ? t.passive : null,
        mods: [
          for (final m in t.mods.take(maxEntries))
            if (ok(m.affixId)) m
        ],
        skills: [
          for (final s in t.skills.take(maxEntries))
            if (ok(s)) s
        ],
        stats: const {},
      );
      if (t.isEmpty) t = null;
    }
    final b = raw['best'];
    return BuildWants(
      weaponTypes: strings(raw['types']),
      weaponBases: strings(raw['bases']),
      mods: List.unmodifiable(mods),
      weaponPassive: ok(wp) ? wp as String : null,
      skills: strings(raw['skills']),
      target: t,
      best: t == null || b is! num ? 0 : b.toInt().clamp(0, 100),
    );
  }

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is BuildWants &&
      _listEq(other.weaponTypes, weaponTypes) &&
      _listEq(other.weaponBases, weaponBases) &&
      _listEq(other.mods, mods) &&
      other.weaponPassive == weaponPassive &&
      _listEq(other.skills, skills) &&
      other.target == target &&
      other.best == best;

  @override
  int get hashCode => Object.hash(Object.hashAll(weaponTypes),
      Object.hashAll(weaponBases), Object.hashAll(mods), weaponPassive,
      Object.hashAll(skills), target, best);
}
