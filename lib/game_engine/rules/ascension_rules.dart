import '../data/ascension_catalog.dart';
import '../models/ascension.dart';
import '../models/player_profile.dart';

/// Reglas puras de la ascensión (docs/specs/ascension.md § 2-3): elegir,
/// tomar nodos, reiniciar y validar lo guardado.
class AscensionRules {
  const AscensionRules();

  /// La ascensión elegida por [p] (si es de su clase).
  AscensionDef? of(PlayerProfile p) {
    final a = kAscensions[p.ascension.id];
    return a != null && a.classId == p.classId ? a : null;
  }

  /// Puntos gastados en nodos.
  int spent(AscensionProgress a) {
    final def = kAscensions[a.id];
    if (def == null) return 0;
    var s = 0;
    for (final id in a.nodes) {
      s += def.node(id)?.cost ?? 0;
    }
    return s;
  }

  int free(AscensionProgress a) => a.earned - spent(a);

  /// Tiene el nodo (la raíz cuenta si eligió esa ascensión).
  bool has(AscensionProgress a, String nodeId) {
    final def = kAscensions[a.id];
    if (def == null) return false;
    return nodeId == def.rootId || a.nodes.contains(nodeId);
  }

  /// Por qué [p] no puede elegir [id] (o `null` si puede).
  String? cannotChoose(PlayerProfile p, String id) {
    final def = kAscensions[id];
    if (def == null) return 'Ascensión desconocida';
    if (def.classId != p.classId) return 'Es de otra clase';
    if (!p.ascension.trials.contains(1)) {
      return 'Superá la Prueba del Tiempo I';
    }
    if (p.ascension.id != null) return 'Ya ascendiste';
    return null;
  }

  PlayerProfile? choose(PlayerProfile p, String id) {
    if (cannotChoose(p, id) != null) return null;
    return p.copyWith(
        ascension: p.ascension.copyWith(id: () => id, nodes: const []));
  }

  /// Por qué [p] no puede tomar [nodeId] (o `null`).
  String? cannotTake(PlayerProfile p, String nodeId) {
    final def = of(p);
    if (def == null) return 'Elegí una ascensión';
    final node = def.node(nodeId);
    if (node == null) return 'Nodo desconocido';
    final a = p.ascension;
    if (has(a, nodeId)) return 'Ya lo tenés';
    if (free(a) < node.cost) {
      return 'Faltan puntos (${free(a)}/${node.cost})';
    }
    if (!node.links.any((l) => has(a, l))) return 'No está conectado';
    return null;
  }

  PlayerProfile? take(PlayerProfile p, String nodeId) {
    if (cannotTake(p, nodeId) != null) return null;
    return p.copyWith(
        ascension: p.ascension.copyWith(nodes: [...p.ascension.nodes, nodeId]));
  }

  /// Reinicio gratis: devuelve los nodos; con [full] además saca la
  /// ascensión (vuelve la clase base). Las Pruebas hechas se quedan.
  PlayerProfile reset(PlayerProfile p, {bool full = false}) => p.copyWith(
      ascension: p.ascension.copyWith(
          nodes: const [], id: full ? () => null : null));

  /// Deja un progreso guardado en un estado válido para la clase
  /// [classId] y el [level] (`ProgressionRules.normalize`).
  AscensionProgress sanitize(String classId, int level, AscensionProgress a) {
    // Pruebas en orden (sin la anterior no cuenta la siguiente).
    final trials = <int>{};
    for (var n = 1; n <= TrialNumbers.count; n++) {
      if (!a.trials.contains(n)) break;
      trials.add(n);
    }
    final def = kAscensions[a.id];
    final id =
        def != null && def.classId == classId && trials.contains(1) ? a.id : null;
    var out = AscensionProgress(trials: trials, id: id);
    if (id == null) return out;
    for (final n in a.nodes) {
      final node = def!.node(n);
      if (node == null || node.root || out.nodes.contains(n)) continue;
      if (free(out) < node.cost || !node.links.any((l) => has(out, l))) {
        continue;
      }
      out = out.copyWith(nodes: [...out.nodes, n]);
    }
    return out;
  }
}

/// Cantidad de Pruebas del Tiempo.
abstract final class TrialNumbers {
  static const count = 3;
}
