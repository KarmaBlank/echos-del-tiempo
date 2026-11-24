import 'dart:convert';

import '../data/biomes_catalog.dart';
import '../data/climate_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/fishing_catalog.dart';
import '../models/localized_text.dart';

/// Climate rules as data (docs/specs/weather_seasons.md § 8):
/// `assets/data/climate/climate.json`. Pure; the asset reader lives in
/// `lib/core/data/climate_data_loader.dart`. Season length and weather
/// weights stay in `kTuning[town]` (Balance), the CLIMA editor edits
/// them there.
class ClimateData {
  const ClimateData(
      {required this.biomes,
      this.fishSeasons = const {},
      this.cropSeasons = const {},
      this.names = const {}});

  static const assetPath = 'assets/data/climate/climate.json';
  static const version = 1;

  final Map<String, BiomeClimate> biomes;

  /// Season overrides (only those that differ from the catalog).
  final Map<String, Set<Season>> fishSeasons;
  final Map<String, Set<Season>> cropSeasons;

  /// Names of the weathers and seasons per locale (`weather.fog`, …).
  final Map<String, LocalizedText> names;

  /// The code values (the fallback), with the names from [sourceNames].
  static ClimateData get defaults =>
      ClimateData(biomes: Map.of(kBiomeClimateDefaults), names: sourceNames);

  /// es-AR names from the enums (other locales empty until written).
  static Map<String, LocalizedText> get sourceNames => {
        for (final w in Weather.values)
          weatherNameKey(w): LocalizedText(w.label),
        for (final s in Season.values) seasonNameKey(s): LocalizedText(s.label),
      };

  /// What the game uses now.
  static ClimateData get current => ClimateData(
      biomes: Map.of(kBiomeClimate),
      fishSeasons: Map.of(kFishSeasonOverrides),
      cropSeasons: Map.of(kCropSeasonOverrides),
      names: kClimateNames.isEmpty ? sourceNames : Map.of(kClimateNames));

  // ---------------- validation (§ 8.3) ----------------

  /// Problems that block saving, as readable lines. Empty = valid.
  List<String> issues(List<String> locales) {
    final out = <String>[];
    for (final b in kBiomes) {
      if (!biomes.containsKey(b.id)) out.add('${b.id}: falta el clima');
    }
    for (final MapEntry(key: id, value: c) in biomes.entries) {
      if (biomeDef(id) == null) out.add('$id: bioma desconocido');
      if (!c.allowed.contains(Weather.despejado)) {
        out.add('$id: despejado tiene que estar permitido');
      }
      if (c.snowMelt == Weather.snow) {
        out.add('$id: la nieve no puede derretirse en nieve');
      }
      if (!c.allows(Weather.snow) && !c.allows(c.snowMelt)) {
        out.add('$id: la nieve se derrite en ${c.snowMelt.name}, que no '
            'está permitido');
      }
    }
    for (final MapEntry(key: id, value: s) in fishSeasons.entries) {
      if (!kFish.containsKey(id)) out.add('pez $id: desconocido');
      if (s.isEmpty) out.add('pez $id: sin estaciones');
    }
    for (final MapEntry(key: id, value: s) in cropSeasons.entries) {
      if (!kCrops.containsKey(id)) out.add('cultivo $id: desconocido');
      if (s.isEmpty) out.add('cultivo $id: sin estaciones');
    }
    for (final k in sourceNames.keys) {
      final t = names[k];
      final miss = t == null ? locales : t.missing(locales);
      if (miss.isNotEmpty) out.add('nombre $k: falta ${miss.join(', ')}');
    }
    return out;
  }

  // ---------------- install ----------------

  /// Puts this data in the game. Returns ids it did not know (ignored).
  List<String> install() {
    final unknown = <String>[];
    kBiomeClimate
      ..clear()
      ..addAll(kBiomeClimateDefaults);
    biomes.forEach((id, c) {
      if (biomeDef(id) == null) {
        unknown.add(id);
      } else {
        kBiomeClimate[id] = c;
      }
    });
    kFishSeasonOverrides.clear();
    fishSeasons.forEach((id, s) {
      if (kFish.containsKey(id) && s.isNotEmpty) {
        if (!_same(s, kFish[id]!.seasons)) kFishSeasonOverrides[id] = s;
      } else {
        unknown.add(id);
      }
    });
    kCropSeasonOverrides.clear();
    cropSeasons.forEach((id, s) {
      if (kCrops.containsKey(id) && s.isNotEmpty) {
        if (!_same(s, kCrops[id]!.seasons)) kCropSeasonOverrides[id] = s;
      } else {
        unknown.add(id);
      }
    });
    kClimateNames
      ..clear()
      ..addAll(names);
    return unknown;
  }

  /// Back to the code values.
  static void restore() => defaults.install();

  static bool _same(Set<Season> a, Set<Season> b) =>
      a.length == b.length && a.containsAll(b);

  // ---------------- JSON ----------------

  static List<String> _seasons(Set<Season> s) => [
        for (final v in Season.values)
          if (s.contains(v)) v.name
      ];

  static Set<Season> _readSeasons(Object? j) =>
      j is List ? {for (final n in j) Season.fromName(n)} : const {};

  Map<String, Object?> toJson() => {
        'version': version,
        'biomes': {
          for (final e in biomes.entries) e.key: e.value.toJson(),
        },
        'fishSeasons': {
          for (final e in fishSeasons.entries) e.key: _seasons(e.value),
        },
        'cropSeasons': {
          for (final e in cropSeasons.entries) e.key: _seasons(e.value),
        },
        'names': {
          for (final e in names.entries) e.key: e.value.toJson(),
        },
      };

  String encode() => '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  static ClimateData fromJson(Object? j) {
    if (j is! Map) throw const FormatException('climate.json: no es un objeto');
    Map<String, Object?> m(Object? x) =>
        x is Map ? {for (final e in x.entries) '${e.key}': e.value} : const {};
    return ClimateData(
      biomes: {
        for (final e in m(j['biomes']).entries)
          e.key: BiomeClimate.fromJson(e.value),
      },
      fishSeasons: {
        for (final e in m(j['fishSeasons']).entries)
          e.key: _readSeasons(e.value),
      },
      cropSeasons: {
        for (final e in m(j['cropSeasons']).entries)
          e.key: _readSeasons(e.value),
      },
      names: {
        for (final e in m(j['names']).entries)
          e.key: LocalizedText.fromJson(e.value),
      },
    );
  }

  static ClimateData decode(String raw) => fromJson(jsonDecode(raw));
}
