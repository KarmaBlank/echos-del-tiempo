/// Town path materials (town_editor.md § 4.6): what the CAMINOS tool
/// paints. Ordered from the humblest to the finest; the first one is the
/// default (always unlocked) and the one the auto-router lays.
///
/// Numbers live in `kTuning[TuningId.town]` under `<key>Gold`,
/// `<key>Ore` and `<key>Level`; art in sprite_manifest.yaml
/// (`items.vida_path_<id>_<mask>`, `tool/export_path_sprites.dart`).
class TownPathDef {
  const TownPathDef(this.id, this.key, {this.ore});

  /// Stable id (saved in `TownState.paths`, sent on the wire).
  final String id;

  /// Tuning prefix (`pathStone` → `pathStoneGold`, …).
  final String key;

  /// Smithing material spent per tile (`kSmithMaterials` id), if any.
  final String? ore;

  /// Manifest id of the piece for the N/E/S/W mask (`Autotile.mask4`).
  String sprite(int mask) => 'path_${id}_$mask';

  /// Manifest id of the palette icon.
  String get icon => 'path_${id}_icon';
}

/// Default material: auto paths and old saves use it.
const kDefaultPath = 'dirt';

const kTownPaths = <TownPathDef>[
  TownPathDef('dirt', 'pathDirt'),
  TownPathDef('stone', 'pathStone', ore: 'ore_copper'),
  // Runic cobble: stones set with the old magitech bronze.
  TownPathDef('rune', 'pathRune', ore: 'ore_bronze'),
];

TownPathDef? townPath(String? id) =>
    kTownPaths.where((p) => p.id == id).firstOrNull;
