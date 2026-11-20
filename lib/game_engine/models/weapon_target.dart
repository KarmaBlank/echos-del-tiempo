import 'build_plan.dart';
import 'item.dart';
import 'upgrade_stat.dart';

/// Prioridad de un objetivo de arma (docs/specs/build_planner_v2.md § 1.2).
enum TargetPriority {
  main('main', 'principal'),
  transition('transition', 'de transición'),
  alt('alt', 'alternativa');

  const TargetPriority(this.key, this.label);

  /// Clave del YAML / JSON.
  final String key;
  final String label;

  static TargetPriority byKey(Object? k) {
    for (final p in values) {
      if (p.key == k) return p;
    }
    return main;
  }
}

/// Estadísticas mínimas que puede pedir un objetivo de arma, con su
/// clave de YAML / JSON. `crit` va en puntos de porcentaje.
const kTargetStats = {
  'atk': 'ATQ',
  'mag': 'MAG',
  'crit': 'crítico',
  'spd': 'velocidad',
  'def': 'DEF',
  'hp': 'vida',
};

/// Objetivo de arma completo de un plan v2 (build_planner_v2.md § 1.2):
/// base o tipo, rareza mínima, ranuras, mods con tier, pasiva con nivel,
/// habilidades, nivel de objeto, estadísticas mínimas y forja. Inmutable;
/// lo que no se pide queda `null` / vacío y no cuenta para el %.
class WeaponTarget {
  const WeaponTarget({
    this.priority = TargetPriority.main,
    this.level = 1,
    this.base,
    this.type,
    this.rarity,
    this.slots,
    this.mods = const [],
    this.passive,
    this.passiveLevel = 1,
    this.skills = const [],
    this.itemLevel,
    this.stats = const {},
    this.forge = const {},
    this.keepQuebrar = true,
  });

  /// Hasta 3 objetivos por plan.
  static const maxPerPlan = 3;

  final TargetPriority priority;

  /// Desde qué nivel del personaje se busca.
  final int level;

  /// Id de base (`kWeapons`); `null` = cualquier base del [type].
  final String? base;
  final String? type;
  final Rarity? rarity;

  /// Ranuras de mods mínimas (cupo de la rareza).
  final int? slots;
  final List<ModGoal> mods;
  final String? passive;
  final int passiveLevel;
  final List<String> skills;
  final int? itemLevel;

  /// Mínimos con el arma equipada (claves de [kTargetStats]).
  final Map<String, int> stats;
  final Map<UpgradeStat, int> forge;

  /// Conservar la ranura de Quebrar (loot.md § 16.3).
  final bool keepQuebrar;

  int get forgeTotal => forge.values.fold(0, (a, b) => a + b);

  bool get isEmpty =>
      base == null &&
      type == null &&
      rarity == null &&
      slots == null &&
      mods.isEmpty &&
      passive == null &&
      skills.isEmpty &&
      itemLevel == null &&
      stats.isEmpty &&
      forge.isEmpty;

  WeaponTarget copyWith({
    TargetPriority? priority,
    int? level,
    String? Function()? base,
    String? Function()? type,
    Rarity? Function()? rarity,
    int? Function()? slots,
    List<ModGoal>? mods,
    String? Function()? passive,
    int? passiveLevel,
    List<String>? skills,
    int? Function()? itemLevel,
    Map<String, int>? stats,
    Map<UpgradeStat, int>? forge,
    bool? keepQuebrar,
  }) =>
      WeaponTarget(
        priority: priority ?? this.priority,
        level: level ?? this.level,
        base: base != null ? base() : this.base,
        type: type != null ? type() : this.type,
        rarity: rarity != null ? rarity() : this.rarity,
        slots: slots != null ? slots() : this.slots,
        mods: mods ?? this.mods,
        passive: passive != null ? passive() : this.passive,
        passiveLevel: passiveLevel ?? this.passiveLevel,
        skills: skills ?? this.skills,
        itemLevel: itemLevel != null ? itemLevel() : this.itemLevel,
        stats: stats ?? this.stats,
        forge: forge ?? this.forge,
        keepQuebrar: keepQuebrar ?? this.keepQuebrar,
      );

  // ------------------------------------------------------------------
  // JSON / YAML (misma forma; build_planner_v2.md § 2.2)
  // ------------------------------------------------------------------

  static const _forgeYaml = {
    UpgradeStat.pow: 'power',
    UpgradeStat.crit: 'crit',
    UpgradeStat.spd: 'speed',
    UpgradeStat.def: 'defense',
  };

  Map<String, Object?> toJson() => {
        'priority': priority.key,
        'lvl': level,
        if (base != null) 'base': base,
        if (type != null) 'type': type,
        if (rarity != null) 'rarity': rarity!.name,
        if (slots != null) 'slots': slots,
        if (itemLevel != null) 'ilvl': itemLevel,
        if (mods.isNotEmpty) 'mods': [for (final m in mods) m.toJson()],
        if (passive != null) 'passive': [passive, passiveLevel],
        if (skills.isNotEmpty) 'skills': skills,
        if (stats.isNotEmpty) 'stats': {...stats},
        if (forge.isNotEmpty)
          'forge': {
            for (final s in UpgradeStat.values)
              if ((forge[s] ?? 0) > 0) _forgeYaml[s]!: forge[s],
          },
        if (!keepQuebrar) 'keepQuebrar': false,
      };

  /// Lectura tolerante (JSON del plan o mapa del YAML): `null` si [raw]
  /// no es un mapa; lo que tiene otro tipo se ignora. No valida ids
  /// contra los catálogos (eso es `WeaponTargetRules.validate`).
  static WeaponTarget? fromJson(Object? raw) {
    if (raw is! Map) return null;
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    int? integer(Object? v) => v is num && v.isFinite ? v.truncate() : null;
    final mods = <ModGoal>[];
    if (raw['mods'] case final List l) {
      for (final m in l) {
        final g = ModGoal.fromJson(m);
        if (g != null && !mods.any((x) => x.affixId == g.affixId)) mods.add(g);
      }
    }
    String? passive;
    var pl = 1;
    final rp = raw['passive'];
    if (rp is String && rp.isNotEmpty) {
      passive = rp;
    } else if (rp is List && rp.isNotEmpty && rp[0] is String) {
      passive = rp[0] as String;
      pl = (rp.length > 1 ? integer(rp[1]) ?? 1 : 1).clamp(1, 5);
    }
    final skills = <String>[];
    if (raw['skills'] case final List l) {
      for (final s in l) {
        if (s is String && s.isNotEmpty && !skills.contains(s)) skills.add(s);
      }
    }
    final stats = <String, int>{};
    if (raw['stats'] case final Map m) {
      for (final k in kTargetStats.keys) {
        final v = integer(m[k]);
        if (v != null && v > 0) stats[k] = v;
      }
    }
    final forge = <UpgradeStat, int>{};
    if (raw['forge'] case final Map m) {
      for (final s in UpgradeStat.values) {
        final v = integer(m[_forgeYaml[s]] ?? m[s.key]);
        if (v != null && v > 0) forge[s] = v.clamp(1, 5);
      }
    }
    final r = raw['rarity'];
    final slots = integer(raw['slots']);
    final ilvl = integer(raw['ilvl']);
    return WeaponTarget(
      priority: TargetPriority.byKey(raw['priority']),
      level: (integer(raw['lvl']) ?? 1).clamp(1, 50),
      base: str(raw['base']),
      type: str(raw['type']),
      rarity: r is String ? Rarity.byName(r) : null,
      slots: slots != null && slots > 0 ? slots.clamp(1, 10) : null,
      mods: List.unmodifiable(mods),
      passive: passive,
      passiveLevel: pl,
      skills: List.unmodifiable(skills),
      itemLevel: ilvl != null && ilvl > 0 ? ilvl.clamp(1, 50) : null,
      stats: Map.unmodifiable(stats),
      forge: Map.unmodifiable(forge),
      keepQuebrar: raw['keepQuebrar'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WeaponTarget && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;
}
