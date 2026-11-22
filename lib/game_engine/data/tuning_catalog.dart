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
}

/// Los valores del código.
const Map<String, TuningDef> kTuningDefaults = {
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
};

/// Los valores vigentes (código o parche instalado).
final Map<String, TuningDef> kTuning = Map.of(kTuningDefaults);

/// El grupo [id] vigente.
TuningDef tuning(String id) => kTuning[id]!;
