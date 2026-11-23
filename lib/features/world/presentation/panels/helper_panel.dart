import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/helper_rules.dart';
import '../../../../game_engine/rules/life_craft_rules.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';

/// Pantalla de un ayudante (farming.md § 8, v0.25.5; tecla G al lado del
/// NPC). Granjero: SEMILLAS (plantilla TRASPASO: las tuyas a la
/// izquierda, las de la huerta a la derecha), TAREAS (plantar, regar, cosechar) y COFRE.
/// Pescador: MEJORAS y COFRE. MEJORAS (v0.27.0, farming.md § 8.5): grilla
/// de mejoras de este ayudante con su rango, costo y MEJORAR. Todo lo valida el anfitrión.
class HelperPanel extends StatefulWidget {
  const HelperPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<HelperPanel> createState() => _HelperPanelState();
}

class _HelperPanelState extends State<HelperPanel> {
  int _tab = 0;

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
    final tabs = farm
        ? const ['SEMILLAS', 'TAREAS', 'MEJORAS', 'COFRE']
        : const ['MEJORAS', 'COFRE'];
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
          Builder(builder: (_) {
            final st = b.stat(i);
            final (xp, need) = HelperRules.progress(st);
            return Text(
                'Nivel ${HelperRules.level(st)}'
                '${need > 0 ? ' · XP $xp / $need' : ' · nivel máximo'}'
                ' · gana XP trabajando',
                key: const ValueKey('helper-level'),
                style: DsText.body());
          }),
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
            'MEJORAS' => _upgrades(b, i),
            _ => _chest(b),
          },
        ],
      ),
    );
  }

  // ---------------- SEMILLAS ----------------

  static final _rarityFilters = [
    const DsTransferFilter('TODAS', null),
    for (final r in FishRarity.values)
      DsTransferFilter(r.label.toUpperCase(), r.name),
  ];

  DsTransferItem _seedItem(TownBuild b, String id, int n, bool theirs) {
    final d = kCrops[id]!;
    final mine = widget.view.me?.profile.life.farm.seedCount(id) ?? 0;
    final there = b.seeds[id] ?? 0;
    return DsTransferItem(
      id: id,
      icon: LifeIcon('semilla_$id', LifeIconKind.semilla,
          size: LifeItemGrid.iconSize),
      name: d.seedName,
      border: fishRarityColor(d.rarity),
      count: n,
      tag: d.rarity.name,
      info: '${d.rarity.label} · tenés $mine · la huerta tiene $there',
    );
  }

  List<DsTransferItem> _sorted(
          Map<String, int> m, DsTransferItem? Function(String, int) f) =>
      [
        for (final e in (m.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))))
          if (e.value > 0)
            if (f(e.key, e.value) case final x?) x
      ];

  Widget _seeds(TownBuild b) {
    final mine =
        widget.view.me?.profile.life.farm.seeds ?? const <String, int>{};
    return DsTransferTemplate(
      key: const ValueKey('helper-seeds'),
      keyPrefix: 'helper',
      leftTitle: 'TUS SEMILLAS',
      rightTitle: 'SEMILLAS DE LA HUERTA',
      left: _sorted(mine,
          (k, n) => kCrops[k] == null ? null : _seedItem(b, k, n, false)),
      right: _sorted(b.seeds,
          (k, n) => kCrops[k] == null ? null : _seedItem(b, k, n, true)),
      filters: _rarityFilters,
      searchHint: 'BUSCAR SEMILLA',
      leftEmpty: 'No tenés semillas. Comprá en el agropecuario o cosechá.',
      rightEmpty: 'La huerta no tiene semillas: pasale de las tuyas.',
      onMove: (from, id, q) => from == DsTransferSide.left
          ? c.giveSeeds(b.id, id, q)
          : c.takeSeeds(b.id, id, q),
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

  // ---------------- MEJORAS ----------------

  Widget _upgrades(TownBuild b, int i) {
    final p = widget.view.me?.profile;
    final st = b.stat(i);
    final mat = HelperRules.matOf(b.kind);
    LifeItemCellData cell(HelperUpgrade u) {
      final r = st.rank(u);
      final max = r >= HelperRules.maxRank;
      final cost = max ? null : HelperRules.upgradeCost(b.kind, r + 1);
      final why = p == null
          ? 'Sin personaje'
          : HelperRules.cannotUpgrade(p, b, i, u);
      final col = max ? DsColors.textTitle : DsColors.border;
      return LifeItemCellData(
        id: 'helper-up-${u.name}',
        icon: LifeIcon('mejora_${u.name}', LifeIconKind.herramienta,
            size: LifeItemGrid.iconSize),
        border: col,
        search: u.label,
        caption: '$r/${HelperRules.maxRank}',
        detail: LifeItemDetail(
          name: u.label,
          nameColor: DsColors.textTitle,
          tags: [('RANGO $r / ${HelperRules.maxRank}', DsColors.textSecondary)],
          lines: [
            'Cada rango: ${HelperRules.effectText(u)}',
            if (cost != null) 'Cuesta: ${HelperRules.costText(cost)}',
            if (cost != null) 'Pide nivel ${cost.level} del ayudante',
          ],
          actions: [
            DsButton(max ? 'MÁXIMO' : 'MEJORAR',
                key: ValueKey('helper-up-go-${u.name}'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                tooltip: why,
                onPressed: why == null
                    ? () => c.upgradeHelper(b.id, i, u)
                    : null),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
            'Mejoras de este ${b.kind == BuildKind.huerta ? 'granjero' : 'pescador'}. '
            'Cuestan oro, ${kLifeMaterials[mat]!.name.toLowerCase()} y tablas '
            '(se hacen en CONDENSAR); los rangos altos piden más nivel.',
            style: DsText.detail()),
        Text(
            'Tenés: ${p?.life.craft(mat) ?? 0} ${kLifeMaterials[mat]!.name.toLowerCase()}'
            ' · ${p?.life.craft('tabla') ?? 0} tablas · ${p?.credits ?? 0} de oro',
            key: const ValueKey('helper-up-have'),
            style: DsText.body()),
        SizedBox(height: DsSpace.xs),
        SizedBox(
          height: 300,
          child: LifeItemGrid(
            key: const ValueKey('helper-upgrades'),
            groups: [
              LifeItemGroup('MEJORAS', [
                for (final u in HelperRules.upgradesOf(b.kind)) cell(u)
              ]),
            ],
            empty: 'Sin mejoras.',
          ),
        ),
      ],
    );
  }

  // ---------------- COFRE ----------------

  Widget _chest(TownBuild b) {
    final lake = b.kind == BuildKind.lago;
    final p = widget.view.me?.profile;
    DsTransferItem? cell(String k, int n) {
      if (lake) {
        final f = kFish[k];
        return DsTransferItem(
          id: k,
          icon: LifeIcon(k, LifeIconKind.pescado, size: LifeItemGrid.iconSize),
          name: f?.name ?? k,
          border: f == null ? DsColors.border : fishRarityColor(f.rarity),
          count: n,
          tag: f?.rarity.name,
          info: 'en el cofre',
        );
      }
      final pc = parseCropKey(k);
      return DsTransferItem(
        id: k,
        icon: LifeIcon('cosecha_${pc?.$1.id ?? k}', LifeIconKind.cosecha,
            size: LifeItemGrid.iconSize),
        name: pc == null ? k : '${pc.$1.name} (${pc.$2.label.toLowerCase()})',
        border: pc == null ? DsColors.border : fishRarityColor(pc.$1.rarity),
        count: n,
        tag: pc?.$1.rarity.name,
        info: 'en el cofre',
      );
    }

    // Lo tuyo del mismo tipo (solo para ver, el cofre se recoge entero).
    final mine = p == null
        ? const <String, int>{}
        : lake
            ? p.life.bag
            : p.life.farm.crops;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${b.chestTotal}/${TownRules.t.i('chestMax')} en el cofre',
            key: const ValueKey('helper-chest-count'),
            style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        DsTransferTemplate(
          key: const ValueKey('helper-chest'),
          keyPrefix: 'helper-chest',
          leftTitle: lake ? 'TUS PECES' : 'TUS COSECHAS',
          rightTitle: 'COFRE',
          left: _sorted(mine, cell),
          right: _sorted(b.chest, cell),
          filters: _rarityFilters,
          allowLeftToRight: false,
          allowRightToLeft: false,
          leftEmpty: lake ? 'No tenés peces.' : 'Lo que recojas va a tu bolsa.',
          rightEmpty: 'Vacío. Lo que junten los ayudantes cae acá.',
          extraActions: [
            DsButton('← RECOGER TODO',
                key: const ValueKey('helper-collect'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                onPressed:
                    b.chest.isEmpty ? null : () => c.collectChest(b.id)),
          ],
          onMove: (a, b, n) {},
        ),
      ],
    );
  }
}
