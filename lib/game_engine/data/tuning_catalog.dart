// Números sueltos de reglas (economía, mejora y carga de ULT, Ecos) que
// el parche de balance puede tocar (docs/specs/balance_admin.md § 1.1,
// tipos de "Ajustes"). Cada grupo es una entidad del parche; el código
// lee siempre [kTuning], que `BalanceRegistries.install` cambia en el
// lugar y `restore` devuelve a estos valores.

import 'life_tree_catalog.dart' show kLifeTreeTuning;

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
  static const dungeon = 'dungeon';
  static const smithing = 'smithing';
  static const regions = 'regions';
  static const ascension = 'ascension';
  static const gear = 'gear';
  static const gearV2 = 'gearV2';
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
    // Fishing ambience (biome_regions.md § 7.2.3): music level while
    // fishing outside the town, seconds to duck / return, volume of the
    // ambience sounds and the gap between them (s).
    'ambMusicLevel': 0.08,
    'ambDuckSec': 1.5,
    'ambVolume': 0.35,
    'ambGapMinSec': 8,
    'ambGapMaxSec': 20,
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
    // Bestiario de pesca (fishing.md § 10): primera captura de cada
    // especie, × su XP normal; XP de personaje por rareza × este factor.
    'firstCatchFishXp': 5,
    'firstCatchCharXp': 4,
    // Cebos (fishing.md § 14, v0.44.0): × copies of the fish a bait
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
    // Agua brillante (fishing.md § 11).
    'spotRare': 0.35,
    'spotLoot': 0.25,
    'spotRadius': 2,
    // Balsas de los lagos grandes (fishing.md § 15): velocidad (× la de
    // caminar), tiles de agua para que un lago tenga muelle, alcance
    // (tiles) del muelle y de la orilla para bajar, y lo que suma cada
    // tile de distancia a la orilla (rareza / tamaño, con tope).
    'raftSpeed': 0.8,
    'raftMinLakeTiles': 70,
    'raftDockReach': 1.5,
    'raftShoreReach': 1.2,
    'deepRarePerTile': 0.08,
    'deepRareMax': 0.5,
    'deepSizePerTile': 0.05,
    'deepSizeMax': 0.3,
    // Horarios de los peces (fishing.md § 13): chance de que un pez fuera
    // de su franja entre igual en la tirada.
    'offHoursChance': 0.03,
    // Pescador nativo del bioma (fishing.md § 12).
    'fisherRarityLevels': 6,
    'fisherXpBase': 30,
    'fisherXpStep': 6,
    'fisherCharXpPerValue': 1.5,
    'fisherGoldPerValue': 0.6,
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
    // Afinidad de los cultivos con la hora y el clima (farming.md § 14).
    'affinityBonus': 0.25,
    'affinityMalus': 0.1,
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
    'dryRate': 0.5,
    'waterSec': 240,
    'waterRateMin': 0.6,
    'workXp': 3,
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
    // Compost-only fertilizers (profession_gear.md § 3.3).
    'fertBrasaBias': 0.6,
    'fertBrasaSpeed': 1.2,
    'fertMielBias': 0.6,
    'fertMielSpeed': 1.2,
    'fertEscarchaBias': 0.6,
    'fertEscarchaSpeed': 1.2,
    // × de precio y XP por calidad.
    'qualityMultNormal': 1,
    'qualityMultRaro': 1.3,
    'qualityMultEpico': 1.8,
    'qualityMultLegendario': 3,
    // Semillas: chance de que la cosecha devuelva una (no legendarias).
    'seedDropChance': 0.55,
    // Hallazgos de la huerta (farming.md § 5): chance, pesos, mejora por
    // nivel, pity del hallazgo y de la semilla legendaria.
    'lootChance': 0.12,
    'lootSemilla': 60,
    'lootMateriales': 35,
    'lootLegendaria': 5,
    'lootLevelBonus': 0.03,
    'lootPityAfter': 40,
    'legendPityAfter': 100,
    'lootMatMin': 1,
    'lootMatMax': 2,
    // Agropecuario: × en materiales, oro por Esquirla y canje de un
    // legendario.
    'matRate': 1.2,
    'matValue': 25,
    'legendCristales': 3,
    'legendPrismas': 1,
    // Estación (farming.md § 16): los cultivos de estación (no los de todo
    // el año) en su estación se venden × seasonPriceMult y crecen ×
    // seasonGrowMult.
    'seasonPriceMult': 1.3,
    'seasonGrowMult': 1.2,
    // Cocina (farming.md § 17): buff = (mealBuffBase × qualityMult<Q> +
    // mealBuffPerQuality × índice de calidad), dura mealMissions misiones
    // (+1 si la receta lleva pescado).
    'mealBuffBase': 0.05,
    'mealBuffPerQuality': 0.03,
    'mealMissions': 2,
    // farming.md § 19: misiones extra por escalón, ingredientes del
    // festín y extras de la comida legendaria.
    'mealMissionsRaro': 0,
    'mealMissionsEpico': 1,
    'mealMissionsLegendario': 1,
    'mealFeastMult': 2.0,
    'mealRegen': 0.03,
    'mealBreak': 0.25,
    'mealShield': 0.12,
    'mealShieldTurns': 3,
    // Validación del host: alcance (px) y segundos entre labores.
    'reachPx': 30,
    'minWorkSec': 0.15,
  }),
  // farming.md § 6–8 (v0.23.0): ampliaciones, lago y ayudante.
  TuningId.town: TuningDef('Pueblo', {
    // World labels (ui_style.md § "Etiquetas en el mundo"): names over
    // NPCs, places and objects show only within this many tiles of the
    // local player (then fade over one tile). Players' names always show.
    'labelRevealTiles': 4.5,
    // Dar materiales de oficio (share_materials.md § 3): el botón del
    // medio del selector de cantidad (1 / giveStep / todo).
    'giveStep': 5,
    // Player stall (player_shop.md § 3): listings, top price over the
    // reference, visitors per world day and their buy chance / amount,
    // and how many sales the log keeps.
    'stallSlots': 6,
    'stallMaxMarkup': 3,
    'stallVisitors': 3,
    'stallBaseChance': 0.6,
    'stallElasticity': 2,
    'stallMaxChance': 0.95,
    'stallMaxBuy': 3,
    'stallLogCap': 20,
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
    'helperPlots': 12,
    'fisherTiles': 18,
    'fisherCatch': 2,
    'helperEverySec': 45,
    // Pescador en pantalla (farming.md § 8.1, v0.48.2): respiración (s
    // por px), momento de la pesca tras cada vuelta (s), cada cuántos s
    // cambia de lugar en la orilla y s por tile al caminar.
    'fisherBreathSec': 1.75,
    'fisherCatchSec': 0.7,
    'fisherMoveSec': 240,
    'fisherWalkTileSec': 0.45,
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
    // Seasons and weather per biome (weather_seasons.md § 1–2, v0.44.0):
    // days per season, weight of each weather per season (snow only in
    // winter), × of each weather per biome (no key = × 1) and fog / snow
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
    // Auto-fishing (fishing.md § 6): × bite wait, × rod / tree bonuses,
    // × epic weight and × XP (Fishing and character).
    'autoWaitMult': 2.0,
    'autoPassiveMult': 0.5,
    'autoEpicMult': 0.25,
    'autoXpMult': 0.5,
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
    // v0.42.6: mudanza (px/s al salir caminando del bioma). Salidas
    // nocturnas (§ 10.1.1): chance por noche de cada habitante (la base
    // para uno sin clave propia; Oren, el vidente, sale más).
    'resWalkSpeed': 40,
    'resNightOutBase': 0.12,
    'resNightOutIlda': 0.12,
    'resNightOutVelda': 0.12,
    'resNightOutKael': 0.12,
    'resNightOutBrann': 0.12,
    'resNightOutOren': 0.3,
    'resSettledRep': 5,
    // roles.md § 9.4 (v0.48.x): Rooted is easier to reach (was 12).
    'resRootedRep': 10,
    'resMaxTier': 5,
    'resMaxHouse': 3,
    'resHouseGold': 800,
    'resRequestEveryDays': 2,
    'resUnhappyDays': 4,
    'resRequestRep': 2,
    // v0.30.0: casa (tablas y botín del bioma por nivel), cercanía de
    // los pedidos (tiles), stock por nivel y órdenes de entrega (XP de
    // personaje con tope diario, oro, relación y un punto de árbol cada
    // `orderSkillEvery` órdenes).
    'resHouseMat': 3,
    'resHouseLoot': 3,
    'resNearTiles': 6,
    'resStockRare': 1,
    'resStockLegend': 3,
    // overworld_biomes.md § 9.1.1: materials by role, x trader price.
    'resWareMarkup': 2.0,
    'orderEveryDays': 1,
    'orderXpPerValue': 2.0,
    'orderXpDayCap': 4000,
    'orderGoldPerValue': 0.6,
    // farming.md § 19.1: pedidos de comidas cocinadas.
    'mealOrderPay': 1.8,
    'mealOrderChance': 0.35,
    'mealOrderLevel': 5,
    'mealOrderMin': 1,
    'mealOrderMax': 2,
    'orderSkillEvery': 5,
    // roles.md § 9.4: relationship per delivered order (was 1).
    'orderRep': 2,
    // roles.md § 9: resident milestone track (relationship needed per
    // reward, amounts, endgame extras with Ecos unlocked) and the bonus
    // chest a delivered order sometimes rolls.
    'msRepChest': 2,
    'msRepMaterial': 4,
    'msRepMeal': 7,
    'msRepSilver': 14,
    'msRepWeapon': 18,
    'msRepEco': 24,
    'msRepUnique': 30,
    'msMaterialN': 4,
    'msMealN': 2,
    'msEndShards': 3,
    'msEndCrystals': 2,
    'msEndAnchors': 1,
    'orderChestChance': 0.12,
    'lifeLevelCharXp': 120,
    // roles.md § 3 y § 4: dificultad de las órdenes por oficio y encargo
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
  TuningId.lifeTree: TuningDef('Oficios: árboles', {
    'pointsPerLevel': 1,
    // life_trees_v2.md § 2: tier t asks for level step × (t − 1) + 1.
    'tierLevelStep': 3,
    // Herrería (roles.md § 6): nivel = curva de Pesca con estos números.
    'smithMaxLevel': 30,
    'smithXpBase': 40,
    'smithXpExp': 1.5,
    'smithXpForge': 12,
    'smithXpCommission': 60,
    'smithXpCondense': 4,
    'smithForgeCap': 0.4,
    // Every node effect and grant amount (life_trees_v2.md § 7).
    ...kLifeTreeTuning,
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
  // persistent_dungeons.md (v0.34.0): reaparición y Ofrenda del jefe.
  // Costo de la Ofrenda en la zona z: esquirlas = esqBase + esqPerZone × z;
  // cristales = crisPerZone × (z − crisFrom + 1) desde la zona crisFrom;
  // prismas = prismaPerZone × (z − prismaFrom + 1) desde prismaFrom.
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
  TuningId.smithing: TuningDef('Minería y herrería', {
    // Mining v2 (mining_smithing.md § 1): levels, rock, veins, tools.
    'mineLevels': 4,
    'mineW': 72,
    'mineH': 48,
    'mineReach': 26,
    'caveDensity': 0.0,
    'formations': 6,
    'streamChance': 0.5,
    'lakeChance': 0.3,
    'chambers': 6,
    'minerYield': 0.5,
    'minerUpGold': 250,
    'minerUpIngots': 4,
    'discoverLit': 4.0,
    'discoverView': 9.0,
    'veinGlow': 1.0,
    'veinGlowRich': 1.3,
    'veinGlowDeep': 1.6,
    'veinGlowGem': 2.0,
    'chamberMin': 1,
    'chamberMax': 2,
    'grottoChance': 0.35,
    'secretChance': 0.6,
    'relicChance': 0.35,
    'mushroomChance': 0.6,
    'loreChance': 0.5,
    'chestRate': 0.3,
    'rockHits': 3,
    'rockHitsPerLevel': 2,
    'veinHitMult': 1.5,
    'reqTierLv0': 0,
    'reqTierLv1': 1,
    'reqTierLv2': 2,
    'reqTierLv3': 3,
    'reqTierLv4': 4,
    'veinClusters': 22,
    'veinClustersPerLevel': 3,
    'veinSizeMin': 3,
    'veinSizeMax': 7,
    'wCommon': 70,
    'wRich': 10,
    'wRichPerLevel': 6,
    'wDeep': 0,
    'wDeepPerLevel': 8,
    'wGem': 2,
    'wGemPerLevel': 3,
    'rich_bosque': 1.0,
    'rich_ruinas': 1.0,
    'rich_cavernas': 1.1,
    'rich_grieta': 1.2,
    'rich_abismo': 1.3,
    'richOreBonus': 2,
    'richRareChance': 0.2,
    'crystalRareChance': 0.1,
    'digXp': 1,
    'tool0Power': 1,
    'tool0Swing': 0.38,
    'tool0Yield': 0.0,
    'tool0Gold': 0,
    'tool0Ingots': 0,
    'tool1Power': 1,
    'tool1Swing': 0.3,
    'tool1Yield': 0.05,
    'tool1Gold': 150,
    'tool1Ingots': 4,
    'tool2Power': 2,
    'tool2Swing': 0.28,
    'tool2Yield': 0.1,
    'tool2Gold': 400,
    'tool2Ingots': 6,
    'tool3Power': 2,
    'tool3Swing': 0.22,
    'tool3Yield': 0.18,
    'tool3Gold': 900,
    'tool3Ingots': 8,
    'tool4Power': 3,
    'tool4Swing': 0.1,
    'tool4Yield': 0.25,
    'tool4Gold': 2000,
    'tool4Ingots': 10,
    'torchGold': 4,
    'torchOre': 1,
    'torchBatch': 5,
    'bombGold': 40,
    'bombOre': 2,
    'bombRadius': 2,
    'bombFuse': 1.2,
    'oilGold': 60,
    'oilOre': 3,
    'boostSec': 180,
    'boostRare': 1.0,
    'boostYield': 0.5,
    'regrowSec': 900,
    'regrowRadius': 3,
    'regrowSafeTiles': 12,
    'minerCost': 300,
    'minerMax': 3,
    'minerStepSec': 1.2,
    'minerPower': 1,
    'minerTorchEvery': 8,
    'stationGold': 200,
    'stationIngots': 4,
    'cartCap': 30,
    'cartTravelSec': 90,
    'cartBackSec': 60,
    // Smith income (§ 2.2): trader prices and smithing orders.
    'orePricePerTier': 6,
    'ingotPricePerTier': 34,
    'rarePricePerTier': 45,
    'specialPrice': 150,
    'forgedSellMult': 1.5,
    'forgedSellPerRarity': 0.25,
    'smithOrderChance': 0.35,
    'smithOrderMin': 3,
    'smithOrderMax': 6,
    'smithOrderPay': 1.6,
    // Forged weapon orders (§ 2.2): a weapon of a type, min rarity and
    // min item level, forged at the HERRERÍA.
    'forgeOrderLevel': 4,
    'forgeOrderChance': 0.3,
    'forgeOrderPay': 1.5,
    'forgeOrderXp': 30,
    'forgeOrderMaxRarity': 3,
    'mineOreMin': 1,
    'mineOreMax': 2,
    'mineRareChance': 0.06,
    'mineBaitChance': 0.05,
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
  // profession_gear.md (v0.50): profession weapons, weapon seeds, the
  // sub-path mechanics of the life trees and the parity model.
  TuningId.gear: TuningDef('Oficios: equipo', {
    // § 3 Living weapons: growth, care and quality.
    'livingGrowSec': 1500,
    'livingCompostMax': 3,
    'livingWaterQ': 0.6,
    'livingCompostQ': 0.3,
    'livingAncientQ': 0.4,
    'livingLevelQ': 0.035,
    'livingTreeQ': 2,
    'livingFina': 0.8,
    'livingExcelente': 1.3,
    'livingLegend': 1.7,
    'livingLegendCompost': 2,
    'livingLegendTree': 0.15,
    'livingRegrowLevels': 3,
    'livingItemLevelPerFarm': 1.5,
    'livingHarvestXp': 120,
    // § 3.1 Where weapon seeds come from.
    'seedSearchChance': 0.12,
    'seedMineChestChance': 0.2,
    'seedOrderChance': 0.25,
    'seedMutateShare': 0.08,
    'seedAncientChance': 0.15,
    // § 4 Pesca: sunken echo weapons and the fish forge.
    'sunkenShare': 0.8,
    'sunkenChestChance': 0.95,
    'sunkenChestFade': 0.02,
    'sunkenDepth': 0.05,
    'sunkenEpic': 0.95,
    'sunkenLegend': 0.035,
    'sunkenLegendTree': 0.0,
    'fishForgeGold': 600,
    'fishForgeLegend': 0.15,
    'fishForgeLegendTree': 0.2,
    'fishForgeLevel': 12,
    // § 4.3 Fishing sub-paths.
    'netEverySec': 60,
    'harpoonDepth': 2,
    'twinMax': 0.6,
    'calmMax': 0.6,
    'raftMax': 0.5,
    // § 5 Herrería: forge-only weapons and its sub-paths.
    'forgeGearChance': 0.25,
    'forgeGearLevel': 5,
    'forgeTierShare': 0.3,
    'veinAreaMax': 4,
    'mineSpeedMax': 0.5,
    'detectMax': 12,
    // § 6 Meals.
    'mealPowerMax': 1,
    // § 7 Parity model (activity of one hour of play, per profession).
    'parityCatchesPerHour': 110,
    'parityVeinsPerHour': 100,
    'parityPlots': 9,
    'parityTreeSearchesPerHour': 10,
    'parityOrdersPerHour': 1,
    'parityChestsPerHour': 2,
    'parityAutoShare': 0.5,
    'parityRarityRaro': 1,
    'parityRarityEpico': 2.5,
    'parityRarityLegendario': 8,
  }),
  // profession_gear_v2.md: forge by parts, fish taken apart, living
  // weapons of every type; quality, slots and the manual edge.
  TuningId.gearV2: TuningDef('Oficios: equipo v2', {
    // § 2 Quality q (0..1) and mod slots.
    'slotLevelCap': 30,
    'slotLevelW': 0.3,
    'slotMatW': 0.2,
    'slotManualW': 0.5,
    'autoQualityShare': 0.2,
    'masterworkQ': 0.85,
    'settingQ': 0.1,
    // § 3 Forge by parts: rarity by q and cost.
    'forgeQMagico': 0.15,
    'forgeQRaro': 0.3,
    'forgeQEpico': 0.55,
    'forgeQLegend': 0.85,
    'partsBaseIngots': 8,
    // § 4 Fish taken apart at Brann's.
    'fishPartGold': 150,
    'fishPartLevel': 5,
    'fishScaleEpic': 2,
    'fishScaleLegend': 3,
    'fishBone': 1,
    'fishEssenceEpic': 1,
    'fishEssenceLegend': 2,
    // § 1 ULT of a Legendary profession weapon.
    'legendUltChance': 1,
    // § 2 Parity model.
    'parityExtraSlotW': 0.5,
    'parityManualEdge': 1.15,
  }),
  // ascension.md § 3 (v0.49): points, branch stats and Trades conditions
  // of the ascension tree v2.
  TuningId.ascension: TuningDef('Ascensión', {
    'pointsPerTrial': 7,
    'maxCapstones': 1,
    'minorHp': 0.02,
    'minorAtk': 0.02,
    'minorMag': 0.02,
    'minorDef': 1,
    'minorCrit': 0.01,
    'minorSpd': 0.1,
    'minorUlt': 0.03,
    'minorHeal': 0.03,
    'overloadStacks': 1,
    'forgedLevel': 3,
    'masteryLevel': 5,
    'townPerCondition': 0.03,
  }),
  TuningId.regions: TuningDef('Regiones de bioma', {
    // Water reflections (water_reflections.md): strength per water kind,
    // tint toward the water colour, shore rows and actor reach (tiles),
    // actor caps per quality, wave (px, rad/s, rows per cycle), wake,
    // fade steps (px from the water line), sky veil and clouds, night
    // light glows (length px, opacity) and stars, auto-low frame time
    // (ms), bank opacity and lip (px), drop of the water line under an
    // actor afloat (px), warm dusk tint of the water surface.
    'reflAlpha': 0.74,
    'reflMurkyAlpha': 0.46,
    'reflTint': 0.16,
    'reflRows': 1,
    'reflActorReach': 1,
    'reflActorFadeTiles': 1,
    'reflMaxLen': 24,
    'reflActorsHigh': 16,
    'reflActorsLow': 6,
    'reflWaveAmp': 1,
    'reflWaveSpeed': 1.4,
    'reflWaveRows': 7,
    'reflWakeRadius': 22,
    'reflWakeAmp': 2,
    'reflFade1': 10,
    'reflFade2': 20,
    'reflSkyAlpha': 0.3,
    'reflCloudAlpha': 0.5,
    'reflGlowLen': 14,
    'reflGlowAlpha': 0.6,
    'reflBankAlpha': 0.45,
    'reflBankLip': 2,
    'reflFloatDrop': 10,
    'reflDuskTint': 0.16,
    'reflStars': 7,
    'reflAutoLowMs': 25,
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
    // steps (biome_regions.md § 2.1).
    'mainPathMax': 38,
    // The wilds (biome_exploration.md § 2–6): section cell (tiles),
    // trail noise, tree density per 100 by section kind, giant lake
    // chance and radii, caverns with a lake / with beams, hidden nooks,
    // forage per section, chests, extra trail loops and the mine count.
    'wildCell': 20,
    'wildTrailNoise': 2.5,
    'wildForestDensity': 55,
    'wildMeadowDensity': 6,
    'wildDensity': 22,
    'giantLakeChance': 0.5,
    'giantLakeRxMin': 16,
    'giantLakeRxMax': 20,
    'giantLakeRyMin': 10,
    'giantLakeRyMax': 12,
    'cavernLakeChance': 0.5,
    'cavernShaftChance': 0.4,
    'hiddenNookChance': 0.45,
    'wildForagePerSection': 2,
    'wildChestChance': 0.6,
    'wildExtraLoops': 4,
    'minesMin': 2,
    'minesMax': 3,
    // Exploration content per biome and day (§ 6): chance of a roll and
    // the most deep actors at once; shrine gold.
    'exploreChance': 0.85,
    'exploreMax': 2,
    'shrineGold': 40,
    // Forage (§ 5): seed bush rare-seed weight multiplier, echo bloom
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
    // Cozy life (cozy_life.md § 1): while fishing the camera shows this
    // fraction of the map (< 1 = closer), the HUD fades / shrinks, up to
    // cozyFireflies fireflies at night, the cozy music level and the gap
    // between ambience sounds (s).
    'cozyFishZoom': 0.85,
    'cozyHudOpacity': 0.45,
    'cozyHudScale': 0.9,
    'cozyFireflies': 10,
    'cozyMusicLevel': 0.6,
    'cozyAmbGapMinSec': 5,
    'cozyAmbGapMaxSec': 14,
    // Raft decorations (§ 1), gold.
    'raftLanternCost': 60,
    'raftRoofCost': 120,
    'raftPaintCost': 40,
    // Farm decorations (§ 2), gold; scarecrow quality bias and reach.
    'decorFenceCost': 10,
    'decorScarecrowCost': 80,
    'decorPotCost': 20,
    'decorPathCost': 5,
    'decorLampCost': 40,
    'scarecrowQualityBias': 0.05,
    'scarecrowRadius': 4,
    // Hold-to-gather (§ 3): base hold (s), speed per Cultivo level, floor.
    'gatherHoldSec': 1.2,
    'gatherSpeedPerLevel': 0.03,
    'gatherHoldMinSec': 0.4,
    // Hold = repeat (§ 3): seconds between repeats of a held E / click.
    'holdRepeatSec': 0.25,
    // Tree search (§ 3): chance of each find (rest = nothing) and XP.
    'searchSeedChance': 0.3,
    'searchMushroomChance': 0.2,
    'searchNestChance': 0.12,
    'searchRecipeChance': 0.05,
    'searchXp': 3,
    // Waystones (§ 4): reach (px) to activate / use one.
    'waystoneReach': 26,
    // Overworld map discovery (biome_exploration.md § 11.4): tiles each
    // player reveals around them, and tiles known from the start around
    // the arrival and the story goals.
    'mapRevealRadius': 9,
    'mapStartRadius': 5,
    // Dungeon map discovery (§ 11.8): same, inside mission floors.
    'dungeonMapRevealRadius': 7,
    'dungeonMapStartRadius': 4,
    // Caverns (§ 3.1): × of the lake radii, thickness of the rock rim
    // (tiles) and the most openings above (0 = none).
    'caveScaleX': 2.0,
    'caveScaleY': 2.2,
    'caveWallTiles': 2.5,
    'caveSkylightsMax': 2,
    // Cavern look (§ 7.2.1): darkness by day, extra darkness against
    // the walls and over how many tiles it fades, share of floor tiles
    // with a glowing speck, water glow alpha, mist noise layers and their
    // drift (px/s), seconds between drip ripples.
    'caveDark': 0.78,
    'caveVignette': 0.6,
    'caveVignetteTiles': 3,
    'caveSpecks': 0.06,
    'caveWaterGlow': 0.16,
    'caveMistBands': 2,
    'caveMistSpeed': 3,
    'caveDripSec': 3.5,
    // Roofed caves (§ 7.2.1): roof lip at the mouth (px), light pools
    // under the openings (alpha, half-size px, pixel step), dust motes
    // per pool and their drift speed (cycles/s).
    'caveRoofLip': 9,
    'cavePoolAlpha': 0.07,
    'cavePoolSize': 13,
    'cavePoolPixel': 3,
    'caveMotes': 3,
    'caveMoteSpeed': 0.05,
    // Wind sway of grass, bushes and canopies (§ 7.2.2): px, speed
    // (rad/s) and the share of vegetation tiles that sway.
    'swayAmp': 1,
    'swaySpeed': 1.6,
    'swayDensity': 0.3,
  }),
  TuningId.mission: TuningDef('Misiones', {
    'maxFloors': 3,
    'groupScale': 0.7,
    'areaScale': 0.7,
    // free_movement.md § 2.1.1: seconds a gathering waits before the
    // proposer (and whoever joined) enters on their own.
    'gatherSeconds': 20,
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
    // ecos_atlas.md § 4.2: Ecos del mismo tier por fusión y Anclas extra.
    'fuseCount': 3,
    'fuseAnchors': 0,
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
    'diffAtk': 0.12,
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
    // Balance pass (§ 12.3): boss HP / ATQ multipliers and the class kit
    // (% damage, flat DEF and status resist per class; world mode never reads these).
    'bossHp': 1.6,
    'bossAtk': 1.3,
    'classDmgGuerrero': 0,
    'classDmgMaga': 0,
    'classDmgPaladin': 0,
    'classDmgTirador': 0,
    'classDefGuerrero': 0,
    'classDefMaga': 10,
    'classDefPaladin': -8,
    'classDefTirador': 13,
    'classResistGuerrero': 0,
    'classResistMaga': 1,
    'classResistPaladin': 1,
    'classResistTirador': 0,
    // Nivel de los enemigos: 1 + piso × levelPerFloor + capa ×
    // levelPerLayer (+ élite / jefe).
    'levelPerFloor': 6,
    'levelPerLayer': 0.25,
    // Vida y ATQ de los enemigos de la Travesía (× sobre la curva del
    // Mundo, antes de la dificultad).
    'enemyHp': 0.4,
    'enemyAtk': 0.36,
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
    // Nobody alone kills it in one phase (combat.md § "Nadie solo en una
    // fase"): an enemy at or above this fraction of its max HP when a
    // character's phase began survives that character's lethal hit at 1
    // HP if another living ally can still finish it (0 = off).
    'phaseHold': 0.5,
    // Tanks (combat.md § "Tanques"): elemental ward (× damage of that
    // element), its duration in own turns and Defense (× damage taken).
    'wardMult': 0.5,
    'wardTurns': 3,
    'tankGuard': 0.7,
    // Enemy Silence (combat.md § "Silencio"): own turns of the silenced
    // player, how often a silencer recasts it (0 = only when it opens
    // the fight) and whether it also blocks the ULT (1 = yes).
    'silenceTurns': 1,
    'silenceEvery': 4,
    'silenceUlt': 1,
    'silenceCooldown': 1,
    // Player break bar (combo_balance.md § 5.4): on (1), threshold,
    // points per enemy hit and per 1% of max HP lost, decay at the start
    // of its turn, own turns broken and × damage taken while broken.
    'pBreakOn': 1,
    'pBreakMax': 100,
    'pBreakHit': 10,
    'pBreakHp': 0.6,
    'pBreakDecay': 0.1,
    'pBrokenTurns': 2,
    'pBrokenMult': 1.25,
    // Enemy stun on a player becomes this fraction of its break threshold
    // (combat.md § "Control sobre jugadores").
    'pStunBreak': 0.35,
    // Enemy Convergences (combo_balance.md § "Convergencias enemigas"):
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
    'modeSolo': 1,
    // Por fases: pausa de planificación al abrir la fase de jugadores (s).
    'planPause': 2,
  }),
};

/// Los valores vigentes (código o parche instalado).
final Map<String, TuningDef> kTuning = Map.of(kTuningDefaults);

/// El grupo [id] vigente.
TuningDef tuning(String id) => kTuning[id]!;
