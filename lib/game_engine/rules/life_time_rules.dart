import '../data/climate_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import 'sky_rules.dart';
import 'weather_rules.dart';

/// Franja del día (day_night_weather.md § 6): amanecer 05:00-07:59, día
/// 08:00-17:59, atardecer 18:00-20:59, noche 21:00-04:59.
enum DayTime {
  siempre('Siempre'),
  amanecer('Amanecer'),
  dia('Día'),
  atardecer('Atardecer'),
  noche('Noche');

  const DayTime(this.label);
  final String label;
}

/// Afinidad de crecimiento de un cultivo (farming.md § 14).
enum CropAffinity {
  siempre('Parejo'),
  dia('Crece más de día'),
  noche('Crece más de noche'),
  lluvia('Crece más con lluvia');

  const CropAffinity(this.label);
  final String label;
}

/// Horarios de los peces y afinidades de los cultivos (fishing.md § 13,
/// farming.md § 14). Puras: el anfitrión las aplica con el reloj del
/// mundo; la UI las muestra.
abstract final class LifeTimeRules {
  static TuningDef get t => tuning(TuningId.fishing);
  static TuningDef get tf => tuning(TuningId.farming);

  static int _h(String id) => id.codeUnits.fold<int>(7, (a, c) => a * 31 + c) & 0x7fffffff;

  /// Franja de ahora.
  static DayTime now(SkyState s) {
    final (h, _) = SkyRules.hourOf(s);
    if (h >= 5 && h < 8) return DayTime.amanecer;
    if (h >= 8 && h < 18) return DayTime.dia;
    if (h >= 18 && h < 21) return DayTime.atardecer;
    return DayTime.noche;
  }

  /// Horario del pez: los comunes siempre; los raros de día o de noche;
  /// los épicos al amanecer o al atardecer; los legendarios de noche.
  static DayTime fishTime(String id) {
    final d = kFish[id];
    if (d == null || d.visitor) return DayTime.siempre;
    final h = _h(id);
    return switch (d.rarity) {
      FishRarity.comun => DayTime.siempre,
      FishRarity.raro => h % 2 == 0 ? DayTime.dia : DayTime.noche,
      FishRarity.epico => h % 2 == 0 ? DayTime.amanecer : DayTime.atardecer,
      FishRarity.legendario => DayTime.noche,
    };
  }

  /// Clima que pide el pez (`null` = cualquiera): el del catálogo si lo
  /// tiene (estricto); si no, algunos épicos con lluvia y los legendarios
  /// de la Grieta y el Abismo con tormenta.
  static Weather? fishWeather(String id) {
    final d = kFish[id];
    if (d == null) return null;
    if (d.weather != null) return d.weather;
    if (d.rarity == FishRarity.legendario &&
        (d.biome == 'grieta' || d.biome == 'abismo')) {
      return Weather.tormenta;
    }
    if (d.rarity == FishRarity.epico && _h(id) % 3 == 0) return Weather.lluvia;
    return null;
  }

  /// Seasons when [id] bites (weather_seasons.md § 4).
  static Set<Season> fishSeasons(String id) =>
      kFishSeasonOverrides[id] ?? kFish[id]?.seasons ?? kAllSeasons;

  /// In season now (strict: no off-hours chance).
  static bool fishInSeason(String id, SkyState s) =>
      fishSeasons(id).contains(WeatherRules.season(s.day));

  static bool _weatherOk(Weather want, Weather cur) =>
      want == Weather.lluvia ? cur.wet : cur == want;

  /// ¿Pica ahora? Lluvia vale también con tormenta. [weather]: el clima
  /// del lugar donde se pesca (por defecto, el del pueblo).
  static bool fishActive(String id, SkyState s, {Weather? weather}) {
    if (!fishInSeason(id, s)) return false;
    final ft = fishTime(id);
    if (ft != DayTime.siempre && ft != now(s)) return false;
    final w = fishWeather(id);
    if (w == null) return true;
    return _weatherOk(w, weather ?? SkyRules.now(s));
  }

  /// Hard gate (never bypassed by the off-hours chance): its season and,
  /// when the catalog names one, its weather.
  static bool _strictOk(String id, SkyState s, Weather cur) {
    if (!fishInSeason(id, s)) return false;
    final w = kFish[id]?.weather;
    return w == null || _weatherOk(w, cur);
  }

  /// El lago filtrado a lo que pica ahora; fuera de horario un pez entra
  /// solo con chance `offHoursChance` ([roll] en 0..1). Fuera de estación
  /// o del clima que pide el catálogo, nunca. Se suman los visitantes de
  /// [biome] (weather_seasons.md § 4.2) que pican ahora. Nunca vacío.
  static List<String> activeTable(
      List<String> lake, SkyState s, double Function() roll,
      {String? biome, Weather? weather}) {
    final off = t.d('offHoursChance');
    final cur = weather ?? SkyRules.now(s);
    final out = [
      for (final id in lake)
        if (_strictOk(id, s, cur) &&
            (fishActive(id, s, weather: cur) || roll() < off))
          id,
      if (biome != null)
        for (final v in visitors(biome))
          if (!lake.contains(v) && fishActive(v, s, weather: cur)) v,
    ];
    if (out.isNotEmpty) return out;
    final inSeason = [
      for (final id in lake)
        if (_strictOk(id, s, cur)) id
    ];
    return inSeason.isEmpty ? lake : inSeason;
  }

  /// Seasonal / weather visitors of [biome] (§ 4.2).
  static List<String> visitors(String biome) => [
        for (final f in kFish.values)
          if (f.visitor && f.biome == biome) f.id
      ];

  static String fishTimeText(String id) {
    final w = fishWeather(id);
    return '${fishTime(id).label}${w == null ? '' : ' · ${w.label}'}';
  }

  // ---------------- cultivos ----------------

  static CropAffinity cropAffinity(String id) {
    final c = kCrops[id];
    if (c == null) return CropAffinity.siempre;
    return CropAffinity.values[_h(id) % CropAffinity.values.length];
  }

  /// Seasons when [id] grows (farming.md § 15).
  static Set<Season> cropSeasons(String id) =>
      kCropSeasonOverrides[id] ?? kCrops[id]?.seasons ?? kAllSeasons;

  /// Only grows (and is only harvested) in winter.
  static bool cropWinterOnly(String id) {
    final s = cropSeasons(id);
    return s.length == 1 && s.contains(Season.winter);
  }

  /// The crop grows in [season].
  static bool cropInSeason(String id, Season season) =>
      cropSeasons(id).contains(season);

  /// A seasonal crop (not one of all year) in its season (farming.md
  /// § 16): sells × `seasonPriceMult` and grows × `seasonGrowMult`.
  static bool cropSeasonal(String id, Season season) {
    final s = cropSeasons(id);
    return s.length < Season.values.length && s.contains(season);
  }

  /// × of growth from the season bonus (1 when it doesn't apply).
  static double seasonGrow(String id, Season season) =>
      cropSeasonal(id, season) ? tf.d('seasonGrowMult') : 1;

  /// × of price from the season bonus (1 when it doesn't apply).
  static double seasonPrice(String id, Season season) =>
      cropSeasonal(id, season) ? tf.d('seasonPriceMult') : 1;

  /// × de crecimiento ahora: + `affinityBonus` en su franja, −
  /// `affinityMalus` fuera (parejo = 1). Fuera de estación, 0: se frena
  /// (no muere) hasta que vuelva su estación (farming.md § 15).
  static double cropGrowth(String id, SkyState s) {
    final season = WeatherRules.season(s.day);
    if (!cropInSeason(id, season)) return 0;
    final sg = seasonGrow(id, season);
    final a = cropAffinity(id);
    if (a == CropAffinity.siempre) return sg;
    final inWin = switch (a) {
      CropAffinity.dia => !SkyRules.isNight(s),
      CropAffinity.noche => SkyRules.isNight(s),
      CropAffinity.lluvia => SkyRules.now(s).wet,
      CropAffinity.siempre => true,
    };
    return sg *
        (inWin ? 1 + tf.d('affinityBonus') : 1 - tf.d('affinityMalus'));
  }
}
