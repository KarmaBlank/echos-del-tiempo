import 'run_json.dart';
import '../models/attributes.dart';
import '../models/battle_command.dart';
import '../models/build_wants.dart';
import '../models/eco.dart' show EcoCraftOp;
import '../models/fish_line.dart';
import '../models/inventory_sort.dart';
import '../models/item.dart' show CraftOp;
import '../models/loot.dart' show LootDrop;

import '../models/player_profile.dart';
import '../models/session_action.dart';
import '../models/upgrade_stat.dart';
import 'json_read.dart';

/// `SessionAction` ⇄ JSON con las claves de `onMsg` del prototipo
/// (`{t:'pos', x, y, dir, mv, ep}`, `{t:'cmd', a:'atk', tg}`...).
/// Tabla completa en docs/specs/netcode.md § "Cliente → host".
abstract final class ActionJson {
  /// Clave de `BattleItem` (`p[d.it]` del prototipo: `pot` / `eter`).
  static String itemKey(BattleItem i) => switch (i) {
        BattleItem.potion => 'pot',
        BattleItem.ether => 'eter',
        BattleItem.aether => 'eterV',
      };

  static BattleItem itemFromKey(String k) => switch (k) {
        'pot' => BattleItem.potion,
        'eter' => BattleItem.ether,
        'eterV' => BattleItem.aether,
        _ => throw FormatException('JSON inválido: objeto de batalla', k),
      };

  static Json toJson(SessionAction a) => switch (a) {
        MoveAction() => {
            't': 'pos',
            'x': a.x,
            'y': a.y,
            'dir': a.dir,
            'mv': a.moving,
            'ep': a.epoch,
          },
        ProposeMissionAction() => {'t': 'propose', 'id': a.missionId},
        GatherAction() => {'t': 'gather', 'op': a.op.name},
        VoteMissionAction() => {'t': 'vote', 'ok': a.yes},
        ReadyAction() => {'t': 'ready', 'ok': a.ready},
        CancelPrepAction() => {'t': 'cancelPrep'},
        ActivateSealAction() => {'t': 'seal', 'id': a.itemId},
        ChangeClassAction() => {'t': 'cls', 'cls': a.classId},
        RespecAction() => {'t': 'respec'},
        AllocateStatsAction() => {
            't': 'stats',
            'add': {
              for (final e in a.add.entries)
                PlayerProfile.attributeKey(e.key): e.value,
            },
          },
        EquipAction() => {'t': 'equip', 'w': a.weaponId},
        TakeNodeAction() => {'t': 'node', 'id': a.nodeId},
        UntakeNodeAction() => {'t': 'untake', 'id': a.nodeId},
        TakeNodesAction() => {'t': 'nodes', 'ids': a.nodeIds},
        ChooseMilestoneAction() => {
            't': 'milestone',
            'm': a.milestone,
            'id': a.keystoneId,
          },
        ResetTreeAction() => {'t': 'treeReset'},
        FuseAction() => {
            't': 'fuse',
            'a': a.baseWeaponId,
            'b': a.sacrificeWeaponId,
            'sk': a.skillId,
          },
        UpgradeAction() => {'t': 'up', 'w': a.weaponId, 'stat': a.stat.key},
        BuyItemAction() => {'t': 'buyItem', 'it': itemKey(a.item)},
        UseItemAction() => {'t': 'useItem', 'it': itemKey(a.item)},
        BuyWeaponAction() => {'t': 'buy', 'w': a.weaponId},
        BattleAction() => {'t': 'cmd', ...commandToJson(a.command)},
        CancelQueuedBattleAction() => {'t': 'uncmd'},
        MoveQueuedBattleAction() => {'t': 'qmv', 'p': a.playerId, 'to': a.to},
        ConfirmBattleQueueAction() => {'t': 'qok'},
        ChatAction() => {'t': 'chat', 'txt': a.text},
        PauseAction() => {'t': 'pause', 'on': a.paused},
        BackToLobbyAction() => {'t': 'back'},
        LeaveReadyAction() => {'t': 'leave', 'ok': a.ready},
        TakeLostLootAction() => {'t': 'lost', 'id': a.lostId},
        UseStairsAction() => {'t': 'stairs', 'down': a.down},
        InteractPoiAction() => {
            't': 'poi',
            'id': a.poiId,
            if (a.toPoi != null) 'to': a.toPoi,
          },
        CraftAction() => {
            't': 'craft',
            'op': a.op.name,
            'w': a.targetUid,
            if (a.sourceUid != null) 'src': a.sourceUid,
            if (a.index != 0) 'i': a.index,
            if (a.skillId != null) 'sk': a.skillId,
            if (a.replaceSkillId != null) 'rep': a.replaceSkillId,
            // v0.5.1 (protocolo 6): elección manual de LIMPIAR INVENTARIO.
            if (a.uids.isNotEmpty) 'us': a.uids,
          },
        GiveItemAction() => {
            't': 'give',
            'to': a.toPlayerId,
            'tok': a.token,
            if (a.count != 1) 'n': a.count,
          },
        DropItemAction() => {
            't': 'drop',
            'tok': a.token,
            if (a.count != 1) 'n': a.count,
          },
        PickUpAction() => {'t': 'pick', 'id': a.groundId},
        StashPutAction() => {
            't': 'stashPut',
            'op': a.opId,
            'it': [
              for (final i in a.items)
                {'tok': i.token, if (i.count != 1) 'n': i.count},
            ],
          },
        StashTakeAction() => {
            't': 'stashTake',
            'op': a.opId,
            'd': [for (final d in a.drops) d.toJson()],
          },
        MoveInventoryAction() => {'t': 'invMove', 'a': a.from, 'b': a.to},
        SortInventoryAction() => {'t': 'invSort', 'k': a.key.name},
        SeenItemsAction() => {'t': 'seen', 'u': a.uids},
        SetLootFilterAction() => {'t': 'filter', 'txt': a.text},
        // ULT v2 (ultimates_v2.md § 5.2).
        SelectUltAction() => {'t': 'ultSel', 'id': a.ultId},
        UpgradeUltAction() => {'t': 'ultUp', 'id': a.ultId},
        SetBuildWantsAction(:final wants) => {
            't': 'wants',
            if (wants != null && !wants.isEmpty) 'w': wants.toJson(),
          },
        ProposeEcoAction() => {'t': 'eco', 'u': a.uid},
        EcoCraftAction() => {'t': 'ecoCraft', 'u': a.uid, 'op': a.op.name},
        EcoFuseAction() => {'t': 'ecoFuse', 'us': a.uids},
        DevGrantEcoAction() => {'t': 'devEco', 'tier': a.tier},
        // Ascensión v0.5 (ascension.md § 6).
        ProposeTrialAction() => {'t': 'trial', 'n': a.trial},
        ChooseAscensionAction() => {'t': 'ascChoose', 'id': a.ascensionId},
        TakeAscensionNodeAction() => {'t': 'ascNode', 'id': a.nodeId},
        ResetAscensionAction() => {'t': 'ascReset', if (a.full) 'full': true},
        DevGrantTrialAction() => {'t': 'devTrial', 'n': a.trial},
        // Jefes del Abismo v0.8 (abyss_bosses.md § 5).
        ProposeAbyssAction() => {'t': 'abyss', 'n': a.boss},
        ProposeRiftAction() => {'t': 'rift', 'u': a.uid},
        EventNpcActAction() => {'t': 'wevAct', 'u': a.uid, 'i': a.index},
        ScheduleTownEventAction() => {'t': 'tev', 'u': a.id},
        ProposeTourneyAction() => {'t': 'tourney', 'u': a.id},
        // TUTORIAL v0.9 (combat_tutorial.md § 6).
        StartTutorialAction() => {'t': 'tut', 'cmp': a.companions},
        TutorialAckAction() => {'t': 'tutOk'},
        TutorialControlAction() => {'t': 'tutCtl', 'op': a.op.name},
        // v0.9.6 (combat_tutorial.md § 4.4).
        TutorialChoiceAction() => {'t': 'tutPick', 'c': a.choice},
        DevAbyssAction() => {'t': 'devAbyss', 'k': a.kind},
        // Hazañas v0.14 (achievements.md § 5.2).
        ClaimAchievementAction() => {'t': 'ach', 'id': a.id},
        // Travesía (protocolo Travesía 1; roguelike.md).
        RunStartAction() => {
            't': 'runStart',
            if (a.zones != 0) 'z': a.zones,
            if (a.difficulty != 0) 'df': a.difficulty,
            if (a.eliteWins.isNotEmpty) 'ew': a.eliteWins,
          },
        RunPrepAction() => {'t': 'runPrep', 'p': RunJson.prepToJson(a.prep)},
        RunVoteAction() => {'t': 'runVote', 'n': a.nodeId},
        RunRewardAction() => {
            't': 'runReward',
            if (a.tree != null) 'tr': a.tree,
            if (a.weapon != null) 'w': a.weapon,
            if (a.extra != null) 'x': a.extra,
            if (a.ult != null) 'u': a.ult,
            if (a.drop != null) 'd': a.drop,
          },
        RunReadyAction() => {'t': 'runReady'},
        RunBuyUltAction() => {'t': 'runBuyUlt', 'u': a.ultId},
        RunSkillAction() => {'t': 'runSkill', 's': a.skillId, 'on': a.equip},
        RunUpgradeSkillAction() => {'t': 'runSkillUp', 's': a.skillId},
        // Pesca v0.22.0 (protocolo 42, fishing.md § 6).
        FishBiteAction() => {'t': 'fBite', 'pw': a.power},
        FishResultAction() => {'t': 'fRes', 'ok': a.success},

        // Protocolo 43 (v0.22.2): pesca en el mapa.
        FishLineAction() => {
            't': 'fLn',
            if (a.line case final l?) 'l': l.toJson(),
          },
        // Protocol 67: auto-fishing (fishing.md § 6).
        FishAutoAction() => {
            't': 'fAuto',
            if (a.on) 'on': true,
            if (!a.on) 'r': a.reason.index,
          },
        // Protocolo 60 (v0.37.0): Llama errante.
        WispAction() => {'t': 'wisp', if (a.on) 'on': true},
        RaftAction() => {'t': 'raft', if (a.on) 'on': true},
        SellFishAction() => {
            't': 'fSell',
            if (a.species != null) 'sp': a.species,
            if (a.materials) 'mat': true,
          },
        ExchangeFishAction() => {'t': 'fSwap', 'sp': a.species},
        BuyRodAction() => {'t': 'rodBuy', 'r': a.rodId},
        EquipRodAction() => {'t': 'rodEq', 'r': a.rodId},
        // Protocolo 44 (v0.23.0): huerta, pueblo y árboles de oficios.
        FarmTileAction() => {
            't': 'farm',
            'o': a.op.name,
            'x': a.tx,
            'y': a.ty,
            if (a.seed != null) 'sd': a.seed,
          },
        // Protocol 88: player stall (player_shop.md § 4).
        StallAction() => {
            't': 'stall',
            'o': a.op.name,
            'c': a.cell,
            if (a.qty != 0) 'n': a.qty,
            if (a.price != 0) 'p': a.price,
            if (a.owner != null) 'ow': a.owner,
          },
        GiveLifeAction() => {
            't': 'giveLife',
            'to': a.toPlayerId,
            'c': a.cell,
            if (a.count != 1) 'n': a.count,
          },
        FarmShopAction() => {
            't': 'farmShop',
            'o': a.op.name,
            if (a.id != null) 'id': a.id,
            if (a.n != 1) 'n': a.n,
            if (a.materials) 'mat': true,
            if (a.to != null) 'to': a.to,
          },
        TownAction() => {
            't': 'town',
            'o': a.op.name,
            if (a.id != null) 'id': a.id,
            if (a.target != null) 'tg': a.target,
            if (a.x != null) 'x': a.x,
            if (a.y != null) 'y': a.y,
            if (a.n != 1) 'n': a.n,
          },
        LifeTreeAction() => {
            't': 'lifeTree',
            'k': a.skill,
            if (a.node != null) 'n': a.node,
          },
        // Protocolo 46 (v0.26.0): mapa de viaje y recolección.
        TravelAction() => {
            't': 'travel',
            'p': a.place,
            if (a.ecoZone != null) 'ez': a.ecoZone,
          },
        ForageAction() => {'t': 'forage', 'i': a.spot},
        // Protocol 91: cozy life (cozy_life.md).
        CozyAction() => {
            't': 'cozy',
            'op': a.op.index,
            if (a.id != null) 'id': a.id,
            if (a.x != null) 'x': a.x,
            if (a.y != null) 'y': a.y,
          },
        // Protocol 73: region waystones (biome_regions.md § 4).
        WaystoneAction() => {
            't': 'way',
            'i': a.stone,
            if (a.to != null) 'to': a.to,
          },
        // Biome exploration v2 (biome_exploration.md § 9).
        WildLootAction() => {
            't': 'wx',
            'i': a.i,
            if (a.shrine) 's': 1,
          },
        // Protocol 69: mining and smithing (mining_smithing.md § 6).
        MineAction() => {
            't': 'mine',
            'o': a.op.name,
            if (a.x != 0) 'x': a.x,
            if (a.y != 0) 'y': a.y,
            if (a.id != null) 'i': a.id,
            if (a.mat != null) 'g': a.mat,
            if (a.n != 1) 'n': a.n,
          },
        SmithAction() => {
            't': 'smith',
            'o': a.op.name,
            'g': a.material,
            if (a.base != null) 'b': a.base,
            if (a.rarity != 0) 'r': a.rarity,
            if (a.n != 1) 'n': a.n,
          },
        // Protocolo 57 (v0.33.0): salir solo de la mazmorra.
        LeaveDungeonAction() => {
            't': 'leaveD',
            if (a.poiId != null) 'i': a.poiId,
          },
        // Protocolo 63: IR CON otro jugador.
        JoinPlayerAction() => {'t': 'joinP', 'p': a.targetId},
        // Protocolo 58 (v0.34.0): Ofrenda del jefe.
        OfferBossAction() => {'t': 'offer'},
      };

  /// Lanza [FormatException] si [j] no es una acción conocida y bien formada.
  static SessionAction fromJson(Json j) {
    final t = j.str('t');
    switch (t) {
      case 'pos':
        return MoveAction(j.dbl('x'), j.dbl('y'),
            epoch: j.integer('ep'),
            dir: j.integer('dir') > 0 ? 1 : -1,
            moving: j.flag('mv'));
      case 'propose':
        return ProposeMissionAction(j.str('id'));
      case 'gather':
        return GatherAction(j.enumByName('op', GatherOp.values));
      case 'vote':
        return VoteMissionAction(j.boolean('ok'));
      case 'ready':
        return ReadyAction(j.boolean('ok'));
      case 'cancelPrep':
        return const CancelPrepAction();
      case 'seal':
        return ActivateSealAction(j.integer('id'));
      case 'cls':
        return ChangeClassAction(j.str('cls'));
      case 'respec':
        return const RespecAction();
      case 'stats':
        final add = j.obj('add');
        final out = <Attribute, int>{};
        for (final a in Attribute.values) {
          final v = add.intOrNull(PlayerProfile.attributeKey(a));
          if (v != null) out[a] = v;
        }
        return AllocateStatsAction(out);
      case 'equip':
        return EquipAction(j.str('w'));
      case 'node':
        return TakeNodeAction(j.str('id'));
      case 'nodes':
        return TakeNodesAction([
          for (final x in asList(j['ids']).take(64))
            x is String ? x : throw const FormatException('JSON inválido: id'),
        ]);
      case 'milestone':
        return ChooseMilestoneAction(j.integer('m'), j.str('id'));
      case 'untake':
        return UntakeNodeAction(j.str('id'));
      case 'treeReset':
        return const ResetTreeAction();
      case 'fuse':
        return FuseAction(j.str('a'), j.str('b'), j.str('sk'));
      case 'up':
        final stat = UpgradeStat.fromKey(j.str('stat')) ??
            (throw FormatException('JSON inválido: estadística', j['stat']));
        return UpgradeAction(j.str('w'), stat);
      case 'buyItem':
        return BuyItemAction(itemFromKey(j.str('it')));
      case 'useItem':
        return UseItemAction(itemFromKey(j.str('it')));
      case 'buy':
        return BuyWeaponAction(j.str('w'));
      case 'cmd':
        return BattleAction(commandFromJson(j));
      case 'uncmd':
        return const CancelQueuedBattleAction();
      case 'qmv':
        return MoveQueuedBattleAction(j.str('p'), j.integer('to'));
      case 'qok':
        return const ConfirmBattleQueueAction();
      case 'chat':
        return ChatAction(j.str('txt'));
      case 'pause':
        return PauseAction(j.boolean('on'));
      case 'back':
        return const BackToLobbyAction();
      case 'leave':
        return LeaveReadyAction(j.boolean('ok'));
      case 'lost':
        return TakeLostLootAction(j.integer('id'));
      case 'stairs':
        return UseStairsAction(down: j.boolean('down'));
      case 'poi':
        return InteractPoiAction(j.integer('id'), toPoi: j.intOrNull('to'));
      case 'craft':
        return CraftAction(j.enumByName('op', CraftOp.values), j.str('w'),
            sourceUid: j.strOrNull('src'),
            index: j.intOrNull('i') ?? 0,
            skillId: j.strOrNull('sk'),
            replaceSkillId: j.strOrNull('rep'),
            uids: j['us'] == null
                ? const []
                : List.unmodifiable(j.strings('us')));
      case 'give':
        return GiveItemAction(j.str('to'), j.str('tok'),
            count: j.intOrNull('n') ?? 1);
      case 'drop':
        return DropItemAction(j.str('tok'), count: j.intOrNull('n') ?? 1);
      case 'stashPut':
        final its = j['it'];
        return StashPutAction(j.str('op'), [
          if (its is List)
            for (final r in its.take(StashPutAction.maxItems))
              if (r is Map && r['tok'] is String)
                StashPutItem(r['tok'] as String,
                    count: r['n'] is num ? (r['n'] as num).toInt() : 1),
        ]);
      case 'stashTake':
        final ds = j['d'];
        return StashTakeAction(j.str('op'), [
          if (ds is List)
            for (final r in ds.take(StashPutAction.maxItems))
              if (LootDrop.fromJson(r) case final d?) d,
        ]);
      case 'pick':
        return PickUpAction(j.integer('id'));
      case 'invMove':
        return MoveInventoryAction(j.integer('a'), j.integer('b'));
      case 'seen':
        final u = j['u'];
        return SeenItemsAction(u is List
            ? [
                for (final e in u)
                  if (e is String) e
              ]
            : const []);
      case 'invSort':
        return SortInventoryAction(j.enumByName('k', InventorySortKey.values));
      case 'filter':
        return SetLootFilterAction(j.strOrNull('txt'));
      case 'ultSel':
        return SelectUltAction(j.strOrNull('id'));
      case 'ultUp':
        return UpgradeUltAction(j.str('id'));
      case 'wants':
        final w = BuildWants.fromJson(j['w']);
        return SetBuildWantsAction(w.isEmpty ? null : w);
      case 'eco':
        return ProposeEcoAction(j.str('u'));
      case 'ecoCraft':
        return EcoCraftAction(
            j.str('u'), j.enumByName('op', EcoCraftOp.values));
      case 'ecoFuse':
        return EcoFuseAction(List.unmodifiable(j.strings('us')));
      case 'devEco':
        return DevGrantEcoAction(j.integer('tier'));
      case 'trial':
        return ProposeTrialAction(j.integer('n'));
      case 'ascChoose':
        return ChooseAscensionAction(j.str('id'));
      case 'ascNode':
        return TakeAscensionNodeAction(j.str('id'));
      case 'ascReset':
        return ResetAscensionAction(full: j.flag('full'));
      case 'devTrial':
        return DevGrantTrialAction(j.integer('n'));
      case 'abyss':
        return ProposeAbyssAction(j.integer('n'));
      case 'rift':
        return ProposeRiftAction(j.str('u'));
      case 'wevAct':
        return EventNpcActAction(j.str('u'), j.integer('i'));

      case 'tev':
        return ScheduleTownEventAction(j.str('u'));
      case 'tourney':
        return ProposeTourneyAction(j.str('u'));
      case 'tut':
        return StartTutorialAction(companions: j['cmp'] != false);
      case 'tutOk':
        return const TutorialAckAction();
      case 'tutCtl':
        return TutorialControlAction(
            j.enumByName('op', TutorialControl.values));
      case 'tutPick':
        return TutorialChoiceAction(j.str('c'));
      case 'devAbyss':
        return DevAbyssAction(j.str('k'));
      case 'ach':
        return ClaimAchievementAction(j.str('id'));
      case 'runStart':
        return RunStartAction(
          zones: j.intOrNull('z') ?? 0,
          difficulty: j.intOrNull('df') ?? 0,
          eliteWins: {
            for (final e in (j['ew'] == null
                    ? const <String, Object?>{}
                    : asJson(j['ew']))
                .entries)
              e.key: e.value is num
                  ? (e.value as num).toInt()
                  : throw FormatException('JSON inválido', e.value),
          },
        );
      case 'runPrep':
        return RunPrepAction(RunJson.prepFromJson(asJson(j['p'])));
      case 'runVote':
        return RunVoteAction(j.integer('n'));
      case 'runReward':
        return RunRewardAction(
            tree: j.intOrNull('tr'),
            weapon: j.intOrNull('w'),
            extra: j.intOrNull('x'),
            ult: j.intOrNull('u'),
            drop: j['d'] as String?);
      case 'runReady':
        return const RunReadyAction();
      case 'runBuyUlt':
        return RunBuyUltAction(j.str('u'));
      case 'runSkill':
        return RunSkillAction(j.str('s'), equip: j['on'] == true);
      case 'runSkillUp':
        return RunUpgradeSkillAction(j.str('s'));
      case 'fBite':
        return FishBiteAction(j.dbl('pw'));
      case 'fRes':
        return FishResultAction(j.boolean('ok'));
      case 'fAuto':
        final r = (j.intOrNull('r') ?? 0)
            .clamp(0, AutoFishStop.values.length - 1);
        return FishAutoAction(j['on'] == true, AutoFishStop.values[r]);
      case 'fLn':
        return FishLineAction(FishLine.fromJson(j['l']));

      case 'wisp':
        return WispAction(j['on'] == true);
      case 'raft':
        return RaftAction(j['on'] == true);
      case 'fSell':
        return SellFishAction(
            species: j.strOrNull('sp'), materials: j['mat'] == true);
      case 'fSwap':
        return ExchangeFishAction(j.str('sp'));
      case 'rodBuy':
        return BuyRodAction(j.str('r'));
      case 'rodEq':
        return EquipRodAction(j.str('r'));
      case 'farm':
        return FarmTileAction(j.enumByName('o', FarmOp.values),
            j.integer('x'), j.integer('y'),
            seed: j.strOrNull('sd'));
      case 'stall':
        return StallAction(j.enumByName('o', StallOp.values), j.str('c'),
            qty: j.intOrNull('n') ?? 0,
            price: j.intOrNull('p') ?? 0,
            owner: j.strOrNull('ow'));
      case 'giveLife':
        return GiveLifeAction(j.str('to'), j.str('c'),
            count: j.intOrNull('n') ?? 1);
      case 'farmShop':
        return FarmShopAction(j.enumByName('o', FarmShopOp.values),
            id: j.strOrNull('id'),
            n: j.intOrNull('n') ?? 1,
            materials: j['mat'] == true,
            to: j.strOrNull('to'));
      case 'town':
        return TownAction(j.enumByName('o', TownOp.values),
            id: j.strOrNull('id'),
            target: j.strOrNull('tg'),
            x: j.intOrNull('x'),
            y: j.intOrNull('y'),
            n: j.intOrNull('n') ?? 1);
      case 'lifeTree':
        return LifeTreeAction(j.str('k'), j.strOrNull('n'));
      case 'travel':
        return TravelAction(j.str('p'),
            ecoZone: j['ez'] is num ? (j['ez'] as num).toInt() : null);
      case 'forage':
        return ForageAction(j.integer('i'));
      case 'cozy':
        final op = j.integer('op');
        if (op < 0 || op >= CozyOp.values.length) {
          throw FormatException('JSON inválido: cozy', op);
        }
        return CozyAction(CozyOp.values[op],
            id: j.strOrNull('id'), x: j.intOrNull('x'), y: j.intOrNull('y'));
      case 'way':
        return WaystoneAction(j.integer('i'), to: j.intOrNull('to'));
      case 'wx':
        return WildLootAction(j.integer('i'),
            shrine: (j.intOrNull('s') ?? 0) != 0);
      case 'mine':
        final op = MineOp.values.asNameMap()[j.str('o')] ??
            (throw FormatException('JSON inválido: mine', j['o']));
        return MineAction(op,
            x: j.intOrNull('x') ?? 0,
            y: j.intOrNull('y') ?? 0,
            id: j.strOrNull('i'),
            mat: j.strOrNull('g'),
            n: j.intOrNull('n') ?? 1);
      case 'smith':
        final op = SmithOp.values.asNameMap()[j.str('o')] ??
            (throw FormatException('JSON inválido: smith', j['o']));
        return SmithAction(op, j.str('g'),
            base: j.strOrNull('b'),
            rarity: j.intOrNull('r') ?? 0,
            n: j.intOrNull('n') ?? 1);
      case 'leaveD':
        return LeaveDungeonAction(poiId: j.intOrNull('i'));
      case 'offer':
        return const OfferBossAction();
      case 'joinP':
        return JoinPlayerAction(j.str('p'));
    }
    throw FormatException('JSON inválido: acción desconocida', t);
  }

  /// Las claves de `battleCmd` (`a`, `tg`, `tk`, `pt`, `du`, `it`, `to`).
  static Json commandToJson(BattleCommand c) => switch (c) {
        AttackCommand() => {
            'a': 'atk',
            if (c.targetId != null) 'tg': c.targetId
          },
        SkillCommand() => {
            'a': 'tech',
            'tk': c.skillId,
            if (c.targetId != null) 'tg': c.targetId,
          },
        UltimateCommand() => {
            'a': 'ult',
            if (c.targetId != null) 'tg': c.targetId
          },
        // `du` (v0.8.3, aditivo, sin subir kProtocolVersion): qué dúo. Un
        // host viejo lo ignora y hace el dúo de clase del par.
        DualCommand() => {
            'a': 'dual',
            'pt': c.partnerId,
            if (c.dualId != null) 'du': c.dualId,
          },
        ItemCommand() => {
            'a': 'item',
            'it': itemKey(c.item),
            if (c.targetPlayerId != null) 'to': c.targetPlayerId,
          },
        DefendCommand() => {'a': 'def'},
        // Pasar turno (v0.8.3): variante de `def` (aditivo, sin subir
        // kProtocolVersion; un host viejo lo toma como Defender).
        PassCommand() => {'a': 'def', 'ps': true},
        // Modos de turno (turn_modes.md, protocolo 39).
        WaitCommand() => {'a': 'wait'},
        EndTurnCommand() => {'a': 'end'},
      };

  static BattleCommand commandFromJson(Json j) {
    final a = j.str('a');
    return switch (a) {
      'atk' => AttackCommand(targetId: j.strOrNull('tg')),
      'tech' => SkillCommand(j.str('tk'), targetId: j.strOrNull('tg')),
      'ult' => UltimateCommand(targetId: j.strOrNull('tg')),
      'dual' => DualCommand(j.str('pt'), dualId: j.strOrNull('du')),
      'item' => ItemCommand(itemFromKey(j.str('it')),
          targetPlayerId: j.strOrNull('to')),
      'def' => j.flag('ps') ? const PassCommand() : const DefendCommand(),
      'wait' => const WaitCommand(),
      'end' => const EndTurnCommand(),
      _ => throw FormatException('JSON inválido: comando de batalla', a),
    };
  }
}
