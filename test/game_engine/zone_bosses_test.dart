import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zone_bosses_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/enemy_def.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/abyss_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/boss_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/dungeon_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/gear_v2_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Phased zone bosses (docs/specs/bosses.md § v0.50): Rey Limo's phases,
// telegraphs, co-op scaling, the Eco re-fight, boss loot and the unlock.

const _startNodes = PassiveTreeCatalog(
  nodes: {
    's_gue': PassiveNode(id: 's_gue', x: 0, y: -1.1, name: 'Inicio: Guerrero', kind: 'st', effects: {}, links: []),
    's_mag': PassiveNode(id: 's_mag', x: 1.1, y: 0, name: 'Inicio: Maga', kind: 'st', effects: {}, links: []),
  },
  startNodeByClass: {'guerrero': 's_gue', 'maga': 's_mag'},
  exclusions: {},
);

const _stats = StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(_startNodes));

BattleEngine _engine() => BattleEngine(stats: _stats, random: () => 0.99);

BattlePartyMember _member(String id, String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: '${cls.name} $id',
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

BattleState _start(BattleEngine e, int players,
    {List<String> enemies = const ['reyLimo', 'slime', 'slime']}) {
  final s = e
      .start(
        party: [
          for (var i = 0; i < players; i++)
            _member('p${i + 1}', i.isEven ? 'guerrero' : 'maga')
        ],
        enemyTypes: enemies,
      )
      .state;
  for (final p in s.party) {
    p
      ..maxHp = 999999
      ..hp = 999999
      ..mp = 99;
  }
  // Mundo turns the phases on (BossRules.applyBattle).
  s.enemies.first.phase = 1;
  return s;
}

BattleState _turnOf(BattleState s, String id) {
  final c = s.copy()..currentId = id;
  for (final p in c.party) {
    p.pulse = BattleEngine.pulseMax;
  }
  return c;
}

BattleStep _bossAct(BattleEngine e, BattleState s) =>
    e.enemyTurn(_turnOf(s, 'e0'))!;

BattleStep _hit(BattleEngine e, BattleState s) =>
    e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand(targetId: 'e0'))!;

/// Leaves the boss just above [frac] of its life and hits it once.
BattleStep _crossTo(BattleEngine e, BattleState s, double frac) {
  final c = s.copy();
  final b = c.enemies.first;
  b.hp = (b.maxHp * frac).ceil() + 1;
  return _hit(e, c);
}

Iterable<BossMechanicEvent> _mech(BattleStep s, BossMechanicPhase ph) =>
    s.events.whereType<BossMechanicEvent>().where((e) => e.phase == ph);

void main() {
  final t = tuning(TuningId.bosses);

  group('catalog', () {
    test('Rey Limo: 3 phases from kTuning, telegraphed specials', () {
      final d = zoneBossOf('reyLimo')!;
      expect(d.phases.length, 3);
      expect(d.phases.map((p) => p.gate), [1, t.d('p2Gate'), t.d('p3Gate')]);
      expect(d.phases[1].summon, isTrue);
      expect(d.phases[1].attackMult, t.d('p2Atk'));
      expect(d.phases[2].attackMult, t.d('p3Atk'));
      for (final p in d.phases) {
        expect(p.moves.where((m) => m.kind.telegraphed), isNotEmpty,
            reason: p.name);
      }
      final en = kEnemies['reyLimo']!;
      expect(bossMechanicOf(en), isNull, reason: 'Travesía keeps it plain');
      expect(kBossMechanics[kZoneBossMechanics['reyLimo']]!.kind,
          BossMechanicKind.abyss);
      expect(zoneBossOf('golemReloj'), isNull);
      expect(kZoneBossZones['reyLimo'], 1);
    });

    test('the defs follow the Balance patch (kTuning)', () {
      final saved = kTuning[TuningId.bosses]!;
      try {
        kTuning[TuningId.bosses] =
            TuningDef(saved.name, {...saved.values, 'p2Gate': 0.5});
        expect(zoneBossOf('reyLimo')!.phases[1].gate, 0.5);
      } finally {
        kTuning[TuningId.bosses] = saved;
      }
    });

    test('phaseAt follows the gates', () {
      expect(BossRules.phaseAt('reyLimo', 1), 0);
      expect(BossRules.phaseAt('reyLimo', 0.7), 0);
      expect(BossRules.phaseAt('reyLimo', 0.66), 1);
      expect(BossRules.phaseAt('reyLimo', 0.4), 1);
      expect(BossRules.phaseAt('reyLimo', 0.2), 2);
      expect(BossRules.phaseAt('golemReloj', 0.2), 0);
    });
  });

  group('battle', () {
    test('phase 1 telegraphs Ola Ácida one action ahead', () {
      final e = _engine();
      var s = _start(e, 2);
      expect(s.enemies.first.phase, 1);
      final log = <BattleStep>[];
      for (var i = 0; i < 2; i++) {
        final st = _bossAct(e, s);
        log.add(st);
        s = st.state;
      }
      // After the 2nd attack the next move (3rd) is the wave: warned.
      expect(_mech(log[1], BossMechanicPhase.abyssTelegraph), hasLength(1));
      expect(AbyssRules.nextMove(zoneBossOf('reyLimo')!, s.enemies.first).label,
          'Ola Ácida');
      final wave = _bossAct(e, s);
      expect(
          wave.events.whereType<ActionEvent>().first.kind,
          BattleActionKind.enemyArea);
      // Poison on the party (nobody defended).
      expect(wave.state.party.every((p) => p.statuses.isNotEmpty), isTrue);
    });

    test('crossing 66 % clamps life, enters División and splits', () {
      final e = _engine();
      var s = _start(e, 2);
      // Kill the starting slimes: the split brings them back.
      for (final c in s.enemies.skip(1)) {
        c.hp = 0;
      }
      final atk0 = s.enemies.first.attack;
      final st = _crossTo(e, s, t.d('p2Gate'));
      s = st.state;
      final b = s.enemies.first;
      expect(b.phase, 2);
      expect(b.hp, (b.maxHp * t.d('p2Gate')).ceil());
      expect(b.attack, greaterThan(atk0));
      expect(_mech(st, BossMechanicPhase.phaseShift).single.value, 2);
      final slimes =
          s.enemies.where((c) => c.alive && c.enemyType == 'slime').length;
      expect(slimes, t.i('adds'));
    });

    test('solo: fewer slimes on the split', () {
      final e = _engine();
      var s = _start(e, 1);
      for (final c in s.enemies.skip(1)) {
        c.hp = 0;
      }
      s = _crossTo(e, s, t.d('p2Gate')).state;
      expect(s.enemies.where((c) => c.alive && c.enemyType == 'slime').length,
          t.i('soloAdds'));
    });

    test('phase 3 opens with Marea Real (wet + delay) and turns crimson', () {
      final e = _engine();
      var s = _start(e, 2);
      s = _crossTo(e, s, t.d('p2Gate')).state;
      final st = _crossTo(e, s, t.d('p3Gate'));
      s = st.state;
      expect(s.enemies.first.phase, 3);
      expect(_mech(st, BossMechanicPhase.phaseShift).single.value, 3);
      final d = zoneBossOf('reyLimo')!;
      expect(AbyssRules.nextMove(d, s.enemies.first).label, 'Marea Real');
      final before = {for (final p in s.party) p.id: p.nextTurn};
      final tide = _bossAct(e, s);
      for (final p in tide.state.party) {
        expect(p.nextTurn, greaterThan(before[p.id]!), reason: 'delayed');
      }
    });

    test('defending halves the wave', () {
      final e = _engine();
      var s = _start(e, 2);
      for (var i = 0; i < 2; i++) {
        s = _bossAct(e, s).state;
      }
      final def = s.copy();
      def.party.first.defending = true;
      final a = _bossAct(e, s).events.whereType<DamageEvent>()
          .firstWhere((x) => x.targetId == 'p1').amount;
      final b = _bossAct(e, def).events.whereType<DamageEvent>()
          .firstWhere((x) => x.targetId == 'p1').amount;
      expect(b, lessThan(a));
    });

    test('no fury with enrageTurns 0', () {
      expect(zoneBossOf('reyLimo')!.enrageTurns, greaterThan(100000));
    });
  });

  group('scaling and Eco', () {
    test('party size adds partyHpPer life and break per extra player', () {
      expect(BossRules.partyHp(1), 1);
      expect(BossRules.partyHp(4), closeTo(1 + 3 * t.d('partyHpPer'), 1e-9));
      final e = _engine();
      final s1 = _start(e, 1), s4 = _start(e, 4);
      final hp1 = s1.enemies.first.maxHp, br1 = s1.enemies.first.breakBase;
      final hp4 = s4.enemies.first.maxHp, br4 = s4.enemies.first.breakBase;
      BossRules.applyBattle(s1, players: 1);
      BossRules.applyBattle(s4, players: 4);
      expect(s1.enemies.first.maxHp, hp1);
      expect(s4.enemies.first.maxHp, (hp4 * BossRules.partyHp(4)).round());
      expect(s4.enemies.first.breakBase,
          closeTo(br4 * BossRules.partyHp(4), 1e-9));
      expect(s1.enemies.first.breakBase, br1);
    });

    test('Eco tier: life, break and attack up; commons untouched', () {
      final e = _engine();
      final s = _start(e, 2);
      final b = s.enemies.first;
      final hp = b.maxHp, atk = b.attack, slime = s.enemies[1].maxHp;
      BossRules.applyBattle(s, players: 2, eco: true);
      expect(b.maxHp, (hp * BossRules.partyHp(2) * t.d('ecoHp')).round());
      expect(b.hp, b.maxHp);
      expect(b.attack, (atk * t.d('ecoAtk')).round());
      expect(s.enemies[1].maxHp, slime);
    });

    test('Eco offering costs ecoCostMult × and pays more loot', () {
      final normal = DungeonRules.offeringCost(1);
      final eco = DungeonRules.offeringCost(1, eco: true);
      for (final k in normal.keys) {
        expect(eco[k], (normal[k]! * t.d('ecoCostMult')).ceil());
      }
      expect(BossRules.extraRolls(), 0);
      expect(BossRules.extraRolls(eco: true), t.i('ecoLootRolls'));
      expect(BossRules.legendaryChance(0.1, eco: true),
          closeTo(0.1 + t.d('ecoLegendBonus'), 1e-9));
      expect(BossRules.material('reyLimo'), ('boss_gelcrown', t.i('bossMat')));
      expect(BossRules.material('reyLimo', eco: true),
          ('boss_gelcrown', t.i('ecoMat')));
      expect(BossRules.material('golemReloj'), isNull);
    });

    test('offer action round-trips eco on the wire', () {
      final j = ActionJson.toJson(const OfferBossAction(eco: true));
      expect(j, {'t': 'offer', 'eco': true});
      expect((ActionJson.fromJson(j) as OfferBossAction).eco, isTrue);
      expect(ActionJson.toJson(const OfferBossAction()), {'t': 'offer'});
      expect((ActionJson.fromJson({'t': 'offer'}) as OfferBossAction).eco, isFalse);
    });
  });

  group('boss material', () {
    test('Corona de Gel is a parts-forge setting with poison affinity', () {
      final m = kSmithMaterials['boss_gelcrown']!;
      expect(m.kind, SmithMatKind.rare);
      expect(kRareAffinity['boss_gelcrown'], GameElement.veneno);
      expect(GearV2Rules.fits(PartSlot.setting, 'boss_gelcrown'), isTrue);
      expect(GearV2Rules.fits(PartSlot.base, 'boss_gelcrown'), isFalse);
    });
  });

  group('session', () {
    PlayerProfile strong(String name, {int zone = 1}) {
      final p = zoneProgression.normalize(
          PlayerProfile(name: name, classId: 'guerrero', level: 50));
      final half = p.points ~/ 2;
      return zoneProgression
          .allocate(p, {Attribute.vit: half, Attribute.fue: p.points - half})!
          .copyWith(unlockedZone: zone);
    }

    GameSession toBoss(dynamic e, GameSession s) {
      final boss = s.mission!.enemies.singleWhere((x) => x.boss);
      s = e.tick(s, 0.05).state as GameSession;
      final map = e.mapFor(s);
      s = act(e, s, 'p0', MoveAction(map.floor(0)!.stairsDown!.x,
          map.floor(0)!.stairsDown!.y, epoch: s.players['p0']!.epoch));
      s = e.tick(s, 0.05).state as GameSession;
      s = wait(e, s, s.graceLeft + 0.1);
      return moveTo(e, s, 'p0', boss.x, boss.y);
    }

    GameSession win(dynamic e, GameSession s) {
      s = runBattle(e, s, until: (x) => x.result != null);
      for (var i = 0; i < 5 && s.mode == SessionMode.levelUp; i++) {
        for (final p in s.playerList) {
          if (p.profile.points > 0) {
            s = act(e, s, p.id,
                AllocateStatsAction({Attribute.vit: p.profile.points}));
          }
        }
        s = runBattle(e, s, until: (x) => x.result != null);
      }
      return s;
    }

    test('beating Rey Limo opens zone 2 and drops the Corona de Gel', () {
      final e = sessionEngine(zones: true);
      var s = inField(e, 'm1', profiles: [strong('Ana')]);
      s = toBoss(e, s);
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.battle);
      expect(s.battle!.state.enemies.first.phase, 1);
      s = win(e, s);
      expect(s.result!.success, isTrue);
      expect(s.result!.unlocked, {'p0': 2});
      expect(s.players['p0']!.profile.unlockedZone, 2);
      expect(s.players['p0']!.profile.life.ore('boss_gelcrown'),
          t.i('bossMat'));
    });

    test('mission JSON carries bossEco (be)', () {
      final e = sessionEngine(zones: true);
      final s = inField(e, 'm1', profiles: [strong('Ana')]);
      final m = s.mission!..bossEco = true;
      expect(m.copy().bossEco, isTrue);
      expect(s.copy().mission!.bossEco, isTrue);
    });

    test('a group boss has more life than a solo one', () {
      final e1 = sessionEngine(zones: true);
      var s1 = inField(e1, 'm1', profiles: [strong('Ana')]);
      s1 = e1.tick(toBoss(e1, s1), 0.05).state;
      final e2 = sessionEngine(zones: true);
      var s2 = inField(e2, 'm1', profiles: [strong('Ana'), strong('Beto')]);
      s2 = e2.tick(toBoss(e2, s2), 0.05).state;
      expect(s2.mode, SessionMode.battle);
      expect(s2.battle!.state.enemies.first.maxHp,
          greaterThan(s1.battle!.state.enemies.first.maxHp));
    });
  });
}
