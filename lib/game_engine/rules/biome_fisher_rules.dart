import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'fishing_rules.dart';
import 'npc_talk_rules.dart';
import 'resident_rules.dart';

/// Pescador nativo de un bioma (fishing.md § 12): camina por la orilla
/// de su lago, nunca se muda al pueblo y pide un pez de su lago por día.
class BiomeFisherDef {
  const BiomeFisherDef(this.biome, this.name);
  final String biome;
  final String name;

  /// Sprite (`items.vida_npc_pesc_<bioma>` del manifest).
  String get sprite => 'npc_pesc_$biome';
}

const kBiomeFishersDefaults = <String, BiomeFisherDef>{
  kBosque: BiomeFisherDef(kBosque, 'Nera de la Orilla'),
  kRuinas: BiomeFisherDef(kRuinas, 'Tadeo Engranaje'),
  kCavernas: BiomeFisherDef(kCavernas, 'Sila Escarcha'),
  kGrieta: BiomeFisherDef(kGrieta, 'Bruno Brasa'),
  kAbismo: BiomeFisherDef(kAbismo, 'Eco Viejo'),
};

/// Lo que lee el juego (sus frases viven en `NpcTalkDef.ambient`).
final Map<String, BiomeFisherDef> kBiomeFishers =
    Map.of(kBiomeFishersDefaults);

/// Lo que pide hoy el pescador de un bioma.
typedef FisherRequest = ({String species, int n, int cm});

/// Reglas puras del pescador nativo (fishing.md § 12). El anfitrión
/// valida y entrega; la UI usa lo mismo para explicar.
abstract final class BiomeFisherRules {
  static TuningDef get t => FishingRules.t;

  /// Dónde camina en (px): una vuelta lenta por la orilla del lago.
  static (double, double) position(BiomeLayout lay, double time) {
    final (cx, cy, rx, ry) = lay.lake;
    final a = time * 0.02 + lay.id.length;
    return (
      (cx + 0.5 + (rx + 1.3) * math.cos(a)) * 16,
      (cy + 0.5 + (ry + 1.3) * math.sin(a)) * 16,
    );
  }

  /// El pedido del día [day] para alguien con Pesca [lv]: un pez del lago
  /// con rareza hasta `lv / fisherRarityLevels`, 1 a 3, y un tamaño
  /// mínimo que sube con el nivel (hasta tres cuartos del rango).
  static FisherRequest? request(String biome, int day, int lv) {
    final lay = biomeLayout(biome);
    if (lay == null) return null;
    final maxR = (lv ~/ math.max(1, t.i('fisherRarityLevels')))
        .clamp(0, FishRarity.values.length - 1);
    final pool = [
      for (final id in lay.fish)
        if ((kFish[id]?.rarity.index ?? 99) <= maxR) id
    ];
    if (pool.isEmpty) return null;
    final h = day * 7 + biome.codeUnits.fold<int>(0, (a, c) => a + c);
    final sp = pool[h % pool.length];
    final d = kFish[sp]!;
    final frac = (lv / math.max(1, FishingRules.maxLevel)).clamp(0.0, 0.75);
    return (
      species: sp,
      n: 1 + h % 3,
      cm: d.minCm + ((d.maxCm - d.minCm) * frac).round(),
    );
  }

  static String dayKey(PlayerProfile p, String biome, int day) =>
      'fr:${p.name}:$biome:$day';

  /// Recompensa: XP de Pesca, XP de personaje y oro.
  static ({int fishXp, int charXp, int gold}) reward(FisherRequest r, int lv) {
    final v = (kFish[r.species]?.price ?? 10) * r.n;
    return (
      fishXp: t.i('fisherXpBase') + t.i('fisherXpStep') * lv,
      charXp: (v * t.d('fisherCharXpPerValue')).round(),
      gold: (v * t.d('fisherGoldPerValue')).round(),
    );
  }

  /// Oro del pedido con su favor (overworld_biomes.md § 12.3): después de
  /// invitarlo, paga [NpcTalkRules.favorGold] veces.
  static int favorGold(TownState s, String biome, int gold) =>
      NpcTalkRules.declined(s, biome)
          ? (gold * NpcTalkRules.favorGold).round()
          : gold;

  /// Por qué [p] no puede entregar hoy (o `null`).
  static String? cannot(PlayerProfile p, TownState s, String biome, int day) {
    final r = request(biome, day, FishingRules.level(p));
    if (r == null) return 'Hoy no pide nada';
    if (s.daily.containsKey(dayKey(p, biome, day))) {
      return 'Ya le entregaste hoy';
    }
    if ((p.life.log[r.species] ?? 0) < r.cm) {
      return 'Pescá uno de ${r.cm} cm o más';
    }
    final have = p.life.count(r.species);
    if (have < r.n) return 'Tenés $have de ${r.n}';
    return null;
  }

  /// Entrega: perfil (pescados, oro y XP de Pesca), pueblo (marca del
  /// día) y la XP de personaje que suma el motor.
  static (PlayerProfile, TownState, int)? deliver(
      PlayerProfile p, TownState s, String biome, int day) {
    if (cannot(p, s, biome, day) != null) return null;
    final lv = FishingRules.level(p);
    final r = request(biome, day, lv)!;
    final taken = ResidentRules.takeFish(p, r.species, r.n);
    if (taken == null) return null;
    final w = reward(r, lv);
    final prof = taken.copyWith(
        credits: taken.credits + favorGold(s, biome, w.gold),
        life: taken.life.copyWith(fishXp: taken.life.fishXp + w.fishXp));
    return (
      prof,
      s.copyWith(daily: {...s.daily, dayKey(p, biome, day): 1}),
      w.charXp,
    );
  }
}
