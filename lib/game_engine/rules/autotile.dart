/// Four-neighbour autotiling (docs/specs/town_editor.md § Cercos): a
/// piece picks its look from which of its N / E / S / W neighbours are
/// of the same kind. Pure Dart, shared by every connecting piece.
abstract final class Autotile {
  static const n = 1, e = 2, s = 4, w = 8;

  /// Bit mask of the same-kind neighbours; [same] gets the offset.
  static int mask4(bool Function(int dx, int dy) same) =>
      (same(0, -1) ? n : 0) |
      (same(1, 0) ? e : 0) |
      (same(0, 1) ? s : 0) |
      (same(-1, 0) ? w : 0);

  /// Shape of [mask]: how many arms and whether they line up.
  static AutotileShape shape(int mask) {
    final arms = [n, e, s, w].where((b) => mask & b != 0).length;
    return switch (arms) {
      0 => AutotileShape.post,
      1 => AutotileShape.end,
      2 => mask == (n | s) || mask == (e | w)
          ? AutotileShape.straight
          : AutotileShape.corner,
      3 => AutotileShape.tee,
      _ => AutotileShape.cross,
    };
  }
}

enum AutotileShape { post, end, straight, corner, tee, cross }
