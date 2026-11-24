/// Camp of a biome resident in their outdoor area (overworld_biomes.md
/// § 9.2): a lit campfire plus one prop of their trade. Pure decoration:
/// the tiles stay walkable.
class NpcCampDef {
  const NpcCampDef(
      {required this.prop,
      required this.spark,
      this.fire = (2, 0),
      this.propAt = (3, 0)});

  /// Prop sprite id (`items.vida_camp_<prop>` in the manifest).
  final String prop;

  /// Spark color key of the activity (resolved by the painter).
  final String spark;

  /// Campfire and prop offsets, in tiles, from `BiomeNpcDef.tile`.
  final (int, int) fire;
  final (int, int) propAt;

  /// Campfire sprite id (`items.vida_camp_fire`).
  static const fireSprite = 'camp_fire';
  String get propSprite => 'camp_$prop';
}

/// Resident id → camp.
const Map<String, NpcCampDef> kNpcCamps = {
  'ilda': NpcCampDef(prop: 'basket', spark: 'flora'),
  'velda': NpcCampDef(prop: 'scrolls', spark: 'runa'),
  'kael': NpcCampDef(prop: 'dummy', spark: 'calida'),
  'brann': NpcCampDef(prop: 'anvil', spark: 'brasa'),
  'oren': NpcCampDef(prop: 'orb', spark: 'eco'),
};
