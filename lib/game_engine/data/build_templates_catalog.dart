import '../models/attributes.dart';
import '../models/build_plan.dart';

/// Plantilla de build: un plan armado para una clase
/// (docs/specs/build_planner.md § 3). Los nodos del árbol son los
/// objetivos (notables y keystone); al aplicarla se completa el camino
/// (`BuildPlanRules.withTreePaths`).
class BuildTemplate {
  const BuildTemplate({
    required this.id,
    required this.classId,
    required this.name,
    required this.description,
    required this.plan,
  });

  final String id;
  final String classId;
  final String name;
  final String description;
  final BuildPlan plan;
}

const _vit = Attribute.vit;
const _esp = Attribute.esp;
const _agi = Attribute.agi;
const _fue = Attribute.fue;
const _des = Attribute.des;

/// Rama A completa de una ascensión + su nodo final (6 puntos).
List<String> _branchA(String a) => ['${a}_a1', '${a}_a2', '${a}_a3', '${a}_k'];
List<String> _branchB(String a) => ['${a}_b1', '${a}_b2', '${a}_b3', '${a}_k'];

/// Las plantillas, 2 por clase.
final List<BuildTemplate> kBuildTemplates = [
  BuildTemplate(
    id: 'gue_berserker',
    classId: 'guerrero',
    name: 'Berserker sangrado',
    description: 'Hacha pesada, robo de vida y Furia de Sangre: '
        'pega más cuanto menos vida tiene.',
    plan: BuildPlan(
      name: 'Berserker sangrado',
      templateId: 'gue_berserker',
      attributes: const {_fue: 40, _vit: 24},
      treeNodes: const ['sangre_na', 'sangre_nb', 'sangre_k'],
      ascensionId: 'berserker',
      ascensionNodes: _branchA('berserker'),
      weaponTypes: const ['hacha'],
      weaponBases: const ['hacha_berserker'],
      mods: const [ModGoal('feroz', 3), ModGoal('del_vampiro', 3)],
      weaponPassive: 'sedDelArma',
      skills: const ['hendir', 'sangria'],
      targetLevel: 50,
    ),
  ),
  BuildTemplate(
    id: 'gue_quiebre',
    classId: 'guerrero',
    name: 'Rompeguardias',
    description: 'Espada, quiebre y Demoledor; Señor de la Guerra '
        'para buffear al grupo.',
    plan: BuildPlan(
      name: 'Rompeguardias',
      templateId: 'gue_quiebre',
      attributes: const {_fue: 36, _des: 18},
      treeNodes: const ['quiebre_na', 'quiebre_nb', 'quiebre_k'],
      ascensionId: 'senorGuerra',
      ascensionNodes: _branchB('senorGuerra'),
      weaponTypes: const ['espada'],
      weaponBases: const ['espada_runica'],
      mods: const [ModGoal('feroz', 3), ModGoal('letal', 4)],
      weaponPassive: 'filoResonante',
      skills: const ['tajoT', 'gritoGuerra'],
      targetLevel: 50,
    ),
  ),
  BuildTemplate(
    id: 'mag_brasa',
    classId: 'maga',
    name: 'Elementalista de brasa',
    description: 'Quemaduras que se apilan y Detonar para reventarlas.',
    plan: BuildPlan(
      name: 'Elementalista de brasa',
      templateId: 'mag_brasa',
      attributes: const {_esp: 40, _agi: 14},
      treeNodes: const ['brasa_na', 'brasa_nb', 'brasa_k'],
      ascensionId: 'elementalista',
      ascensionNodes: _branchA('elementalista'),
      weaponTypes: const ['báculo'],
      weaponBases: const ['baculo_fuego'],
      mods: const [ModGoal('arcano', 3), ModGoal('abrasador', 2)],
      weaponPassive: 'brasaAvivada',
      skills: const ['bola', 'llamarada', 'detonar'],
      targetLevel: 50,
    ),
  ),
  BuildTemplate(
    id: 'mag_cronos',
    classId: 'maga',
    name: 'Cronomante del tiempo',
    description: 'Retrasa enemigos y adelanta aliados: el grupo juega '
        'más turnos.',
    plan: BuildPlan(
      name: 'Cronomante del tiempo',
      templateId: 'mag_cronos',
      attributes: const {_esp: 34, _agi: 24},
      treeNodes: const ['cronos_na', 'cronos_nb', 'cronos_k'],
      ascensionId: 'cronomante',
      ascensionNodes: _branchB('cronomante'),
      weaponTypes: const ['tomo'],
      weaponBases: const ['tomo_tiempo'],
      mods: const [ModGoal('arcano', 3), ModGoal('veloz', 3)],
      weaponPassive: 'pesoDelTiempo',
      skills: const ['detener', 'aceleron'],
      targetLevel: 50,
    ),
  ),
  BuildTemplate(
    id: 'tir_precision',
    classId: 'tirador',
    name: 'Francotirador crítico',
    description: 'Críticos enormes a un objetivo con rifle y Ojo de '
        'Halcón.',
    plan: BuildPlan(
      name: 'Francotirador crítico',
      templateId: 'tir_precision',
      attributes: const {_des: 40, _agi: 20},
      treeNodes: const ['precision_na', 'precision_nb', 'precision_k'],
      ascensionId: 'francotirador',
      ascensionNodes: _branchA('francotirador'),
      weaponTypes: const ['rifle'],
      weaponBases: const ['rifle_precision'],
      mods: const [ModGoal('certero', 3), ModGoal('letal', 3)],
      weaponPassive: 'ojoCertero',
      skills: const ['perfora', 'tiroCabeza'],
      targetLevel: 50,
    ),
  ),
  BuildTemplate(
    id: 'tir_toxina',
    classId: 'tirador',
    name: 'Trampero tóxico',
    description: 'Veneno que se acumula, trampas y daño en área con arco.',
    plan: BuildPlan(
      name: 'Trampero tóxico',
      templateId: 'tir_toxina',
      attributes: const {_des: 30, _agi: 26},
      treeNodes: const ['toxina_na', 'toxina_nb', 'toxina_k'],
      ascensionId: 'trampero',
      ascensionNodes: _branchB('trampero'),
      weaponTypes: const ['arco'],
      weaponBases: const ['arco_sombra'],
      mods: const [ModGoal('ponzonoso', 2), ModGoal('veloz', 4)],
      weaponPassive: 'toxinaPersistente',
      skills: const ['venenosa', 'redCaza'],
      targetLevel: 50,
    ),
  ),
  BuildTemplate(
    id: 'pal_guardian',
    classId: 'paladin',
    name: 'Guardián muralla',
    description: 'Escudos para todo el grupo, provocar y Égida Eterna.',
    plan: BuildPlan(
      name: 'Guardián muralla',
      templateId: 'pal_guardian',
      attributes: const {_vit: 40, _fue: 20},
      treeNodes: const ['bastion_na', 'bastion_nb', 'bastion_k'],
      ascensionId: 'guardian',
      ascensionNodes: _branchA('guardian'),
      weaponTypes: const ['maza+escudo'],
      weaponBases: const ['maza_escudo_bastion'],
      mods: const [ModGoal('de_la_vida', 3), ModGoal('del_baluarte', 3)],
      weaponPassive: 'bastionVivo',
      skills: const ['provocar', 'fortaleza'],
      targetLevel: 50,
    ),
  ),
  BuildTemplate(
    id: 'pal_templario',
    classId: 'paladin',
    name: 'Templario del juicio',
    description: 'Daño sagrado y aturdir con martillo y escudo.',
    plan: BuildPlan(
      name: 'Templario del juicio',
      templateId: 'pal_templario',
      attributes: const {_fue: 30, _vit: 26, _esp: 20},
      treeNodes: const ['juicio_na', 'juicio_nb', 'juicio_k'],
      ascensionId: 'templario',
      ascensionNodes: _branchB('templario'),
      weaponTypes: const ['martillo+escudo'],
      weaponBases: const ['martillo_escudo_juicio'],
      mods: const [ModGoal('feroz', 3), ModGoal('certero', 4)],
      weaponPassive: 'conmocion',
      skills: const ['juicio', 'castigo'],
      targetLevel: 50,
    ),
  ),
];

/// Plantillas de una clase, en orden.
List<BuildTemplate> buildTemplatesFor(String classId) =>
    [for (final t in kBuildTemplates) if (t.classId == classId) t];

BuildTemplate? buildTemplate(String id) {
  for (final t in kBuildTemplates) {
    if (t.id == id) return t;
  }
  return null;
}
