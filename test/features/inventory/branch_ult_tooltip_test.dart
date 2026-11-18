import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/skill_chip.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

// El mod "ULT: <nombre>" se ve como la ULT del arma (branch_ults.md).

void main() {
  const it = ItemInstance(uid: 'a', baseId: 'espada_bronce', rarity: Rarity.raro, ultId: 'ult_guillotina', name: 'Filo X');

  test('el tooltip muestra "ULT: Guillotina" y no la del tipo', () {
    final m = itemTooltipMarkup(zoneProgression, it,
        level: 10, attributes: const PlayerAttributes({}));
    expect(m, contains('ULT: Guillotina'));
    expect(itemSkillsMarkup(zoneProgression, it), isNot(contains('Tajo Final')));
  });

  testWidgets('las fichas de habilidades muestran la ULT del mod', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SkillChips(rules: zoneProgression, item: it))));
    expect(find.textContaining('Guillotina', findRichText: true), findsWidgets);
    expect(find.textContaining('Tajo Final', findRichText: true), findsNothing);
  });
}
