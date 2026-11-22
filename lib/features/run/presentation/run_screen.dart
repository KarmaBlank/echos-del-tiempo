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
import '../../../game_engine/rules/ult_rules.dart';
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
              '${p.name} · Nv ${p.profile.level} · '
              'Vida ${p.hp.ceil()}/${p.maxHp} · Oro ${p.profile.credits}',
              style: DsText.body(p.id == view.localId
                  ? DsColors.selected
                  : DsColors.text),
            ),
        ],
      );

  Widget _character() => DsButton('PERSONAJE [C]',
      onPressed: () => controller.openPanel(WorldPanel.character));

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
              Text('${runNodeLetter(t)} ${t.label}',
                  style: DsText.detail(runNodeColor(t))),
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
        'Armas de tu clase, pociones y Éter a cambio de oro. También podés '
            'vender armas desde la armería.',
      RunNodeType.armeria => 'Forjá y fusioná tus armas antes de seguir.',
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
                onPressed: () => controller.openPanel(WorldPanel.armory)),
          if (type == RunNodeType.armeria)
            DsButton('ABRIR ARMERÍA',
                onPressed: () => controller.openPanel(WorldPanel.armory)),
          DsButton('LISTO',
              key: const ValueKey('run-ready'),
              kind: DsButtonKind.primary,
              onPressed: ready ? null : controller.runReady),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: DsText.body()),
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

/// Recompensa de un jugador (organismo): tres filas (Árbol / Arma /
/// Extra), una opción por fila o SALTAR, y CONFIRMAR.
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

  static String extraText(RunExtra x) => switch (x.kind) {
        RunExtraKind.oro => '+${x.amount} de oro',
        RunExtraKind.pocion => '+${x.amount} pociones',
        RunExtraKind.eter => '+${x.amount} Éter',
        RunExtraKind.atributo =>
          '+${x.amount} ${attrName(x.attribute ?? Attribute.vit)}',
        RunExtraKind.mejora => RunBoon.byName(x.boon)?.text ?? 'Mejora',
      };

  Widget _row(String label, int count, int? picked, ValueChanged<int?> onPick,
      Widget Function(int i) card) {
    return Padding(
      padding: EdgeInsets.only(bottom: DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSectionHeader(label),
          SizedBox(height: DsSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: DsSpace.sm),
                    child: DsCard(
                      key: ValueKey('run-offer-$label-$i'),
                      selected: picked == i,
                      onTap: () => onPick(picked == i ? null : i),
                      child: card(i),
                    ),
                  ),
                ),
              if (count == 0)
                Expanded(
                    child: Text('Nada para ofrecer.', style: DsText.detail())),
              DsButton('SALTAR',
                  selected: picked == null, onPressed: () => onPick(null)),
            ],
          ),
        ],
      ),
    );
  }

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
                _row('ÁRBOL', o.nodes.length, _tree,
                    (i) => setState(() => _tree = i), (i) {
                  final n = tree.nodes[o.nodes[i]];
                  final path = tree.paths[n?.pathId]?.name ?? '';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n?.name ?? o.nodes[i], style: DsText.subtitle()),
                      Text(path, style: DsText.detail()),
                      if (n != null)
                        for (final l in passiveEffectsText(n))
                          Text(l, style: DsText.body()),
                    ],
                  );
                }),
                _row('ARMA', o.weapons.length, _weapon,
                    (i) => setState(() => _weapon = i), (i) {
                  final w = weapons[o.weapons[i]];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w?.name ?? o.weapons[i], style: DsText.subtitle()),
                      if (w != null)
                        Text('${w.type} · Nv ${w.level}',
                            style: DsText.detail()),
                    ],
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
                        Text('Queda activa; se cambia en PERSONAJE.',
                            style: DsText.detail()),
                      ],
                    );
                  }),
                _row('EXTRA', o.extras.length, _extra,
                    (i) => setState(() => _extra = i),
                    (i) => Text(extraText(o.extras[i]),
                        style: DsText.subtitle())),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: DsButton('CONFIRMAR',
              key: const ValueKey('run-reward-confirm'),
              kind: DsButtonKind.primary,
              onPressed: () => c.chooseRunReward(
                  tree: _tree, weapon: _weapon, extra: _extra, ult: _ult)),
        ),
      ],
    );
  }
}
