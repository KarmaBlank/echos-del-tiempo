import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';

/// Pantalla de un ayudante (farming.md § 8, v0.25.4; tecla G al lado del
/// NPC). Granjero: SEMILLAS (dos grillas: las tuyas y las de la huerta,
/// con PASAR → / ← DEVOLVER), TAREAS (plantar, regar, cosechar) y COFRE.
/// Pescador: solo COFRE. Todo lo valida el anfitrión.
class HelperPanel extends StatefulWidget {
  const HelperPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<HelperPanel> createState() => _HelperPanelState();
}

class _HelperPanelState extends State<HelperPanel> {
  int _tab = 0;
  String _query = '';
  FishRarity? _rarity;


  SessionController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final hp = c.helperPanel;
    final b = hp == null ? null : c.town.build(hp.$1);
    if (b == null || hp!.$2 >= b.helper) {
      return PanelFrame(
          key: const ValueKey('panel-helper'),
          title: 'AYUDANTE',
          width: 480,
          onClose: c.closePanel,
          child: Text('Este ayudante ya no está.', style: DsText.detail()));
    }
    final farm = b.kind == BuildKind.huerta;
    final i = hp.$2;
    final tabs = farm ? const ['SEMILLAS', 'TAREAS', 'COFRE'] : const ['COFRE'];
    final tab = _tab.clamp(0, tabs.length - 1);
    return PanelFrame(
      key: const ValueKey('panel-helper'),
      title: '${farm ? 'GRANJERO' : 'PESCADOR'} ${i + 1}',
      width: 820,
      onClose: c.closePanel,
      actions: [
        PanelButton('CERRAR',
            key: const ValueKey('helper-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(TownRules.helperLine(b), style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          if (tabs.length > 1)
            DsTabBar(
              tabs: [
                for (final t in tabs)
                  DsTab(t, key: ValueKey('helper-tab-${t.toLowerCase()}')),
              ],
              index: tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
          SizedBox(height: DsSpace.sm),
          switch (tabs[tab]) {
            'SEMILLAS' => _seeds(b),
            'TAREAS' => _tasks(b, i),
            _ => _chest(b),
          },
        ],
      ),
    );
  }

  // ---------------- SEMILLAS ----------------

  LifeItemCellData _seedCell(TownBuild b, String id, int n, bool theirs) {
    final d = kCrops[id]!;
    final mine = widget.view.me?.profile.life.farm.seedCount(id) ?? 0;
    final there = b.seeds[id] ?? 0;
    Widget btn(String label, int q) => DsButton(
        theirs ? '← DEVOLVER $label' : 'PASAR $label →',
        key: ValueKey('helper-${theirs ? 'take' : 'give'}-$label'),
        size: DsButtonSize.compact,
        kind: theirs ? DsButtonKind.secondary : DsButtonKind.primary,
        onPressed: () => theirs
            ? c.takeSeeds(b.id, id, q)
            : c.giveSeeds(b.id, id, q));
    return LifeItemCellData(
      id: 'helper-cell-${theirs ? 'r' : 'l'}-$id',
      icon: LifeIcon('semilla_$id', LifeIconKind.semilla,
          size: LifeItemGrid.iconSize),
      border: fishRarityColor(d.rarity),
      search: d.seedName,
      count: n,
      detail: LifeItemDetail(
        name: d.seedName,
        nameColor: fishRarityColor(d.rarity),
        tags: [
          (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
          (theirs ? 'DE LA HUERTA' : 'TUYA', DsColors.textSecondary),
        ],
        lines: ['Tenés $mine', 'La huerta tiene $there'],
        description: theirs
            ? 'Los granjeros plantan de acá en sus parcelas.'
            : 'Pasala a la huerta: los granjeros la plantan solos.',
        actions: [btn('1', 1), if (n >= 10) btn('10', 10), btn('TODO', 0)],
      ),
    );
  }

  Widget _seeds(TownBuild b) {
    final p = widget.view.me?.profile;
    final mine = p?.life.farm.seeds ?? const <String, int>{};
    final q = _query.toLowerCase();
    bool pass(String id) {
      final d = kCrops[id];
      if (d == null) return false;
      if (_rarity != null && d.rarity != _rarity) return false;
      return q.isEmpty || d.seedName.toLowerCase().contains(q);
    }

    List<LifeItemCellData> cells(Map<String, int> m, bool theirs) => [
          for (final e in (m.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key))))
            if (e.value > 0 && pass(e.key)) _seedCell(b, e.key, e.value, theirs)
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          DsSearchField(
              key: const ValueKey('helper-search'),
              hint: 'BUSCAR SEMILLA',
              onChanged: (v) => setState(() => _query = v)),
          SizedBox(width: DsSpace.sm),
          Expanded(
            child: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              for (final r in [null, ...FishRarity.values])
                DsButton((r?.label ?? 'Todas').toUpperCase(),
                    key: ValueKey('helper-filter-${r?.name ?? 'todas'}'),
                    size: DsButtonSize.compact,
                    selected: _rarity == r,
                    onPressed: () => setState(() => _rarity = r)),
            ]),
          ),
        ]),
        SizedBox(height: DsSpace.sm),
        SizedBox(
          height: 360,
          child: LifeItemGrid(
            key: const ValueKey('helper-seeds'),
            groups: [
              LifeItemGroup('TUS SEMILLAS', cells(mine, false),
                  headerKey: const ValueKey('helper-mine')),
              LifeItemGroup('SEMILLAS DE LA HUERTA', cells(b.seeds, true),
                  headerKey: const ValueKey('helper-theirs')),
            ],
            empty: 'No hay semillas que coincidan. Comprá en el agropecuario '
                'o cosechá para conseguir.',
          ),
        ),
      ],
    );
  }

  // ---------------- TAREAS ----------------

  Widget _tasks(TownBuild b, int i) {
    final mask = b.taskMask(i);
    final next = TownRules.farmerNext(b, i);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
            'Cada vuelta hace una sola tarea: la primera prendida que tenga '
            'algo para hacer en su área, en este orden.',
            style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: [
          for (final t in HelperTask.values)
            DsButton('${t.index + 1}. ${t.label.toUpperCase()}',
                key: ValueKey('helper-task-${t.name}'),
                selected: mask & t.bit != 0,
                onPressed: () =>
                    c.setHelperTasks(b.id, i, mask ^ t.bit)),
        ]),
        SizedBox(height: DsSpace.sm),
        Text(
            'Próximo ciclo: ${next?.label.toLowerCase() ?? 'descansa'} · '
            '${c.helperRoundIn.ceil()} s',
            key: const ValueKey('helper-next'),
            style: DsText.body()),
      ],
    );
  }

  // ---------------- COFRE ----------------

  Widget _chest(TownBuild b) {
    final lake = b.kind == BuildKind.lago;
    final items = b.chest.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final collect = DsButton('RECOGER TODO',
        key: const ValueKey('helper-collect'),
        size: DsButtonSize.compact,
        kind: DsButtonKind.primary,
        onPressed: b.chest.isEmpty ? null : () => c.collectChest(b.id));
    LifeItemCellData cell(String k, int n) {
      if (lake) {
        final f = kFish[k];
        return LifeItemCellData(
          id: 'helper-chest-$k',
          icon: LifeIcon(k, LifeIconKind.pescado, size: LifeItemGrid.iconSize),
          border: f == null ? DsColors.border : fishRarityColor(f.rarity),
          search: f?.name ?? k,
          count: n,
          detail: LifeItemDetail(
              name: f?.name ?? k,
              nameColor: f == null ? DsColors.textPrimary : fishRarityColor(f.rarity),
              lines: ['×$n en el cofre'],
              actions: [collect]),
        );
      }
      final pc = parseCropKey(k);
      final col = pc == null ? DsColors.border : fishRarityColor(pc.$1.rarity);
      return LifeItemCellData(
        id: 'helper-chest-$k',
        icon: LifeIcon('cosecha_${pc?.$1.id ?? k}', LifeIconKind.cosecha,
            size: LifeItemGrid.iconSize),
        border: col,
        search: pc?.$1.name ?? k,
        count: n,
        detail: LifeItemDetail(
            name: pc?.$1.name ?? k,
            nameColor: col,
            tags: [if (pc != null) (pc.$2.label.toUpperCase(), col)],
            lines: ['×$n en el cofre'],
            actions: [collect]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Text('${b.chestTotal}/${TownRules.t.i('chestMax')} en el cofre',
              key: const ValueKey('helper-chest-count'),
              style: DsText.detail()),
          const Spacer(),
          collect,
        ]),
        SizedBox(height: DsSpace.xs),
        SizedBox(
          height: 300,
          child: LifeItemGrid(
            groups: [
              LifeItemGroup(null, [for (final e in items) cell(e.key, e.value)])
            ],
            empty: 'Vacío. Lo que junten los ayudantes cae acá.',
          ),
        ),
      ],
    );
  }
}
