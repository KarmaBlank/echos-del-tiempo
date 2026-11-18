import 'dart:math' as math;

import '../models/passive_tree.dart';

/// Versión del árbol que guarda el perfil (`tv`). Un perfil con una
/// versión menor se migra al cargarlo (passive_tree_v3.md § 11).
const kPassiveTreeVersion = 3;

/// Árbol de pasivas v3: 4 inicios, anillo central de 12, rutas de clase,
/// 20 clusters de clase con bifurcaciones, 4 puentes híbridos y 4
/// clusters de grupo (352 nodos). Forma, coordenadas e ids exactos en
/// docs/specs/passive_tree_v3.md; todo se genera desde las definiciones
/// de abajo, con ids determinísticos.
final PassiveTreeCatalog kPassiveTree = _build();

/// Ids que existen igual en la v2 y la v3 (mismo id, nombre y efecto):
/// el anillo central y los inicios. La migración desde la v2 conserva
/// solo estos (passive_tree_v3.md § 11).
final Set<String> kTreeIdsStableSinceV2 = {
  for (final (id, _, _, _) in _ring) id,
  for (final c in _classes) 's_${c.short}',
};

typedef _Fx = Map<String, num>;

/// Nodo chico: nombre y efectos.
typedef _S = (String name, _Fx fx);

/// Notable: nombre, efectos y mecánica.
typedef _N = (String name, _Fx fx, String mech);

/// Keystone: nombre, id de keystone y mecánica (si tiene).
typedef _K = (String name, String key, String? mech);

class _ClassDef {
  const _ClassDef(this.id, this.short, this.angle, this.startName,
      this.startFx, this.r1, this.r2, this.fan);
  final String id, short;
  final double angle;
  final String startName;
  final _Fx startFx;
  final _S r1, r2, fan;
}

/// Cluster de clase: id, nombre, tema, chico A, chico B, notable A,
/// notable B y keystone (passive_tree_v3.md § 4).
typedef _Cluster = (
  String id,
  String name,
  String theme,
  _S a,
  _S b,
  _N na,
  _N nb,
  _K k,
);

/// Puente: id, nombre, tema, chico lado A, chico lado B, híbrido y los
/// 3 notables (`_n1`, `_nl`, `_nr`) (passive_tree_v3.md § 7).
typedef _Bridge = (
  String id,
  String name,
  String theme,
  _S a,
  _S b,
  _S h,
  _N n1,
  _N nl,
  _N nr,
);

/// Cluster de grupo: id, nombre, tema, chico A, chico B y 2 notables
/// (passive_tree_v3.md § 8).
typedef _Group = (String id, String name, String theme, _S a, _S b, _N na, _N nb);

const _classes = <_ClassDef>[
  _ClassDef('guerrero', 'gue', -90, 'Inicio: Guerrero', {'hp': 0.05, 'atk': 0.04},
      ('Disciplina', {'atk': 0.03}), ('Temple', {'hp': 0.03}),
      ('Sendero del Acero', {'atk': 0.02, 'hp': 0.03})),
  _ClassDef('maga', 'mag', 0, 'Inicio: Maga', {'mp': 0.08, 'mag': 0.04},
      ('Estudio', {'mag': 0.03}), ('Reserva Arcana', {'mp': 0.04}),
      ('Sendero Arcano', {'mag': 0.02, 'mp': 0.04})),
  _ClassDef('tirador', 'tir', 90, 'Inicio: Tirador', {'crit': 0.03, 'spd': 0.3},
      ('Ojo Atento', {'crit': 0.015}), ('Paso Ágil', {'spd': 0.15}),
      ('Sendero del Viento', {'crit': 0.01, 'atk': 0.02})),
  _ClassDef('paladin', 'pal', 180, 'Inicio: Paladín', {'hp': 0.06, 'def': 1},
      ('Voto', {'def': 1}), ('Devoción', {'hp': 0.03}),
      ('Sendero Sagrado', {'hp': 0.03, 'heal': 0.03})),
];

/// Clusters por clase, de ángulo menor a mayor (θ − 30° .. θ + 30°).
const Map<String, List<_Cluster>> _clusters = {
  'guerrero': [
    (
      'muralla', 'Muralla', 'defensa y contraataque',
      ('Coraza', {'def': 1}), ('Aguante', {'hp': 0.03}),
      ('Contraataque', {'def': 2}, 'contraataque'),
      ('Represalia', {'hp': 0.03}, 'represalia'),
      ('Golpe Imparable', 'imparable', null),
    ),
    (
      'sangre', 'Sangre', 'robo de vida y poca vida',
      ('Fuerza Bruta', {'atk': 0.03}), ('Vigor', {'hp': 0.03}),
      ('Último Aliento', {'hp': 0.03}, 'ultimoAliento'),
      ('Sed de Sangre', {'atk': 0.03}, 'sedSangre'),
      ('Furia de Sangre', 'furia', null),
    ),
    (
      'quiebre', 'Quiebre', 'quebrar enemigos',
      ('Impacto', {'atk': 0.03}), ('Firmeza', {'hp': 0.03}),
      ('Rompeguardias', {'atk': 0.03}, 'rompeguardias'),
      ('Ensañamiento', {'atk': 0.03}, 'ensanamiento'),
      ('Demoledor', 'demoledor', 'demoledor'),
    ),
    (
      'gritos', 'Gritos', 'ULT y gritos de grupo',
      ('Aliento', {'ult': 0.03}), ('Pulmones', {'hp': 0.03}),
      ('Clamor', {'atk': 0.03}, 'clamor'),
      ('Rugido', {'ult': 0.04}, 'rugido'),
      ('Caudillo', 'caudillo', 'caudillo'),
    ),
    (
      'filo', 'Filo', 'críticos y velocidad',
      ('Filo Agudo', {'crit': 0.015}), ('Pies Ligeros', {'spd': 0.15}),
      ('Frenesí', {'crit': 0.015}, 'frenesi'),
      ('Corte en Cadena', {'atk': 0.03}, 'corteCadena'),
      ('Danza de Cuchillas', 'danza', 'danza'),
    ),
  ],
  'maga': [
    (
      'arcano', 'Arcano', 'maná, ULT y cadenas mágicas',
      ('Concentración', {'mp': 0.04}), ('Afinidad', {'ult': 0.03}),
      ('Arco Voltaico', {'mag': 0.03}, 'arcoVoltaico'),
      ('Eco Arcano', {'mp': 0.04}, 'ecoArcano'),
      ('Mente sobre Materia', 'mente', null),
    ),
    (
      'brasa', 'Brasa', 'quemadura y explosiones',
      ('Ascua', {'mag': 0.03}), ('Reserva', {'mp': 0.04}),
      ('Combustión', {'burn': 1}, 'combustion'),
      ('Choque Térmico', {'mag': 0.03}, 'choqueTermico'),
      ('Tormenta Arcana', 'tormenta', null),
    ),
    (
      'cronos', 'Cronos', 'retrasos y timeline',
      ('Segundero', {'mag': 0.03}), ('Péndulo', {'spd': 0.15}),
      ('Reloj Roto', {'spd': 0.15}, 'relojRoto'),
      ('Paso Compartido', {'spd': 0.15}, 'pasoCompartido'),
      ('Bucle Eterno', 'bucle', 'bucle'),
    ),
    (
      'escarcha', 'Escarcha', 'congelación y control del tiempo',
      ('Escarcha', {'mag': 0.03}), ('Calma Helada', {'spd': 0.15}),
      ('Tiempo Gélido', {'frz': 1}, 'tiempoGelido'),
      ('Fractura', {'mag': 0.03}, 'fractura'),
      ('Alma de Hielo', 'almaHielo', 'almaHielo'),
    ),
    (
      'prisma', 'Prisma', 'elementos combinados',
      ('Facetas', {'mag': 0.02, 'mp': 0.02}), ('Lente', {'hp': 0.03}),
      ('Refracción', {'ult': 0.03}, 'refraccion'),
      ('Catalizador', {'ult': 0.03}, 'catalizador'),
      ('Singularidad', 'singularidad', 'singularidad'),
    ),
  ],
  'tirador': [
    (
      'viento', 'Viento', 'velocidad y ataques extra',
      ('Reflejos', {'spd': 0.15}), ('Ráfaga', {'atk': 0.03}),
      ('Viento a Favor', {'spd': 0.15}, 'vientoFavor'),
      ('Rebote', {'atk': 0.03}, 'rebote'),
      ('Cadena Infinita', 'cadena', 'cadena'),
    ),
    (
      'lluvia', 'Lluvia', 'habilidades a todos',
      ('Carcaj', {'atk': 0.03}), ('Aljaba', {'ult': 0.03}),
      ('Aguacero', {'atk': 0.03}, 'aguacero'),
      ('Esquirlas', {'spd': 0.15}, 'esquirlas'),
      ('Diluvio', 'diluvio', 'diluvio'),
    ),
    (
      'precision', 'Precisión', 'críticos y objetivo marcado',
      ('Puntería', {'crit': 0.015}), ('Tensión', {'atk': 0.03}),
      ('Marca del Cazador', {'crit': 0.015}, 'marcaCazador'),
      ('Punto Débil', {'atk': 0.03}, 'puntoDebil'),
      ('Ojo de Halcón', 'halcon', null),
    ),
    (
      'acecho', 'Acecho', 'marcas y remate',
      ('Rastro', {'crit': 0.01, 'spd': 0.1}), ('Sigilo', {'spd': 0.15}),
      ('Presa Herida', {'crit': 0.015}, 'presaHerida'),
      ('Rematar', {'atk': 0.03}, 'rematar'),
      ('Depredador', 'depredador', 'depredador'),
    ),
    (
      'toxina', 'Toxina', 'veneno y debilitamiento',
      ('Ponzoña', {'atk': 0.03}), ('Resistencia', {'hp': 0.03}),
      ('Debilitar', {'poi': 1}, 'debilitar'),
      ('Plaga Contagiosa', {'atk': 0.03}, 'plagaContagiosa'),
      ('Toxicidad', 'toxicidad', null),
    ),
  ],
  'paladin': [
    (
      'luz', 'Luz', 'Sagrado',
      ('Destello', {'mag': 0.02, 'heal': 0.02}), ('Calidez', {'heal': 0.04}),
      ('Llama Sagrada', {'mag': 0.03}, 'llamaSagrada'),
      ('Resplandor', {'heal': 0.04}, 'resplandor'),
      ('Sol Interior', 'solInterior', 'solInterior'),
    ),
    (
      'juicio', 'Juicio', 'daño sagrado y aturdir',
      ('Celo', {'atk': 0.03}), ('Rigor', {'crit': 0.015}),
      ('Martillo Bendito', {'atk': 0.03}, 'martilloBendito'),
      ('Castigo Divino', {'mag': 0.03}, 'castigoDivino'),
      ('Paladín Inherente', 'inherente', null),
    ),
    (
      'fe', 'Fe', 'curación y regeneración',
      ('Gracia', {'heal': 0.04}), ('Fe', {'hp': 0.03}),
      ('Mano Sanadora', {'heal': 0.05}, 'manoSanadora'),
      ('Plegaria', {'hp': 0.03}, 'plegaria'),
      ('Paladín Creyente', 'creyente', null),
    ),
    (
      'vigilia', 'Vigilia', 'reducción de daño',
      ('Centinela', {'def': 1}), ('Entereza', {'hp': 0.03}),
      ('Guardia Alta', {'def': 1}, 'guardiaAlta'),
      ('Voto de Hierro', {'hp': 0.03}, 'votoHierro'),
      ('Inamovible', 'inamovible', 'inamovible'),
    ),
    (
      'bastion', 'Bastión', 'escudos, protección y provocar',
      ('Templanza', {'def': 1}), ('Firmeza', {'hp': 0.03}),
      ('Guardián', {'def': 2}, 'guardian'),
      ('Desafío', {'hp': 0.03}, 'desafio'),
      ('Égida Eterna', 'egida', 'egida'),
    ),
  ],
};

/// Puentes, uno por par de clases vecinas (en el orden de [_classes]: el
/// puente `i` une la clase `i` con la `i + 1`).
const List<_Bridge> _bridges = [
  (
    'hojaArcana', 'Hoja Arcana', 'híbrido Guerrero–Maga: acero y magia',
    ('Temple Rúnico', {'atk': 0.03}), ('Runa de Filo', {'mag': 0.02, 'ult': 0.02}),
    ('Acero Arcano', {'atk': 0.02, 'mag': 0.02}),
    ('Filo Rúnico', {'atk': 0.02, 'mag': 0.02}, 'filoRunico'),
    ('Hechizo Afilado', {'atk': 0.03}, 'hechizoAfilado'),
    ('Égida Rúnica', {'mag': 0.03}, 'egidaRunica'),
  ),
  (
    'runas', 'Runas', 'híbrido Maga–Tirador: arcano-crítico',
    ('Glifo', {'mag': 0.02, 'ult': 0.02}), ('Mira Rúnica', {'crit': 0.015}),
    ('Runa Certera', {'mag': 0.02, 'crit': 0.01}),
    ('Ojo Arcano', {'crit': 0.015}, 'ojoArcano'),
    ('Sobrecarga', {'ult': 0.03}, 'sobrecarga'),
    ('Disparo Rúnico', {'crit': 0.015}, 'disparoRunico'),
  ),
  (
    'centinela', 'Centinela', 'híbrido Tirador–Paladín: marcas y luz',
    ('Vigía', {'crit': 0.015}), ('Escudo Ligero', {'def': 1}),
    ('Guardia Atenta', {'crit': 0.01, 'hp': 0.03}),
    ('Ojo del Vigía', {'def': 1}, 'vigia'),
    ('Saeta Sagrada', {'crit': 0.015}, 'saetaSagrada'),
    ('Cobertura', {'hp': 0.03}, 'cobertura'),
  ),
  (
    'coloso', 'Coloso', 'híbrido Paladín–Guerrero: tanque',
    ('Muro', {'def': 1}), ('Mole', {'hp': 0.03}),
    ('Coloso', {'hp': 0.03, 'def': 1}),
    ('Piel de Piedra', {'hp': 0.03}, 'pielPiedra'),
    ('Desquite', {'def': 1}, 'desquite'),
    ('Peso Muerto', {'atk': 0.03}, 'pesoMuerto'),
  ),
];

/// Clusters de grupo, en las diagonales −45°, 45°, 135° y 225°.
const List<_Group> _groups = [
  (
    'estandarte', 'Estandarte', 'grupo: más daño para todos',
    ('Asta', {'atk': 0.02, 'mag': 0.02}), ('Hermanos de Armas', {'hp': 0.03}),
    ('Bandera de Guerra', {'atk': 0.02}, 'banderaGuerra'),
    ('Carga Conjunta', {'hp': 0.03}, 'cargaConjunta'),
  ),
  (
    'sintonia', 'Sintonía', 'grupo: ULT y turnos compartidos',
    ('Compás', {'ult': 0.03}), ('Ritmo', {'spd': 0.15}),
    ('Relevo', {'ult': 0.03}, 'relevo'),
    ('A la Carga', {'spd': 0.15}, 'alaCarga'),
  ),
  (
    'vinculo', 'Vínculo', 'grupo: curas y escudos',
    ('Lazo', {'heal': 0.03}), ('Cuidado', {'hp': 0.03}),
    ('Lazo Vital', {'heal': 0.03}, 'lazoVital'),
    ('Escudo Compartido', {'hp': 0.03}, 'escudoCompartido'),
  ),
  (
    'refugio', 'Refugio', 'grupo: menos daño recibido',
    ('Trinchera', {'def': 1}), ('Abrigo', {'hp': 0.03}),
    ('Formación', {'def': 1}, 'formacion'),
    ('Hermandad', {'hp': 0.03}, 'hermandad'),
  ),
];

/// Anillo: id, ángulo, nombre, efectos (iguales a la v2).
const _ring = <(String, double, String, _Fx)>[
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

// ---- Geometría (unidades de árbol, passive_tree_v3.md § 2) ----

const kRingRadius = 2.0;
const kStartRadius = 3.1;
const kRoadRadii = (4.0, 4.9);
const kFanRadius = 6.0;
const kClusterRadius = 7.0;

/// Separación angular entre clusters de una clase.
const kClusterSpread = 15.0;

/// Plantilla de un cluster de clase: sufijo, (u, v), tipo de nodo
/// (`a`/`b` = chico A/B, `na`/`nb` = notable, `k` = keystone).
const _clusterShape = <(String, double, double, String)>[
  ('e1', 0, 0, 'a'),
  ('e2', 0.8, 0, 'a'),
  ('f', 1.6, 0, 'a'),
  ('a1', 2.35, -0.65, 'a'),
  ('a2', 3.15, -0.85, 'a'),
  ('na', 3.95, -0.95, 'na'),
  ('b1', 2.35, 0.65, 'b'),
  ('b2', 3.15, 0.85, 'b'),
  ('nb', 3.95, 0.95, 'nb'),
  ('j', 4.65, 0, 'b'),
  ('k', 5.55, 0, 'k'),
];
const _clusterLinks = [
  ('e1', 'e2'), ('e2', 'f'), ('f', 'a1'), ('a1', 'a2'), ('a2', 'na'), //
  ('f', 'b1'), ('b1', 'b2'), ('b2', 'nb'), ('na', 'j'), ('nb', 'j'),
  ('j', 'k'),
];

/// Plantilla de un puente (`a`/`b` = chico lado A/B, `h` = híbrido).
const _bridgeShape = <(String, double, double, String)>[
  ('a1', 11.6, -1.6, 'a'),
  ('a2', 12.4, -0.8, 'a'),
  ('b1', 11.6, 1.6, 'b'),
  ('b2', 12.4, 0.8, 'b'),
  ('h', 13.2, 0, 'h'),
  ('n1', 14.0, 0, 'n1'),
  ('l1', 14.7, -0.7, 'a'),
  ('l2', 15.4, -1.1, 'a'),
  ('nl', 16.2, -1.3, 'nl'),
  ('r1', 14.7, 0.7, 'b'),
  ('r2', 15.4, 1.1, 'b'),
  ('nr', 16.2, 1.3, 'nr'),
];
const _bridgeLinks = [
  ('a1', 'a2'), ('a2', 'h'), ('b1', 'b2'), ('b2', 'h'), ('h', 'n1'), //
  ('n1', 'l1'), ('l1', 'l2'), ('l2', 'nl'), ('n1', 'r1'), ('r1', 'r2'),
  ('r2', 'nr'),
];

/// Plantilla de un cluster de grupo.
const _groupShape = <(String, double, double, String)>[
  ('e1', 2.9, 0, 'a'),
  ('e2', 3.7, 0, 'a'),
  ('a1', 4.45, -0.45, 'a'),
  ('a2', 5.25, -0.55, 'a'),
  ('na', 6.05, -0.55, 'na'),
  ('b1', 4.45, 0.45, 'b'),
  ('b2', 5.25, 0.55, 'b'),
  ('nb', 6.05, 0.55, 'nb'),
  ('j', 6.75, 0, 'b'),
  ('t', 7.55, 0, 'a'),
];
const _groupLinks = [
  ('e1', 'e2'), ('e2', 'a1'), ('a1', 'a2'), ('a2', 'na'), ('e2', 'b1'), //
  ('b1', 'b2'), ('b2', 'nb'), ('na', 'j'), ('nb', 'j'), ('j', 't'),
];

(double, double) _polar(double r, double deg) {
  final a = deg * math.pi / 180;
  return (r * math.cos(a), r * math.sin(a));
}

/// Punto (u, v) del marco local orientado a [deg] con origen a radio [r0].
(double, double) _local(double r0, double deg, double u, double v) {
  final a = deg * math.pi / 180;
  final r = r0 + u;
  return (
    r * math.cos(a) - v * math.sin(a),
    r * math.sin(a) + v * math.cos(a),
  );
}

PassiveTreeCatalog _build() {
  final nodes = <String, _MutableNode>{};
  final paths = <String, PassivePath>{};

  void add(String id, (double, double) at, String name, _Fx fx, String kind,
      {String? key, String? path, String? mech}) {
    assert(!nodes.containsKey(id), 'id repetido: $id');
    nodes[id] = _MutableNode(id, at.$1, at.$2, name, fx, kind, key, path, mech);
  }

  void link(String a, String b) {
    nodes[a]!.links.add(b);
    nodes[b]!.links.add(a);
  }

  // Anillo central, en ciclo.
  for (final (id, deg, name, fx) in _ring) {
    add(id, _polar(kRingRadius, deg), name, fx, 's');
  }
  for (var i = 0; i < _ring.length; i++) {
    link(_ring[i].$1, _ring[(i + 1) % _ring.length].$1);
  }

  for (final c in _classes) {
    final th = c.angle;
    final sid = 's_${c.short}';
    add(sid, _polar(kStartRadius, th), c.startName, c.startFx, 'st');
    link(sid, 'p_${c.short}');

    // Ruta de clase: r1 → r2 → abanico f1..f5.
    final r1 = '${c.short}_r1', r2 = '${c.short}_r2';
    add(r1, _polar(kRoadRadii.$1, th), c.r1.$1, c.r1.$2, 's');
    add(r2, _polar(kRoadRadii.$2, th), c.r2.$1, c.r2.$2, 's');
    link(sid, r1);
    link(r1, r2);
    for (var i = 0; i < 5; i++) {
      final f = '${c.short}_f${i + 1}';
      add(f, _polar(kFanRadius, th + (i - 2) * kClusterSpread), c.fan.$1,
          c.fan.$2, 's');
      if (i > 0) link('${c.short}_f$i', f);
    }
    link(r2, '${c.short}_f3');

    // Clusters de clase.
    final list = _clusters[c.id]!;
    for (var i = 0; i < list.length; i++) {
      final (pid, pname, theme, a, b, na, nb, ks) = list[i];
      final deg = th + (i - 2) * kClusterSpread;
      final (lx, ly) = _local(kClusterRadius, deg, 5.55 + 1.0, 0);
      paths[pid] = PassivePath(
          id: pid,
          name: pname,
          theme: theme,
          classId: c.id,
          labelX: lx,
          labelY: ly);
      for (final (s, u, v, kind) in _clusterShape) {
        final at = _local(kClusterRadius, deg, u, v);
        final id = '${pid}_$s';
        switch (kind) {
          case 'a':
            add(id, at, a.$1, a.$2, 's', path: pid);
          case 'b':
            add(id, at, b.$1, b.$2, 's', path: pid);
          case 'na' || 'nb':
            final n = kind == 'na' ? na : nb;
            add(id, at, n.$1, n.$2, 'n', path: pid, mech: n.$3);
          default:
            add(id, at, ks.$1, const {'key': 1}, 'k',
                key: ks.$2, path: pid, mech: ks.$3);
        }
      }
      for (final (x, y) in _clusterLinks) {
        link('${pid}_$x', '${pid}_$y');
      }
      link('${c.short}_f${i + 1}', '${pid}_e1');
      // Atajo con el cluster anterior de la misma clase.
      if (i > 0) link('${list[i - 1].$1}_b2', '${pid}_a2');
    }
  }

  // Puentes híbridos: del notable B del último cluster de la clase i al
  // notable A del primero de la clase i + 1.
  for (var i = 0; i < _bridges.length; i++) {
    final (pid, pname, theme, a, b, h, n1, nl, nr) = _bridges[i];
    final ca = _classes[i], cb = _classes[(i + 1) % _classes.length];
    final deg = ca.angle + 45;
    final (lx, ly) = _local(0, deg, 17.2, 0);
    paths[pid] = PassivePath(
        id: pid,
        name: pname,
        theme: theme,
        classId: '${ca.id}+${cb.id}',
        kind: 'puente',
        labelX: lx,
        labelY: ly);
    for (final (s, u, v, kind) in _bridgeShape) {
      final at = _local(0, deg, u, v);
      final id = '${pid}_$s';
      switch (kind) {
        case 'a':
          add(id, at, a.$1, a.$2, 's', path: pid);
        case 'b':
          add(id, at, b.$1, b.$2, 's', path: pid);
        case 'h':
          add(id, at, h.$1, h.$2, 's', path: pid);
        default:
          final n = switch (kind) { 'n1' => n1, 'nl' => nl, _ => nr };
          add(id, at, n.$1, n.$2, 'n', path: pid, mech: n.$3);
      }
    }
    for (final (x, y) in _bridgeLinks) {
      link('${pid}_$x', '${pid}_$y');
    }
    link('${_clusters[ca.id]!.last.$1}_nb', '${pid}_a1');
    link('${_clusters[cb.id]!.first.$1}_na', '${pid}_b1');
  }

  // Clusters de grupo: entre los dos nodos de anillo de su diagonal.
  for (var i = 0; i < _groups.length; i++) {
    final (pid, pname, theme, a, b, na, nb) = _groups[i];
    final deg = _classes[i].angle + 45;
    final (lx, ly) = _local(0, deg, 8.4, 0);
    paths[pid] = PassivePath(
        id: pid,
        name: pname,
        theme: theme,
        classId: 'grupo',
        kind: 'grupo',
        labelX: lx,
        labelY: ly);
    for (final (s, u, v, kind) in _groupShape) {
      final at = _local(0, deg, u, v);
      final id = '${pid}_$s';
      switch (kind) {
        case 'a':
          add(id, at, a.$1, a.$2, 's', path: pid);
        case 'b':
          add(id, at, b.$1, b.$2, 's', path: pid);
        default:
          final n = kind == 'na' ? na : nb;
          add(id, at, n.$1, n.$2, 'n', path: pid, mech: n.$3);
      }
    }
    for (final (x, y) in _groupLinks) {
      link('${pid}_$x', '${pid}_$y');
    }
    // Los nodos de anillo a δ ± 15°: índices 3i + 1 y 3i + 2.
    link(_ring[3 * i + 1].$1, '${pid}_e1');
    link(_ring[3 * i + 2].$1, '${pid}_e1');
  }

  return PassiveTreeCatalog(
    nodes: {for (final n in nodes.values) n.id: n.freeze()},
    startNodeByClass: {for (final c in _classes) c.id: 's_${c.short}'},
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
  final _Fx fx;
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
