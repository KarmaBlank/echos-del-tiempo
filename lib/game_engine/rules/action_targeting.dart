/// One rule for "what does E / the click act on" (controls.md § Cursor
/// de acción): the prompt, the tile cursor and the input all read the
/// same selection, so what the cursor marks is what E does.
library;

/// What kind of thing a target is. Drawing: ground work targets (trees,
/// bushes, plots, rocks) get the tile cursor; everything else a 1 px
/// white outline around its silhouette ([ActionTarget.outline]).
enum ActionTargetKind {
  tree,
  forage,
  plot,
  rock,
  find,
  npc,
  chest,
  shrine,
  waystone,
  portal,
  mine,
  station,
  sign,
  fountain,
  shop,
  dock,
  travel,

  /// A farm animal, its egg on the ground or its coop / barn house
  /// (animals.md § 4.2): the tile cursor, never the outline.
  animal,
}

/// Something next to the player that E / a click can act on.
class ActionTarget {
  const ActionTarget(this.x, this.y, this.kind,
      {this.ok = true, this.id = 0, this.key = '', bool? outline})
      : outline = outline ??
            !(kind == ActionTargetKind.tree ||
                kind == ActionTargetKind.forage ||
                kind == ActionTargetKind.plot ||
                kind == ActionTargetKind.rock);

  /// Ground work targets (tool actions): the only ones with the tile
  /// cursor; everything else is outlined.
  static const groundKinds = {
    ActionTargetKind.tree,
    ActionTargetKind.forage,
    ActionTargetKind.plot,
    ActionTargetKind.rock,
  };

  /// Tile.
  final int x, y;
  final ActionTargetKind kind;

  /// The action can happen now (green); `false` = blocked (orange).
  final bool ok;

  /// Index / key of the thing (bush index, NPC order…).
  final int id;

  /// String key of the thing (NPC id, event uid, build id…).
  final String key;

  /// Drawn with the white sprite outline instead of the tile cursor.
  final bool outline;

  (int, int) get tile => (x, y);

  @override
  bool operator ==(Object other) =>
      other is ActionTarget &&
      other.x == x &&
      other.y == y &&
      other.kind == kind &&
      other.ok == ok &&
      other.id == id &&
      other.key == key &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(x, y, kind, ok, id, key, outline);

  @override
  String toString() => 'ActionTarget($x, $y, ${kind.name}, ok: $ok)';
}

/// Cursor colour.
enum CursorTone { none, ok, blocked }

abstract final class ActionTargeting {
  /// Reach in tiles around the player's tile (the 8 neighbours + own).
  static const defaultReach = 1;

  static bool inReach(int px, int py, int x, int y,
          {int reach = defaultReach}) =>
      (x - px).abs() <= reach && (y - py).abs() <= reach;

  /// A tile picked with the mouse and kept while the button is held
  /// ([aim]) still counts only while it is in reach of the player's tile
  /// and is not that tile; otherwise `null`, so the selection re-runs
  /// (hover, WASD direction, nearest). A held click never keeps working a
  /// tile the player walked away from (controls.md § Cursor de acción).
  static (int, int)? heldAim(int px, int py, (int, int)? aim,
      {int reach = defaultReach}) {
    if (aim case (final ax, final ay)
        when (ax, ay) != (px, py) &&
            inReach(px, py, ax, ay, reach: reach)) {
      return aim;
    }
    return null;
  }

  /// The neighbour offset of a facing / last-move vector: the dominant
  /// axis wins (ties go horizontal); no direction = down.
  static (int, int) facingStep(num fx, num fy) {
    if (fx == 0 && fy == 0) return (0, 1);
    return fx.abs() >= fy.abs()
        ? (fx.sign.toInt(), 0)
        : (0, fy.sign.toInt());
  }

  /// Picks the target among [candidates] (the player stands on
  /// ([px], [py])):
  /// 1. the one under [hover] (mouse), when in reach;
  /// 2. the one in the [facing] neighbour (last WASD direction);
  /// 3. the nearest — possible ones first, then distance, then y, x.
  /// [skip] drops tiles already worked in a hold, so a held E moves on to
  /// the next one.
  static ActionTarget? select({
    required int px,
    required int py,
    required Iterable<ActionTarget> candidates,
    (int, int)? hover,
    (int, int) facing = (0, 1),
    Set<(int, int)> skip = const {},
    int reach = defaultReach,
  }) {
    final list = [
      for (final c in candidates)
        if (inReach(px, py, c.x, c.y, reach: reach) && !skip.contains(c.tile))
          c
    ];
    if (list.isEmpty) return null;
    if (hover case (final hx, final hy)
        when inReach(px, py, hx, hy, reach: reach)) {
      for (final c in list) {
        if (c.x == hx && c.y == hy) return c;
      }
    }
    final (fx, fy) = facing;
    final ahead = (px + fx, py + fy);
    ActionTarget? front;
    for (final c in list) {
      if (c.tile == ahead && (front == null || (c.ok && !front.ok))) front = c;
    }
    if (front != null) return front;
    list.sort((a, b) {
      if (a.ok != b.ok) return a.ok ? -1 : 1;
      final da = _d2(a, px, py), db = _d2(b, px, py);
      if (da != db) return da.compareTo(db);
      if (a.y != b.y) return a.y.compareTo(b.y);
      return a.x.compareTo(b.x);
    });
    return list.first;
  }

  static int _d2(ActionTarget a, int px, int py) =>
      (a.x - px) * (a.x - px) + (a.y - py) * (a.y - py);

  /// Cursor colour for [t]: none (no target / an NPC, which is outlined
  /// instead), green or orange.
  static CursorTone tone(ActionTarget? t) => t == null || t.outline
      ? CursorTone.none
      : t.ok
          ? CursorTone.ok
          : CursorTone.blocked;
}
