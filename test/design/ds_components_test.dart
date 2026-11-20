import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/design/gallery/ds_gallery_screen.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart'
    show TextSize;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../real_fonts.dart';
import 'ds_harness.dart';

void main() {
  testWidgets('DsButton deja ≥ 8 px libres en los cuatro lados',
      (tester) async {
    await loadRealFonts(tester);
    for (final size in DsButtonSize.values) {
      await pumpDs(tester, DsButton('EQUIPAR', size: size, onPressed: () {}));
      final btn = tester.getRect(find.byType(OutlinedButton));
      final txt = tester.getRect(find.text('EQUIPAR'));
      final b = DsMetrics.controlBorder;
      expect(txt.left - btn.left - b, greaterThanOrEqualTo(8));
      expect(btn.right - txt.right - b, greaterThanOrEqualTo(8));
      expect(txt.top - btn.top - b, greaterThanOrEqualTo(8 - 0.5));
      expect(btn.bottom - txt.bottom - b, greaterThanOrEqualTo(8 - 0.5));
    }
  });

  testWidgets('DsButton: cursor de mano, desactivado con cursor normal',
      (tester) async {
    var taps = 0;
    await pumpDs(
        tester,
        Row(mainAxisSize: MainAxisSize.min, children: [
          DsButton('SI', onPressed: () => taps++),
          const DsButton('NO', onPressed: null),
        ]));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('SI')));
    await tester.pump();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click);
    await gesture.moveTo(tester.getCenter(find.text('NO')));
    await tester.pump();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.basic);
    await tester.tap(find.text('SI'));
    await tester.tap(find.text('NO'), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('foco de teclado: aro dorado y Enter activa', (tester) async {
    var taps = 0;
    await pumpDs(tester, DsButton('IR', onPressed: () => taps++));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final ring = tester.widget<DsFocusRing>(find.byType(DsFocusRing));
    expect(ring.focused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('la insignia de la pestaña va al lado del texto, sin taparlo',
      (tester) async {
    await loadRealFonts(tester);
    await pumpDs(
        tester,
        SizedBox(
          width: 900,
          child: DsTabBar(
              tabs: const [DsTab('PASIVAS', badge: '3'), DsTab('EQUIPO')],
              index: 0,
              onChanged: (_) {}),
        ));
    final text = tester.getRect(find.text('PASIVAS'));
    final badge = tester.getRect(find.byType(DsBadge));
    expect(text.overlaps(badge), isFalse);
    expect(badge.left, greaterThan(text.right));
  });

  testWidgets('DsListRow: una línea, desactivada no responde', (tester) async {
    var taps = 0;
    await pumpDs(
        tester,
        SizedBox(
          width: 500,
          child: Column(children: [
            DsListRow(title: 'Espada', detail: 'Nv 1', onTap: () => taps++),
            DsListRow(title: 'Báculo', enabled: false, onTap: () => taps++),
          ]),
        ));
    await tester.tap(find.text('Espada'));
    await tester.tap(find.text('Báculo'), warnIfMissed: false);
    expect(taps, 1);
    final t = tester.widget<Text>(find.text('Espada'));
    expect(t.maxLines, 1);
  });

  testWidgets('DsAttributeRow: el tope solo aparece al pasarlo',
      (tester) async {
    await pumpDs(
        tester,
        SizedBox(
          width: 700,
          child: Column(children: [
            DsAttributeRow(
                name: 'Vitalidad', code: 'VIT', value: 30, onAdd: () {}),
            DsAttributeRow(
                name: 'Agilidad',
                code: 'AGI',
                value: 61,
                cappedStep: 1.5,
                onAdd: () {}),
          ]),
        ));
    expect(find.text('+3 VIT'), findsOneWidget);
    expect(find.text('+3 → +1.5'), findsOneWidget);
  });

  testWidgets('DsFold despliega y pliega', (tester) async {
    await pumpDs(tester, const DsFold(child: Text('oculto')));
    expect(find.text('oculto'), findsNothing);
    await tester.tap(find.text('> MAS'));
    await tester.pump();
    expect(find.text('oculto'), findsOneWidget);
  });

  testWidgets('DsCost en rojo si no alcanza', (tester) async {
    await pumpDs(
        tester,
        const Row(mainAxisSize: MainAxisSize.min, children: [
          DsCost.mp(8),
          DsCost.pulse(2, affordable: false),
        ]));
    final mp = tester.widget<Text>(find.text('8 MP'));
    final p = tester.widget<Text>(find.text('2 P'));
    expect(mp.style!.color, DsColors.mp);
    expect(p.style!.color, DsColors.danger);
  });

  for (final size in TextSize.values) {
    for (final page in DsGalleryPage.values) {
      testWidgets('galería ${page.name} en ${size.name} sin desbordes',
          (tester) async {
        await loadRealFonts(tester);
        await pumpDs(
            tester,
            SizedBox(
                width: 1880,
                height: 1040,
                child:
                    DsGalleryScreen(initialPage: page, initialTextSize: size)),
            size: const Size(1920, 1080));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
