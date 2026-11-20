import 'dart:convert';

import 'package:echos_del_tiempo/features/admin/domain/admin_index.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_patch.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_registries.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Daño de lanzar Golpe Maestro (ULT v2 elegida) con [catalog].
int _ultDamage(GameCatalog catalog) {
  final engine = BattleEngine(
      stats: StatsCalculator(
          classes: catalog.classes, treeRules: PassiveTreeRules(kPassiveTree)),
      catalog: catalog,
      random: mulberry32(3));
  final cls = kClasses['guerrero']!;
  var s = engine.start(party: [
    BattlePartyMember(
      id: 'p1',
      name: 'G',
      ult: 100,
      build: PlayerBuild(
        classId: 'guerrero',
        level: 20,
        attributes: PlayerAttributes.base(cls.baseAttributes),
        equippedWeapon: catalog.weapons[cls.startWeaponId]!,
        ultSel: 'ult2_golpeMaestro',
      ),
    ),
  ], enemyTypes: ['caballeroHueco'], triggeredBy: 'p1').state;
  s = engine.nextTurn(s).state;
  final step = engine.command(s, 'p1', const UltimateCommand())!;
  return step.events
      .whereType<DamageEvent>()
      .where((e) => e.targetId.startsWith('e'))
      .fold(0, (a, e) => a + e.amount);
}

void main() {
  tearDown(BalanceRegistries.restore);

  test('las 50 ULT de jugador están en el índice de Balance', () {
    final idx = buildAdminIndex(BalanceBase.standard());
    final ults = idx.where((e) => e.kind == BalanceKind.ultimate).map((e) => e.id);
    for (final id in kUltV2.keys) {
      expect(ults, contains(id));
    }
  });

  test('un parche a una ULT de jugador cambia su efecto y se revierte', () {
    final before = _ultDamage(GameCatalog.standard);
    final r = BalancePatch.parse(
        jsonEncode({
          'schema': 1,
          'basedOn': '0.5.0',
          'overrides': {
            'ultimate': {
              'ult2_golpeMaestro': {'power': 10.0},
            },
          },
        }),
        BalanceBase.standard());
    expect(r.issues.where((i) => i.error), isEmpty);
    final patched = r.patch.applyTo(GameCatalog.standard);
    expect(patched.playerUlts['ult2_golpeMaestro']!.power, 10.0);
    expect(_ultDamage(patched), greaterThan(before));
    // Sin parche vuelve al valor del código.
    expect(_ultDamage(GameCatalog.standard), before);
  });
}
