import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/domain/skill_text.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Batalla de una Maga con 4 invocaciones (docs/specs/summoner.md § 8).
BattleState summonBattle() {
  final engine = BattleEngine(
    stats: StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
    random: () => 0.99,
  );
  final cls = kClasses['maga']!;
  var s = engine.start(party: [
    BattlePartyMember(
      id: 'm',
      name: 'Maga',
      build: PlayerBuild(
        classId: 'maga',
        level: 44,
        attributes: PlayerAttributes.base(cls.baseAttributes),
        equippedWeapon: kWeapons['libro_cuatro']!,
      ),
    ),
  ], enemyTypes: const ['slime', 'bat', 'slime'], triggeredBy: 'm').state;
  for (final e in s.enemies) {
    e
      ..maxHp = 9999
      ..hp = 9999;
  }
  s.party.first
    ..ult = 100
    ..mp = 99;
  s.currentId = 'm';
  s = engine.command(s, 'm', const UltimateCommand())!.state;
  return engine.nextTurn(s).state;
}

void main() {
  testWidgets('batalla con invocaciones: fila en la tarjeta y escena sin errores',
      (tester) async {
    final state = summonBattle();
    expect(state.summons, hasLength(4));
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(battle: state, canAct: false, onCommand: (_) => false),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('summons-row')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('tooltip de invocar: stats con tu MAG y de dónde sale', () {
    final p = summonBattle().party.first;
    final t = describeSkillMarkup(kSkills['invGolem']!, p);
    expect(t, contains('Gólem'));
    expect(t, contains('Vida <b>'));
    expect(t, contains('Máx. 4'));
  });
}
