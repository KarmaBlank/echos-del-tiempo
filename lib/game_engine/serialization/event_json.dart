import '../models/ascension.dart' show TrapKind;
import '../models/battle_event.dart';
import '../models/elements.dart';
import '../models/fish_line.dart' show AutoFishStop;
import '../models/game_map.dart' show PoiKind, QuestKind;
import '../models/game_session.dart';
import '../models/item.dart' show CraftOp;
import '../models/loot.dart';

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
        PausedEvent() => {'t': 'paused', 'id': e.playerId, 'name': e.name},
        ResumedEvent() => {'t': 'resumed', 'id': e.playerId, 'name': e.name},
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
            if (e.tier != ChestTier.madera) 'tr': e.tier.name,
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
        RunNodeEnteredEvent() => {'t': 'runNode', 'f': e.floor, 'n': e.nodeId},
        RunEndedEvent() => {'t': 'runEnd', 'win': e.victory},
        FishBiteEvent() => {
            't': 'fBite',
            'id': e.playerId,
            'sp': e.species,
            'cm': e.sizeCm,
          },
        MineDugEvent() => {
            't': 'mDug',
            'id': e.playerId,
            'x': e.tx,
            'y': e.ty,
            'c': e.code,
            if (e.label.isNotEmpty) 'l': e.label,
          },
        MineBombEvent() => {'t': 'mBomb', 'x': e.tx, 'y': e.ty, 'f': e.fuse},
        MineBlastEvent() => {'t': 'mBlast', 'x': e.tx, 'y': e.ty, 'r': e.radius},
        WaterLootEvent() => {
            't': 'fLoot',
            'id': e.playerId,
            'l': e.label,
            'r': e.rarity,
          },
        CropHarvestedEvent() => {
            't': 'cHarv',
            'id': e.playerId,
            'c': e.crop,
            'q': e.quality,
            'n': e.count,
            'x': e.tx,
            'y': e.ty,
            if (e.helper) 'h': true,
          },
        FarmLootEvent() => {
            't': 'cLoot',
            'id': e.playerId,
            'l': e.label,
            'r': e.rarity,
            'x': e.tx,
            'y': e.ty,
          },
        LightningEvent() => {
            't': 'bolt',
            'x': e.tx,
            'y': e.ty,
            if (e.lost) 'l': true,
          },
        FishAutoStoppedEvent() => {
            't': 'fAutoOff',
            'id': e.playerId,
            'r': e.reason.index,
            'n': e.caught,
          },
        FishCaughtEvent() => {
            't': 'fCaught',
            'id': e.playerId,
            'sp': e.species,
            'cm': e.sizeCm,
            if (e.auto) 'auto': true,
          },
        FloorChangedEvent() => {'t': 'floor', 'f': e.floor, 'down': e.down},
        StairsOpenedEvent() => {'t': 'stairs', 'f': e.floor},
        PoiUsedEvent() => {
            't': 'poi',
            'id': e.playerId,
            'poi': e.poiId,
            'k': e.kind.name,
            if (e.blessing != null) 'bl': e.blessing!.name,
            if (e.toPoi != null) 'to': e.toPoi,
          },
        QuestDoneEvent() => {
            't': 'quest',
            'q': e.questId,
            'f': e.floor,
            'k': e.kind.name,
          },
        FellIntoVoidEvent() => {'t': 'fall', 'id': e.playerId, 'f': e.floor},
        ZoneUnlockedEvent() => {'t': 'zoneUnlocked', 'id': e.playerId, 'z': e.zone},
        LootDropEvent() => {
            't': 'loot',
            'id': e.playerId,
            'd': e.drop.toJson(),
            'src': e.source.name,
            if (e.groundId != null) 'g': e.groundId,
            if (e.uid != null) 'u': e.uid,
          },
        LootPickedEvent() => {
            't': 'picked',
            'id': e.playerId,
            'g': e.groundId,
            'd': e.drop.toJson(),
          },
        ItemGivenEvent() => {
            't': 'given',
            'from': e.fromId,
            'to': e.toId,
            'd': e.drop.toJson(),
          },
        CraftedEvent() => {
            't': 'crafted',
            'id': e.playerId,
            'op': e.op.name,
            'u': e.uid,
          },
        EcoCompletedEvent() => {
            't': 'ecoDone',
            'ids': e.playerIds,
            'tier': e.tier,
            'z': e.zone,
            'b': e.boss,
          },
        MasteryUpEvent() => {'t': 'mastery', 'id': e.playerId, 'm': e.mastery},
        EcosUnlockedEvent() => {'t': 'ecoUnlocked', 'id': e.playerId},
        // Ascensión v0.5 (ascension.md § 6).
        TrialCompletedEvent() => {
            't': 'trialDone',
            'n': e.trial,
            'ids': e.playerIds,
          },
        AscensionChosenEvent() => {
            't': 'ascChosen',
            'id': e.playerId,
            'asc': e.ascensionId,
          },
        TrapTriggeredEvent() => {
            't': 'trap',
            'id': e.playerId,
            'k': e.kind.name,
            'd': e.damage,
          },
        // Jefes del Abismo v0.8 (abyss_bosses.md § 5).
        AbyssDefeatedEvent() => {
            't': 'abyssDone',
            'n': e.boss,
            'ids': e.playerIds,
          },
        // TUTORIAL v0.9 (combat_tutorial.md § 6).
        TutorialDoneEvent() => {
            't': 'tutDone',
            'ids': e.playerIds,
            'v': e.version,
          },
        // Hazañas v0.14 (achievements.md § 5.1).
        AchievementUnlockedEvent() => {'t': 'ach', 'p': e.playerId, 'id': e.id},
      };

  static LootDrop _drop(Object? raw) =>
      LootDrop.fromJson(raw) ??
      (throw FormatException('JSON inválido: drop', raw));

  SessionEvent fromJson(Json j) {
    final t = j.str('t');
    switch (t) {
      case 'sys':
        return SystemMessageEvent(j.str('txt'));
      case 'chat':
        return ChatMessageEvent(j.str('id'), j.str('from'), j.str('txt'));
      case 'paused':
        return PausedEvent(j.str('id'), j.str('name'));
      case 'resumed':
        return ResumedEvent(j.str('id'), j.str('name'));
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
            weaponId: j.strOrNull('w'),
            tier: j.enumOrNull('tr', ChestTier.values) ?? ChestTier.madera);
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
      case 'runNode':
        return RunNodeEnteredEvent(j.integer('f'), j.integer('n'));
      case 'runEnd':
        return RunEndedEvent(j.boolean('win'));
      case 'fBite':
        return FishBiteEvent(j.str('id'), j.str('sp'), j.integer('cm'));
      case 'fLoot':
        return WaterLootEvent(j.str('id'), j.str('l'), j.integer('r'));
      case 'mDug':
        return MineDugEvent(j.str('id'), j.integer('x'), j.integer('y'),
            j.str('c'), j.strOrNull('l') ?? '');
      case 'mBomb':
        return MineBombEvent(j.integer('x'), j.integer('y'),
            (j['f'] as num?)?.toDouble() ?? 1);
      case 'mBlast':
        return MineBlastEvent(j.integer('x'), j.integer('y'), j.integer('r'));
      case 'cHarv':
        return CropHarvestedEvent(j.str('id'), j.str('c'), j.integer('q'),
            j.integer('n'), j.integer('x'), j.integer('y'),
            helper: j['h'] == true);
      case 'cLoot':
        return FarmLootEvent(j.str('id'), j.str('l'), j.integer('r'),
            j.integer('x'), j.integer('y'));
      case 'bolt':
        return LightningEvent(j.integer('x'), j.integer('y'),
            lost: j['l'] == true);
      case 'fAutoOff':
        final r = j.integer('r').clamp(0, AutoFishStop.values.length - 1);
        return FishAutoStoppedEvent(
            j.str('id'), AutoFishStop.values[r], j.integer('n'));
      case 'fCaught':
        return FishCaughtEvent(j.str('id'), j.str('sp'), j.integer('cm'),
            auto: j['auto'] == true);
      case 'floor':
        return FloorChangedEvent(j.integer('f'), down: j.boolean('down'));
      case 'stairs':
        return StairsOpenedEvent(j.integer('f'));
      case 'poi':
        return PoiUsedEvent(
            j.str('id'), j.integer('poi'), j.enumByName('k', PoiKind.values),
            blessing: j.enumOrNull('bl', BlessingKind.values),
            toPoi: j.intOrNull('to'));
      case 'quest':
        return QuestDoneEvent(j.integer('q'), j.integer('f'),
            j.enumByName('k', QuestKind.values));
      case 'fall':
        return FellIntoVoidEvent(j.str('id'), j.integer('f'));
      case 'zoneUnlocked':
        return ZoneUnlockedEvent(j.str('id'), j.integer('z'));
      case 'loot':
        return LootDropEvent(j.str('id'), _drop(j['d']),
            j.enumByName('src', LootSource.values),
            groundId: j.intOrNull('g'), uid: j.strOrNull('u'));
      case 'picked':
        return LootPickedEvent(j.str('id'), j.integer('g'), _drop(j['d']));
      case 'given':
        return ItemGivenEvent(j.str('from'), j.str('to'), _drop(j['d']));
      case 'crafted':
        return CraftedEvent(
            j.str('id'), j.enumByName('op', CraftOp.values), j.str('u'));
      case 'ecoDone':
        return EcoCompletedEvent(List.unmodifiable(j.strings('ids')),
            tier: j.integer('tier'), zone: j.integer('z'), boss: j.integer('b'));
      case 'mastery':
        return MasteryUpEvent(j.str('id'), j.integer('m'));
      case 'ecoUnlocked':
        return EcosUnlockedEvent(j.str('id'));
      case 'trialDone':
        return TrialCompletedEvent(
            j.integer('n'), List.unmodifiable(j.strings('ids')));
      case 'ascChosen':
        return AscensionChosenEvent(j.str('id'), j.str('asc'));
      case 'trap':
        return TrapTriggeredEvent(j.str('id'),
            j.enumByName('k', TrapKind.values), j.integer('d'));
      case 'tutDone':
        return TutorialDoneEvent(
            List.unmodifiable(j.strings('ids')), j.integer('v'));
      case 'abyssDone':
        return AbyssDefeatedEvent(
            j.integer('n'), List.unmodifiable(j.strings('ids')));
      case 'ach':
        return AchievementUnlockedEvent(j.str('p'), j.str('id'));
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
            if (e.vulnerable) 'vul': true,
            if (e.hitIndex != 0) 'hi': e.hitIndex,
            if (e.chainFrom != null) 'cf': e.chainFrom,
            if (e.pierced) 'pc': true,
            if (e.affinity != 1) 'af': e.affinity,
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
        BreakEvent() => {
            'k': 'brk',
            'id': e.targetId,
            'ph': e.phase.name,
            'g': e.gauge,
            'max': e.max,
            if (e.cancelledUlt) 'cu': true,
          },
        EnemyUltWarningEvent() => {
            'k': 'eultWarn',
            'id': e.actorId,
            'u': e.ultId,
            'name': e.name,
          },
        EnemyUltEvent() => {
            'k': 'eult',
            'id': e.actorId,
            'u': e.ultId,
            'name': e.name,
            'tg': e.targetId,
            'all': e.allTargets,
            if (e.wipedBuffs) 'wipe': true,
          },
        BossMechanicEvent() => {
            'k': 'boss',
            'id': e.actorId,
            'ph': e.phase.name,
            if (e.targetId != null) 'tg': e.targetId,
            if (e.value != 0) 'v': e.value,
          },
        // Reacciones v0.7 (elemental_reactions.md § 8).
        ReactionEvent() => {
            'k': 'react',
            'id': e.targetId,
            'rk': e.kind.name,
            'n': e.amount,
            if (e.sourceId != null) 'src': e.sourceId,
            if (e.consumedStacks != 0) 'cs': e.consumedStacks,
            if (e.splash.isNotEmpty) 'sp': e.splash,
          },
        IceEvent() => {'k': 'ice', 'id': e.targetId, 'ph': e.phase.name},
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
          vulnerable: j.flag('vul'),
          hitIndex: j.intOrNull('hi') ?? 0,
          chainFrom: j.strOrNull('cf'),
          pierced: j.flag('pc'),
          affinity: j.dblOrNull('af') ?? 1,
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
      case 'brk':
        return BreakEvent(j.str('id'), j.enumByName('ph', BreakPhase.values),
            j.dbl('g'), j.dbl('max'),
            cancelledUlt: j.flag('cu'));
      case 'eultWarn':
        return EnemyUltWarningEvent(j.str('id'), j.str('u'), j.str('name'));
      case 'eult':
        return EnemyUltEvent(j.str('id'), j.str('u'), j.str('name'),
            targetId: j.strOrNull('tg'),
            allTargets: j.boolean('all'),
            wipedBuffs: j.flag('wipe'));
      case 'boss':
        return BossMechanicEvent(
            j.str('id'), j.enumByName('ph', BossMechanicPhase.values),
            targetId: j.strOrNull('tg'), value: j.dblOrNull('v') ?? 0);
      case 'react':
        final sp = j.objOrNull('sp');
        return ReactionEvent(j.str('id'),
            j.enumByName('rk', ReactionKind.values), j.integer('n'),
            sourceId: j.strOrNull('src'),
            consumedStacks: j.intOrNull('cs') ?? 0,
            splash: sp == null
                ? const {}
                : {for (final e in sp.entries) e.key: (e.value as num).toInt()});
      case 'ice':
        return IceEvent(j.str('id'), j.enumByName('ph', IcePhase.values));
    }
    throw FormatException('JSON inválido: evento de batalla desconocido', k);
  }
}
