import '../models/renown.dart';

/// Path surface the town paths show at a tier (renown_town_growth.md § 5.2).
enum PathMaterial { dirt, gravel, cobble }

/// The big centre prop of a town event (§ 6.4).
enum EventCenterpiece { bonfire, stage }

/// What a town tier adds on top of the playable map (§ 5.2). Pure data:
/// counts and switches; the layer picks the spots. [sprites] are the
/// manifest ids (`tiles.<id>`) the layer draws.
class TownTierDressing {
  const TownTierDressing({
    required this.path,
    this.fences = false,
    this.lampPosts = 0,
    this.well = false,
    this.noticeBoard = false,
    this.plaza = false,
    this.roofVariant = 0,
    this.banners = 0,
  });

  final PathMaterial path;
  final bool fences, well, noticeBoard, plaza;

  /// Lamp posts along the paths (max; fewer if the map has no room).
  final int lampPosts;

  /// 0 plain roofs, 1 chimneys, 2 + ridge trim, 3 + weathervanes.
  final int roofVariant;

  /// Banners at the town entrance.
  final int banners;
}

/// What an ongoing town event adds that day (§ 6.4).
class TownEventDressing {
  const TownEventDressing({
    required this.centerpiece,
    this.garlands = 0,
    this.stalls = 0,
    this.crowd = 0,
    this.skyLanterns = 0,
    this.ambience,
  });

  final EventCenterpiece centerpiece;

  /// Garland spans strung between houses (max).
  final int garlands;
  final int stalls, crowd;

  /// Sky lanterns drifting up at night (0 by day).
  final int skyLanterns;

  /// Ambience hook id for the music layer (`null` = town music as usual).
  final String? ambience;
}

/// Manifest ids (`tiles.<id>`, procedural) of the dressing props.
abstract final class DressingSprite {
  static const lampPost = 'town_lamp_post';
  static const well = 'town_well';
  static const noticeBoard = 'town_notice_board';
  static const fence = 'town_fence';
  static const garland = 'festival_garland';
  static const stall = 'festival_stall';
  static const bonfire = 'festival_bonfire';
  static const stage = 'festival_stage';
  static const skyLantern = 'festival_sky_lantern';
  static const all = [
    lampPost, well, noticeBoard, fence, garland, stall, bonfire, stage,
    skyLantern,
  ];
}

/// One entry per `townTiers` level (caserío, aldea, pueblo, ciudad).
const kTownTierDressing = <TownTierDressing>[
  TownTierDressing(path: PathMaterial.dirt),
  TownTierDressing(
      path: PathMaterial.gravel, fences: true, lampPosts: 2, banners: 2,
      roofVariant: 1),
  TownTierDressing(
      path: PathMaterial.gravel, fences: true, lampPosts: 4, well: true,
      noticeBoard: true, banners: 2, roofVariant: 2),
  TownTierDressing(
      path: PathMaterial.cobble, fences: true, lampPosts: 6, well: true,
      noticeBoard: true, plaza: true, banners: 4, roofVariant: 3),
];

/// Dressing per event kind (§ 6.4).
const kTownEventDressing = <TownEventKind, TownEventDressing>{
  TownEventKind.festival: TownEventDressing(
      centerpiece: EventCenterpiece.bonfire, garlands: 4, stalls: 3,
      crowd: 8, skyLanterns: 10, ambience: 'festival'),
  TownEventKind.tournament: TownEventDressing(
      centerpiece: EventCenterpiece.stage, garlands: 2, stalls: 1,
      crowd: 10, ambience: 'tournament'),
};
