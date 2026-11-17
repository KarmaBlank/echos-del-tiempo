import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Guerrero nivel 3 con FUE 14 / DES 8 (2 puntos sin repartir).
PlayerProfile _warriorL3({int credits = 0, List<String>? inventory}) =>
    progression.normalize(PlayerProfile.fromJson({
      'name': 'Ana',
      'cls': 'guerrero',
      'lvl': 3,
      'cr': credits,
      'st': {'VIT': 10, 'ESP': 4, 'AGI': 6, 'FUE': 14, 'DES': 8},
      'pts': 2,
      'inv': inventory ?? ['espada_bronce'],
      'eq': 'espada_bronce',
    }));

void main() {
  group('niveles', () {
    test('xpNeed = 10 + l² × 8', () {
      expect(ProgressionRules.xpNeed(1), 18);
      expect(ProgressionRules.xpNeed(2), 42);
      expect(ProgressionRules.xpNeed(7), 402);
    });

    test('gainXp sube varios niveles de una y da 3 puntos por nivel', () {
      final g = progression.gainXp(newProfile('A', 'maga'), 70);
      expect(g.levelsGained, 2);
      expect(g.profile.level, 3);
      expect(g.profile.xp, 70 - 18 - 42);
      expect(g.profile.points, 6);
    });

    test('gainXp sin llegar al siguiente nivel', () {
      final g = progression.gainXp(newProfile('A', 'maga'), 17);
      expect(g.levelsGained, 0);
      expect(g.profile.level, 1);
      expect(g.profile.xp, 17);
    });
  });

  group('atributos', () {
    test('allocate: negativos cuentan 0, total > 0 y ≤ puntos', () {
      final p = _warriorL3();
      final next = progression.allocate(p, {Attribute.fue: 2, Attribute.vit: -5})!;
      expect(next.attributes[Attribute.fue], 16);
      expect(next.attributes[Attribute.vit], 10);
      expect(next.points, 0);
      expect(progression.allocate(p, {Attribute.fue: 3}), isNull);
      expect(progression.allocate(p, {Attribute.fue: 0}), isNull);
    });

    test('previewAllocation no cambia el perfil', () {
      final p = _warriorL3();
      final now = progression.derivedStats(p);
      final preview = progression.previewAllocation(p, {Attribute.vit: 2});
      expect(preview.maxHp, greaterThan(now.maxHp));
      expect(p.attributes[Attribute.vit], 10);
    });

    test('resetBuild: atributos base y todos los puntos', () {
      final p = progression.resetBuild(_warriorL3());
      expect(p.attributes[Attribute.fue], 12);
      expect(p.attributes[Attribute.des], 6);
      expect(p.points, 6);
    });

    test('resetBuild equipa la inicial si el arma deja de cumplir requisitos', () {
      var p = _warriorL3(credits: 300);
      p = progression.buyWeapon(p, 'espada_ignea')!;
      p = progression.equip(p, 'espada_ignea')!;
      p = progression.resetBuild(p);
      expect(p.equipped, 'espada_bronce');
    });

    test('changeClass: árbol vacío, arma inicial y atributos de la clase nueva', () {
      var p = _warriorL3();
      p = progression.takeNode(p, 'gue_a0')!;
      final m = progression.changeClass(p, 'maga')!;
      expect(m.classId, 'maga');
      expect(m.tree, isEmpty);
      expect(m.equipped, 'baculo_aprendiz');
      expect(m.inventory, containsAll(['espada_bronce', 'baculo_aprendiz']));
      expect(m.attributes[Attribute.esp], 13);
      expect(m.points, 6);
      expect(progression.changeClass(m, 'maga'), isNull);
      expect(progression.changeClass(m, 'ninja'), isNull);
    });
  });

  group('armas y tienda', () {
    test('buyWeapon: de su clase, a la venta, no repetida y con créditos', () {
      final p = _warriorL3(credits: 300);
      final b = progression.buyWeapon(p, 'espada_ignea')!;
      expect(b.credits, 0);
      expect(b.inventory, contains('espada_ignea'));
      expect(progression.buyWeapon(b, 'espada_ignea'), isNull);
      expect(progression.buyWeapon(p, 'baculo_fuego'), isNull); // otra clase
      expect(progression.buyWeapon(p, 'espada_bronce'), isNull); // precio 0
      expect(progression.buyWeapon(p, 'hacha_rompe'), isNull); // 650 > 300
    });

    test('equip exige tenerla y cumplir requisitos', () {
      var p = _warriorL3(credits: 2000);
      expect(progression.equip(p, 'espada_ignea'), isNull); // no la tiene
      p = progression.buyWeapon(p, 'espada_ignea')!; // FUE 14, DES 8: cumple
      p = progression.buyWeapon(p, 'hacha_rompe')!; // FUE 18: no cumple
      expect(progression.equip(p, 'espada_ignea')!.equipped, 'espada_ignea');
      expect(progression.equip(p, 'hacha_rompe'), isNull);
      expect(progression.canEquip(p, 'hacha_rompe'), isFalse);
    });

    test('buyItem: precio y tope de 9', () {
      final p = _warriorL3(credits: 100);
      final b = progression.buyItem(p, BattleItem.potion)!;
      expect(b.potions, 4);
      expect(b.credits, 70);
      final e = progression.buyItem(p, BattleItem.ether)!;
      expect(e.ethers, 2);
      expect(e.credits, 60);
      expect(progression.buyItem(p.copyWith(potions: 9), BattleItem.potion), isNull);
      expect(progression.buyItem(p.copyWith(credits: 29), BattleItem.potion), isNull);
    });
  });

  group('herrería', () {
    test('upCost = round(max(precio, 200) × 0.22 × (l + 1))', () {
      expect(progression.upgradeCost('espada_bronce', 0), 44);
      expect(progression.upgradeCost('espada_bronce', 4), 220);
      expect(progression.upgradeCost('espada_ignea', 0), 66);
      expect(progression.upgradeCost('mandoble_eco', 2), 924);
    });

    test('sube de a 1 hasta 5, cobra y cambia los stats', () {
      var p = _warriorL3(credits: 10000);
      final before = progression.derivedStats(p);
      for (var l = 0; l < 5; l++) {
        final next = progression.upgrade(p, 'espada_bronce', UpgradeStat.pow)!;
        expect(next.credits, p.credits - progression.upgradeCost('espada_bronce', l));
        p = next;
      }
      expect(p.upgradesFor('espada_bronce').pow, 5);
      expect(progression.upgrade(p, 'espada_bronce', UpgradeStat.pow), isNull);
      expect(progression.derivedStats(p).attack, greaterThan(before.attack));
      expect(progression.weaponDisplayName(p, 'espada_bronce'), 'Espada de Bronce +5');
    });

    test('Defensa solo en armas con escudo', () {
      final g = _warriorL3(credits: 1000);
      expect(progression.upgrade(g, 'espada_bronce', UpgradeStat.def), isNull);
      final pal = progression
          .normalize(PlayerProfile(classId: 'paladin', credits: 1000, level: 1))
          .copyWith(inventory: ['espada_escudo_novato', 'maza_escudo_roble']);
      expect(progression.upgrade(pal, 'maza_escudo_roble', UpgradeStat.def)!
          .upgradesFor('maza_escudo_roble')
          .def, 1);
      expect(progression.upgradeStatsFor(kWeaponsShield), contains(UpgradeStat.def));
    });

    test('no mejora armas que no tiene ni de otra clase', () {
      final p = _warriorL3(credits: 1000, inventory: ['espada_bronce', 'baculo_fuego']);
      expect(progression.upgrade(p, 'espada_ignea', UpgradeStat.crit), isNull);
      expect(progression.upgrade(p, 'baculo_fuego', UpgradeStat.crit), isNull);
    });
  });

  group('fusión', () {
    PlayerProfile base({int credits = 500}) {
      final p = _warriorL3(
          credits: credits,
          inventory: ['espada_bronce', 'espada_ignea', 'hacha_rompe']);
      return p.copyWith(upgrades: {
        'hacha_rompe': const WeaponUpgradeLevels(pow: 2),
      }, fused: {
        'hacha_rompe': 'giro',
      });
    }

    test('el arma base hereda la habilidad y la otra se consume', () {
      final f = progression.fuse(base(), 'espada_ignea', 'hacha_rompe', 'sismo')!;
      expect(f.credits, 300);
      expect(f.fused, {'espada_ignea': 'sismo'});
      expect(f.inventory, ['espada_bronce', 'espada_ignea']);
      expect(f.upgrades.containsKey('hacha_rompe'), isFalse);
      expect(progression.weaponSkills(f, 'espada_ignea'), ['ignea', 'giro', 'sismo']);
    });

    test('validaciones', () {
      final p = base();
      expect(progression.fuse(p, 'espada_ignea', 'espada_bronce', 'giro'), isNull,
          reason: 'no se sacrifica la inicial');
      expect(progression.fuse(p, 'hacha_rompe', 'espada_ignea', 'ignea'), isNotNull);
      final eq = p.copyWith(equipped: 'espada_ignea');
      expect(progression.fuse(eq, 'hacha_rompe', 'espada_ignea', 'ignea'), isNull,
          reason: 'no se sacrifica la equipada');
      expect(progression.fuse(p, 'espada_ignea', 'hacha_rompe', 'ignea'), isNull,
          reason: 'la habilidad debe ser propia del arma sacrificada');
      expect(progression.fuse(p, 'espada_ignea', 'espada_ignea', 'ignea'), isNull);
      expect(progression.fuse(base(credits: 199), 'espada_ignea', 'hacha_rompe', 'sismo'),
          isNull);
    });

    test('weaponSkills incluye el kit de clase del Paladín', () {
      final pal = newProfile('P', 'paladin');
      expect(progression.weaponSkills(pal),
          ['aura', 'fortaleza', 'proteccion', 'estocada', 'golpeEscudo']);
    });
  });

  group('árbol', () {
    test('takeNode necesita puntos y conexión', () {
      expect(progression.takeNode(newProfile('A', 'guerrero'), 'gue_a0'), isNull);
      final p = _warriorL3();
      final t = progression.takeNode(p, 'gue_a0')!;
      expect(t.tree, ['gue_a0']);
      expect(progression.takeNode(p, 'mag_a0'), isNull);
      expect(progression.resetTree(t).tree, isEmpty);
    });
  });

  group('normalize (addPlayer / loadProfile)', () {
    test('corrige un perfil inválido', () {
      final p = progression.normalize(PlayerProfile.fromJson({
        'name': 'NombreDemasiadoLargo',
        'cls': 'ninja',
        'lvl': 0,
        'xp': -5,
        'cr': -1,
        'st': {'VIT': 99},
        'pts': 3,
        'inv': ['espada_ignea', 'nada', 42],
        'eq': 'nada',
        'pot': 50,
        'eter': -2,
        'up': {
          'espada_ignea': {'pow': 9, 'def': 3, 'xx': 1},
          'nada': {'pow': 1},
        },
        'fuse': {'espada_ignea': 'giro', 'nada': 'giro', 'espada_bronce': 'nope'},
        'tree': ['gue_a1', 'gue_a0'],
      }));
      expect(p.name, 'NombreDema');
      expect(p.classId, 'guerrero');
      expect(p.level, 1);
      expect(p.xp, 0);
      expect(p.credits, 0);
      expect(p.attributes[Attribute.vit], 10);
      expect(p.points, 0);
      expect(p.inventory, ['espada_ignea', 'espada_bronce']);
      expect(p.equipped, 'espada_bronce');
      expect(p.potions, 9);
      expect(p.ethers, 0);
      expect(p.upgrades.keys, ['espada_ignea']);
      expect(p.upgradesFor('espada_ignea').pow, 5);
      expect(p.upgradesFor('espada_ignea').def, 0);
      expect(p.fused, {'espada_ignea': 'giro'});
      expect(p.tree, isEmpty, reason: 'nivel 1: sin puntos de árbol');
    });

    test('valida el árbol en orden', () {
      final p = progression.normalize(PlayerProfile.fromJson({
        'cls': 'guerrero',
        'lvl': 4,
        'tree': ['gue_a1', 'gue_a0', 'gue_a1', 'mag_a0', 's_gue', 'gue_b0', 'gue_b1'],
      }));
      // gue_a1 no conecta todavía; gue_a0 sí; después gue_a1 ya conecta;
      // mag_a0 no conecta; s_gue ya lo tiene; gue_b0 entra y no quedan puntos.
      expect(p.tree, ['gue_a0', 'gue_a1', 'gue_b0']);
    });

    test('perfil nuevo: 3 pociones, 1 de maná y arma inicial', () {
      final p = newProfile('Leo', 'tirador');
      expect(p.potions, 3);
      expect(p.ethers, 1);
      expect(p.inventory, ['arco_corto']);
      expect(p.equipped, 'arco_corto');
      expect(p.points, 0);
    });

    test('atributos válidos se conservan', () {
      final p = _warriorL3();
      expect(p.attributes[Attribute.fue], 14);
      expect(p.points, 2);
    });
  });
}

const kWeaponsShield = WeaponDef(
  id: 'test',
  name: 'Escudo',
  classId: 'paladin',
  type: 'espada+escudo',
  tier: 0,
  price: 0,
  requirements: {},
  atk: PowerFormula(base: 1),
  shieldDefense: 2,
);
