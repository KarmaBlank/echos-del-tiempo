import '../../../game_engine/data/passive_mechanics.dart';
import '../../../game_engine/models/passive_tree.dart';
import '../../../game_engine/rules/passive_tree_rules.dart';

/// Texto de cada keystone (`KEYS` del prototipo, líneas 344-351, más las
/// 4 nuevas del árbol v2: passive_tree_v2.md § 4). Las de la v3 usan el
/// texto de su mecánica (passive_tree_v3.md § 6).
const Map<String, String> kKeystoneText = {
  'imparable':
      'Golpe Imparable: tu ataque básico golpea a TODOS los enemigos al 60% del daño.',
  'furia': 'Furia de Sangre: +35% ATQ, pero −4 DEF.',
  'mente': 'Mente sobre Materia: +30% MAG, pero −20% vida máx.',
  'tormenta':
      'Tormenta Arcana: habilidades a todos los enemigos +25% daño; a un solo enemigo −15%.',
  'halcon':
      'Ojo de Halcón: tus críticos hacen ×2.0 (en vez de ×1.5), pero −15% ATQ.',
  'toxicidad':
      'Toxicidad: tus habilidades aplican +2 stacks de Veneno, pero −10% ATQ.',
  'creyente':
      'Paladín Creyente: Aura Restauradora también hace daño de luz (MAG × 0.8) a todos; cada básico 25% de curar 2% de vida a todos. Excluye Inherente.',
  'inherente':
      'Paladín Inherente: cada básico 25% de aplicar Sagrado (5 de daño/turno, 3 turnos, se acumula). Excluye Creyente.',
  'danza':
      'Danza de Cuchillas: cada crítico te da otro turno inmediato (un turno extra no da otro), pero tu crítico máximo baja a 40%.',
  'almaHielo':
      'Alma de Hielo: mientras estés en pie, la Congelación de los enemigos no se derrite sola, pero no podés aplicar Quemadura.',
  'cadena':
      'Cadena Infinita: tus rebotes saltan a todos los enemigos (cada salto 60% del anterior), pero tus acciones a un solo objetivo hacen −20%.',
  'egida':
      'Égida Eterna: al empezar tu turno ganás un escudo del 10% de tu vida máx. (1 turno, no acumula), pero −20% ATQ y −20% MAG.',
};

/// `0.04` → `4%`, `0.015` → `1.5%`.
String _pct(num v) {
  final p = (v * 1000).round() / 10;
  return p == p.roundToDouble() ? '${p.round()}%' : '$p%';
}

String? _mechanicLine(PassiveNode n) {
  final m = kMechanics[n.mechanicId];
  return m == null ? null : '${n.name}: ${m.description}';
}

/// Texto plano para el buscador del árbol: nombre, cluster, tema, efectos
/// y mecánica, en minúsculas y sin tildes (passive_tree_v3.md § 13).
String passiveSearchText(PassiveTreeCatalog catalog, PassiveNode n) {
  final path = catalog.paths[n.pathId];
  return foldSearch([
    n.name,
    if (path != null) path.name,
    if (path != null) path.theme,
    ...passiveEffectsText(n),
  ].join(' '));
}

/// Minúsculas y sin tildes (para buscar "danza" o "DAÑO" igual).
String foldSearch(String s) {
  const from = 'áéíóúüñÁÉÍÓÚÜÑ';
  const to = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString().toLowerCase();
}

/// `fxTxt` (líneas 353-356): una línea por efecto, en el orden del
/// prototipo. Sin emojis (la fuente no los tiene).
List<String> passiveEffectsText(PassiveNode node) {
  final fx = node.effects;
  num? f(String k) {
    final v = fx[k];
    return v == null || v == 0 ? null : v;
  }

  return [
    if (f('hp') case final v?) '+${_pct(v)} vida máx.',
    if (f('mp') case final v?) '+${_pct(v)} maná máx.',
    if (f('atk') case final v?) '+${_pct(v)} ATQ',
    if (f('mag') case final v?) '+${_pct(v)} MAG',
    if (f('crit') case final v?) '+${_pct(v)} crítico',
    if (f('spd') case final v?) '+$v velocidad',
    if (f('def') case final v?) '+$v DEF',
    if (f('ult') case final v?) '+${_pct(v)} carga de ULT',
    if (f('heal') case final v?) '+${_pct(v)} curación',
    if (f('burn') case final v?) '+$v stack de Quemadura que apliques',
    if (f('poi') case final v?) '+$v stack de Veneno que apliques',
    if (f('frz') case final v?) '+$v stack de Congelación que apliques',
    if (node.keystoneId case final k?)
      // Keystones v3: el texto de su mecánica, que ya trae la contra.
      kKeystoneText[k] ?? _mechanicLine(node) ?? k
    else if (node.mechanicId case final m?)
      kMechanics[m]?.description ?? m,
  ];
}

/// Cómo se dibuja un nodo (`treeHtml`).
enum TreeNodeState { start, taken, available, locked }

/// Estado de un nodo para el jugador y, si no se puede tomar, el motivo
/// (mismo orden que `PassiveTreeRules.canTake`, ver docs/specs/panels.md).
class TreeNodeStatus {
  const TreeNodeStatus(this.state, [this.reason]);
  final TreeNodeState state;
  final String? reason;

  bool get canTake => state == TreeNodeState.available;
}

TreeNodeStatus treeNodeStatus(
  PassiveTreeRules rules, {
  required String classId,
  required int level,
  required PlayerPassiveProgress progress,
  required String nodeId,
  required bool inBattle,
}) {
  final cat = rules.catalog;
  if (cat.startNodeByClass[classId] == nodeId) {
    return const TreeNodeStatus(TreeNodeState.start, 'Nodo inicial');
  }
  if (rules.hasNode(classId, progress, nodeId)) {
    return const TreeNodeStatus(TreeNodeState.taken, 'Ya lo tienes');
  }
  if (inBattle) {
    return const TreeNodeStatus(TreeNodeState.locked, 'No en batalla');
  }
  if (rules.pointsAvailable(level, progress) <= 0) {
    return const TreeNodeStatus(TreeNodeState.locked, 'Sin puntos de árbol');
  }
  final ex = cat.exclusions[nodeId];
  if (ex != null && rules.hasNode(classId, progress, ex)) {
    return TreeNodeStatus(
        TreeNodeState.locked, 'Excluye ${cat.nodes[ex]?.name ?? ex}');
  }
  if (!rules.canTake(classId, level, progress, nodeId)) {
    return const TreeNodeStatus(
        TreeNodeState.locked, 'Necesita un nodo conectado');
  }
  return const TreeNodeStatus(TreeNodeState.available);
}
