// v0.9.1: Quebrar sin daño en una ranura base quitable, habilidades que
// "Pueden quebrar" y el afijo Quebrantador (combo_balance.md § 5.1 y
// § 5.3; loot.md § 16.3).

import 'package:echos_del_tiempo/game_engine/data/affixes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/balance_migration.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/break_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/combo_planner.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart' show progression;

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));
final _craft = progression.crafting;
final _items = progression.items;

/// Habilidades con "Puede quebrar" por tipo de arma (tabla de
/// combo_balance.md § 5.3, propuesta).
const _breakers = {
  'espada': ['tajoT'],
  'hacha': ['hendir'],
  'lanza': ['empalar'],
  'espada+escudo': ['estocada'],
  'martillo+escudo': ['juicio', 'aplastar'],
  'maza+escudo': ['golpeEscudo'],
  'arco': ['rayoF', 'flechaPerforante'],
  'ballesta': ['virote'],
  'rifle': ['perfora'],
  'dagas': ['tajoGemelo'],
  'báculo': ['descarga'],
  'varita': ['rayoArcano'],
  'tomo': ['torrente'],
};

Combatant _hero(List<String> skills, {PlayerBuild? build}) => Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      pulse: 5,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: skills,
      build: build,
      classId: 'guerrero',
      weaponType: 'espada',
      nextTurn: 10,
    );

Combatant _foe({bool fissured = false}) => Combatant(
      id: 'e0',
      name: 'Gólem',
      isPlayer: false,
      hp: 500,
      maxHp: 500,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: 'golem',
      fissured: fissured,
      nextTurn: 50,
    )..breakBase = 10;

BattleStep? _do(Combatant hero, Combatant foe, String skill) =>
    BattleEngine(stats: _stats, random: () => 0.99, familiesEnabled: false)
        .command(
            BattleState(
                party: [hero], enemies: [foe], clock: 10, currentId: 'p1'),
            'p1',
            SkillCommand(skill, targetId: 'e0'));

PlayerProfile _profile(List<ItemInstance> items, String equipped) =>
    progression.normalize(PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        credits: 10000,
        items: items,
        equipped: equipped));

List<String> _battleKit(ItemInstance w) =>
    BattleEngine(stats: _stats, random: () => 0.5)
        .start(party: [
          BattlePartyMember(
              id: 'p1',
              name: 'Ana',
              build: progression.buildOf(_profile([w], w.uid))),
        ], enemyTypes: const ['slime'])
        .state
        .party
        .single
        .skillIds;

void main() {
  group('Quebrar no hace daño', () {
    for (final id in kBaseQuebrarIds) {
      test('$id: power 0, Pulso 2, quiebra sin número de daño', () {
        final q = kSkills[id]!;
        expect(q.power, 0);
        expect(q.pureBreak, isTrue);
        expect(q.pulse, 2);
        final s = _do(_hero([id]), _foe(fissured: true), id)!;
        final e = s.state.enemies.single;
        expect(e.broken, isTrue);
        expect(e.hp, 500);
        expect(s.events.whereType<DamageEvent>(), isEmpty);
        expect(_do(_hero([id]), _foe(), id), isNull,
            reason: 'sigue pidiendo objetivo Fisurado');
      });
    }
  });

  group('Puede quebrar', () {
    test('cada tipo de arma tiene 1-2 habilidades con breaks en su pool', () {
      for (final e in _breakers.entries) {
        expect(e.value.length, inInclusiveRange(1, 2));
        for (final id in e.value) {
          final sk = kSkills[id]!;
          expect(sk.breaks, isTrue, reason: id);
          expect(sk.pureBreak, isFalse, reason: id);
          expect(sk.requires, isEmpty, reason: id);
          expect(
              kWeapons.values
                  .any((w) => w.type == e.key && w.skillIds.contains(id)),
              isTrue,
              reason: '$id en ${e.key}');
        }
      }
      final table = {for (final l in _breakers.values) ...l};
      final weaponSkills = {for (final w in kWeapons.values) ...w.skillIds};
      final marked = {
        for (final s in kSkills.values)
          if (s.breaks && !s.pureBreak && weaponSkills.contains(s.id)) s.id,
      };
      expect(marked, table);
    });

    test('pega normal y quiebra si está Fisurado; si no, solo pega', () {
      final a = _do(_hero(['tajoT']), _foe(fissured: true), 'tajoT')!;
      expect(a.state.enemies.single.broken, isTrue);
      expect(a.state.enemies.single.hp, lessThan(500));
      final b = _do(_hero(['tajoT']), _foe(), 'tajoT')!;
      expect(b.state.enemies.single.broken, isFalse);
      expect(b.state.enemies.single.hp, lessThan(500));
    });

    test('la IA prefiere la de más daño; Quebrar base queda última', () {
      final foes = [_foe(fissured: true)];
      const plan = ComboPlanner();
      expect(plan.quebrar(_hero(['quebrar', 'estocada', 'tajoT']), foes)
          ?.skillId, 'tajoT');
      expect(plan.quebrar(_hero(['quebrar', 'estocada']), foes)?.skillId,
          'estocada');
      expect(plan.quebrar(_hero(['quebrar']), foes)?.skillId, 'quebrar');
      expect(plan.quebrar(_hero(['quebrar', 'tajoT']), [_foe()]), isNull);
    });
  });

  group('ranura base de Quebrar (loot.md § 16.3)', () {
    test('el arma la trae al final y se puede elegir para reemplazar', () {
      const w = ItemInstance(uid: 'w', baseId: 'espada_bronce');
      expect(_items.skillsOf(w).last, kQuebrarId);
      expect(_items.replaceableSkills(w), [kQuebrarId]);
      expect(_items.canReceiveSkill(w, kQuebrarId), isNotNull,
          reason: 'Quebrar no se traslada');
      expect(_battleKit(w).last, kQuebrarId);
    });

    test('reemplazar Quebrar: la trasladada ocupa su ranura', () {
      final p = _profile(const [
        ItemInstance(
            uid: 'w', baseId: 'espada_bronce', extraSkills: ['tajoGemelo']),
        ItemInstance(uid: 'd', baseId: 'dagas_cobre'),
        ItemInstance(uid: 'x', baseId: 'dagas_cobre'),
      ], 'x');
      final w = p.itemByUid('w')!;
      expect(_items.needsReplaceChoice(w, 'dagaSaltarina'), isTrue);
      final r = _craft.transferSkill(p, 'w', 'd', 'dagaSaltarina',
          replaceSkillId: kQuebrarId);
      expect(r.ok, isTrue, reason: r.error);
      final after = r.after!;
      expect(after.quebrarReplaced, isTrue);
      expect(after.extraSkills, ['tajoGemelo', 'dagaSaltarina']);
      expect(after.skillCapacity, 2);
      expect(_items.skillsOf(after), isNot(contains(kQuebrarId)));
      expect(_items.replaceableSkills(after), ['tajoGemelo', 'dagaSaltarina']);
      expect(r.replacedSkillId, kQuebrarId);
      // Serializa (`nq`) y se sanea sin perder la ranura.
      expect(after.toJson()['nq'], 1);
      final back = _items.sanitize(ItemInstance.fromJson(after.toJson())!)!;
      expect(back.quebrarReplaced, isTrue);
      expect(back.extraSkills, ['tajoGemelo', 'dagaSaltarina']);
      // En batalla, sin Quebrar.
      final kit = _battleKit(after);
      expect(kit, isNot(contains(kQuebrarId)));
      expect(kit, contains('dagaSaltarina'));
    });

    test('armas viejas (sin nq) conservan Quebrar; la migración no cambia nada',
        () {
      final old = ItemInstance.fromJson({
        'u': 'w',
        'b': 'espada_bronce',
        's': ['tajoGemelo'],
      })!;
      expect(old.quebrarReplaced, isFalse);
      expect(_items.skillsOf(old), contains(kQuebrarId));
      final (m, refund) = const BalanceMigration().migrateItem(old);
      expect(m, old);
      expect(refund.isEmpty, isTrue);
      expect(kBalanceVersion, 2);
      expect(_battleKit(old).last, kQuebrarId);
    });
  });

  group('afijo Quebrantador', () {
    test('existe, un tier fijo y no sale en maza+escudo', () {
      final a = kAffixes['quebrantador']!;
      expect(a.stat, ModStat.breakSkill);
      expect([a.tiers.single.min, a.tiers.single.max], [1, 1]);
      expect(a.allows('maza+escudo'), isFalse);
      expect(a.allows('espada'), isTrue);
      expect(ModStat.breakSkill.format(1), 'Habilidad principal: puede quebrar');
    });

    test('la habilidad principal del arma puede quebrar', () {
      final w = kWeapons['espada_bronce']!;
      final main = BreakRules.modSkillOf(w)!;
      expect(main, 'embestida', reason: 'la primera a un objetivo');
      expect(kSkills[main]!.breaks, isFalse);
      const modded = ItemInstance(
          uid: 'w',
          baseId: 'espada_bronce',
          rarity: Rarity.magico,
          itemLevel: 10,
          affixes: [AffixRoll('quebrantador', 1, 1)]);
      expect(BreakRules.hasBreakMod(w, modded), isTrue);
      final b = progression.buildOf(_profile(const [modded], 'w'));
      final hero = _hero([main], build: b);
      expect(BreakRules.canBreak(kSkills[main]!, hero), isTrue);
      expect(BreakRules.canBreak(kSkills['giro']!, hero), isFalse);
      expect(BreakRules.canBreak(kSkills[main]!, _hero([main])), isFalse);
      final s = _do(hero, _foe(fissured: true), main)!;
      expect(s.state.enemies.single.broken, isTrue);
      expect(
          const ComboPlanner().quebrar(hero, [_foe(fissured: true)])?.skillId,
          main);
    });
  });
}
