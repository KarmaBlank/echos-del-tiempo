import '../../../game_engine/data/run_boons.dart';
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

/// Pantallas de la Travesía (docs/specs/roguelike.md), sobre la sesión:
/// sala previa, mapa con votación, recompensa, tienda / armería /
/// descanso y fin. Solo arma la vista; todo lo decide el host.
class RunScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final r = s.run;
    final Widget body;
    if (s.mode == SessionMode.lobby || r == null) {
      body = _lobby();
    } else {
      body = switch (r.phase) {
        RunPhase.map || RunPhase.battle => _map(r),
        RunPhase.reward => _reward(r),
        RunPhase.stop => _stop(r),
        RunPhase.over => _over(r),
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

  Widget _party() => Wrap(
        spacing: DsSpace.md,
        runSpacing: DsSpace.xs,
        children: [
          for (final p in s.playerList)
            Text(
              '${p.name} · Vida ${p.hp.ceil()}/${p.maxHp} · '
              'Maná ${p.mp.ceil()}/${p.maxMp} · Oro ${p.profile.credits}',
              style: DsText.body(p.id == view.localId
                  ? DsColors.selected
                  : DsColors.text),
            ),
        ],
      );

  /// PERSONAJE [C] e INVENTARIO [I] (las mismas teclas que en el Mundo).
  Widget _character() => Wrap(spacing: DsSpace.sm, children: [
        DsButton('PERSONAJE [C]',
            key: const ValueKey('run-open-character'),
            tooltip: 'Atributos, arma, ULT, mejoras y objetos de la run',
            onPressed: () => controller.openPanel(WorldPanel.character)),
        DsButton('INVENTARIO [I]',
            key: const ValueKey('run-open-inventory'),
            tooltip: 'Equipar armas, usar pociones y ordenar el bolso',
            onPressed: () => controller.openPanel(WorldPanel.inventory)),
      ]);

  Widget _lobby() => Center(
        child: PanelFrame(
          title: 'TRAVESÍA',
          width: 760,
          actions: [
            DsButton('VOLVER AL TÍTULO', onPressed: onExit),
            _character(),
            if (controller.hasRunSave) ...[
              DsButton('ABANDONAR',
                  key: const ValueKey('run-abandon'),
                  onPressed: controller.abandonRun),
              DsButton('CONTINUAR TRAVESÍA',
                  key: const ValueKey('run-continue'),
                  kind: DsButtonKind.primary,
                  onPressed: controller.continueRun),
            ] else
              DsButton('EMPEZAR TRAVESÍA',
                  key: const ValueKey('run-start'),
                  kind: DsButtonKind.primary,
                  onPressed: controller.startRun),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Tres pisos, un camino ramificado y un guardián al final '
                  'de cada uno. Cada uno arranca con un personaje nuevo de '
                  'su clase: lo que se gana en la run se pierde al terminar. '
                  'En PERSONAJE podés equipar tu arma y elegir tu ULT antes '
                  'de salir.',
                  style: DsText.body()),
              if (controller.hasRunSave) ...[
                SizedBox(height: DsSpace.sm),
                Text(
                    'Hay una Travesía a medias. Podés seguirla donde la '
                    'dejaste o abandonarla para empezar otra.',
                    style: DsText.subtitle()),
              ],
              SizedBox(height: DsSpace.md),
              if (view.roomCode case final code?)
                Text('Código de sala: $code', style: DsText.subtitle()),
              SizedBox(height: DsSpace.sm),
              for (final p in s.playerList)
                Text(
                    '${p.name} · '
                    '${controller.engine.catalog.classes[p.profile.classId]?.name ?? p.profile.classId}',
                    style: DsText.body()),
              SizedBox(height: DsSpace.md),
              _prep(),
            ],
          ),
        ),
      );

  Widget _prep() => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 380),
        child: SingleChildScrollView(
            child: RunPrepView(controller: controller)),
      );

  Widget _map(RunState r) {
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
            Text('PISO ${r.floor + 1}/${RunTuning.floors} · $zone',
                style: DsText.title()),
            const Spacer(),
            _character(),
          ],
        ),
        SizedBox(height: DsSpace.xs),
        _party(),
        SizedBox(height: DsSpace.xs),
        Text(
            r.phase == RunPhase.map
                ? 'Marcá el próximo nodo. Esperando a: '
                    '${missing.isEmpty ? '-' : missing.join(', ')}'
                : 'Entrando...',
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
            for (final t in RunNodeType.values)
              DsTooltip(
                card: runNodeTip(t),
                child: Text('${runNodeLetter(t)} ${t.label}',
                    style: DsText.detail(runNodeColor(t))),
              ),
          ],
        ),
      ],
    );
  }

  Widget _reward(RunState r) {
    final offer = r.offers[view.localId];
    if (offer == null) {
      final missing = [for (final id in r.offers.keys) _name(id)];
      return Center(
        child: Text('Esperando a: ${missing.join(', ')}',
            style: DsText.subtitle()),
      );
    }
    return RunRewardView(
      key: ValueKey('run-reward-${r.wins}'),
      offer: offer,
      controller: controller,
    );
  }

  Widget _stop(RunState r) {
    final type = RunRules.floorOf(r).node(r.node!).type;
    final ready = r.ready.contains(view.localId);
    final missing = [
      for (final id in _humans())
        if (!r.ready.contains(id)) _name(id)
    ];
    final text = switch (type) {
      RunNodeType.tienda =>
        'Armas de tu clase, ULT, pociones y Éter a cambio de oro. Lo que '
            'no uses lo vendés desde la misma tienda.',
      RunNodeType.armeria =>
        'Mejorá tus armas con oro (FORJA: poder, crítico, velocidad) o '
            'pasá una habilidad de un arma a otra (FUSIÓN).',
      _ => 'El grupo descansa y recupera vida y maná.',
    };
    return Center(
      child: PanelFrame(
        title: type.label,
        width: 760,
        actions: [
          _character(),
          if (type == RunNodeType.tienda)
            DsButton('ABRIR TIENDA',
                key: const ValueKey('run-open-shop'),
                onPressed: () => controller.openPanel(WorldPanel.armory)),
          if (type == RunNodeType.armeria)
            DsButton('ABRIR FORJA',
                key: const ValueKey('run-open-armory'),
                onPressed: () => controller.openPanel(WorldPanel.forge)),
          DsButton('LISTO',
              key: const ValueKey('run-ready'),
              kind: DsButtonKind.primary,
              onPressed: ready ? null : controller.runReady),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: DsText.body()),
            if (type == RunNodeType.tienda) ..._ultShop(r),
            if (type == RunNodeType.armeria) ..._skillForge(r),
            SizedBox(height: DsSpace.sm),
            _party(),
            SizedBox(height: DsSpace.sm),
            Text('Esperando a: ${missing.isEmpty ? '-' : missing.join(', ')}',
                style: DsText.detail()),
          ],
        ),
      ),
    );
  }

  /// Mejora de habilidades libres en la armería (§ 12.2): cuánto cuesta y
  /// cuánto poder suma cada nivel.
  List<Widget> _skillForge(RunState r) {
    final me = view.me;
    if (me == null) return const [];
    final c = controller;
    final owned = r.ownedSkills(me.id);
    final pct = (RunTuning.skillUpPower * 100).round();
    return [
      SizedBox(height: DsSpace.md),
      const DsSectionHeader('MEJORAR HABILIDADES'),
      Text(
          'El arma (y lo que trae) se mejora en ABRIR FORJA → MEJORAR. Acá, '
          'cada nivel suma +$pct % de poder a una habilidad libre (hasta '
          '+${RunTuning.skillUpMax}).',
          style: DsText.detail()),
      SizedBox(height: DsSpace.xs),
      if (owned.isEmpty)
        Text('No tenés habilidades libres para mejorar.',
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
                        '${max ? '' : '  →  +${lv + 1} (poder ${100 + pct * lv} % → ${100 + pct * (lv + 1)} %)'}',
                        style: DsText.body()),
                  ),
                ),
                DsButton(max ? 'MÁXIMO' : '$cost DE ORO',
                    key: ValueKey('run-skill-up-$id'),
                    size: DsButtonSize.compact,
                    tooltip: max
                        ? null
                        : poor
                            ? 'Te falta oro'
                            : 'Mejorar a +${lv + 1}',
                    onPressed:
                        max || poor ? null : () => c.upgradeRunSkill(id)),
              ]);
            }(),
          ),
    ];
  }

  /// ULT a la venta en esta tienda (§ 12.2): caras y valiosas.
  List<Widget> _ultShop(RunState r) {
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
      const DsSectionHeader('ULT A LA VENTA'),
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
                      '${sk.name}  ·  Con ${UltRules.weaponsOf(id).join(', ')}',
                      style: DsText.body()),
                ),
              ),
              DsButton(
                  me.profile.ultKnown.contains(id) ? 'TENÉS' : '$price DE ORO',
                  key: ValueKey('run-buy-ult-$id'),
                  size: DsButtonSize.compact,
                  tooltip: me.profile.ultKnown.contains(id)
                      ? null
                      : gold < price
                          ? 'Te falta oro'
                          : 'Queda aprendida y activa',
                  onPressed: me.profile.ultKnown.contains(id) || gold < price
                      ? null
                      : () => c.buyRunUlt(id)),
            ]),
          ),
    ];
  }

  Widget _over(RunState r) => Center(
        child: PanelFrame(
          title: r.victory == true
              ? 'TRAVESÍA COMPLETADA'
              : 'FIN DE LA TRAVESÍA',
          width: 760,
          actions: [
            DsButton('VOLVER AL TÍTULO',
                key: const ValueKey('run-exit'), onPressed: onExit),
            DsButton('NUEVA TRAVESÍA',
                kind: DsButtonKind.primary, onPressed: controller.startRun),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  'Piso alcanzado: ${r.floor + 1}/${RunTuning.floors} · '
                  'Peleas ganadas: ${r.wins} · '
                  'Ecos ganados: ${MetaProgressRules.coinsOf(r)}',
                  style: DsText.body()),
              SizedBox(height: DsSpace.md),
              _prep(),
            ],
          ),
        ),
      );
}

/// Recompensa de un jugador (organismo): filas Objetos / Arma / (ULT) /
/// Extra, una opción por fila o SALTAR, y CONFIRMAR. Cada tarjeta tiene
/// su tooltip con el detalle.
class RunRewardView extends StatefulWidget {
  const RunRewardView(
      {super.key, required this.offer, required this.controller});

  final RunOffer offer;
  final SessionController controller;

  @override
  State<RunRewardView> createState() => _RunRewardViewState();
}

class _RunRewardViewState extends State<RunRewardView> {
  int? _tree, _weapon, _extra, _ult;

  static String attrName(Attribute a) => runAttributeName(a);

  /// Pide sacrificar una habilidad libre (la nueva no entra).
  bool _askDrop = false;

  String _skillName(String? id) =>
      widget.controller.engine.catalog.skills[id]?.name ?? id ?? '?';

  String extraText(RunExtra x) => switch (x.kind) {
        RunExtraKind.habilidad => 'Habilidad: ${_skillName(x.skill)}',
        _ => extraTextOf(x),
      };

  static String extraTextOf(RunExtra x) => switch (x.kind) {
        RunExtraKind.habilidad => 'Habilidad nueva',
        RunExtraKind.oro => '+${x.amount} de oro',
        RunExtraKind.pocion => '+${x.amount} pociones',
        RunExtraKind.eter => '+${x.amount} Éter',
        RunExtraKind.atributo =>
          '+${x.amount} ${attrName(x.attribute ?? Attribute.vit)}',
        RunExtraKind.mejora => RunBoon.byName(x.boon)?.text ?? 'Mejora',
      };

  /// Qué hace cada extra (tooltip).
  static String extraHelp(RunExtra x) => switch (x.kind) {
        RunExtraKind.habilidad =>
          'Habilidad libre: se equipa aparte de las del arma. Si no hay '
              'lugar, tenés que sacrificar una.',
        RunExtraKind.oro => 'Para la tienda y la forja de la armería.',
        RunExtraKind.pocion => 'Cada poción cura vida en combate o fuera.',
        RunExtraKind.eter => 'Cada Éter recupera maná en combate.',
        RunExtraKind.atributo =>
          'Sube ${attrName(x.attribute ?? Attribute.vit)} para el resto de '
              'la run. ${runAttributeHelp(x.attribute ?? Attribute.vit)}',
        RunExtraKind.mejora =>
          'Mejora directa: dura toda la run y se apila si la repetís. '
              'Se ve en MEJORAS, en PERSONAJE.',
      };

  Widget _row(String label, int count, int? picked, ValueChanged<int?> onPick,
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
                        key: ValueKey('run-offer-$label-$i'),
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
                    child: Text('Nada para ofrecer.', style: DsText.detail())),
              DsButton('SALTAR',
                  tooltip: 'No tomar nada de esta fila',
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
            const DsSectionHeader('TENÉS QUE SACRIFICAR UNA HABILIDAD'),
            Text(
                'No hay lugar para '
                '${_skillName(widget.offer.extras[_extra!].skill)}. Elegí '
                'cuál dejar (las del arma no se tocan).',
                style: DsText.detail()),
            SizedBox(height: DsSpace.sm),
            Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: [
              for (final id in _equipped)
                if (widget.controller.engine.catalog.skills[id]
                    case final sk?)
                  RetroTooltip(
                    message: describeSkillMarkup(sk, null),
                    child: DsButton('SACRIFICAR ${sk.name}',
                        key: ValueKey('run-drop-$id'),
                        size: DsButtonSize.compact,
                        onPressed: () => _confirm(drop: id)),
                  ),
              DsButton('CANCELAR',
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
        Text('ELEGÍ TU RECOMPENSA', style: DsText.title()),
        SizedBox(height: DsSpace.md),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('OBJETOS', o.nodes.length, _tree,
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
                    help: 'Objetos de la run: un efecto pasivo que dura '
                        'hasta el final de la Travesía.',
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
                            Text('Se suma a OBJETOS DE LA RUN en PERSONAJE.',
                                style: DsText.detail()),
                          ],
                        ),
                        child: child,
                      );
                    }),
                _row('ARMA', o.weapons.length, _weapon,
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
                    help: 'Va al bolso; se equipa sin nivel ni atributos '
                        'mínimos.',
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
                  _row('ULT', o.ults.length, _ult,
                      (i) => setState(() => _ult = i), (i) {
                    final sk = kWeaponUltSkills[o.ults[i]];
                    final types = UltRules.weaponsOf(o.ults[i]);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sk?.name ?? o.ults[i], style: DsText.subtitle()),
                        if (types.isNotEmpty)
                          Text('Con ${types.join(', ')}',
                              style: DsText.detail()),
                      ],
                    );
                  },
                      help: 'Rara y valiosa: queda aprendida y activa; se '
                          'cambia en PERSONAJE.',
                      tip: (i, child) {
                        final sk = kWeaponUltSkills[o.ults[i]];
                        if (sk == null) return child;
                        return RetroTooltip(
                            message:
                                describeSkillMarkup(sk, null, ultimate: true),
                            child: child);
                      }),
                _row('EXTRA', o.extras.length, _extra,
                    (i) => setState(() => _extra = i),
                    (i) => Text(extraText(o.extras[i]),
                        style: DsText.subtitle()),
                    help: 'Oro, consumibles, atributos, una mejora directa o '
                        'una habilidad.',
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
            child: DsButton('CONFIRMAR',
                key: const ValueKey('run-reward-confirm'),
                kind: DsButtonKind.primary,
                onPressed: _confirm),
          ),
      ],
    );
  }
}
