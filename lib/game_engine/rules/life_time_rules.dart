import '../data/farming_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import 'sky_rules.dart';

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
    if (d == null) return DayTime.siempre;
    final h = _h(id);
    return switch (d.rarity) {
      FishRarity.comun => DayTime.siempre,
      FishRarity.raro => h % 2 == 0 ? DayTime.dia : DayTime.noche,
      FishRarity.epico => h % 2 == 0 ? DayTime.amanecer : DayTime.atardecer,
      FishRarity.legendario => DayTime.noche,
    };
  }

  /// Clima que pide el pez (`null` = cualquiera): algunos épicos con
  /// lluvia; los legendarios de la Grieta y el Abismo con tormenta.
  static Weather? fishWeather(String id) {
    final d = kFish[id];
    if (d == null) return null;
    if (d.rarity == FishRarity.legendario &&
        (d.biome == 'grieta' || d.biome == 'abismo')) {
      return Weather.tormenta;
    }
    if (d.rarity == FishRarity.epico && _h(id) % 3 == 0) return Weather.lluvia;
    return null;
  }

  /// ¿Pica ahora? Lluvia vale también con tormenta.
  static bool fishActive(String id, SkyState s) {
    final ft = fishTime(id);
    if (ft != DayTime.siempre && ft != now(s)) return false;
    final w = fishWeather(id);
    if (w == null) return true;
    final cur = SkyRules.now(s);
    return w == Weather.lluvia ? cur.wet : cur == w;
  }

  /// El lago filtrado a lo que pica ahora; fuera de horario un pez entra
  /// solo con chance `offHoursChance` ([roll] en 0..1). Nunca vacío.
  static List<String> activeTable(
      List<String> lake, SkyState s, double Function() roll) {
    final off = t.d('offHoursChance');
    final out = [
      for (final id in lake)
        if (fishActive(id, s) || roll() < off) id
    ];
    return out.isEmpty ? lake : out;
  }

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

  /// × de crecimiento ahora: + `affinityBonus` en su franja, −
  /// `affinityMalus` fuera (parejo = 1).
  static double cropGrowth(String id, SkyState s) {
    final a = cropAffinity(id);
    if (a == CropAffinity.siempre) return 1;
    final inWin = switch (a) {
      CropAffinity.dia => !SkyRules.isNight(s),
      CropAffinity.noche => SkyRules.isNight(s),
      CropAffinity.lluvia => SkyRules.now(s).wet,
      CropAffinity.siempre => true,
    };
    return inWin ? 1 + tf.d('affinityBonus') : 1 - tf.d('affinityMalus');
  }
}
