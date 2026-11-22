import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/weapon_advice_block.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_guide_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/ds_harness.dart';

final _rules = ProgressionRules(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)));

WeaponAdvice _advice({String? type}) => BuildGuideRules(_rules).advice(
    BuildPlan(chosenType: type),
    PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        level: 40,
        items: [
          ItemInstance.common('a', 'espada_bronce'),
          const ItemInstance(
              uid: 'b',
              baseId: 'espada_templada',
              rarity: Rarity.raro,
              itemLevel: 30),
        ],
        equipped: 'a',
        attributes:
            const PlayerAttributes({Attribute.fue: 50, Attribute.des: 20})));

Widget _block(WeaponAdvice a,
        {ValueChanged<String>? onEquip,
        String? Function(String)? blocked,
        ValueChanged<String?>? onType}) =>
    SingleChildScrollView(
      child: SizedBox(
          width: 320,
          child: WeaponAdviceBlock(
            advice: a,
            nameOf: (i) => i.baseId,
            onEquip: onEquip,
            equipBlocked: blocked,
            onOpenForge: (_) {},
            onOpenShop: () {},
            onChooseType: onType,
          )),
    );

void main() {
  for (final factor in [1.0, 1.6]) {
    testWidgets('se ve sin desbordes con texto x$factor', (tester) async {
      await pumpDs(tester, _block(_advice(), onType: (_) {}),
          factor: factor, size: const Size(400, 900));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('advice-ideal')), findsOneWidget);
      expect(find.byKey(const ValueKey('advice-best')), findsOneWidget);
      expect(find.byKey(const ValueKey('advice-howto')), findsOneWidget);
    });
  }

  testWidgets('EQUIPAR equipa la mejor; con motivo queda deshabilitado',
      (tester) async {
    final a = _advice();
    expect(a.best!.equipped, isFalse);
    String? equipped;
    await pumpDs(tester, _block(a, onEquip: (u) => equipped = u));
    await tester.tap(find.byKey(const ValueKey('advice-equip')));
    expect(equipped, a.best!.item!.uid);

    await pumpDs(
        tester,
        _block(a,
            onEquip: (u) => equipped = 'x', blocked: (_) => 'En combate'));
    final b =
        tester.widget<DsButton>(find.byKey(const ValueKey('advice-equip')));
    expect(b.onPressed, isNull);
    expect(b.tooltip, 'En combate');
  });

  testWidgets('sin callback no hay botón EQUIPAR', (tester) async {
    await pumpDs(tester, _block(_advice()));
    expect(find.byKey(const ValueKey('advice-equip')), findsNothing);
  });

  testWidgets('Quiero usar: elegir tipo avisa el tipo', (tester) async {
    String? picked = 'sin tocar';
    await pumpDs(tester, _block(_advice(), onType: (t) => picked = t));
    expect(find.byKey(const ValueKey('advice-type')), findsOneWidget);
    final next = find.descendant(
        of: find.byKey(const ValueKey('advice-type')),
        matching: find.text('›'));
    await tester.tap(next.first);
    expect(picked, isNot('sin tocar'));
    expect(picked, isNotNull);
  });
}
