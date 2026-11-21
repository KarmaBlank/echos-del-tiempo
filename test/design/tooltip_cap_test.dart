import 'package:echos_del_tiempo/app/design/ds_components.dart';
import 'package:echos_del_tiempo/app/design/ds_tokens.dart';
import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/app/theme/retro_type.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regla global (v0.20.1): todo tooltip respeta el ancho y la letra del
/// estándar del inventario ([RetroHoverCard.textWidth] × factor), tope
/// 45 % de la ventana, y nunca escala dos veces.
void main() {
  for (final f in [1.0, 2.0]) {
    testWidgets('DsTooltip con tope del inventario (factor $f)', (t) async {
      t.view.physicalSize = const Size(1920, 1080);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      late double std;
      late double titleSize;
      await t.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(f)),
            child: child!),
        home: Scaffold(
          body: Center(child: Builder(builder: (c) {
            std = RetroType.width(c, RetroHoverCard.textWidth);
            titleSize = MediaQuery.textScalerOf(c)
                .scale(DsText.body().fontSize!);
            return DsTooltip(
              card: DsTooltipCard(
                  title: 'Volver a tirar', children: [Text('x ' * 400)]),
              child: const SizedBox(
                  key: ValueKey('target'), width: 40, height: 40),
            );
          })),
        ),
      ));
      final g = await t.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      await g.moveTo(t.getCenter(find.byKey(const ValueKey('target'))));
      await t.pumpAndSettle(const Duration(seconds: 1));
      final card = find.byType(DsTooltipCard);
      expect(card, findsOneWidget);
      final r = t.getRect(card);
      expect(r.width, lessThanOrEqualTo(std + 1));
      expect(r.width, lessThanOrEqualTo(1920 * 0.45 + 1));
      expect(r.left >= 0 && r.right <= 1920, isTrue);
      expect(r.top >= 0 && r.bottom <= 1080, isTrue);
      // Sin doble escala: el título mide a lo sumo ~2 líneas de su letra.
      final title = t.getRect(find.text('Volver a tirar'));
      expect(title.height, lessThanOrEqualTo(titleSize * 2.2));
      await g.removePointer();
    });
  }
}
