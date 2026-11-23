import 'dart:ui';

import 'package:echos_del_tiempo/features/world/presentation/hud/map_hover_tip.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/tool_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Size(1000, 800), tip = Size(200, 100);
  Offset at(Offset c) =>
      MapHoverTipLayout(c, 16, 160).getPositionForChild(screen, tip);

  test('tooltip del mapa: abajo a la derecha del cursor', () {
    expect(at(const Offset(100, 100)), const Offset(116, 116));
  });
  test('tooltip del mapa: sube cerca de la barra de abajo y no sale', () {
    final p = at(const Offset(950, 700));
    expect(p, const Offset(734, 584));
  });
  test('barra de herramienta: márgenes iguales (centrada)', () {
    final (l, r) = toolSide(1914, 700, 542);
    expect(l, r);
    expect(l, (1914 - ToolHud.width) / 2);
  });
  test('etiquetas del mapa no salen por arriba', () {
    final r = placeLabels([const Rect.fromLTWH(0, 0, 50, 10)], [0],
        bounds: const Rect.fromLTWH(0, 0, 100, 100));
    expect(r.single, 0);
  });
}
