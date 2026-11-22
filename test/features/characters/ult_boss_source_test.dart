// ULT de botín de jefe (ultimates_v2.md § 3.6): la etiqueta no habla de
// fragmentos, cada una dice qué jefe la enseña y dónde aparece, y la
// sección muestra "Jefes vencidos: X/10". Con ULT_BOSS_SHOTS=<carpeta>
// además guarda una captura de la sección.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ult_def.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

final _out = Platform.environment['ULT_BOSS_SHOTS'];

UltDef _boss(String ref) =>
    kUltV2List.firstWhere((u) => u.source == UltSource.boss && u.ref == ref);

void main() {
  test('la etiqueta del origen es Botín de jefe, sin fragmentos', () {
    expect(UltSource.boss.label, 'Botín de jefe');
    expect(UltSource.boss.key, 'boss');
    for (final u in kUltV2List.where((u) => u.source == UltSource.boss)) {
      final t = ultHowText(u);
      expect(t.toLowerCase(), isNot(contains('fragmento')), reason: u.id);
      expect(t, contains('(la primera victoria la enseña)'));
      expect(bossUltZone(u), isNotNull, reason: u.id);
    }
  });

  test('texto exacto: jefe, zona y versión del Abismo', () {
    expect(
        ultHowText(_boss('reyLimo')),
        'Se aprende al vencer a Rey Limo (la primera victoria la enseña). '
        'Aparece como jefe de la zona 1, Pradera Esmeralda (Nv 1–5).');
    expect(ultHowText(_boss('golemReloj')),
        endsWith('Su versión del Abismo también la enseña.'));
  });

  test('jefes vencidos: por ULT aprendida o zona desbloqueada', () {
    final p = newProfile('Ana', 'guerrero');
    expect(bossUltsDefeated(p), 0);
    final q = p.copyWith(
        unlockedZone: 3, ultKnown: {_boss('centinela').id});
    // Zonas 1 y 2 superadas + Centinela aprendida.
    expect(bossUltsDefeated(q), 3);
    expect(bossUltDefeated(_boss('matriarca'), q), isTrue);
    expect(bossUltDefeated(_boss('golemReloj'), q), isFalse);
  });

  testWidgets('la sección muestra progreso y cómo conseguir cada una',
      (tester) async {
    final key = GlobalKey();
    final p = newProfile('Ana', 'guerrero')
        .copyWith(unlockedZone: 3, ultKnown: {_boss('reyLimo').id});
    await pumpPanel(tester,
        profile: p,
        build: (v, c) => RepaintBoundary(
            key: key, child: CharacterPanel(view: v, controller: c)));
    final tab = CharacterTab.values.indexOf(CharacterTab.ults);
    await tester.tap(find.byKey(ValueKey('tab-$tab')));
    await tester.pump();
    expect(find.textContaining('FRAGMENTO'), findsNothing);
    final prog = find.byKey(const ValueKey('ult-boss-progress'));
    expect(tester.widget<Text>(prog).data, 'Jefes vencidos: 2/10');
    final row = find.byKey(ValueKey('ult-row-${_boss('matriarca').id}'));
    expect(
        find.descendant(
            of: row,
            matching: find.text(
                'Falta · Vencé a Matriarca Araña (zona 2, Nv 6–10)')),
        findsOneWidget);
    expect(bossUltStatusText(_boss('matriarca'), p),
        'Ya lo venciste: volvé a vencerlo para aprenderla.');
    expect(bossUltStatusText(_boss('devorador'), p), 'Todavía no lo venciste.');
    // Clic: la info de la derecha dice cómo se consigue y el estado.
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await tester.pump();
    expect(find.textContaining('Se aprende al vencer a Matriarca Araña'),
        findsOneWidget);
    expect(find.text('Ya lo venciste: volvé a vencerlo para aprenderla.'),
        findsOneWidget);
    final out = _out;
    if (out == null) return;
    await tester.runAsync(() async {
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage();
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(out).createSync(recursive: true);
      File('$out/despues_ult_botin_jefe.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
