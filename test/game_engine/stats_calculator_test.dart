import 'package:flutter_test/flutter_test.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/class_def.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';

void main() {
  final emptyCatalog = const PassiveTreeCatalog(
    nodes: {},
    startNodeByClass: {'guerrero': 's_gue'},
    exclusions: {},
  );
  final calculator = StatsCalculator(
    classes: const {
      'guerrero': ClassDef(
        id: 'guerrero', name: 'Guerrero',
        allowedWeaponTypes: ['espada'], startWeaponId: 'espada_bronce',
      ),
    },
    treeRules: PassiveTreeRules(emptyCatalog),
  );

  final espadaBronce = const WeaponDef(
    id: 'espada_bronce', name: 'Espada de Bronce', classId: 'guerrero',
    type: 'espada', tier: 1, price: 0,
    requirements: {},
    atk: PowerFormula(base: 8, coefficients: {Attribute.fue: 0.5, Attribute.des: 0.1}),
  );

  test('stats base sin mejoras ni árbol coinciden con la fórmula de referencia', () {
    final build = PlayerBuild(
      classId: 'guerrero',
      level: 1,
      attributes: PlayerAttributes.base({
        Attribute.vit: 10, Attribute.esp: 4, Attribute.agi: 6,
        Attribute.fue: 12, Attribute.des: 6,
      }),
      equippedWeapon: espadaBronce,
    );
    final stats = calculator.calculate(build);

    // Mismos valores que el prototipo HTML para este build exacto
    // (verificados con Playwright durante la sesión de migración).
    expect(stats.maxHp, 20 + 10 * 4 + 1 * 2); // 62
    expect(stats.attack, (8 + 12 * 0.5 + 6 * 0.1).round()); // 15
    expect(stats.critChance, closeTo(0.03 + 6 * 0.012, 1e-9));
  });

  test('las mejoras de arma por estadística suman independientes', () {
    final build = PlayerBuild(
      classId: 'guerrero',
      level: 1,
      attributes: PlayerAttributes.base({
        Attribute.vit: 10, Attribute.esp: 4, Attribute.agi: 6,
        Attribute.fue: 12, Attribute.des: 6,
      }),
      equippedWeapon: espadaBronce,
      weaponUpgrades: const WeaponUpgradeLevels(pow: 2, crit: 1, spd: 1),
    );
    final base = calculator.calculate(build.copyWithNoUpgrades());
    final upgraded = calculator.calculate(build);

    expect(upgraded.attack, greaterThan(base.attack));
    expect(upgraded.critChance, greaterThan(base.critChance));
    expect(upgraded.speed, greaterThan(base.speed));
  });
}

extension on PlayerBuild {
  PlayerBuild copyWithNoUpgrades() => PlayerBuild(
        classId: classId,
        level: level,
        attributes: attributes,
        equippedWeapon: equippedWeapon,
      );
}
