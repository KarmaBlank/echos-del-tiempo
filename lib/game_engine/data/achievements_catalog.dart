import '../models/achievement.dart';

// Hazañas (docs/specs/achievements.md § 2): 33, una vez por cuenta. Los
// números son los del spec (§ 3; créditos ×2 tras medir ≈ ₵2400 por misión
// a mitad de juego, § 4); la recompensa va al personaje con el que se
// logra.

const _forge = AchievementCategory.forge;
const _fusion = AchievementCategory.fusion;
const _salvage = AchievementCategory.salvage;
const _inv = AchievementCategory.inventory;
const _combat = AchievementCategory.combat;
const _prog = AchievementCategory.progression;
const _end = AchievementCategory.endgame;

typedef _R = AchievementReward;

/// El catálogo, en el orden de la pestaña.
const List<AchievementDef> kAchievements = [
  // ---- Forja (5) ----
  AchievementDef(
      id: 'forge_first',
      name: 'Primera forja',
      category: _forge,
      how: 'En FORJA, subí un nivel de cualquier mejora de un arma.',
      reward: _R(credits: 400, esquirlas: 2)),
  AchievementDef(
      id: 'forge_plus5',
      name: 'Forjar a +5',
      category: _forge,
      how: 'Llevá un arma a 5 niveles de forja en total.',
      reward: _R(credits: 800, cristales: 1)),
  AchievementDef(
      id: 'forge_cap',
      name: 'Al tope',
      category: _forge,
      how: 'Forjá un arma Rara o mejor hasta su tope total de forja.',
      reward: _R(credits: 1800, prismas: 1)),
  AchievementDef(
      id: 'forge_10',
      name: 'Forjador II',
      category: _forge,
      how: 'Subí 10 niveles de forja en total (cualquier arma).',
      reward: _R(credits: 1000, cristales: 1),
      counter: AchievementCounter.forgeLevels,
      goal: 10),
  AchievementDef(
      id: 'forge_30',
      name: 'Forjador III',
      category: _forge,
      how: 'Subí 30 niveles de forja en total (cualquier arma).',
      reward: _R(credits: 2400, prismas: 1),
      counter: AchievementCounter.forgeLevels,
      goal: 30),

  // ---- Fusión (9) ----
  AchievementDef(
      id: 'fuse_first',
      name: 'Primera fusión',
      category: _fusion,
      how: 'En FUSIÓN, hacé cualquier operación: trasladar, quitar o '
          'agregar un afijo, volver a tirar o subir de rareza.',
      reward: _R(credits: 600, esquirlas: 2, cristales: 1),
      counter: AchievementCounter.fusions,
      goal: 1),
  AchievementDef(
      id: 'fuse_5',
      name: 'Fusionador II',
      category: _fusion,
      how: 'Hacé 5 operaciones de fusión en total.',
      reward: _R(credits: 1200, cristales: 1, prismas: 1),
      counter: AchievementCounter.fusions,
      goal: 5),
  AchievementDef(
      id: 'fuse_20',
      name: 'Fusionador III',
      category: _fusion,
      how: 'Hacé 20 operaciones de fusión en total.',
      reward: _R(credits: 3000, prismas: 2),
      counter: AchievementCounter.fusions,
      goal: 20),
  AchievementDef(
      id: 'fuse_skill',
      name: 'Traer habilidad',
      category: _fusion,
      how: 'En FUSIÓN, elegí un arma para sacrificar y trasladá una de sus '
          'habilidades a otra.',
      reward: _R(credits: 600, cristales: 1)),
  AchievementDef(
      id: 'fuse_passive',
      name: 'Traer pasiva',
      category: _fusion,
      how: 'En FUSIÓN, trasladá la pasiva de un Épico a otro Épico.',
      reward: _R(credits: 1000, prismas: 1)),
  AchievementDef(
      id: 'fuse_affix',
      name: 'Traer afijo',
      category: _fusion,
      how: 'En FUSIÓN, trasladá un afijo de un arma sacrificada a otra.',
      reward: _R(credits: 400, esquirlas: 2)),
  AchievementDef(
      id: 'fuse_break_slot',
      name: 'Reemplazar Quebrar',
      category: _fusion,
      how: 'En FUSIÓN, trasladá una habilidad a la Ranura de Quebrar de un '
          'arma.',
      reward: _R(credits: 600, cristales: 1)),
  AchievementDef(
      id: 'fuse_rarity',
      name: 'Subir de rareza',
      category: _fusion,
      how: 'En FUSIÓN, usá un Prisma Roto para subir la rareza de un arma.',
      reward: _R(credits: 600, prismas: 1)),
  AchievementDef(
      id: 'fuse_reroll',
      name: 'Volver a tirar',
      category: _fusion,
      how: 'En FUSIÓN, usá una Esquirla del Eco para volver a tirar los '
          'valores de los afijos.',
      reward: _R(credits: 200, esquirlas: 3)),

  // ---- Reforja, desarme y venta (4) ----
  AchievementDef(
      id: 'reforge_first',
      name: 'Reforjar',
      category: _salvage,
      how: 'Reforjá un arma: cambiá su base y conservá rareza, mods y forja.',
      reward: _R(credits: 1000, cristales: 1)),
  AchievementDef(
      id: 'salvage_10',
      name: 'Desarmar 10',
      category: _salvage,
      how: 'Desarmá 10 armas en total (el lote cuenta cada una).',
      reward: _R(credits: 400, esquirlas: 3),
      counter: AchievementCounter.salvaged,
      goal: 10),
  AchievementDef(
      id: 'salvage_50',
      name: 'Desarmar 50',
      category: _salvage,
      how: 'Desarmá 50 armas en total.',
      reward: _R(credits: 1000, cristales: 1, prismas: 1),
      counter: AchievementCounter.salvaged,
      goal: 50),
  AchievementDef(
      id: 'sell_first',
      name: 'Primera venta',
      category: _salvage,
      how: 'Vendé un arma en el pueblo (una o por lote).',
      reward: _R(credits: 100, potions: 1)),

  // ---- Inventario, filtro y alijo (4) ----
  AchievementDef(
      id: 'inv_search',
      name: 'Usar buscador',
      category: _inv,
      how: 'Escribí en el buscador del inventario o del alijo y encontrá '
          'algo.',
      reward: _R(potions: 2)),
  AchievementDef(
      id: 'filter_rule',
      name: 'Primera regla de filtro',
      category: _inv,
      how: 'En FILTRO, creá o editá una regla y guardá el filtro.',
      reward: _R(credits: 200, esquirlas: 2)),
  AchievementDef(
      id: 'stash_store',
      name: 'Guardar en alijo',
      category: _inv,
      how: 'Mové un objeto del inventario al alijo compartido.',
      reward: _R(credits: 200, ethers: 1)),
  AchievementDef(
      id: 'stash_move_all',
      name: 'Mover todo',
      category: _inv,
      how: 'En el alijo, usá MOVER TODO AL ALIJO con algo para mover.',
      reward: _R(credits: 200, esquirlas: 2)),

  // ---- Combate (4) ----
  AchievementDef(
      id: 'combat_break',
      name: 'Primer quiebre',
      category: _combat,
      how: 'Llená la barra de quiebre de un enemigo y quebralo con un golpe '
          'con Quebrar.',
      reward: _R(potions: 2)),
  AchievementDef(
      id: 'combat_convergence',
      name: 'Primera Convergencia',
      category: _combat,
      how: 'Prepará los stacks y detoná una Convergencia (vale para quien '
          'preparó y para quien detonó).',
      reward: _R(credits: 200, potions: 1, ethers: 1)),
  AchievementDef(
      id: 'combat_instant_chain',
      name: 'Encadenar Instante',
      category: _combat,
      how: 'En tu turno, usá una habilidad INSTANTE y después otra acción.',
      reward: _R(credits: 200, ethers: 2)),
  AchievementDef(
      id: 'combat_cancel_ult',
      name: 'Cancelar ULT de jefe',
      category: _combat,
      how: 'Cuando un jefe avisa su ULT, quebralo antes de que la lance.',
      reward: _R(credits: 800, cristales: 1)),

  // ---- Progresión (4) ----
  AchievementDef(
      id: 'equip_legendary',
      name: 'Equipar legendaria',
      category: _prog,
      how: 'Equipá un arma Legendaria.',
      reward: _R(credits: 600, cristales: 1)),
  AchievementDef(
      id: 'tree_milestone',
      name: 'Primer hito',
      category: _prog,
      how: 'En el ÁRBOL, elegí la keystone del hito del nivel 10 ó 20.',
      reward: _R(credits: 600, potions: 2)),
  AchievementDef(
      id: 'build_plan_done',
      name: 'Completar plan de BUILD',
      category: _prog,
      how: 'En BUILD, armá un plan y cumplí todos sus objetivos.',
      reward: _R(credits: 1200, prismas: 1)),
  AchievementDef(
      id: 'attr_cap',
      name: 'Pasar tope de atributo',
      category: _prog,
      how: 'Subí un atributo más allá de su tope blando (desde ahí rinde la '
          'mitad).',
      reward: _R(credits: 400, esquirlas: 2)),

  // ---- Endgame (3) ----
  AchievementDef(
      id: 'eco_first',
      name: 'Primer Eco',
      category: _end,
      how: 'Completá una misión dentro de un Eco.',
      reward: _R(credits: 1200, prismas: 1)),
  AchievementDef(
      id: 'atlas_node',
      name: 'Nodo del Atlas',
      category: _end,
      how: 'En el ATLAS, tomá tu primer nodo.',
      reward: _R(credits: 1000, cristales: 1)),
  AchievementDef(
      id: 'abyss_boss',
      name: 'Fondo del Abismo',
      category: _end,
      how: 'Vencé a cualquier Jefe del Abismo.',
      reward: _R(credits: 2400, prismas: 1)),
];

/// Por id.
final Map<String, AchievementDef> kAchievementsById = {
  for (final a in kAchievements) a.id: a,
};

/// Las que el cliente detecta y le pide al host (§ 5.2): no pasan por
/// ninguna acción del host o viven solo en el cliente (buscador, MOVER
/// TODO, Atlas de la cuenta, plan de BUILD local).
const Set<String> kClientClaimableAchievements = {
  'inv_search',
  'stash_move_all',
  'atlas_node',
  'build_plan_done',
};
