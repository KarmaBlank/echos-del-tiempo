import 'dart:math' as math;

import 'layout_doc.dart';
import 'layout_spec.dart';

/// Un problema del layout. Los errores impiden guardar y publicar
/// (§ 2.5.3); los avisos no.
class LayoutIssue {
  const LayoutIssue(this.message,
      {this.slot, this.where, this.error = true});
  final String message;
  final String? slot;

  /// Dónde se vio (p. ej. `1280x720 · 150 %` o `narrow`).
  final String? where;
  final bool error;

  @override
  String toString() =>
      '${error ? 'ERROR' : 'AVISO'}${where == null ? '' : ' [$where]'}'
      '${slot == null ? '' : ' $slot'}: $message';
}

/// Rectángulo simple (Dart puro; el editor y los tests pasan los de
/// los `RenderBox`).
class LayoutRect {
  const LayoutRect(this.left, this.top, this.width, this.height);
  final double left, top, width, height;
  double get right => left + width;
  double get bottom => top + height;

  bool overlaps(LayoutRect o, {double eps = 0.5}) =>
      left < o.right - eps &&
      o.left < right - eps &&
      top < o.bottom - eps &&
      o.top < bottom - eps;

  bool inside(LayoutRect o, {double eps = 0.5}) =>
      left >= o.left - eps &&
      top >= o.top - eps &&
      right <= o.right + eps &&
      bottom <= o.bottom + eps;

  @override
  String toString() =>
      '(${left.toStringAsFixed(0)},${top.toStringAsFixed(0)} '
      '${width.toStringAsFixed(0)}×${height.toStringAsFixed(0)})';
}

/// Validador del layout (§ 2.5). Dart puro.
abstract final class LayoutValidator {
  /// Objetivo de clic mínimo (accessibility.md).
  static const minTarget = 32.0;

  /// 1. Estático: ids, duplicados, regiones, `allowedRegions`, fijos en
  /// su lugar, ocultar solo lo `hideable`, sin ciclos de grupos.
  static List<LayoutIssue> validateStatic(
      LayoutDoc doc, LayoutScreenSpec spec) {
    final out = <LayoutIssue>[];
    if (doc.screen != spec.screen) {
      out.add(LayoutIssue(
          'El archivo es de "${doc.screen}", no de "${spec.screen}"'));
    }
    final seen = <String>{};
    final containers = spec.containers;
    for (final p in doc.slots) {
      final s = spec.slots[p.id];
      if (s == null) {
        out.add(LayoutIssue('Slot desconocido', slot: p.id));
        continue;
      }
      if (!seen.add(p.id)) {
        out.add(LayoutIssue('Slot repetido', slot: p.id));
      }
      if (!containers.contains(p.region)) {
        out.add(LayoutIssue('Región desconocida "${p.region}"', slot: p.id));
      } else if (!spec.allows(p.id, p.region)) {
        out.add(LayoutIssue(
            s.movable
                ? 'No puede ir en "${p.region}"'
                : 'Es fijo: no se puede mover',
            slot: p.id));
      }
      _hide(out, s, p.rule, null);
    }
    for (final id in spec.slots.keys) {
      if (!seen.contains(id)) out.add(LayoutIssue('Falta en el layout', slot: id));
    }
    // Ciclos: un grupo dentro de sí mismo (directo o indirecto).
    final parent = {for (final p in doc.slots) p.id: p.region};
    for (final id in parent.keys) {
      var cur = parent[id];
      for (var i = 0; cur != null && i <= parent.length; i++) {
        if (cur == id) {
          out.add(LayoutIssue('Grupo dentro de sí mismo', slot: id));
          break;
        }
        cur = parent[cur];
      }
    }
    for (final MapEntry(key: bp, value: rules) in doc.breakpoints.entries) {
      for (final MapEntry(key: id, value: r) in rules.entries) {
        final s = spec.slots[id];
        if (s == null) {
          out.add(LayoutIssue('Slot desconocido', slot: id, where: bp.name));
          continue;
        }
        if (r.region case final region?) {
          if (!containers.contains(region)) {
            out.add(LayoutIssue('Región desconocida "$region"',
                slot: id, where: bp.name));
          } else if (!spec.allows(id, region)) {
            out.add(LayoutIssue(
                s.movable
                    ? 'No puede ir en "$region"'
                    : 'Es fijo: no se puede mover',
                slot: id,
                where: bp.name));
          }
        } else if (r.order != null && !s.movable) {
          out.add(LayoutIssue('Es fijo: no se puede reordenar',
              slot: id, where: bp.name));
        }
        _hide(out, s, r, bp.name);
      }
    }
    // Un grupo no queda vacío (avisa: se ve como hueco).
    for (final bp in [null, ...LayoutBreakpoint.values]) {
      final res = doc.resolve(bp);
      for (final s in spec.slots.values) {
        if (s.group && res.containerOf(s.id) != null && res.of(s.id).isEmpty) {
          out.add(LayoutIssue('Grupo vacío',
              slot: s.id, where: bp?.name, error: false));
        }
      }
    }
    return out;
  }

  static void _hide(
      List<LayoutIssue> out, LayoutSlotSpec s, SlotRule r, String? where) {
    if (r.hide == true && !s.hideable) {
      out.add(LayoutIssue('No se puede ocultar (acción única u obligatorio)',
          slot: s.id, where: where));
    }
  }

  /// 2. Geométrico, con los rectángulos medidos de una pantalla ya
  /// renderizada en un tamaño de ventana y de texto ([where]):
  /// nada fuera de [viewport], sin solapes entre hermanos ([siblings]),
  /// objetivos de clic ≥ [minTarget] ([targets]: slot → rects de sus
  /// botones) y orden de foco = orden visual ([focusGroups]: por
  /// contenedor, los ids en el orden de recorrido del foco). Los desbordes (`RenderFlex
  /// overflowed`) los informa quien renderiza ([overflows]).
  static List<LayoutIssue> validateGeometry({
    required String where,
    required LayoutRect viewport,
    required Map<String, LayoutRect> slots,
    List<List<String>> siblings = const [],
    Map<String, List<LayoutRect>> targets = const {},
    List<List<String>> focusGroups = const [],
    List<String> overflows = const [],
  }) {
    final out = <LayoutIssue>[
      for (final o in overflows) LayoutIssue('Desborde: $o', where: where),
    ];
    for (final MapEntry(key: id, value: r) in slots.entries) {
      if (r.width <= 0 && r.height <= 0) continue;
      if (!r.inside(viewport)) {
        out.add(LayoutIssue('Fuera de la ventana $r', slot: id, where: where));
      }
    }
    for (final group in siblings) {
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          final a = slots[group[i]], b = slots[group[j]];
          if (a == null || b == null) continue;
          if (a.width <= 0 || b.width <= 0) continue;
          if (a.overlaps(b)) {
            out.add(LayoutIssue('Se solapa con ${group[j]}',
                slot: group[i], where: where));
          }
        }
      }
    }
    for (final MapEntry(key: id, value: rects) in targets.entries) {
      for (final r in rects) {
        if (r.width + 0.01 < minTarget || r.height + 0.01 < minTarget) {
          out.add(LayoutIssue(
              'Objetivo de clic chico ${r.width.toStringAsFixed(0)}×'
              '${r.height.toStringAsFixed(0)} (mín. ${minTarget.toInt()})',
              slot: id,
              where: where));
        }
      }
    }
    for (final group in focusGroups) {
      final focus = [for (final id in group) if (slots.containsKey(id)) id];
      final visual = readingOrder({for (final id in focus) id: slots[id]!});
      for (var i = 0; i < focus.length; i++) {
        if (focus[i] != visual[i]) {
          out.add(LayoutIssue(
              'Orden de foco distinto del visual (va ${focus[i]}, se ve '
              '${visual[i]})',
              slot: focus[i],
              where: where));
          break;
        }
      }
    }
    return out;
  }

  /// Orden de lectura: arriba→abajo por filas (dos rectángulos están en
  /// la misma fila si se solapan en vertical) y en cada fila izq→der.
  static List<String> readingOrder(Map<String, LayoutRect> rects) {
    final ids = rects.keys.toList()
      ..sort((a, b) => rects[a]!.top.compareTo(rects[b]!.top));
    final rows = <List<String>>[];
    double rowBottom = -double.infinity;
    for (final id in ids) {
      final r = rects[id]!;
      if (rows.isEmpty || r.top >= rowBottom - 0.5) {
        rows.add([id]);
        rowBottom = r.bottom;
      } else {
        rows.last.add(id);
        rowBottom = math.max(rowBottom, r.bottom);
      }
    }
    return [
      for (final row in rows)
        ...(row..sort((a, b) => rects[a]!.left.compareTo(rects[b]!.left))),
    ];
  }
}
