import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Sin árbol: los números del arma se ven solos.
const _bare = StatsCalculator(
  classes: kClasses,
  treeRules: PassiveTreeRules(PassiveTreeCatalog(
      nodes: {}, startNodeByClass: {}, exclusions: {})),
);

PlayerBuild _build(String weaponId, {ItemInstance? item, int level = 1}) =>
    PlayerBuild(
      classId: 'guerrero',
      level: level,
      attributes:
          PlayerAttributes.base(kClasses['guerrero']!.baseAttributes),
      equippedWeapon: kWeapons[weaponId]!,
      passiveProgress: PlayerPassiveProgress.empty,
      item: item,
    );

BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  return BattleEngine(
      stats: statsCalc, random: () => i < rolls.length ? rolls[i++] : 0.99);
}

Combatant _hero({
  Set<String> mech = const {},
  int attack = 20,
  int hp = 100,
  List<String> skills = const [],
  double lifeSteal = 0,
  double regen = 0,
  int resist = 0,
  double healReceived = 0,
  double nextTurn = 0,
}) =>
    Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      hp: hp,
      maxHp: 100,
      speed: 10,
      attack: attack,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      mechanics: {...mech},
      skillIds: skills,
      classId: 'guerrero',
      weaponType: 'espada',
      lifeSteal: lifeSteal,
      regenPerTurn: regen,
      statusResist: resist,
      healReceived: healReceived,
      nextTurn: nextTurn,
    );

Combatant _foe(String id,
        {Map<StatusKind, int>? st,
        double breakBase = 0,
        StatusApplication? inflicts,
        double nextTurn = 50}) =>
    Combatant(
      id: id,
      name: 'Limo $id',
      isPlayer: false,
      hp: 100,
      maxHp: 100,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: 'slime',
      statuses: st,
      breakBase: breakBase,
      inflicts: inflicts,
      nextTurn: nextTurn,
    );

BattleState _battle(List<Combatant> party, List<Combatant> foes,
        {String? current = 'p1'}) =>
    BattleState(party: party, enemies: foes, currentId: current);

void main() {
  group('StatsCalculator con afijos', () {
    test('sin mods: los números de siempre', () {
      final plain = _bare.calculate(_build('espada_bronce'));
      final common = _bare.calculate(_build('espada_bronce',
          item: const ItemInstance(uid: 'x', baseId: 'espada_bronce')));
      expect(common.attack, plain.attack);
      expect(common.maxHp, plain.maxHp);
      expect(common.speed, plain.speed);
      // 6 + 0.6 × 12 + 0.2 × 6 = 14.4 → 14.
      expect(plain.attack, 14);
    });

    test('orden: atributos → base → plano → % → forja', () {
      const item = ItemInstance(
        uid: 'r1',
        baseId: 'espada_bronce',
        rarity: Rarity.raro,
        affixes: [
          AffixRoll('feroz', 4, 20), // +20% ATQ
          AffixRoll('afilado', 4, 5), // +5 ATQ
          AffixRoll('del_toro', 5, 4), // +4 FUE
          AffixRoll('de_la_vida', 4, 30), // +30 vida
        ],
        forge: WeaponUpgradeLevels(pow: 1),
      );
      final d = _bare.calculate(_build('espada_bronce', item: item));
      // FUE 16: 6 + 9.6 + 1.2 = 16.8; (16.8 + 5) × 1.2 × 1.12 = 29.3 → 29.
      expect(d.attack, 29);
      // Magia sin fórmula: copia al ataque con sus mods.
      expect(d.magic, 29);
      expect(d.maxHp, 20 + 40 + 2 + 30);
      final atk = d.breakdown['ATQ']!;
      expect(atk.total, 29);
      expect(atk.text,
          'ATQ 29 = base 16.8 + 5 plano × 1.20 afijos × 1.12 forja');
      expect(d.breakdown['HP']!.text, 'HP 92 = base 62 + 30 afijos');
    });

    test('crítico, daño crítico, velocidad, DEF, ULT, estados y combate', () {
      const item = ItemInstance(
        uid: 'e1',
        baseId: 'espada_bronce',
        rarity: Rarity.epico,
        affixes: [
          AffixRoll('certero', 3, 6),
          AffixRoll('letal', 4, 15),
          AffixRoll('veloz', 4, 3),
          AffixRoll('impetuoso', 4, 8),
          AffixRoll('abrasador', 2, 1),
          AffixRoll('del_vampiro', 4, 2),
        ],
      );
      final plain = _bare.calculate(_build('espada_bronce'));
      final d = _bare.calculate(_build('espada_bronce', item: item));
      expect(d.critChance, closeTo(plain.critChance + 0.06, 1e-9));
      expect(d.critMultiplier, closeTo(1.65, 1e-9));
      expect(d.speed, closeTo(plain.speed + 0.3, 1e-9));
      expect(d.ultChargeBonus, closeTo(0.08, 1e-9));
      expect(d.statusBonus[StatusKind.burn], 1);
      expect(d.lifeSteal, closeTo(0.02, 1e-9));
    });

    test('implícito de la base (lanza: +0.3 vel)', () {
      final w = kWeapons['lanza_hierro']!;
      expect(w.implicit, [const ItemMod(ModStat.speed, 3)]);
      final d = _bare.calculate(PlayerBuild(
        classId: 'guerrero',
        level: 4,
        attributes: PlayerAttributes.base(kClasses['guerrero']!.baseAttributes),
        equippedWeapon: w,
      ));
      // 6 + 3 + 0.6 − 0.5 peso + 0.3 implícito.
      expect(d.speed, closeTo(9.4, 1e-9));
    });

    test('la pasiva entra como mecánica; la forja sube su nivel', () {
      const item = ItemInstance(
        uid: 'e2',
        baseId: 'espada_bronce',
        rarity: Rarity.epico,
        passiveId: 'filoResonante',
        forge: WeaponUpgradeLevels(pow: 2, crit: 2),
      );
      expect(item.effectivePassiveLevel, 3);
      final d = _bare.calculate(_build('espada_bronce', item: item));
      expect(d.mechanics, contains('wp:filoResonante:3'));
      // En un Raro (sin cupo de pasiva) no cuenta.
      final raro = _bare.calculate(_build('espada_bronce',
          item: item.copyWith(rarity: Rarity.raro)));
      expect(raro.mechanics.where((m) => m.startsWith('wp:')), isEmpty);
    });

    test('perfil → build → combatiente con la pasiva y las habilidades', () {
      final p = progression.normalize(PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        items: const [
          ItemInstance(
            uid: 'i1',
            baseId: 'espada_bronce',
            rarity: Rarity.epico,
            passiveId: 'sedDelArma',
            extraSkills: ['bola'],
          ),
        ],
        equipped: 'i1',
      ));
      expect(p.equippedUid, 'i1');
      final b = progression.buildOf(p);
      expect(b.item!.uid, 'i1');
      final s = sessionEngine();
      final step = s.battles.start(
          party: [
            BattlePartyMember(id: 'p0', name: 'Ana', build: b),
          ],
          enemyTypes: ['slime']);
      final c = step.state.party.single;
      expect(c.mechanics, contains('wp:sedDelArma:1'));
      expect(c.skillIds, containsAll(['giro', 'embestida', 'bola']));
    });
  });

  group('pasivas de arma en combate', () {
    test('Filo Resonante I: rebota al 25% (id de mecánica del arma)', () {
      final st = _engine().command(
          _battle([_hero(mech: {'wp:filoResonante:1'})],
              [_foe('e0'), _foe('e1')]),
          'p1',
          const AttackCommand(targetId: 'e0'))!;
      expect(st.state.enemies.map((e) => e.hp), [80, 95]);
      final bounce = st.events.whereType<DamageEvent>().last;
      expect(bounce.sourceId, 'wp:filoResonante:1');
      expect(st.state.log, contains('Filo Resonante I'));
    });

    test('Rompehielos: +20% de quiebre contra congelados', () {
      BattleState run(Set<String> mech) => _engine()
          .command(
              _battle([_hero(mech: mech)], [
                _foe('e0', st: {StatusKind.freeze: 1}, breakBase: 200),
              ]),
              'p1',
              const AttackCommand(targetId: 'e0'))!
          .state;
      expect(run({}).enemies.single.breakGauge, 20);
      expect(run({'wp:rompehielos:1'}).enemies.single.breakGauge, 24);
    });

    test('Escarcha Viva: +1 Congelación con su probabilidad', () {
      // Azar: crítico 0.99 (no), Escarcha Viva V (80%) con 0.1 → sí.
      final st = _engine([0.99, 0.1]).command(
          _battle([_hero(mech: {'wp:escarchaViva:5'}, skills: ['lanzaH'])],
              [_foe('e0')]),
          'p1',
          const SkillCommand('lanzaH', targetId: 'e0'))!;
      expect(st.state.enemies.single.stacks(StatusKind.freeze), 3);
      final miss = _engine([0.99, 0.9]).command(
          _battle([_hero(mech: {'wp:escarchaViva:5'}, skills: ['lanzaH'])],
              [_foe('e0')]),
          'p1',
          const SkillCommand('lanzaH', targetId: 'e0'))!;
      expect(miss.state.enemies.single.stacks(StatusKind.freeze), 2);
    });

    test('Golpe Conmocionante: aturde con su probabilidad', () {
      final st = _engine([0.99, 0.0]).command(
          _battle([_hero(mech: {'wp:conmocion:1'})], [_foe('e0')]),
          'p1',
          const AttackCommand(targetId: 'e0'))!;
      expect(st.state.enemies.single.stacks(StatusKind.stun), 1);
      expect(st.events.whereType<ProcEvent>().single.sourceId,
          'wp:conmocion:1');
    });
  });

  group('afijos de combate', () {
    test('robo de vida: % del daño de la acción', () {
      final st = _engine().command(
          _battle([_hero(hp: 50, lifeSteal: 0.5)], [_foe('e0')]),
          'p1',
          const AttackCommand(targetId: 'e0'))!;
      expect(st.state.party.single.hp, 60);
      expect(st.state.log, contains('robo de vida +10 HP'));
    });

    test('regeneración al empezar el turno', () {
      final st = _engine().nextTurn(
          _battle([_hero(hp: 50, regen: 0.05)], [_foe('e0')], current: null));
      expect(st.state.currentId, 'p1');
      expect(st.state.party.single.hp, 55);
    });

    test('resistencia: −1 stack de Congelación recibido (mín. 1)', () {
      int frozen(int resist) => _engine()
          .enemyTurn(_battle([
            _hero(resist: resist, nextTurn: 50)
          ], [
            _foe('e0',
                inflicts: const StatusApplication(StatusKind.freeze, 2),
                nextTurn: 0),
          ], current: 'e0'))!
          .state
          .party
          .single
          .stacks(StatusKind.freeze);
      expect(frozen(0), 2);
      expect(frozen(1), 1);
      expect(frozen(5), 1);
    });

    test('curación recibida multiplica las curas', () {
      final st = _engine().command(
          _battle([_hero(hp: 10, healReceived: 0.5, skills: ['cura'])],
              [_foe('e0')]),
          'p1',
          const SkillCommand('cura'))!;
      // Cura: MAG 20 × 1.5 + 6 = 36 → × 1.5 = 54.
      expect(st.state.party.single.hp, 64);
    });
  });
}
