// Números sueltos de reglas (economía, mejora y carga de ULT, Ecos) que
// el parche de balance puede tocar (docs/specs/balance_admin.md § 1.1,
// tipos de "Ajustes"). Cada grupo es una entidad del parche; el código
// lee siempre [kTuning], que `BalanceRegistries.install` cambia en el
// lugar y `restore` devuelve a estos valores.

/// Un grupo de números con nombre (los valores del código o del parche).
class TuningDef {
  const TuningDef(this.name, this.values);

  final String name;
  final Map<String, num> values;

  double d(String k) => values[k]!.toDouble();
  int i(String k) => values[k]!.round();
}

/// Id de cada grupo (= id de la entidad en su tipo del parche).
abstract final class TuningId {
  static const ultLevel = 'ultLevel';
  static const ultUpgrade = 'ultUpgrade';
  static const ultCharge = 'ultCharge';
  static const condense = 'condense';
  static const materials = 'materials';
  static const ecoTier = 'ecoTier';
  static const buildGuide = 'buildGuide';
  static const consumables = 'consumables';
  static const travesia = 'travesia';
  static const combatLimits = 'combatLimits';
  static const exploration = 'exploration';
  static const mission = 'mission';
  static const fishing = 'fishing';
  static const farming = 'farming';
  static const town = 'town';
  static const lifeTree = 'lifeTree';
}

/// Los valores del código.
const Map<String, TuningDef> kTuningDefaults = {
  // fishing.md (v0.22.0): Pesca, cañas, minijuego y agropecuario.
  TuningId.fishing: TuningDef('Pesca', {
    // Nivel: XP para pasar del nivel l = xpBase × l^xpExp; tope maxLevel.
    'maxLevel': 30,
    'xpBase': 40,
    'xpExp': 1.5,
    // Pesos de rareza (la caña y el lance sube los no comunes).
    'weightComun': 70,
    'weightRaro': 22,
    'weightEpico': 7,
    'weightLegendario': 1,
    // Capturas sin legendario que garantizan uno (0 = sin pity).
    'pityAfter': 200,
    // Lance largo: + chance de rareza con la carga al máximo.
    'distanceBonus': 0.3,
    // × de XP de Pesca por rareza.
    'xpComun': 1,
    'xpRaro': 2.5,
    'xpEpico': 6,
    'xpLegendario': 15,
    // XP de personaje por rareza y tope por estadía en el pueblo.
    'charXpComun': 2,
    'charXpRaro': 5,
    'charXpEpico': 12,
    'charXpLegendario': 30,
    'charXpCap': 60,
    // Herramientas (town_loop.md § 11c).
    'bonusFloor': 0.4,
    'bonusCurve': 1.5,
    // Picada: espera en segundos, ventana para clavar y señuelos.
    'biteMinSec': 2.5,
    'biteMaxSec': 7,
    'biteWindowSec': 1.1,
    'nibblesMax': 3,
    // Barra: zona (fracción de la barra), velocidad del pez, progreso.
    'zoneBase': 0.24,
    'barSpeed': 1,
    'progressStart': 0.25,
    'progressGain': 0.1,
    'progressDrain': 0.12,
    // Dificultad (× velocidad y nervio del pez) por rareza.
    'diffComun': 0.6,
    'diffRaro': 0.9,
    'diffEpico': 1.25,
    'diffLegendario': 1.6,
    // Validación del host: segundos mínimos entre lances y de pelea.
    'minCastSec': 2,
    'minReelSec': 1.5,
    // Pesca en el mapa (v0.22.2): tiles que vuela la boya con la carga al
    // máximo y bonus de rareza por tirar desde un muelle.
    'maxCastTiles': 5,
    'dockBonus': 0.1,
    // Botín del agua (fishing.md § 8): chance de que la captura no sea un
    // pez, pesos de cada tipo, mejora por nivel de Pesca y caña, pity del
    // cofre o arma y los legendarios exclusivos (nivel y caña mínimos).
    'lootChance': 0.15,
    'lootBasura': 60,
    'lootMateriales': 28,
    'lootCofre': 9,
    'lootArma': 3,
    'lootLevelBonus': 0.03,
    'lootPityAfter': 80,
    'lootLegendChance': 0.01,
    'lootLegendLevel': 15,
    'lootLegendRod': 2,
    'lootMatMin': 1,
    'lootMatMax': 3,
    // Auto-pesca: × de XP, peces por clic y espera entre usos (s).
    'autoMult': 0.4,
    'autoCount': 3,
    'autoCooldownSec': 30,
    // Agropecuario: × del valor si se cobra en materiales, oro por
    // Esquirla y recompensa del canje de un legendario.
    'matRate': 1.2,
    'matValue': 25,
    'legendCristales': 3,
    'legendPrismas': 1,
  }),
  // farming.md (v0.23.0): Cultivo, herramientas, huerta y agropecuario.
  TuningId.farming: TuningDef('Cultivo', {
    // Nivel: misma forma que Pesca.
    'maxLevel': 30,
    'xpBase': 40,
    'xpExp': 1.5,
    // × de XP de Cultivo por rareza del cultivo.
    'xpComun': 1,
    'xpRaro': 2.5,
    'xpEpico': 6,
    'xpLegendario': 15,
    // XP de personaje por rareza y tope por estadía en el pueblo.
    'charXpComun': 2,
    'charXpRaro': 5,
    'charXpEpico': 12,
    'charXpLegendario': 30,
    'charXpCap': 60,
    // Herramientas (town_loop.md § 11c).
    'bonusFloor': 0.4,
    'bonusCurve': 1.5,
    // Crecimiento: × sin regar, segundos de riego, segundos que suma cada
    // misión ganada y XP por arar/plantar/regar. Un regador de nivel bajo
    // riega más lento: × crecimiento = waterRateMin + (1 − min) × efect.
    'dryRate': 0.35,
    'waterSec': 240,
    'waterRateMin': 0.6,
    'missionGrowSec': 420,
    'workXp': 1,
    // Calidad (farming.md § 3): pesos base de normal / rara / épica /
    // legendaria; el puntaje S de los aportes multiplica la rara × (1+S),
    // la épica × (1+S)^2 y la legendaria × (1+S)^3.
    'wQNormal': 70,
    'wQRaro': 22,
    'wQEpico': 7,
    'wQLegendario': 1,
    // Aporte de cada uno al puntaje S: quien planta (potencial), los
    // riegos (calidad media × fracción regada) y quien cosecha (pesa más).
    'sPlant': 0.6,
    'sWater': 0.5,
    'sHarvest': 1.4,
    // Puntaje de una persona: base + nivel × perLevel + herramienta +
    // árbol (el «quality» de sus nodos).
    'pBase': 0.05,
    'pPerLevel': 0.04,
    // Abonos: sesgo al puntaje y × de crecimiento por tipo.
    'fertComunBias': 0.4,
    'fertComunSpeed': 1.15,
    'fertRunicoBias': 1,
    'fertRunicoSpeed': 1.3,
    'fertEcoBias': 2,
    'fertEcoSpeed': 1.5,
    // × de precio y XP por calidad.
    'qualityMultNormal': 1,
    'qualityMultRaro': 1.3,
    'qualityMultEpico': 1.8,
    'qualityMultLegendario': 3,
    // Semillas: chance de que la cosecha devuelva una (no legendarias).
    'seedDropChance': 0.4,
    // Hallazgos de la huerta (farming.md § 5): chance, pesos, mejora por
    // nivel, pity del hallazgo y de la semilla legendaria.
    'lootChance': 0.07,
    'lootSemilla': 60,
    'lootMateriales': 35,
    'lootLegendaria': 5,
    'lootLevelBonus': 0.03,
    'lootPityAfter': 40,
    'legendPityAfter': 150,
    'lootMatMin': 1,
    'lootMatMax': 2,
    // Agropecuario: × en materiales, oro por Esquirla y canje de un
    // legendario.
    'matRate': 1.2,
    'matValue': 25,
    'legendCristales': 3,
    'legendPrismas': 1,
    // Validación del host: alcance (px) y segundos entre labores.
    'reachPx': 30,
    'minWorkSec': 0.15,
  }),
  // farming.md § 6–8 (v0.23.0): ampliaciones, lago y ayudante.
  TuningId.town: TuningDef('Pueblo', {
    // Ampliaciones (town_editor.md § 2: cada una suma una franja de 8 a un
    // lado): tope total, tope por lado y costo de la n-ésima (oro = base ×
    // mult^(n−1); Esquirlas × n; Cristales desde la 2.ª).
    'maxExpansions': 6,
    'maxPerSide': 3,
    'expGoldBase': 1500,
    'expGoldMult': 2.5,
    'expEsquirlas': 6,
    'expCristales': 2,
    // Lagos (town_editor.md § 5): capacidad mínima y por tile de agua,
    // peso extra por pez soltado (tope por especie), rareza por cada 36
    // tiles por encima del lago base y por especie criando, chance de
    // cría por misión ganada.
    'lakeMin': 2,
    'lakePerTile': 0.2,
    'stockWeight': 1,
    'stockWeightCap': 4,
    'lakeZoneRare': 0.05,
    'breedRare': 0.03,
    'breedRareCap': 0.15,
    'breedChance': 0.35,
    // Ayudantes (farming.md § 8, v0.25.5): nivel del oficio para
    // contratar, oro por ayudante, parcelas de cada granjero, tiles de
    // lago por pescador, peces por vuelta, cada cuántos segundos trabajan,
    // × de XP al que recoge el cofre y tope del cofre.
    'helperLevel': 5,
    'helperCost': 800,
    'helperPlots': 8,
    'fisherTiles': 18,
    'fisherCatch': 2,
    'helperEverySec': 45,
    'helperXpShare': 0.1,
    'chestMax': 200,
    // Progresión de cada ayudante (farming.md § 8.5, v0.27.0): nivel
    // tope, XP del nivel l = base × l^exp (1 por parcela atendida o pez),
    // materiales de oficio al contratar, mejoras (oro y materiales por
    // rango, niveles por rango, tope de rangos) y su efecto por rango.
    'helperMaxLevel': 10,
    'helperXpBase': 30,
    'helperXpExp': 1.4,
    'hireMat': 5,
    'upGold': 400,
    'upMat': 3,
    'upTabla': 1,
    'upRankLevels': 3,
    'upMaxRank': 4,
    'upPlots': 2,
    'upRitmo': 0.15,
    'upCalidad': 0.1,
    'upRareSeed': 0.03,
    'upPeces': 1,
    'upRareza': 0.06,
    // Materiales de oficio de CONDENSAR (v0.27.0): cosechas o pescados
    // por fibra / cebo, Esquirlas y oro de cada una; fibras, Esquirlas y
    // oro por tabla.
    'fibraIn': 5,
    'ceboIn': 5,
    'lifeEsq': 1,
    'lifeCr': 20,
    'tablaFibra': 3,
    'tablaEsq': 2,
    'tablaCr': 50,
    // Día, noche y clima (day_night_weather.md, v0.27.0): segundos de día
    // y de noche, del atardecer / amanecer, chances del clima, parte del
    // día que dura, rayos (cada cuánto se tira y la chance), picada y
    // pescadores con tormenta y el oro del faro.
    'daySec': 300,
    'nightSec': 300,
    'duskSec': 40,
    'rainChance': 0.25,
    'stormChance': 0.06,
    'weatherMinFrac': 0.2,
    'weatherMaxFrac': 0.45,
    'boltEverySec': 12,
    'boltChance': 0.4,
    'stormBite': 0.3,
    'stormFisher': 0.35,
    'faroCost': 300,
    // Exteriores de bioma y refuerzos (overworld_biomes.md § 7): rebrote
    // de cada recolectable (s), chance de semilla del bioma, XP de Cultivo
    // por recolectar, turnos de espera del refuerzo que llega a una pelea
    // (en intervalos propios) y peso de cada ausente en la dificultad.
    'forageRespawnSec': 240,
    'forageSeedChance': 0.12,
    'forageXp': 6,
    'reinforceDelay': 1,
    'absentWeight': 0.6,
    // Habitantes de bioma (overworld_biomes.md § 10): relación, etapas,
    // edificio, pedidos y beneficio permanente de cada rol (base + paso
    // por nivel).
    'resInviteRep': 3,
    'resSettledRep': 5,
    'resRootedRep': 12,
    'resMaxTier': 5,
    'resMaxHouse': 3,
    'resHouseGold': 800,
    'resRequestEveryDays': 2,
    'resUnhappyDays': 4,
    'resRequestRep': 2,
    'resherbolariaBase': 10,
    'resherbolariaStep': 5,
    'resarchivistaBase': 1,
    'resarchivistaStep': 1,
    'resinstructorBase': 5,
    'resinstructorStep': 3,
    'resforjadorBase': 5,
    'resforjadorStep': 3,
    'resvidenteBase': 3,
    'resvidenteStep': 2,
  }),
  // life_skill_trees.md (v0.23.0): puntos y valor de cada nodo.
  TuningId.lifeTree: TuningDef('Oficios: árboles', {
    'pointsPerLevel': 1,
    'p_r': 0.05,
    'p_a1': 0.06,
    'p_a2': 0.08,
    'p_a3': 0.1,
    'p_a4': 0.1,
    'p_a4_2': 0.1,
    'p_m': 0.1,
    'p_b1': 0.15,
    'p_b2': 0.2,
    'p_b3': 0.1,
    'p_b4': 0.2,
    'p_k1': 1,
    'p_k2': 0.15,
    'p_f': 0.1,
    'p_f_2': 0.15,
    'c_r': 0.05,
    'c_a1': 0.08,
    'c_a2': 0.3,
    'c_a3': 0.12,
    'c_a4': 0.12,
    'c_a4_2': 0.1,
    'c_m': 0.1,
    'c_b1': 0.1,
    'c_b2': 0.1,
    'c_b3': 0.25,
    'c_b4': 0.2,
    'c_b4_2': 0.15,
    'c_k1': 0.5,
    'c_k2': 0.15,
    'c_f': 0.1,
    'c_f_2': 0.15,
  }),
  // world.md § "Colisión y movimiento": px/s del jugador en el campo
  // (v0.20.19: 78 → 98, +25 %).
  TuningId.exploration: TuningDef('Exploración', {
    'playerSpeed': 98,
    // town_loop.md § 2 (v0.21.0): cinemática de partida del pueblo a la
    // zona, en segundos (≤ 4, saltable).
    'departureSec': 3,
  }),
  // worldgen.md § 6.8 (v0.20.22): misiones cortas. Tope de pisos por
  // misión, × de grupos normales por piso y × del área de cada piso.
  TuningId.mission: TuningDef('Misiones', {
    'maxFloors': 3,
    'groupScale': 0.7,
    'areaScale': 0.7,
  }),
  // ultimates_v2.md § 2.4: +6% por nivel sobre el 1.
  TuningId.ultLevel: TuningDef('Escalado de ULT por nivel', {
    'perLevel': 0.06,
  }),
  // ultimates_v2.md § 2.4 / materials_economy.md § 6.
  TuningId.ultUpgrade: TuningDef('Costo de mejora de ULT', {
    'credits': 1000,
    'cristal': 1,
    'prismaFrom': 3,
    'fragFrom': 3,
  }),
  // Carga de la barra ULT (combat.md): daño recibido y hecho; enemigos.
  TuningId.ultCharge: TuningDef('Carga de barra ULT', {
    'takenFactor': 110,
    'dealtBase': 5,
    'dealtScale': 30,
    'dealtCap': 22,
    'enemyPerTurn': 25,
    'enemyPerHp': 100,
  }),
  // materials_economy.md § 4.3 (v0.20.8: 20 Esquirlas / 8 Cristales).
  TuningId.condense: TuningDef('Recetas de Condensar', {
    'cristalCost': 20,
    'cristalCredits': 100,
    'prismaCost': 8,
    'prismaCredits': 500,
  }),
  // materials_economy.md § 4.1-4.2 (economía v0.15).
  TuningId.materials: TuningDef('Materiales, desarme y rareza', {
    'chanceEsquirla': 0.08,
    'chanceCristal': 0.025,
    'chancePrisma': 0.006,
    'multBattle': 1,
    'multChest': 2,
    'multMission': 2,
    'multElite': 3,
    'multBoss': 5,
    'weightComun': 60,
    'weightMagico': 27,
    'weightRaro': 10,
    'weightEpico': 2.7,
    'weightLegendario': 0.3,
    'zoneEpicWeight': 1.5,
    'salvageHighLevel': 25,
    'upComunPrismas': 1,
    'upComunCredits': 100,
    'upMagicoPrismas': 3,
    'upMagicoCredits': 300,
    'upRaroPrismas': 6,
    'upRaroCredits': 800,
    'transferCredits': 200,
    'transferCristales': 2,
    'restoreQuebrarCredits': 100,
    'addAffixCredits': 50,
    'rerollCredits': 25,
  }),
  // materials_economy.md § 4.4.
  TuningId.ecoTier: TuningDef('Bonus de tier de Ecos', {
    'tierQuantity': 0.03,
    'partyQuantity': 0.10,
  }),
  // build_planner.md § 9: pesos de la guía del builder.
  TuningId.buildGuide: TuningDef('Guía del builder', {
    'dmgWeight': 2,
    'elementWeight': 2,
    'passiveWeight': 1.5,
    'modWeight': 0.5,
    'goalWeight': 2,
    'fitWeight': 3,
    'attrWeight': 2,
    'treeWeight': 2,
    'powerWeight': 1.5,
    'reqPenalty': 0.6,
    'recommendTop': 3,
    // § 9.4 Consejo de arma.
    'forgeWeight': 4,
    'upgradeMinGain': 0.2,
    'buyMinGain': 0.2,
    'typeTie': 0.25,
    'howToNames': 3,
  }),
  // loot.md § 17.6: precios de la tienda y Éter en cofres; combat.md §
  // "Revivir y el árbol": sinergia de revivir con el árbol.
  TuningId.consumables: TuningDef('Consumibles y revivir', {
    'potionPrice': 30,
    'etherPrice': 40,
    'aetherMult': 5,
    'aetherChestChance': 0.05,
    'espPer': 0.003,
    'healScale': 0.5,
    'shieldScale': 1.0,
    'shieldCap': 0.25,
    'shieldTurns': 2,
  }),
  // roguelike.md § 4 y § 8: mejoras directas de la fila Extra, progreso
  // entre runs y curva de la Travesía. Solo lo lee la Travesía.
  TuningId.travesia: TuningDef('Travesía', {
    // Mejoras directas (§ 4): valor de cada una (se apilan).
    'boonSpell': 10,
    'boonAttack': 15,
    'boonHeal': 20,
    'boonCrit': 5,
    'boonUlt': 20,
    'boonElite': 15,
    'boonPulse': 1,
    'boonDefense': 4,
    'boonSteal': 4,
    // Mejoras que entran al sorteo de la fila Extra.
    'boonsInExtra': 2,
    // Progreso entre runs (§ 8): moneda.
    'coinPerFloor': 10,
    'coinElite': 4,
    'coinBoss': 12,
    'coinWin': 20,
    // Zonas: las primeras del sorteo y piso que hay que alcanzar
    // (1 = el primero) para desbloquear una más.
    'zonesStart': 3,
    'zoneUnlockFloor': 2,
    // Élites: niveles extra por cada vez que ya se venció a esa élite.
    'eliteRepeatLevel': 2,
    // Dificultad: + por nivel a ATQ y vida enemigos (acumulativo).
    'diffAtk': 0.08,
    'diffHp': 0.10,
    'diffMax': 5,
    // Sin niveles (v0.3.0): el personaje crece solo con recompensas.
    // Puntos de la recompensa de atributo y niveles por encima de los
    // enemigos de la entrada del piso de las armas ofrecidas.
    'attrReward': 5,
    // Habilidades (§ 12.2): tope total contando ATACAR y DEFENDER (las
    // del arma no cuentan), habilidades nuevas en la fila Extra y mejora
    // en la armería (oro base × nivel siguiente, + poder por nivel, tope).
    'maxSkills': 6,
    'skillsInExtra': 1,
    'skillUpCost': 60,
    'skillUpPower': 0.15,
    'skillUpMax': 3,
    // ULT como recompensa rara (por tipo de pelea) y en la tienda.
    'ultChanceCombate': 0.05,
    'ultChanceElite': 0.3,
    'ultChanceJefe': 1.0,
    'shopUlts': 2,
    'ultPrice': 260,
    'weaponLevelAhead': 2,
    // Nivel de los enemigos: 1 + piso × levelPerFloor + capa ×
    // levelPerLayer (+ élite / jefe).
    'levelPerFloor': 4,
    'levelPerLayer': 0.25,
    // Vida y ATQ de los enemigos de la Travesía (× sobre la curva del
    // Mundo, antes de la dificultad).
    'enemyHp': 0.4,
    'enemyAtk': 0.3,
  }),
  // combat.md § "Límites": efectos encadenados por acción, tope de daño
  // por golpe de jefes y élites, "aguanta una ronda" de los comunes y
  // rendimientos decrecientes de la velocidad.
  TuningId.combatLimits: TuningDef('Límites de combate', {
    // Efectos encadenados: total por acción y profundidad de la cadena
    // (un efecto que dispara otro que dispara otro...).
    'procMax': 64,
    'procDepth': 6,
    // Tope absoluto por golpe (fracción de la vida máxima; 0 = sin
    // tope). Vale siempre, también con debilidad, reacción o quiebre.
    'capBoss': 0.35,
    'capElite': 0.60,
    'capCommon': 0,
    // Aguanta una ronda (1 = sí): el primer golpe letal a un común antes
    // de que actúen todos los jugadores vivos lo deja en 1 de vida.
    'holdCoop': 1,
    'holdSolo': 0,
    // Turnos como máximo por cada turno del aliado vivo más lento
    // (0 = sin tope).
    'turnsPerSlowest': 2,
    // Velocidad efectiva sobre el umbral: lo que sobra rinde × el factor.
    'speedSoftCap': 16,
    'speedSoftFactor': 0.5,
    // Carga de ULT extra (árbol, mods, efectos e invocaciones): tope por
    // acción y por turno de quien la recibe, en puntos de la barra (100).
    'ultBonusAction': 50,
    'ultBonusTurn': 50,
    // Modo de combate por defecto de la sala (turn_modes.md § 1): 0 línea
    // de tiempo, 1 por rondas, 2 por fases.
    'modeCoop': 1,
    'modeSolo': 0,
    // Por fases: pausa de planificación al abrir la fase de jugadores (s).
    'planPause': 2,
  }),
};

/// Los valores vigentes (código o parche instalado).
final Map<String, TuningDef> kTuning = Map.of(kTuningDefaults);

/// El grupo [id] vigente.
TuningDef tuning(String id) => kTuning[id]!;
