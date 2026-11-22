import '../data/passive_tree_catalog.dart' show treeV7Id;
import 'attributes.dart';
import 'weapon_target.dart';

export 'weapon_target.dart';

/// Un nodo del árbol por nivel (plan v2 `tl`): desde qué nivel se toma.
class TreeStep {
  const TreeStep(this.level, this.node, {this.milestone});

  final int level;
  final String node;

  /// 10 / 20 si es la keystone de un hito.
  final int? milestone;

  List<Object> toJson() =>
      [level, node, if (milestone != null) milestone!];

  static TreeStep? fromJson(Object? raw) {
    if (raw is! List || raw.length < 2) return null;
    final l = raw[0], n = raw[1];
    if (l is! num || n is! String || n.isEmpty) return null;
    final m = raw.length > 2 && raw[2] is num ? (raw[2] as num).toInt() : null;
    return TreeStep(l.toInt().clamp(1, 70), treeV7Id(n),
        milestone: m == 10 || m == 20 ? m : null);
  }

  @override
  bool operator ==(Object other) =>
      other is TreeStep &&
      other.level == level &&
      other.node == node &&
      other.milestone == milestone;

  @override
  int get hashCode => Object.hash(level, node, milestone);
}

/// Tramo de atributos (plan v2 `as`): de [from] a [to] (cerrado) cada
/// punto va a [attribute].
class AttrSpan {
  const AttrSpan(this.from, this.to, this.attribute, {this.overcap = false});

  final int from;
  final int to;
  final Attribute attribute;

  /// La plantilla pasa el tope blando a propósito.
  final bool overcap;

  int get points => to - from + 1;

  List<Object> toJson() =>
      [from, to, attribute.name.toUpperCase(), if (overcap) true];

  static AttrSpan? fromJson(Object? raw) {
    if (raw is! List || raw.length < 3) return null;
    final f = raw[0], t = raw[1], a = raw[2];
    if (f is! num || t is! num || a is! String) return null;
    final attr = Attribute.values
        .where((x) => x.name == a.toLowerCase())
        .firstOrNull;
    if (attr == null || t < f) return null;
    return AttrSpan(f.toInt(), t.toInt(), attr,
        overcap: raw.length > 3 && raw[3] == true);
  }

  @override
  bool operator ==(Object other) =>
      other is AttrSpan &&
      other.from == from &&
      other.to == to &&
      other.attribute == attribute &&
      other.overcap == overcap;

  @override
  int get hashCode => Object.hash(from, to, attribute, overcap);
}

/// Plan de build de un personaje (docs/specs/build_planner.md § 1-2).
/// Inmutable y serializable; vive en el slot del personaje de la cuenta,
/// nunca en el `PlayerProfile` (no viaja por la red).
class BuildPlan {
  const BuildPlan({
    this.name = '',
    this.notes = '',
    this.templateId,
    this.attributes = const {},
    this.treeNodes = const [],
    this.ascensionId,
    this.ascensionNodes = const [],
    this.weaponTypes = const [],
    this.weaponBases = const [],
    this.mods = const [],
    this.weaponPassive,
    this.chosenType,
    this.skills = const [],
    this.targetLevel,
    this.targetMastery,
    this.checklist = const [],
    this.weaponTargets = const [],
    this.timeline = const [],
    this.attrSpans = const [],
    this.ultActive,
    this.ultUpgrades = const {},
    this.feats = const [],
  });

  /// Versión del formato: 1 = plan v1; 2 = con algún campo de BUILD v2
  /// (build_planner_v2.md § 2.2). Un plan v1 se guarda igual que siempre.
  static const formatVersion = 2;

  int get version => weaponTargets.isEmpty &&
          timeline.isEmpty &&
          attrSpans.isEmpty &&
          ultActive == null &&
          ultUpgrades.isEmpty &&
          feats.isEmpty
      ? 1
      : 2;
  static const empty = BuildPlan();

  /// Largo máximo del nombre y de cada ítem del checklist.
  static const maxName = 32;
  static const maxText = 80;

  /// Largo máximo de las notas.
  static const maxNotes = 600;

  final String name;
  final String notes;

  /// Plantilla con la que se armó (`kBuildTemplates`), si hubo una.
  final String? templateId;

  /// Objetivo de puntos repartidos por atributo.
  final Map<Attribute, int> attributes;

  /// Nodos del árbol planificados, en el orden en que se marcaron.
  final List<String> treeNodes;
  final String? ascensionId;
  final List<String> ascensionNodes;

  /// Tipos de arma preferidos (`hacha`, `báculo`...).
  final List<String> weaponTypes;

  /// Bases de arma preferidas (ids de `kWeapons`).
  final List<String> weaponBases;
  final List<ModGoal> mods;

  /// Pasiva de arma buscada (`kWeaponPassives`).
  final String? weaponPassive;

  /// Tipo de arma que el jugador eligió para el consejo de arma (§ 9.5);
  /// `null` = el ideal. No es una meta (no cuenta en el progreso).
  final String? chosenType;
  final List<String> skills;
  final int? targetLevel;
  final int? targetMastery;
  final List<ChecklistItem> checklist;

  /// Objetivos de arma v2 (hasta [WeaponTarget.maxPerPlan], en orden de
  /// prioridad).
  final List<WeaponTarget> weaponTargets;

  /// Árbol por nivel de la plantilla: desde qué nivel se toma cada nodo
  /// (lo usa "TOMAR SIGUIENTE DEL PLAN").
  final List<TreeStep> timeline;

  /// Tramos de atributos por nivel de la plantilla.
  final List<AttrSpan> attrSpans;

  /// ULT activa sugerida (ultimates_v2.md § 2.1) y nivel de mejora
  /// buscado de cada ULT del repertorio.
  final String? ultActive;
  final Map<String, int> ultUpgrades;

  /// Hazañas buscadas (`kAchievements`).
  final List<String> feats;

  /// Objetivo de arma principal (el primero `main`, si no el primero).
  WeaponTarget? get mainTarget {
    for (final t in weaponTargets) {
      if (t.priority == TargetPriority.main) return t;
    }
    return weaponTargets.isEmpty ? null : weaponTargets.first;
  }

  /// Objetivo de arma vigente al nivel [level]: el de mayor `lvl` que ya
  /// llegó (principal antes que transición si empatan).
  WeaponTarget? targetAt(int level) {
    WeaponTarget? best;
    for (final t in weaponTargets) {
      if (t.priority == TargetPriority.alt || t.level > level) continue;
      if (best == null ||
          t.level > best.level ||
          (t.level == best.level && t.priority == TargetPriority.main)) {
        best = t;
      }
    }
    return best ??
        (weaponTargets.isEmpty
            ? null
            : weaponTargets.reduce((a, b) => a.level <= b.level ? a : b));
  }

  /// Cantidad de metas (sin contar nombre ni notas).
  int get goalCount =>
      attributes.length +
      treeNodes.length +
      (ascensionId == null ? 0 : 1) +
      ascensionNodes.length +
      weaponTypes.length +
      weaponBases.length +
      mods.length +
      (weaponPassive == null ? 0 : 1) +
      skills.length +
      (targetLevel == null ? 0 : 1) +
      (targetMastery == null ? 0 : 1) +
      checklist.length +
      weaponTargets.length +
      (ultActive == null ? 0 : 1) +
      ultUpgrades.length +
      feats.length;

  bool get isEmpty => goalCount == 0 && name.isEmpty && notes.isEmpty;

  BuildPlan copyWith({
    String? name,
    String? notes,
    String? Function()? templateId,
    Map<Attribute, int>? attributes,
    List<String>? treeNodes,
    String? Function()? ascensionId,
    List<String>? ascensionNodes,
    List<String>? weaponTypes,
    List<String>? weaponBases,
    List<ModGoal>? mods,
    String? Function()? weaponPassive,
    String? Function()? chosenType,
    List<String>? skills,
    int? Function()? targetLevel,
    int? Function()? targetMastery,
    List<ChecklistItem>? checklist,
    List<WeaponTarget>? weaponTargets,
    List<TreeStep>? timeline,
    List<AttrSpan>? attrSpans,
    String? Function()? ultActive,
    Map<String, int>? ultUpgrades,
    List<String>? feats,
  }) =>
      BuildPlan(
        name: name ?? this.name,
        notes: notes ?? this.notes,
        templateId: templateId != null ? templateId() : this.templateId,
        attributes: attributes ?? this.attributes,
        treeNodes: treeNodes ?? this.treeNodes,
        ascensionId: ascensionId != null ? ascensionId() : this.ascensionId,
        ascensionNodes: ascensionNodes ?? this.ascensionNodes,
        weaponTypes: weaponTypes ?? this.weaponTypes,
        weaponBases: weaponBases ?? this.weaponBases,
        mods: mods ?? this.mods,
        weaponPassive:
            weaponPassive != null ? weaponPassive() : this.weaponPassive,
        chosenType: chosenType != null ? chosenType() : this.chosenType,
        skills: skills ?? this.skills,
        targetLevel: targetLevel != null ? targetLevel() : this.targetLevel,
        targetMastery:
            targetMastery != null ? targetMastery() : this.targetMastery,
        checklist: checklist ?? this.checklist,
        weaponTargets: weaponTargets ?? this.weaponTargets,
        timeline: timeline ?? this.timeline,
        attrSpans: attrSpans ?? this.attrSpans,
        ultActive: ultActive != null ? ultActive() : this.ultActive,
        ultUpgrades: ultUpgrades ?? this.ultUpgrades,
        feats: feats ?? this.feats,
      );

  /// Próximo nodo del árbol por nivel que falta en [taken] y ya se puede
  /// buscar a [level] (`null` = ninguno).
  String? nextTimelineNode(int level, Set<String> taken) {
    for (final s in timeline) {
      if (s.level > level) break;
      if (!taken.contains(s.node)) return s.node;
    }
    return null;
  }

  /// Atributo del tramo vigente a [level] (`null` = sin tramo).
  Attribute? spanAttributeAt(int level) {
    for (final s in attrSpans) {
      if (level >= s.from && level <= s.to) return s.attribute;
    }
    return null;
  }

  /// Marca o desmarca un nodo del árbol.
  BuildPlan toggleTreeNode(String id) => copyWith(
      treeNodes: treeNodes.contains(id)
          ? [for (final n in treeNodes) if (n != id) n]
          : [...treeNodes, id]);

  /// Agrega [ids] que falten (en orden).
  BuildPlan addTreeNodes(Iterable<String> ids) => copyWith(treeNodes: [
        ...treeNodes,
        for (final id in ids.toSet()) if (!treeNodes.contains(id)) id,
      ]);

  // ------------------------------------------------------------------
  // JSON
  // ------------------------------------------------------------------

  static String _attrKey(Attribute a) => a.name.toUpperCase();

  Map<String, Object?> toJson() => {
        'v': version,
        if (name.isNotEmpty) 'name': name,
        if (notes.isNotEmpty) 'notes': notes,
        if (templateId != null) 'tpl': templateId,
        if (attributes.isNotEmpty)
          'attr': {
            for (final a in Attribute.values)
              if (attributes[a] case final v?) _attrKey(a): v,
          },
        if (treeNodes.isNotEmpty) 'tree': treeNodes,
        if (ascensionId != null) 'asc': ascensionId,
        if (ascensionNodes.isNotEmpty) 'ascN': ascensionNodes,
        if (weaponTypes.isNotEmpty) 'types': weaponTypes,
        if (weaponBases.isNotEmpty) 'bases': weaponBases,
        if (mods.isNotEmpty) 'mods': [for (final m in mods) m.toJson()],
        if (weaponPassive != null) 'wp': weaponPassive,
        if (chosenType != null) 'wantType': chosenType,
        if (skills.isNotEmpty) 'skills': skills,
        if (targetLevel != null) 'lvl': targetLevel,
        if (targetMastery != null) 'ms': targetMastery,
        if (checklist.isNotEmpty)
          'check': [for (final c in checklist) c.toJson()],
        if (weaponTargets.isNotEmpty)
          'wt': [for (final t in weaponTargets) t.toJson()],
        if (timeline.isNotEmpty) 'tl': [for (final s in timeline) s.toJson()],
        if (attrSpans.isNotEmpty)
          'as': [for (final s in attrSpans) s.toJson()],
        if (ultActive != null) 'ult': ultActive,
        if (ultUpgrades.isNotEmpty) 'ultUp': {...ultUpgrades},
        if (feats.isNotEmpty) 'feat': feats,
      };

  /// Lectura tolerante: `null` si [raw] no es un objeto; lo que falta o
  /// tiene otro tipo toma su valor por defecto. No valida ids contra los
  /// catálogos (los desconocidos se conservan y no cuentan).
  static BuildPlan? fromJson(Object? raw) {
    if (raw is! Map) return null;
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    int? integer(Object? v) =>
        v is num && v.isFinite ? v.truncate() : null;
    List<String> strings(Object? v) {
      if (v is! List) return const [];
      final out = <String>[];
      for (final e in v) {
        if (e is String && e.isNotEmpty && !out.contains(e)) out.add(e);
      }
      return out;
    }

    final attrs = <Attribute, int>{};
    final rawAttr = raw['attr'];
    if (rawAttr is Map) {
      for (final a in Attribute.values) {
        final v = integer(rawAttr[_attrKey(a)]);
        if (v != null && v > 0) attrs[a] = v;
      }
    }
    final mods = <ModGoal>[];
    final rawMods = raw['mods'];
    if (rawMods is List) {
      for (final m in rawMods) {
        final g = ModGoal.fromJson(m);
        if (g != null && !mods.any((x) => x.affixId == g.affixId)) mods.add(g);
      }
    }
    final check = <ChecklistItem>[];
    final rawCheck = raw['check'];
    if (rawCheck is List) {
      for (final c in rawCheck) {
        if (ChecklistItem.fromJson(c) case final i?) check.add(i);
      }
    }
    final lvl = integer(raw['lvl']);
    final ms = integer(raw['ms']);
    final targets = <WeaponTarget>[];
    if (raw['wt'] case final List l) {
      for (final t in l) {
        if (targets.length >= WeaponTarget.maxPerPlan) break;
        if (WeaponTarget.fromJson(t) case final w?) targets.add(w);
      }
    }
    final tl = <TreeStep>[
      if (raw['tl'] case final List l)
        for (final s in l)
          if (TreeStep.fromJson(s) case final x?) x,
    ];
    final spans = <AttrSpan>[
      if (raw['as'] case final List l)
        for (final s in l)
          if (AttrSpan.fromJson(s) case final x?) x,
    ];
    final ups = <String, int>{};
    if (raw['ultUp'] case final Map m) {
      for (final e in m.entries) {
        final v = integer(e.value);
        if (e.key is String && v != null && v > 1) {
          ups[e.key as String] = v.clamp(2, 5);
        }
      }
    }
    return BuildPlan(
      name: str(raw['name']) ?? '',
      notes: str(raw['notes']) ?? '',
      templateId: str(raw['tpl']),
      attributes: Map.unmodifiable(attrs),
      // Ids del árbol v6 fusionados → v7 (progression_v2.md § 7).
      treeNodes: [
        for (final id in {for (final s in strings(raw['tree'])) treeV7Id(s)}) id
      ],
      ascensionId: str(raw['asc']),
      ascensionNodes: strings(raw['ascN']),
      weaponTypes: strings(raw['types']),
      weaponBases: strings(raw['bases']),
      mods: List.unmodifiable(mods),
      weaponPassive: str(raw['wp']),
      chosenType: str(raw['wantType']),
      skills: strings(raw['skills']),
      targetLevel: lvl != null && lvl > 0 ? lvl : null,
      targetMastery: ms != null && ms > 0 ? ms : null,
      checklist: List.unmodifiable(check),
      weaponTargets: List.unmodifiable(targets),
      timeline: List.unmodifiable(tl),
      attrSpans: List.unmodifiable(spans),
      ultActive: str(raw['ult']),
      ultUpgrades: Map.unmodifiable(ups),
      feats: strings(raw['feat']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BuildPlan && _eq(toJson(), other.toJson());

  @override
  int get hashCode => Object.hash(name, goalCount, templateId);

  static bool _eq(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_eq(a[k], b[k])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_eq(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}

/// Mod buscado: un afijo con tier mínimo (T1 es el mejor; `minTier` 5
/// acepta cualquiera de T1 a T5).
class ModGoal {
  const ModGoal(this.affixId, [this.minTier = 5]);

  final String affixId;
  final int minTier;

  /// Un tier tirado cumple: los mods fijos de un legendario (tier 0)
  /// siempre cumplen.
  bool accepts(int tier) => tier <= minTier;

  List<Object> toJson() => [affixId, minTier];

  static ModGoal? fromJson(Object? raw) {
    if (raw is! List || raw.isEmpty || raw[0] is! String) return null;
    final id = raw[0] as String;
    if (id.isEmpty) return null;
    final t = raw.length > 1 && raw[1] is num ? (raw[1] as num).toInt() : 5;
    return ModGoal(id, t.clamp(1, 5));
  }

  @override
  bool operator ==(Object other) =>
      other is ModGoal && other.affixId == affixId && other.minTier == minTier;

  @override
  int get hashCode => Object.hash(affixId, minTier);
}

/// Ítem del checklist libre (se tilda a mano).
class ChecklistItem {
  const ChecklistItem(this.text, {this.done = false});

  final String text;
  final bool done;

  ChecklistItem toggled() => ChecklistItem(text, done: !done);

  List<Object> toJson() => [text, done];

  static ChecklistItem? fromJson(Object? raw) {
    if (raw is! List || raw.isEmpty || raw[0] is! String) return null;
    final t = (raw[0] as String).trim();
    if (t.isEmpty) return null;
    return ChecklistItem(t, done: raw.length > 1 && raw[1] == true);
  }

  @override
  bool operator ==(Object other) =>
      other is ChecklistItem && other.text == text && other.done == done;

  @override
  int get hashCode => Object.hash(text, done);
}
