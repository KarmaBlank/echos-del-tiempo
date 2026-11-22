import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Pasa por texto JSON real (como por la red).
Json _wire(Json j) => asJson(jsonDecode(jsonEncode(j)));

const _sessionJson = SessionJson();
const _eventJson = EventJson();

/// Todas las acciones, con todos sus campos opcionales usados.
final _allActions = <SessionAction>[
  const MoveAction(12.3, 45.6, epoch: 3, dir: -1, moving: true),
  const ProposeMissionAction('m2'),
  const VoteMissionAction(false),
  const ReadyAction(true),
  const CancelPrepAction(),
  const ActivateSealAction(7),
  const ChangeClassAction('maga'),
  const RespecAction(),
  const AllocateStatsAction({Attribute.vit: 2, Attribute.fue: 1}),
  const EquipAction('espada2'),
  const TakeNodeAction('g1'),
  const ResetTreeAction(),
  const FuseAction('a', 'b', 'sk'),
  const UpgradeAction('espada2', UpgradeStat.crit),
  const BuyItemAction(BattleItem.ether),
  const BuyWeaponAction('hacha1'),
  const ChatAction('hola sala'),
  const BackToLobbyAction(),
  const UseStairsAction(down: true),
  const UseStairsAction(down: false),
  const BattleAction(AttackCommand(targetId: 'e1')),
  const BattleAction(AttackCommand()),
  const BattleAction(SkillCommand('corte', targetId: 'e2')),
  const BattleAction(SkillCommand('cura')),
  const BattleAction(UltimateCommand(targetId: 'e0')),
  const BattleAction(UltimateCommand()),
  const BattleAction(DualCommand('p2')),
  const BattleAction(ItemCommand(BattleItem.potion, targetPlayerId: 'p1')),
  const BattleAction(ItemCommand(BattleItem.ether)),
  const BattleAction(DefendCommand()),
  const BattleAction(PassCommand()),
];

/// Todos los eventos de batalla, con todos sus campos.
const _allBattleEvents = <BattleEvent>[
  TurnStartedEvent('h'),
  DamageEvent('e1', 12,
      critical: true,
      critMultiplier: 1.75,
      pierceMultiplier: 1.3,
      fromStatus: true,
      statusSource: StatusKind.burn),
  DamageEvent('e1', 3),
  ActionEvent('p1', BattleActionKind.skill,
      skillId: 'corte', partnerId: 'p2', targetId: 'e1', allTargets: true),
  ActionEvent('e0', BattleActionKind.enemyArea),
  HealEvent('p1', 9, mana: true),
  StatusAppliedEvent('e1', StatusKind.freeze, 2, weakness: true),
  TurnSkippedEvent('e1', StatusKind.stun),
  DelayedEvent('e2'),
  KnockedOutEvent('p2'),
  RevivedEvent('p2'),
  UltimateUsedEvent('h', 'Tajo del Tiempo'),
  BattleEndedEvent(true, 40, 25),
  // Árbol v2.
  DamageEvent('e2', 7, sourceId: 'rebote'),
  ProcEvent('p1', 'frenesi'),
  ProcEvent('p1', 'marcaCazador', targetId: 'e1'),
  BuffAppliedEvent('p1', 'frenesi', BuffStat.speed, 0.2, 2),
  BuffAppliedEvent('e1', 'debilitar', BuffStat.attack, -0.15, 2),
  ShieldEvent('p2', 12),
  ShieldEvent('p2', 5, absorbed: true),
  // Quiebre y ULT enemigas.
  DamageEvent('e1', 30, vulnerable: true),
  BreakEvent('e1', BreakPhase.fill, 12.5, 50),
  BreakEvent('e1', BreakPhase.broken, 50, 50, cancelledUlt: true),
  BreakEvent('e1', BreakPhase.recovered, 0, 62.5),
  EnemyUltWarningEvent('e0', 'eult_diluvio', 'Diluvio Ácido'),
  EnemyUltEvent('e0', 'eult_finEras', 'Fin de las Eras',
      allTargets: true, wipedBuffs: true),
  EnemyUltEvent('e0', 'eult_furia', 'Furia Élite', targetId: 'p1'),
];

final _result = MissionResult(
  id: 4,
  missionId: 'm1',
  missionName: 'Pradera Esmeralda',
  success: true,
  rank: MissionRank.a,
  time: 312.5,
  xp: 120,
  credits: 80,
  bonus: 20,
  bonusPercent: 0.25,
  kos: 1,
  elites: 2,
  eliteDrops: const [WeaponDrop('h', 'espada2')],
  drops: const {'p1': 'baculo2'},
  timeLeft: 17.25,
);

/// Todos los eventos de sesión, con todos sus campos.
final _allEvents = <SessionEvent>[
  const SystemMessageEvent('Ana se unió a la sala.'),
  const ChatMessageEvent('p1', 'Ana', 'hola'),
  const PlayerJoinedEvent('p1'),
  const PlayerLeftEvent('p2'),
  const MissionStartedEvent('m3', 123456),
  const ObjectiveProgressEvent(ObjectiveKind.seals, 1, 2),
  const GateOpenedEvent(),
  const ChestOpenedEvent('h', 41, item: BattleItem.potion, weaponId: 'arco2'),
  const ChestOpenedEvent('h', 30),
  const BattleStartedEvent(2, 17, boss: true, elite: true),
  const BattleStepEvent(_allBattleEvents),
  const LevelUpEvent('p1', 3),
  const BattleFinishedEvent(false),
  const WeaponDropEvent('h', 'espada3', 'elite'),
  MissionEndedEvent(_result),
  const ReturnedToLobbyEvent(),
  const FloorChangedEvent(2, down: true),
  const FloorChangedEvent(0, down: false),
  const StairsOpenedEvent(1),
  const ZoneUnlockedEvent('p1', 3),
];

String _actionText(SessionAction a) => jsonEncode(ActionJson.toJson(a));
String _eventText(SessionEvent e) => jsonEncode(_eventJson.toJson(e));
String _sessionText(GameSession s) => jsonEncode(_sessionJson.toJson(s));

/// encode → texto → decode → encode da lo mismo.
void _expectSessionRoundTrip(GameSession s) {
  final text = _sessionText(s);
  final back = _sessionJson.fromJson(asJson(jsonDecode(text)));
  expect(_sessionText(back), text);
}

void main() {
  group('acciones', () {
    test('todas ida y vuelta, mismo tipo', () {
      for (final a in _allActions) {
        final back = ActionJson.fromJson(_wire(ActionJson.toJson(a)));
        expect(back.runtimeType, a.runtimeType);
        expect(_actionText(back), _actionText(a), reason: '$a');
      }
    });

    test('claves del prototipo', () {
      expect(ActionJson.toJson(const MoveAction(1.5, 2, epoch: 4, moving: true)),
          {'t': 'pos', 'x': 1.5, 'y': 2.0, 'dir': 1, 'mv': true, 'ep': 4});
      expect(
          ActionJson.toJson(const BattleAction(
              ItemCommand(BattleItem.potion, targetPlayerId: 'p2'))),
          {'t': 'cmd', 'a': 'item', 'it': 'pot', 'to': 'p2'});
      expect(ActionJson.toJson(const BattleAction(SkillCommand('x', targetId: 'e1'))),
          {'t': 'cmd', 'a': 'tech', 'tk': 'x', 'tg': 'e1'});
      expect(ActionJson.toJson(const AllocateStatsAction({Attribute.agi: 3})),
          {'t': 'stats', 'add': {'AGI': 3}});
    });

    test('Pasar turno (v0.8.3): variante aditiva de `def`', () {
      expect(ActionJson.toJson(const BattleAction(PassCommand())),
          {'t': 'cmd', 'a': 'def', 'ps': true});
      // Defender no cambia (lo que manda un v0.8.2).
      expect(ActionJson.toJson(const BattleAction(DefendCommand())),
          {'t': 'cmd', 'a': 'def'});
      Object cmd(Json j) => (ActionJson.fromJson(j) as BattleAction).command;
      expect(cmd({'t': 'cmd', 'a': 'def'}), isA<DefendCommand>());
      expect(cmd({'t': 'cmd', 'a': 'def', 'ps': false}), isA<DefendCommand>());
      expect(cmd({'t': 'cmd', 'a': 'def', 'ps': true}), isA<PassCommand>());
      expect(() => ActionJson.fromJson({'t': 'cmd', 'a': 'def', 'ps': 'si'}),
          throwsFormatException);
    });

    test('campos leídos', () {
      final m = ActionJson.fromJson(_wire(ActionJson.toJson(
          const MoveAction(3.25, 4.5, epoch: 9, dir: -1, moving: true))));
      m as MoveAction;
      expect([m.x, m.y, m.epoch, m.dir, m.moving], [3.25, 4.5, 9, -1, true]);
      final b = ActionJson.fromJson(_wire(ActionJson.toJson(
          const BattleAction(DualCommand('p3'))))) as BattleAction;
      expect((b.command as DualCommand).partnerId, 'p3');
      final st = ActionJson.fromJson(_wire(ActionJson.toJson(
              const AllocateStatsAction({Attribute.des: 2, Attribute.esp: 1}))))
          as AllocateStatsAction;
      expect(st.add, {Attribute.des: 2, Attribute.esp: 1});
    });

    test('mal formadas → FormatException', () {
      for (final bad in <Json>[
        {'t': 'volar'},
        {'t': 'pos', 'x': 1, 'y': 2},
        {'t': 'pos', 'x': 'a', 'y': 2, 'ep': 1, 'dir': 1},
        {'t': 'cmd', 'a': 'magia'},
        {'t': 'cmd', 'a': 'tech'},
        {'t': 'buyItem', 'it': 'elixir'},
        {'t': 'up', 'w': 'x', 'stat': 'luck'},
        {'t': 'vote', 'ok': 'si'},
        {'no': 'type'},
      ]) {
        expect(() => ActionJson.fromJson(bad), throwsFormatException,
            reason: '$bad');
      }
    });
  });

  group('eventos', () {
    test('todos ida y vuelta, mismo tipo', () {
      for (final e in _allEvents) {
        final back = _eventJson.fromJson(_wire(_eventJson.toJson(e)));
        expect(back.runtimeType, e.runtimeType);
        expect(_eventText(back), _eventText(e), reason: '$e');
      }
    });

    test('eventos de batalla con sus campos', () {
      final back = _eventJson.fromJson(
          _wire(_eventJson.toJson(const BattleStepEvent(_allBattleEvents))));
      final evs = (back as BattleStepEvent).events;
      expect(evs.map((e) => e.runtimeType).toList(),
          _allBattleEvents.map((e) => e.runtimeType).toList());
      final dmg = evs[1] as DamageEvent;
      expect([dmg.targetId, dmg.amount, dmg.critical, dmg.critMultiplier,
              dmg.pierceMultiplier, dmg.fromStatus, dmg.statusSource],
          ['e1', 12, true, 1.75, 1.3, true, StatusKind.burn]);
      final act = evs[3] as ActionEvent;
      expect([act.kind, act.skillId, act.partnerId, act.targetId, act.allTargets],
          [BattleActionKind.skill, 'corte', 'p2', 'e1', true]);
      expect(dmg.sourceId, isNull);
      final bounce =
          evs.whereType<DamageEvent>().firstWhere((d) => d.sourceId != null);
      expect([bounce.targetId, bounce.amount, bounce.sourceId],
          ['e2', 7, 'rebote']);
      final proc = evs.whereType<ProcEvent>().last;
      expect([proc.actorId, proc.sourceId, proc.targetId],
          ['p1', 'marcaCazador', 'e1']);
      final buff = evs.whereType<BuffAppliedEvent>().last;
      expect([buff.targetId, buff.sourceId, buff.stat, buff.value, buff.turns],
          ['e1', 'debilitar', BuffStat.attack, -0.15, 2]);
      final shield = evs.whereType<ShieldEvent>().last;
      expect([shield.targetId, shield.amount, shield.absorbed], ['p2', 5, true]);
      // Quiebre y ULT enemigas.
      expect(evs.whereType<DamageEvent>().last.vulnerable, isTrue);
      expect(dmg.vulnerable, isFalse);
      final brk = evs.whereType<BreakEvent>().toList();
      expect(
          [for (final b in brk) [b.targetId, b.phase, b.gauge, b.max, b.cancelledUlt]],
          [
            ['e1', BreakPhase.fill, 12.5, 50, false],
            ['e1', BreakPhase.broken, 50, 50, true],
            ['e1', BreakPhase.recovered, 0, 62.5, false],
          ]);
      final warn = evs.whereType<EnemyUltWarningEvent>().single;
      expect([warn.actorId, warn.ultId, warn.name],
          ['e0', 'eult_diluvio', 'Diluvio Ácido']);
      final ults = evs.whereType<EnemyUltEvent>().toList();
      expect(
          [for (final u in ults) [u.actorId, u.ultId, u.name, u.targetId, u.allTargets, u.wipedBuffs]],
          [
            ['e0', 'eult_finEras', 'Fin de las Eras', null, true, true],
            ['e0', 'eult_furia', 'Furia Élite', 'p1', false, false],
          ]);
    });

    test('eventos viejos sin las claves del árbol v2 se siguen leyendo', () {
      final e = _eventJson.battleFromJson({
        'k': 'dmg', 'id': 'e1', 'n': 3, 'crit': false, 'cm': 1.5, 'pm': 1,
        'st': false, 'src': null,
      }) as DamageEvent;
      expect(e.sourceId, isNull);
      final sh = _eventJson.battleFromJson({'k': 'shield', 'id': 'p', 'n': 4})
          as ShieldEvent;
      expect(sh.absorbed, isFalse);
    });

    test('resultado de misión completo', () {
      final back = _eventJson.fromJson(
          _wire(_eventJson.toJson(MissionEndedEvent(_result))));
      final r = (back as MissionEndedEvent).result;
      expect(r.rank, MissionRank.a);
      expect(r.drops, {'p1': 'baculo2'});
      expect(r.eliteDrops.single.weaponId, 'espada2');
      expect(r.timeLeft, 17.25);
    });
  });

  group('GameSession', () {
    test('lobby con votación y preparación', () {
      final e = sessionEngine();
      var s = e.create();
      s = e.addPlayer(s, 'h', newProfile('Host', 'guerrero'))!.state;
      s = e.addPlayer(s, 'p1', newProfile('Ana', 'maga'))!.state;
      _expectSessionRoundTrip(s);
      s = act(e, s, 'h', const ProposeMissionAction('m1'));
      _expectSessionRoundTrip(s);
      final back = _sessionJson.fromJson(_wire(_sessionJson.toJson(s)));
      expect(back.players.keys, ['h', 'p1']); // orden de llegada
      expect(back.vote!.yes, {'h'});
      expect(back.players['p1']!.profile.classId, 'maga');
      s = act(e, s, 'p1', const VoteMissionAction(true));
      s = e.tick(s, 0.05).state;
      s = act(e, s, 'h', const ReadyAction(true));
      expect(s.mode, SessionMode.prep);
      _expectSessionRoundTrip(s);
      expect(_sessionJson.fromJson(_wire(_sessionJson.toJson(s))).prep!.ready,
          {'h': true});
    });

    test('una misión entera: campo, batalla y resultado', () {
      final e = sessionEngine();
      var s = inField(e, 'm1', classes: ['guerrero', 'maga']);
      final log = <SessionEvent>[];
      final seen = <SessionMode>{};
      var sawPlayerBuild = false, sawInflicts = false, sawStatuses = false;
      for (var i = 0; i < 40000 && s.result == null; i++) {
        if (i % 7 == 0) {
          _expectSessionRoundTrip(s);
          seen.add(s.mode);
          final b = s.battle;
          if (b != null) {
            sawPlayerBuild |= b.state.party.any((c) => c.build != null);
            sawInflicts |= b.state.enemies.any((c) => c.inflicts != null);
            sawStatuses |= [...b.state.party, ...b.state.enemies]
                .any((c) => c.statuses.values.any((n) => n > 0));
          }
        }
        switch (s.mode) {
          case SessionMode.battle:
            final b = s.battle!;
            if (b.waitingForPlayer) {
              final step = e.apply(
                  s, b.state.currentId!, const BattleAction(AttackCommand()));
              if (step != null) {
                log.addAll(step.events);
                s = step.state;
                continue;
              }
            }
          case SessionMode.levelUp:
            for (final p in s.playerList.toList()) {
              if (s.mustAllocate(p.id)) {
                s = act(e, s, p.id,
                    AllocateStatsAction({Attribute.vit: p.profile.points}));
              }
            }
          case SessionMode.field when s.graceLeft <= 0:
            final boss = s.mission!.enemies.firstWhere((x) => x.boss);
            s = moveTo(e, s, 'p0', boss.x, boss.y);
          default:
            break;
        }
        final step = e.tick(s, 0.05);
        log.addAll(step.events);
        s = step.state;
      }
      expect(s.result, isNotNull);
      _expectSessionRoundTrip(s);
      seen.add(s.mode);
      expect(seen, containsAll([SessionMode.field, SessionMode.battle, SessionMode.result]));
      expect(sawPlayerBuild, isTrue);
      expect(sawInflicts, isTrue);
      expect(sawStatuses, isTrue);

      // Todos los eventos reales de la partida también van y vuelven.
      expect(log.whereType<BattleStepEvent>(), isNotEmpty);
      for (final ev in log) {
        expect(_eventText(_eventJson.fromJson(_wire(_eventJson.toJson(ev)))),
            _eventText(ev));
      }

      // El cliente lee lo mismo que el host (lo que dibuja la UI).
      final back = _sessionJson.fromJson(_wire(_sessionJson.toJson(s)));
      expect(back.result!.rank, s.result!.rank);
      expect(back.mission!.seed, s.mission!.seed);
      expect(back.players['p1']!.profile.xp, s.players['p1']!.profile.xp);
    });

    test('combatiente con build: arma resuelta por el catálogo', () {
      final e = sessionEngine();
      var s = inField(e, 'm1', classes: ['paladin']);
      s = wait(e, s, 3);
      final en = s.mission!.enemies.firstWhere((x) => !x.boss && !x.elite);
      s = moveTo(e, s, 'p0', en.x, en.y);
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.battle);
      final back = _sessionJson.fromJson(_wire(_sessionJson.toJson(s)));
      final me = back.battle!.state.party.single;
      final orig = s.battle!.state.party.single;
      expect(me.build!.equippedWeapon.id, orig.build!.equippedWeapon.id);
      expect(me.build!.attributes.values, orig.build!.attributes.values);
      expect(me.maxHp, orig.maxHp);
      expect(back.battle!.waitingForPlayer, s.battle!.waitingForPlayer);
    });

    test('snapshot mal formado → FormatException', () {
      final e = sessionEngine();
      final s = e.addPlayer(e.create(), 'h', newProfile('Host', 'guerrero'))!.state;
      final j = _wire(_sessionJson.toJson(s));
      expect(() => _sessionJson.fromJson({...j, 'mode': 'volando'}),
          throwsFormatException);
      expect(() => _sessionJson.fromJson({...j}..remove('players')),
          throwsFormatException);
    });
  });
}
