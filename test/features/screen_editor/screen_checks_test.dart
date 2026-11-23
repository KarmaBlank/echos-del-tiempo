import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:echos_del_tiempo/app/design/registry/ds_registry.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_bindings.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_layout.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_layout_catalog.dart';
import 'package:echos_del_tiempo/features/screen_editor/domain/screen_checks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Medida falsa y determinista: cada letra = tamaño nominal de ancho,
/// línea = 1,5 × nominal; corta en el ancho disponible.
Size _measure(String text, DsTextStyleId style, double maxWidth) {
  final w = text.length * style.nominal;
  if (!maxWidth.isFinite || w <= maxWidth) {
    return Size(w, style.nominal * 1.5);
  }
  final perLine = math.max(1, (maxWidth / style.nominal).floor());
  final lines = (text.length / perLine).ceil();
  return Size(maxWidth, lines * style.nominal * 1.5);
}

ScreenElement _text(String id,
        {String role = 'texto',
        String style = 'body',
        String variant = 'normal',
        double x = 100,
        double y = 300,
        double w = 400,
        double h = 40,
        String text = 'Hola'}) =>
    ScreenElement(
        id: id,
        component: 'text',
        text: text,
        role: role,
        textStyle: style,
        variant: variant,
        x: x,
        y: y,
        w: w,
        h: h);

ScreenElement _button(String id,
        {double x = 100,
        double y = 600,
        double w = 240,
        double h = 40,
        int? focus = 1,
        String? action = 'configuracion',
        String variant = 'secundario'}) =>
    ScreenElement(
        id: id,
        component: 'button',
        text: 'OK',
        variant: variant,
        x: x,
        y: y,
        w: w,
        h: h,
        focusOrder: focus,
        action: action);

void main() {
  final checker = ScreenChecker(bindings: titleBindings, measure: _measure);

  List<ScreenIssue> run(List<ScreenElement> els) =>
      checker.run(ScreenLayout(screen: 'title', elements: els));

  ScreenLayout fixAll(ScreenLayout l, ScreenIssueKind kind) {
    for (var i = 0; i < 10; i++) {
      final issue =
          checker.run(l).where((x) => x.kind == kind && x.fix != null).firstOrNull;
      if (issue == null) return l;
      l = issue.fix!(l);
    }
    return l;
  }

  test('contraste: relación WCAG', () {
    expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFF777777), const Color(0xFF777777)), 1);
  });

  test('contraste: texto sobre una superficie usa el fondo de abajo', () {
    const panel = ScreenElement(
        id: 'p',
        component: 'panel',
        variant: 'elevada',
        x: 0,
        y: 0,
        w: 1280,
        h: 720);
    final l = ScreenLayout(screen: 'title', elements: [panel, _text('t')]);
    expect(checker.backgroundOf(l, 1),
        DsRegistry.instance['panel']!.surface!('elevada'));
    final none = ScreenLayout(screen: 'title', elements: [_text('t')]);
    expect(checker.backgroundOf(none, 0), checker.background);
  });

  test('contraste bajo: aviso con arreglo a la variante normal', () {
    // Un fondo igual al color de peligro: contraste 1:1.
    final dangerBg = ScreenChecker(
        bindings: titleBindings,
        measure: _measure,
        background: DsRegistry.instance['text']!
            .textColor!('peligro', DsTextStyleId.body));
    final l = ScreenLayout(
        screen: 'title', elements: [_text('t', variant: 'peligro')]);
    final issue = dangerBg
        .run(l)
        .firstWhere((i) => i.kind == ScreenIssueKind.contrast);
    expect(issue.elementId, 't');
    if (issue.fix != null) {
      expect(issue.fix!(l).byId('t')!.variant, 'normal');
    }
  });

  test('rol vs estilo: un título con estilo de texto', () {
    final issues = run([_text('t', role: 'titulo', style: 'body')]);
    final i = issues.firstWhere((i) => i.kind == ScreenIssueKind.roleStyle);
    final fixed =
        i.fix!(ScreenLayout(screen: 'title', elements: [_text('t', role: 'titulo')]));
    expect(fixed.byId('t')!.textStyle, 'display');
  });

  test('jerarquía: dos títulos, subtítulo arriba del título', () {
    final issues = run([
      _text('sub', role: 'subtitulo', style: 'subtitle', y: 10, h: 24),
      _text('t1', role: 'titulo', style: 'title', y: 100, h: 40),
      _text('t2', role: 'titulo', style: 'title', y: 200, h: 40),
    ]);
    final h = issues.where((i) => i.kind == ScreenIssueKind.hierarchy);
    expect(h.map((i) => i.elementId), containsAll(['t2', 'sub']));
    final l = ScreenLayout(screen: 'title', elements: [
      _text('t1', role: 'titulo', style: 'title', y: 100),
      _text('t2', role: 'titulo', style: 'title', y: 200),
    ]);
    final fixed = fixAll(l, ScreenIssueKind.hierarchy);
    expect(fixed.byId('t2')!.role, 'subtitulo');
    expect(fixed.byId('t2')!.textStyle, 'subtitle');
  });

  test('texto recortado: se agranda la caja', () {
    final l = ScreenLayout(screen: 'title', elements: [
      _text('t', text: 'Un texto bastante largo para la caja', w: 80, h: 16),
    ]);
    expect(checker.run(l).map((i) => i.kind), contains(ScreenIssueKind.clipped));
    final fixed = fixAll(l, ScreenIssueKind.clipped);
    expect(checker.run(fixed).map((i) => i.kind),
        isNot(contains(ScreenIssueKind.clipped)));
  });

  test('objetivo de clic chico: se agranda a ≥ 32 efectivos', () {
    const l = ScreenLayout(screen: 'title', elements: [
      ScreenElement(
          id: 'q',
          component: 'icon_button',
          text: '?',
          x: 10,
          y: 10,
          w: 16,
          h: 16,
          focusOrder: 1,
          action: 'ayudaTeclas'),
    ]);
    expect(checker.run(l).map((i) => i.kind),
        contains(ScreenIssueKind.tapTarget));
    final fixed = fixAll(l, ScreenIssueKind.tapTarget);
    final q = fixed.byId('q')!;
    expect(q.w * 0.8, greaterThanOrEqualTo(32));
    expect(q.h * 0.8, greaterThanOrEqualTo(32));
  });

  test('texto mínimo: Subtítulo en 1024×768 pasa; ventana ínfima avisa', () {
    expect(
        run([_text('s', role: 'subtitulo', style: 'subtitle')])
            .map((i) => i.kind),
        isNot(contains(ScreenIssueKind.textSize)));
    final tiny = ScreenChecker(
        bindings: titleBindings,
        measure: _measure,
        previewSizes: const [Size(640, 360)]);
    final issues = tiny.run(ScreenLayout(
        screen: 'title', elements: [_text('d', role: 'detalle', style: 'detail')]));
    expect(issues.map((i) => i.kind), contains(ScreenIssueKind.textSize));
  });

  test('orden de foco: falta, repetido y fuera de lectura → renumerar', () {
    final l = ScreenLayout(screen: 'title', elements: [
      _button('b', x: 600, focus: 1),
      _button('a', x: 100, focus: 2),
      _button('c', x: 100, y: 100, focus: null),
    ]);
    expect(checker.run(l).where((i) => i.kind == ScreenIssueKind.focusOrder),
        isNotEmpty);
    final fixed = fixAll(l, ScreenIssueKind.focusOrder);
    expect(fixed.byId('c')!.focusOrder, 1);
    expect(fixed.byId('a')!.focusOrder, 2);
    expect(fixed.byId('b')!.focusOrder, 3);
    expect(checker.run(fixed).where((i) => i.kind == ScreenIssueKind.focusOrder),
        isEmpty);
  });

  test('deshabilitado: sin acción va gris; el acento se quita', () {
    final l = ScreenLayout(screen: 'title', elements: [
      _button('x', action: null, variant: 'primario'),
      _button('y', action: 'noExiste', focus: 2),
    ]);
    final d = checker.run(l).where((i) => i.kind == ScreenIssueKind.disabled);
    expect(d.map((i) => i.elementId), ['x', 'y']);
    final fixed = d.first.fix!(l);
    expect(fixed.byId('x')!.variant, 'secundario');
    expect(d.last.fix, isNull);
  });

  test('bindings: grilla sin fuente → la primera de la pantalla', () {
    const l = ScreenLayout(screen: 'title', elements: [
      ScreenElement(
          id: 'g', component: 'data_grid', x: 0, y: 0, w: 400, h: 200),
    ]);
    final fixed = fixAll(l, ScreenIssueKind.binding);
    expect(fixed.byId('g')!.dataSource, titleBindings.dataSources.first.id);
  });

  test('fuera del lienzo: se mete adentro', () {
    final l = ScreenLayout(
        screen: 'title', elements: [_text('t', x: 1200, y: 700, w: 200)]);
    final fixed = fixAll(l, ScreenIssueKind.bounds);
    final t = fixed.byId('t')!;
    expect(t.x + t.w, lessThanOrEqualTo(1280));
    expect(t.y + t.h, lessThanOrEqualTo(720));
  });

  test('el título del repo pasa VERIFICAR', () {
    final l = ScreenLayout.parse(
        File(ScreenLayoutCatalog.pathOf('title')).readAsStringSync());
    expect(checker.run(l), isEmpty);
  });
}
