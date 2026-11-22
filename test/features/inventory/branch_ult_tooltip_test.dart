import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/skill_chip.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

// v0.20.15: el mod "ULT: <nombre>" ya no se muestra en el arma (se aprende
// al conseguirla, ultimates_v2.md § 2.1).

void main() {
  const it = ItemInstance(uid: 'a', baseId: 'espada_bronce', rarity: Rarity.raro, ultId: 'ult_guillotina', name: 'Filo X');

  test('el tooltip ya no muestra la ULT del mod ni la del tipo', () {
    final m = itemTooltipMarkup(zoneProgression, it,
        level: 10, attributes: const PlayerAttributes({}));
    expect(m, isNot(contains('ULT: Guillotina')));
    expect(itemSkillsMarkup(zoneProgression, it), isNot(contains('Tajo Final')));
  });

  testWidgets('las fichas de habilidades no muestran ULT', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SkillChips(rules: zoneProgression, item: it))));
    expect(find.textContaining('Guillotina', findRichText: true), findsNothing);
    expect(find.textContaining('Tajo Final', findRichText: true), findsNothing);
  });
}
