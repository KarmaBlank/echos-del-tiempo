import 'dart:math' as math;

import '../data/farming_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/item.dart' show CraftMaterial;
import '../models/player_profile.dart';

/// Un material de oficio (farming.md § 8.5, v0.27.0).
class LifeMaterialDef {
  const LifeMaterialDef(this.id, this.name, this.description);
  final String id, name, description;
}

const kLifeMaterials = <String, LifeMaterialDef>{
  'fibra': LifeMaterialDef('fibra', 'Fibra vegetal',
      'Cosechas prensadas y atadas. La piden los granjeros.'),
  'cebo': LifeMaterialDef('cebo', 'Cebo prensado',
      'Pescado curado en tiras. Lo piden los pescadores.'),
  'tabla': LifeMaterialDef('tabla', 'Tabla tratada',
      'Fibra trenzada y endurecida con Esquirlas. Para mejoras grandes.'),
};

/// Lo que pide condensar una unidad de un material de oficio.
typedef LifeRecipe = ({
  int crops,
  int fish,
  int fibras,
  int esquirlas,
  int credits,
});

/// CONDENSAR materiales de oficio (materials_economy.md § 4.4): cosechas o
/// pescados (nunca legendarios; primero los de menos valor) + Esquirlas +
/// oro → fibra o cebo; fibras + Esquirlas + oro → tabla. Sin azar.
abstract final class LifeCraftRules {
  static TuningDef get t => tuning(TuningId.town);

  /// Tope de cada pila.
  static const maxStack = 99;

  /// Prefijo del objetivo de `CraftOp.condense` para estos materiales.
  static const prefix = 'life:';

  static LifeRecipe? recipe(String id) => switch (id) {
        'fibra' => (
            crops: t.i('fibraIn'),
            fish: 0,
            fibras: 0,
            esquirlas: t.i('lifeEsq'),
            credits: t.i('lifeCr')
          ),
        'cebo' => (
            crops: 0,
            fish: t.i('ceboIn'),
            fibras: 0,
            esquirlas: t.i('lifeEsq'),
            credits: t.i('lifeCr')
          ),
        'tabla' => (
            crops: 0,
            fish: 0,
            fibras: t.i('tablaFibra'),
            esquirlas: t.i('tablaEsq'),
            credits: t.i('tablaCr')
          ),
        _ => null,
      };

  /// Cosechas que se pueden gastar (sin legendarias), de menos a más valor.
  static List<(String, int)> spendableCrops(PlayerProfile p) {
    final out = <(String, int, int, int)>[];
    for (final e in p.life.farm.crops.entries) {
      final c = parseCropKey(e.key);
      if (c == null || e.value <= 0) continue;
      if (c.$1.rarity == FishRarity.legendario) continue;
      out.add((e.key, e.value, c.$1.rarity.index, c.$2.index));
    }
    out.sort((a, b) {
      final r = a.$3.compareTo(b.$3);
      if (r != 0) return r;
      final q = a.$4.compareTo(b.$4);
      return q != 0 ? q : a.$1.compareTo(b.$1);
    });
    return [for (final o in out) (o.$1, o.$2)];
  }

  /// Pescados que se pueden gastar (sin legendarios), de menos a más.
  static List<(String, int)> spendableFish(PlayerProfile p) {
    final out = <(String, int, int)>[];
    for (final e in p.life.bag.entries) {
      final f = kFish[e.key];
      if (f == null || e.value <= 0 || f.rarity == FishRarity.legendario) {
        continue;
      }
      out.add((e.key, e.value, f.rarity.index));
    }
    out.sort((a, b) {
      final r = a.$3.compareTo(b.$3);
      return r != 0 ? r : a.$1.compareTo(b.$1);
    });
    return [for (final o in out) (o.$1, o.$2)];
  }

  static int _sum(List<(String, int)> l) => l.fold(0, (a, e) => a + e.$2);

  /// Cuántas veces alcanza ahora (también el lugar en la pila).
  static int maxTimes(PlayerProfile p, String id) {
    final r = recipe(id);
    if (r == null) return 0;
    final caps = <int>[maxStack - p.life.craft(id)];
    if (r.crops > 0) caps.add(_sum(spendableCrops(p)) ~/ r.crops);
    if (r.fish > 0) caps.add(_sum(spendableFish(p)) ~/ r.fish);
    if (r.fibras > 0) caps.add(p.life.craft('fibra') ~/ r.fibras);
    if (r.esquirlas > 0) {
      caps.add(p.material(CraftMaterial.esquirla) ~/ r.esquirlas);
    }
    if (r.credits > 0) caps.add(p.credits ~/ r.credits);
    return math.max(0, caps.reduce(math.min));
  }

  static Map<String, int> _take(
      Map<String, int> from, List<(String, int)> order, int n) {
    final out = {...from};
    var left = n;
    for (final (k, have) in order) {
      if (left <= 0) break;
      final k2 = math.min(have, left);
      out[k] = have - k2;
      left -= k2;
    }
    out.removeWhere((_, v) => v <= 0);
    return out;
  }

  /// Condensa [times] de [id]; `null` si no alcanza.
  static PlayerProfile? condense(PlayerProfile p, String id, int times) {
    final r = recipe(id);
    if (r == null || times < 1 || maxTimes(p, id) < times) return null;
    var life = p.life;
    if (r.crops > 0) {
      life = life.copyWith(
          farm: life.farm.copyWith(
              crops: _take(life.farm.crops, spendableCrops(p), r.crops * times)));
    }
    if (r.fish > 0) {
      life = life.copyWith(bag: _take(life.bag, spendableFish(p), r.fish * times));
    }
    final crafts = {...life.crafts};
    if (r.fibras > 0) crafts['fibra'] = life.craft('fibra') - r.fibras * times;
    crafts[id] = (crafts[id] ?? 0) + times;
    life = life.copyWith(crafts: crafts);
    final esq = p.material(CraftMaterial.esquirla);
    return p.copyWith(
      life: life,
      credits: p.credits - r.credits * times,
      materials: {
        ...p.materials,
        CraftMaterial.esquirla: esq - r.esquirlas * times,
      },
    );
  }

  /// "5 cosechas + 1 Esquirla + 20 de oro".
  static String recipeText(String id) {
    final r = recipe(id);
    if (r == null) return '';
    return [
      if (r.crops > 0) '${r.crops} cosechas',
      if (r.fish > 0) '${r.fish} pescados',
      if (r.fibras > 0) '${r.fibras} fibras',
      if (r.esquirlas > 0)
        '${r.esquirlas} Esquirla${r.esquirlas == 1 ? '' : 's'}',
      if (r.credits > 0) '${r.credits} de oro',
    ].join(' + ');
  }

  /// Gasta [mats] (id → cantidad) de los materiales de oficio de [p];
  /// `null` si no alcanza.
  static PlayerProfile? spend(PlayerProfile p, Map<String, int> mats) {
    final crafts = {...p.life.crafts};
    for (final e in mats.entries) {
      final have = crafts[e.key] ?? 0;
      if (have < e.value) return null;
      crafts[e.key] = have - e.value;
    }
    return p.copyWith(life: p.life.copyWith(crafts: crafts));
  }
}
