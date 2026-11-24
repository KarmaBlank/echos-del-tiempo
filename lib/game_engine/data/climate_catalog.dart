// Climate rules per biome (docs/specs/weather_seasons.md § 2.3 and § 8).
// Pure data: `WeatherRules` reads it; the Editor (CLIMA) edits it and
// `ClimateData` (assets/data/climate/climate.json) installs it at
// startup. The `*Defaults` maps are the code fallback.

import '../models/localized_text.dart';
import '../models/sky.dart';
import 'biomes_catalog.dart';

/// How a biome is exposed to the sky.
enum Exposure {
  /// Open sky: every weather its season allows.
  outdoor('Al aire libre'),

  /// Under rock or roof: no weather, no ground change.
  sheltered('Resguardado'),

  /// Hot ground: snow melts (→ `snowMelt`), no rain or snow overlay and
  /// no ground change.
  volcanic('Volcánico');

  const Exposure(this.label);
  final String label;

  static Exposure fromName(Object? n) =>
      values.firstWhere((v) => v.name == n, orElse: () => outdoor);
}

/// Ground overlays of a biome (§ 6.3): seasonal and weather marks drawn
/// over the same base tiles.
class GroundFx {
  const GroundFx(
      {this.snow = false,
      this.puddles = false,
      this.leaves = false,
      this.flowers = false});

  static const all =
      GroundFx(snow: true, puddles: true, leaves: true, flowers: true);
  static const none = GroundFx();

  /// Snow cover / frost in winter.
  final bool snow;

  /// Puddles and a wet tint while it rains.
  final bool puddles;

  /// Fallen leaves in autumn.
  final bool leaves;

  /// Flowers in spring.
  final bool flowers;

  GroundFx copyWith({bool? snow, bool? puddles, bool? leaves, bool? flowers}) =>
      GroundFx(
          snow: snow ?? this.snow,
          puddles: puddles ?? this.puddles,
          leaves: leaves ?? this.leaves,
          flowers: flowers ?? this.flowers);

  bool get any => snow || puddles || leaves || flowers;

  Map<String, Object?> toJson() => {
        'snow': snow,
        'puddles': puddles,
        'leaves': leaves,
        'flowers': flowers,
      };

  static GroundFx fromJson(Object? j) {
    if (j is! Map) return none;
    return GroundFx(
        snow: j['snow'] == true,
        puddles: j['puddles'] == true,
        leaves: j['leaves'] == true,
        flowers: j['flowers'] == true);
  }

  @override
  bool operator ==(Object other) =>
      other is GroundFx &&
      other.snow == snow &&
      other.puddles == puddles &&
      other.leaves == leaves &&
      other.flowers == flowers;

  @override
  int get hashCode => Object.hash(snow, puddles, leaves, flowers);
}

/// The climate of one biome.
class BiomeClimate {
  const BiomeClimate(
      {this.exposure = Exposure.outdoor,
      this.allowed = const {
        Weather.despejado,
        Weather.lluvia,
        Weather.tormenta,
        Weather.fog,
        Weather.snow,
      },
      this.snowMelt = Weather.despejado,
      this.ground = GroundFx.all});

  final Exposure exposure;

  /// Weathers that can happen here (clear always can).
  final Set<Weather> allowed;

  /// What a snow roll becomes where snow cannot happen (§ 2.3): clear,
  /// or fog for steam over hot ground.
  final Weather snowMelt;

  /// Ground overlays (always off when not outdoor).
  final GroundFx ground;

  /// The weather can happen here: an open sky that allows it.
  bool allows(Weather w) =>
      w == Weather.despejado ||
      (exposure != Exposure.sheltered &&
          allowed.contains(w) &&
          !(exposure == Exposure.volcanic && w == Weather.snow));

  /// Overlays actually drawn (none when sheltered or volcanic).
  GroundFx get groundShown =>
      exposure == Exposure.outdoor ? ground : GroundFx.none;

  /// Rain or snow particles are drawn (not on hot ground).
  bool get showsPrecipitation => exposure == Exposure.outdoor;

  BiomeClimate copyWith(
          {Exposure? exposure,
          Set<Weather>? allowed,
          Weather? snowMelt,
          GroundFx? ground}) =>
      BiomeClimate(
          exposure: exposure ?? this.exposure,
          allowed: allowed ?? this.allowed,
          snowMelt: snowMelt ?? this.snowMelt,
          ground: ground ?? this.ground);

  Map<String, Object?> toJson() => {
        'exposure': exposure.name,
        'allowed': [
          for (final w in Weather.values)
            if (allowed.contains(w)) w.name
        ],
        'snowMelt': snowMelt.name,
        'ground': ground.toJson(),
      };

  static BiomeClimate fromJson(Object? j) {
    if (j is! Map) return const BiomeClimate();
    final a = j['allowed'];
    return BiomeClimate(
        exposure: Exposure.fromName(j['exposure']),
        allowed: a is List
            ? {for (final n in a) Weather.fromName(n)}
            : const BiomeClimate().allowed,
        snowMelt: Weather.fromName(j['snowMelt']),
        ground: GroundFx.fromJson(j['ground']));
  }

  @override
  bool operator ==(Object other) =>
      other is BiomeClimate &&
      other.exposure == exposure &&
      other.snowMelt == snowMelt &&
      other.ground == ground &&
      other.allowed.length == allowed.length &&
      other.allowed.containsAll(allowed);

  @override
  int get hashCode =>
      Object.hash(exposure, snowMelt, ground, Object.hashAllUnordered(allowed));
}

/// Code defaults (§ 2.3 table).
const kBiomeClimateDefaults = <String, BiomeClimate>{
  kPueblo: BiomeClimate(),
  kBosque: BiomeClimate(),
  kRuinas: BiomeClimate(),
  kCavernas: BiomeClimate(
      exposure: Exposure.sheltered,
      allowed: {Weather.despejado},
      ground: GroundFx.none),
  kGrieta: BiomeClimate(
      exposure: Exposure.volcanic,
      allowed: {Weather.despejado, Weather.tormenta, Weather.fog},
      snowMelt: Weather.fog,
      ground: GroundFx.none),
  kAbismo: BiomeClimate(),
};

/// What the game uses now (installed from climate.json).
final kBiomeClimate = Map<String, BiomeClimate>.of(kBiomeClimateDefaults);

/// Climate of [biome] (`null` = the town). Unknown biomes: outdoor.
BiomeClimate climateOf(String? biome) =>
    kBiomeClimate[biome ?? kPueblo] ?? const BiomeClimate();

/// Season overrides from the Editor (§ 8): fish id → seasons, crop id →
/// seasons. Missing = the catalog's own seasons.
final kFishSeasonOverrides = <String, Set<Season>>{};
final kCropSeasonOverrides = <String, Set<Season>>{};

/// Player-facing names of the weathers and seasons edited in CLIMA
/// (every locale required, § 8.2). Missing = the i18n tables.
final kClimateNames = <String, LocalizedText>{};

/// Key of a name in [kClimateNames]: `weather.fog`, `season.winter`.
String weatherNameKey(Weather w) => 'weather.${w.name}';
String seasonNameKey(Season s) => 'season.${s.name}';
