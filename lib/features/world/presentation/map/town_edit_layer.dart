import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:material_ui/material_ui.dart';
import '../../../../app/design/design.dart' show DsColors;
import '../../../../game_engine/data/cozy_catalog.dart' show kFarmDecos;

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

  /// Dibuja el contorno de la unión de [parts] (coordenadas del pueblo),
  /// corrido [inset] px hacia adentro.
  static void _outline(
      Canvas c, List<TownRect> parts, int ox, int oy, Paint line,
      {double inset = 0.5}) {
    bool inside(int x, int y) => parts.any((p) => p.contains(x, y));
    for (final (x0, y0, x1, y1) in TownRect.outline(parts)) {
      // El lado de adentro del segmento define hacia dónde se corre.
      final horiz = y0 == y1;
      final double dx, dy;
      if (horiz) {
        dx = 0;
        dy = inside(x0, y0) ? inset : -inset;
      } else {
        dy = 0;
        dx = inside(x0, y0) ? inset : -inset;
      }
      c.drawLine(Offset((x0 + ox) * ts + dx, (y0 + oy) * ts + dy),
          Offset((x1 + ox) * ts + dx, (y1 + oy) * ts + dy), line);
    }
  }

  /// Cursor feedback of the MOVER / BORRAR / CAMINOS tools (§ 1.7): the
  /// piece under the mouse outlined in gold (MOVER) or filled in the
  /// danger colour (BORRAR); the brush tile green or red (CAMINOS).
  static void _drawTool(Canvas c, SessionController ctl, TownEdit e, int ox,
      int oy, Paint fill, Paint line) {
    if (e.pick != null || e.step != TownEditStep.browse) return;
    final t = e.hoverTile;
    if (t == null) return;
    final town = ctl.town;
    final danger = e.mode == TownEditMode.erase;
    void mark(Rect r) {
      c.drawRect(
          r,
          fill
            ..color = danger
                ? DsColors.danger.withValues(alpha: 0.45)
                : TownEditPalette.valid);
      c.drawRect(
          r.deflate(0.5),
          line
            ..color = danger ? DsColors.danger : TownEditPalette.selected
            ..strokeWidth = 1.5);
      line.strokeWidth = 1;
    }

    switch (e.mode) {
      case TownEditMode.paths:
        final erase = e.pathErase || HardwareKeyboard.instance.isShiftPressed;
        final bad = ctl.pathBrushError(t.$1, t.$2, erase: erase) != null;
        final r = Rect.fromLTWH(t.$1 * ts, t.$2 * ts, ts, ts);
        c.drawRect(
            r,
            fill
              ..color = bad
                  ? TownEditPalette.invalid
                  : erase
                      ? DsColors.danger.withValues(alpha: 0.45)
                      : TownEditPalette.valid);
        c.drawRect(
            r.deflate(0.5),
            line
              ..color =
                  bad ? TownEditPalette.invalidBorder : TownEditPalette.validBorder);
      case TownEditMode.move || TownEditMode.erase:
        final id = ctl.editHoverTarget;
        if (id == null) {
          // BORRAR over a hand-drawn path: that tile.
          if (danger && town.paths.containsKey((t.$1 - ox, t.$2 - oy))) {
            mark(Rect.fromLTWH(t.$1 * ts, t.$2 * ts, ts, ts));
          }
          return;
        }
        if (TownState.parseLightId(id) ?? TownState.parseDecorId(id)
            case (final x, final y)?) {
          mark(Rect.fromLTWH((x + ox) * ts, (y + oy) * ts, ts, ts));
          return;
        }
        if (town.build(id) case final b?) {
          for (final p in b.parts) {
            mark(Rect.fromLTWH(
                (p.x + ox) * ts, (p.y + oy) * ts, p.w * ts, p.h * ts));
          }
          return;
        }
        for (final l in TownPlan.landmarksOf(town)) {
          if (l.id != id) continue;
          mark(Rect.fromLTWH(
              (l.x + ox) * ts, (l.y + oy) * ts, l.w * ts, l.h * ts));
        }
      case TownEditMode.build:
        return;
    }
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
    // Elegir la casa de un habitante (overworld_biomes.md § 10.1): igual,
    // con las CASAS libres resaltadas.
    if (e.pick case final kind?) {
      for (final b in town.builds) {
        if (b.kind != kind) continue;
        final ok = ctl.pickWhy(b) == null;
        final hot =
            ok && (b.id == e.hoverBuild || b.id == e.selected);
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
      // Contorno de la unión: una huerta o lago fundido se ve como uno.
      _outline(c, b.parts, ox, oy, line);
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
    _drawTool(c, ctl, e, ox, oy, fill, line);
    final g = e.ghost;
    if (g == null) return;
    final List<TownRect> parts;
    if (e.step == TownEditStep.placing &&
            (e.placeDef == kFaroId || kFarmDecos.containsKey(e.placeDef)) ||
        e.step == TownEditStep.moving &&
            (TownState.parseLightId(e.selected) != null ||
                TownState.parseDecorId(e.selected) != null)) {
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
    // MOVER: the auto paths the town would lay with the piece there
    // (town_editor.md § 1.7), in gold over the map.
    if (ok && e.step == TownEditStep.moving) {
      final moved = TownState.parseLightId(e.selected) != null ||
              TownState.parseDecorId(e.selected) != null
          ? null
          : TownRules.move(town, e.selected!, g.$1, g.$2).town;
      if (moved != null) {
        final plan = TownPlan.of(moved);
        fill.color = TownEditPalette.route;
        for (final (x, y) in plan.routed) {
          c.drawRect(Rect.fromLTWH(x * ts, y * ts, ts, ts).deflate(2), fill);
        }
      }
    }
    // Vista previa de la fusión: si al soltar se funde con otra huerta o
    // lago, se marca el contorno del resultado (town_editor.md § 4.2).
    if (ok && (e.step == TownEditStep.placing || e.step == TownEditStep.moving)) {
      final r = e.step == TownEditStep.placing
          ? TownRules.place(town, e.placeDef!, g.$1, g.$2)
          : TownRules.move(town, e.selected!, g.$1, g.$2);
      final m = r.id == null ? null : r.town?.build(r.id!);
      if (m != null && m.parts.length > parts.length) {
        _outline(c, m.parts, ox, oy, line..color = TownEditPalette.selected,
            inset: -1.5);
      }
    }
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
