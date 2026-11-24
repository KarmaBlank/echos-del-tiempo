import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/items_catalog.dart';
import '../models/eco.dart';
import '../models/inventory_sort.dart';
import '../models/item.dart';
import '../models/loot.dart';
import '../models/player_profile.dart';
import 'item_rules.dart';

/// Inventario de casillas por personaje (loot.md § 4b): grilla de
/// [columns] × [rows]; cada arma ocupa 1 casilla (la equipada no ocupa);
/// pociones y materiales se apilan en 1 casilla por tipo. Funciones
/// puras sobre `PlayerProfile`.
/// Uid prefix of a weapon forged at the HERRERÍA (`CraftRules.forgedPrefix`).
const kForgedUidPrefix = 'smith-';

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
        StackKind.aether => p.aethers,
        _ => p.material(k.material!),
      };

  static int stackMax(StackKind k) =>
      k == StackKind.potion || k == StackKind.ether || k == StackKind.aether
          ? kMaxItemStack
          : k.maxStack;

  static PlayerProfile withStack(PlayerProfile p, StackKind k, int n) =>
      switch (k) {
        StackKind.potion => p.copyWith(potions: n),
        StackKind.ether => p.copyWith(ethers: n),
        StackKind.aether => p.copyWith(aethers: n),
        _ => p.copyWith(materials: {...p.materials, k.material!: n}),
      };

  // ------------------------------------------------------------------
  // Casillas
  // ------------------------------------------------------------------

  /// Pilas de la sección CONSUMIBLES (v0.5.1): no ocupan casilla.
  static const consumables = [
    StackKind.potion,
    StackKind.ether,
    StackKind.aether,
  ];

  /// Pilas de la sección MATERIALES (v0.5.1): no ocupan casilla.
  static final materials = [
    for (final k in StackKind.values)
      if (k.material != null) k,
  ];

  /// Tokens que ocupan casilla, en orden natural: armas no equipadas y
  /// Ecos. Desde v0.5.1 las pilas (pociones, éter, materiales) van en sus
  /// secciones fijas y no ocupan casilla (loot.md § 17).
  static List<String> tokens(PlayerProfile p) => [
        for (final i in p.items)
          if (i.uid != p.equippedUid) i.uid,
        for (final e in p.ecos) e.uid,
      ];

  static int cellsUsed(PlayerProfile p) => tokens(p).length;

  static int freeCells(PlayerProfile p) => cells - cellsUsed(p);

  /// La grilla: respeta las posiciones guardadas (`grid`) de lo que sigue
  /// existiendo y pone lo nuevo en las primeras casillas libres. Lo que no
  /// entra queda en [overflow] (perfiles viejos con más de 40 armas).
  /// Migración v0.5.1: los tokens de pila guardados (`pot`, `mat:...`)
  /// ya no son tokens de casilla, así que su casilla queda libre.
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
    // Las marcas NUEVO de lo que ya no está se van.
    final fresh = p.fresh.isEmpty
        ? null
        : {
            for (final t in p.fresh)
              if (p.itemByUid(t) != null || p.ecoByUid(t) != null) t
          };
    return p.copyWith(
        grid: l.cells.sublist(0, last + 1),
        fresh: fresh != null && fresh.length != p.fresh.length ? fresh : null);
  }

  /// Saca la marca NUEVO de [uids] (`SeenItemsAction`); `null` si no
  /// cambia nada.
  static PlayerProfile? markSeen(PlayerProfile p, Iterable<String> uids) {
    final next = {...p.fresh}..removeAll(uids);
    return next.length == p.fresh.length ? null : p.copyWith(fresh: next);
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
  // Ordenar (v0.5.1, loot.md § 17.2)
  // ------------------------------------------------------------------

  /// Orden total de las armas y Ecos de [p] según [key], con la
  /// **equipada siempre primero** (vive en su casilla EQUIPADA, antes de
  /// la grilla). Determinístico: el último desempate es el `uid`.
  /// Salvo en [InventorySortKey.recent], primero las armas y después los
  /// Ecos (rareza, tier, más nuevo).
  List<String> sortOrder(PlayerProfile p, InventorySortKey key) {
    final index = {for (var i = 0; i < p.items.length; i++) p.items[i].uid: i};
    final eqUid = p.equippedItem?.uid;
    final weapons = [
      for (final i in p.items)
        if (i.uid != eqUid) i,
    ];
    final names = {for (final i in weapons) i.uid: _fold(items.displayName(i))};
    String type(ItemInstance i) => catalog.weapons[i.baseId]?.type ?? '';
    int byRarity(ItemInstance a, ItemInstance b) =>
        b.rarity.index.compareTo(a.rarity.index);
    int byLevel(ItemInstance a, ItemInstance b) =>
        b.itemLevel.compareTo(a.itemLevel);
    int byName(ItemInstance a, ItemInstance b) =>
        names[a.uid]!.compareTo(names[b.uid]!);
    int byRecent(String a, String b) {
      final s = _seq(b).compareTo(_seq(a));
      if (s != 0) return s;
      return (index[b] ?? -1).compareTo(index[a] ?? -1);
    }

    int chain(List<int Function()> cmps, String ua, String ub) {
      for (final c in cmps) {
        final r = c();
        if (r != 0) return r;
      }
      return ua.compareTo(ub);
    }

    weapons.sort((a, b) => chain(
        switch (key) {
          InventorySortKey.rarity => [
              () => byRarity(a, b),
              () => byLevel(a, b),
              () => byName(a, b),
            ],
          InventorySortKey.itemLevel => [
              () => byLevel(a, b),
              () => byRarity(a, b),
              () => byName(a, b),
            ],
          InventorySortKey.weaponType => [
              () => type(a).compareTo(type(b)),
              () => byRarity(a, b),
              () => byLevel(a, b),
              () => byName(a, b),
            ],
          InventorySortKey.name => [
              () => byName(a, b),
              () => byRarity(a, b),
              () => byLevel(a, b),
            ],
          InventorySortKey.recent => [() => byRecent(a.uid, b.uid)],
        },
        a.uid,
        b.uid));
    final ecos = [...p.ecos]..sort((a, b) => chain([
          () => b.rarity.index.compareTo(a.rarity.index),
          () => b.tier.compareTo(a.tier),
          () => byRecent(a.uid, b.uid),
        ], a.uid, b.uid));
    final rest = key == InventorySortKey.recent
        ? ([
            for (final w in weapons) w.uid,
            for (final e in ecos) e.uid,
          ]..sort((a, b) => chain([() => byRecent(a, b)], a, b)))
        : [
            for (final w in weapons) w.uid,
            for (final e in ecos) e.uid,
          ];
    return [if (eqUid != null) eqUid, ...rest];
  }

  /// `SortInventoryAction`: la grilla queda en el orden de [sortOrder]
  /// desde la casilla 0 (sin la equipada, que no ocupa casilla).
  PlayerProfile sort(PlayerProfile p, InventorySortKey key) {
    final eqUid = p.equippedItem?.uid;
    final order = [
      for (final t in sortOrder(p, key))
        if (t != eqUid) t,
    ];
    return relayout(
        p.copyWith(grid: order.length > cells ? order.sublist(0, cells) : order));
  }

  /// Número de `i<n>` / `eco<n>` (más alto = más nuevo); -1 si no tiene
  /// (armas iniciales y migradas).
  static int _seq(String uid) {
    final m = _seqRe.firstMatch(uid);
    return m == null ? -1 : int.parse(m.group(1)!);
  }

  static final _seqRe = RegExp(r'^(?:i|eco)(\d+)$');

  /// Minúsculas sin tildes, para ordenar por nombre.
  static String _fold(String s) {
    const from = 'áéíóúüñàèìòù';
    const to = 'aeiouunaeiou';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i < 0 ? ch : to[i]);
    }
    return b.toString();
  }

  // ------------------------------------------------------------------
  // Recibir / quitar
  // ------------------------------------------------------------------

  /// Motivo por el que [p] no puede recibir [d], o `null` si puede.
  static String? cannotReceive(PlayerProfile p, LootDrop d) {
    final st = d.stack;
    if (st != null) {
      // Las pilas tienen su sección: solo cuenta el tope.
      final have = stackCount(p, st);
      if (have + d.count > stackMax(st)) return 'Máximo ${stackMax(st)}';
      return null;
    }
    if (d.eco != null) return freeCells(p) <= 0 ? 'Inventario lleno' : null;
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

  /// Un `uid` libre de Eco (`eco<n>`, mismo contador que las armas; no
  /// choca con ningún token de la grilla).
  static (String, int) nextEcoUid(PlayerProfile p) {
    final taken = {
      for (final e in p.ecos) e.uid,
      for (final i in p.items) i.uid,
    };
    var n = p.itemSeq + 1;
    while (taken.contains('eco$n')) {
      n++;
    }
    return ('eco$n', n);
  }

  /// Agrega un Eco con un `uid` nuevo (sin mirar el lugar).
  static (PlayerProfile, String) addEco(PlayerProfile p, EcoItem eco) {
    final (uid, seq) = nextEcoUid(p);
    final next =
        p.copyWith(ecos: [...p.ecos, eco.copyWith(uid: uid)], itemSeq: seq);
    return (relayout(next), uid);
  }

  /// Saca un Eco.
  static PlayerProfile removeEco(PlayerProfile p, String uid) => relayout(
      p.copyWith(ecos: [for (final e in p.ecos) if (e.uid != uid) e]));

  /// Reemplaza un Eco por su versión nueva (mismo `uid`).
  static PlayerProfile replaceEco(PlayerProfile p, EcoItem eco) =>
      p.copyWith(ecos: [for (final e in p.ecos) e.uid == eco.uid ? eco : e]);

  /// Agrega un arma con un `uid` nuevo (sin mirar el lugar: eso es
  /// [receive]). Devuelve el perfil y el `uid` asignado.
  static (PlayerProfile, String) addItem(PlayerProfile p, ItemInstance item) {
    final (fresh, seq) = nextUid(p);
    // A weapon forged at the HERRERÍA keeps its mark (mining_smithing.md
    // § 2.2: it sells above loot).
    final uid = item.uid.startsWith(kForgedUidPrefix)
        ? '$kForgedUidPrefix$fresh'
        : fresh;
    final next = p.copyWith(
        items: [...p.items, item.copyWith(uid: uid)], itemSeq: seq);
    return (relayout(next), uid);
  }

  /// Recibe un drop si hay lugar; `null` si no. Las armas y los Ecos
  /// quedan marcados NUEVO ([markNew]; el alijo no marca).
  static PlayerProfile? receive(PlayerProfile p, LootDrop d,
      {bool markNew = true}) {
    if (cannotReceive(p, d) != null) return null;
    PlayerProfile mark((PlayerProfile, String) r) => markNew
        ? r.$1.copyWith(fresh: {...r.$1.fresh, r.$2})
        : r.$1;
    final it = d.item;
    if (it != null) return mark(addItem(p, it));
    final eco = d.eco;
    if (eco != null) return mark(addEco(p, eco));
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
    final eco = p.ecoByUid(token);
    if (eco != null) {
      return (profile: removeEco(p, token), drop: LootDrop.eco(eco), error: null);
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
