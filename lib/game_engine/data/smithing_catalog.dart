import 'biomes_catalog.dart';

/// Kind of a smithing material (docs/specs/mining_smithing.md § 2).
///
/// v2 (§ 1.6): [tool] = a mining tool you own (amount 1); [supply] = a
/// mine consumable (torch, bomb, booster).
enum SmithMatKind { ore, ingot, rare, special, tool, supply }

/// A smithing material. [name] is the es-AR source text; the UI resolves
/// `data.materials.smith.<id>.name`. [tier] is the ore level (1..5) of
/// its biome; [seasons] is empty for all year (hook for the season
/// rules: nothing reads it yet).
class SmithMaterialDef {
  const SmithMaterialDef(this.id, this.name, this.kind,
      {this.biome, this.tier = 0, this.seasons = const {}});

  final String id;
  final String name;
  final SmithMatKind kind;
  final String? biome;
  final int tier;
  final Set<String> seasons;

  String get textKey => 'data.materials.smith.$id.name';
}

/// The ores, ingot and rare material of one biome.
class BiomeOres {
  const BiomeOres(this.biome, this.tier,
      {required this.ore, required this.ingot, required this.rare});
  final String biome;
  final int tier;
  final String ore, ingot, rare;
}

/// Plano antiguo: recipe for a crafted legendary (dungeon veins).
const kSchematic = 'schematic';

/// Núcleo de guardián: zone bosses drop it; also unlocks a legendary.
const kGuardianCore = 'guardian_core';

/// Per-biome table (data-driven: a new biome only adds a row here).
const kBiomeOres = <String, BiomeOres>{
  kBosque: BiomeOres(kBosque, 1,
      ore: 'ore_copper', ingot: 'ingot_copper', rare: 'rare_amber'),
  kRuinas: BiomeOres(kRuinas, 2,
      ore: 'ore_bronze', ingot: 'ingot_bronze', rare: 'rare_cog'),
  kCavernas: BiomeOres(kCavernas, 3,
      ore: 'ore_frost', ingot: 'ingot_frost', rare: 'rare_rime'),
  kGrieta: BiomeOres(kGrieta, 4,
      ore: 'ore_ember', ingot: 'ingot_ember', rare: 'rare_magma'),
  kAbismo: BiomeOres(kAbismo, 5,
      ore: 'ore_echo', ingot: 'ingot_echo', rare: 'rare_sand'),
};

/// Every smithing material by id.
const kSmithMaterials = <String, SmithMaterialDef>{
  'ore_copper': SmithMaterialDef('ore_copper', 'Mena de cobre',
      SmithMatKind.ore, biome: kBosque, tier: 1),
  'ingot_copper': SmithMaterialDef('ingot_copper', 'Lingote de cobre',
      SmithMatKind.ingot, biome: kBosque, tier: 1),
  'rare_amber': SmithMaterialDef('rare_amber', 'Ámbar de raíz',
      SmithMatKind.rare, biome: kBosque, tier: 1),
  'ore_bronze': SmithMaterialDef('ore_bronze', 'Mena de bronce rúnico',
      SmithMatKind.ore, biome: kRuinas, tier: 2),
  'ingot_bronze': SmithMaterialDef('ingot_bronze', 'Lingote de bronce rúnico',
      SmithMatKind.ingot, biome: kRuinas, tier: 2),
  'rare_cog': SmithMaterialDef('rare_cog', 'Engranaje antiguo',
      SmithMatKind.rare, biome: kRuinas, tier: 2),
  'ore_frost': SmithMaterialDef('ore_frost', 'Mena de hierro helado',
      SmithMatKind.ore, biome: kCavernas, tier: 3),
  'ingot_frost': SmithMaterialDef('ingot_frost', 'Lingote de hierro helado',
      SmithMatKind.ingot, biome: kCavernas, tier: 3),
  'rare_rime': SmithMaterialDef('rare_rime', 'Cristal de escarcha',
      SmithMatKind.rare, biome: kCavernas, tier: 3),
  'ore_ember': SmithMaterialDef('ore_ember', 'Mena de acero ígneo',
      SmithMatKind.ore, biome: kGrieta, tier: 4),
  'ingot_ember': SmithMaterialDef('ingot_ember', 'Lingote de acero ígneo',
      SmithMatKind.ingot, biome: kGrieta, tier: 4),
  'rare_magma': SmithMaterialDef('rare_magma', 'Corazón de magma',
      SmithMatKind.rare, biome: kGrieta, tier: 4),
  'ore_echo': SmithMaterialDef('ore_echo', 'Mena de plata del eco',
      SmithMatKind.ore, biome: kAbismo, tier: 5),
  'ingot_echo': SmithMaterialDef('ingot_echo', 'Lingote de plata del eco',
      SmithMatKind.ingot, biome: kAbismo, tier: 5),
  'rare_sand': SmithMaterialDef('rare_sand', 'Arena detenida',
      SmithMatKind.rare, biome: kAbismo, tier: 5),
  kSchematic:
      SmithMaterialDef(kSchematic, 'Plano antiguo', SmithMatKind.special),
  kGuardianCore: SmithMaterialDef(
      kGuardianCore, 'Núcleo de guardián', SmithMatKind.special),
  // Mining v2 (mining_smithing.md § 1.6): tools and consumables.
  'pico': SmithMaterialDef('pico', 'Pico de hierro', SmithMatKind.tool),
  'pick_copper': SmithMaterialDef(
      'pick_copper', 'Pico de cobre', SmithMatKind.tool, tier: 1),
  'pick_frost': SmithMaterialDef(
      'pick_frost', 'Pico de hierro helado', SmithMatKind.tool, tier: 2),
  'pick_ember': SmithMaterialDef(
      'pick_ember', 'Pico de acero ígneo', SmithMatKind.tool, tier: 3),
  'drill_echo': SmithMaterialDef(
      'drill_echo', 'Taladro de plata del eco', SmithMatKind.tool, tier: 4),
  'mine_torch':
      SmithMaterialDef('mine_torch', 'Antorcha de mina', SmithMatKind.supply),
  'mine_bomb':
      SmithMaterialDef('mine_bomb', 'Bomba de mina', SmithMatKind.supply),
  'vein_oil':
      SmithMaterialDef('vein_oil', 'Aceite de veta', SmithMatKind.supply),
};

/// The ingot an ore smelts into (`null` = not an ore).
String? ingotOf(String ore) {
  for (final b in kBiomeOres.values) {
    if (b.ore == ore) return b.ingot;
  }
  return null;
}

/// The ore an ingot comes from (`null` = not an ingot).
String? oreOf(String ingot) {
  for (final b in kBiomeOres.values) {
    if (b.ingot == ingot) return b.ore;
  }
  return null;
}

/// Biome of a zone (its dungeon entrance is in that biome's exterior).
String? biomeOfZone(int zone) {
  for (final l in kBiomeLayouts.values) {
    for (final (z, _, _) in l.entrances) {
      if (z == zone) return l.id;
    }
  }
  return null;
}

/// Ambient NPC of a mine (`ui.world.mine.npc.<id>.*`).
const kMineNpcs = ['miner', 'hermit'];

/// Lines per mine NPC (keys `.0` .. `.n-1`; BORRADOR).
const kMineNpcLines = 3;

/// Lines of the lore stones (`ui.world.mine.lore.<n>`; BORRADOR).
const kMineLoreLines = 4;
