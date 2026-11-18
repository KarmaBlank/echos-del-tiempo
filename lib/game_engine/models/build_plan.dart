import 'attributes.dart';

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
    this.skills = const [],
    this.targetLevel,
    this.targetMastery,
    this.checklist = const [],
  });

  static const formatVersion = 1;
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
  final List<String> skills;
  final int? targetLevel;
  final int? targetMastery;
  final List<ChecklistItem> checklist;

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
      checklist.length;

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
    List<String>? skills,
    int? Function()? targetLevel,
    int? Function()? targetMastery,
    List<ChecklistItem>? checklist,
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
        skills: skills ?? this.skills,
        targetLevel: targetLevel != null ? targetLevel() : this.targetLevel,
        targetMastery:
            targetMastery != null ? targetMastery() : this.targetMastery,
        checklist: checklist ?? this.checklist,
      );

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
        'v': formatVersion,
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
        if (skills.isNotEmpty) 'skills': skills,
        if (targetLevel != null) 'lvl': targetLevel,
        if (targetMastery != null) 'ms': targetMastery,
        if (checklist.isNotEmpty)
          'check': [for (final c in checklist) c.toJson()],
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
    return BuildPlan(
      name: str(raw['name']) ?? '',
      notes: str(raw['notes']) ?? '',
      templateId: str(raw['tpl']),
      attributes: Map.unmodifiable(attrs),
      treeNodes: strings(raw['tree']),
      ascensionId: str(raw['asc']),
      ascensionNodes: strings(raw['ascN']),
      weaponTypes: strings(raw['types']),
      weaponBases: strings(raw['bases']),
      mods: List.unmodifiable(mods),
      weaponPassive: str(raw['wp']),
      skills: strings(raw['skills']),
      targetLevel: lvl != null && lvl > 0 ? lvl : null,
      targetMastery: ms != null && ms > 0 ? ms : null,
      checklist: List.unmodifiable(check),
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
