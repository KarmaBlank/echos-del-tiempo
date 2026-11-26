import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/path_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/path_rules.dart';
import '../../../../game_engine/rules/town_plan.dart';
import '../../../combat/presentation/sprite_catalog.dart';

/// Hand-drawn town paths (town_editor.md § 4.6): one autotiled piece per
/// tile and material (`items.vida_path_<id>_<mask>`), drawn over the base
/// path tile and the tier dressing. Tiles hidden under a building are
/// not in `TownPlan.hand`, so they don't show.
abstract final class PathLayer {
  static const ts = 16.0;

  static void draw(Canvas c, TownState town, Rect view,
      ui.Image? Function(String id) icon) {
    if (town.paths.isEmpty) return;
    final plan = TownPlan.of(town);
    for (final MapEntry(key: (x, y), value: id) in plan.hand.entries) {
      final px = x * ts, py = y * ts;
      if (!view.inflate(ts).contains(Offset(px, py))) continue;
      final d = townPath(id);
      final im = d == null ? null : icon(d.sprite(PathRules.mask(plan, x, y)));
      if (im == null) continue;
      c.drawImageRect(
          im,
          Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
          Rect.fromLTWH(px, py, ts, ts),
          SpriteCatalog.pixelPaint());
    }
  }
}
