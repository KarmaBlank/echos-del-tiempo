import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/climate_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/sky.dart';

export '../models/sky.dart';
export '../data/climate_catalog.dart' show Exposure, BiomeClimate, GroundFx, climateOf;

/// Seasons and per-biome weather (docs/specs/weather_seasons.md). Pure
/// and deterministic: everything comes from the world seed, the world
/// day and the biome id, so every peer computes the same sky. Numbers in
/// `kTuning[TuningId.town]` (Editor → Balance → Pueblo).
///
/// This is the API other world systems query (events, mining, …):
/// [season], [dayWeather] and [current].
abstract final class WeatherRules {
  static TuningDef get t => tuning(TuningId.town);

  /// Days per season (≥ 1).
  static int get seasonDays => math.max(1, t.i('seasonDays'));

  /// Season of world [day] (day 1 is the first day of spring; day ≤ 0,
  /// a world without a clock, counts as spring).
  static Season season(int day) {
    if (day <= 0) return Season.spring;
    return Season.values[((day - 1) ~/ seasonDays) % Season.values.length];
  }

  /// Day inside its season (1 … [seasonDays]).
  static int seasonDay(int day) => day <= 0 ? 1 : (day - 1) % seasonDays + 1;

  /// Days left until the next season starts (1 = tomorrow).
  static int daysToNextSeason(int day) => seasonDays - seasonDay(day) + 1;

  /// The biome has a sky (no weather underground, § 2.3). `null` or
  /// `pueblo` is the town.
  static bool hasSky(String? biome) =>
      climateOf(biome).exposure != Exposure.sheltered;

  /// [w] can happen in [biome] (its exposure and allowed list).
  static bool allows(String? biome, Weather w) => climateOf(biome).allows(w);

  /// Tuning key of a biome multiplier (`bioPuebloRain`, …).
  static String _bioKey(String? biome, Weather w) {
    final id = biome ?? kPueblo;
    return 'bio${id[0].toUpperCase()}${id.substring(1)}${w.key}';
  }

  /// Raw weight of [w] in [season] for [biome]: the season weight × the
  /// biome multiplier (1 when the biome has none). Snow only in winter.
  static double _raw(Season season, String? biome, Weather w) {
    if (w == Weather.snow && season != Season.winter) return 0;
    final base = t.values['w${season.key}${w.key}'] ?? 0;
    final mul = w == Weather.despejado ? 1 : (t.values[_bioKey(biome, w)] ?? 1);
    return math.max(0.0, base.toDouble() * mul.toDouble());
  }

  /// Weight of [w] after the biome rules (§ 2.3): weathers the biome
  /// does not allow weigh 0, except snow, whose weight goes to the
  /// biome's `snowMelt` (clear, or fog as steam over hot ground).
  static double weight(Season season, String? biome, Weather w) {
    final c = climateOf(biome);
    if (!c.allows(w)) return 0;
    var k = _raw(season, biome, w);
    if (!c.allows(Weather.snow) &&
        (c.allows(c.snowMelt) ? c.snowMelt : Weather.despejado) == w) {
      k += _raw(season, biome, Weather.snow);
    }
    return k;
  }

  /// Weather picked by a uniform [roll] in [0, 1).
  static Weather pick(double roll, Season season, String? biome) {
    var total = 0.0;
    for (final w in Weather.values) {
      total += weight(season, biome, w);
    }
    if (total <= 0) return Weather.despejado;
    var x = roll.clamp(0.0, 0.999999) * total;
    for (final w in Weather.values) {
      final k = weight(season, biome, w);
      if (x < k) return w;
      x -= k;
    }
    return Weather.despejado;
  }

  /// The weather of world [day] in [biome] for world [seed]. Same inputs,
  /// same answer, on every peer.
  static Weather dayWeather(int seed, int day, String? biome) {
    if (!hasSky(biome) || day <= 0) return Weather.despejado;
    return pick(unit(seed, day, biome ?? kPueblo, 0), season(day), biome);
  }

  /// Part of the day the weather lasts (fractions 0–1 of the full day):
  /// `weatherMinFrac` … `weatherMaxFrac`, starting anywhere that fits.
  static (double, double) window(int seed, int day, String? biome) {
    final lo = t.d('weatherMinFrac').clamp(0.05, 1.0);
    final hi = math.max(lo, t.d('weatherMaxFrac').clamp(0.05, 1.0));
    final frac = lo + (hi - lo) * unit(seed, day, biome ?? kPueblo, 1);
    final from = (1 - frac) * unit(seed, day, biome ?? kPueblo, 2);
    return (from, from + frac);
  }

  /// The weather right now in [biome] (`null` = the town, which reads
  /// the stored sky so old saves keep their day).
  static Weather current(SkyState sky, {String? biome}) {
    if (!sky.started || !hasSky(biome)) return Weather.despejado;
    final Weather w;
    final double from, to;
    if (biome == null || biome == kPueblo) {
      (w, from, to) = (sky.weather, sky.from, sky.to);
    } else {
      w = dayWeather(sky.seed, sky.day, biome);
      (from, to) = window(sky.seed, sky.day, biome);
    }
    if (w == Weather.despejado) return w;
    final p = (sky.clock / _length).clamp(0.0, 1.0);
    return p >= from && p < to ? w : Weather.despejado;
  }

  static double get _length =>
      math.max(1, t.d('daySec')) + math.max(1, t.d('nightSec'));

  /// Chance a fish bites in [w] (`stormBite`, `fogBite`, `snowBite`).
  static double biteChance(Weather w) => switch (w) {
        Weather.tormenta => t.d('stormBite'),
        Weather.fog => t.d('fogBite'),
        Weather.snow => t.d('snowBite'),
        _ => 1.0,
      }
          .clamp(0.0, 1.0);

  /// Share of the fishers' catch in [w] (`stormFisher`, `fogFisher`,
  /// `snowFisher`).
  static double fisherFactor(Weather w) => switch (w) {
        Weather.tormenta => t.d('stormFisher'),
        Weather.fog => t.d('fogFisher'),
        Weather.snow => t.d('snowFisher'),
        _ => 1.0,
      }
          .clamp(0.0, 1.0);

  // ---------------- deterministic hash ----------------

  /// 32-bit multiply that gives the same bits on the VM and on the web.
  static int _mul(int a, int b) {
    final lo = (a & 0xffff) * b;
    final hi = (((a >>> 16) & 0xffff) * b) & 0xffff;
    return (lo + (hi << 16)) & 0xffffffff;
  }

  static int _mix(int h) {
    h &= 0xffffffff;
    h ^= h >>> 16;
    h = _mul(h, 0x85ebca6b);
    h ^= h >>> 13;
    h = _mul(h, 0xc2b2ae35);
    h ^= h >>> 16;
    return h & 0xffffffff;
  }

  /// Uniform number in [0, 1) from (seed, day, biome, salt).
  static double unit(int seed, int day, String biome, int salt) {
    var h = _mix(seed ^ 0x9e3779b9);
    h = _mix(h ^ _mul(day & 0xffffffff, 0x27d4eb2d));
    for (final c in biome.codeUnits) {
      h = _mix(h ^ c);
    }
    h = _mix(h ^ _mul(salt + 1, 0x165667b1));
    return (h & 0xffffff) / 0x1000000;
  }
}
