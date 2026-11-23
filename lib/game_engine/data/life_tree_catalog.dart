// Árboles de talentos de los oficios (docs/specs/life_skill_trees.md).
// Datos puros: la forma del árbol vive acá; los números de cada nodo, en
// `kTuning[TuningId.lifeTree]` (Editor → Balance → Oficios: árboles).

/// Oficio con árbol propio.
enum LifeSkillKind {
  pesca('PESCA'),
  cultivo('CULTIVO'),
  herreria('HERRERÍA');

  const LifeSkillKind(this.label);
  final String label;
}

/// Un nodo del árbol de un oficio.
class LifeTreeNode {
  const LifeTreeNode(this.id, this.name, this.text,
      {required this.x,
      required this.y,
      this.cost = 1,
      this.links = const [],
      this.effects = const {},
      this.exclusive,
      this.major = false,
      this.root = false});

  final String id;
  final String name;

  /// Descripción con `{v}` / `{v2}` en lugar de los números del Balance.
  final String text;

  /// Columna (−2..2) y fila (0..5) en el lienzo.
  final int x, y;
  final int cost;

  /// Vecinos: se puede tomar si alguno está tomado (o es la raíz).
  final List<String> links;

  /// Efecto → clave del valor en el Balance (`lifeTree`).
  final Map<String, String> effects;

  /// Grupo excluyente: solo un nodo del grupo por árbol.
  final String? exclusive;
  final bool major;
  final bool root;
}

/// Efectos que leen las reglas (farming.md § 9, fishing.md § 9).
abstract final class LifeFx {
  // Pesca
  static const zone = 'zone';
  static const bite = 'bite';
  static const loot = 'loot';
  static const legend = 'legend';
  static const auto = 'auto';
  // Cultivo
  static const grow = 'grow';
  static const quality = 'quality';
  static const extra = 'extra';
  static const helper = 'helper';
  static const seed = 'seed';
  static const water = 'water';
  // Herrería (roles.md § 6)
  static const forge = 'forge';
  // Todos
  static const sell = 'sell';
  static const xp = 'xp';
  // Poder de aventurero (roles.md § 5): vida máxima y ATQ / MAG (en
  // fracción, se suman al árbol de pasivas).
  static const hp = 'hp';
  static const atk = 'atk';
}

const _pesca = <LifeTreeNode>[
  LifeTreeNode('p_r', 'Pescador', '+{v} % de XP de Pesca.',
      x: 0, y: 0, cost: 0, root: true, links: ['p_a1', 'p_b1'],
      effects: {LifeFx.xp: 'p_r'}),
  LifeTreeNode('p_a1', 'Muñeca firme', 'Zona de captura +{v} %.',
      x: -1, y: 1, links: ['p_r', 'p_a2', 'p_a3', 'p_m'],
      effects: {LifeFx.zone: 'p_a1'}),
  LifeTreeNode('p_a2', 'Ojo de boya', 'La picada llega {v} % antes.',
      x: -2, y: 2, links: ['p_a1', 'p_a4'], exclusive: 'p_a',
      effects: {LifeFx.bite: 'p_a2'}),
  LifeTreeNode('p_a3', 'Zona ancha', 'Zona de captura +{v} % más.',
      x: -1, y: 2, links: ['p_a1', 'p_a4'], exclusive: 'p_a',
      effects: {LifeFx.zone: 'p_a3'}),
  LifeTreeNode('p_a4', 'Pulso quieto',
      'Zona de captura +{v} % y picada {v2} % antes.',
      x: -1, y: 3, cost: 2, major: true, links: ['p_a2', 'p_a3', 'p_k1'],
      effects: {LifeFx.zone: 'p_a4', LifeFx.bite: 'p_a4_2'}),
  LifeTreeNode('p_m', 'Regateo', 'El agropecuario paga +{v} % por pescado.',
      x: 0, y: 2, links: ['p_a1', 'p_b1'], effects: {LifeFx.sell: 'p_m'}),
  LifeTreeNode('p_b1', 'Rastreador', 'Botín del agua: chance × (1 + {v} %).',
      x: 1, y: 1, links: ['p_r', 'p_b2', 'p_b3', 'p_m'],
      effects: {LifeFx.loot: 'p_b1'}),
  LifeTreeNode('p_b2', 'Ojo de ruinas',
      'Botín del agua: chance × (1 + {v} %) más.',
      x: 2, y: 2, links: ['p_b1', 'p_b4'], exclusive: 'p_b',
      effects: {LifeFx.loot: 'p_b2'}),
  LifeTreeNode('p_b3', 'Llamado del eco', 'Rareza de los peces +{v} %.',
      x: 1, y: 2, links: ['p_b1', 'p_b4'], exclusive: 'p_b',
      effects: {LifeFx.legend: 'p_b3'}),
  LifeTreeNode('p_b4', 'Mareas del tiempo', 'Rareza de los peces +{v} %.',
      x: 1, y: 3, cost: 2, major: true, links: ['p_b2', 'p_b3', 'p_k2'],
      effects: {LifeFx.legend: 'p_b4'}),
  LifeTreeNode('p_k1', 'Red de pescador',
      'Pescadores: +{v} peces por vuelta.',
      x: -1, y: 4, cost: 2, links: ['p_a4', 'p_f'], exclusive: 'p_k',
      effects: {LifeFx.auto: 'p_k1'}),
  LifeTreeNode('p_k2', 'Lance del Mañana', 'Rareza de los peces +{v} % más.',
      x: 1, y: 4, cost: 2, links: ['p_b4', 'p_f'], exclusive: 'p_k',
      effects: {LifeFx.legend: 'p_k2'}),
  LifeTreeNode('p_f', 'Maestro del lago',
      '+{v} % de precio y +{v2} % de XP de Pesca.',
      x: 0, y: 5, cost: 3, major: true, links: ['p_k1', 'p_k2'],
      effects: {LifeFx.sell: 'p_f', LifeFx.xp: 'p_f_2'}),
  // Poder de aventurero (roles.md § 5).
  LifeTreeNode('p_v', 'Brazos de remo', 'Vida máxima +{v} %.',
      x: -2, y: 1, links: ['p_a1'], effects: {LifeFx.hp: 'p_v'}),
  LifeTreeNode('p_d', 'Arpón del eco', 'ATQ y MAG +{v} %.',
      x: 2, y: 1, links: ['p_b1'], effects: {LifeFx.atk: 'p_d'}),
  LifeTreeNode('p_g', 'Calma del lago', 'Vida máxima +{v} % y ATQ y MAG +{v2} %.',
      x: -2, y: 5, cost: 2, links: ['p_f'],
      effects: {LifeFx.hp: 'p_g', LifeFx.atk: 'p_g_2'}),
];

const _cultivo = <LifeTreeNode>[
  LifeTreeNode('c_r', 'Granjero', '+{v} % de XP de Cultivo.',
      x: 0, y: 0, cost: 0, root: true, links: ['c_a1', 'c_b1'],
      effects: {LifeFx.xp: 'c_r'}),
  LifeTreeNode('c_a1', 'Surco parejo', 'Los cultivos crecen +{v} % rápido.',
      x: -1, y: 1, links: ['c_r', 'c_a2', 'c_a3', 'c_m'],
      effects: {LifeFx.grow: 'c_a1'}),
  LifeTreeNode('c_a2', 'Riego profundo', 'El riego dura +{v} %.',
      x: -2, y: 2, links: ['c_a1', 'c_a4'], exclusive: 'c_a',
      effects: {LifeFx.water: 'c_a2'}),
  LifeTreeNode('c_a3', 'Tierra viva', 'Los cultivos crecen +{v} % más rápido.',
      x: -1, y: 2, links: ['c_a1', 'c_a4'], exclusive: 'c_a',
      effects: {LifeFx.grow: 'c_a3'}),
  LifeTreeNode('c_a4', 'Raíz del tiempo',
      'Crecen +{v} % rápido y la calidad sube {v2}.',
      x: -1, y: 3, cost: 2, major: true, links: ['c_a2', 'c_a3', 'c_k1'],
      effects: {LifeFx.grow: 'c_a4', LifeFx.quality: 'c_a4_2'}),
  LifeTreeNode('c_m', 'Puesto propio', 'El agropecuario paga +{v} % por cosechas.',
      x: 0, y: 2, links: ['c_a1', 'c_b1'], effects: {LifeFx.sell: 'c_m'}),
  LifeTreeNode('c_b1', 'Mano fina', 'La calidad de la cosecha sube {v}.',
      x: 1, y: 1, links: ['c_r', 'c_b2', 'c_b3', 'c_m'],
      effects: {LifeFx.quality: 'c_b1'}),
  LifeTreeNode('c_b2', 'Doble surco', '+{v} % de chance de cosecha doble.',
      x: 2, y: 2, links: ['c_b1', 'c_b4'], exclusive: 'c_b',
      effects: {LifeFx.extra: 'c_b2'}),
  LifeTreeNode('c_b3', 'Ojo de semilla',
      'Hallazgos de la huerta: chance × (1 + {v} %).',
      x: 1, y: 2, links: ['c_b1', 'c_b4'], exclusive: 'c_b',
      effects: {LifeFx.seed: 'c_b3'}),
  LifeTreeNode('c_b4', 'Cosecha del eco',
      'La calidad sube {v} y los hallazgos × (1 + {v2} %).',
      x: 1, y: 3, cost: 2, major: true, links: ['c_b2', 'c_b3', 'c_k2'],
      effects: {LifeFx.quality: 'c_b4', LifeFx.seed: 'c_b4_2'}),
  LifeTreeNode('c_k1', 'Capataz',
      'El ayudante atiende +{v} % de parcelas y rinde más.',
      x: -1, y: 4, cost: 2, links: ['c_a4', 'c_f'], exclusive: 'c_k',
      effects: {LifeFx.helper: 'c_k1'}),
  LifeTreeNode('c_k2', 'Manos propias', '+{v} % de chance de cosecha doble.',
      x: 1, y: 4, cost: 2, links: ['c_b4', 'c_f'], exclusive: 'c_k',
      effects: {LifeFx.extra: 'c_k2'}),
  LifeTreeNode('c_f', 'Maestro de la huerta',
      '+{v} % de precio y +{v2} % de XP de Cultivo.',
      x: 0, y: 5, cost: 3, major: true, links: ['c_k1', 'c_k2'],
      effects: {LifeFx.sell: 'c_f', LifeFx.xp: 'c_f_2'}),
  // Poder de aventurero (roles.md § 5).
  LifeTreeNode('c_v', 'Espalda de surco', 'Vida máxima +{v} %.',
      x: -2, y: 1, links: ['c_a1'], effects: {LifeFx.hp: 'c_v'}),
  LifeTreeNode('c_d', 'Hoz templada', 'ATQ y MAG +{v} %.',
      x: 2, y: 1, links: ['c_b1'], effects: {LifeFx.atk: 'c_d'}),
  LifeTreeNode('c_g', 'Raíz firme', 'Vida máxima +{v} % y ATQ y MAG +{v2} %.',
      x: -2, y: 5, cost: 2, links: ['c_f'],
      effects: {LifeFx.hp: 'c_g', LifeFx.atk: 'c_g_2'}),
];

// Herrería (roles.md § 6): árbol chico de 8 nodos.
const _herreria = <LifeTreeNode>[
  LifeTreeNode('h_r', 'Aprendiz de fragua', '+{v} % de XP de Herrería.',
      x: 0, y: 0, cost: 0, root: true, links: ['h_a1', 'h_b1'],
      effects: {LifeFx.xp: 'h_r'}),
  LifeTreeNode('h_a1', 'Martillo justo', 'La forja cuesta {v} % menos.',
      x: -1, y: 1, links: ['h_r', 'h_a2'], effects: {LifeFx.forge: 'h_a1'}),
  LifeTreeNode('h_b1', 'Temple', 'Vida máxima +{v} %.',
      x: 1, y: 1, links: ['h_r', 'h_b2'], effects: {LifeFx.hp: 'h_b1'}),
  LifeTreeNode('h_a2', 'Yunque antiguo', 'La forja cuesta {v} % menos.',
      x: -1, y: 2, links: ['h_a1', 'h_m'], exclusive: 'h_x',
      effects: {LifeFx.forge: 'h_a2'}),
  LifeTreeNode('h_b2', 'Filo del pasado', 'ATQ y MAG +{v} %.',
      x: 1, y: 2, links: ['h_b1', 'h_m'], effects: {LifeFx.atk: 'h_b2'}),
  LifeTreeNode('h_c', 'Ojo de oficio', '+{v} % de XP de Herrería.',
      x: 0, y: 2, links: ['h_a1', 'h_b1'], exclusive: 'h_x',
      effects: {LifeFx.xp: 'h_c'}),
  LifeTreeNode('h_m', 'Mecanismo vivo', 'Vida máxima +{v} % y ATQ y MAG +{v2} %.',
      x: 0, y: 3, cost: 2, major: true, links: ['h_a2', 'h_b2', 'h_f'],
      effects: {LifeFx.hp: 'h_m', LifeFx.atk: 'h_m_2'}),
  LifeTreeNode('h_f', 'Maestro de la fragua',
      'La forja cuesta {v} % menos y +{v2} % de XP de Herrería.',
      x: 0, y: 4, cost: 3, major: true, links: ['h_m'],
      effects: {LifeFx.forge: 'h_f', LifeFx.xp: 'h_f_2'}),
];

/// Los nodos de cada oficio.
const kLifeTrees = <LifeSkillKind, List<LifeTreeNode>>{
  LifeSkillKind.pesca: _pesca,
  LifeSkillKind.cultivo: _cultivo,
  LifeSkillKind.herreria: _herreria,
};

LifeTreeNode? lifeTreeNode(LifeSkillKind k, String id) {
  for (final n in kLifeTrees[k]!) {
    if (n.id == id) return n;
  }
  return null;
}
