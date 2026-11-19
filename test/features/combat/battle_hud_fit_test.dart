import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_hud.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';

/// Lo que no tiene que quedar cortado en la escena (fuentes reales):
/// la vida de 4+ cifras en la caja del objetivo y un log largo en la banda.

Combatant _foe(int hp) => Combatant(
      id: 'e0',
      name: 'Autómata de entrenamiento',
      isPlayer: false,
      hp: hp,
      maxHp: hp,
      speed: 5,
      attack: 6,
      critChance: 0,
      enemyType: 'golem',
      breakBase: 22,
    );

Future<void> _pump(WidgetTester tester, Widget child, {double dpr = 1}) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = Size(1280 * dpr, 720 * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: RetroTheme.build(),
    home: Scaffold(body: child),
  ));
  await tester.pump();
}

/// [text] se dibuja entero (sin recortar) dentro de la caja [box].
void _fitsIn(WidgetTester tester, Finder text, Finder box) {
  final p = tester.renderObject<RenderParagraph>(text);
  expect(p.size.width,
      greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.5),
      reason: 'el texto se cortó a lo ancho');
  final r = tester.getRect(text);
  final b = tester.getRect(box);
  expect(r.left >= b.left - 0.5 && r.right <= b.right + 0.5, isTrue,
      reason: '$r fuera de $b');
}

void main() {
  for (final hp in [126, 1200, 10000]) {
    testWidgets('caja del objetivo: $hp/$hp entra', (tester) async {
      await _pump(tester, Align(
          alignment: Alignment.topLeft, child: TargetBar(enemy: _foe(hp))));
      _fitsIn(tester, find.text('$hp/$hp'),
          find.byKey(const ValueKey('target-bar')));
    });
  }

  testWidgets('caja del objetivo: 3 cifras sin achicar', (tester) async {
    await _pump(tester, Align(
        alignment: Alignment.topLeft, child: TargetBar(enemy: _foe(126))));
    // Escala 1: lo dibujado mide lo mismo que el párrafo.
    final t = find.text('126/126');
    expect(tester.getRect(t).width,
        closeTo(tester.renderObject<RenderParagraph>(t).size.width, 0.01));
  });

  for (final dpr in [1.0, 1.5]) {
    testWidgets('banda del log: una línea larga no se corta (dpr $dpr)',
        (tester) async {
      final b = BattleState(party: [
        Combatant(
            id: 'p1',
            name: 'Caro',
            isPlayer: true,
            hp: 60,
            maxHp: 60,
            speed: 10,
            attack: 13,
            critChance: 0,
            classId: 'tirador'),
      ], enemies: [
        _foe(54)
      ])
        ..currentId = 'p1'
        ..log = 'Caro · Flecha Venenosa → Limo: 9 = ATQ 13 × 0.7 · +3 Veneno · '
            '¡COMBUSTIÓN! 10 Quemadura × 2.5% = 25% → 14 a Limo · Instante: '
            'una acción más';
      await _pump(tester, BattleView(battle: b, onCommand: (_) => true),
          dpr: dpr);
      final text = find.textContaining('Flecha Venenosa');
      final band = find.ancestor(of: text, matching: find.byType(Row)).first;
      final p = tester.renderObject<RenderParagraph>(text);
      final br = tester.getRect(band);
      // Alto que necesita el texto (no el de la caja, que se recorta).
      expect(p.getMaxIntrinsicHeight(p.size.width),
          lessThanOrEqualTo(br.height + 0.5),
          reason: 'el log no entra en la banda (${br.height})');
      expect(p.size.width, lessThanOrEqualTo(br.width));
      expect(tester.takeException(), isNull);
    });
  }
}
