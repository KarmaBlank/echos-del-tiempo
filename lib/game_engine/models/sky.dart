/// Clima de un día (docs/specs/day_night_weather.md § 3).
enum Weather {
  despejado('Despejado'),
  lluvia('Lluvia'),
  tormenta('Tormenta'),
  // weather_seasons.md § 2 (v0.44.0): fog and snow.
  fog('Niebla'),
  snow('Nieve');

  const Weather(this.label);
  final String label;

  /// Llueve (la lluvia y la tormenta riegan; la niebla y la nieve no).
  bool get wet => this == lluvia || this == tormenta;

  /// Short key used by the tuning (`wSpringRain`, `bioBosqueFog`, …).
  String get key => switch (this) {
        despejado => 'Clear',
        lluvia => 'Rain',
        tormenta => 'Storm',
        fog => 'Fog',
        snow => 'Snow',
      };

  static Weather fromName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return despejado;
  }
}

/// Season of the world (weather_seasons.md § 1): derived from the world
/// day, `seasonDays` days each.
enum Season {
  spring('Primavera'),
  summer('Verano'),
  autumn('Otoño'),
  winter('Invierno');

  const Season(this.label);
  final String label;

  /// Tuning key suffix (`wSpringRain`, …).
  String get key => '${name[0].toUpperCase()}${name.substring(1)}';

  static Season fromName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return spring;
  }
}

/// All four seasons (the default of fish that live all year).
const kAllSeasons = {
  Season.spring,
  Season.summer,
  Season.autumn,
  Season.winter
};

/// Every season but winter (the default of planted crops).
const kWarmSeasons = {Season.spring, Season.summer, Season.autumn};

/// Reloj y clima del mundo (day_night_weather.md § 1–3). Lo lleva el
/// anfitrión y viaja con el pueblo (`TownState.sky`): todos ven la misma
/// hora y el mismo cielo. Inmutable.
class SkyState {
  const SkyState({
    this.day = 0,
    this.clock = 0,
    this.weather = Weather.despejado,
    this.from = 0,
    this.to = 0,
    this.tomorrow = Weather.despejado,
    this.seed = 0,
  });

  /// World weather seed (weather_seasons.md § 3): every biome's weather
  /// comes from (seed, day, biome). Picked once by the host.
  final int seed;

  /// Días que pasaron desde que el mundo tiene reloj (0 = sin arrancar).
  final int day;

  /// Segundos desde el amanecer del día (0 … duración del día).
  final double clock;

  /// El clima de hoy y la parte del día en que dura (fracción 0–1 del
  /// día completo; afuera de [from, to) está despejado).
  final Weather weather;
  final double from, to;

  /// El pronóstico (el cartel de la noche).
  final Weather tomorrow;

  bool get started => day > 0;

  SkyState copyWith({
    int? day,
    double? clock,
    Weather? weather,
    double? from,
    double? to,
    Weather? tomorrow,
    int? seed,
  }) =>
      SkyState(
          day: day ?? this.day,
          clock: clock ?? this.clock,
          weather: weather ?? this.weather,
          from: from ?? this.from,
          to: to ?? this.to,
          tomorrow: tomorrow ?? this.tomorrow,
          seed: seed ?? this.seed);

  Map<String, Object?> toJson() => {
        'd': day,
        'c': (clock * 10).round() / 10,
        if (weather != Weather.despejado) ...{
          'w': weather.name,
          'f': (from * 1000).round() / 1000,
          't': (to * 1000).round() / 1000,
        },
        if (tomorrow != Weather.despejado) 'm': tomorrow.name,
        if (seed != 0) 'sd': seed,
      };

  static SkyState fromJson(Object? raw) {
    if (raw is! Map) return const SkyState();
    double n(Object? v) => v is num && v.isFinite ? v.toDouble() : 0;
    return SkyState(
      day: n(raw['d']).round().clamp(0, 1 << 30),
      clock: n(raw['c']).clamp(0, 1e6),
      weather: Weather.fromName(raw['w']),
      from: n(raw['f']).clamp(0, 1),
      to: n(raw['t']).clamp(0, 1),
      tomorrow: Weather.fromName(raw['m']),
      seed: n(raw['sd']).round().clamp(0, 0x7fffffff),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SkyState &&
      other.day == day &&
      other.clock == clock &&
      other.weather == weather &&
      other.from == from &&
      other.to == to &&
      other.tomorrow == tomorrow &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(day, clock, weather, from, to, tomorrow, seed);
}
