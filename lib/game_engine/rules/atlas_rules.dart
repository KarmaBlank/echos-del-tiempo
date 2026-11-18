import '../data/eco_catalog.dart';
import '../models/atlas.dart';

/// Lo que ganó una cuenta al completar un Eco.
typedef AtlasGain = ({AtlasProgress progress, int points, List<String> keys});

/// Reglas del Atlas del Tiempo (docs/specs/ecos_atlas.md § 5). Puras.
class AtlasRules {
  const AtlasRules({this.nodes = kAtlasNodes});

  final List<AtlasNodeDef> nodes;

  static const rootId = 'origen';

  AtlasNodeDef? node(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // Puntos
  // ------------------------------------------------------------------

  /// Puntos de una "primera vez" (`t<n>`, `z<n>`, `b<n>`): 1, o 2 los
  /// tiers 9–16.
  static int pointsFor(String key) {
    if (key.startsWith('t')) {
      final t = int.tryParse(key.substring(1)) ?? 0;
      return t >= 9 ? 2 : 1;
    }
    return 1;
  }

  /// Máximo de puntos que se pueden ganar (todas las primeras veces).
  static int get maxPoints {
    var t = 0;
    for (var i = 1; i <= 16; i++) {
      t += pointsFor('t$i');
    }
    return t + 10 + 10;
  }

  int earned(AtlasProgress p) => p.done.fold(0, (a, k) => a + pointsFor(k));

  int spent(AtlasProgress p) =>
      p.nodes.fold(0, (a, id) => a + (node(id)?.cost ?? 0));

  int free(AtlasProgress p) => earned(p) - spent(p);

  /// Las claves de un Eco completado (tier, zona, jefe).
  static List<String> keysOf(
          {required int tier, required int zone, required int boss}) =>
      ['t$tier', 'z$zone', 'b$boss'];

  /// Anota un Eco completado: las claves nuevas dan puntos.
  AtlasGain complete(AtlasProgress p,
      {required int tier, required int zone, required int boss}) {
    final fresh = [
      for (final k in keysOf(tier: tier, zone: zone, boss: boss))
        if (!p.done.contains(k)) k,
    ];
    if (fresh.isEmpty) return (progress: p, points: 0, keys: const []);
    return (
      progress: p.copyWith(done: {...p.done, ...fresh}),
      points: fresh.fold(0, (a, k) => a + pointsFor(k)),
      keys: fresh,
    );
  }

  // ------------------------------------------------------------------
  // Nodos
  // ------------------------------------------------------------------

  bool has(AtlasProgress p, String id) => id == rootId || p.nodes.contains(id);

  /// Por qué no se puede tomar [id], o `null` si se puede.
  String? cannotTake(AtlasProgress p, String id) {
    final n = node(id);
    if (n == null) return 'Nodo desconocido';
    if (n.locked) return 'Próximamente';
    if (has(p, id)) return 'Ya lo tenés';
    if (!n.links.any((l) => has(p, l))) return 'No está unido a tu Atlas';
    if (free(p) < n.cost) return 'Faltan puntos (${n.cost})';
    return null;
  }

  AtlasProgress? take(AtlasProgress p, String id) =>
      cannotTake(p, id) == null ? p.copyWith(nodes: [...p.nodes, id]) : null;

  /// Reinicio gratis (regla del dueño): conserva las primeras veces.
  AtlasProgress reset(AtlasProgress p) => p.copyWith(nodes: const []);

  /// Deja solo los nodos válidos, en un orden en que se pudieron tomar
  /// (carga de disco o de la red). Los puntos no se validan acá: si
  /// faltan, se cortan los últimos.
  AtlasProgress sanitize(AtlasProgress p) {
    var out = p.copyWith(nodes: const []);
    final pending = [...p.nodes];
    var progressed = true;
    while (progressed && pending.isNotEmpty) {
      progressed = false;
      for (final id in [...pending]) {
        final next = take(out, id);
        if (next != null) {
          out = next;
          pending.remove(id);
          progressed = true;
        } else if (node(id) == null || node(id)!.locked) {
          pending.remove(id);
        }
      }
    }
    return out;
  }

  /// Efectos de una lista de nodos (los inválidos o bloqueados se ignoran).
  AtlasEffects effects(Iterable<String> ids) {
    final sum = <String, double>{};
    for (final id in ids) {
      final n = node(id);
      if (n == null || n.locked) continue;
      n.effects.forEach((k, v) => sum[k] = (sum[k] ?? 0) + v);
    }
    double d(String k) => sum[k] ?? 0;
    int i(String k) => (sum[k] ?? 0).round();
    return AtlasEffects(
      ecoDrop: d('ecoDrop'),
      zones: {
        for (var z = 1; z <= 10; z++)
          if (d('zone$z') > 0) z,
      },
      quantity: d('quantity'),
      rarity: d('rarity'),
      legendary: d('legendary'),
      bossWeapons: i('bossWeapons'),
      eliteWeapons: i('eliteWeapons'),
      anchor: d('anchor'),
      bossUnique: d('bossUnique'),
      bossEcos: i('bossEcos'),
      freeMods: i('freeMods'),
      modPower: d('modPower'),
      tempered: d('tempered'),
      xp: d('xp'),
      chests: i('chests'),
      extraEco: d('extraEco'),
      tierUp: d('tierUp'),
    );
  }
}
