import '../data/passive_tree_catalog.dart';
import '../models/passive_tree.dart';
import 'passive_tree_rules.dart';

/// Migra los nodos tomados guardados con el árbol [fromVersion] al árbol
/// actual (docs/specs/passive_tree_v3.md § 11). Devuelve los que se
/// conservan, en orden; el resto se devuelve como puntos (reinicio
/// gratis). Nunca falla: los ids desconocidos se descartan.
///
/// - Versión actual (o futura): sin cambios (los valida `normalize`).
/// - v2: solo los ids que existen igual en la v3 (anillo e inicios,
///   [kTreeIdsStableSinceV2]), si siguen conectados en el orden tomado.
/// - v1 o sin versión: nada.
List<String> migrateTreeIds(String classId, List<String> ids, int fromVersion,
    {PassiveTreeCatalog? catalog}) {
  if (fromVersion >= kPassiveTreeVersion) return ids;
  if (fromVersion < 2) return const [];
  final tree = catalog ?? kPassiveTree;
  final cls = tree.startNodeByClass.containsKey(classId) ? classId : 'guerrero';
  final rules = PassiveTreeRules(tree);
  final kept = <String>[];
  for (final id in ids) {
    if (!kTreeIdsStableSinceV2.contains(id)) continue;
    // Sin tope de puntos: el nivel real lo aplica `normalize`.
    if (rules.canTake(cls, 1 << 20, PlayerPassiveProgress(kept), id)) {
      kept.add(id);
    }
  }
  return kept;
}
