import 'dart:io';
import 'dart:ui';

import 'package:echos_del_tiempo/core/screen_layout/screen_layout.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_layout_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout de pantalla como datos (docs/specs/screen_editor.md § 2).
void main() {
  const e = ScreenElement(
    id: 'b',
    component: 'button',
    variant: 'primario',
    text: 'JUGAR',
    x: 100,
    y: 600,
    w: 200,
    h: 40,
    hAnchor: HAnchor.right,
    vAnchor: VAnchor.bottom,
    align: ScreenAlign.center,
    focusOrder: 2,
    action: 'nuevaPartida',
  );
  const layout = ScreenLayout(screen: 'title', elements: [e]);

  test('ida y vuelta por JSON sin pérdida', () {
    final back = ScreenLayout.parse(layout.encode());
    expect(back, layout);
    expect(back.elements.single.action, 'nuevaPartida');
    expect(back.elements.single.hAnchor, HAnchor.right);
    expect(back.encode(), layout.encode());
  });

  test('copyWith puede limpiar campos opcionales', () {
    expect(e.copyWith(action: null).action, isNull);
    expect(e.copyWith(x: 8).action, 'nuevaPartida');
  });

  test('JSON inválido: FormatException', () {
    expect(() => ScreenLayout.parse('[]'), throwsFormatException);
    expect(() => ScreenLayout.parse('{"elements": []}'), throwsFormatException);
  });

  test('anclas: a la escala de diseño la caja no se mueve', () {
    final p = layout.place(e, const Size(1280, 720));
    expect(p.rect, const Rect.fromLTWH(100, 600, 200, 40));
    expect(p.scale, 1);
  });

  test('anclas: derecha/abajo se pegan al borde; estirar llena', () {
    // 16:10 más alto: escala 1, sobran 80 px abajo.
    final p = layout.place(e, const Size(1280, 800));
    expect(p.rect.top, 680);
    expect(p.rect.left, 100);
    final wide = layout.place(e, const Size(1600, 720)); // sobran 320 a lo ancho
    expect(wide.rect.left, 420);
    final s = e.copyWith(hAnchor: HAnchor.stretch);
    expect(layout.place(s, const Size(1600, 720)).rect.width, 520);
    final c = e.copyWith(hAnchor: HAnchor.center, vAnchor: VAnchor.center);
    final big = layout.place(c, const Size(2560, 1440));
    expect(big.scale, 2);
    expect(big.rect, const Rect.fromLTWH(200, 1200, 400, 80));
  });

  test('el layout del título del repo parsea y vuelve igual', () {
    final text = File(ScreenLayoutCatalog.pathOf('title')).readAsStringSync();
    final l = ScreenLayout.parse(text);
    expect(l.screen, 'title');
    expect(l.byId('title-quit')?.action, 'salirDelJuego');
    expect(ScreenLayout.parse(l.encode()), l);
  });
}
