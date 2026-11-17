import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/items_catalog.dart';
import '../models/item.dart';
import '../models/loot.dart';
import '../models/player_profile.dart';
import 'item_rules.dart';

/// Inventario de casillas por personaje (loot.md § 4b): grilla de
/// [columns] × [rows]; cada arma ocupa 1 casilla (la equipada no ocupa);
/// pociones y materiales se apilan en 1 casilla por tipo. Funciones
/// puras sobre `PlayerProfile`.
class InventoryRules {
  const InventoryRules({this.items = const ItemRules()});

  final ItemRules items;

  GameCatalog get catalog => items.catalog;

  static const columns = 8;
  static const rows = 5;
  static const cells = columns * rows;

  /// Tope de armas guardadas (con lo que desborda la grilla incluido).
  static const maxItems = cells * 2;

  // ------------------------------------------------------------------
  // Pilas
  // ------------------------------------------------------------------

  static int stackCount(PlayerProfile p, StackKind k) => switch (k) {
        StackKind.potion => p.potions,
        StackKind.ether => p.ethers,
        _ => p.material(k.material!),
      };

  static int stackMax(StackKind k) =>
      k == StackKind.potion || k == StackKind.ether ? kMaxItemStack : k.maxStack;

  static PlayerProfile withStack(PlayerProfile p, StackKind k, int n) =>
      switch (k) {
        StackKind.potion => p.copyWith(potions: n),
        StackKind.ether => p.copyWith(ethers: n),
        _ => p.copyWith(materials: {...p.materials, k.material!: n}),
      };

  // ------------------------------------------------------------------
  // Casillas
  // ------------------------------------------------------------------

  /// Tokens que ocupan casilla, en orden natural (armas no equipadas,
  /// después pociones y materiales).
  static List<String> tokens(PlayerProfile p) => [
        for (final i in p.items)
          if (i.uid != p.equippedUid) i.uid,
        for (final k in StackKind.values)
          if (stackCount(p, k) > 0) k.token,
      ];

  static int cellsUsed(PlayerProfile p) => tokens(p).length;

  static int freeCells(PlayerProfile p) => cells - cellsUsed(p);

  /// La grilla: respeta las posiciones guardadas (`grid`) de lo que sigue
  /// existiendo y pone lo nuevo en las primeras casillas libres. Lo que no
  /// entra queda en [overflow] (perfiles viejos con más de 40 armas).
  static ({List<String?> cells, List<String> overflow}) layout(
      PlayerProfile p) {
    final present = tokens(p);
    final left = {...present};
    final out = List<String?>.filled(cells, null);
    for (var i = 0; i < math.min(cells, p.grid.length); i++) {
      final t = p.grid[i];
      if (t != null && left.remove(t)) out[i] = t;
    }
    final overflow = <String>[];
    var free = 0;
    for (final t in present) {
      if (!left.contains(t)) continue;
      while (free < cells && out[free] != null) {
        free++;
      }
      if (free < cells) {
        out[free] = t;
      } else {
        overflow.add(t);
      }
    }
    return (cells: out, overflow: overflow);
  }

  /// Guarda la grilla normalizada en el perfil.
  static PlayerProfile relayout(PlayerProfile p) {
    final l = layout(p);
    var last = l.cells.lastIndexWhere((t) => t != null);
    return p.copyWith(grid: l.cells.sublist(0, last + 1));
  }

  /// Mueve (intercambia) dos casillas. `null` si alguna está fuera.
  static PlayerProfile? move(PlayerProfile p, int from, int to) {
    if (from < 0 || to < 0 || from >= cells || to >= cells || from == to) {
      return null;
    }
    final g = layout(p).cells;
    if (g[from] == null) return null;
    final t = g[from];
    g[from] = g[to];
    g[to] = t;
    final last = g.lastIndexWhere((x) => x != null);
    return p.copyWith(grid: g.sublist(0, last + 1));
  }

  // ------------------------------------------------------------------
  // Recibir / quitar
  // ------------------------------------------------------------------

  /// Motivo por el que [p] no puede recibir [d], o `null` si puede.
  static String? cannotReceive(PlayerProfile p, LootDrop d) {
    final st = d.stack;
    if (st != null) {
      final have = stackCount(p, st);
      if (have + d.count > stackMax(st)) return 'Máximo ${stackMax(st)}';
      if (have == 0 && freeCells(p) <= 0) return 'Inventario lleno';
      return null;
    }
    if (p.items.length >= maxItems || freeCells(p) <= 0) {
      return 'Inventario lleno';
    }
    return null;
  }

  /// Un `uid` libre (`i<n>`) y el contador nuevo.
  static (String, int) nextUid(PlayerProfile p) {
    final taken = {for (final i in p.items) i.uid};
    var n = p.itemSeq + 1;
    while (taken.contains('i$n')) {
      n++;
    }
    return ('i$n', n);
  }

  /// Agrega un arma con un `uid` nuevo (sin mirar el lugar: eso es
  /// [receive]). Devuelve el perfil y el `uid` asignado.
  static (PlayerProfile, String) addItem(PlayerProfile p, ItemInstance item) {
    final (uid, seq) = nextUid(p);
    final next = p.copyWith(
        items: [...p.items, item.copyWith(uid: uid)], itemSeq: seq);
    return (relayout(next), uid);
  }

  /// Recibe un drop si hay lugar; `null` si no.
  static PlayerProfile? receive(PlayerProfile p, LootDrop d) {
    if (cannotReceive(p, d) != null) return null;
    final it = d.item;
    if (it != null) return addItem(p, it).$1;
    final st = d.stack!;
    return relayout(withStack(p, st, stackCount(p, st) + d.count));
  }

  /// Saca un arma (sin validar si está protegida).
  static PlayerProfile removeItem(PlayerProfile p, String uid) => relayout(
      p.copyWith(items: [for (final i in p.items) if (i.uid != uid) i]));

  /// Reemplaza un arma por su versión nueva (mismo `uid`).
  static PlayerProfile replaceItem(PlayerProfile p, ItemInstance item) =>
      p.copyWith(items: [
        for (final i in p.items) i.uid == item.uid ? item : i,
      ]);

  /// No se puede soltar, dar ni sacrificar: la equipada y la última
  /// instancia del arma inicial de su clase.
  bool isProtected(PlayerProfile p, String uid) {
    if (uid == p.equippedUid) return true;
    final it = p.itemByUid(uid);
    if (it == null) return false;
    final start = catalog.classes[p.classId]?.startWeaponId;
    return it.baseId == start &&
        p.items.where((i) => i.baseId == start).length <= 1;
  }

  /// Lo que se saca del inventario para dar o soltar: un arma por `uid`
  /// o [count] de una pila por token. Devuelve el perfil sin eso y el
  /// drop, o el motivo si no se puede.
  ({PlayerProfile? profile, LootDrop? drop, String? error}) take(
      PlayerProfile p, String token, {int count = 1}) {
    final st = StackKind.byToken(token);
    if (st != null) {
      final have = stackCount(p, st);
      if (count <= 0 || count > have) {
        return (profile: null, drop: null, error: 'No tienes tantos');
      }
      return (
        profile: relayout(withStack(p, st, have - count)),
        drop: LootDrop.stack(st, count),
        error: null,
      );
    }
    final it = p.itemByUid(token);
    if (it == null) return (profile: null, drop: null, error: 'No lo tienes');
    if (isProtected(p, token)) {
      return (
        profile: null,
        drop: null,
        error: token == p.equippedUid ? 'Equipada' : 'Arma inicial',
      );
    }
    return (profile: removeItem(p, token), drop: LootDrop.item(it), error: null);
  }
}
