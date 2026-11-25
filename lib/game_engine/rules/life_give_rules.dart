import 'dart:math' as math;

import '../data/tuning_catalog.dart';
import '../models/player_profile.dart';
import 'mining_rules.dart';
import 'oficio_storage_rules.dart';

/// Why a profession-material gift is refused (docs/specs/share_materials.md).
enum LifeGiveBlock { unknown, amount, missing, recipientFull }

/// Giving profession materials to a teammate (share_materials.md): a
/// stack of a profession bag (`fish:`, `crop:`, `seed:`, `fert:`,
/// `craft:`) or a smithing material (`ore:`). Tools never move. Pure
/// Dart; the host validates with [give] inside `SessionEngine`.
abstract final class LifeGiveRules {
  static const kinds = ['fish', 'crop', 'seed', 'fert', 'craft', 'ore'];

  static TuningDef get _t => tuning(TuningId.town);

  /// The middle preset of the amount selector (1 / [step] / all).
  static int get step => math.max(1, _t.i('giveStep'));

  /// Units of [cell] that [p] owns (0 for unknown cells).
  static int have(PlayerProfile p, String cell) {
    final (kind, id) = _split(cell) ?? ('', '');
    final l = p.life, f = l.farm;
    return switch (kind) {
      'fish' => l.count(id),
      'crop' => f.crops[id] ?? 0,
      'seed' => f.seeds[id] ?? 0,
      'fert' => f.ferts[id] ?? 0,
      'craft' => l.craft(id),
      'ore' => l.ore(id),
      _ => 0,
    };
  }

  static (String, String)? _split(String cell) {
    final i = cell.indexOf(':');
    if (i <= 0 || i == cell.length - 1) return null;
    final kind = cell.substring(0, i);
    return kinds.contains(kind) ? (kind, cell.substring(i + 1)) : null;
  }

  /// [p] with [n] (may be negative) more units of [cell].
  static PlayerProfile _add(PlayerProfile p, String cell, int n) {
    final (kind, id) = _split(cell)!;
    final l = p.life, f = l.farm;
    Map<String, int> plus(Map<String, int> m) {
      final v = (m[id] ?? 0) + n;
      final out = {...m};
      if (v <= 0) {
        out.remove(id);
      } else {
        out[id] = v;
      }
      return out;
    }

    return p.copyWith(
        life: switch (kind) {
      'fish' => l.copyWith(bag: plus(l.bag)),
      'crop' => l.copyWith(farm: f.copyWith(crops: plus(f.crops))),
      'seed' => l.copyWith(farm: f.copyWith(seeds: plus(f.seeds))),
      'fert' => l.copyWith(farm: f.copyWith(ferts: plus(f.ferts))),
      'craft' => l.copyWith(crafts: plus(l.crafts)),
      _ => l.copyWith(ores: plus(l.ores)),
    });
  }

  static int get _oreCap => math.max(1, MiningRules.t.i('stackCap'));

  /// Why [from] cannot give [n] of [cell] to [to] (or `null`).
  static LifeGiveBlock? block(
      PlayerProfile from, PlayerProfile to, String cell, int n) {
    if (_split(cell) == null) return LifeGiveBlock.unknown;
    if (n < 1) return LifeGiveBlock.amount;
    if (have(from, cell) < n) return LifeGiveBlock.missing;
    final after = _add(to, cell, n);
    if (have(after, cell) != have(to, cell) + n) return LifeGiveBlock.unknown;
    if (cell.startsWith('ore:') && have(after, cell) > _oreCap) {
      return LifeGiveBlock.recipientFull;
    }
    if (OficioStorageRules.overflows(to, after)) {
      return LifeGiveBlock.recipientFull;
    }
    return null;
  }

  /// Moves [n] of [cell] from [from] to [to]; `null` if [block] refuses.
  static (PlayerProfile, PlayerProfile)? give(
      PlayerProfile from, PlayerProfile to, String cell, int n) {
    if (block(from, to, cell, n) != null) return null;
    return (_add(from, cell, -n), _add(to, cell, n));
  }
}
