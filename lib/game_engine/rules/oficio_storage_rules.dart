import 'dart:math' as math;

import '../data/fishing_catalog.dart';
import '../models/player_profile.dart';
import '../models/session_action.dart';
import 'farming_rules.dart';

/// Bolsas de oficio (docs/specs/oficio_storage.md): PESCA, CULTIVO y
/// HERRERÍA, cada una con [OficioStorageRules.cap] casillas. Una casilla es
/// una pila (especie, semilla, calidad de cosecha, herramienta...).
enum OficioBag {
  pesca('PESCA'),
  cultivo('CULTIVO'),
  herreria('HERRERÍA');

  const OficioBag(this.label);
  final String label;
}

/// Qué cuenta para cada bolsa y qué pasa cuando se llena. Dart puro; el
/// host lo aplica en `SessionEngine.apply` / `tick`.
abstract final class OficioStorageRules {
  static const cap = 40;

  /// Las casillas de [b] (claves con prefijo, `tool:` nunca se vende).
  static Set<String> cells(PlayerProfile p, OficioBag b) {
    final l = p.life, f = l.farm;
    return switch (b) {
      OficioBag.pesca => {
          for (final r in l.rods) 'tool:$r',
          for (final s in l.bag.keys) 'fish:$s',
        },
      OficioBag.cultivo => {
          for (final t in {...f.hoes, ...f.cans}) 'tool:$t',
          for (final s in f.seeds.keys) 'seed:$s',
          for (final s in f.ferts.keys) 'fert:$s',
          for (final s in f.crops.keys) 'crop:$s',
        },
      OficioBag.herreria => {for (final c in l.crafts.keys) 'craft:$c'},
    };
  }

  static int used(PlayerProfile p, OficioBag b) => cells(p, b).length;

  /// Lugar disponible: el tope, o lo que ya había si un save viejo lo
  /// supera (nunca se borra nada al cargar; solo no crece).
  static int room(PlayerProfile before, OficioBag b) =>
      math.max(cap, used(before, b));

  /// Compras que el host rechaza si dejarían una bolsa por encima de
  /// [room] (no se cobra ni se vende de vuelta).
  static bool isPurchase(SessionAction a) =>
      a is BuyRodAction ||
      (a is FarmShopAction &&
          (a.op == FarmShopOp.buySeed ||
              a.op == FarmShopOp.buyTool ||
              a.op == FarmShopOp.buyAbono)) ||
      (a is TownAction && a.op == TownOp.takeSeeds);

  /// Alguna bolsa de [after] tiene más pilas que las que permite [before].
  static bool overflows(PlayerProfile before, PlayerProfile after) =>
      OficioBag.values.any((b) => used(after, b) > room(before, b));

  /// Precio de venta automática de la pila [cell] de [p] (todas sus
  /// unidades).
  static int value(PlayerProfile p, String cell) {
    final i = cell.indexOf(':');
    final kind = cell.substring(0, i), id = cell.substring(i + 1);
    final f = p.life.farm;
    return switch (kind) {
      'fish' => (kFish[id]?.price ?? 0) * p.life.count(id),
      'crop' => switch (parseCropKey(id)) {
          (final c, final q) =>
            FarmingRules.unitPrice(p, c, q) * f.cropCount(id),
          null => 0,
        },
      'seed' => ((kCrops[id]?.price ?? 0) ~/ 2) * f.seedCount(id),
      'fert' => ((kFertilizers[id]?.price ?? 0) ~/ 2) * (f.ferts[id] ?? 0),
      _ => 0,
    };
  }

  /// Vende solas las pilas nuevas que no entran (de la última nueva hacia
  /// atrás). Las herramientas y los materiales de oficio nunca se venden.
  static ({PlayerProfile profile, int gold, List<String> sold}) settle(
      PlayerProfile before, PlayerProfile after) {
    var p = after;
    var gold = 0;
    final sold = <String>[];
    for (final b in OficioBag.values) {
      final over = used(p, b) - room(before, b);
      if (over <= 0) continue;
      final old = cells(before, b);
      final fresh = [
        for (final c in cells(p, b))
          if (!old.contains(c) && !c.startsWith('tool:') &&
              !c.startsWith('craft:'))
            c
      ].reversed.take(over);
      for (final c in fresh) {
        gold += value(p, c);
        sold.add(c);
        p = _remove(p, c);
      }
    }
    if (gold > 0) p = p.copyWith(credits: p.credits + gold);
    return (profile: p, gold: gold, sold: sold);
  }

  static PlayerProfile _remove(PlayerProfile p, String cell) {
    final i = cell.indexOf(':');
    final kind = cell.substring(0, i), id = cell.substring(i + 1);
    final l = p.life, f = l.farm;
    Map<String, int> without(Map<String, int> m) => {...m}..remove(id);
    return p.copyWith(
        life: switch (kind) {
      'fish' => l.copyWith(bag: without(l.bag)),
      'crop' => l.copyWith(farm: f.copyWith(crops: without(f.crops))),
      'seed' => l.copyWith(farm: f.copyWith(seeds: without(f.seeds))),
      'fert' => l.copyWith(farm: f.copyWith(ferts: without(f.ferts))),
      _ => l,
    });
  }

  /// Nombre legible de [cell] para el aviso.
  static String name(String cell) {
    final i = cell.indexOf(':');
    final kind = cell.substring(0, i), id = cell.substring(i + 1);
    return switch (kind) {
      'fish' => kFish[id]?.name ?? id,
      'crop' => parseCropKey(id)?.$1.name ?? id,
      'seed' => kCrops[id]?.seedName ?? id,
      'fert' => kFertilizers[id]?.name ?? id,
      _ => id,
    };
  }
}
