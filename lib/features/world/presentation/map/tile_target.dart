import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../app/design/ds_tokens.dart';
import 'map_themes.dart';

const _ts = 16.0;

/// The work-target marker shared by the farm and the mines (farming.md
/// § 4, mining_smithing.md § 1.9): a 1 px box on each tile the next E /
/// click touches, green when the tool works there and orange when not.
/// With [progress] (0..1) a thin bar along the bottom of the tile fills
/// toward the moment the work is done (a rock breaking).
void drawTileTarget(Canvas c, Iterable<(int, int)> tiles, bool ok,
    {double? progress}) {
  final col = ok ? FarmPalette.targetOk : FarmPalette.targetBad;
  final line = Paint()
    ..color = col
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final fill = Paint();
  for (final (x, y) in tiles) {
    final px = x * _ts, py = y * _ts;
    c.drawRect(Rect.fromLTWH(px + 0.5, py + 0.5, _ts - 1, _ts - 1), line);
    if (progress == null) continue;
    final k = progress.clamp(0.0, 1.0);
    c.drawRect(Rect.fromLTWH(px + 2, py + _ts - 4, _ts - 4, 2),
        fill..color = TargetPalette.barBack);
    final w = ((_ts - 4) * k).roundToDouble();
    if (w > 0) {
      c.drawRect(Rect.fromLTWH(px + 2, py + _ts - 4, w, 2), fill..color = col);
    }
  }
}

final _outlinePaint = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = const ColorFilter.mode(DsColors.targetOutline, BlendMode.srcIn);

/// The selected NPC (controls.md § Cursor de acción): its silhouette
/// drawn white 1 px off in the 4 directions, behind the sprite drawn
/// right after at [dst]. NPCs get this instead of the tile cursor.
void drawSpriteOutline(Canvas c, ui.Image im, Rect dst) {
  final src = Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble());
  for (final o in const [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
  ]) {
    c.drawImageRect(im, src, dst.shift(o), _outlinePaint);
  }
}
