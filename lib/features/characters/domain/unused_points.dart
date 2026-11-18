import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/ascension_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';

/// Puntos sin usar de un personaje: de atributos, de árbol y de ascensión
/// (docs/specs/passive_tree_v4.md § 7). Puro: lo usan el aviso del HUD,
/// las pestañas del panel de personaje y el aviso al subir de nivel.
class UnusedPoints {
  const UnusedPoints({this.attributes = 0, this.tree = 0, this.ascension = 0});

  /// Del perfil, con las reglas reales (árbol: `treeLevel`, con Maestría).
  factory UnusedPoints.of(PlayerProfile p, ProgressionRules rules) =>
      UnusedPoints(
        attributes: p.points < 0 ? 0 : p.points,
        tree: rules.treeRules.pointsAvailable(p.treeLevel, p.passiveProgress),
        ascension: _ascension.free(p.ascension).clamp(0, 1 << 20),
      );

  static const _ascension = AscensionRules();

  static const none = UnusedPoints();

  final int attributes;
  final int tree;
  final int ascension;

  int get total => attributes + tree + ascension;
  bool get any => total > 0;

  static String _n(int n, String what) =>
      '$n punto${n == 1 ? '' : 's'} de $what';

  /// Desglose para el tooltip del HUD (`3 de atributos · 2 de árbol`).
  List<String> get parts => [
        if (attributes > 0) _n(attributes, 'atributos'),
        if (tree > 0) _n(tree, 'árbol'),
        if (ascension > 0) _n(ascension, 'ascensión'),
      ];

  /// Texto del aviso al subir de nivel (o al ganar puntos de ascensión):
  /// `Tenés 2 puntos de árbol sin usar · [C]`; `null` si no hay nada que
  /// avisar.
  String? get toastText {
    final p = parts;
    if (p.isEmpty) return null;
    final where = attributes > 0 || tree > 0
        ? '[C]${ascension > 0 ? ' · ascensión: Estatua del Tiempo' : ''}'
        : 'Estatua del Tiempo';
    final list = p.length == 1
        ? p.single
        : '${p.sublist(0, p.length - 1).join(', ')} y ${p.last}';
    return 'Tenés $list sin usar · $where';
  }

  @override
  bool operator ==(Object other) =>
      other is UnusedPoints &&
      other.attributes == attributes &&
      other.tree == tree &&
      other.ascension == ascension;

  @override
  int get hashCode => Object.hash(attributes, tree, ascension);

  @override
  String toString() => 'UnusedPoints($attributes, $tree, $ascension)';
}
