import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Rework del Paladín (v0.5, docs/specs/ascension.md § 4): sin kit de
/// clase; Aura Restauradora, Fortaleza y Protección son el kit del
/// Guardián, mejorado.

const _classicKit = ['proteccion', 'fortaleza', 'aura'];

BattleEngine _engine() => BattleEngine(stats: statsCalc, random: () => 0.99);

/// Un Paladín nivel 50 (perfil normalizado) con la ascensión [asc].
PlayerProfile _paladin({String? asc, String weapon = 'espada_escudo_novato'}) {
  var p = zoneProgression.normalize(PlayerProfile(
    name: 'Pal',
    classId: 'paladin',
    level: 50,
    items: [ItemInstance.common('w1', weapon)],
  ));
  final third = p.points ~/ 3;
  p = zoneProgression.allocate(p, {
    Attribute.vit: third,
    Attribute.esp: third,
    Attribute.fue: p.points - 2 * third,
  })!;
  return zoneProgression.normalize(p.copyWith(
      equipped: 'w1',
      ascension: AscensionProgress(trials: const {1}, id: asc)));
}

Combatant _combatant(PlayerProfile p) => _engine()
    .start(party: [
      BattlePartyMember(
          id: 'p1', name: 'Pal', build: zoneProgression.buildOf(p))
    ], enemyTypes: const ['slime'])
    .state
    .party
    .single;

void main() {
  group('Paladín base', () {
    test('ninguna clase tiene kit fijo', () {
      for (final c in kClasses.values) {
        expect(c.kitSkillIds, isEmpty, reason: c.id);
      }
    });

    test('sus habilidades son solo las del arma', () {
      final p = _paladin();
      expect(zoneProgression.weaponSkills(p), kWeapons['espada_escudo_novato']!.skillIds);
      final c = _combatant(p);
      expect(c.skillIds, ['estocada', 'golpeEscudo', 'sanar']);
      for (final id in _classicKit) {
        expect(c.skillIds, isNot(contains(id)), reason: id);
      }
      // Los rasgos de clase siguen.
      expect(c.stunOnAttackChance, 0.03);
      expect(c.pierceWeakness, 1.5);
    });

    test('con otra arma, otras habilidades (se puede buildear)', () {
      final c = _combatant(_paladin(weapon: 'maza_escudo_bastion'));
      expect(c.skillIds, ['provocar', 'escudoFe']);
    });

    test('Templario: armas + su kit, sin el kit clásico', () {
      final c = _combatant(_paladin(asc: 'templario'));
      expect(c.skillIds, ['estocada', 'golpeEscudo', 'sanar', 'castigo', 'luzCegadora']);
    });

    test('las armas de Paladín cubren apoyo y defensa sin el kit', () {
      final pal = kWeapons.values.where((w) => w.classId == 'paladin').toList();
      Iterable<int> levelsWith(String skill) =>
          pal.where((w) => w.skillIds.contains(skill)).map((w) => w.level);
      // El arma inicial ya trae una cura.
      expect(kWeapons[kClasses['paladin']!.startWeaponId]!.skillIds, contains('sanar'));
      for (final s in ['sanar', 'bendicion', 'provocar', 'escudoFe']) {
        expect(levelsWith(s), isNotEmpty, reason: s);
      }
      // Cada tipo con escudo tiene al menos una cura salvo el martillo
      // (línea de daño a propósito, loot.md § 8.2).
      for (final t in ['espada+escudo', 'maza+escudo']) {
        expect(
            pal.any((w) =>
                w.type == t &&
                w.skillIds.any((s) => kSkills[s]!.kind == SkillKind.heal)),
            isTrue,
            reason: t);
      }
      for (final w in kWeapons.values) {
        expect(w.skillIds.length, lessThanOrEqualTo(3), reason: w.id);
      }
    });
  });

  group('Guardián: el kit clásico, mejorado', () {
    test('al ascender tiene Protección, Fortaleza y Aura Restauradora', () {
      expect(kAscensions['guardian']!.skillIds, _classicKit);
      final c = _combatant(_paladin(asc: 'guardian'));
      expect(c.skillIds, ['estocada', 'golpeEscudo', 'sanar', ..._classicKit]);
      // Égida Grupal y Juramento ya no existen.
      expect(kSkills.containsKey('egidaGrupal'), isFalse);
      expect(kSkills.containsKey('juramento'), isFalse);
    });

    test('los números del kit', () {
      final pro = kSkills['proteccion']!;
      expect((pro.mp, pro.kind, pro.selfBuff!.stat, pro.selfBuff!.value),
          (5, SkillKind.protect, BuffStat.guard, 0.20));
      final fort = kSkills['fortaleza']!;
      expect((fort.mp, fort.amount, fort.partyShield, fort.partyShieldTurns),
          (6, 2, 0.15, 3));
      expect(fort.partyBuffs.single.value, 0.10);
      final aura = kSkills['aura']!;
      expect((aura.mp, aura.kind, aura.power), (6, SkillKind.regen, 1.0));
    });

    BattleState duo(PlayerProfile g) {
      final e = _engine();
      final s = e.start(party: [
        BattlePartyMember(id: 'g', name: 'Gua', build: zoneProgression.buildOf(g)),
        BattlePartyMember(
            id: 'm',
            name: 'Ana',
            build: zoneProgression.buildOf(zoneProgression
                .normalize(PlayerProfile(name: 'Ana', classId: 'maga', level: 50)))),
      ], enemyTypes: const ['slime'], triggeredBy: 'g').state;
      return e.nextTurn(s).state;
    }

    test('Fortaleza: DEF +2 propia, escudo 15% y −10% daño al grupo', () {
      final s = duo(_paladin(asc: 'guardian'));
      expect(s.currentId, 'g');
      final g = s.byId('g')!;
      final step = _engine().command(s, 'g', const SkillCommand('fortaleza'))!;
      final g2 = step.state.byId('g')!, m2 = step.state.byId('m')!;
      expect(g2.bonusDefense, 2);
      expect(m2.shield, (g.maxHp * 0.15).round());
      expect(m2.effectTotal(BuffStat.guard), closeTo(0.10, 1e-9));
      expect(g2.mp, g.mp - 6);
    });

    test('Protección: protege y el Guardián recibe −20% de daño', () {
      final s = duo(_paladin(asc: 'guardian'));
      final step = _engine().command(s, 'g', const SkillCommand('proteccion'))!;
      final g2 = step.state.byId('g')!;
      expect(g2.protecting, isTrue);
      expect(g2.effectTotal(BuffStat.guard), closeTo(0.20, 1e-9));
    });

    test('Aura Restauradora: cura MAG × 1.0 + 4 y Regeneración', () {
      final s = duo(_paladin(asc: 'guardian'));
      final m = s.byId('m')!..hp = 1;
      final g = s.byId('g')!;
      final step = _engine().command(s, 'g', const SkillCommand('aura'))!;
      final m2 = step.state.byId('m')!;
      final heal = ((g.magic * 1.0 + 4) * (1 + g.healBonus)).round();
      expect(m2.hp, 1 + heal);
      expect(m2.stacks(StatusKind.regen), greaterThan(0));
      expect(m.id, 'm');
    });
  });

  group('migración', () {
    test('un Paladín v0.4 carga igual y queda con las habilidades del arma', () {
      final v04 = {
        'pv': 3,
        'name': 'Viejo',
        'cls': 'paladin',
        'lvl': 20,
        'xp': 0,
        'cr': 50,
        'st': {'VIT': 40, 'ESP': 20, 'AGI': 10, 'FUE': 20, 'DES': 5},
        'pts': 0,
        'items': [
          {'u': 'a', 'b': 'espada_escudo_novato'},
          // Un traslado imposible (a mano): el kit de una ascensión nunca
          // viaja en un arma.
          {'u': 'b', 'b': 'maza_escudo_roble', 'r': 'epico', 's': ['aura', 'provocar']},
        ],
        'eq': 'b',
        'tree': [],
        'tv': 2,
        'zu': 4,
      };
      final p = zoneProgression.normalize(PlayerProfile.fromJson(v04));
      expect(p.classId, 'paladin');
      expect(p.ascension.isEmpty, isTrue);
      expect(p.item('b')!.extraSkills, ['provocar']);
      expect(zoneProgression.weaponSkills(p), ['golpeEscudo', 'sanar', 'provocar']);
      final c = _combatant(p);
      for (final id in _classicKit) {
        expect(c.skillIds, isNot(contains(id)), reason: id);
      }
      // Ida y vuelta sin perder nada.
      final again = zoneProgression.normalize(PlayerProfile.fromJson(p.toJson()));
      expect(again.toJson(), p.toJson());
    });

    test('ItemRules.sanitize descarta habilidades del kit de ascensión', () {
      const items = ItemRules();
      final i = items.sanitize(const ItemInstance(
          uid: 'x',
          baseId: 'espada_bronce',
          rarity: Rarity.epico,
          extraSkills: ['fortaleza', 'sangria', 'ignea']))!;
      expect(i.extraSkills, ['ignea']);
    });
  });
}
