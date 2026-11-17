import '../models/passive_tree.dart';

/// Árbol de pasivas completo — puerto 1:1 del bloque que arma `TREE`,
/// `TREE_START` y `EXCL` en el prototipo (mismas posiciones, nombres,
/// efectos y conexiones). Ver docs/specs/passive_tree.md.
final PassiveTreeCatalog kPassiveTree = _build();

typedef _Node = (String name, Map<String, num> fx, String kind, String? key);

_Node _s(String name, Map<String, num> fx) => (name, fx, 's', null);
_Node _n(String name, Map<String, num> fx) => (name, fx, 'n', null);
_Node _k(String name, String key) => (name, const {'key': 1}, 'k', key);

PassiveTreeCatalog _build() {
  final nodes = <String, _MutableNode>{};
  void add(String id, double x, double y, String name, Map<String, num> fx,
      String kind, String? key) {
    nodes[id] = _MutableNode(id, x, y, name, fx, kind, key);
  }

  void link(String a, String b) {
    nodes[a]!.links.add(b);
    nodes[b]!.links.add(a);
  }

  // Centros de clase (N, E, S, O).
  const dirs = {'gue': (0, -1), 'mag': (1, 0), 'tir': (0, 1), 'pal': (-1, 0)};
  final classes = <String, (String, Map<String, num>, List<_Node>, List<_Node>)>{
    'gue': (
      'Inicio: Guerrero', {'hp': 0.05, 'atk': 0.04},
      [_s('Fuerza', {'atk': 0.08}), _s('Fuerza', {'atk': 0.08}), _n('Brutalidad', {'atk': 0.15, 'crit': 0.05}), _k('Golpe Imparable', 'imparable')],
      [_s('Vigor', {'hp': 0.08}), _s('Coraza', {'def': 2}), _n('Piel de Hierro', {'def': 4, 'hp': 0.10}), _k('Furia de Sangre', 'furia')],
    ),
    'mag': (
      'Inicio: Maga', {'mp': 0.08, 'mag': 0.04},
      [_s('Intelecto', {'mag': 0.08}), _s('Intelecto', {'mag': 0.08}), _n('Erudición', {'mag': 0.15, 'mp': 0.15}), _k('Mente sobre Materia', 'mente')],
      [_s('Concentración', {'mp': 0.10}), _s('Afinidad', {'ult': 0.10}), _n('Piromancia', {'burn': 1, 'frz': 1}), _k('Tormenta Arcana', 'tormenta')],
    ),
    'tir': (
      'Inicio: Tirador', {'crit': 0.03, 'spd': 0.3},
      [_s('Precisión', {'crit': 0.04}), _s('Precisión', {'crit': 0.04}), _n('Ojo Certero', {'crit': 0.08, 'atk': 0.10}), _k('Ojo de Halcón', 'halcon')],
      [_s('Reflejos', {'spd': 0.5}), _s('Reflejos', {'spd': 0.5}), _n('Venenos', {'poi': 1, 'atk': 0.10}), _k('Toxicidad', 'toxicidad')],
    ),
    'pal': (
      'Inicio: Paladín', {'hp': 0.06, 'def': 1},
      [_s('Fe', {'hp': 0.10}), _s('Gracia', {'heal': 0.10}), _n('Devoción', {'heal': 0.20, 'def': 2}), _k('Paladín Creyente', 'creyente')],
      [_s('Templanza', {'def': 2}), _s('Celo', {'atk': 0.08}), _n('Fervor', {'atk': 0.15, 'ult': 0.10}), _k('Paladín Inherente', 'inherente')],
    ),
  };

  classes.forEach((c, def) {
    final (dx, dy) = dirs[c]!;
    final px = -dy, py = dx;
    final sid = 's_$c';
    add(sid, dx * 1.1, dy * 1.1, def.$1, def.$2, 'st', null);
    for (final (br, sg, list) in [('a', 1, def.$3), ('b', -1, def.$4)]) {
      var prev = sid;
      for (var i = 0; i < list.length; i++) {
        final (name, fx, kind, key) = list[i];
        final r = 1.75 + i * 0.62, sp = 0.32 + i * 0.05;
        final id = '${c}_$br$i';
        add(id, dx * r + px * sg * sp * r * 0.55, dy * r + py * sg * sp * r * 0.55,
            name, fx, kind, key);
        link(prev, id);
        prev = id;
      }
    }
  });

  // Puentes entre zonas.
  for (final (id, a, b, x, y, name, fx) in [
    ('b_ne', 'gue', 'mag', 0.85, -0.85, 'Equilibrio', <String, num>{'hp': 0.06, 'mp': 0.06}),
    ('b_se', 'mag', 'tir', 0.85, 0.85, 'Fluidez', <String, num>{'ult': 0.06, 'spd': 0.4}),
    ('b_sw', 'tir', 'pal', -0.85, 0.85, 'Guardia', <String, num>{'def': 2, 'crit': 0.03}),
    ('b_nw', 'pal', 'gue', -0.85, -0.85, 'Aguante', <String, num>{'hp': 0.08}),
  ]) {
    add(id, x, y, name, fx, 's', null);
    link(id, 's_$a');
    link(id, 's_$b');
  }

  return PassiveTreeCatalog(
    nodes: {for (final n in nodes.values) n.id: n.freeze()},
    startNodeByClass: const {
      'guerrero': 's_gue',
      'maga': 's_mag',
      'tirador': 's_tir',
      'paladin': 's_pal',
    },
    exclusions: const {'pal_a3': 'pal_b3', 'pal_b3': 'pal_a3'},
  );
}

class _MutableNode {
  _MutableNode(this.id, this.x, this.y, this.name, this.fx, this.kind, this.key);
  final String id;
  final double x, y;
  final String name;
  final Map<String, num> fx;
  final String kind;
  final String? key;
  final links = <String>[];

  PassiveNode freeze() => PassiveNode(
        id: id,
        x: x,
        y: y,
        name: name,
        effects: fx,
        kind: kind,
        links: List.unmodifiable(links),
        keystoneId: key,
      );
}
