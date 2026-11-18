import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_patch.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_registries.dart';
import 'package:echos_del_tiempo/game_engine/data/affixes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

BalanceParseResult _parse(Object json) =>
    BalancePatch.parse(jsonEncode(json), BalanceBase.standard());

Map<String, Object?> _ov(Map<String, Object?> overrides) =>
    {'schema': 1, 'basedOn': '0.5.0', 'overrides': overrides};

/// Una batalla completa del guerrero contra 2 limos con azar fijo; devuelve
/// todos los eventos como texto (para comparar catálogos).
List<String> _battleLog(GameCatalog catalog) {
  final stats = StatsCalculator(
      classes: catalog.classes, treeRules: PassiveTreeRules(kPassiveTree));
  final engine =
      BattleEngine(stats: stats, catalog: catalog, random: mulberry32(7));
  final cls = kClasses['guerrero']!;
  var s = engine
      .start(party: [
        BattlePartyMember(
          id: 'p1',
          name: 'G',
          build: PlayerBuild(
            classId: 'guerrero',
            level: 3,
            attributes: PlayerAttributes.base(cls.baseAttributes),
            equippedWeapon: catalog.weapons[cls.startWeaponId]!,
          ),
        ),
      ], enemyTypes: ['slime', 'slime'])
      .state;
  final log = <String>[];
  for (var i = 0; i < 300 && !s.ended; i++) {
    BattleStep? step;
    if (s.currentId == null) {
      step = engine.nextTurn(s);
    } else if (!s.current!.isPlayer) {
      step = engine.enemyTurn(s);
    } else {
      step = engine.command(s, 'p1', const SkillCommand('giro')) ??
          engine.command(s, 'p1', const AttackCommand());
    }
    s = step!.state;
    for (final e in step.events) {
      log.add(switch (e) {
        DamageEvent() => 'dmg ${e.targetId} ${e.amount}',
        _ => e.runtimeType.toString(),
      });
    }
  }
  log.add('end ${s.outcome?.victory}');
  return log;
}

void main() {
  tearDown(BalanceRegistries.restore);

  group('parche vacío', () {
    test('el balance.json del repo es válido y no cambia nada', () {
      final r = BalancePatch.parse(
          File('assets/balance/balance.json').readAsStringSync(),
          BalanceBase.standard());
      expect(r.issues.where((i) => i.error), isEmpty);
      expect(r.patch.isEmpty, isTrue);
      expect(r.patch.hash, kBaseBalanceHash);
      expect(identical(r.patch.applyTo(GameCatalog.standard), GameCatalog.standard),
          isTrue);
    });

    test('texto vacío / overrides vacíos / valores iguales al código', () {
      expect(BalancePatch.parse('', BalanceBase.standard()).patch.isEmpty, isTrue);
      final same = _parse(_ov({
        'skill': {
          'sismo': {'power': 1.2, 'mp': 6}
        },
        'enemy': {
          'slime': {'hp': 30}
        },
      }));
      expect(same.issues, isEmpty);
      expect(same.patch.isEmpty, isTrue);
      expect(same.patch.hash, kBaseBalanceHash);
    });

    test('la batalla es idéntica con el parche vacío instalado', () {
      final before = _battleLog(GameCatalog.standard);
      final r = _parse(_ov({}));
      r.patch.installRegistries();
      expect(_battleLog(r.patch.applyTo(GameCatalog.standard)), before);
    });
  });

  group('overrides válidos', () {
    test('habilidad, arma, enemigo, ULT, clase y dual', () {
      final r = _parse(_ov({
        'skill': {
          'sismo': {
            'power': 1.4,
            'mp': 5,
            'status': {'kind': 'burn', 'stacks': 2, 'chance': 0.5},
          }
        },
        'weapon': {
          'hacha_rompe': {
            'level': 5,
            'atk': {'base': 18, 'fue': 0.9},
            'requirements': {'fue': 20},
          }
        },
        'enemy': {
          'slime': {'hp': 40, 'inflicts': null}
        },
        'ultimate': {
          'espada': {'power': 3.3}
        },
        'class': {
          'paladin': {'baseDefense': 4}
        },
        'dual': {
          'guerrero+maga': {'power': 1.7}
        },
      }));
      expect(r.issues, isEmpty);
      final c = r.patch.applyTo(GameCatalog.standard);
      final sismo = c.skills['sismo']!;
      expect(sismo.power, 1.4);
      expect(sismo.mp, 5);
      expect(sismo.status!.kind, StatusKind.burn);
      expect(sismo.status!.chance, 0.5);
      expect(sismo.allTargets, isTrue, reason: 'lo no tocado queda igual');
      final hacha = c.weapons['hacha_rompe']!;
      expect(hacha.level, 5);
      expect(hacha.atk.base, 18);
      expect(hacha.atk.coefficients[Attribute.fue], 0.9);
      expect(hacha.requirements, {Attribute.fue: 20});
      expect(hacha.skillIds, ['sismo', 'rompearmaduras']);
      expect(c.enemies['slime']!.hp, 40);
      expect(c.enemies['slime']!.inflicts, isNull);
      expect(c.ultimates['espada']!.power, 3.3);
      expect(c.classes['paladin']!.baseDefense, 4);
      expect(c.duals['guerrero+maga']!.power, 1.7);
      // El resto, el mismo objeto.
      expect(identical(c.skills['giro'], GameCatalog.standard.skills['giro']), isTrue);
      expect(c.balanceHash, r.patch.hash);
      expect(c.balanceHash, startsWith('b1-'));
    });

    test('ida y vuelta por JSON conserva el hash', () {
      final r = _parse(_ov({
        'enemy': {
          'bat': {'speed': 12.5, 'xp': 9}
        },
        'skill': {
          'chispa': {'power': 1.7}
        },
      }));
      final again = BalancePatch.parse(r.patch.toPrettyJson(), BalanceBase.standard());
      expect(again.issues, isEmpty);
      expect(again.patch.hash, r.patch.hash);
      // El orden de las claves no importa.
      final swapped = _parse(_ov({
        'skill': {
          'chispa': {'power': 1.7}
        },
        'enemy': {
          'bat': {'xp': 9, 'speed': 12.5}
        },
      }));
      expect(swapped.patch.hash, r.patch.hash);
      expect(_parse(_ov({
        'skill': {
          'chispa': {'power': 1.8}
        },
      })).patch.hash, isNot(r.patch.hash));
    });

    test('desactivar una habilidad la saca de todas las armas', () {
      final r = _parse(_ov({
        'skill': {
          'giro': {'disabled': true}
        },
      }));
      expect(r.issues, isEmpty);
      final c = r.patch.applyTo(GameCatalog.standard);
      expect(c.weapons.values.any((w) => w.skillIds.contains('giro')), isFalse);
      expect(c.weapons['espada_bronce']!.skillIds, ['embestida']);
      expect(c.skills.containsKey('giro'), isTrue, reason: 'sigue en el catálogo');
    });

    test('el motor usa el número parcheado', () {
      int giroDamage(GameCatalog catalog) {
        final stats = StatsCalculator(
            classes: catalog.classes, treeRules: PassiveTreeRules(kPassiveTree));
        final engine =
            BattleEngine(stats: stats, catalog: catalog, random: () => 0.99);
        final cls = kClasses['guerrero']!;
        var s = engine.start(party: [
          BattlePartyMember(
            id: 'p1',
            name: 'G',
            build: PlayerBuild(
              classId: 'guerrero',
              level: 1,
              attributes: PlayerAttributes.base(cls.baseAttributes),
              equippedWeapon: catalog.weapons['espada_bronce']!,
            ),
          ),
        ], enemyTypes: ['golem'], triggeredBy: 'p1').state;
        s = engine.nextTurn(s).state;
        expect(s.currentId, 'p1');
        final step = engine.command(s, 'p1', const SkillCommand('giro'))!;
        return step.events
            .whereType<DamageEvent>()
            .fold(0, (n, e) => n + e.amount);
      }

      final base = giroDamage(GameCatalog.standard);
      final r = _parse(_ov({
        'skill': {
          'giro': {'power': 2.0}
        },
      }));
      final patched = giroDamage(r.patch.applyTo(GameCatalog.standard));
      expect(patched, greaterThan(base));
      expect(patched / base, closeTo(2.0, 0.25));
    });
  });

  group('registros globales', () {
    test('afijo, nodo y mecánica se instalan y se restauran', () {
      final feroz = kAffixes['feroz']!;
      final node = kPassiveTree.nodes.values.firstWhere((n) => n.effects.containsKey('atk'));
      final frenesi = kMechanics['frenesi']!;
      final r = _parse(_ov({
        'affix': {
          'feroz': {
            'weight': 1500,
            'tiers': [
              {'tier': 1, 'minLevel': 40, 'min': 35, 'max': 45, 'weight': 20},
            ],
          },
          'veloz': {'disabled': true},
        },
        'passiveNode': {
          node.id: {
            'effects': {'atk': 0.5}
          }
        },
        'mechanic': {
          'frenesi': {
            'effects': [
              {'kind': 'buffSelf', 'value': 0.3, 'turns': 3, 'stat': 'speed'},
            ],
            'description': 'Al hacer crítico: +30% velocidad por 3 turnos.',
          },
        },
      }));
      expect(r.issues, isEmpty);
      r.patch.installRegistries();
      expect(kAffixes['feroz']!.weight, 1500);
      expect(kAffixes['feroz']!.tiers.single.max, 45);
      expect(kAffixes['veloz']!.weight, 0);
      expect(kPassiveTree.nodes[node.id]!.effects, {'atk': 0.5});
      expect(kMechanics['frenesi']!.effects.single.value, 0.3);
      expect(mechanicById('frenesi')!.effects.single.turns, 3);
      // Instalar otro parche parte del código, no del anterior.
      _parse(_ov({})).patch.installRegistries();
      expect(identical(kAffixes['feroz'], feroz), isTrue);
      r.patch.installRegistries();
      BalanceRegistries.restore();
      expect(identical(kAffixes['feroz'], feroz), isTrue);
      expect(identical(kPassiveTree.nodes[node.id], node), isTrue);
      expect(identical(kMechanics['frenesi'], frenesi), isTrue);
    });

    test('mecánica con números nuevos y la descripción vieja → aviso', () {
      final r = _parse(_ov({
        'mechanic': {
          'frenesi': {'chance': 0.5}
        },
      }));
      expect(r.hasErrors, isFalse);
      expect(r.issues.single.path, 'mechanic.frenesi.description');
      expect(r.patch.isEmpty, isFalse);
    });
  });

  group('validación: rechaza sin romper', () {
    test('JSON roto, raíz inválida y schema futuro → parche vacío + error', () {
      for (final text in ['{oops', '[1,2]', jsonEncode({'schema': 99})]) {
        final r = BalancePatch.parse(text, BalanceBase.standard());
        expect(r.patch.isEmpty, isTrue, reason: text);
        expect(r.hasErrors, isTrue, reason: text);
      }
    });

    test('cada entrada inválida se descarta sola con un error claro', () {
      final r = _parse(_ov({
        'pocion': {'x': {}},
        'skill': {
          'noExiste': {'power': 2},
          'sismo': {
            'power': 'mucho',
            'mp': 500,
            'status': {'kind': 'lava', 'stacks': 1},
            'colorin': 3,
            'delay': 0.5, // válido: se aplica igual
          },
          'chispa': {
            'extraStatuses': [
              {'kind': 'burn', 'stacks': 0},
            ],
          },
        },
        'weapon': {
          'espada_bronce': {
            'skillIds': ['giro', 'inventada'],
            'disabled': true,
          },
        },
        'affix': {
          'feroz': {
            'tiers': [
              {'tier': 1, 'minLevel': 40, 'min': 50, 'max': 10, 'weight': 20},
            ],
          },
        },
        'enemy': {
          'slime': {'hp': 0, 'speed': double.nan.toString()},
        },
      }));
      String msg(String path) =>
          r.issues.firstWhere((i) => i.path == path).message;
      expect(msg('pocion'), contains('desconocido'));
      expect(msg('skill.noExiste'), contains('no existe'));
      expect(msg('skill.sismo.power'), contains('número'));
      expect(msg('skill.sismo.mp'), contains('rango'));
      expect(msg('skill.sismo.status'), contains('lava'));
      expect(msg('skill.sismo.colorin'), contains('desconocido'));
      expect(msg('skill.chispa.extraStatuses'), contains('stacks'));
      expect(msg('weapon.espada_bronce.skillIds'), contains('inventada'));
      expect(msg('weapon.espada_bronce.disabled'), contains('no se pueden desactivar'));
      expect(msg('affix.feroz.tiers'), contains('menor que mínimo'));
      expect(msg('enemy.slime.hp'), contains('rango'));
      expect(msg('enemy.slime.speed'), contains('número'));
      // Lo válido sobrevive.
      expect(r.patch.overrides[BalanceKind.skill]!['sismo'], {'delay': 0.5});
      final c = r.patch.applyTo(GameCatalog.standard);
      expect(c.skills['sismo']!.delay, 0.5);
      expect(c.skills['sismo']!.power, 1.2);
      expect(c.weapons['espada_bronce']!.skillIds, ['giro', 'embestida']);
    });

    test('edición del admin: volver al valor base quita la entrada', () {
      var p = BalancePatch.empty;
      p = p.withField(BalanceKind.skill, 'sismo', 'power', 1.5, baseValue: 1.2);
      expect(p.isEmpty, isFalse);
      expect(p.entityCount, 1);
      p = p.withField(BalanceKind.skill, 'sismo', 'power', 1.2, baseValue: 1.2);
      expect(p.isEmpty, isTrue);
      expect(p.toJson()['overrides'], isEmpty);
    });
  });
}
