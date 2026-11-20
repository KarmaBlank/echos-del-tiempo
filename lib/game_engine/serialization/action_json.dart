import '../models/attributes.dart';
import '../models/battle_command.dart';
import '../models/build_wants.dart';
import '../models/eco.dart' show EcoCraftOp;
import '../models/inventory_sort.dart';
import '../models/item.dart' show CraftOp;

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
      };

  static BattleItem itemFromKey(String k) => switch (k) {
        'pot' => BattleItem.potion,
        'eter' => BattleItem.ether,
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
        BuyWeaponAction() => {'t': 'buy', 'w': a.weaponId},
        BattleAction() => {'t': 'cmd', ...commandToJson(a.command)},
        ChatAction() => {'t': 'chat', 'txt': a.text},
        PauseAction() => {'t': 'pause', 'on': a.paused},
        BackToLobbyAction() => {'t': 'back'},
        UseStairsAction() => {'t': 'stairs', 'down': a.down},
        InteractPoiAction() => {'t': 'poi', 'id': a.poiId},
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
        MoveInventoryAction() => {'t': 'invMove', 'a': a.from, 'b': a.to},
        SortInventoryAction() => {'t': 'invSort', 'k': a.key.name},
        SeenItemsAction() => {'t': 'seen', 'u': a.uids},
        SetLootFilterAction() => {'t': 'filter', 'txt': a.text},
        SetBuildWantsAction(:final wants) => {
            't': 'wants',
            if (wants != null && !wants.isEmpty) 'w': wants.toJson(),
          },
        ProposeEcoAction() => {'t': 'eco', 'u': a.uid},
        EcoCraftAction() => {'t': 'ecoCraft', 'u': a.uid, 'op': a.op.name},
        DevGrantEcoAction() => {'t': 'devEco', 'tier': a.tier},
        // Ascensión v0.5 (ascension.md § 6).
        ProposeTrialAction() => {'t': 'trial', 'n': a.trial},
        ChooseAscensionAction() => {'t': 'ascChoose', 'id': a.ascensionId},
        TakeAscensionNodeAction() => {'t': 'ascNode', 'id': a.nodeId},
        ResetAscensionAction() => {'t': 'ascReset', if (a.full) 'full': true},
        DevGrantTrialAction() => {'t': 'devTrial', 'n': a.trial},
        // Jefes del Abismo v0.8 (abyss_bosses.md § 5).
        ProposeAbyssAction() => {'t': 'abyss', 'n': a.boss},
        // TUTORIAL v0.9 (combat_tutorial.md § 6).
        StartTutorialAction() => {'t': 'tut', 'cmp': a.companions},
        TutorialAckAction() => {'t': 'tutOk'},
        TutorialControlAction() => {'t': 'tutCtl', 'op': a.op.name},
        // v0.9.6 (combat_tutorial.md § 4.4).
        TutorialChoiceAction() => {'t': 'tutPick', 'c': a.choice},
        DevAbyssAction() => {'t': 'devAbyss', 'k': a.kind},
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
      case 'buy':
        return BuyWeaponAction(j.str('w'));
      case 'cmd':
        return BattleAction(commandFromJson(j));
      case 'chat':
        return ChatAction(j.str('txt'));
      case 'pause':
        return PauseAction(j.boolean('on'));
      case 'back':
        return const BackToLobbyAction();
      case 'stairs':
        return UseStairsAction(down: j.boolean('down'));
      case 'poi':
        return InteractPoiAction(j.integer('id'));
      case 'craft':
        return CraftAction(j.enumByName('op', CraftOp.values), j.str('w'),
            sourceUid: j.strOrNull('src'),
            index: j.intOrNull('i') ?? 0,
            skillId: j.strOrNull('sk'),
            replaceSkillId: j.strOrNull('rep'),
            uids: j['us'] == null ? const [] : List.unmodifiable(j.strings('us')));
      case 'give':
        return GiveItemAction(j.str('to'), j.str('tok'),
            count: j.intOrNull('n') ?? 1);
      case 'drop':
        return DropItemAction(j.str('tok'), count: j.intOrNull('n') ?? 1);
      case 'pick':
        return PickUpAction(j.integer('id'));
      case 'invMove':
        return MoveInventoryAction(j.integer('a'), j.integer('b'));
      case 'seen':
        final u = j['u'];
        return SeenItemsAction(
            u is List ? [for (final e in u) if (e is String) e] : const []);
      case 'invSort':
        return SortInventoryAction(j.enumByName('k', InventorySortKey.values));
      case 'filter':
        return SetLootFilterAction(j.strOrNull('txt'));
      case 'wants':
        final w = BuildWants.fromJson(j['w']);
        return SetBuildWantsAction(w.isEmpty ? null : w);
      case 'eco':
        return ProposeEcoAction(j.str('u'));
      case 'ecoCraft':
        return EcoCraftAction(j.str('u'), j.enumByName('op', EcoCraftOp.values));
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
    }
    throw FormatException('JSON inválido: acción desconocida', t);
  }

  /// Las claves de `battleCmd` (`a`, `tg`, `tk`, `pt`, `du`, `it`, `to`).
  static Json commandToJson(BattleCommand c) => switch (c) {
        AttackCommand() => {'a': 'atk', if (c.targetId != null) 'tg': c.targetId},
        SkillCommand() => {
            'a': 'tech',
            'tk': c.skillId,
            if (c.targetId != null) 'tg': c.targetId,
          },
        UltimateCommand() => {'a': 'ult', if (c.targetId != null) 'tg': c.targetId},
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
      _ => throw FormatException('JSON inválido: comando de batalla', a),
    };
  }
}
