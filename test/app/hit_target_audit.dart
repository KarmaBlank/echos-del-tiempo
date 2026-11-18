import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Tamaño mínimo de un objetivo clicable a texto Normal (px lógicos;
/// docs/specs/accessibility.md § "Objetivos clicables").
const kMinHitSize = 24.0;

/// Los objetivos clicables visibles de la pantalla que miden menos de
/// [min] en alguna dirección: `descripción (ancho×alto)`. Cuenta botones
/// habilitados, `GestureDetector` / `InkWell` con toque y `Slider`.
List<String> smallHitTargets(WidgetTester tester, {double min = kMinHitSize}) {
  bool tappable(Widget w) => switch (w) {
        ButtonStyleButton(:final onPressed) => onPressed != null,
        GestureDetector(:final onTap, :final onTapUp, :final onTapDown) =>
          onTap != null || onTapUp != null || onTapDown != null,
        InkWell(:final onTap) => onTap != null,
        Slider() => true,
        _ => false,
      };
  final out = <String>[];
  final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final e in find.byWidgetPredicate(tappable).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.hasSize || !ro.attached) continue;
    final r = ro.localToGlobal(Offset.zero) & ro.size;
    if (!screen.overlaps(r)) continue; // fuera de la vista (scroll)
    if (ro.size.width + 0.01 < min || ro.size.height + 0.01 < min) {
      final w = e.widget;
      // La clave más cercana (el detector suele no tenerla).
      Key? key = w.key is ValueKey ? w.key : null;
      var up = 0;
      if (key == null) {
        e.visitAncestorElements((a) {
          if (a.widget.key is ValueKey) {
            key = a.widget.key;
            return false;
          }
          return ++up < 8;
        });
      }
      out.add('${w.runtimeType}${key == null ? '' : ' $key'} '
          '(${ro.size.width.toStringAsFixed(0)}×${ro.size.height.toStringAsFixed(0)})');
    }
  }
  if (debugAudit) {
    // ignore: avoid_print
    print('auditados: ${find.byWidgetPredicate(tappable).evaluate().length}');
  }
  return out;
}

bool debugAudit = false;
