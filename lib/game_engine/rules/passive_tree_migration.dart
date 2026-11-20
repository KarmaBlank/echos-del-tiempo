import '../data/passive_tree_catalog.dart';

/// Migra los nodos tomados guardados con el árbol [fromVersion] al árbol
/// actual. Desde el árbol v7 (progresión v2, `tv` 6; progression_v2.md
/// § 7) cualquier versión anterior se devuelve entera, gratis: los
/// chicos se fusionaron y los puntos cambiaron de valor. Versión actual
/// (o futura): sin cambios (los valida `normalize`).
List<String> migrateTreeIds(String classId, List<String> ids, int fromVersion) {
  if (fromVersion >= kPassiveTreeVersion) return ids;
  return const [];
}
