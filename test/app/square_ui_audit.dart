import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Regla pixel (design_system.md § Principios, ui_style.md § "Sin
/// redondeos"): la UI no tiene formas redondeadas ni circulares.
///
/// Devuelve los widgets de UI de la pantalla con radio > 0 o forma
/// circular: `Tipo (clave más cercana)`. Lo que dibujan los painters
/// (`CustomPaint`: anillo y nodos del árbol, efectos de batalla,
/// minimapa) no son widgets de decoración y no se miran; las excepciones
/// de arte hechas con widgets van en [kRoundArtKeys].
List<String> roundedUi(WidgetTester tester) {
  final out = <String>[];
  for (final e in find.byWidgetPredicate((_) => true).evaluate()) {
    final why = _rounded(e.widget);
    if (why == null || _isArt(e)) continue;
    out.add('$why${_nearestKey(e)}');
  }
  return out;
}

/// Prefijos de `ValueKey<String>` cuyos subárboles son arte de escena
/// intencionalmente redondo (nodos de la constelación de Ascensión).
const kRoundArtKeys = ['asc-node-', 'asc-aura'];

bool _isArt(Element e) {
  bool art(Widget w) {
    final k = w.key;
    return k is ValueKey<String> && kRoundArtKeys.any(k.value.startsWith);
  }

  if (art(e.widget)) return true;
  var found = false;
  e.visitAncestorElements((a) {
    found = art(a.widget);
    return !found;
  });
  return found;
}

String _nearestKey(Element e) {
  Key? key = e.widget.key is ValueKey ? e.widget.key : null;
  var up = 0;
  if (key == null) {
    e.visitAncestorElements((a) {
      if (a.widget.key is ValueKey) {
        key = a.widget.key;
        return false;
      }
      return ++up < 12;
    });
  }
  return key == null ? '' : ' $key';
}

bool _radius(BorderRadiusGeometry? r) =>
    r != null && r != BorderRadius.zero && r != BorderRadiusDirectional.zero;

bool _shape(ShapeBorder? s) => switch (s) {
      null => false,
      RoundedRectangleBorder(:final borderRadius) => _radius(borderRadius),
      BeveledRectangleBorder() => false,
      LinearBorder() => false,
      Border() => false,
      _ => true, // CircleBorder, StadiumBorder, ContinuousRectangleBorder…
    };

bool _deco(Decoration? d) => switch (d) {
      BoxDecoration(:final borderRadius, :final shape) =>
        shape == BoxShape.circle || _radius(borderRadius),
      ShapeDecoration(:final shape) => _shape(shape),
      _ => false,
    };

String? _rounded(Widget w) => switch (w) {
      DecoratedBox(:final decoration) when _deco(decoration) =>
        'DecoratedBox',
      Material(:final shape, :final borderRadius, :final type)
          when _shape(shape) ||
              _radius(borderRadius) ||
              type == MaterialType.circle =>
        'Material',
      ClipRRect(:final borderRadius) when _radius(borderRadius) => 'ClipRRect',
      ClipOval() => 'ClipOval',
      PhysicalShape(:final clipper)
          when clipper is ShapeBorderClipper && _shape(clipper.shape) =>
        'PhysicalShape',
      Badge() => 'Badge (pastilla de Material)',
      _ => null,
    };
