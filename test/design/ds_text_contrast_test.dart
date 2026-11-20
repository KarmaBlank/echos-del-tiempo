import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../app/contrast_test.dart' show contrast;

/// Contraste WCAG de los 4 colores de texto del sistema de diseño
/// (design_system.md § 3.2) contra los fondos de cada tema: Cuerpo y
/// Detalle ≥ 4.5:1, Título y Subtítulo ≥ 3:1 (texto grande).
void main() {
  tearDown(() => UiTheme.kind = InterfaceTheme.blue);
  const backgrounds = {
    'fondo': ProtoColors.bg,
    'panel': ProtoColors.panel,
    'campo': ProtoColors.input,
    'botón': ProtoColors.button,
  };
  for (final t in InterfaceTheme.values) {
    test('texto del sistema de diseño · ${t.name}', () {
      UiTheme.kind = t;
      final lines = <String>[];
      for (final role in DsTextRole.values) {
        final min =
            role == DsTextRole.title || role == DsTextRole.subtitle ? 3.0 : 4.5;
        for (final b in backgrounds.entries) {
          final r =
              contrast(DsTextColor.inTheme(t, role), Color(b.value.toARGB32()));
          lines.add('${role.name}/${b.key} ${r.toStringAsFixed(2)}');
          expect(r, greaterThanOrEqualTo(min),
              reason: '${role.name} sobre ${b.key} (${t.name})');
        }
      }
      // ignore: avoid_print
      print('${t.name}: ${lines.join(', ')}');
    });
  }
}
