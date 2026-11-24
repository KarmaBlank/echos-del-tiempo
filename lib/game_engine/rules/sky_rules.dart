import 'dart:math' as math;

import '../data/tuning_catalog.dart';
import 'weather_rules.dart';

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

  /// Exteriores de bioma sin cielo (overworld_biomes.md § 3.5): ni noche
  /// ni clima aunque sean zona segura.
  static const undergroundThemes = {
    'cavernas_ext',
    // Minas (mining_smithing.md § 1.2): bajo tierra, sin cielo.
    'mina_bosque', 'mina_ruinas', 'mina_cavernas', 'mina_grieta',
    'mina_abismo',
  };

  static bool outdoor(String theme, {bool town = false}) =>
      !undergroundThemes.contains(theme) &&
      (town || outdoorThemes.contains(theme));

  /// El primer día: arranca a media mañana, despejado, con pronóstico.
  /// The host picks the world weather seed once ([rand] only here); the
  /// forecast and every day after come from it (weather_seasons.md § 3).
  static SkyState start(double Function() rand) {
    final seed = 1 + (rand() * 0x7ffffffe).floor();
    return SkyState(
        day: 1,
        clock: daySec * 0.15,
        seed: seed,
        tomorrow: WeatherRules.dayWeather(seed, 2, null));
  }

  /// Avanza [dt] segundos. Al pasar el final del día empieza el siguiente
  /// con el clima pronosticado (en su tramo del día) y se calcula el
  /// pronóstico nuevo. Determinista: sale de la semilla del cielo
  /// (weather_seasons.md § 3); [rand] solo arranca un cielo nuevo.
  static SkyState advance(SkyState s0, double dt, double Function() rand) {
    var s = s0.started ? s0 : start(rand);
    var c = s.clock + dt;
    while (c >= length) {
      c -= length;
      final w = s.tomorrow;
      final day = s.day + 1;
      final (from, to) = WeatherRules.window(s.seed, day, null);
      s = SkyState(
          day: day,
          seed: s.seed,
          weather: w,
          from: w == Weather.despejado ? 0 : from,
          to: w == Weather.despejado ? 0 : to,
          tomorrow: WeatherRules.dayWeather(s.seed, day + 1, null));
    }
    return s.copyWith(clock: c);
  }

  /// The weather now in [place] (`null` = the town).
  static Weather nowIn(SkyState s, String? place) =>
      WeatherRules.current(s, biome: place);

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

  /// La hora del reloj del HUD (day_night_weather.md § 1.1): el día va de
  /// las 06:00 a las 20:00 y la noche de las 20:00 a las 06:00, cada
  /// tramo estirado a su duración. Minutos de a 10.
  static (int, int) hourOf(SkyState s) {
    final c = s.clock.clamp(0.0, length);
    final h = c < daySec
        ? 6 + 14 * c / daySec
        : 20 + 10 * (c - daySec) / nightSec;
    var m = ((h % 24) * 60).floor();
    m -= m % 10;
    return (m ~/ 60 % 24, m % 60);
  }

  /// "14:30".
  static String clockLabel(SkyState s) {
    final (h, m) = hourOf(s);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Segundos que faltan para que se haga de noche o de día.
  static double untilChange(SkyState s) {
    final c = s.clock;
    return c < daySec ? daySec - c : length - c;
  }

  /// El cartel de la noche: "Mañana: lluvia".
  static String forecast(SkyState s) =>
      'Mañana: ${s.tomorrow.label.toLowerCase()}';

  /// Chance de que pique con el clima de ahora en [place] (`stormBite`,
  /// `fogBite`, `snowBite`; 1 si no).
  static double biteChance(SkyState s, [String? place]) =>
      WeatherRules.biteChance(nowIn(s, place));

  /// Parte de la pesca de los pescadores con el clima de ahora (pueblo).
  static double fisherFactor(SkyState s) =>
      WeatherRules.fisherFactor(now(s));
}
