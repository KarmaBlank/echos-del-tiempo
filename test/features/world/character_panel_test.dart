import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

String _plain(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).textSpan!.toPlainText();

void main() {
  testWidgets('personaje: el reparto muestra antes > después y se confirma',
      (tester) async {
    final start = progression.normalize(
        PlayerProfile(name: 'Ana', classId: 'guerrero', level: 3)); // 6 pts
    final c = await pumpPanel(tester,
        profile: start,
        build: (v, c) => CharacterPanel(view: v, controller: c));
    final before = progression.derivedStats(start);
    expect(_plain(tester, 'stat-HP'), 'HP ${before.maxHp}');
    expect(find.textContaining('Puntos: 6'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('inc-vit')));
    await tapVisible(tester, find.byKey(const ValueKey('inc-vit')));
    await tapVisible(tester, find.byKey(const ValueKey('inc-fue')));
    final preview = progression.previewAllocation(
        start, {Attribute.vit: 2, Attribute.fue: 1});
    expect(preview.maxHp, greaterThan(before.maxHp));
    expect(_plain(tester, 'stat-HP'), 'HP ${before.maxHp} > ${preview.maxHp}');
    expect(_plain(tester, 'stat-ATQ'),
        'ATQ ${before.attack} > ${preview.attack}');
    expect(find.textContaining('Puntos: 3'), findsOneWidget);
    // Nada cambió todavía en el host.
    expect(c.view!.me!.profile.points, 6);

    await tapVisible(tester, find.byKey(const ValueKey('dec-fue')));
    await tapVisible(tester, find.byKey(const ValueKey('confirm-points')));
    final p = c.view!.me!.profile;
    expect(p.attributes[Attribute.vit], start.attributes[Attribute.vit] + 2);
    expect(p.attributes[Attribute.fue], start.attributes[Attribute.fue]);
    expect(p.points, 4);
    expect(c.view!.me!.maxHp,
        progression.previewAllocation(start, {Attribute.vit: 2}).maxHp);
    expect(_plain(tester, 'stat-HP'), 'HP ${c.view!.me!.maxHp}');

    // Reiniciar puntos (en el lobby).
    await tapVisible(tester, find.byKey(const ValueKey('respec')));
    expect(c.view!.me!.profile.points, 6);
  });

  testWidgets('personaje: cambio de clase en el lobby y equipar en Armas',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: progression.normalize(PlayerProfile(
            name: 'Ana',
            classId: 'guerrero',
            level: 3,
            inventory: const ['espada_bronce', 'espada_ignea'])),
        build: (v, c) => CharacterPanel(view: v, controller: c));

    // Armas: la Ígnea pide FUE 14 / DES 8; Lv3 tiene FUE 12, DES 6.
    await tapVisible(tester, find.byKey(const ValueKey('tab-1')));
    expect(find.text('EQUIPADA'), findsOneWidget);
    expect(tester
        .widget<PanelButton>(find.byKey(const ValueKey('equip-espada_ignea')))
        .reason, 'Requisitos');

    // Con el reparto pendiente cumpliría: "Confirma puntos".
    await tapVisible(tester, find.byKey(const ValueKey('tab-0')));
    await tapVisible(tester, find.byKey(const ValueKey('inc-fue')));
    await tapVisible(tester, find.byKey(const ValueKey('inc-fue')));
    await tapVisible(tester, find.byKey(const ValueKey('inc-des')));
    await tapVisible(tester, find.byKey(const ValueKey('inc-des')));
    await tapVisible(tester, find.byKey(const ValueKey('tab-1')));
    expect(tester
        .widget<PanelButton>(find.byKey(const ValueKey('equip-espada_ignea')))
        .reason, 'Confirma puntos');
    await tapVisible(tester, find.byKey(const ValueKey('tab-0')));
    await tapVisible(tester, find.byKey(const ValueKey('confirm-points')));
    await tapVisible(tester, find.byKey(const ValueKey('tab-1')));
    await tapVisible(tester, find.byKey(const ValueKey('equip-espada_ignea')));
    expect(c.view!.me!.profile.equipped, 'espada_ignea');

    // Cambio de clase (solo lobby).
    await tapVisible(tester, find.byKey(const ValueKey('tab-0')));
    await tapVisible(tester, find.byKey(const ValueKey('class-maga')));
    expect(c.view!.me!.profile.classId, 'maga');
    expect(c.view!.me!.profile.equipped, 'baculo_aprendiz');
  });
}
