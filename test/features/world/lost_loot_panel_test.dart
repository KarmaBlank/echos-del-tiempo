import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/lost_loot_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

void main() {
  testWidgets('loot perdido: grilla, ficha al pasar el mouse y TOMAR',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: progression.normalize(
            PlayerProfile(name: 'Ana', classId: 'guerrero', level: 3)),
        build: (v, c) => LostLootPanel(view: v, controller: c));
    LootDrop sword(String uid) => LootDrop.item(ItemInstance(
        uid: uid, baseId: 'espada_ignea', rarity: Rarity.raro, itemLevel: 2));
    c.session!.lostLoot
      ..add(GroundLoot(id: 1, drop: sword('a'), x: 0, y: 0))
      ..add(GroundLoot(id: 2, drop: sword('b'), x: 0, y: 0));
    c.openPanel(WorldPanel.lostLoot); // re-emite la vista
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lost-cell-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('lost-cell-2')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('lost-cell-1')),
            matching: find.byType(ItemCell)),
        findsOneWidget);

    // Hover: aparece la ficha de siempre (una tarjeta más en pantalla).
    final name = find.textContaining('gnea', findRichText: true);
    final before = name.evaluate().length;
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('lost-cell-2'))));
    await tester.pumpAndSettle();
    expect(name.evaluate().length, greaterThan(before));
    await g.moveTo(Offset.zero);
    await tester.pumpAndSettle();

    // Elegir la 2 y TOMAR desde el detalle.
    await tester.tap(find.byKey(const ValueKey('lost-cell-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lost-take-2')));
    await tester.pumpAndSettle();
    expect(c.session!.lostLoot.map((x) => x.id), [1]);
    expect(c.session!.players.values.first.profile.items.map((i) => i.baseId),
        contains('espada_ignea'));

    // TOMAR TODO se lleva el resto.
    await tester.tap(find.byKey(const ValueKey('lost-take-all')));
    await tester.pumpAndSettle();
    expect(c.session!.lostLoot, isEmpty);
    expect(find.byKey(const ValueKey('lost-empty')), findsOneWidget);
  });
}
