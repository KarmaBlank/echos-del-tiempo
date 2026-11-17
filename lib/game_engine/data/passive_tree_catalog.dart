import 'dart:math' as math;

import '../models/passive_tree.dart';

/// Versión del árbol que guarda el perfil (`tv`). Un perfil con una
/// versión menor se reinicia gratis al cargarlo (passive_tree_v2.md § 6).
const kPassiveTreeVersion = 2;

/// Árbol de pasivas v2: 4 inicios, anillo central compartido de 12 nodos
/// y 12 caminos de 8 nodos (112 en total). Datos exactos en
/// docs/specs/passive_tree_v2.md.
final PassiveTreeCatalog kPassiveTree = _build();

/// Nodo de un camino: nombre, efectos y mecánica (notables/keystones).
typedef _P = (String name, Map<String, num> fx, String? mech);

/// Definición de un camino: id, nombre, tema, chicos A (1-3), chicos B
/// (4-5), notable 1, notable 2 y keystone (nombre, id de keystone,
/// mecánica si es nueva).
typedef _Path = (
  String id,
  String name,
  String theme,
  _P small1,
  _P small2,
  _P notable1,
  _P notable2,
  (String name, String key, String? mech) keystone,
);

const _classes = <(
  String cls,
  String short,
  double angle,
  String startName,
  Map<String, num>
)>[
  ('guerrero', 'gue', -90, 'Inicio: Guerrero', {'hp': 0.05, 'atk': 0.04}),
  ('maga', 'mag', 0, 'Inicio: Maga', {'mp': 0.08, 'mag': 0.04}),
  ('tirador', 'tir', 90, 'Inicio: Tirador', {'crit': 0.03, 'spd': 0.3}),
  ('paladin', 'pal', 180, 'Inicio: Paladín', {'hp': 0.06, 'def': 1}),
];

/// Caminos por clase, en orden de ángulo (clase −32°, clase, clase +32°).
const Map<String, List<_Path>> _paths = {
  'guerrero': [
    (
      'muralla',
      'Muralla',
      'defensa y contraataque',
      ('Coraza', {'def': 1}, null),
      ('Aguante', {'hp': 0.06}, null),
      ('Contraataque', {'def': 2}, 'contraataque'),
      ('Represalia', {'hp': 0.06}, 'represalia'),
      ('Golpe Imparable', 'imparable', null)
    ),
    (
      'sangre',
      'Sangre',
      'robo de vida y poca vida',
      ('Fuerza Bruta', {'atk': 0.06}, null),
      ('Vigor', {'hp': 0.06}, null),
      ('Último Aliento', {'hp': 0.05}, 'ultimoAliento'),
      ('Sed de Sangre', {'atk': 0.06}, 'sedSangre'),
      ('Furia de Sangre', 'furia', null)
    ),
    (
      'filo',
      'Filo',
      'críticos y velocidad',
      ('Filo Agudo', {'crit': 0.03}, null),
      ('Pies Ligeros', {'spd': 0.3}, null),
      ('Frenesí', {'crit': 0.03}, 'frenesi'),
      ('Corte en Cadena', {'atk': 0.05}, 'corteCadena'),
      ('Danza de Cuchillas', 'danza', 'danza')
    ),
  ],
  'maga': [
    (
      'arcano',
      'Arcano',
      'maná, ULT y cadenas mágicas',
      ('Concentración', {'mp': 0.08}, null),
      ('Afinidad', {'ult': 0.06}, null),
      ('Arco Voltaico', {'mag': 0.06}, 'arcoVoltaico'),
      ('Eco Arcano', {'mp': 0.10}, 'ecoArcano'),
      ('Mente sobre Materia', 'mente', null)
    ),
    (
      'brasa',
      'Brasa',
      'quemadura y explosiones',
      ('Ascua', {'mag': 0.06}, null),
      ('Reserva', {'mp': 0.08}, null),
      ('Combustión', {'burn': 1}, 'combustion'),
      ('Choque Térmico', {'mag': 0.06}, 'choqueTermico'),
      ('Tormenta Arcana', 'tormenta', null)
    ),
    (
      'escarcha',
      'Escarcha',
      'congelación y control del tiempo',
      ('Escarcha', {'mag': 0.05}, null),
      ('Calma Helada', {'spd': 0.3}, null),
      ('Tiempo Gélido', {'frz': 1}, 'tiempoGelido'),
      ('Fractura', {'mag': 0.06}, 'fractura'),
      ('Alma de Hielo', 'almaHielo', 'almaHielo')
    ),
  ],
  'tirador': [
    (
      'viento',
      'Viento',
      'velocidad y ataques extra',
      ('Reflejos', {'spd': 0.3}, null),
      ('Ráfaga', {'atk': 0.05}, null),
      ('Viento a Favor', {'spd': 0.4}, 'vientoFavor'),
      ('Rebote', {'atk': 0.05}, 'rebote'),
      ('Cadena Infinita', 'cadena', 'cadena')
    ),
    (
      'precision',
      'Precisión',
      'críticos y objetivo marcado',
      ('Puntería', {'crit': 0.03}, null),
      ('Tensión', {'atk': 0.05}, null),
      ('Marca del Cazador', {'crit': 0.03}, 'marcaCazador'),
      ('Punto Débil', {'atk': 0.05}, 'puntoDebil'),
      ('Ojo de Halcón', 'halcon', null)
    ),
    (
      'toxina',
      'Toxina',
      'veneno y debilitamiento',
      ('Ponzoña', {'atk': 0.05}, null),
      ('Resistencia', {'hp': 0.05}, null),
      ('Debilitar', {'poi': 1}, 'debilitar'),
      ('Plaga Contagiosa', {'atk': 0.05}, 'plagaContagiosa'),
      ('Toxicidad', 'toxicidad', null)
    ),
  ],
  'paladin': [
    (
      'juicio',
      'Juicio',
      'daño sagrado y aturdir',
      ('Celo', {'atk': 0.06}, null),
      ('Rigor', {'crit': 0.02}, null),
      ('Martillo Bendito', {'atk': 0.05}, 'martilloBendito'),
      ('Castigo Divino', {'mag': 0.06}, 'castigoDivino'),
      ('Paladín Inherente', 'inherente', null)
    ),
    (
      'fe',
      'Fe',
      'curación y regeneración',
      ('Gracia', {'heal': 0.08}, null),
      ('Fe', {'hp': 0.06}, null),
      ('Mano Sanadora', {'heal': 0.10}, 'manoSanadora'),
      ('Plegaria', {'hp': 0.06}, 'plegaria'),
      ('Paladín Creyente', 'creyente', null)
    ),
    (
      'bastion',
      'Bastión',
      'escudos, protección y provocar',
      ('Templanza', {'def': 1}, null),
      ('Firmeza', {'hp': 0.06}, null),
      ('Guardián', {'def': 2}, 'guardian'),
      ('Desafío', {'hp': 0.08}, 'desafio'),
      ('Égida Eterna', 'egida', 'egida')
    ),
  ],
};

/// Anillo: id, ángulo, nombre, efectos (passive_tree_v2.md § 1).
const _ring = <(String, double, String, Map<String, num>)>[
  ('p_gue', -90, 'Umbral de Acero', {'atk': 0.04}),
  ('r_gm1', -60, 'Equilibrio', {'hp': 0.04, 'mp': 0.04}),
  ('r_gm2', -30, 'Equilibrio', {'hp': 0.04, 'mp': 0.04}),
  ('p_mag', 0, 'Umbral Arcano', {'mag': 0.04}),
  ('r_mt1', 30, 'Fluidez', {'ult': 0.04, 'spd': 0.2}),
  ('r_mt2', 60, 'Fluidez', {'ult': 0.04, 'spd': 0.2}),
  ('p_tir', 90, 'Umbral del Viento', {'crit': 0.02}),
  ('r_tp1', 120, 'Guardia', {'def': 1, 'crit': 0.02}),
  ('r_tp2', 150, 'Guardia', {'def': 1, 'crit': 0.02}),
  ('p_pal', 180, 'Umbral Sagrado', {'def': 1}),
  ('r_pg1', 210, 'Aguante', {'hp': 0.06}),
  ('r_pg2', 240, 'Aguante', {'hp': 0.06}),
];

/// Radios y ángulos del dibujo (unidades de árbol).
const kRingRadius = 1.5;
const kStartRadius = 2.5;
const kPathFirstRadius = 3.4;
const kPathStep = 0.8;
const kPathSpread = 32.0;

PassiveTreeCatalog _build() {
  final nodes = <String, _MutableNode>{};
  (double, double) polar(double r, double deg) {
    final a = deg * math.pi / 180;
    return (r * math.cos(a), r * math.sin(a));
  }

  void add(String id, double r, double deg, String name, Map<String, num> fx,
      String kind,
      {String? key, String? path, String? mech}) {
    final (x, y) = polar(r, deg);
    nodes[id] = _MutableNode(id, x, y, name, fx, kind, key, path, mech);
  }

  void link(String a, String b) {
    nodes[a]!.links.add(b);
    nodes[b]!.links.add(a);
  }

  // Anillo central, en ciclo.
  for (final (id, deg, name, fx) in _ring) {
    add(id, kRingRadius, deg, name, fx, 's');
  }
  for (var i = 0; i < _ring.length; i++) {
    link(_ring[i].$1, _ring[(i + 1) % _ring.length].$1);
  }

  final paths = <String, PassivePath>{};
  for (final (cls, short, angle, startName, startFx) in _classes) {
    final sid = 's_$short';
    add(sid, kStartRadius, angle, startName, startFx, 'st');
    link(sid, 'p_$short');
    final list = _paths[cls]!;
    for (var k = 0; k < list.length; k++) {
      final (pid, pname, theme, a, b, n1, n2, ks) = list[k];
      paths[pid] =
          PassivePath(id: pid, name: pname, theme: theme, classId: cls);
      final deg = angle + (k - 1) * kPathSpread;
      final seq = <(String, _P, String)>[
        ('${pid}_1', a, 's'),
        ('${pid}_2', a, 's'),
        ('${pid}_3', a, 's'),
        ('${pid}_n1', n1, 'n'),
        ('${pid}_4', b, 's'),
        ('${pid}_5', b, 's'),
        ('${pid}_n2', n2, 'n'),
      ];
      var prev = sid;
      for (var i = 0; i < seq.length; i++) {
        final (id, (name, fx, mech), kind) = seq[i];
        add(id, kPathFirstRadius + kPathStep * i, deg, name, fx, kind,
            path: pid, mech: mech);
        link(prev, id);
        prev = id;
      }
      final (kname, key, kmech) = ks;
      add('${pid}_k', kPathFirstRadius + kPathStep * 7, deg, kname,
          const {'key': 1}, 'k',
          key: key, path: pid, mech: kmech);
      link(prev, '${pid}_k');
    }
  }

  return PassiveTreeCatalog(
    nodes: {for (final n in nodes.values) n.id: n.freeze()},
    startNodeByClass: const {
      'guerrero': 's_gue',
      'maga': 's_mag',
      'tirador': 's_tir',
      'paladin': 's_pal',
    },
    exclusions: const {'fe_k': 'juicio_k', 'juicio_k': 'fe_k'},
    paths: paths,
  );
}

class _MutableNode {
  _MutableNode(this.id, this.x, this.y, this.name, this.fx, this.kind, this.key,
      this.path, this.mech);
  final String id;
  final double x, y;
  final String name;
  final Map<String, num> fx;
  final String kind;
  final String? key;
  final String? path;
  final String? mech;
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
        pathId: path,
        mechanicId: mech,
      );
}
