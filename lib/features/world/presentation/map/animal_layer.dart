import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/animal_rules.dart';
import '../../../../game_engine/rules/autotile.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import 'tile_target.dart';

/// Coops and barns on the town map (docs/specs/animals.md § 3–4): the
/// fence of the yard (the town's autotile fence pieces), the house, the
/// animals strolling the pasture by day (asleep inside at night) and the
/// products waiting to be collected. Every sprite comes from the manifest
/// through [sprite] (`items.vida_<id>`); positions come from the room
/// clock, so every peer sees the same.
class AnimalLayer {
  static const ts = 16.0;

  void draw(Canvas c, TownState town, double time, double t,
      ui.Image? Function(String id) sprite,
      {required bool asleep,
      void Function(String text, double x, double y, Color color, double size)?
          text,
      ({String build, int uid})? hover,
      String? selectedHouse,
      ({String build, int uid})? selectedAnimal}) {
    final (ox, oy) = town.origin;
    final paint = SpriteCatalog.pixelPaint();
    void img(ui.Image im, double left, double top,
        {bool flip = false, double scale = 1, bool outline = false}) {
      final w = im.width * scale, h = im.height * scale;
      final dst = Rect.fromLTWH(left.roundToDouble(), top.roundToDouble(), w, h);
      if (flip) {
        c.save();
        c.translate(dst.center.dx * 2, 0);
        c.scale(-1, 1);
      }
      // The E / click target: white 1 px silhouette (controls.md).
      if (outline) drawSpriteOutline(c, im, dst);
      c.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(),
          im.height.toDouble()), dst, paint);
      if (flip) c.restore();
    }

    for (final b in town.builds) {
      if (!b.kind.ranch) continue;
      final home = AnimalRules.homeOf(b)!;
      // Fence around the yard, with the gate at the bottom.
      final fence = AnimalRules.fenceTiles(b);
      final gate = AnimalRules.gateOf(b);
      final all = {...fence, gate};
      for (final (x, y) in fence) {
        final m = Autotile.mask4((dx, dy) => all.contains((x + dx, y + dy)));
        if (sprite('decor_fence_$m') case final im?) {
          img(im, (x + ox) * ts, (y + oy) * ts);
        }
      }
      if (sprite('decor_fence_gate_h') case final im?) {
        img(im, (gate.$1 + ox) * ts, (gate.$2 + oy) * ts);
      }
      // The house, bottom-aligned on its rectangle.
      final house = AnimalRules.houseOf(b);
      if (sprite(home.sprite) case final im?) {
        img(im, (house.x + ox + house.w / 2) * ts - im.width / 2,
            (house.bottom + oy) * ts - im.height,
            outline: selectedHouse == b.id);
      }
      if (asleep) {
        if (b.animals.isNotEmpty && text != null) {
          final z = (t / 600).floor() % 3;
          text('z' * (z + 1), (house.right + ox) * ts - 4,
              (house.y + oy) * ts + 4, const Color(0xFFE8E0FF), 6);
        }
        continue;
      }
      for (final a in b.animals) {
        // Products on the floor (eggs) wait at the nest.
        if (a.ready != null && a.def.tool == null) {
          final (nx, ny) = AnimalRules.nestOf(b, a);
          if (sprite(a.def.productDef.sprite) case final im?) {
            img(im, (nx + ox) * ts + 3, (ny + oy) * ts + 4, scale: 0.6);
          }
        }
      }
      for (final a in b.animals) {
        final pos = AnimalRules.animalPos(b, a, time);
        final step = pos.walk && (t ~/ 160).isOdd;
        final im = sprite(step ? '${a.def.sprite}_b' : a.def.sprite) ??
            sprite(a.def.sprite);
        final cx = (pos.x + ox) * ts, bottom = (pos.y + oy) * ts + 6;
        if (im != null) {
          final bob = pos.walk ? 0.0 : (math.sin(t / 400 + a.uid) > 0.8 ? 1.0 : 0.0);
          img(im, cx - im.width / 2, bottom - im.height + bob,
              flip: pos.dx < 0,
              outline: selectedAnimal != null &&
                  selectedAnimal.build == b.id &&
                  selectedAnimal.uid == a.uid);
          if (hover != null && hover.build == b.id && hover.uid == a.uid) {
            c.drawRect(
                Rect.fromLTWH(cx - im.width / 2 - 1, bottom - im.height - 1,
                    im.width + 2.0, im.height + 2.0),
                Paint()
                  ..color = const Color(0xFFFFE9A8)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1);
          }
          // Milk / wool ready: a small bubble with the product.
          if (a.ready != null && a.def.tool != null) {
            final top = bottom - im.height - 9 + (math.sin(t / 300) * 1).roundToDouble();
            c.drawRect(Rect.fromLTWH(cx - 5, top - 1, 10, 10),
                Paint()..color = const Color(0xCC1A1420));
            if (sprite(a.def.productDef.sprite) case final pi?) {
              img(pi, cx - 4, top, scale: 0.5);
            }
          }
        }
      }
    }
  }
}
