import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/construction_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/town_plan.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import 'farm_layer.dart' show MapText;
import 'map_themes.dart';

/// Lo que se dibuja encima del pueblo en la edición (town_editor.md §
/// 1.3): franjas fantasma de cada lado con su costo, contornos de las
/// construcciones y el fantasma de lo que se mueve o se pone (verde si
/// entra, rojo si no). Colores en [TownEditPalette].
abstract final class TownEditLayer {
  static const ts = 16.0;

  /// La franja fantasma de [side] en px del mundo para un mapa de
  /// [w] × [h] px.
  static Rect stripRect(TownSide side, double w, double h) {
    const s = kTownStrip * ts;
    return switch (side) {
      TownSide.norte => Rect.fromLTWH(0, -s, w, s),
      TownSide.sur => Rect.fromLTWH(0, h, w, s),
      TownSide.oeste => Rect.fromLTWH(-s, 0, s, h),
      TownSide.este => Rect.fromLTWH(w, 0, s, h),
    };
  }

  /// [view]: lo visible del mundo (px); la etiqueta de cada franja va en
  /// el centro de su parte visible.
  static void draw(Canvas c, SessionController ctl, GameMap map, MapText text,
      {Rect? view}) {
    final e = ctl.townEdit;
    if (e == null) return;
    final town = ctl.town;
    final (ox, oy) = town.origin;
    final fill = Paint();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final w = map.width * ts, h = map.height * ts;
    // Elegir dónde contratar (farming.md § 8): solo las huertas o los
    // lagos, dorados si se puede contratar, grises si no.
    if (e.hire case final kind?) {
      for (final b in town.builds) {
        if (b.kind != kind) continue;
        final ok = ctl.hireWhy(b) == null;
        final hot = ok && b.id == e.hoverBuild;
        for (final p in b.parts) {
          final r = Rect.fromLTWH(
              (p.x + ox) * ts, (p.y + oy) * ts, p.w * ts, p.h * ts);
          c.drawRect(
              r, fill..color = ok ? TownEditPalette.valid : TownEditPalette.sideFull);
          c.drawRect(
              r.deflate(0.5),
              line
                ..color = hot
                    ? TownEditPalette.selected
                    : ok
                        ? TownEditPalette.validBorder
                        : TownEditPalette.sideLocked);
        }
      }
      return;
    }
    for (final side in TownSide.values) {
      final full = TownRules.sideFull(town, side) != null;
      final r = stripRect(side, w, h);
      final picked = e.side == side;
      c.drawRect(
          r, fill..color = full ? TownEditPalette.sideFull : TownEditPalette.side);
      c.drawRect(
          r.deflate(0.5),
          line
            ..color = full
                ? TownEditPalette.sideLocked
                : picked
                    ? TownEditPalette.selected
                    : TownEditPalette.sideBorder);
      // El texto (AMPLIAR y el costo) va en px de pantalla, en
      // `TownStripCards` (town_editor.md § 1.3).
    }
    for (final b in town.builds) {
      final sel = b.id == e.selected;
      line.color = sel ? TownEditPalette.selected : TownEditPalette.outline;
      for (final p in b.parts) {
        c.drawRect(
            Rect.fromLTWH((p.x + ox) * ts, (p.y + oy) * ts, p.w * ts, p.h * ts)
                .deflate(0.5),
            line);
      }
    }
    // Faros (day_night_weather.md § 5).
    for (final f in town.lights) {
      line.color = TownState.lightId(f) == e.selected
          ? TownEditPalette.selected
          : TownEditPalette.outline;
      c.drawRect(
          Rect.fromLTWH((f.$1 + ox) * ts, (f.$2 + oy) * ts, ts, ts).deflate(0.5),
          line);
    }
    // Lugares fijos: también se pueden mover (town_editor.md § 3.3).
    for (final l in TownPlan.landmarksOf(town)) {
      line.color = l.id == e.selected
          ? TownEditPalette.selected
          : TownEditPalette.outline;
      c.drawRect(
          Rect.fromLTWH((l.x + ox) * ts, (l.y + oy) * ts, l.w * ts, l.h * ts)
              .deflate(0.5),
          line);
    }
    if (e.tile case (final tx, final ty)? when e.step == TownEditStep.choose) {
      c.drawRect(Rect.fromLTWH(tx * ts, ty * ts, ts, ts).deflate(0.5),
          line..color = TownEditPalette.selected);
    }
    final g = e.ghost;
    if (g == null) return;
    final List<TownRect> parts;
    if (e.step == TownEditStep.placing && e.placeDef == kFaroId ||
        e.step == TownEditStep.moving &&
            TownState.parseLightId(e.selected) != null) {
      parts = [TownRect(g.$1, g.$2, 1, 1)];
    } else if (e.step == TownEditStep.placing) {
      final d = construction(e.placeDef ?? '');
      if (d == null) return;
      parts = [TownRect(g.$1, g.$2, d.w, d.h)];
    } else if (e.step == TownEditStep.moving) {
      final b = ctl.editSelected;
      final l = ctl.editLandmark;
      if (l != null) {
        parts = [TownRect(g.$1, g.$2, l.w, l.h)];
      } else if (b == null) {
        return;
      } else {
        final m = b.movedTo(g.$1 - ox, g.$2 - oy);
        parts = [for (final p in m.parts) p.shift(ox, oy)];
      }
    } else {
      return;
    }
    final ok = ctl.editGhostError == null;
    for (final p in parts) {
      final r = Rect.fromLTWH(p.x * ts, p.y * ts, p.w * ts, p.h * ts);
      c.drawRect(r,
          fill..color = ok ? TownEditPalette.valid : TownEditPalette.invalid);
      c.drawRect(
          r.deflate(0.5),
          line
            ..color = ok
                ? TownEditPalette.validBorder
                : TownEditPalette.invalidBorder);
    }
  }
}
