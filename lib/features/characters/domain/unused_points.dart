import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/ascension_rules.dart';
import '../../../game_engine/rules/life_tree_rules.dart';
import '../../../game_engine/rules/passive_tree_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';

/// Puntos sin usar de un personaje: de atributos, de árbol y de ascensión
/// (docs/specs/passive_tree_v4.md § 7). Puro: lo usan el aviso del HUD,
/// las pestañas del panel de personaje y el aviso al subir de nivel.
class UnusedPoints {
  const UnusedPoints({
    this.attributes = 0,
    this.tree = 0,
    this.ascension = 0,
    this.companions = const [],
    this.milestone = 0,
    this.oficios = 0,
  });

  /// Hito pendiente (10 o 20; 0 = ninguno; progression_v2.md § 5).
  final int milestone;

  /// Los mismos puntos más los de los compañeros de la party jugando solo
  /// (nombre, total; solo los que tienen; solo_party.md § 6.3).
  UnusedPoints withCompanions(List<(String, int)> list) => UnusedPoints(
        attributes: attributes,
        tree: tree,
        ascension: ascension,
        milestone: milestone,
        oficios: oficios,
        companions: [
          for (final c in list)
            if (c.$2 > 0) c
        ],
      );

  /// Del perfil, con las reglas reales (árbol: `treeLevel`, con Maestría).
  factory UnusedPoints.of(PlayerProfile p, ProgressionRules rules) =>
      UnusedPoints(
        attributes: p.points < 0 ? 0 : p.points,
        // Libres + los de los hitos pendientes (se ganan al elegir).
        tree: rules.treeRules.pointsAvailable(p.treePoints, p.passiveProgress) +
            p.pendingMilestones.fold<int>(
                0, (a, m) => a + PassiveTreeRules.milestonePoints[m]!),
        ascension: _ascension.free(p.ascension).clamp(0, 1 << 20),
        milestone: p.pendingMilestones.isEmpty ? 0 : p.pendingMilestones.first,
        oficios: LifeTreeRules.freeTotal(p),
      );

  static const _ascension = AscensionRules();

  static const none = UnusedPoints();

  final int attributes;
  final int tree;
  final int ascension;

  /// Puntos de los árboles de oficios (life_skill_trees.md § 3).
  final int oficios;

  /// Compañeros con puntos sin usar: (nombre, total).
  final List<(String, int)> companions;

  /// Los de los compañeros, sumados.
  int get companionTotal => companions.fold(0, (a, c) => a + c.$2);

  /// Los del personaje (sin los compañeros).
  int get own => attributes + tree + ascension + oficios;

  int get total => own + companionTotal;

  /// Lo que se reparte desde PERSONAJE (atributos, árbol, compañeros): la
  /// insignia del botón. La ascensión tiene su propio panel y solo va en
  /// el tooltip (v0.20.16).
  int get characterTotal => attributes + tree + oficios + companionTotal;
  bool get any => total > 0;

  static String _n(int n, String what) =>
      '$n punto${n == 1 ? '' : 's'} de $what';

  /// Desglose para el tooltip del HUD (`3 de atributos · 2 de árbol`;
  /// los compañeros: `Leo: 3 puntos`).
  List<String> get parts => [
        ..._ownParts,
        for (final (name, n) in companions)
          '$name: $n punto${n == 1 ? '' : 's'}',
      ];

  List<String> get _ownParts => [
        if (attributes > 0) _n(attributes, 'atributos'),
        if (tree > 0) _n(tree, 'árbol'),
        if (ascension > 0) _n(ascension, 'ascensión'),
        if (oficios > 0) _n(oficios, 'oficios'),
      ];

  /// Texto del aviso al subir de nivel (o al ganar puntos de ascensión):
  /// `Tenés 2 puntos de árbol sin usar · [TAB]`; `null` si no hay nada que
  /// avisar.
  ///
  /// Con compañeros, una parte por cada uno: `Leo tiene 3 puntos sin usar`.
  String? get toastText {
    if (milestone > 0) {
      return '¡Hito del nivel $milestone! Elegí tu keystone en ÁRBOL · [TAB]';
    }
    final p = _ownParts;
    final mates = [
      for (final (name, n) in companions)
        '$name tiene $n punto${n == 1 ? '' : 's'} sin usar',
    ];
    if (p.isEmpty && mates.isEmpty) return null;
    if (p.isEmpty) return '${mates.join(' · ')} · [TAB]';
    final where = attributes > 0 || tree > 0 || oficios > 0 || mates.isNotEmpty
        ? '[TAB]${ascension > 0 ? ' · ascensión: Estatua del Tiempo' : ''}'
        : 'Estatua del Tiempo';
    final list = p.length == 1
        ? p.single
        : '${p.sublist(0, p.length - 1).join(', ')} y ${p.last}';
    return [
      'Tenés $list sin usar',
      ...mates,
      where,
    ].join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is UnusedPoints &&
      other.attributes == attributes &&
      other.tree == tree &&
      other.ascension == ascension &&
      other.milestone == milestone &&
      _sameList(other.companions, companions);

  static bool _sameList(List<(String, int)> a, List<(String, int)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(
      attributes, tree, ascension, milestone, Object.hashAll(companions));

  @override
  String toString() =>
      'UnusedPoints($attributes, $tree, $ascension, $companions)';
}
