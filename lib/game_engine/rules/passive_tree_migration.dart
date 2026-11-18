import '../data/passive_tree_catalog.dart';
import '../models/passive_tree.dart';
import 'passive_tree_rules.dart';

/// Migra los nodos tomados guardados con el árbol [fromVersion] al árbol
/// actual (docs/specs/passive_tree_v3.md § 11 y passive_tree_v4.md § 6).
/// Devuelve los que se conservan, en orden; el resto se devuelve como
/// puntos (reinicio gratis). Nunca falla: los ids desconocidos se
/// descartan.
///
/// - Versión actual (o futura): sin cambios (los valida `normalize`).
/// - v4: todo salvo los nodos que cambiaron de notable en la v5
///   ([kTreeIdsChangedInV5], passive_tree_v4.md § 8.3).
/// - v3: los ids que existen igual en la v4 ([kTreeIdsStableSinceV3]:
///   anillo, inicios, `r1` y abanico, notables A/B y keystones de los
///   clusters de clase, puentes y grupos salvo la punta), si siguen
///   conectados en el orden tomado.
/// - v2: solo anillo e inicios ([kTreeIdsStableSinceV2]), igual.
/// - v1 o sin versión: nada.
List<String> migrateTreeIds(String classId, List<String> ids, int fromVersion,
    {PassiveTreeCatalog? catalog}) {
  if (fromVersion >= kPassiveTreeVersion) return ids;
  if (fromVersion < 2) return const [];
  final tree = catalog ?? kPassiveTree;
  final stable = switch (fromVersion) {
    2 => kTreeIdsStableSinceV2,
    3 => kTreeIdsStableSinceV3,
    _ => tree.nodes.keys.toSet().difference(kTreeIdsChangedInV5),
  };
  final cls = tree.startNodeByClass.containsKey(classId) ? classId : 'guerrero';
  final rules = PassiveTreeRules(tree);
  final kept = <String>[];
  for (final id in ids) {
    if (!stable.contains(id)) continue;
    // Sin tope de puntos: el nivel real lo aplica `normalize`.
    if (rules.canTake(cls, 1 << 20, PlayerPassiveProgress(kept), id)) {
      kept.add(id);
    }
  }
  return kept;
}
