import 'dart:math' as math;

import '../data/tuning_catalog.dart';
import '../models/sky.dart';

export '../models/sky.dart';

/// Reloj de día y noche y clima (docs/specs/day_night_weather.md). Puras;
/// los números en `kTuning[TuningId.town]` (Editor → Balance → Pueblo).
abstract final class SkyRules {
  static TuningDef get t => tuning(TuningId.town);

  static double get daySec => math.max(1, t.d('daySec'));
  static double get nightSec => math.max(1, t.d('nightSec'));

  /// Duración del día completo (luz + noche).
  static double get length => daySec + nightSec;

  /// Temas de mapa al aire libre: ahí se ve la noche y el clima (no en
  /// mazmorras, ruinas ni el abismo; § 1.3).
  static const outdoorThemes = {'pradera', 'bosque', 'mundo', 'lobby', 'pueblo'};

  static bool outdoor(String theme, {bool town = false}) =>
      town || outdoorThemes.contains(theme);

  /// El primer día: arranca a media mañana, despejado, con pronóstico.
  static SkyState start(double Function() rand) => SkyState(
      day: 1, clock: daySec * 0.15, tomorrow: rollWeather(rand()));

  /// Un clima al azar con [roll] en [0, 1): tormenta, lluvia o despejado.
  static Weather rollWeather(double roll) {
    final storm = t.d('stormChance').clamp(0.0, 1.0);
    final rain = t.d('rainChance').clamp(0.0, 1.0 - storm);
    if (roll < storm) return Weather.tormenta;
    if (roll < storm + rain) return Weather.lluvia;
    return Weather.despejado;
  }

  /// Avanza [dt] segundos. Al pasar el final del día empieza el siguiente
  /// con el clima pronosticado (en un tramo al azar del día) y se tira el
  /// pronóstico nuevo.
  static SkyState advance(SkyState s0, double dt, double Function() rand) {
    var s = s0.started ? s0 : start(rand);
    var c = s.clock + dt;
    while (c >= length) {
      c -= length;
      final w = s.tomorrow;
      final lo = t.d('weatherMinFrac').clamp(0.05, 1.0);
      final hi = math.max(lo, t.d('weatherMaxFrac').clamp(0.05, 1.0));
      final frac = lo + (hi - lo) * rand();
      final from = (1 - frac) * rand();
      s = SkyState(
          day: s.day + 1,
          weather: w,
          from: w == Weather.despejado ? 0 : from,
          to: w == Weather.despejado ? 0 : from + frac,
          tomorrow: rollWeather(rand()));
    }
    return s.copyWith(clock: c);
  }

  /// Parte del día completo que pasó (0–1).
  static double phase(SkyState s) => (s.clock / length).clamp(0.0, 1.0);

  /// El clima que hace ahora (fuera de su tramo, despejado).
  static Weather now(SkyState s) {
    if (!s.started || s.weather == Weather.despejado) return Weather.despejado;
    final p = phase(s);
    return p >= s.from && p < s.to ? s.weather : Weather.despejado;
  }

  static double _smooth(double x) {
    final v = x.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  /// Oscuridad del cielo (0 = pleno día, 1 = noche cerrada) con el
  /// atardecer y el amanecer suaves de `duskSec` centrados en el cambio.
  static double darkness(SkyState s) {
    if (!s.started) return 0;
    final d = math.max(1.0, t.d('duskSec'));
    final c = s.clock;
    final half = d / 2;
    // Atardecer alrededor de daySec, amanecer alrededor de 0 / length.
    if (c < half) return 1 - _smooth((c + half) / d);
    if (c > length - half) return 1 - _smooth((c - length + half) / d);
    if (c < daySec - half) return 0;
    if (c < daySec + half) return _smooth((c - daySec + half) / d);
    return 1;
  }

  static bool isNight(SkyState s) => darkness(s) >= 0.5;

  /// Segundos que faltan para que se haga de noche o de día.
  static double untilChange(SkyState s) {
    final c = s.clock;
    return c < daySec ? daySec - c : length - c;
  }

  /// El cartel de la noche: "Mañana: lluvia".
  static String forecast(SkyState s) =>
      'Mañana: ${s.tomorrow.label.toLowerCase()}';

  /// Chance de que pique con el clima de ahora (`stormBite` con
  /// tormenta; 1 si no).
  static double biteChance(SkyState s) => now(s) == Weather.tormenta
      ? t.d('stormBite').clamp(0.0, 1.0)
      : 1;

  /// Parte de la pesca de los pescadores con el clima de ahora.
  static double fisherFactor(SkyState s) => now(s) == Weather.tormenta
      ? t.d('stormFisher').clamp(0.0, 1.0)
      : 1;
}
