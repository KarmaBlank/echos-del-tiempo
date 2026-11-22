import 'dart:math' as math;

import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/eco_rules.dart';
import '../../../game_engine/rules/inventory_rules.dart';
import '../../../game_engine/rules/item_rules.dart';

/// Lo que hay en una casilla del alijo: un arma, un Eco o una pila de
/// material.
class StashEntry {
  const StashEntry.item(ItemInstance this.item)
      : material = null,
        eco = null,
        count = 1;
  const StashEntry.material(CraftMaterial this.material, this.count)
      : item = null,
        eco = null;

  /// Los Ecos también van al alijo (docs/specs/ecos_atlas.md § 2).
  const StashEntry.eco(EcoItem this.eco)
      : item = null,
        material = null,
        count = 1;

  final ItemInstance? item;
  final CraftMaterial? material;
  final EcoItem? eco;
  final int count;

  Map<String, Object?> toJson() => item != null
      ? {'it': item!.toJson()}
      : eco != null
          ? {'eco': eco!.toJson()}
          : {'m': material!.name, 'n': count};

  /// `null` si no tiene la forma esperada. Las armas pasan por
  /// [ItemRules.sanitize] (las inválidas se descartan).
  static StashEntry? fromJson(Map<Object?, Object?> raw, ItemRules rules) {
    final it = ItemInstance.fromJson(raw['it']);
    if (it != null) {
      final ok = rules.sanitize(it);
      return ok == null ? null : StashEntry.item(ok);
    }
    final eco = EcoItem.fromJson(raw['eco']);
    if (eco != null) return StashEntry.eco(EcoRules.sanitize(eco));
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
  Stash._(this.cells, [List<StashEntry> unclaimed = const []])
      : unclaimed = List.unmodifiable(unclaimed);

  factory Stash.empty() =>
      Stash._(List.unmodifiable(List<StashEntry?>.filled(size, null)));

  /// Objetos sin recoger (loot.md § 4b): lo propio que quedó en el piso o
  /// no entró en el inventario y tampoco en el alijo. Sin tope: nada que
  /// era de un jugador se pierde. Lo más nuevo, al final.
  final List<StashEntry> unclaimed;

  Stash withUnclaimed(List<StashEntry> next) => Stash._(cells, next);

  /// 2 pestañas generales + la de ECOS (characters.md § 3.1).
  static const tabs = 3;

  /// Pestaña ECOS: solo Ecos y materiales de endgame ([isEndgame]).
  static const ecoTab = 2;
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

  /// Ecos y materiales del Atlas / Abismo: los que van a la pestaña ECOS.
  static bool isEndgame({EcoItem? eco, CraftMaterial? material}) =>
      eco != null ||
      material == CraftMaterial.ancla ||
      material == CraftMaterial.esencia ||
      (material?.isFragment ?? false);

  static bool entryIsEndgame(StashEntry e) =>
      isEndgame(eco: e.eco, material: e.material);

  /// La casilla [cell] admite [e] (la pestaña ECOS, solo endgame).
  static bool accepts(int cell, StashEntry e) =>
      cell ~/ perTab != ecoTab || entryIsEndgame(e);

  /// Orden de pestañas donde buscar lugar: lo de endgame, primero ECOS y
  /// después las generales; lo demás, solo las generales empezando por
  /// [tab].
  static List<int> tabOrder({int tab = 0, bool endgame = false}) {
    final general = [for (var t = 0; t < tabs; t++) if (t != ecoTab) t];
    final start = general.indexOf(tab);
    final g = start < 0
        ? general
        : [...general.sublist(start), ...general.sublist(0, start)];
    return endgame ? [ecoTab, ...g] : g;
  }

  /// Primera casilla libre según [tabOrder].
  int? firstFree({int tab = 0, bool endgame = false}) {
    for (final t in tabOrder(tab: tab, endgame: endgame)) {
      final base = t * perTab;
      for (var i = base; i < base + perTab; i++) {
        if (cells[i] == null) return i;
      }
    }
    return null;
  }

  Stash put(int i, StashEntry? e) {
    final next = [...cells];
    next[i] = e;
    return Stash._(List.unmodifiable(next), unclaimed);
  }

  Map<String, Object?> toJson() => {
        'cells': [
          for (var i = 0; i < size; i++)
            if (cells[i] case final c?) {'i': i, ...c.toJson()},
        ],
        // v0.20.11: Objetos sin recoger (opcional; vacío si falta).
        if (unclaimed.isNotEmpty)
          'uncl': [for (final e in unclaimed) e.toJson()],
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
    final box = <StashEntry>[];
    final rawBox = raw is Map ? raw['uncl'] : null;
    if (rawBox is List) {
      for (final r in rawBox) {
        if (r is! Map) continue;
        final e = StashEntry.fromJson(r, rules);
        if (e != null) box.add(e);
      }
    }
    return Stash._(List.unmodifiable(out), box);
  }
}

/// Resultado de mover algo entre un personaje y el alijo: el perfil y
/// el alijo nuevos (y [drop], lo que se movió), o el motivo por el que
/// no se puede.
class StashMove {
  const StashMove(PlayerProfile this.profile, Stash this.stash, {this.drop})
      : error = null;
  const StashMove.error(String this.error)
      : profile = null,
        stash = null,
        drop = null;

  final PlayerProfile? profile;
  final Stash? stash;
  final LootDrop? drop;
  final String? error;

  bool get ok => error == null;
}

/// Una pieza de un movimiento en lote: [token] del personaje (al alijo)
/// o [cell] del alijo (al personaje), y lo que se movió.
class StashBatchItem {
  const StashBatchItem({this.token, this.cell, required this.drop});
  final String? token;
  final int? cell;
  final LootDrop drop;
}

/// Resultado de un lote ([StashRules.depositMany] / `withdrawMany`):
/// cómo quedan perfil y alijo, qué se movió y cuántas piezas quedaron
/// (con el primer motivo).
class StashBatch {
  const StashBatch(this.profile, this.stash, this.moved,
      {this.left = 0, this.reason});

  final PlayerProfile profile;
  final Stash stash;
  final List<StashBatchItem> moved;
  final int left;
  final String? reason;

  /// `Movidos N · Quedaron M: alijo lleno` (una línea).
  String summary() {
    final base = 'Movidos ${moved.length}';
    if (left == 0) return base;
    final why = reason == null ? '' : ': ${reason!.toLowerCase()}';
    return '$base · Quedaron $left$why';
  }
}

/// Reglas del alijo (docs/specs/characters.md § 3). Funciones puras; la
/// validación del lado del personaje es la de [InventoryRules].
class StashRules {
  const StashRules({this.inventory = const InventoryRules()});

  final InventoryRules inventory;

  static const potionsError = 'Las pociones no van al alijo';
  static const stashFull = 'Alijo lleno';
  static const ecoTabOnly = 'La pestaña ECOS es solo para Ecos y endgame';

  /// Motivo por el que [token] no puede ir al alijo nunca (equipada, arma
  /// inicial, pociones), o `null`.
  String? blocked(PlayerProfile p, String token) {
    final st = StackKind.byToken(token);
    if (st != null) return st.material == null ? potionsError : null;
    if (p.ecoByUid(token) != null) return null;
    if (p.itemByUid(token) == null) return 'No lo tienes';
    if (inventory.isProtected(p, token)) {
      return token == p.equippedUid ? 'Equipada' : 'Arma inicial';
    }
    return null;
  }

  /// Todo lo que se puede llevar al alijo (MOVER TODO): armas no
  /// protegidas y Ecos de la grilla, y las pilas de materiales.
  List<String> movableTokens(PlayerProfile p) => [
        for (final t in InventoryRules.layout(p).cells)
          if (t != null && StackKind.byToken(t) == null && blocked(p, t) == null)
            t,
        for (final m in CraftMaterial.values)
          if (InventoryRules.stackCount(p, StackKind.of(m)) > 0)
            StackKind.of(m).token,
      ];

  /// Guarda en el alijo lo que el personaje tiene en [token] (`uid` de
  /// arma o `mat:<material>`), en la pestaña [tab] si hay lugar (Ecos y
  /// materiales de endgame: primero la pestaña ECOS).
  StashMove deposit(PlayerProfile p, Stash s, String token, {int tab = 0}) {
    final why = blocked(p, token);
    if (why != null) return StashMove.error(why);
    final st = StackKind.byToken(token);
    if (st != null) {
      final m = st.material!;
      final have = InventoryRules.stackCount(p, st);
      if (have <= 0) return const StashMove.error('No tienes tantos');
      final at = s.cellOf(m);
      final inStash = at == null ? 0 : s.cells[at]!.count;
      final n = math.min(have, Stash.maxMaterialStack - inStash);
      if (n <= 0) {
        return const StashMove.error('Alijo: máximo ${Stash.maxMaterialStack}');
      }
      final drop = LootDrop.stack(st, n);
      final next = store(s, drop, tab: tab);
      if (next == null) return const StashMove.error(stashFull);
      final taken = inventory.take(p, token, count: n);
      if (taken.error != null) return StashMove.error(taken.error!);
      return StashMove(taken.profile!, next, drop: drop);
    }
    final eco = p.ecoByUid(token);
    if (eco != null) {
      final drop = LootDrop.eco(eco);
      final next = store(s, drop, tab: tab);
      if (next == null) return const StashMove.error(stashFull);
      return StashMove(InventoryRules.removeEco(p, token), next, drop: drop);
    }
    final it = p.itemByUid(token)!;
    final drop = LootDrop.item(it);
    final next = store(s, drop, tab: tab);
    if (next == null) return const StashMove.error(stashFull);
    final taken = inventory.take(p, token);
    if (taken.error != null) return StashMove.error(taken.error!);
    return StashMove(taken.profile!, next, drop: drop);
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
    final eco = e.eco;
    if (it != null || eco != null) {
      final drop = it != null ? LootDrop.item(it) : LootDrop.eco(eco!);
      final why = InventoryRules.cannotReceive(p, drop);
      if (why != null) return StashMove.error(why);
      return StashMove(
          InventoryRules.receive(p, drop, markNew: false)!, s.put(cell, null),
          drop: drop);
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
    return StashMove(InventoryRules.receive(p, drop, markNew: false)!,
        unstore(s, cell, drop)!,
        drop: drop);
  }

  /// Guarda en lote [tokens] (MOVER TODO / MOVER ELEGIDOS): lo que entra
  /// se mueve, lo demás queda con el primer motivo.
  StashBatch depositMany(PlayerProfile p, Stash s, Iterable<String> tokens,
      {int tab = 0}) {
    final moved = <StashBatchItem>[];
    var left = 0;
    String? reason;
    for (final t in tokens) {
      final m = deposit(p, s, t, tab: tab);
      if (!m.ok) {
        left++;
        reason ??= m.error;
        continue;
      }
      p = m.profile!;
      s = m.stash!;
      moved.add(StashBatchItem(token: t, drop: m.drop!));
    }
    return StashBatch(p, s, moved, left: left, reason: reason);
  }

  /// Saca en lote las casillas [cells] (SACAR ELEGIDOS).
  StashBatch withdrawMany(PlayerProfile p, Stash s, Iterable<int> cells) {
    final moved = <StashBatchItem>[];
    var left = 0;
    String? reason;
    for (final c in cells) {
      final m = withdraw(p, s, c);
      if (!m.ok) {
        left++;
        reason ??= m.error;
        continue;
      }
      p = m.profile!;
      s = m.stash!;
      moved.add(StashBatchItem(cell: c, drop: m.drop!));
    }
    return StashBatch(p, s, moved, left: left, reason: reason);
  }

  /// Pone [d] en el alijo: un material se suma a su pila (hasta 999),
  /// lo demás va a la primera casilla libre. `null` si no entra.
  static Stash? store(Stash s, LootDrop d, {int tab = 0}) {
    final m = d.stack?.material;
    if (d.stack != null && m == null) return null;
    final StashEntry e;
    if (d.item case final it?) {
      e = StashEntry.item(it);
    } else if (d.eco case final eco?) {
      e = StashEntry.eco(eco);
    } else {
      final at = s.cellOf(m!);
      final inStash = at == null ? 0 : s.cells[at]!.count;
      if (inStash + d.count > Stash.maxMaterialStack) return null;
      e = StashEntry.material(m, inStash + d.count);
      if (at != null) return s.put(at, e);
    }
    final at = s.firstFree(tab: tab, endgame: Stash.entryIsEndgame(e));
    return at == null ? null : s.put(at, e);
  }

  /// Saca [d] de la casilla [cell] (lo que [store] puso). `null` si la
  /// casilla no lo tiene.
  static Stash? unstore(Stash s, int cell, LootDrop d) {
    if (cell < 0 || cell >= Stash.size) return null;
    final e = s.cells[cell];
    if (e == null) return null;
    if (d.item != null || d.eco != null) {
      final same = d.item != null
          ? e.item?.uid == d.item!.uid
          : e.eco?.uid == d.eco!.uid;
      return same ? s.put(cell, null) : null;
    }
    final m = d.stack?.material;
    if (m == null || e.material != m || e.count < d.count) return null;
    final left = e.count - d.count;
    return s.put(cell, left > 0 ? StashEntry.material(m, left) : null);
  }

  /// Guarda [d] (loot recuperado): al alijo si entra; si no (o con [box],
  /// lo que el filtro oculta), a Objetos sin recoger. Nunca se descarta:
  /// el loot recién tirado trae el uid provisorio (`nuevo`) y los uid de
  /// distintos personajes se repiten, así que un uid que ya está en el
  /// alijo o en la caja se renombra en vez de tomarse como duplicado
  /// (loot.md § 4b.1). [toBox] dice dónde quedó.
  static ({Stash stash, bool toBox}) recover(Stash s, LootDrop d,
      {int tab = 0, bool box = false}) {
    d = _freshUid(s, d);
    if (!box) {
      final at = store(s, d, tab: tab);
      if (at != null) return (stash: at, toBox: false);
    }
    final StashEntry? e = d.item != null
        ? StashEntry.item(d.item!)
        : d.eco != null
            ? StashEntry.eco(d.eco!)
            : d.stack?.material != null
                ? StashEntry.material(d.stack!.material!, d.count)
                : null;
    if (e == null) return (stash: s, toBox: false);
    return (stash: s.withUnclaimed([...s.unclaimed, e]), toBox: true);
  }

  /// [d] con un uid que no está en [s] (`r<n>` si el suyo ya está).
  static LootDrop _freshUid(Stash s, LootDrop d) {
    final it = d.item, eco = d.eco;
    if (it == null && eco == null) return d;
    final taken = {
      for (final c in [...s.cells, ...s.unclaimed])
        if (c != null) ...[
          if (c.item != null) c.item!.uid,
          if (c.eco != null) c.eco!.uid,
        ],
    };
    final uid = it?.uid ?? eco!.uid;
    if (!taken.contains(uid)) return d;
    var n = taken.length;
    while (taken.contains('r$n')) {
      n++;
    }
    return it != null
        ? LootDrop.item(it.copyWith(uid: 'r$n'))
        : LootDrop.eco(eco!.copyWith(uid: 'r$n'));
  }

  /// Lo de la posición [i] de Objetos sin recoger como [LootDrop].
  static LootDrop? unclaimedDrop(Stash s, int i) {
    if (i < 0 || i >= s.unclaimed.length) return null;
    final e = s.unclaimed[i];
    if (e.item != null) return LootDrop.item(e.item!);
    if (e.eco != null) return LootDrop.eco(e.eco!);
    return LootDrop.stack(StackKind.of(e.material!), e.count);
  }

  /// Saca la posición [i] de Objetos sin recoger (TOMAR ya confirmado o
  /// DESCARTAR). `null` si no existe.
  static Stash? dropUnclaimed(Stash s, int i) {
    if (i < 0 || i >= s.unclaimed.length) return null;
    return s.withUnclaimed([...s.unclaimed]..removeAt(i));
  }

  /// Saca de Objetos sin recoger lo que el host confirmó de un TOMAR
  /// ([d], pedido de la posición [i]). `null` si ya no está.
  static Stash? untakeBox(Stash s, int i, LootDrop d) {
    final uid = d.item?.uid ?? d.eco?.uid;
    if (uid != null) {
      final at = s.unclaimed
          .indexWhere((e) => e.item?.uid == uid || e.eco?.uid == uid);
      return at < 0 ? null : dropUnclaimed(s, at);
    }
    final m = d.stack?.material;
    if (m == null || i < 0 || i >= s.unclaimed.length) return null;
    final e = s.unclaimed[i];
    if (e.material != m || e.count < d.count) return null;
    final box = [...s.unclaimed];
    if (e.count > d.count) {
      box[i] = StashEntry.material(m, e.count - d.count);
    } else {
      box.removeAt(i);
    }
    return s.withUnclaimed(box);
  }

  /// TOMAR: la posición [i] de Objetos sin recoger al inventario (entera;
  /// un material, lo que entre y el resto queda).
  StashMove claim(PlayerProfile p, Stash s, int i) {
    final d = unclaimedDrop(s, i);
    if (d == null) return const StashMove.error('No está');
    if (d.stack != null) {
      final st = d.stack!;
      final n = math.min(
          d.count, InventoryRules.stackMax(st) - InventoryRules.stackCount(p, st));
      if (n <= 0) return StashMove.error('Máximo ${InventoryRules.stackMax(st)}');
      final take = LootDrop.stack(st, n);
      final next = InventoryRules.receive(p, take, markNew: false);
      if (next == null) return const StashMove.error('Inventario lleno');
      final left = d.count - n;
      final box = [...s.unclaimed];
      if (left > 0) {
        box[i] = StashEntry.material(st.material!, left);
      } else {
        box.removeAt(i);
      }
      return StashMove(next, s.withUnclaimed(box), drop: take);
    }
    final why = InventoryRules.cannotReceive(p, d);
    if (why != null) return StashMove.error(why);
    return StashMove(InventoryRules.receive(p, d, markNew: false)!,
        dropUnclaimed(s, i)!,
        drop: d);
  }

  /// Cambia de lugar dos casillas del alijo. `null` si no se puede (la
  /// pestaña ECOS solo admite endgame).
  static Stash? move(Stash s, int from, int to) {
    if (from < 0 || to < 0 || from >= Stash.size || to >= Stash.size) {
      return null;
    }
    if (from == to || s.cells[from] == null) return null;
    final a = s.cells[from], b = s.cells[to];
    if (!Stash.accepts(to, a!) || (b != null && !Stash.accepts(from, b))) {
      return null;
    }
    return s.put(from, b).put(to, a);
  }
}
