import '../../../game_engine/data/run_boons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/rules/meta_progress_rules.dart';
import '../../../game_engine/rules/run_rules.dart';
import '../../../game_engine/rules/run_tuning.dart';
import '../../passive_tree/domain/passive_text.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import '../../../game_engine/data/branch_ults_catalog.dart'
    show kWeaponUltSkills;
import '../../../game_engine/models/item.dart';
import '../../../game_engine/rules/reward_offer_rules.dart';
import '../../../game_engine/rules/ult_rules.dart';
import '../../combat/domain/skill_text.dart';
import '../../inventory/presentation/item_hover_tip.dart';
import 'run_character_panel.dart';
import 'run_map_view.dart';
import 'run_prep_view.dart';
import '../../../core/i18n/i18n_providers.dart';

/// Pantallas de la Travesía (docs/specs/roguelike.md), sobre la sesión:
/// sala previa, mapa con votación, recompensa, tienda / armería /
/// descanso y fin. Solo arma la vista; todo lo decide el host.
class RunScreen extends ConsumerWidget {
  const RunScreen({
    super.key,
    required this.view,
    required this.controller,
    required this.onExit,
  });

  final SessionView view;
  final SessionController controller;
  final VoidCallback onExit;

  GameSession get s => view.session;

  String _name(String id) => s.players[id]?.name ?? '?';

  List<String> _humans() =>
      [for (final p in s.playerList) if (!p.isCompanion) p.id];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.strings;
    final r = s.run;
    final Widget body;
    if (s.mode == SessionMode.lobby || r == null) {
      body = _lobby(t);
    } else {
      body = switch (r.phase) {
        RunPhase.map || RunPhase.battle => _map(t, r),
        RunPhase.reward => _reward(t, r),
        RunPhase.stop => _stop(t, r),
        RunPhase.over => _over(t, r),
      };
    }
    return ColoredBox(
      color: ProtoColors.bg,
      child: Padding(
        padding: EdgeInsets.all(DsSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: body),
            SizedBox(height: DsSpace.sm),
            _log(),
          ],
        ),
      ),
    );
  }

  Widget _log() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in view.messages.reversed.take(3).toList().reversed)
            Text(m, style: DsText.detail()),
        ],
      );

  Widget _party(Strings t) => Wrap(
        spacing: DsSpace.md,
        runSpacing: DsSpace.xs,
        children: [
          for (final p in s.playerList)
            Text(
              t.t('ui.run.party_line', {
                'name': p.name,
                'hp': p.hp.ceil(),
                'maxHp': p.maxHp,
                'mp': p.mp.ceil(),
                'maxMp': p.maxMp,
                'gold': p.profile.credits,
              }),
              style: DsText.body(p.id == view.localId
                  ? DsColors.selected
                  : DsColors.text),
            ),
        ],
      );

  /// PERSONAJE [TAB] y EQUIPAMIENTO [I] (las mismas teclas que en el Mundo).
  Widget _character(Strings t) => Wrap(spacing: DsSpace.sm, children: [
        DsButton(t.t('ui.run.open_character'),
            key: const ValueKey('run-open-character'),
            tooltip: t.t('ui.run.open_character_tip'),
            onPressed: () => controller.openPanel(WorldPanel.character)),
        DsButton(t.t('ui.run.open_inventory'),
            key: const ValueKey('run-open-inventory'),
            tooltip: t.t('ui.run.open_inventory_tip'),
            onPressed: () => controller.openPanel(WorldPanel.inventory)),
      ]);

  Widget _lobby(Strings t) => Center(
        child: PanelFrame(
          title: t.t('ui.run.lobby.title'),
          width: 760,
          actions: [
            DsButton(t.t('ui.run.back_to_title'), onPressed: onExit),
            _character(t),
            if (controller.hasRunSave) ...[
              DsButton(t.t('ui.run.lobby.abandon'),
                  key: const ValueKey('run-abandon'),
                  onPressed: controller.abandonRun),
              DsButton(t.t('ui.run.lobby.continue'),
                  key: const ValueKey('run-continue'),
                  kind: DsButtonKind.primary,
                  onPressed: controller.continueRun),
            ] else
              DsButton(t.t('ui.run.lobby.start'),
                  key: const ValueKey('run-start'),
                  kind: DsButtonKind.primary,
                  onPressed: controller.startRun),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  t.t('ui.run.lobby.about'),
                  style: DsText.body()),
              if (controller.hasRunSave) ...[
                SizedBox(height: DsSpace.sm),
                Text(
                    t.t('ui.run.lobby.has_save'),
                    style: DsText.subtitle()),
              ],
              SizedBox(height: DsSpace.md),
              if (view.roomCode case final code?)
                Text(t.t('ui.run.lobby.room_code', {'code': code}),
                    style: DsText.subtitle()),
              SizedBox(height: DsSpace.sm),
              for (final p in s.playerList)
                Text(
                    '${p.name} · '
                    '${controller.engine.catalog.classes[p.profile.classId]?.name ?? p.profile.classId}',
                    style: DsText.body()),
              SizedBox(height: DsSpace.md),
              _prep(t),
            ],
          ),
        ),
      );

  Widget _prep(Strings t) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 380),
        child: SingleChildScrollView(
            child: RunPrepView(controller: controller)),
      );

  Widget _map(Strings t, RunState r) {
    final floor = RunRules.floorOf(r);
    final reachable = r.phase == RunPhase.map
        ? RunRules.reachable(r).toSet()
        : const <int>{};
    final votes = <int, List<String>>{};
    for (final e in r.votes.entries) {
      final n = _name(e.key);
      (votes[e.value] ??= []).add(n.isEmpty ? '?' : n.substring(0, 1));
    }
    final missing = [
      for (final id in _humans())
        if (!r.votes.containsKey(id)) _name(id)
    ];
    final zone = controller.engine.catalog.zone(r.zones[r.floor])?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
                t.t('ui.run.map.floor', {
                  'floor': r.floor + 1,
                  'floors': RunTuning.floors,
                  'zone': zone,
                }),
                style: DsText.title()),
            const Spacer(),
            _character(t),
          ],
        ),
        SizedBox(height: DsSpace.xs),
        _party(t),
        SizedBox(height: DsSpace.xs),
        Text(
            r.phase == RunPhase.map
                ? t.t('ui.run.map.pick_next', {
                    'names': missing.isEmpty ? '-' : missing.join(', '),
                  })
                : t.t('ui.run.map.entering'),
            style: DsText.detail()),
        Expanded(
          child: RunMapView(
            floor: floor,
            current: r.node,
            reachable: reachable,
            votes: votes,
            myVote: r.votes[view.localId],
            onVote: controller.voteRunNode,
          ),
        ),
        Wrap(
          spacing: DsSpace.md,
          children: [
            for (final n in RunNodeType.values)
              DsTooltip(
                card: runNodeTip(t, n),
                child: Text('${runNodeLetter(t, n)} ${runNodeLabel(t, n)}',
                    style: DsText.detail(runNodeColor(n))),
              ),
          ],
        ),
      ],
    );
  }

  Widget _reward(Strings t, RunState r) {
    final offer = r.offers[view.localId];
    if (offer == null) {
      final missing = [for (final id in r.offers.keys) _name(id)];
      return Center(
        child: Text(t.t('ui.run.waiting_for', {'names': missing.join(', ')}),
            style: DsText.subtitle()),
      );
    }
    return RunRewardView(
      key: ValueKey('run-reward-${r.wins}'),
      offer: offer,
      controller: controller,
    );
  }

  Widget _stop(Strings t, RunState r) {
    final type = RunRules.floorOf(r).node(r.node!).type;
    final ready = r.ready.contains(view.localId);
    final missing = [
      for (final id in _humans())
        if (!r.ready.contains(id)) _name(id)
    ];
    final text = switch (type) {
      RunNodeType.tienda => t.t('ui.run.stop.shop'),
      RunNodeType.armeria => t.t('ui.run.stop.armory'),
      _ => t.t('ui.run.stop.rest'),
    };
    return Center(
      child: PanelFrame(
        title: runNodeLabel(t, type),
        width: 760,
        actions: [
          _character(t),
          if (type == RunNodeType.tienda)
            DsButton(t.t('ui.run.stop.open_shop'),
                key: const ValueKey('run-open-shop'),
                onPressed: () => controller.openPanel(WorldPanel.armory)),
          if (type == RunNodeType.armeria)
            DsButton(t.t('ui.run.stop.open_forge'),
                key: const ValueKey('run-open-armory'),
                onPressed: () => controller.openPanel(WorldPanel.forge)),
          DsButton(t.t('ui.run.stop.ready'),
              key: const ValueKey('run-ready'),
              kind: DsButtonKind.primary,
              onPressed: ready ? null : controller.runReady),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: DsText.body()),
            if (type == RunNodeType.tienda) ..._ultShop(t, r),
            if (type == RunNodeType.armeria) ..._skillForge(t, r),
            SizedBox(height: DsSpace.sm),
            _party(t),
            SizedBox(height: DsSpace.sm),
            Text(
                t.t('ui.run.waiting_for', {
                  'names': missing.isEmpty ? '-' : missing.join(', '),
                }),
                style: DsText.detail()),
          ],
        ),
      ),
    );
  }

  /// Mejora de habilidades libres en la armería (§ 12.2): cuánto cuesta y
  /// cuánto poder suma cada nivel.
  List<Widget> _skillForge(Strings t, RunState r) {
    final me = view.me;
    if (me == null) return const [];
    final c = controller;
    final owned = r.ownedSkills(me.id);
    final pct = (RunTuning.skillUpPower * 100).round();
    return [
      SizedBox(height: DsSpace.md),
      DsSectionHeader(t.t('ui.run.forge.title')),
      Text(
          t.t('ui.run.forge.hint', {'pct': pct, 'max': RunTuning.skillUpMax}),
          style: DsText.detail()),
      SizedBox(height: DsSpace.xs),
      if (owned.isEmpty)
        Text(t.t('ui.run.forge.none'),
            style: DsText.detail()),
      for (final id in owned)
        if (c.engine.catalog.skills[id] case final sk?)
          Padding(
            padding: EdgeInsets.only(bottom: DsSpace.xs),
            child: () {
              final lv = r.skillLevel(me.id, id);
              final max = lv >= RunTuning.skillUpMax;
              final cost = RunTuning.skillUpCost(lv + 1);
              final poor = me.profile.credits < cost;
              return Row(children: [
                Expanded(
                  child: RetroTooltip(
                    message: describeSkillMarkup(sk, null),
                    child: Text(
                        '${sk.name}  +$lv'
                        '${max ? '' : t.t('ui.run.forge.next', {'next': lv + 1, 'from': 100 + pct * lv, 'to': 100 + pct * (lv + 1)})}',
                        style: DsText.body()),
                  ),
                ),
                DsButton(
                    max
                        ? t.t('ui.run.forge.max')
                        : t.t('ui.run.gold_price', {'n': cost}),
                    key: ValueKey('run-skill-up-$id'),
                    size: DsButtonSize.compact,
                    tooltip: max
                        ? null
                        : poor
                            ? t.t('ui.run.not_enough_gold')
                            : t.t('ui.run.forge.upgrade_to', {'n': lv + 1}),
                    onPressed:
                        max || poor ? null : () => c.upgradeRunSkill(id)),
              ]);
            }(),
          ),
    ];
  }

  /// ULT a la venta en esta tienda (§ 12.2): caras y valiosas.
  List<Widget> _ultShop(Strings t, RunState r) {
    final me = view.me;
    if (me == null || r.node == null) return const [];
    final c = controller;
    final stock = RewardOfferRules(
            tree: c.engine.progression.treeRules.catalog,
            catalog: c.engine.catalog)
        .shopUlts(me.profile, seed: r.seed, floor: r.floor, node: r.node!);
    if (stock.isEmpty) return const [];
    final price = RunTuning.ultPrice;
    final gold = me.profile.credits;
    return [
      SizedBox(height: DsSpace.md),
      DsSectionHeader(t.t('ui.run.ult_shop.title')),
      SizedBox(height: DsSpace.xs),
      for (final id in stock)
        if (kWeaponUltSkills[id] case final sk?)
          Padding(
            padding: EdgeInsets.only(bottom: DsSpace.xs),
            child: Row(children: [
              Expanded(
                child: RetroTooltip(
                  message: describeSkillMarkup(sk, null, ultimate: true),
                  child: Text(
                      t.t('ui.run.ult_shop.row', {
                        'name': sk.name,
                        'weapons': UltRules.weaponsOf(id).join(', '),
                      }),
                      style: DsText.body()),
                ),
              ),
              DsButton(
                  me.profile.ultKnown.contains(id)
                      ? t.t('ui.run.ult_shop.owned')
                      : t.t('ui.run.gold_price', {'n': price}),
                  key: ValueKey('run-buy-ult-$id'),
                  size: DsButtonSize.compact,
                  tooltip: me.profile.ultKnown.contains(id)
                      ? null
                      : gold < price
                          ? t.t('ui.run.not_enough_gold')
                          : t.t('ui.run.ult_shop.learned'),
                  onPressed: me.profile.ultKnown.contains(id) || gold < price
                      ? null
                      : () => c.buyRunUlt(id)),
            ]),
          ),
    ];
  }

  Widget _over(Strings t, RunState r) => Center(
        child: PanelFrame(
          title: r.victory == true
              ? t.t('ui.run.over.victory')
              : t.t('ui.run.over.defeat'),
          width: 760,
          actions: [
            DsButton(t.t('ui.run.back_to_title'),
                key: const ValueKey('run-exit'), onPressed: onExit),
            DsButton(t.t('ui.run.over.new_run'),
                kind: DsButtonKind.primary, onPressed: controller.startRun),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  t.t('ui.run.over.summary', {
                    'floor': r.floor + 1,
                    'floors': RunTuning.floors,
                    'wins': r.wins,
                    'coins': MetaProgressRules.coinsOf(r),
                  }),
                  style: DsText.body()),
              SizedBox(height: DsSpace.md),
              _prep(t),
            ],
          ),
        ),
      );
}

/// Recompensa de un jugador (organismo): filas Objetos / Arma / (ULT) /
/// Extra, una opción por fila o SALTAR, y CONFIRMAR. Cada tarjeta tiene
/// su tooltip con el detalle.
class RunRewardView extends ConsumerStatefulWidget {
  const RunRewardView(
      {super.key, required this.offer, required this.controller});

  final RunOffer offer;
  final SessionController controller;

  @override
  ConsumerState<RunRewardView> createState() => _RunRewardViewState();
}

class _RunRewardViewState extends ConsumerState<RunRewardView> {
  int? _tree, _weapon, _extra, _ult;

  String attrName(Attribute a) => runAttributeName(ref.strings, a);

  /// Pide sacrificar una habilidad libre (la nueva no entra).
  bool _askDrop = false;

  String _skillName(String? id) =>
      widget.controller.engine.catalog.skills[id]?.name ?? id ?? '?';

  String extraText(RunExtra x) => switch (x.kind) {
        RunExtraKind.habilidad =>
          ref.t('ui.run.reward.extra.skill', {'name': _skillName(x.skill)}),
        RunExtraKind.oro => ref.t('ui.run.reward.extra.gold', {'n': x.amount}),
        RunExtraKind.pocion =>
          ref.t('ui.run.reward.extra.potions', {'n': x.amount}),
        RunExtraKind.eter => ref.t('ui.run.reward.extra.ether', {'n': x.amount}),
        RunExtraKind.atributo => ref.t('ui.run.reward.extra.attr', {
            'n': x.amount,
            'attr': attrName(x.attribute ?? Attribute.vit),
          }),
        RunExtraKind.mejora =>
          RunBoon.byName(x.boon)?.text ?? ref.t('ui.run.boon_short'),
      };

  /// Qué hace cada extra (tooltip).
  String extraHelp(RunExtra x) => switch (x.kind) {
        RunExtraKind.atributo => ref.t('ui.run.reward.help.atributo', {
            'attr': attrName(x.attribute ?? Attribute.vit),
            'help': runAttributeHelp(ref.strings, x.attribute ?? Attribute.vit),
          }),
        _ => ref.t('ui.run.reward.help.${x.kind.name}'),
      };

  Widget _row(String id, String label, int count, int? picked,
      ValueChanged<int?> onPick,
      Widget Function(int i) card,
      {String? help, Widget Function(int i, Widget child)? tip}) {
    return Padding(
      padding: EdgeInsets.only(bottom: DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSectionHeader(label),
          if (help != null) Text(help, style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: DsSpace.sm),
                    child: () {
                      final w = DsCard(
                        key: ValueKey('run-offer-$id-$i'),
                        selected: picked == i,
                        onTap: () => onPick(picked == i ? null : i),
                        child: card(i),
                      );
                      return tip == null ? w : tip(i, w);
                    }(),
                  ),
                ),
              if (count == 0)
                Expanded(
                    child: Text(ref.t('ui.run.reward.nothing'),
                        style: DsText.detail())),
              DsButton(ref.t('ui.run.reward.skip'),
                  tooltip: ref.t('ui.run.reward.skip_tip'),
                  selected: picked == null, onPressed: () => onPick(null)),
            ],
          ),
        ],
      ),
    );
  }

  /// Las habilidades libres equipadas del jugador local.
  List<String> get _equipped {
    final c = widget.controller;
    final v = c.view;
    return v?.session.run?.loadout[v.actorId] ?? const [];
  }

  void _confirm({String? drop}) {
    final x = _extra == null ? null : widget.offer.extras[_extra!];
    if (drop == null &&
        x?.skill != null &&
        _equipped.length >= RunTuning.freeSkillSlots) {
      setState(() => _askDrop = true);
      return;
    }
    widget.controller.chooseRunReward(
        tree: _tree, weapon: _weapon, extra: _extra, ult: _ult, drop: drop);
  }

  /// «Tenés que sacrificar una habilidad» (§ 12.2): solo las libres.
  Widget _dropPrompt() => DsCard(
        key: const ValueKey('run-drop-prompt'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsSectionHeader(ref.t('ui.run.reward.drop.title')),
            Text(
                ref.t('ui.run.reward.drop.text', {
                  'name': _skillName(widget.offer.extras[_extra!].skill),
                }),
                style: DsText.detail()),
            SizedBox(height: DsSpace.sm),
            Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: [
              for (final id in _equipped)
                if (widget.controller.engine.catalog.skills[id]
                    case final sk?)
                  RetroTooltip(
                    message: describeSkillMarkup(sk, null),
                    child: DsButton(
                        ref.t('ui.run.reward.drop.button', {'name': sk.name}),
                        key: ValueKey('run-drop-$id'),
                        size: DsButtonSize.compact,
                        onPressed: () => _confirm(drop: id)),
                  ),
              DsButton(ref.t('ui.run.reward.drop.cancel'),
                  key: const ValueKey('run-drop-cancel'),
                  onPressed: () => setState(() => _askDrop = false)),
            ]),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final c = widget.controller;
    final tree = c.engine.progression.treeRules.catalog;
    final weapons = c.engine.catalog.weapons;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ref.t('ui.run.reward.title'), style: DsText.title()),
        SizedBox(height: DsSpace.md),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('items', ref.t('ui.run.reward.row.items'), o.nodes.length, _tree,
                    (i) => setState(() => _tree = i), (i) {
                  final n = tree.nodes[o.nodes[i]];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n?.name ?? o.nodes[i], style: DsText.subtitle()),
                      if (n != null)
                        for (final l in passiveEffectsClean(n))
                          Text(l, style: DsText.body()),
                    ],
                  );
                },
                    help: ref.t('ui.run.reward.row.items_help'),
                    tip: (i, child) {
                      final n = tree.nodes[o.nodes[i]];
                      if (n == null) return child;
                      return DsTooltip(
                        card: DsTooltipCard(
                          title: n.name,
                          tags: [
                            if (tree.paths[n.pathId]?.name case final path?)
                              DsTag(path, color: DsColors.textSecondary),
                          ],
                          children: [
                            for (final l in passiveEffectsClean(n)) Text(l),
                            Text(ref.t('ui.run.reward.row.items_tip'),
                                style: DsText.detail()),
                          ],
                        ),
                        child: child,
                      );
                    }),
                _row('weapon', ref.t('ui.run.reward.row.weapon'), o.weapons.length,
                    _weapon,
                    (i) => setState(() => _weapon = i), (i) {
                  final w = weapons[o.weapons[i]];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w?.name ?? o.weapons[i], style: DsText.subtitle()),
                      if (w != null) Text(w.type, style: DsText.detail()),
                    ],
                  );
                },
                    help: ref.t('ui.run.reward.row.weapon_help'),
                    tip: (i, child) {
                      final w = weapons[o.weapons[i]];
                      final me = c.view?.actor;
                      if (w == null || me == null) return child;
                      return itemHoverTip(
                        rules: c.engine.progression,
                        viewer: me.profile,
                        item: ItemInstance.common('run-offer-$i', w.id,
                            itemLevel: w.level),
                        attributes: me.profile.attributes,
                        child: child,
                      );
                    }),
                if (o.ults.isNotEmpty)
                  _row('ult', ref.t('ui.run.reward.row.ult'), o.ults.length, _ult,
                      (i) => setState(() => _ult = i), (i) {
                    final sk = kWeaponUltSkills[o.ults[i]];
                    final types = UltRules.weaponsOf(o.ults[i]);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sk?.name ?? o.ults[i], style: DsText.subtitle()),
                        if (types.isNotEmpty)
                          Text(ref.t('ui.run.reward.with', {'weapons': types.join(', ')}),
                              style: DsText.detail()),
                      ],
                    );
                  },
                      help: ref.t('ui.run.reward.row.ult_help'),
                      tip: (i, child) {
                        final sk = kWeaponUltSkills[o.ults[i]];
                        if (sk == null) return child;
                        return RetroTooltip(
                            message:
                                describeSkillMarkup(sk, null, ultimate: true),
                            child: child);
                      }),
                _row('extra', ref.t('ui.run.reward.row.extra'), o.extras.length,
                    _extra,
                    (i) => setState(() => _extra = i),
                    (i) => Text(extraText(o.extras[i]),
                        style: DsText.subtitle()),
                    help: ref.t('ui.run.reward.row.extra_help'),
                    tip: (i, child) {
                      final x = o.extras[i];
                      final sk = c.engine.catalog.skills[x.skill];
                      if (sk != null) {
                        return RetroTooltip(
                            message: '${describeSkillMarkup(sk, null)}<br>'
                                '<span class="k">${extraHelp(x)}</span>',
                            child: child);
                      }
                      return DsTooltip(
                        card: DsTooltipCard(
                          title: extraText(x),
                          children: [Text(extraHelp(x))],
                        ),
                        child: child,
                      );
                    }),
              ],
            ),
          ),
        ),
        if (_askDrop)
          _dropPrompt()
        else
          Align(
            alignment: Alignment.centerRight,
            child: DsButton(ref.t('ui.run.reward.confirm'),
                key: const ValueKey('run-reward-confirm'),
                kind: DsButtonKind.primary,
                onPressed: _confirm),
          ),
      ],
    );
  }
}
