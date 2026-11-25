import 'biomes_catalog.dart' show BiomeLayout;
import 'tuning_catalog.dart';

/// Mine entrance tiles of a biome exterior (§ 1.1), registered as
/// `BiomeRegions.mineHook`: the cave mouths the region generator carved
/// off the main path (`BiomeLayout.mineSites`, one per north corner).
List<(int, int)> mineEntrances(BiomeLayout lay) => lay.mineSites;

/// Tile codes that only appear inside mine levels (docs/specs/
/// mining_smithing.md § 1). Rock is `Tile.wall` (`#`), floor `Tile.floor`,
/// the common vein `Tile.ore` (`r`), the way up `Tile.stairsUp` and the
/// shaft down `Tile.stairsDown`. Kept here so `game_map.dart` only lists
/// them in its solid set.
abstract final class MineTile {
  /// Unbreakable rock: the level border and a few formations.
  static const bedrock = 'X';

  /// Rich vein of the biome ore (more ore, better rare chance).
  static const rich = 'd';

  /// Vein of the next tier ore (deeper levels).
  static const deep = 'e';

  /// Gem vein: the rare material of the biome.
  static const gem = 'a';

  /// Glowing crystal growing out of the rock (breakable, gives light).
  static const crystal = 'c';

  /// Torch on the ground (walkable) and on a rock face (solid).
  static const torch = 'I';
  static const wallTorch = 'i';

  /// Mine chest, old magitech relic chest and an opened chest.
  static const chest = r'$';
  static const relic = 'U';
  static const chestOpen = '*';

  /// Mushroom patch (E picks it) and a lore stone (E reads it).
  static const mushroom = 'y';
  static const lore = '&';

  /// Cart station spot: rails on the floor (walkable). The station and
  /// its cart are drawn on top when built.
  static const station = 'Z';

  /// Every vein tile (mining it yields ore).
  static const veins = {'r', rich, deep, gem};

  /// Tiles a pickaxe or a bomb breaks (veins, rock and crystals).
  static const breakable = {'#', 'r', rich, deep, gem, crystal, wallTorch};

  /// Solid mine-only tiles (added to `Tile.solidTiles`).
  static const solid = {
    bedrock, rich, deep, gem, crystal, wallTorch, chest, relic, chestOpen,
    mushroom, lore,
  };
}

/// What a mining tool does (docs/specs/mining_smithing.md § 1.6). Numbers
/// live in `kTuning[TuningId.smithing]` under `tool<tier>…`.
class MineToolDef {
  const MineToolDef(this.id, this.name, this.tier,
      {this.ingot, this.drill = false});

  /// Id (also the `LifeSkills.ores` key and the sprite `vida_<id>`).
  final String id;

  /// es-AR source text; UI: `data.materials.smith.<id>.name`.
  final String name;

  /// Hardness tier it can break (0 = the starter pick).
  final int tier;

  /// Ingot the smith crafts it from (`null` = starter or shop only).
  final String? ingot;

  /// Mines continuously while the key is held.
  final bool drill;

  TuningDef get _t => tuning(TuningId.smithing);

  /// Hits per swing.
  int get power => _t.i('tool${tier}Power');

  /// Seconds between swings.
  double get swing => _t.d('tool${tier}Swing');

  /// Chance of one extra ore per vein.
  double get yieldBonus => _t.d('tool${tier}Yield');

  /// Shop / craft gold.
  int get gold => _t.i('tool${tier}Gold');

  /// Ingots to craft it.
  int get ingots => _t.i('tool${tier}Ingots');
}

/// The starter pick every character carries (sprite `vida_pico`).
const kStarterPick = 'pico';

/// Mining tools by tier (index = tier).
const kMineTools = <MineToolDef>[
  MineToolDef(kStarterPick, 'Pico de hierro viejo', 0),
  MineToolDef('pick_copper', 'Pico de cobre', 1, ingot: 'ingot_copper'),
  MineToolDef('pick_frost', 'Pico de hierro helado', 2, ingot: 'ingot_frost'),
  MineToolDef('pick_ember', 'Pico de acero ígneo', 3, ingot: 'ingot_ember'),
  MineToolDef('drill_echo', 'Taladro del eco', 4,
      ingot: 'ingot_echo', drill: true),
];

MineToolDef? mineTool(String id) {
  for (final t in kMineTools) {
    if (t.id == id) return t;
  }
  return null;
}

/// Consumables of the mines (stack in `LifeSkills.ores`).
const kMineTorch = 'mine_torch';
const kMineBomb = 'mine_bomb';
const kVeinOil = 'vein_oil';

/// Consumables in HUD order (torch, bomb, booster).
const kMineSupplies = [kMineTorch, kMineBomb, kVeinOil];

/// Tuning key prefix of each consumable's price (`<prefix>Gold`).
const kMineSupplyKey = {
  kMineTorch: 'torch',
  kMineBomb: 'bomb',
  kVeinOil: 'oil',
};
