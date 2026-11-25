// Cozy life content (docs/specs/cozy_life.md): raft decorations, farm
// decorations and compost recipes. Pure data; prices live in the
// Balance (`TuningId.regions`, the `*CostKey` of each entry).

/// Where a raft decoration goes (cozy_life.md § 1).
enum RaftDecoSlot { lantern, roof, paint }

class RaftDecoDef {
  const RaftDecoDef(this.id, this.slot, this.costKey, {this.paint});
  final String id;
  final RaftDecoSlot slot;

  /// Tunable with the gold price.
  final String costKey;

  /// Index of the paint colour (`RaftPalette.paints`), for paint decos.
  final int? paint;
}

const kRaftDecos = <String, RaftDecoDef>{
  'lantern': RaftDecoDef('lantern', RaftDecoSlot.lantern, 'raftLanternCost'),
  'roof': RaftDecoDef('roof', RaftDecoSlot.roof, 'raftRoofCost'),
  'paint_red':
      RaftDecoDef('paint_red', RaftDecoSlot.paint, 'raftPaintCost', paint: 0),
  'paint_blue':
      RaftDecoDef('paint_blue', RaftDecoSlot.paint, 'raftPaintCost', paint: 1),
  'paint_green':
      RaftDecoDef('paint_green', RaftDecoSlot.paint, 'raftPaintCost', paint: 2),
  'paint_cream':
      RaftDecoDef('paint_cream', RaftDecoSlot.paint, 'raftPaintCost', paint: 3),
};

/// A 1×1 farm decoration placed in EDITAR PUEBLO (cozy_life.md § 2).
class FarmDecoDef {
  const FarmDecoDef(this.id, this.costKey);
  final String id;
  final String costKey;

  /// Manifest id of its sprite (`tiles.decor_<id>`).
  String get sprite => 'decor_$id';
}

const kFarmDecos = <String, FarmDecoDef>{
  'fence': FarmDecoDef('fence', 'decorFenceCost'),
  'scarecrow': FarmDecoDef('scarecrow', 'decorScarecrowCost'),
  'pot': FarmDecoDef('pot', 'decorPotCost'),
  'stone_path': FarmDecoDef('stone_path', 'decorPathCost'),
  'lamp': FarmDecoDef('lamp', 'decorLampCost'),
};

/// A compost recipe found while searching trees (cozy_life.md § 3):
/// harvest bag items (crop keys `id@q`) → bags of a fertilizer.
class CompostRecipe {
  const CompostRecipe(this.id, this.inputs, this.fert, this.makes);
  final String id;
  final Map<String, int> inputs;

  /// Id of `kFertilizers`.
  final String fert;
  final int makes;
}

const kCompostRecipes = <String, CompostRecipe>{
  'leaf_mulch': CompostRecipe('leaf_mulch', {'moras_bosque@0': 3}, 'abono', 2),
  'herb_compost': CompostRecipe(
      'herb_compost', {'hierba_rocio@0': 2, 'moras_bosque@0': 1}, 'abono', 3),
  'mushroom_compost': CompostRecipe('mushroom_compost',
      {'hongo_ambar@0': 2, 'hierba_rocio@0': 2}, 'abono_runico', 1),
  // Living weapon composts (profession_gear.md § 3.3): the Abono branch of
  // the Cultivo tree hands these out; searching trees finds them too.
  'ember_compost': CompostRecipe(
      'ember_compost', {'chile_volcan@0': 2, 'moras_bosque@0': 1}, 'abono_brasa', 2),
  'honey_compost': CompostRecipe('honey_compost',
      {'frutilla_rocio@0': 2, 'moras_bosque@0': 1}, 'abono_miel', 2),
  'frost_compost': CompostRecipe(
      'frost_compost', {'rabano_nieve@0': 2, 'hierba_rocio@0': 1}, 'abono_escarcha', 2),
};

/// What a tree search can turn up (cozy_life.md § 3).
enum SearchFind { nothing, seed, mushroom, nest, recipe }
