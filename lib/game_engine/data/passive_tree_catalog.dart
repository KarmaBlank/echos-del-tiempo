import 'dart:math' as math;

import '../models/passive_tree.dart';
import 'passive_tree_v6.dart';

/// Versión del árbol que guarda el perfil (`tv`). Un perfil con una
/// versión menor se migra al cargarlo (passive_tree_v4.md § 6). El árbol
/// v6 (v0.8) solo agrega nodos: los ids de la v5 siguen iguales, así que
/// la versión no cambia (passive_tree_v6.md § 8).
const kPassiveTreeVersion = 5;

/// Árbol de pasivas v6 (v0.8, passive_tree_v6.md): el árbol v5 (4
/// inicios, anillo central de 12, rutas de clase, 20 clusters de clase
/// con 4 notables cada uno, 4 puentes híbridos y 4 clusters de grupo;
/// passive_tree_v4.md) sin tocar, más el anillo exterior: 12 clusters
/// exteriores de clase, 4 puentes elementales y 4 clusters de grupo
/// exteriores (584 nodos, 200 notables, 36 keystones). Forma, coordenadas
/// e ids exactos en los specs; todo se genera desde las definiciones de
/// abajo y de passive_tree_v6.dart, con ids determinísticos.
final PassiveTreeCatalog kPassiveTree = _build();

/// Ids que existen igual en la v2 y la v4 (mismo id, nombre y efecto):
/// el anillo central y los inicios. La migración desde la v2 conserva
/// solo estos (passive_tree_v3.md § 11).
final Set<String> kTreeIdsStableSinceV2 = {
  for (final (id, _, _, _) in _ring) id,
  for (final c in _classes) 's_${c.short}',
};

/// Nodos que cambiaron de notable en el árbol v5 (v0.7, notables de
/// reacción: passive_tree_v4.md § 8): mismo id y posición, otra mecánica.
/// Al migrar desde la v4 se devuelven gratis.
const Set<String> kTreeIdsChangedInV5 = {
  'arcano_n1', 'brasa_n1', 'brasa_nc', 'escarcha_nc', 'prisma_n1', //
  'prisma_nc', 'cronos_nc', 'toxina_nc', 'lluvia_nc', 'runas_nr',
  'hojaArcana_nl', 'estandarte_nt', 'sintonia_nt', 'luz_nc', 'acecho_nc',
};

/// Ids que existen igual en la v3 y la actual (mismo id, tipo, nombre,
/// efectos y mecánica): anillo, inicios, `r1` y abanico de cada ruta, los
/// 2 notables y la keystone de cada cluster de clase, los puentes enteros
/// y los clusters de grupo salvo su punta (passive_tree_v4.md § 6), menos
/// lo que cambió en la v5 (§ 8).
final Set<String> kTreeIdsStableSinceV3 = {
  ...kTreeIdsStableSinceV2,
  for (final c in _classes) ...[
    '${c.short}_r1',
    for (var i = 1; i <= 5; i++) '${c.short}_f$i',
    for (final cl in _clusters[c.id]!)
      for (final s in ['na', 'nb', 'k']) '${cl.$1}_$s',
  ],
  for (final b in _bridges)
    for (final (s, _, _, _) in _bridgeShape) '${b.$1}_$s',
  for (final g in _groups)
    for (final (s, _, _, kind) in _groupShape)
      if (kind != 'nt') '${g.$1}_$s',
}.difference(kTreeIdsChangedInV5);

typedef _Fx = Map<String, num>;

/// Nodo chico: nombre y efectos.
typedef _S = (String name, _Fx fx);

/// Notable: nombre, efectos y mecánica.
typedef _N = (String name, _Fx fx, String mech);

/// Keystone: nombre, id de keystone y mecánica (si tiene).
typedef _K = (String name, String key, String? mech);

class _ClassDef {
  const _ClassDef(this.id, this.short, this.angle, this.startName,
      this.startFx, this.r1, this.fan);
  final String id, short;
  final double angle;
  final String startName;
  final _Fx startFx;
  final _S r1, fan;
}

/// Cluster de clase v4: id, nombre, tema, chico de entrada (`_m1`, `_m2`),
/// chico de rama (`_ma`, `_mb`), notable de entrada (`_n1`), notables A y
/// B de la bifurcación (`_na`, `_nb`, los de la v3), notable de unión
/// (`_nc`) y keystone (passive_tree_v4.md § 2-3).
typedef _Cluster = (
  String id,
  String name,
  String theme,
  _S a,
  _S b,
  _N n1,
  _N na,
  _N nb,
  _N nc,
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

/// Cluster de grupo: id, nombre, tema, chico A, chico B, 2 notables y el
/// notable de la punta (`_nt`, v4) (passive_tree_v3.md § 8 y v4 § 4).
typedef _Group = (
  String id,
  String name,
  String theme,
  _S a,
  _S b,
  _N na,
  _N nb,
  _N nt,
);

const _classes = <_ClassDef>[
  _ClassDef('guerrero', 'gue', -90, 'Inicio: Guerrero', {'hp': 0.05, 'atk': 0.04},
      ('Disciplina', {'atk': 0.03}),
      ('Sendero del Acero', {'atk': 0.02, 'hp': 0.03})),
  _ClassDef('maga', 'mag', 0, 'Inicio: Maga', {'mp': 0.08, 'mag': 0.04},
      ('Estudio', {'mag': 0.03}),
      ('Sendero Arcano', {'mag': 0.02, 'mp': 0.04})),
  _ClassDef('tirador', 'tir', 90, 'Inicio: Tirador', {'crit': 0.03, 'spd': 0.3},
      ('Ojo Atento', {'crit': 0.015}),
      ('Sendero del Viento', {'crit': 0.01, 'atk': 0.02})),
  _ClassDef('paladin', 'pal', 180, 'Inicio: Paladín', {'hp': 0.06, 'def': 1},
      ('Voto', {'def': 1}),
      ('Sendero Sagrado', {'hp': 0.03, 'heal': 0.03})),
];

/// Clusters por clase, de ángulo menor a mayor (θ − 30° .. θ + 30°).
const Map<String, List<_Cluster>> _clusters = {
  'guerrero': [
    (
      'muralla', 'Muralla', 'defensa y contraataque',
      ('Coraza', {'def': 2}), ('Aguante', {'hp': 0.04}),
      ('Rompeolas', {'def': 1}, 'rompeolas'),
      ('Contraataque', {'def': 2}, 'contraataque'),
      ('Represalia', {'hp': 0.03}, 'represalia'),
      ('Coraza de Espinas', {'hp': 0.03}, 'corazaEspinas'),
      ('Golpe Imparable', 'imparable', null),
    ),
    (
      'sangre', 'Sangre', 'robo de vida y poca vida',
      ('Fuerza Bruta', {'atk': 0.05}), ('Vigor', {'hp': 0.04}),
      ('Sangría', {'atk': 0.03}, 'sangriaVital'),
      ('Último Aliento', {'hp': 0.03}, 'ultimoAliento'),
      ('Sed de Sangre', {'atk': 0.03}, 'sedSangre'),
      ('Frenesí Sangriento', {'atk': 0.03}, 'frenesiSangriento'),
      ('Furia de Sangre', 'furia', null),
    ),
    (
      'quiebre', 'Quiebre', 'quebrar enemigos',
      ('Impacto', {'atk': 0.05}), ('Firmeza', {'hp': 0.04}),
      ('Mazazo', {'atk': 0.03}, 'mazazo'),
      ('Rompeguardias', {'atk': 0.03}, 'rompeguardias'),
      ('Ensañamiento', {'atk': 0.03}, 'ensanamiento'),
      ('Brecha', {'atk': 0.03}, 'brecha'),
      ('Demoledor', 'demoledor', 'demoledor'),
    ),
    (
      'gritos', 'Gritos', 'ULT y gritos de grupo',
      ('Aliento', {'ult': 0.05}), ('Pulmones', {'hp': 0.04}),
      ('Arenga', {'ult': 0.03}, 'arenga'),
      ('Clamor', {'atk': 0.03}, 'clamor'),
      ('Rugido', {'ult': 0.04}, 'rugido'),
      ('Estruendo', {'ult': 0.03}, 'estruendo'),
      ('Caudillo', 'caudillo', 'caudillo'),
    ),
    (
      'filo', 'Filo', 'críticos y velocidad',
      ('Filo Agudo', {'crit': 0.02}), ('Pies Ligeros', {'spd': 0.2}),
      ('Estocada Precisa', {'crit': 0.015}, 'estocadaPrecisa'),
      ('Frenesí', {'crit': 0.015}, 'frenesi'),
      ('Corte en Cadena', {'atk': 0.03}, 'corteCadena'),
      ('Desarme', {'spd': 0.15}, 'desarme'),
      ('Danza de Cuchillas', 'danza', 'danza'),
    ),
  ],
  'maga': [
    (
      'arcano', 'Arcano', 'maná, ULT y cadenas mágicas',
      ('Concentración', {'mp': 0.06}), ('Afinidad', {'ult': 0.05}),
      ('Salto Voltaico', {'mp': 0.04}, 'saltoVoltaico'),
      ('Arco Voltaico', {'mag': 0.03}, 'arcoVoltaico'),
      ('Eco Arcano', {'mp': 0.04}, 'ecoArcano'),
      ('Pulso Arcano', {'mag': 0.03}, 'pulsoArcano'),
      ('Mente sobre Materia', 'mente', null),
    ),
    (
      'brasa', 'Brasa', 'quemadura y explosiones',
      ('Ascua', {'mag': 0.045}), ('Reserva', {'mp': 0.06}),
      ('Fundición', {'mp': 0.04}, 'fundicion'),
      ('Combustión', {'burn': 1}, 'combustion'),
      ('Choque Térmico', {'mag': 0.03}, 'choqueTermico'),
      ('Mecha Corta', {'mp': 0.04}, 'mechaCorta'),
      ('Tormenta Arcana', 'tormenta', null),
    ),
    (
      'cronos', 'Cronos', 'retrasos y timeline',
      ('Segundero', {'mag': 0.045}), ('Péndulo', {'spd': 0.2}),
      ('Arena del Tiempo', {'spd': 0.15}, 'arenaTiempo'),
      ('Reloj Roto', {'spd': 0.15}, 'relojRoto'),
      ('Paso Compartido', {'spd': 0.15}, 'pasoCompartido'),
      ('Estasis', {'spd': 0.15}, 'estasis'),
      ('Bucle Eterno', 'bucle', 'bucle'),
    ),
    (
      'escarcha', 'Escarcha', 'congelación y control del tiempo',
      ('Escarcha', {'mag': 0.045}), ('Calma Helada', {'spd': 0.2}),
      ('Frío Penetrante', {'mp': 0.04}, 'frioPenetrante'),
      ('Tiempo Gélido', {'frz': 1}, 'tiempoGelido'),
      ('Fractura', {'mag': 0.03}, 'fractura'),
      ('Cristalizar', {'spd': 0.15}, 'cristalizar'),
      ('Alma de Hielo', 'almaHielo', 'almaHielo'),
    ),
    (
      'prisma', 'Prisma', 'elementos combinados',
      ('Facetas', {'mag': 0.03, 'mp': 0.03}), ('Lente', {'hp': 0.04}),
      ('Rocío Arcano', {'mag': 0.03}, 'rocioArcano'),
      ('Refracción', {'ult': 0.03}, 'refraccion'),
      ('Catalizador', {'ult': 0.03}, 'catalizador'),
      ('Alto Voltaje', {'ult': 0.03}, 'altoVoltaje'),
      ('Singularidad', 'singularidad', 'singularidad'),
    ),
  ],
  'tirador': [
    (
      'viento', 'Viento', 'velocidad y ataques extra',
      ('Reflejos', {'spd': 0.2}), ('Ráfaga', {'atk': 0.05}),
      ('Viento Cortante', {'spd': 0.15}, 'vientoCortante'),
      ('Viento a Favor', {'spd': 0.15}, 'vientoFavor'),
      ('Rebote', {'atk': 0.03}, 'rebote'),
      ('Huracán', {'atk': 0.03}, 'huracan'),
      ('Cadena Infinita', 'cadena', 'cadena'),
    ),
    (
      'lluvia', 'Lluvia', 'habilidades a todos',
      ('Carcaj', {'atk': 0.05}), ('Aljaba', {'ult': 0.05}),
      ('Lluvia Ácida', {'atk': 0.03}, 'lluviaAcida'),
      ('Aguacero', {'atk': 0.03}, 'aguacero'),
      ('Esquirlas', {'spd': 0.15}, 'esquirlas'),
      ('Chaparrón', {'ult': 0.03}, 'chaparron'),
      ('Diluvio', 'diluvio', 'diluvio'),
    ),
    (
      'precision', 'Precisión', 'críticos y objetivo marcado',
      ('Puntería', {'crit': 0.02}), ('Tensión', {'atk': 0.05}),
      ('Tiro a la Cabeza', {'crit': 0.015}, 'tiroALaCabeza'),
      ('Marca del Cazador', {'crit': 0.015}, 'marcaCazador'),
      ('Punto Débil', {'atk': 0.03}, 'puntoDebil'),
      ('Grieta Expuesta', {'atk': 0.03}, 'grietaExpuesta'),
      ('Ojo de Halcón', 'halcon', null),
    ),
    (
      'acecho', 'Acecho', 'marcas, trampas y remate',
      ('Rastro', {'crit': 0.015, 'spd': 0.15}), ('Sigilo', {'spd': 0.2}),
      ('Trampa de Caza', {'atk': 0.03}, 'trampaCaza'),
      ('Presa Herida', {'crit': 0.015}, 'presaHerida'),
      ('Rematar', {'atk': 0.03}, 'rematar'),
      ('Cazador de Bestias', {'spd': 0.15}, 'cazadorBestias'),
      ('Depredador', 'depredador', 'depredador'),
    ),
    (
      'toxina', 'Toxina', 'veneno y debilitamiento',
      ('Ponzoña', {'atk': 0.05}), ('Resistencia', {'hp': 0.04}),
      ('Toxina Paralizante', {'atk': 0.03}, 'toxinaParalizante'),
      ('Debilitar', {'poi': 1}, 'debilitar'),
      ('Plaga Contagiosa', {'atk': 0.03}, 'plagaContagiosa'),
      ('Reguero de Pólvora', {'hp': 0.03}, 'reguero'),
      ('Toxicidad', 'toxicidad', null),
    ),
  ],
  'paladin': [
    (
      'luz', 'Luz', 'Sagrado',
      ('Destello', {'mag': 0.03, 'heal': 0.03}), ('Calidez', {'heal': 0.06}),
      ('Mano Luminosa', {'heal': 0.04}, 'manoLuminosa'),
      ('Llama Sagrada', {'mag': 0.03}, 'llamaSagrada'),
      ('Resplandor', {'heal': 0.04}, 'resplandor'),
      ('Luz Purificadora', {'heal': 0.04}, 'luzPurificadora'),
      ('Sol Interior', 'solInterior', 'solInterior'),
    ),
    (
      'juicio', 'Juicio', 'daño sagrado y aturdir',
      ('Celo', {'atk': 0.05}), ('Rigor', {'crit': 0.02}),
      ('Sentencia', {'atk': 0.03}, 'sentencia'),
      ('Martillo Bendito', {'atk': 0.03}, 'martilloBendito'),
      ('Castigo Divino', {'mag': 0.03}, 'castigoDivino'),
      ('Veredicto', {'atk': 0.03}, 'veredicto'),
      ('Paladín Inherente', 'inherente', null),
    ),
    (
      'fe', 'Fe', 'curación y regeneración',
      ('Gracia', {'heal': 0.06}), ('Fe', {'hp': 0.04}),
      ('Comunión', {'heal': 0.04}, 'comunion'),
      ('Mano Sanadora', {'heal': 0.05}, 'manoSanadora'),
      ('Plegaria', {'hp': 0.03}, 'plegaria'),
      ('Milagro', {'heal': 0.04}, 'milagro'),
      ('Paladín Creyente', 'creyente', null),
    ),
    (
      'vigilia', 'Vigilia', 'reducción de daño',
      ('Centinela', {'def': 2}), ('Entereza', {'hp': 0.04}),
      ('Represalia Sagrada', {'def': 1}, 'represaliaSagrada'),
      ('Guardia Alta', {'def': 1}, 'guardiaAlta'),
      ('Voto de Hierro', {'hp': 0.03}, 'votoHierro'),
      ('Resiliencia', {'def': 1}, 'resiliencia'),
      ('Inamovible', 'inamovible', 'inamovible'),
    ),
    (
      'bastion', 'Bastión', 'escudos, protección y provocar',
      ('Templanza', {'def': 2}), ('Firmeza', {'hp': 0.04}),
      ('Púas', {'def': 1}, 'puas'),
      ('Guardián', {'def': 2}, 'guardian'),
      ('Desafío', {'hp': 0.03}, 'desafio'),
      ('Escudo Solidario', {'def': 1}, 'escudoSolidario'),
      ('Égida Eterna', 'egida', 'egida'),
    ),
  ],
};

/// Puentes, uno por par de clases vecinas (en el orden de [_classes]: el
/// puente `i` une la clase `i` con la `i + 1`). Sin cambios desde la v3.
const List<_Bridge> _bridges = [
  (
    'hojaArcana', 'Hoja Arcana', 'híbrido Guerrero–Maga: acero y magia',
    ('Temple Rúnico', {'atk': 0.03}), ('Runa de Filo', {'mag': 0.02, 'ult': 0.02}),
    ('Acero Arcano', {'atk': 0.02, 'mag': 0.02}),
    ('Filo Rúnico', {'atk': 0.02, 'mag': 0.02}, 'filoRunico'),
    ('Hoja de Marea', {'atk': 0.03}, 'hojaMarea'),
    ('Égida Rúnica', {'mag': 0.03}, 'egidaRunica'),
  ),
  (
    'runas', 'Runas', 'híbrido Maga–Tirador: arcano-crítico',
    ('Glifo', {'mag': 0.02, 'ult': 0.02}), ('Mira Rúnica', {'crit': 0.015}),
    ('Runa Certera', {'mag': 0.02, 'crit': 0.01}),
    ('Ojo Arcano', {'crit': 0.015}, 'ojoArcano'),
    ('Sobrecarga', {'ult': 0.03}, 'sobrecarga'),
    ('Pulso Rúnico', {'crit': 0.015}, 'pulsoRunico'),
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
    ('Combo de Equipo', {'atk': 0.02, 'mag': 0.02}, 'comboEquipo'),
  ),
  (
    'sintonia', 'Sintonía', 'grupo: ULT y turnos compartidos',
    ('Compás', {'ult': 0.03}), ('Ritmo', {'spd': 0.15}),
    ('Relevo', {'ult': 0.03}, 'relevo'),
    ('A la Carga', {'spd': 0.15}, 'alaCarga'),
    ('Sincronía Elemental', {'ult': 0.03}, 'sincroniaElemental'),
  ),
  (
    'vinculo', 'Vínculo', 'grupo: curas y escudos',
    ('Lazo', {'heal': 0.03}), ('Cuidado', {'hp': 0.03}),
    ('Lazo Vital', {'heal': 0.03}, 'lazoVital'),
    ('Escudo Compartido', {'hp': 0.03}, 'escudoCompartido'),
    ('Ángel Guardián', {'heal': 0.03}, 'angelGuardian'),
  ),
  (
    'refugio', 'Refugio', 'grupo: menos daño recibido',
    ('Trinchera', {'def': 1}), ('Abrigo', {'hp': 0.03}),
    ('Formación', {'def': 1}, 'formacion'),
    ('Hermandad', {'hp': 0.03}, 'hermandad'),
    ('Muro de Escudos', {'def': 1}, 'muroEscudos'),
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

// ---- Geometría (unidades de árbol, passive_tree_v4.md § 2) ----

const kRingRadius = 2.0;
const kStartRadius = 3.1;

/// Radio del único nodo de ruta (`r1`), que reparte a `f2`, `f3` y `f4`.
const kRoadRadius = 4.5;
const kFanRadius = 6.0;
const kClusterRadius = 7.0;

/// Separación angular entre clusters de una clase.
const kClusterSpread = 15.0;

/// Distancia (u) de la keystone a la entrada de su cluster de clase.
const kKeystoneOffset = 4.95;

/// Plantilla de un cluster de clase v4: sufijo, (u, v), tipo de nodo
/// (`a`/`b` = chico de entrada / de rama, `n1`/`na`/`nb`/`nc` = notables,
/// `k` = keystone).
const _clusterShape = <(String, double, double, String)>[
  ('n1', 0, 0, 'n1'),
  ('m1', 0.8, 0, 'a'),
  ('m2', 1.6, 0, 'a'),
  ('na', 2.4, -0.8, 'na'),
  ('nb', 2.4, 0.8, 'nb'),
  ('ma', 3.25, -0.9, 'b'),
  ('mb', 3.25, 0.9, 'b'),
  ('nc', 4.05, 0, 'nc'),
  ('k', kKeystoneOffset, 0, 'k'),
];
const _clusterLinks = [
  ('n1', 'm1'), ('m1', 'm2'), ('m2', 'na'), ('m2', 'nb'), ('na', 'ma'), //
  ('nb', 'mb'), ('ma', 'nc'), ('mb', 'nc'), ('nc', 'k'),
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

/// Plantilla de un cluster de grupo (v4: la punta es un notable).
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
  ('nt', 7.55, 0, 'nt'),
];
const _groupLinks = [
  ('e1', 'e2'), ('e2', 'a1'), ('a1', 'a2'), ('a2', 'na'), ('e2', 'b1'), //
  ('b1', 'b2'), ('b2', 'nb'), ('na', 'j'), ('nb', 'j'), ('j', 'nt'),
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

  void notable(String id, (double, double) at, _N n, String pid) =>
      add(id, at, n.$1, n.$2, 'n', path: pid, mech: n.$3);

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

    // Ruta de clase: r1 → abanico f1..f5 (r1 llega a f2, f3 y f4).
    final r1 = '${c.short}_r1';
    add(r1, _polar(kRoadRadius, th), c.r1.$1, c.r1.$2, 's');
    link(sid, r1);
    for (var i = 0; i < 5; i++) {
      final f = '${c.short}_f${i + 1}';
      add(f, _polar(kFanRadius, th + (i - 2) * kClusterSpread), c.fan.$1,
          c.fan.$2, 's');
      if (i > 0) link('${c.short}_f$i', f);
    }
    for (final f in [2, 3, 4]) {
      link(r1, '${c.short}_f$f');
    }

    // Clusters de clase.
    final list = _clusters[c.id]!;
    for (var i = 0; i < list.length; i++) {
      final (pid, pname, theme, a, b, n1, na, nb, nc, ks) = list[i];
      final deg = th + (i - 2) * kClusterSpread;
      // v6: la etiqueta se corre al costado (v = −1) para dejar libre el
      // tallo del cluster exterior que sale de acá (lado +v).
      final (lx, ly) =
          _local(kClusterRadius, deg, kKeystoneOffset + 1.0, -1.0);
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
          case 'n1':
            notable(id, at, n1, pid);
          case 'na':
            notable(id, at, na, pid);
          case 'nb':
            notable(id, at, nb, pid);
          case 'nc':
            notable(id, at, nc, pid);
          default:
            add(id, at, ks.$1, const {'key': 1}, 'k',
                key: ks.$2, path: pid, mech: ks.$3);
        }
      }
      for (final (x, y) in _clusterLinks) {
        link('${pid}_$x', '${pid}_$y');
      }
      link('${c.short}_f${i + 1}', '${pid}_n1');
      // Atajo con el cluster anterior de la misma clase.
      if (i > 0) link('${list[i - 1].$1}_mb', '${pid}_ma');
    }
  }

  // Puentes híbridos: del notable B del último cluster de la clase i al
  // notable A del primero de la clase i + 1.
  for (var i = 0; i < _bridges.length; i++) {
    final (pid, pname, theme, a, b, h, n1, nl, nr) = _bridges[i];
    final ca = _classes[i], cb = _classes[(i + 1) % _classes.length];
    final deg = ca.angle + 45;
    // v6: la etiqueta pasa de u = 17.2 (ahí está el puente elemental) al
    // hueco entre el cluster de grupo y el puente.
    final (lx, ly) = _local(0, deg, 10.8, 0);
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
          notable(id, at, switch (kind) { 'n1' => n1, 'nl' => nl, _ => nr },
              pid);
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
    final (pid, pname, theme, a, b, na, nb, nt) = _groups[i];
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
          notable(id, at, switch (kind) { 'na' => na, 'nb' => nb, _ => nt },
              pid);
      }
    }
    for (final (x, y) in _groupLinks) {
      link('${pid}_$x', '${pid}_$y');
    }
    // Los nodos de anillo a δ ± 15°: índices 3i + 1 y 3i + 2.
    link(_ring[3 * i + 1].$1, '${pid}_e1');
    link(_ring[3 * i + 2].$1, '${pid}_e1');
  }

  _buildV6(add, link, paths);

  return PassiveTreeCatalog(
    nodes: {for (final n in nodes.values) n.id: n.freeze()},
    startNodeByClass: {for (final c in _classes) c.id: 's_${c.short}'},
    exclusions: const {'fe_k': 'juicio_k', 'juicio_k': 'fe_k'},
    paths: paths,
  );
}

// ---- Anillo exterior v6 (passive_tree_v6.md § 2) ----

/// Radio de la entrada (`_n1`) de los clusters exteriores de clase.
const kOuterRadius = 13.5;

/// Plantilla de un cluster exterior, en el marco del cluster v4 del que
/// cuelga (u desde [kOuterRadius]): tallo `s1`/`s2` desde el `_nc` v4,
/// notable de entrada, bifurcación de 2 notables, unión, cola y keystone.
const _outerShape = <(String, double, double, String)>[
  ('s1', -2.0, 0.85, 's'),
  ('s2', -1.0, 0.85, 's'),
  ('n1', 0, 0, 'n1'),
  ('m1', 0.8, 0, 's'),
  ('m2', 1.6, 0, 's'),
  ('na', 2.4, -0.85, 'na'),
  ('nb', 2.4, 0.85, 'nb'),
  ('ma', 3.2, -1.05, 's'),
  ('mb', 3.2, 1.05, 's'),
  ('ma2', 4.0, -1.0, 's'),
  ('mb2', 4.0, 1.0, 's'),
  ('nc', 4.6, 0, 'nc'),
  ('m3', 5.4, 0, 's'),
  ('nd', 6.2, 0, 'nd'),
  ('k', 7.1, 0, 'k'),
];
const _outerLinks = [
  ('s1', 's2'), ('s2', 'n1'), ('n1', 'm1'), ('m1', 'm2'), ('m2', 'na'), //
  ('m2', 'nb'), ('na', 'ma'), ('nb', 'mb'), ('ma', 'ma2'), ('mb', 'mb2'),
  ('ma2', 'nc'), ('mb2', 'nc'), ('nc', 'm3'), ('m3', 'nd'), ('nd', 'k'),
];

/// Plantilla de un puente elemental en la diagonal (u = radio): eje
/// `i1` (cuelga de las puntas del puente v3), brazos hacia el cluster
/// exterior de cada clase, notable central, 2 notables y keystone.
const _elemShape = <(String, double, double, String)>[
  ('i1', 17.2, 0, 's'),
  ('a1', 16.6, -6.4, 's'),
  ('a2', 17.3, -5.0, 's'),
  ('na', 18.0, -3.6, 'na'),
  ('h1', 18.6, -1.8, 's'),
  ('b1', 16.6, 6.4, 's'),
  ('b2', 17.3, 5.0, 's'),
  ('nb', 18.0, 3.6, 'nb'),
  ('h2', 18.6, 1.8, 's'),
  ('n1', 19.2, 0, 'n1'),
  ('l1', 19.9, -0.9, 's'),
  ('nl', 20.6, -1.7, 'nl'),
  ('r1', 19.9, 0.9, 's'),
  ('nr', 20.6, 1.7, 'nr'),
  ('k', 20.3, 0, 'k'),
];
const _elemLinks = [
  ('a1', 'a2'), ('a2', 'na'), ('na', 'h1'), ('h1', 'n1'), ('b1', 'b2'), //
  ('b2', 'nb'), ('nb', 'h2'), ('h2', 'n1'), ('i1', 'n1'), ('n1', 'l1'),
  ('l1', 'nl'), ('n1', 'r1'), ('r1', 'nr'), ('n1', 'k'),
];

/// Plantilla de un cluster de grupo exterior en la diagonal.
const _outerGroupShape = <(String, double, double, String)>[
  ('e1', 21.4, 0, 's'),
  ('n0', 22.2, 0, 'n0'),
  ('a1', 22.9, -0.7, 's'),
  ('b1', 22.9, 0.7, 's'),
  ('na', 23.6, -1.1, 'na'),
  ('nb', 23.6, 1.1, 'nb'),
  ('a2', 24.35, -0.75, 's'),
  ('b2', 24.35, 0.75, 's'),
  ('nt', 25.0, 0, 'nt'),
];
const _outerGroupLinks = [
  ('e1', 'n0'), ('n0', 'a1'), ('n0', 'b1'), ('a1', 'na'), ('b1', 'nb'), //
  ('na', 'a2'), ('nb', 'b2'), ('a2', 'nt'), ('b2', 'nt'),
];

final Map<String, String> _v6Names = {
  for (final m in kTreeV6Mechanics) m.id: m.name,
  for (final m in kTreeV6SmallMechanics) m.id: m.name,
};

void _buildV6(
  void Function(String id, (double, double) at, String name, _Fx fx,
          String kind,
          {String? key, String? path, String? mech})
      add,
  void Function(String a, String b) link,
  Map<String, PassivePath> paths,
) {
  void node(String id, (double, double) at, String kind, String path,
      String mech) {
    switch (kind) {
      case 's':
        add(id, at, _v6Names[id]!, const {}, 's', path: path, mech: id);
      case 'k':
        add(id, at, _v6Names[mech]!, const {'key': 1}, 'k',
            key: mech, path: path, mech: mech);
      default:
        add(id, at, _v6Names[mech]!, const {}, 'n', path: path, mech: mech);
    }
  }

  // Clusters exteriores de clase: el j cuelga del `_nc` del cluster v4
  // j + 1 (θ − 15°, θ, θ + 15°).
  for (final c in _classes) {
    final outer = kTreeV6Clusters[c.id]!;
    final inner = _clusters[c.id]!;
    for (var j = 0; j < outer.length; j++) {
      final (pid, pname, theme, _, _, notables, ks) = outer[j];
      final deg = c.angle + (j - 1) * kClusterSpread;
      final (lx, ly) = _local(kOuterRadius, deg, 8.7, 0);
      paths[pid] = PassivePath(
          id: pid,
          name: pname,
          theme: theme,
          classId: c.id,
          labelX: lx,
          labelY: ly);
      for (final (s, u, v, kind) in _outerShape) {
        final at = _local(kOuterRadius, deg, u, v);
        final i = kV6ClusterNotables.indexOf(kind);
        node('${pid}_$s', at, kind == 's' || kind == 'k' ? kind : 'n', pid,
            kind == 'k' ? ks : (i < 0 ? '' : notables[i]));
      }
      for (final (x, y) in _outerLinks) {
        link('${pid}_$x', '${pid}_$y');
      }
      link('${inner[j + 1].$1}_nc', '${pid}_s1');
      // Atajo con el cluster exterior anterior de la misma clase.
      if (j > 0) link('${outer[j - 1].$1}_mb2', '${pid}_ma2');
    }
  }

  // Puentes elementales: detrás de cada puente v3, entre el último
  // cluster exterior de la clase i y el primero de la i + 1.
  for (var i = 0; i < kTreeV6Bridges.length; i++) {
    final (pid, pname, theme, _, _, _, notables, ks) = kTreeV6Bridges[i];
    final ca = _classes[i], cb = _classes[(i + 1) % _classes.length];
    final deg = ca.angle + 45;
    final (lx, ly) = _local(0, deg, 18.2, 0);
    paths[pid] = PassivePath(
        id: pid,
        name: pname,
        theme: theme,
        classId: '${ca.id}+${cb.id}',
        kind: 'puente',
        labelX: lx,
        labelY: ly);
    for (final (s, u, v, kind) in _elemShape) {
      final at = _local(0, deg, u, v);
      final n = kV6BridgeNotables.indexOf(kind);
      node('${pid}_$s', at, kind == 's' || kind == 'k' ? kind : 'n', pid,
          kind == 'k' ? ks : (n < 0 ? '' : notables[n]));
    }
    for (final (x, y) in _elemLinks) {
      link('${pid}_$x', '${pid}_$y');
    }
    final old = _bridges[i].$1;
    link('${old}_nl', '${pid}_i1');
    link('${old}_nr', '${pid}_i1');
    link('${kTreeV6Clusters[ca.id]!.last.$1}_mb2', '${pid}_a1');
    link('${kTreeV6Clusters[cb.id]!.first.$1}_ma2', '${pid}_b1');
  }

  // Clusters de grupo exteriores: detrás de cada puente elemental.
  for (var i = 0; i < kTreeV6Groups.length; i++) {
    final (pid, pname, theme, _, _, notables) = kTreeV6Groups[i];
    final deg = _classes[i].angle + 45;
    final (lx, ly) = _local(0, deg, 26.0, 0);
    paths[pid] = PassivePath(
        id: pid,
        name: pname,
        theme: theme,
        classId: 'grupo',
        kind: 'grupo',
        labelX: lx,
        labelY: ly);
    for (final (s, u, v, kind) in _outerGroupShape) {
      final at = _local(0, deg, u, v);
      final n = kV6GroupNotables.indexOf(kind);
      node('${pid}_$s', at, kind == 's' ? 's' : 'n', pid,
          n < 0 ? '' : notables[n]);
    }
    for (final (x, y) in _outerGroupLinks) {
      link('${pid}_$x', '${pid}_$y');
    }
    final bridge = kTreeV6Bridges[i].$1;
    link('${bridge}_nl', '${pid}_e1');
    link('${bridge}_nr', '${pid}_e1');
  }
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
