import '../models/battle_event.dart';
import '../models/game_session.dart';
import '../models/passive_mechanic.dart';
import '../models/session_event.dart';
import '../models/status.dart';
import 'action_json.dart';
import 'json_read.dart';
import 'session_json.dart';

/// `SessionEvent` (y los `BattleEvent` de un paso de batalla) ⇄ JSON,
/// para la lista `ev` del mensaje `state`. Ver docs/specs/netcode.md.
class EventJson {
  const EventJson([this.session = const SessionJson()]);

  /// Para el resultado de `MissionEndedEvent`.
  final SessionJson session;

  Json toJson(SessionEvent e) => switch (e) {
        SystemMessageEvent() => {'t': 'sys', 'txt': e.text},
        ChatMessageEvent() => {
            't': 'chat',
            'id': e.playerId,
            'from': e.from,
            'txt': e.text,
          },
        PlayerJoinedEvent() => {'t': 'joined', 'id': e.playerId},
        PlayerLeftEvent() => {'t': 'left', 'id': e.playerId},
        MissionStartedEvent() => {
            't': 'missionStart',
            'm': e.missionId,
            'seed': e.seed,
          },
        ObjectiveProgressEvent() => {
            't': 'obj',
            'k': e.kind.name,
            'n': e.count,
            'goal': e.goal,
          },
        GateOpenedEvent() => {'t': 'gate'},
        ChestOpenedEvent() => {
            't': 'chest',
            'id': e.playerId,
            'cr': e.credits,
            if (e.item != null) 'it': ActionJson.itemKey(e.item!),
            if (e.weaponId != null) 'w': e.weaponId,
          },
        BattleStartedEvent() => {
            't': 'battleStart',
            'bid': e.battleId,
            'fe': e.fieldEnemyId,
            'boss': e.boss,
            'elite': e.elite,
          },
        BattleStepEvent() => {
            't': 'battleStep',
            'ev': [for (final b in e.events) battleToJson(b)],
          },
        LevelUpEvent() => {'t': 'lvl', 'id': e.playerId, 'lvl': e.level},
        BattleFinishedEvent() => {'t': 'battleEnd', 'win': e.victory},
        WeaponDropEvent() => {
            't': 'drop',
            'id': e.playerId,
            'w': e.weaponId,
            'src': e.source,
          },
        MissionEndedEvent() => {
            't': 'missionEnd',
            'r': session.resultToJson(e.result),
          },
        ReturnedToLobbyEvent() => {'t': 'lobby'},
      };

  SessionEvent fromJson(Json j) {
    final t = j.str('t');
    switch (t) {
      case 'sys':
        return SystemMessageEvent(j.str('txt'));
      case 'chat':
        return ChatMessageEvent(j.str('id'), j.str('from'), j.str('txt'));
      case 'joined':
        return PlayerJoinedEvent(j.str('id'));
      case 'left':
        return PlayerLeftEvent(j.str('id'));
      case 'missionStart':
        return MissionStartedEvent(j.str('m'), j.integer('seed'));
      case 'obj':
        return ObjectiveProgressEvent(j.enumByName('k', ObjectiveKind.values),
            j.integer('n'), j.integer('goal'));
      case 'gate':
        return const GateOpenedEvent();
      case 'chest':
        final it = j.strOrNull('it');
        return ChestOpenedEvent(j.str('id'), j.integer('cr'),
            item: it == null ? null : ActionJson.itemFromKey(it),
            weaponId: j.strOrNull('w'));
      case 'battleStart':
        return BattleStartedEvent(j.integer('bid'), j.integer('fe'),
            boss: j.boolean('boss'), elite: j.boolean('elite'));
      case 'battleStep':
        return BattleStepEvent(List.unmodifiable([
          for (final raw in j.list('ev')) battleFromJson(asJson(raw)),
        ]));
      case 'lvl':
        return LevelUpEvent(j.str('id'), j.integer('lvl'));
      case 'battleEnd':
        return BattleFinishedEvent(j.boolean('win'));
      case 'drop':
        return WeaponDropEvent(j.str('id'), j.str('w'), j.str('src'));
      case 'missionEnd':
        return MissionEndedEvent(session.resultFromJson(j.obj('r')));
      case 'lobby':
        return const ReturnedToLobbyEvent();
    }
    throw FormatException('JSON inválido: evento desconocido', t);
  }

  // ------------------------------------------------------------------
  // BattleEvent
  // ------------------------------------------------------------------

  Json battleToJson(BattleEvent e) => switch (e) {
        TurnStartedEvent() => {'k': 'turn', 'id': e.actorId},
        DamageEvent() => {
            'k': 'dmg',
            'id': e.targetId,
            'n': e.amount,
            'crit': e.critical,
            'cm': e.critMultiplier,
            'pm': e.pierceMultiplier,
            'st': e.fromStatus,
            'src': e.statusSource?.name,
            if (e.sourceId != null) 'proc': e.sourceId,
          },
        ActionEvent() => {
            'k': 'act',
            'id': e.actorId,
            'kind': e.kind.name,
            'sk': e.skillId,
            'pt': e.partnerId,
            'tg': e.targetId,
            'all': e.allTargets,
          },
        HealEvent() => {
            'k': 'heal',
            'id': e.targetId,
            'n': e.amount,
            'mp': e.mana,
          },
        StatusAppliedEvent() => {
            'k': 'status',
            'id': e.targetId,
            's': e.kind.name,
            'n': e.stacks,
            'weak': e.weakness,
          },
        TurnSkippedEvent() => {'k': 'skip', 'id': e.actorId, 'cause': e.cause.name},
        DelayedEvent() => {'k': 'delay', 'id': e.targetId},
        KnockedOutEvent() => {'k': 'ko', 'id': e.targetId},
        RevivedEvent() => {'k': 'revive', 'id': e.targetId},
        UltimateUsedEvent() => {'k': 'ult', 'id': e.actorId, 'name': e.name},
        BattleEndedEvent() => {
            'k': 'end',
            'win': e.victory,
            'xp': e.xp,
            'cr': e.credits,
          },
        ProcEvent() => {
            'k': 'proc',
            'id': e.actorId,
            'src': e.sourceId,
            'tg': e.targetId,
          },
        BuffAppliedEvent() => {
            'k': 'buff',
            'id': e.targetId,
            'src': e.sourceId,
            'stat': e.stat.name,
            'v': e.value,
            'turns': e.turns,
          },
        ShieldEvent() => {
            'k': 'shield',
            'id': e.targetId,
            'n': e.amount,
            'abs': e.absorbed,
          },
        _ => throw ArgumentError('Evento de batalla sin JSON: $e'),
      };

  BattleEvent battleFromJson(Json j) {
    final k = j.str('k');
    switch (k) {
      case 'turn':
        return TurnStartedEvent(j.str('id'));
      case 'dmg':
        return DamageEvent(
          j.str('id'),
          j.integer('n'),
          critical: j.boolean('crit'),
          critMultiplier: j.dbl('cm'),
          pierceMultiplier: j.dbl('pm'),
          fromStatus: j.boolean('st'),
          statusSource: j.enumOrNull('src', StatusKind.values),
          sourceId: j.strOrNull('proc'),
        );
      case 'act':
        return ActionEvent(
          j.str('id'),
          j.enumByName('kind', BattleActionKind.values),
          skillId: j.strOrNull('sk'),
          partnerId: j.strOrNull('pt'),
          targetId: j.strOrNull('tg'),
          allTargets: j.boolean('all'),
        );
      case 'heal':
        return HealEvent(j.str('id'), j.integer('n'), mana: j.boolean('mp'));
      case 'status':
        return StatusAppliedEvent(j.str('id'),
            j.enumByName('s', StatusKind.values), j.integer('n'),
            weakness: j.boolean('weak'));
      case 'skip':
        return TurnSkippedEvent(
            j.str('id'), j.enumByName('cause', StatusKind.values));
      case 'delay':
        return DelayedEvent(j.str('id'));
      case 'ko':
        return KnockedOutEvent(j.str('id'));
      case 'revive':
        return RevivedEvent(j.str('id'));
      case 'ult':
        return UltimateUsedEvent(j.str('id'), j.str('name'));
      case 'end':
        return BattleEndedEvent(
            j.boolean('win'), j.integer('xp'), j.integer('cr'));
      case 'proc':
        return ProcEvent(j.str('id'), j.str('src'),
            targetId: j.strOrNull('tg'));
      case 'buff':
        return BuffAppliedEvent(
            j.str('id'),
            j.str('src'),
            j.enumByName('stat', BuffStat.values),
            j.dbl('v'),
            j.integer('turns'));
      case 'shield':
        return ShieldEvent(j.str('id'), j.integer('n'),
            absorbed: j.flag('abs'));
    }
    throw FormatException('JSON inválido: evento de batalla desconocido', k);
  }
}
