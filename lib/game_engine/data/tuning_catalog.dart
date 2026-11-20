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
  // materials_economy.md § 4.3.
  TuningId.condense: TuningDef('Recetas de Condensar', {
    'cristalCost': 10,
    'cristalCredits': 100,
    'prismaCost': 10,
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
    'addAffixCredits': 50,
    'rerollCredits': 25,
  }),
  // materials_economy.md § 4.4.
  TuningId.ecoTier: TuningDef('Bonus de tier de Ecos', {
    'tierQuantity': 0.03,
    'partyQuantity': 0.10,
  }),
};

/// Los valores vigentes (código o parche instalado).
final Map<String, TuningDef> kTuning = Map.of(kTuningDefaults);

/// El grupo [id] vigente.
TuningDef tuning(String id) => kTuning[id]!;
