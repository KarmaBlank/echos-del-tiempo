// NÃºmeros sueltos de reglas (economÃ­a, mejora y carga de ULT, Ecos) que
// el parche de balance puede tocar (docs/specs/balance_admin.md Â§ 1.1,
// tipos de "Ajustes"). Cada grupo es una entidad del parche; el cÃ³digo
// lee siempre [kTuning], que `BalanceRegistries.install` cambia en el
// lugar y `restore` devuelve a estos valores.

/// Un grupo de nÃºmeros con nombre (los valores del cÃ³digo o del parche).
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
  static const dungeon = 'dungeon';
  static const smithing = 'smithing';
  static const regions = 'regions';
}

/// Los valores del cÃ³digo.
const Map<String, TuningDef> kTuningDefaults = {
  // fishing.md (v0.22.0): Pesca, caÃ±as, minijuego y agropecuario.
  TuningId.fishing: TuningDef('Pesca', {
    // Nivel: XP para pasar del nivel l = xpBase Ã— l^xpExp; tope maxLevel.
    'maxLevel': 30,
    'xpBase': 40,
    'xpExp': 1.5,
    // Pesos de rareza (la caÃ±a y el lance sube los no comunes).
    'weightComun': 70,
    'weightRaro': 22,
    'weightEpico': 7,
    'weightLegendario': 1,
    // Capturas sin legendario que garantizan uno (0 = sin pity).
    'pityAfter': 200,
    // Lance largo: + chance de rareza con la carga al mÃ¡ximo.
    'distanceBonus': 0.3,
    // Ã— de XP de Pesca por rareza.
    'xpComun': 1,
    'xpRaro': 2.5,
    'xpEpico': 6,
    'xpLegendario': 15,
    // XP de personaje por rareza y tope por estadÃ­a en el pueblo.
    'charXpComun': 2,
    'charXpRaro': 5,
    'charXpEpico': 12,
    'charXpLegendario': 30,
    'charXpCap': 60,
    // Herramientas (town_loop.md Â§ 11c).
    'bonusFloor': 0.4,
    'bonusCurve': 1.5,
    // Picada: espera en segundos, ventana para clavar y seÃ±uelos.
    'biteMinSec': 2.5,
    'biteMaxSec': 7,
    'biteWindowSec': 1.1,
    'nibblesMax': 3,
    // Barra: zona (fracciÃ³n de la barra), velocidad del pez, progreso.
    'zoneBase': 0.24,
    'barSpeed': 1,
    'progressStart': 0.25,
    'progressGain': 0.1,
    'progressDrain': 0.12,
    // Dificultad (Ã— velocidad y nervio del pez) por rareza.
    'diffComun': 0.6,
    'diffRaro': 0.9,
    'diffEpico': 1.25,
    'diffLegendario': 1.6,
    // ValidaciÃ³n del host: segundos mÃ­nimos entre lances y de pelea.
    'minCastSec': 2,
    'minReelSec': 1.5,
    // Pesca en el mapa (v0.22.2): tiles que vuela la boya con la carga al
    // mÃ¡ximo y bonus de rareza por tirar desde un muelle.
    'maxCastTiles': 5,
    'dockBonus': 0.1,
    // Bestiario de pesca (fishing.md Â§ 10): primera captura de cada
    // especie, Ã— su XP normal; XP de personaje por rareza Ã— este factor.
    'firstCatchFishXp': 5,
    'firstCatchCharXp': 4,
    // Cebos (fishing.md Â§ 14, v0.44.0): Ã— copies of the fish a bait
    // attracts in the roll, chance of a bait in the water loot and, per
    // bait, bite speed, rarity bonus, size bonus, price and recipe gold.
    'baitAffinity': 4,
    'baitWaterChance': 0.2,
    'baitLombrizBite': 0.15,
    'baitLombrizRare': 0.0,
    'baitLombrizSize': 0.0,
    'baitLombrizPrice': 8,
    'baitLombrizGold': 0,
    'baitLarvaBite': 0.1,
    'baitLarvaRare': 0.15,
    'baitLarvaSize': 0.0,
    'baitLarvaPrice': 30,
    'baitLarvaGold': 10,
    'baitEscarchaBite': 0.05,
    'baitEscarchaRare': 0.1,
    'baitEscarchaSize': 0.15,
    'baitEscarchaPrice': 60,
    'baitEscarchaGold': 20,
    'baitTormentaBite': 0.05,
    'baitTormentaRare': 0.2,
    'baitTormentaSize': 0.05,
    'baitTormentaPrice': 90,
    'baitTormentaGold': 30,
    'baitEcoBite': 0.2,
    'baitEcoRare': 0.35,
    'baitEcoSize': 0.25,
    'baitEcoPrice': 400,
    'baitEcoGold': 200,
    // Agua brillante (fishing.md Â§ 11).
    'spotRare': 0.35,
    'spotLoot': 0.25,
    'spotRadius': 2,
    // Horarios de los peces (fishing.md Â§ 13): chance de que un pez fuera
    // de su franja entre igual en la tirada.
    'offHoursChance': 0.03,
    // Pescador nativo del bioma (fishing.md Â§ 12).
    'fisherRarityLevels': 6,
    'fisherXpBase': 30,
    'fisherXpStep': 6,
    'fisherCharXpPerValue': 1.5,
    'fisherGoldPerValue': 0.6,
    // BotÃ­n del agua (fishing.md Â§ 8): chance de que la captura no sea un
    // pez, pesos de cada tipo, mejora por nivel de Pesca y caÃ±a, pity del
    // cofre o arma y los legendarios exclusivos (nivel y caÃ±a mÃ­nimos).
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
    // Auto-pesca: Ã— de XP, peces por clic y espera entre usos (s).
    'autoMult': 0.4,
    'autoCount': 3,
    'autoCooldownSec': 30,
    // Agropecuario: Ã— del valor si se cobra en materiales, oro por
    // Esquirla y recompensa del canje de un legendario.
    'matRate': 1.2,
    'matValue': 25,
    'legendCristales': 3,
    'legendPrismas': 1,
  }),
  // farming.md (v0.23.0): Cultivo, herramientas, huerta y agropecuario.
  TuningId.farming: TuningDef('Cultivo', {
    // Afinidad de los cultivos con la hora y el clima (farming.md Â§ 14).
    'affinityBonus': 0.25,
    'affinityMalus': 0.1,
    // Nivel: misma forma que Pesca.
    'maxLevel': 30,
    'xpBase': 40,
    'xpExp': 1.5,
    // Ã— de XP de Cultivo por rareza del cultivo.
    'xpComun': 1,
    'xpRaro': 2.5,
    'xpEpico': 6,
    'xpLegendario': 15,
    // XP de personaje por rareza y tope por estadÃ­a en el pueblo.
    'charXpComun': 2,
    'charXpRaro': 5,
    'charXpEpico': 12,
    'charXpLegendario': 30,
    'charXpCap': 60,
    // Herramientas (town_loop.md Â§ 11c).
    'bonusFloor': 0.4,
    'bonusCurve': 1.5,
    // Crecimiento: Ã— sin regar, segundos de riego, segundos que suma cada
    // misiÃ³n ganada y XP por arar/plantar/regar. Un regador de nivel bajo
    // riega mÃ¡s lento: Ã— crecimiento = waterRateMin + (1 âˆ’ min) Ã— efect.
    'dryRate': 0.35,
    'waterSec': 240,
    'waterRateMin': 0.6,
    'missionGrowSec': 420,
    'workXp': 1,
    // Calidad (farming.md Â§ 3): pesos base de normal / rara / Ã©pica /
    // legendaria; el puntaje S de los aportes multiplica la rara Ã— (1+S),
    // la Ã©pica Ã— (1+S)^2 y la legendaria Ã— (1+S)^3.
    'wQNormal': 70,
    'wQRaro': 22,
    'wQEpico': 7,
    'wQLegendario': 1,
    // Aporte de cada uno al puntaje S: quien planta (potencial), los
    // riegos (calidad media Ã— fracciÃ³n regada) y quien cosecha (pesa mÃ¡s).
    'sPlant': 0.6,
    'sWater': 0.5,
    'sHarvest': 1.4,
    // Puntaje de una persona: base + nivel Ã— perLevel + herramienta +
    // Ã¡rbol (el Â«qualityÂ» de sus nodos).
    'pBase': 0.05,
    'pPerLevel': 0.04,
    // Abonos: sesgo al puntaje y Ã— de crecimiento por tipo.
    'fertComunBias': 0.4,
    'fertComunSpeed': 1.15,
    'fertRunicoBias': 1,
    'fertRunicoSpeed': 1.3,
    'fertEcoBias': 2,
    'fertEcoSpeed': 1.5,
    // Ã— de precio y XP por calidad.
    'qualityMultNormal': 1,
    'qualityMultRaro': 1.3,
    'qualityMultEpico': 1.8,
    'qualityMultLegendario': 3,
    // Semillas: chance de que la cosecha devuelva una (no legendarias).
    'seedDropChance': 0.4,
    // Hallazgos de la huerta (farming.md Â§ 5): chance, pesos, mejora por
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
    // Agropecuario: Ã— en materiales, oro por Esquirla y canje de un
    // legendario.
    'matRate': 1.2,
    'matValue': 25,
    'legendCristales': 3,
    'legendPrismas': 1,
    // ValidaciÃ³n del host: alcance (px) y segundos entre labores.
    'reachPx': 30,
    'minWorkSec': 0.15,
  }),
  // farming.md Â§ 6â€“8 (v0.23.0): ampliaciones, lago y ayudante.
  TuningId.town: TuningDef('Pueblo', {
    // Ampliaciones (town_editor.md Â§ 2: cada una suma una franja de 8 a un
    // lado): tope total, tope por lado y costo de la n-Ã©sima (oro = base Ã—
    // mult^(nâˆ’1); Esquirlas Ã— n; Cristales desde la 2.Âª).
    'maxExpansions': 6,
    'maxPerSide': 3,
    'expGoldBase': 1500,
    'expGoldMult': 2.5,
    'expEsquirlas': 6,
    'expCristales': 2,
    // Lagos (town_editor.md Â§ 5): capacidad mÃ­nima y por tile de agua,
    // peso extra por pez soltado (tope por especie), rareza por cada 36
    // tiles por encima del lago base y por especie criando, chance de
    // crÃ­a por misiÃ³n ganada.
    'lakeMin': 2,
    'lakePerTile': 0.2,
    'stockWeight': 1,
    'stockWeightCap': 4,
    'lakeZoneRare': 0.05,
    'breedRare': 0.03,
    'breedRareCap': 0.15,
    'breedChance': 0.35,
    // Ayudantes (farming.md Â§ 8, v0.25.5): nivel del oficio para
    // contratar, oro por ayudante, parcelas de cada granjero, tiles de
    // lago por pescador, peces por vuelta, cada cuÃ¡ntos segundos trabajan,
    // Ã— de XP al que recoge el cofre y tope del cofre.
    'helperLevel': 5,
    'helperCost': 800,
    'helperPlots': 8,
    'fisherTiles': 18,
    'fisherCatch': 2,
    'helperEverySec': 45,
    'helperXpShare': 0.1,
    'chestMax': 200,
    // ProgresiÃ³n de cada ayudante (farming.md Â§ 8.5, v0.27.0): nivel
    // tope, XP del nivel l = base Ã— l^exp (1 por parcela atendida o pez),
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
    // DÃ­a, noche y clima (day_night_weather.md, v0.27.0): segundos de dÃ­a
    // y de noche, del atardecer / amanecer, chances del clima, parte del
    // dÃ­a que dura, rayos (cada cuÃ¡nto se tira y la chance), picada y
    // pescadores con tormenta y el oro del faro.
    'daySec': 300,
    'nightSec': 300,
    'duskSec': 40,
    // Seasons and weather per biome (weather_seasons.md Â§ 1â€“2, v0.44.0):
    // days per season, weight of each weather per season (snow only in
    // winter), Ã— of each weather per biome (no key = Ã— 1) and fog / snow
    // effects on bites and fishers.
    'seasonDays': 7,
    'wSpringClear': 0.55,
    'wSpringRain': 0.28,
    'wSpringStorm': 0.05,
    'wSpringFog': 0.12,
    'wSummerClear': 0.68,
    'wSummerRain': 0.15,
    'wSummerStorm': 0.12,
    'wSummerFog': 0.05,
    'wAutumnClear': 0.5,
    'wAutumnRain': 0.25,
    'wAutumnStorm': 0.07,
    'wAutumnFog': 0.18,
    'wWinterClear': 0.45,
    'wWinterRain': 0.08,
    'wWinterStorm': 0.02,
    'wWinterFog': 0.15,
    'wWinterSnow': 0.3,
    'bioPuebloRain': 1,
    'bioPuebloStorm': 1,
    'bioPuebloFog': 1,
    'bioPuebloSnow': 1,
    'bioBosqueRain': 1.2,
    'bioBosqueStorm': 1,
    'bioBosqueFog': 1.3,
    'bioBosqueSnow': 1,
    'bioRuinasRain': 1,
    'bioRuinasStorm': 1,
    'bioRuinasFog': 1.2,
    'bioRuinasSnow': 0.8,
    'bioGrietaRain': 0.4,
    'bioGrietaStorm': 1.2,
    'bioGrietaFog': 0.5,
    'bioGrietaSnow': 0,
    'bioAbismoRain': 0.8,
    'bioAbismoStorm': 1.5,
    'bioAbismoFog': 1.8,
    'bioAbismoSnow': 0.6,
    'fogBite': 0.85,
    'snowBite': 0.7,
    'fogFisher': 0.85,
    'snowFisher': 0.6,
    'weatherMinFrac': 0.2,
    'weatherMaxFrac': 0.45,
    'boltEverySec': 12,
    'boltChance': 0.4,
    'stormBite': 0.3,
    'stormFisher': 0.35,
    // Auto-fishing (fishing.md Â§ 6): Ã— bite wait, Ã— rod / tree bonuses,
    // Ã— epic weight and Ã— XP (Fishing and character).
    'autoWaitMult': 2.0,
    'autoPassiveMult': 0.5,
    'autoEpicMult': 0.25,
    'autoXpMult': 0.5,
    'faroCost': 300,
    // Exteriores de bioma y refuerzos (overworld_biomes.md Â§ 7): rebrote
    // de cada recolectable (s), chance de semilla del bioma, XP de Cultivo
    // por recolectar, turnos de espera del refuerzo que llega a una pelea
    // (en intervalos propios) y peso de cada ausente en la dificultad.
    'forageRespawnSec': 240,
    'forageSeedChance': 0.12,
    'forageXp': 6,
    'reinforceDelay': 1,
    'absentWeight': 0.6,
    // Habitantes de bioma (overworld_biomes.md Â§ 10): relaciÃ³n, etapas,
    // edificio, pedidos y beneficio permanente de cada rol (base + paso
    // por nivel).
    'resInviteRep': 3,
    // v0.42.6: mudanza (px/s al salir caminando del bioma). Salidas
    // nocturnas (Â§ 10.1.1): chance por noche de cada habitante (la base
    // para uno sin clave propia; Oren, el vidente, sale mÃ¡s).
    'resWalkSpeed': 40,
    'resNightOutBase': 0.12,
    'resNightOutIlda': 0.12,
    'resNightOutVelda': 0.12,
    'resNightOutKael': 0.12,
    'resNightOutBrann': 0.12,
    'resNightOutOren': 0.3,
    'resSettledRep': 5,
    'resRootedRep': 12,
    'resMaxTier': 5,
    'resMaxHouse': 3,
    'resHouseGold': 800,
    'resRequestEveryDays': 2,
    'resUnhappyDays': 4,
    'resRequestRep': 2,
    // v0.30.0: casa (tablas y botÃ­n del bioma por nivel), cercanÃ­a de
    // los pedidos (tiles), stock por nivel y Ã³rdenes de entrega (XP de
    // personaje con tope diario, oro, relaciÃ³n y un punto de Ã¡rbol cada
    // `orderSkillEvery` Ã³rdenes).
    'resHouseMat': 3,
    'resHouseLoot': 3,
    'resNearTiles': 6,
    'resStockRare': 1,
    'resStockLegend': 3,
    'orderEveryDays': 1,
    'orderXpPerValue': 2.0,
    'orderXpDayCap': 4000,
    'orderGoldPerValue': 0.6,
    'orderSkillEvery': 5,
    'orderRep': 1,
    'lifeLevelCharXp': 120,
    // roles.md Â§ 3 y Â§ 4: dificultad de las Ã³rdenes por oficio y encargo
    // de forja de Brann.
    'orderRarityLevels': 12,
    'orderAnyBiomeLevel': 20,
    'orderQualityLevel': 15,
    'orderSizeLevel': 8,
    'comGold': 40,
    'comMat': 4,
    'comLoot': 5,
    'comRareScore': 15,
    'comEpicScore': 40,
    'comLegendLevel': 40,
    'comIlGap': 2,
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
  TuningId.lifeTree: TuningDef('Oficios: Ã¡rboles', {
    'pointsPerLevel': 1,
    // Poder de aventurero (roles.md Â§ 5).
    'p_v': 0.04,
    'p_d': 0.04,
    'p_g': 0.04,
    'p_g_2': 0.04,
    'c_v': 0.04,
    'c_d': 0.04,
    'c_g': 0.04,
    'c_g_2': 0.04,
    // HerrerÃ­a (roles.md Â§ 6): nivel = curva de Pesca con estos nÃºmeros.
    'smithMaxLevel': 30,
    'smithXpBase': 40,
    'smithXpExp': 1.5,
    'smithXpForge': 12,
    'smithXpCommission': 60,
    'smithXpCondense': 4,
    'smithForgeCap': 0.4,
    'h_r': 0.05,
    'h_a1': 0.05,
    'h_b1': 0.04,
    'h_a2': 0.08,
    'h_b2': 0.04,
    'h_c': 0.15,
    'h_m': 0.05,
    'h_m_2': 0.05,
    'h_f': 0.08,
    'h_f_2': 0.15,
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
  // world.md Â§ "ColisiÃ³n y movimiento": px/s del jugador en el campo
  // (v0.20.19: 78 â†’ 98, +25 %).
  TuningId.exploration: TuningDef('ExploraciÃ³n', {
    'playerSpeed': 98,
    // town_loop.md Â§ 2 (v0.21.0): cinemÃ¡tica de partida del pueblo a la
    // zona, en segundos (â‰¤ 4, saltable).
    'departureSec': 3,
  }),
  // worldgen.md Â§ 6.8 (v0.20.22): misiones cortas. Tope de pisos por
  // misiÃ³n, Ã— de grupos normales por piso y Ã— del Ã¡rea de cada piso.
  // persistent_dungeons.md (v0.34.0): reapariciÃ³n y Ofrenda del jefe.
  // Costo de la Ofrenda en la zona z: esquirlas = esqBase + esqPerZone Ã— z;
  // cristales = crisPerZone Ã— (z âˆ’ crisFrom + 1) desde la zona crisFrom;
  // prismas = prismaPerZone Ã— (z âˆ’ prismaFrom + 1) desde prismaFrom.
  TuningId.dungeon: TuningDef('Mazmorras', {
    'respawnDays': 5,
    'esqBase': 2,
    'esqPerZone': 2,
    'crisFrom': 2,
    'crisPerZone': 1,
    'prismaFrom': 4,
    'prismaPerZone': 1,
    'altarReach': 40,
  }),
  // mining_smithing.md (v0.44.0): minas, vetas, fundir y forjar armas.
  TuningId.smithing: TuningDef('MinerÃ­a y herrerÃ­a', {
    'mineNodes': 7,
    'mineRespawnSec': 600,
    'mineReach': 26,
    'mineReshapeDays': 7,
    'mineOreMin': 1,
    'mineOreMax': 2,
    'mineRareChance': 0.06,
    'mineNpcChance': 0.5,
    'mineXp': 8,
    'dungeonOreChance': 0.5,
    'dungeonSchematicChance': 0.15,
    'bossCore': 1,
    'smeltOre': 3,
    'smeltGoldPerTier': 10,
    'smeltXp': 4,
    'ingotIlPerTier': 12,
    'craftIlGap': 3,
    'craftGoldPerIl': 4,
    'brannGoldPerIl': 25,
    'craftXp': 20,
    'lvMagico': 4,
    'lvRaro': 10,
    'lvEpico': 18,
    'lvLegend': 25,
    'ingotsComun': 3,
    'ingotsMagico': 4,
    'ingotsRaro': 6,
    'ingotsEpico': 8,
    'ingotsLegend': 10,
    'rareRaro': 1,
    'rareEpico': 2,
    'rareLegend': 3,
    'stackCap': 999,
  }),
  // biome_regions.md (v0.45.0): generated biome regions, side paths,
  // lakes, waystones and region foraging.
  TuningId.regions: TuningDef('Regiones de bioma', {
    // Layout: extra lakes (0..1 on top of the first), lake radii (tiles),
    // trees per 100 free tiles, plant spots per side path.
    'secondLakeChance': 0.6,
    'lakeRxMin': 3,
    'lakeRxMax': 5,
    'lakeRyMin': 2.4,
    'lakeRyMax': 3.6,
    'treeDensity': 7,
    'plantSpots': 12,
    'seedBushes': 2,
    'seasonalSpots': 2,
    // The main path (spawn -> farthest portal) must stay under this many
    // steps (biome_regions.md Â§ 2.1).
    'mainPathMax': 38,
    // Forage (Â§ 5): seed bush rare-seed weight multiplier, echo bloom
    // regrow (s), seasonal XP multiplier, echo bloom XP multiplier.
    'seedBushRareMul': 4,
    'echoBloomRespawnSec': 1800,
    'seasonalXpMul': 1.5,
    'echoBloomXpMul': 4,
    // Regrown forage only shows up out of view: a spot whose timer ran
    // out stays bare while a player is within this many px, and is
    // checked again after forageRecheckSec.
    'forageHideRadius': 360,
    'forageRecheckSec': 6,
    // Waystones (Â§ 4): reach (px) to activate / use one.
    'waystoneReach': 26,
  }),
  TuningId.mission: TuningDef('Misiones', {
    'maxFloors': 3,
    'groupScale': 0.7,
    'areaScale': 0.7,
  }),
  // ultimates_v2.md Â§ 2.4: +6% por nivel sobre el 1.
  TuningId.ultLevel: TuningDef('Escalado de ULT por nivel', {
    'perLevel': 0.06,
  }),
  // ultimates_v2.md Â§ 2.4 / materials_economy.md Â§ 6.
  TuningId.ultUpgrade: TuningDef('Costo de mejora de ULT', {
    'credits': 1000,
    'cristal': 1,
    'prismaFrom': 3,
    'fragFrom': 3,
  }),
  // Carga de la barra ULT (combat.md): daÃ±o recibido y hecho; enemigos.
  TuningId.ultCharge: TuningDef('Carga de barra ULT', {
    'takenFactor': 110,
    'dealtBase': 5,
    'dealtScale': 30,
    'dealtCap': 22,
    'enemyPerTurn': 25,
    'enemyPerHp': 100,
  }),
  // materials_economy.md Â§ 4.3 (v0.20.8: 20 Esquirlas / 8 Cristales).
  TuningId.condense: TuningDef('Recetas de Condensar', {
    'cristalCost': 20,
    'cristalCredits': 100,
    'prismaCost': 8,
    'prismaCredits': 500,
  }),
  // materials_economy.md Â§ 4.1-4.2 (economÃ­a v0.15).
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
  // materials_economy.md Â§ 4.4.
  TuningId.ecoTier: TuningDef('Bonus de tier de Ecos', {
    'tierQuantity': 0.03,
    'partyQuantity': 0.10,
  }),
  // build_planner.md Â§ 9: pesos de la guÃ­a del builder.
  TuningId.buildGuide: TuningDef('GuÃ­a del builder', {
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
    // Â§ 9.4 Consejo de arma.
    'forgeWeight': 4,
    'upgradeMinGain': 0.2,
    'buyMinGain': 0.2,
    'typeTie': 0.25,
    'howToNames': 3,
  }),
  // loot.md Â§ 17.6: precios de la tienda y Ã‰ter en cofres; combat.md Â§
  // "Revivir y el Ã¡rbol": sinergia de revivir con el Ã¡rbol.
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
  // roguelike.md Â§ 4 y Â§ 8: mejoras directas de la fila Extra, progreso
  // entre runs y curva de la TravesÃ­a. Solo lo lee la TravesÃ­a.
  TuningId.travesia: TuningDef('TravesÃ­a', {
    // Mejoras directas (Â§ 4): valor de cada una (se apilan).
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
    // Progreso entre runs (Â§ 8): moneda.
    'coinPerFloor': 10,
    'coinElite': 4,
    'coinBoss': 12,
    'coinWin': 20,
    // Zonas: las primeras del sorteo y piso que hay que alcanzar
    // (1 = el primero) para desbloquear una mÃ¡s.
    'zonesStart': 3,
    'zoneUnlockFloor': 2,
    // Ã‰lites: niveles extra por cada vez que ya se venciÃ³ a esa Ã©lite.
    'eliteRepeatLevel': 2,
    // Dificultad: + por nivel a ATQ y vida enemigos (acumulativo).
    'diffAtk': 0.08,
    'diffHp': 0.10,
    'diffMax': 5,
    // Sin niveles (v0.3.0): el personaje crece solo con recompensas.
    // Puntos de la recompensa de atributo y niveles por encima de los
    // enemigos de la entrada del piso de las armas ofrecidas.
    'attrReward': 5,
    // Habilidades (Â§ 12.2): tope total contando ATACAR y DEFENDER (las
    // del arma no cuentan), habilidades nuevas en la fila Extra y mejora
    // en la armerÃ­a (oro base Ã— nivel siguiente, + poder por nivel, tope).
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
    // Nivel de los enemigos: 1 + piso Ã— levelPerFloor + capa Ã—
    // levelPerLayer (+ Ã©lite / jefe).
    'levelPerFloor': 4,
    'levelPerLayer': 0.25,
    // Vida y ATQ de los enemigos de la TravesÃ­a (Ã— sobre la curva del
    // Mundo, antes de la dificultad).
    'enemyHp': 0.4,
    'enemyAtk': 0.3,
  }),
  // combat.md Â§ "LÃ­mites": efectos encadenados por acciÃ³n, tope de daÃ±o
  // por golpe de jefes y Ã©lites, "aguanta una ronda" de los comunes y
  // rendimientos decrecientes de la velocidad.
  TuningId.combatLimits: TuningDef('LÃ­mites de combate', {
    // Efectos encadenados: total por acciÃ³n y profundidad de la cadena
    // (un efecto que dispara otro que dispara otro...).
    'procMax': 64,
    'procDepth': 6,
    // Tope absoluto por golpe (fracciÃ³n de la vida mÃ¡xima; 0 = sin
    // tope). Vale siempre, tambiÃ©n con debilidad, reacciÃ³n o quiebre.
    'capBoss': 0.35,
    'capElite': 0.60,
    'capCommon': 0,
    // Aguanta una ronda (1 = sÃ­): el primer golpe letal a un comÃºn antes
    // de que actÃºen todos los jugadores vivos lo deja en 1 de vida.
    'holdCoop': 1,
    'holdSolo': 0,
    // Nobody alone kills it in one phase (combat.md Â§ "Nadie solo en una
    // fase"): an enemy at or above this fraction of its max HP when a
    // character's phase began survives that character's lethal hit at 1
    // HP if another living ally can still finish it (0 = off).
    'phaseHold': 0.5,
    // Tanks (combat.md Â§ "Tanques"): elemental ward (Ã— damage of that
    // element), its duration in own turns and Defense (Ã— damage taken).
    'wardMult': 0.5,
    'wardTurns': 3,
    'tankGuard': 0.7,
    // Enemy Silence (combat.md Â§ "Silencio"): own turns of the silenced
    // player, how often a silencer recasts it (0 = only when it opens
    // the fight) and whether it also blocks the ULT (1 = yes).
    'silenceTurns': 2,
    'silenceEvery': 4,
    'silenceUlt': 1,
    // Player break bar (combo_balance.md Â§ 5.4): on (1), threshold,
    // points per enemy hit and per 1% of max HP lost, decay at the start
    // of its turn, own turns broken and Ã— damage taken while broken.
    'pBreakOn': 1,
    'pBreakMax': 100,
    'pBreakHit': 10,
    'pBreakHp': 0.6,
    'pBreakDecay': 0.1,
    'pBrokenTurns': 2,
    'pBrokenMult': 1.25,
    // Enemy Convergences (combo_balance.md Â§ "Convergencias enemigas"):
    // on (1); cap of a Convergence against a player (fraction of its max
    // HP, also caps the splash); group AI: chance a primer / detonator
    // focuses the primed player and stacks the detonator waits for; lone
    // enemy (only if its own kit has both elements): chance per hit to go
    // for the primed player and stacks it waits for before detonating.
    'eConvOn': 1,
    'eConvCapPlayer': 0.28,
    'eComboFocus': 0.6,
    'eComboMinStacks': 4,
    'eSoloChance': 0.25,
    'eSoloMinStacks': 6,
    // Turnos como mÃ¡ximo por cada turno del aliado vivo mÃ¡s lento
    // (0 = sin tope).
    'turnsPerSlowest': 2,
    // Velocidad efectiva sobre el umbral: lo que sobra rinde Ã— el factor.
    'speedSoftCap': 16,
    'speedSoftFactor': 0.5,
    // Carga de ULT extra (Ã¡rbol, mods, efectos e invocaciones): tope por
    // acciÃ³n y por turno de quien la recibe, en puntos de la barra (100).
    'ultBonusAction': 50,
    'ultBonusTurn': 50,
    // Modo de combate por defecto de la sala (turn_modes.md Â§ 1): 0 lÃ­nea
    // de tiempo, 1 por rondas, 2 por fases.
    'modeCoop': 1,
    'modeSolo': 1,
    // Por fases: pausa de planificaciÃ³n al abrir la fase de jugadores (s).
    'planPause': 2,
  }),
};

/// Los valores vigentes (cÃ³digo o parche instalado).
final Map<String, TuningDef> kTuning = Map.of(kTuningDefaults);

/// El grupo [id] vigente.
TuningDef tuning(String id) => kTuning[id]!;
