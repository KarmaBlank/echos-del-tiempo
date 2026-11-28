/// Furniture, walls, floors and paints of the player house
/// (docs/specs/player_house.md § 8). Pure data: names come from i18n
/// (`ui.town.home.f.<id>`, `ui.town.home.s.<id>`), sprites from the manifest
/// (`items.vida_home_<id>`), and every level gate and cost from
/// `kTuning[TuningId.town]` (`home_<id>_lvl`, `home_<id>_gold`,
/// `home_<id>_mat`), editable in Editor → Balance → Pueblo.
library;

/// What a piece of furniture does (player_house.md § 8.2).
enum FurnitureKind {
  /// Sleep in it (DORMIR).
  bed,

  /// A framed picture on the back wall.
  picture,

  /// Weapon rack: shows the weapons its owner picks.
  rack,

  /// STASH CHEST: opens the same stash as B.
  chest,

  /// Kitchen station: the cooking of the TALLER DE OFICIOS.
  kitchen,

  /// A window on the back wall: daylight on the floor.
  window,

  /// Decoration (bookshelf, armour stand, rug, plants...).
  decor;

  /// Filter of the palette (subtabs, never stacked sections).
  String get filter => switch (this) {
        bed => 'bed',
        picture || window => 'wall',
        rack || chest || kitchen => 'use',
        decor => 'decor',
      };
}

/// A piece of furniture: [w] x [h] tiles. [onWall]: goes on the back
/// wall row (pictures, windows); otherwise on the floor. [walkable]: can
/// be walked over (a rug).
class FurnitureDef {
  const FurnitureDef(this.id, this.kind, this.w, this.h,
      {this.onWall = false, this.walkable = false});

  final String id;
  final FurnitureKind kind;
  final int w, h;
  final bool onWall;
  final bool walkable;

  /// Manifest sprite (`items.vida_home_<id>`).
  String get sprite => 'home_$id';
}

const kHomeFurniture = <FurnitureDef>[
  FurnitureDef('bed_basic', FurnitureKind.bed, 1, 2),
  FurnitureDef('bed_quilted', FurnitureKind.bed, 1, 2),
  FurnitureDef('bed_canopy', FurnitureKind.bed, 2, 2),
  FurnitureDef('picture_meadow', FurnitureKind.picture, 1, 1, onWall: true),
  FurnitureDef('picture_portrait', FurnitureKind.picture, 1, 1, onWall: true),
  FurnitureDef('picture_clock', FurnitureKind.picture, 2, 1, onWall: true),
  FurnitureDef('window', FurnitureKind.window, 1, 1, onWall: true),
  FurnitureDef('window_wide', FurnitureKind.window, 2, 1, onWall: true),
  FurnitureDef('weapon_rack', FurnitureKind.rack, 2, 1),
  FurnitureDef('stash_chest', FurnitureKind.chest, 1, 1),
  FurnitureDef('kitchen', FurnitureKind.kitchen, 2, 1),
  FurnitureDef('bookshelf', FurnitureKind.decor, 2, 1),
  FurnitureDef('armor_stand', FurnitureKind.decor, 1, 1),
  FurnitureDef('rug', FurnitureKind.decor, 3, 2, walkable: true),
  FurnitureDef('plant', FurnitureKind.decor, 1, 1),
  FurnitureDef('candelabra', FurnitureKind.decor, 1, 1),
  FurnitureDef('table', FurnitureKind.decor, 2, 1),
];

FurnitureDef? furniture(String id) =>
    kHomeFurniture.where((f) => f.id == id).firstOrNull;

/// A wall or floor material (player_house.md § 8.4).
class HomeSurfaceDef {
  const HomeSurfaceDef(this.id, {required this.wall, required this.mat});

  final String id;

  /// A wall material (else a floor).
  final bool wall;

  /// Craft material it also asks for (`home_<id>_mat` units; `''` none).
  final String mat;

  /// Manifest tile (`items.vida_home_<id>`, 16 x 16).
  String get sprite => 'home_$id';
}

const kHomeSurfaces = <HomeSurfaceDef>[
  HomeSurfaceDef('wall_plaster', wall: true, mat: ''),
  HomeSurfaceDef('wall_wood', wall: true, mat: 'tabla'),
  HomeSurfaceDef('wall_stone', wall: true, mat: 'fibra'),
  HomeSurfaceDef('wall_brick', wall: true, mat: 'tabla'),
  HomeSurfaceDef('floor_planks', wall: false, mat: ''),
  HomeSurfaceDef('floor_stone', wall: false, mat: 'fibra'),
  HomeSurfaceDef('floor_tiles', wall: false, mat: 'tabla'),
  HomeSurfaceDef('floor_carpet', wall: false, mat: 'fibra'),
];

HomeSurfaceDef? homeSurface(String id) =>
    kHomeSurfaces.where((f) => f.id == id).firstOrNull;

/// Wall paints (RGB), index = paint id. 0 = the material's own colour.
const kHomePaints = <int>[
  0x000000,
  0xe8d8b0,
  0xb8d0e8,
  0xc8e0b0,
  0xe8b8b8,
  0xd0c0e8,
  0x8a6a4a,
];
