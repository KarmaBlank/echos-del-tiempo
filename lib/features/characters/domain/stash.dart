import 'dart:math' as math;

import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/inventory_rules.dart';
import '../../../game_engine/rules/item_rules.dart';

/// Lo que hay en una casilla del alijo: un arma o una pila de material.
class StashEntry {
  const StashEntry.item(ItemInstance this.item)
      : material = null,
        count = 1;
  const StashEntry.material(CraftMaterial this.material, this.count)
      : item = null;

  final ItemInstance? item;
  final CraftMaterial? material;
  final int count;

  Map<String, Object?> toJson() =>
      item != null ? {'it': item!.toJson()} : {'m': material!.name, 'n': count};

  /// `null` si no tiene la forma esperada. Las armas pasan por
  /// [ItemRules.sanitize] (las inválidas se descartan).
  static StashEntry? fromJson(Map<Object?, Object?> raw, ItemRules rules) {
    final it = ItemInstance.fromJson(raw['it']);
    if (it != null) {
      final ok = rules.sanitize(it);
      return ok == null ? null : StashEntry.item(ok);
    }
    final m = raw['m'], n = raw['n'];
    final mat = m is String ? CraftMaterial.byName(m) : null;
    if (mat == null || n is! num || n < 1) return null;
    return StashEntry.material(
        mat, math.min(n.toInt(), Stash.maxMaterialStack));
  }
}

/// Alijo compartido por los personajes de la cuenta: [tabs] pestañas de
/// [columns] × [rows]. Inmutable. Ver docs/specs/characters.md § 3.
class Stash {
  Stash._(this.cells);

  factory Stash.empty() =>
      Stash._(List.unmodifiable(List<StashEntry?>.filled(size, null)));

  static const tabs = 2;
  static const columns = 8;
  static const rows = 6;
  static const perTab = columns * rows;
  static const size = tabs * perTab;

  /// Tope de una pila de material en el alijo (el personaje: 99).
  static const maxMaterialStack = 999;

  /// Las [size] casillas (`null` = vacía); la pestaña es `i ~/ perTab`.
  final List<StashEntry?> cells;

  int get used => cells.where((c) => c != null).length;

  bool get isEmpty => used == 0;

  /// Casilla de la pila de [m], o `null`.
  int? cellOf(CraftMaterial m) {
    final i = cells.indexWhere((c) => c?.material == m);
    return i < 0 ? null : i;
  }

  /// Primera casilla libre, empezando por la pestaña [tab].
  int? firstFree({int tab = 0}) {
    for (var t = 0; t < tabs; t++) {
      final base = ((tab + t) % tabs) * perTab;
      for (var i = base; i < base + perTab; i++) {
        if (cells[i] == null) return i;
      }
    }
    return null;
  }

  Stash put(int i, StashEntry? e) {
    final next = [...cells];
    next[i] = e;
    return Stash._(List.unmodifiable(next));
  }

  Map<String, Object?> toJson() => {
        'cells': [
          for (var i = 0; i < size; i++)
            if (cells[i] case final c?) {'i': i, ...c.toJson()},
        ],
      };

  /// Lectura tolerante: casillas fuera de rango, repetidas o inválidas se
  /// descartan; dos pilas del mismo material se juntan en la primera.
  factory Stash.fromJson(Object? raw, {ItemRules rules = const ItemRules()}) {
    final out = List<StashEntry?>.filled(size, null);
    final list = raw is Map ? raw['cells'] : null;
    if (list is List) {
      for (final r in list) {
        if (r is! Map) continue;
        final i = r['i'];
        if (i is! num) continue;
        final idx = i.toInt();
        if (idx < 0 || idx >= size || out[idx] != null) continue;
        final e = StashEntry.fromJson(r, rules);
        if (e == null) continue;
        final m = e.material;
        if (m != null) {
          final at = out.indexWhere((c) => c?.material == m);
          if (at >= 0) {
            out[at] = StashEntry.material(
                m, math.min(out[at]!.count + e.count, maxMaterialStack));
            continue;
          }
        }
        out[idx] = e;
      }
    }
    return Stash._(List.unmodifiable(out));
  }
}

/// Resultado de mover algo entre un personaje y el alijo: el perfil y
/// el alijo nuevos, o el motivo por el que no se puede.
class StashMove {
  const StashMove(PlayerProfile this.profile, Stash this.stash) : error = null;
  const StashMove.error(String this.error)
      : profile = null,
        stash = null;

  final PlayerProfile? profile;
  final Stash? stash;
  final String? error;

  bool get ok => error == null;
}

/// Reglas del alijo (docs/specs/characters.md § 3). Funciones puras; la
/// validación del lado del personaje es la de [InventoryRules].
class StashRules {
  const StashRules({this.inventory = const InventoryRules()});

  final InventoryRules inventory;

  static const potionsError = 'Las pociones no van al alijo';
  static const stashFull = 'Alijo lleno';

  /// Guarda en el alijo lo que el personaje tiene en [token] (`uid` de
  /// arma o `mat:<material>`), en la pestaña [tab] si hay lugar.
  StashMove deposit(PlayerProfile p, Stash s, String token, {int tab = 0}) {
    final st = StackKind.byToken(token);
    if (st != null) {
      final m = st.material;
      if (m == null) return const StashMove.error(potionsError);
      final have = InventoryRules.stackCount(p, st);
      if (have <= 0) return const StashMove.error('No tienes tantos');
      var at = s.cellOf(m);
      final inStash = at == null ? 0 : s.cells[at]!.count;
      final n = math.min(have, Stash.maxMaterialStack - inStash);
      if (n <= 0) {
        return const StashMove.error('Alijo: máximo ${Stash.maxMaterialStack}');
      }
      at ??= s.firstFree(tab: tab);
      if (at == null) return const StashMove.error(stashFull);
      final taken = inventory.take(p, token, count: n);
      if (taken.error != null) return StashMove.error(taken.error!);
      return StashMove(
          taken.profile!, s.put(at, StashEntry.material(m, inStash + n)));
    }
    final it = p.itemByUid(token);
    if (it == null) return const StashMove.error('No lo tienes');
    if (inventory.isProtected(p, token)) {
      return StashMove.error(
          token == p.equippedUid ? 'Equipada' : 'Arma inicial');
    }
    final at = s.firstFree(tab: tab);
    if (at == null) return const StashMove.error(stashFull);
    final taken = inventory.take(p, token);
    if (taken.error != null) return StashMove.error(taken.error!);
    return StashMove(taken.profile!, s.put(at, StashEntry.item(it)));
  }

  /// Saca al personaje lo que hay en la casilla [cell] del alijo. Los
  /// materiales: lo que entre (hasta el tope del personaje).
  StashMove withdraw(PlayerProfile p, Stash s, int cell) {
    if (cell < 0 || cell >= Stash.size) {
      return const StashMove.error('Casilla vacía');
    }
    final e = s.cells[cell];
    if (e == null) return const StashMove.error('Casilla vacía');
    final it = e.item;
    if (it != null) {
      final drop = LootDrop.item(it);
      final why = InventoryRules.cannotReceive(p, drop);
      if (why != null) return StashMove.error(why);
      return StashMove(InventoryRules.receive(p, drop)!, s.put(cell, null));
    }
    final st = StackKind.of(e.material!);
    final have = InventoryRules.stackCount(p, st);
    final n = math.min(e.count, InventoryRules.stackMax(st) - have);
    if (n <= 0) {
      return StashMove.error('Máximo ${InventoryRules.stackMax(st)}');
    }
    final drop = LootDrop.stack(st, n);
    final why = InventoryRules.cannotReceive(p, drop);
    if (why != null) return StashMove.error(why);
    final left = e.count - n;
    return StashMove(InventoryRules.receive(p, drop)!,
        s.put(cell, left > 0 ? StashEntry.material(e.material!, left) : null));
  }

  /// Cambia de lugar dos casillas del alijo. `null` si no se puede.
  static Stash? move(Stash s, int from, int to) {
    if (from < 0 || to < 0 || from >= Stash.size || to >= Stash.size) {
      return null;
    }
    if (from == to || s.cells[from] == null) return null;
    final a = s.cells[from], b = s.cells[to];
    return s.put(from, b).put(to, a);
  }
}
