/// Shared walk/work motion of every hired helper (farmers, ranch hands,
/// miners): a helper moves from tile [a] to tile [z] over one cycle and
/// works the rest of it. Positions are in tiles (fractional while
/// walking). Pure and deterministic, so every client draws the same.
abstract final class HelperMotion {
  /// Share of a cycle spent working (the rest is walking).
  static const workShare = 0.6;

  /// Linear position between [a] and [z] at walk progress [m] (0..1).
  static ({double x, double y}) lerp((num, num) a, (num, num) z, double m) {
    final k = m.clamp(0.0, 1.0);
    return (x: a.$1 + (z.$1 - a.$1) * k, y: a.$2 + (z.$2 - a.$2) * k);
  }

  /// Works on [a] first ([workShare] of the cycle), then walks to [z].
  /// [f]: cycle progress 0..1. Farmers and ranch hands.
  static ({double x, double y, bool work}) workThenWalk(
      (num, num) a, (num, num) z, double f) {
    final m = f < workShare ? 0.0 : (f - workShare) / (1 - workShare);
    final p = lerp(a, z, m);
    return (x: p.x, y: p.y, work: f < workShare);
  }

  /// Walks from [a] to [z] first, then works on [z]. [f]: cycle progress
  /// 0..1. Miners (each host step moves them one tile, then they dig).
  static ({double x, double y, bool work}) walkThenWork(
      (num, num) a, (num, num) z, double f) {
    const walk = 1 - workShare;
    final p = lerp(a, z, f / walk);
    return (x: p.x, y: p.y, work: f >= walk);
  }
}
