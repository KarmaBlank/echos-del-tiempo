import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/balance/balance_codecs.dart';
import '../../../../game_engine/data/bait_catalog.dart';
import '../../../../game_engine/data/climate_catalog.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/localized_text.dart';
import '../../../../game_engine/serialization/climate_data_json.dart';
import '../admin_controller.dart';
import 'npc_editor_controller.dart' show npcLocaleTags;

/// CLIMA area of the Editor (weather_seasons.md § 8): a draft of
/// `assets/data/climate/climate.json` (biomes, fish / crop seasons and
/// texts) plus the numbers, which live in the Balance draft (town tuning
/// for seasons and weights, fishing tuning for baits).
class ClimateEditorController extends ChangeNotifier {
  ClimateEditorController({required this.balance, List<String>? locales})
      : locales = locales ?? npcLocaleTags() {
    reload();
  }

  final AdminController balance;

  /// Every language a text must have (es-AR first).
  final List<String> locales;

  late ClimateData draft;
  late String _savedJson;
  String? message;

  bool get dirty => draft.encode() != _savedJson;

  void reload() {
    draft = ClimateData.current;
    _savedJson = draft.encode();
    message = null;
    notifyListeners();
  }

  /// Validation (ClimateData.issues); saving is blocked while not empty.
  List<String> get issues => draft.issues(locales);

  // ---- Biomes ----

  BiomeClimate biome(String id) =>
      draft.biomes[id] ?? kBiomeClimateDefaults[id] ?? const BiomeClimate();

  void _setBiome(String id, BiomeClimate c) {
    draft = ClimateData(
        biomes: {...draft.biomes, id: c},
        fishSeasons: draft.fishSeasons,
        cropSeasons: draft.cropSeasons,
        names: draft.names);
    notifyListeners();
  }

  void setExposure(String id, Exposure e) {
    final c = biome(id);
    _setBiome(
        id,
        BiomeClimate(
            exposure: e,
            allowed: c.allowed,
            snowMelt: c.snowMelt,
            ground: c.ground));
  }

  void toggleWeather(String id, Weather w) {
    if (w == Weather.despejado) return;
    final c = biome(id);
    final allowed = {...c.allowed};
    allowed.contains(w) ? allowed.remove(w) : allowed.add(w);
    _setBiome(
        id,
        BiomeClimate(
            exposure: c.exposure,
            allowed: allowed,
            snowMelt: c.snowMelt,
            ground: c.ground));
  }

  void setSnowMelt(String id, Weather w) {
    final c = biome(id);
    _setBiome(
        id,
        BiomeClimate(
            exposure: c.exposure,
            allowed: c.allowed,
            snowMelt: w,
            ground: c.ground));
  }

  void toggleGround(String id, GroundMarkId m) {
    final c = biome(id);
    final g = c.ground;
    final ground = GroundFx(
        snow: m == GroundMarkId.snow ? !g.snow : g.snow,
        puddles: m == GroundMarkId.puddles ? !g.puddles : g.puddles,
        leaves: m == GroundMarkId.leaves ? !g.leaves : g.leaves,
        flowers: m == GroundMarkId.flowers ? !g.flowers : g.flowers);
    _setBiome(
        id,
        BiomeClimate(
            exposure: c.exposure,
            allowed: c.allowed,
            snowMelt: c.snowMelt,
            ground: ground));
  }

  // ---- Fish / crop seasons ----

  Set<Season> fishSeasons(String id) =>
      draft.fishSeasons[id] ?? kFish[id]?.seasons ?? kAllSeasons;
  Set<Season> cropSeasons(String id) =>
      draft.cropSeasons[id] ?? kCrops[id]?.seasons ?? kWarmSeasons;

  static Set<Season> _toggle(Set<Season> s, Season x) {
    final out = {...s};
    out.contains(x) ? out.remove(x) : out.add(x);
    return out;
  }

  void toggleFishSeason(String id, Season s) {
    draft = ClimateData(
        biomes: draft.biomes,
        fishSeasons: {...draft.fishSeasons, id: _toggle(fishSeasons(id), s)},
        cropSeasons: draft.cropSeasons,
        names: draft.names);
    notifyListeners();
  }

  void toggleCropSeason(String id, Season s) {
    draft = ClimateData(
        biomes: draft.biomes,
        fishSeasons: draft.fishSeasons,
        cropSeasons: {...draft.cropSeasons, id: _toggle(cropSeasons(id), s)},
        names: draft.names);
    notifyListeners();
  }

  // ---- Texts ----

  String text(String key, String locale) =>
      draft.names[key]?.byLocale[locale] ?? '';

  void setText(String key, String locale, String v) {
    final m = {...?draft.names[key]?.byLocale, locale: v};
    draft = ClimateData(
        biomes: draft.biomes,
        fishSeasons: draft.fishSeasons,
        cropSeasons: draft.cropSeasons,
        names: {...draft.names, key: LocalizedText.of(m)});
    notifyListeners();
  }

  // ---- Numbers (Balance draft) ----

  num value(BalanceKind k, String key) =>
      balance.draftFields(k, k.jsonKey)[key] as num? ?? 0;

  void setValue(BalanceKind k, String key, num v) {
    balance.setField(k, k.jsonKey, key, v);
    notifyListeners();
  }

  /// Weight keys of one season (`w<Season><Weather>`).
  static List<String> seasonKeys(Season s) => [
        for (final w in Weather.values) 'w${s.key}${w.key}',
      ];

  /// Biome multiplier keys (`bio<Biome><Weather>`) present in tuning.
  List<String> biomeKeys(String biome) => [
        for (final w in Weather.values)
          if (balance
              .draftFields(BalanceKind.town, BalanceKind.town.jsonKey)
              .containsKey('bio${_cap(biome)}${w.key}'))
            'bio${_cap(biome)}${w.key}',
      ];

  static List<String> baitKeys(String id) => [
        for (final f in const ['Bite', 'Rare', 'Size', 'Price', 'Gold'])
          'bait${_baitStem(id)}$f',
      ];

  static String _baitStem(String id) => switch (id) {
        'lombriz' => 'Lombriz',
        'larva_brillante' => 'Larva',
        'cebo_escarcha' => 'Escarcha',
        'cebo_tormenta' => 'Tormenta',
        _ => 'Eco',
      };

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static Iterable<String> get biomeIds => kBiomeClimateDefaults.keys;
  static Iterable<String> get fishIds =>
      kFish.values.where((f) => f.biome != kWaterJunkBiome).map((f) => f.id);
  static Iterable<String> get cropIds =>
      kCrops.values.where((c) => c.biome != 'silvestre').map((c) => c.id);
  static Iterable<String> get baitIds => kBaits.keys;

  /// GUARDAR CLIMA: validates, writes the repo file and applies it.
  Future<bool> save() async {
    final bad = issues;
    if (bad.isNotEmpty) {
      message = 'No se guardó: ${bad.first}';
      notifyListeners();
      return false;
    }
    final repo = balance.repoPath;
    if (repo == null || !balance.host.supportsFiles) {
      message = 'Sin repo: no se puede guardar';
      notifyListeners();
      return false;
    }
    try {
      final sep = balance.host.join('a', 'b').substring(1, 2);
      await balance.host.writeFile(
          balance.host.join(repo, ClimateData.assetPath.replaceAll('/', sep)),
          draft.encode());
    } on Object catch (e) {
      message = 'No se guardó: $e';
      notifyListeners();
      return false;
    }
    draft.install();
    _savedJson = draft.encode();
    message = 'Guardado ${ClimateData.assetPath}';
    notifyListeners();
    return true;
  }
}

/// Ground overlay toggles per biome (weather_seasons.md § 5).
enum GroundMarkId { snow, puddles, leaves, flowers }
