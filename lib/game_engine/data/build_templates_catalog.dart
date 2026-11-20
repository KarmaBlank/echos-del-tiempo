import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../models/attributes.dart';
import 'passive_tree_catalog.dart' show treeV7Id;
import '../models/build_plan.dart';

/// Un objetivo del árbol de una plantilla (build_planner_v2.md § 2.1):
/// un nodo (notable o keystone) desde [level], o la keystone de un hito
/// ([milestone] 10 / 20) con [key] y su respaldo [alt]. El camino entre
/// objetivos lo completa `pathTo` al aplicar.
class TemplateTreeEntry {
  const TemplateTreeEntry({
    required this.level,
    this.node,
    this.milestone,
    this.key,
    this.alt,
  });

  final int level;
  final String? node;
  final int? milestone;
  final String? key;
  final String? alt;

  bool get isMilestone => milestone != null;

  Map<String, Object?> toJson() => {
        'lvl': level,
        if (node != null) 'node': node,
        if (milestone != null) 'milestone': milestone,
        if (key != null) 'key': key,
        if (alt != null) 'alt': alt,
      };

  static TemplateTreeEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final l = raw['lvl'];
    final node = raw['node'], ms = raw['milestone'], k = raw['key'];
    final alt = raw['alt'];
    if (l is! num) return null;
    if (ms is num) {
      if (k is! String) return null;
      return TemplateTreeEntry(
          level: l.toInt(),
          milestone: ms.toInt(),
          key: treeV7Id(k),
          alt: alt is String ? treeV7Id(alt) : null);
    }
    if (node is! String || node.isEmpty) return null;
    return TemplateTreeEntry(level: l.toInt(), node: treeV7Id(node));
  }
}

/// Nodo de Maestría de una plantilla: desde el punto de Maestría [ms].
class MasteryStep {
  const MasteryStep(this.ms, this.node);
  final int ms;
  final String node;
  Map<String, Object?> toJson() => {'ms': ms, 'node': node};
}

/// Endgame de una plantilla (build_planner_v2.md § 2.1).
class TemplateEndgame {
  const TemplateEndgame({
    this.mastery = const [],
    this.atlas = const [],
    this.ecoPrefer = const [],
    this.ecoAvoid = const [],
    this.checklist = const [],
  });

  static const none = TemplateEndgame();

  final List<MasteryStep> mastery;

  /// Nodos del Atlas (`kAtlasNodes`) en orden.
  final List<String> atlas;

  /// Mods de Eco (`kEcoMods`) que conviene correr / evitar.
  final List<String> ecoPrefer;
  final List<String> ecoAvoid;
  final List<String> checklist;

  Map<String, Object?> toJson() => {
        if (mastery.isNotEmpty) 'mastery': [for (final m in mastery) m.toJson()],
        if (atlas.isNotEmpty) 'atlas': atlas,
        if (ecoPrefer.isNotEmpty || ecoAvoid.isNotEmpty)
          'ecoMods': {'prefer': ecoPrefer, 'avoid': ecoAvoid},
        if (checklist.isNotEmpty) 'checklist': checklist,
      };
}

/// Plantilla de build v2 (docs/specs/build_planner_v2.md § 2): datos
/// puros, leídos de `assets/data/build_templates.yaml` (o de un archivo
/// importado). Se convierte en plan con `BuildTemplateRules.toPlan`.
class BuildTemplate {
  const BuildTemplate({
    required this.id,
    required this.classId,
    required this.name,
    required this.description,
    this.tags = const [],
    this.difficulty = 1,
    this.tree = const [],
    this.ascensionId,
    this.ascensionOrder = const [],
    this.attributes = const [],
    this.weapons = const [],
    this.ultActive,
    this.ultUpgrades = const {},
    this.feats = const [],
    this.endgame = TemplateEndgame.none,
    this.imported = false,
  });

  final String id;
  final String classId;
  final String name;
  final String description;
  final List<String> tags;

  /// 1 (fácil) a 3.
  final int difficulty;
  final List<TemplateTreeEntry> tree;
  final String? ascensionId;
  final List<String> ascensionOrder;
  final List<AttrSpan> attributes;
  final List<WeaponTarget> weapons;
  final String? ultActive;
  final Map<String, int> ultUpgrades;
  final List<String> feats;
  final TemplateEndgame endgame;

  /// Vino de un archivo importado (no del juego).
  final bool imported;

  /// Plantilla "de grupo" (etiqueta `grupo`).
  bool get isGroup => tags.contains('grupo');

  BuildTemplate asImported() => BuildTemplate(
        id: id,
        classId: classId,
        name: name,
        description: description,
        tags: tags,
        difficulty: difficulty,
        tree: tree,
        ascensionId: ascensionId,
        ascensionOrder: ascensionOrder,
        attributes: attributes,
        weapons: weapons,
        ultActive: ultActive,
        ultUpgrades: ultUpgrades,
        feats: feats,
        endgame: endgame,
        imported: true,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'class': classId,
        'name': name,
        'desc': description,
        if (tags.isNotEmpty) 'tags': tags,
        'difficulty': difficulty,
        if (tree.isNotEmpty) 'tree': [for (final e in tree) e.toJson()],
        if (ascensionId != null)
          'ascension': {'id': ascensionId, 'order': ascensionOrder},
        if (attributes.isNotEmpty)
          'attributes': [
            for (final s in attributes)
              {
                'from': s.from,
                'to': s.to,
                'attr': s.attribute.name.toUpperCase(),
                if (s.overcap) 'overcap': true,
              }
          ],
        if (weapons.isNotEmpty) 'weapons': [for (final w in weapons) w.toJson()],
        if (ultActive != null || ultUpgrades.isNotEmpty)
          'ult': {
            if (ultActive != null) 'active': ultActive,
            if (ultUpgrades.isNotEmpty) 'upgrades': {...ultUpgrades},
          },
        if (feats.isNotEmpty) 'feats': feats,
        if (endgame.toJson().isNotEmpty) 'endgame': endgame.toJson(),
      };
}

/// Lectura y escritura del YAML de plantillas (build_planner_v2.md
/// § 2.2). Dart puro: lo usan el cargador de assets, el import/export y
/// los tests. Lo que no tiene la forma esperada se descarta con un aviso
/// en [BuildTemplateFile.issues]; nunca lanza.
abstract final class BuildTemplateYaml {
  static const version = 2;
  static const assetPath = 'assets/data/build_templates.yaml';
  static const customAssetPath = 'assets/data/build_templates_custom.yaml';
  static final _id = RegExp(r'^[a-z0-9_]{1,48}$');

  /// Tope de plantillas por archivo importado.
  static const maxImport = 40;

  static BuildTemplateFile parse(String raw, {bool imported = false}) {
    final issues = <String>[];
    Object? doc;
    try {
      doc = loadYaml(raw);
    } on Object catch (e) {
      return BuildTemplateFile(const [], ['YAML inválido: $e']);
    }
    final plain = _plain(doc);
    if (plain is! Map) {
      return const BuildTemplateFile([], ['Falta "templates"']);
    }
    final v = plain['version'];
    if (v is num && v.toInt() > version) {
      issues.add('Versión $v más nueva que la del juego ($version)');
    }
    final list = plain['templates'];
    if (list is! List) {
      return BuildTemplateFile(const [], [...issues, 'Falta "templates"']);
    }
    final out = <BuildTemplate>[];
    for (var i = 0; i < list.length; i++) {
      if (imported && out.length >= maxImport) {
        issues.add('Más de $maxImport plantillas: se ignoran las demás');
        break;
      }
      final t = template(list[i], issues, '#${i + 1}');
      if (t == null) continue;
      if (out.any((x) => x.id == t.id)) {
        issues.add('${t.id}: id repetido (se usa la primera)');
        continue;
      }
      out.add(imported ? t.asImported() : t);
    }
    return BuildTemplateFile(out, issues);
  }

  /// Convierte lo leído por `package:yaml` a mapas y listas de Dart.
  static Object? _plain(Object? v) {
    if (v is YamlMap || v is Map) {
      return {
        for (final e in (v as Map).entries) '${e.key}': _plain(e.value),
      };
    }
    if (v is YamlList || v is List) {
      return [for (final x in v as List) _plain(x)];
    }
    return v;
  }

  static List<String> _strings(Object? v) => [
        if (v is List)
          for (final e in v)
            if (e is String && e.isNotEmpty) e,
      ];

  /// Una plantilla del mapa [raw]; `null` (con aviso) si falta lo esencial.
  static BuildTemplate? template(Object? raw, List<String> issues,
      [String where = '']) {
    if (raw is! Map) {
      issues.add('$where: no es un mapa');
      return null;
    }
    final id = raw['id'], cls = raw['class'], name = raw['name'];
    if (id is! String || !_id.hasMatch(id)) {
      issues.add('$where: id inválido');
      return null;
    }
    if (cls is! String || name is! String || name.trim().isEmpty) {
      issues.add('$id: falta class o name');
      return null;
    }
    final tree = <TemplateTreeEntry>[];
    if (raw['tree'] case final List l) {
      for (final e in l) {
        final x = TemplateTreeEntry.fromJson(e);
        if (x == null) {
          issues.add('$id: entrada de árbol inválida');
        } else {
          tree.add(x);
        }
      }
    }
    String? ascId;
    var order = const <String>[];
    if (raw['ascension'] case final Map a) {
      if (a['id'] case final String s when s.isNotEmpty) ascId = s;
      order = _strings(a['order']);
    }
    final spans = <AttrSpan>[];
    if (raw['attributes'] case final List l) {
      for (final e in l) {
        AttrSpan? s;
        if (e is Map) {
          s = AttrSpan.fromJson(
              [e['from'], e['to'], e['attr'], e['overcap'] == true]);
        }
        if (s == null) {
          issues.add('$id: tramo de atributos inválido');
        } else {
          spans.add(s);
        }
      }
    }
    final weapons = <WeaponTarget>[];
    if (raw['weapons'] case final List l) {
      for (final e in l) {
        final w = WeaponTarget.fromJson(e);
        if (w == null) {
          issues.add('$id: arma inválida');
        } else if (weapons.length < WeaponTarget.maxPerPlan) {
          weapons.add(w);
        } else {
          issues.add('$id: más de ${WeaponTarget.maxPerPlan} armas');
        }
      }
    }
    String? ultActive;
    final ups = <String, int>{};
    if (raw['ult'] case final Map u) {
      if (u['active'] case final String s when s.isNotEmpty) ultActive = s;
      if (u['upgrades'] case final Map m) {
        for (final e in m.entries) {
          if (e.value is num) {
            ups['${e.key}'] = (e.value as num).toInt().clamp(2, 5);
          }
        }
      }
    }
    var endgame = TemplateEndgame.none;
    if (raw['endgame'] case final Map e) {
      final mastery = <MasteryStep>[
        if (e['mastery'] case final List l)
          for (final m in l)
            if (m is Map && m['ms'] is num && m['node'] is String)
              MasteryStep((m['ms'] as num).toInt(), m['node'] as String),
      ];
      final eco = e['ecoMods'];
      endgame = TemplateEndgame(
        mastery: mastery,
        atlas: _strings(e['atlas']),
        ecoPrefer: eco is Map ? _strings(eco['prefer']) : const [],
        ecoAvoid: eco is Map ? _strings(eco['avoid']) : const [],
        checklist: [
          for (final c in _strings(e['checklist']))
            c.length > BuildPlan.maxText
                ? c.substring(0, BuildPlan.maxText)
                : c,
        ],
      );
    }
    final diff = raw['difficulty'];
    final desc = raw['desc'];
    return BuildTemplate(
      id: id,
      classId: cls,
      name: name.length > BuildPlan.maxName
          ? name.substring(0, BuildPlan.maxName)
          : name,
      description: desc is String ? desc : '',
      tags: _strings(raw['tags']),
      difficulty: diff is num ? diff.toInt().clamp(1, 3) : 1,
      tree: List.unmodifiable(tree),
      ascensionId: ascId,
      ascensionOrder: List.unmodifiable(order),
      attributes: List.unmodifiable(spans),
      weapons: List.unmodifiable(weapons),
      ultActive: ultActive,
      ultUpgrades: Map.unmodifiable(ups),
      feats: _strings(raw['feats']),
      endgame: endgame,
    );
  }

  /// Archivo YAML con [templates] (para exportar y compartir). Cada
  /// plantilla va en una línea JSON, que también es YAML válido.
  static String write(List<BuildTemplate> templates) => [
        '# Plantillas de BUILD de Ecos del Tiempo (formato $version).',
        '# Se importan desde BUILD > PLANTILLA > IMPORTAR.',
        'version: $version',
        'templates:',
        for (final t in templates) '  - ${jsonEncode(t.toJson())}',
        '',
      ].join('\n');
}

/// Resultado de leer un archivo de plantillas.
class BuildTemplateFile {
  const BuildTemplateFile(this.templates, this.issues);
  final List<BuildTemplate> templates;
  final List<String> issues;
}

/// Registro de plantillas del juego: las del YAML del juego, las del
/// archivo opcional del dueño (gana su id) y las importadas en esta
/// sesión. Lo llena el composition root (`BuildTemplateLoader`) o un
/// test; vacío hasta entonces.
abstract final class BuildTemplates {
  static List<BuildTemplate> _game = const [];
  static final List<BuildTemplate> _imported = [];
  static List<String> issues = const [];

  /// Reemplaza las del juego (con [custom] encima por id).
  static void install(List<BuildTemplate> game,
      {List<BuildTemplate> custom = const [], List<String> issues = const []}) {
    final byId = {for (final t in game) t.id: t};
    for (final t in custom) {
      byId[t.id] = t;
    }
    _game = List.unmodifiable(byId.values);
    BuildTemplates.issues = List.unmodifiable(issues);
  }

  /// Suma las importadas (un id repetido reemplaza a la importada vieja;
  /// nunca a una del juego: esa se renombra con `_imp`).
  static List<BuildTemplate> addImported(List<BuildTemplate> list) {
    final added = <BuildTemplate>[];
    for (final t in list) {
      var x = t;
      if (_game.any((g) => g.id == t.id)) {
        x = BuildTemplateYaml.template(
                {...t.toJson(), 'id': '${t.id}_imp'}, [])!
            .asImported();
      }
      _imported.removeWhere((i) => i.id == x.id);
      _imported.add(x);
      added.add(x);
    }
    return added;
  }

  static void clearImported() => _imported.clear();

  static List<BuildTemplate> get all => [..._game, ..._imported];

  static List<BuildTemplate> forClass(String classId) =>
      [for (final t in all) if (t.classId == classId) t];

  static BuildTemplate? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// Plantillas cargadas (compatibilidad con v1).
List<BuildTemplate> get kBuildTemplates => BuildTemplates.all;

/// Plantillas de una clase, en orden.
List<BuildTemplate> buildTemplatesFor(String classId) =>
    BuildTemplates.forClass(classId);

BuildTemplate? buildTemplate(String id) => BuildTemplates.byId(id);

/// Atributo por su sigla (`FUE`).
Attribute? attributeByShort(String s) {
  for (final a in Attribute.values) {
    if (a.name == s.toLowerCase()) return a;
  }
  return null;
}
