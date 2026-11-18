import '../models/exploration.dart';
import '../models/game_map.dart';
import '../models/item.dart';
import '../models/zone_def.dart';

// Números de la exploración v0.6 (docs/specs/worldgen.md § 11 y loot.md
// § 23). Todo dato: las reglas están en `rules/exploration_rules.dart`.

/// Una bendición de santuario (worldgen.md § 11.4).
class BlessingDef {
  const BlessingDef(this.kind, this.name, this.effect, {this.mods = const []});
  final BlessingKind kind;
  final String name;

  /// Texto corto del efecto (HUD, cartel, chat).
  final String effect;

  /// Implícitos extra del arma equipada mientras dura (en batalla).
  final List<ItemMod> mods;
}

const Map<BlessingKind, BlessingDef> kBlessings = {
  BlessingKind.fuerza: BlessingDef(BlessingKind.fuerza, 'Bendición de Fuerza',
      '+10% ATQ y MAG',
      mods: [ItemMod(ModStat.atkPct, 10), ItemMod(ModStat.magPct, 10)]),
  BlessingKind.vigor: BlessingDef(BlessingKind.vigor, 'Bendición de Vigor',
      'cura al grupo, +3% vida por turno y regeneración ×3',
      mods: [ItemMod(ModStat.regen, 3)]),
  BlessingKind.fortuna: BlessingDef(BlessingKind.fortuna,
      'Bendición de Fortuna', 'mejor loot y tiradas extra'),
  BlessingKind.reloj: BlessingDef(BlessingKind.reloj, 'Bendición del Reloj',
      '+25% carga de ULT y +5% crítico',
      mods: [ItemMod(ModStat.ultCharge, 25), ItemMod(ModStat.critChance, 5)]),
};

/// Regeneración del campo con la Bendición de Vigor (multiplicador).
const kVigorFieldRegen = 3.0;

/// Bendición de Fortuna: bonus de rareza y chance de una tirada extra.
const kFortuneRarity = 0.5;
const kFortuneExtraRoll = 0.30;

/// Una calidad de cofre (loot.md § 23.1). Por jugador.
class ChestTierDef {
  const ChestTierDef({
    required this.tier,
    required this.name,
    required this.weight,
    required this.weaponChance,
    required this.rarityBonus,
    required this.extraMaterialRolls,
    required this.consumableChance,
    required this.creditMult,
    this.guaranteedRare = false,
    this.themeChance = 0,
    this.ecoChance = 0,
    this.anchorChance = 0,
    this.esquirlas = 0,
  });

  final ChestTier tier;

  /// "un cofre", "un cofre reforzado", "un cofre dorado".
  final String name;

  /// Peso al azar de los cofres comunes del piso.
  final double weight;
  final double weaponChance;
  final double rarityBonus;
  final int extraMaterialRolls;
  final double consumableChance;
  final double creditMult;

  /// Un arma Rara o mejor segura (además de la tirada normal).
  final bool guaranteedRare;

  /// Chance de que el arma segura sea una base temática de la zona.
  final double themeChance;

  /// Chance de un Eco (nivel ≥ `kChestEcoMinLevel`).
  final double ecoChance;

  /// Chance de un Ancla Temporal (solo dentro de un Eco).
  final double anchorChance;

  /// Esquirlas del Eco seguras.
  final int esquirlas;
}

const Map<ChestTier, ChestTierDef> kChestTiers = {
  ChestTier.madera: ChestTierDef(
      tier: ChestTier.madera,
      name: 'un cofre',
      weight: 70,
      weaponChance: 0.45,
      rarityBonus: 0,
      extraMaterialRolls: 0,
      consumableChance: 0.30,
      creditMult: 1),
  ChestTier.plata: ChestTierDef(
      tier: ChestTier.plata,
      name: 'un cofre reforzado',
      weight: 24,
      weaponChance: 0.85,
      rarityBonus: 0.75,
      extraMaterialRolls: 1,
      consumableChance: 0.15,
      creditMult: 1.5,
      themeChance: 0.5,
      ecoChance: 0.08,
      anchorChance: 0.10,
      esquirlas: 1),
  ChestTier.oro: ChestTierDef(
      tier: ChestTier.oro,
      name: 'un cofre dorado',
      weight: 6,
      weaponChance: 0.30,
      rarityBonus: 1.5,
      extraMaterialRolls: 2,
      consumableChance: 0.10,
      creditMult: 2,
      guaranteedRare: true,
      themeChance: 0.5,
      ecoChance: 0.20,
      anchorChance: 0.30,
      esquirlas: 2),
};

/// Nivel desde el que los cofres pueden dar Ecos (zona 10 / endgame).
const kChestEcoMinLevel = 46;

/// Sala secreta: cofre reforzado o dorado.
const kSecretGoldChance = 0.4;

/// Palabras de las bases temáticas de cada generador (id de la base).
const Map<ZoneGen, List<String>> kThemeBaseWords = {
  ZoneGen.pradera: ['bronce', 'sauce', 'corto', 'roble', 'novato'],
  ZoneGen.bosque: ['roble', 'sauce', 'viento', 'ponzona', 'cienaga', 'vibora'],
  ZoneGen.ruinas: ['runica', 'tiempo', 'eco', 'templada', 'cruzado'],
  ZoneGen.cavernas: ['escarcha', 'glacial', 'hielo', 'glaciar'],
  ZoneGen.fortaleza: ['escudo', 'asedio', 'bastion', 'custodio', 'forja'],
  ZoneGen.laberinto: ['tiempo', 'eco', 'cronal', 'ambar', 'estelar'],
  ZoneGen.grieta: ['ignea', 'volcanica', 'infernal', 'fuego', 'dragon'],
  ZoneGen.cementerio: ['sombra', 'ocaso', 'eclipse', 'plaga', 'pestilente'],
  ZoneGen.abismo: ['vacio', 'estelar', 'eclipse', 'tormenta', 'cataclismo'],
  ZoneGen.corazon: ['eras', 'eternidad', 'eterno', 'origen', 'cronos'],
};

// ---------------------------------------------------------------------
// Puntos de interés del mapa (worldgen.md § 11.2, § 11.3, § 11.7)
// ---------------------------------------------------------------------

/// Distancia máxima (pasos BFS) de un tile caminable al PdI más cercano.
const kMaxPoiGap = 18;
const kMaxPoiGapMaze = 22;

/// Lugares de cofre: mínimo y tope (área caminable ÷ esto).
const kMinChestSpots = 2;
const kChestSpotArea = 100;

/// Salas secretas: 1 + 1 desde esta área; cada una con esta chance.
const kSecondSecretArea = 1100;
const kSecretChance = 0.8;

/// Santuario de bendición: 0–1 por piso.
const kShrineChance = 0.6;

/// Piedras de paso: desde esta área, 2 (y 3 desde la segunda).
const kWaystoneArea = 900;
const kThirdWaystoneArea = 1300;

/// Santuario del Viento del Eco: desde esta área, con esta chance.
const kWindArea = 1000;
const kWindChance = 0.7;

/// Viento del Eco: multiplicador de velocidad y duración (s).
const kWindSpeed = 1.4;
const kWindSeconds = 60.0;

/// Atajos: ahorro mínimo de camino (pasos) para que valga la pena.
const kShortcutMinSaving = 40;

/// Misiones opcionales: 1 por piso y 2 desde esta área.
const kSecondQuestArea = 1000;

/// Braseros de la misión `braseros`.
const kBraziers = 3;

// ---------------------------------------------------------------------
// Misiones opcionales (worldgen.md § 11.8, loot.md § 23.3)
// ---------------------------------------------------------------------

/// Texto funcional de cada misión opcional (sin historia: el lore lo
/// pone el dueño más adelante).
String questText(QuestKind k, {bool last = false}) => switch (k) {
      QuestKind.braseros => 'Encendé los braseros',
      QuestKind.guardian => 'Derrotá al guardián antes de bajar',
      QuestKind.reliquia => 'Encontrá la reliquia perdida',
      QuestKind.limpieza => 'Derrotá a todos los grupos del piso',
      QuestKind.secreto => 'Abrí la sala secreta',
      QuestKind.cofres => 'Abrí todos los cofres del piso',
    };

/// Peso de cada premio principal (eco cae a arma bajo nivel 45).
const Map<QuestReward, double> kQuestRewardWeights = {
  QuestReward.arma: 55,
  QuestReward.eco: 25,
  QuestReward.bendicion: 20,
};

/// Arma de premio: chance de Épico (si no, Raro) y de una base del plan
/// de build del jugador.
const kQuestEpicChance = 0.30;
const kQuestBuildChance = 0.60;

/// Paquete de materiales de toda misión opcional (por jugador).
const kQuestEsquirlas = 3;
const kQuestCristales = 1;
const kQuestPrismaLevel = 30;

/// Créditos del premio: base + por nivel del piso.
const kQuestCreditsBase = 60;
const kQuestCreditsPerLevel = 6;

/// Nivel desde el que el premio `eco` da un Eco.
const kQuestEcoMinLevel = 45;
