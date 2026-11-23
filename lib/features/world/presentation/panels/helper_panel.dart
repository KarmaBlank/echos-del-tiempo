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

  /// Semilla elegida y de qué lado (true = la del granjero).
  String? _sel;
  bool _right = false;
  int _qty = 1;

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

    final left = [
      for (final e in mine.entries)
        if (e.value > 0 && pass(e.key)) e
    ]..sort((a, b) => a.key.compareTo(b.key));
    final right = [
      for (final e in b.seeds.entries)
        if (e.value > 0 && pass(e.key)) e
    ]..sort((a, b) => a.key.compareTo(b.key));
    final sel = _sel == null ? null : kCrops[_sel!];
    final have = _sel == null ? 0 : (_right ? b.seeds[_sel] : mine[_sel]) ?? 0;
    int n() => _qty <= 0 ? 0 : _qty;
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
          height: 260,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
                child: _grid('TUS SEMILLAS', 'helper-mine', left, false,
                    'No tenés semillas que coincidan.')),
            SizedBox(width: DsSpace.sm),
            Expanded(
                child: _grid('SEMILLAS DE LA HUERTA', 'helper-theirs', right,
                    true, 'Sin semillas: el granjero solo riega y cosecha.')),
          ]),
        ),
        SizedBox(height: DsSpace.sm),
        DsCard(
          key: const ValueKey('helper-detail'),
          child: Row(children: [
            if (sel != null) ...[
              LifeIcon('semilla_${sel.id}', LifeIconKind.semilla, size: 32),
              SizedBox(width: DsSpace.sm),
            ],
            Expanded(
              child: sel == null
                  ? Text('Elegí una semilla de una de las grillas.',
                      style: DsText.detail())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Text(sel.seedName,
                              style: DsText.body(fishRarityColor(sel.rarity))),
                          Text(
                              '${sel.rarity.label} · tenés ${mine[sel.id] ?? 0} · '
                              'la huerta tiene ${b.seeds[sel.id] ?? 0}',
                              style: DsText.detail()),
                        ]),
            ),
            for (final (label, v) in const [('1', 1), ('10', 10), ('TODO', 0)])
              Padding(
                padding: EdgeInsets.only(left: DsSpace.xs),
                child: DsButton(label,
                    key: ValueKey('helper-qty-$label'),
                    size: DsButtonSize.compact,
                    selected: _qty == v,
                    onPressed: () => setState(() => _qty = v)),
              ),
            SizedBox(width: DsSpace.sm),
            DsButton('PASAR →',
                key: const ValueKey('helper-give'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                onPressed: sel != null && !_right && have > 0
                    ? () => c.giveSeeds(b.id, sel.id, n())
                    : null),
            SizedBox(width: DsSpace.xs),
            DsButton('← DEVOLVER',
                key: const ValueKey('helper-take'),
                size: DsButtonSize.compact,
                onPressed: sel != null && _right && have > 0
                    ? () => c.takeSeeds(b.id, sel.id, n())
                    : null),
          ]),
        ),
      ],
    );
  }

  Widget _grid(String title, String key, List<MapEntry<String, int>> items,
      bool right, String empty) {
    final total = items.fold(0, (a, e) => a + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader(title,
            trailing: DsBadge('$total', key: ValueKey('$key-count'))),
        Expanded(
          child: items.isEmpty
              ? Text(empty, style: DsText.detail())
              : SingleChildScrollView(
                  child: Wrap(
                    key: ValueKey(key),
                    spacing: DsSpace.xs,
                    runSpacing: DsSpace.xs,
                    children: [
                      for (final e in items) _cell(e.key, e.value, right),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _cell(String id, int n, bool right) {
    final d = kCrops[id]!;
    final on = _sel == id && _right == right;
    return DsTooltip(
      message: '${d.seedName} · ${d.rarity.label} · ×$n',
      child: DsPressable(
        key: ValueKey('helper-cell-${right ? 'r' : 'l'}-$id'),
        onPressed: () => setState(() {
          _sel = id;
          _right = right;
        }),
        builder: (context, state) => Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: state.hovered ? DsColors.hover : DsColors.surfaceSunken,
            border: Border.all(
                color: on ? DsColors.selected : fishRarityColor(d.rarity),
                width: on ? 2 : 1),
          ),
          child: Stack(children: [
            Center(
                child: LifeIcon('semilla_$id', LifeIconKind.semilla, size: 32)),
            Positioned(
              right: 2,
              bottom: 0,
              child: Text('$n', style: DsText.detail(DsColors.textPrimary)),
            ),
          ]),
        ),
      ),
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
    final items = b.chest.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    String name(String k) => b.kind == BuildKind.lago
        ? (kFish[k]?.name ?? k)
        : switch (parseCropKey(k)) {
            (final crop, final q)? => '${crop.name} (${q.label})',
            null => k,
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsSectionHeader('COFRE',
            trailing: DsBadge('${b.chestTotal}/${TownRules.t.i('chestMax')}',
                key: const ValueKey('helper-chest-count'))),
        if (items.isEmpty)
          Text('Vacío. Lo que junten los ayudantes cae acá.',
              style: DsText.detail())
        else
          Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
            for (final e in items)
              DsTag('${name(e.key)} ×${e.value}',
                  color: DsColors.textSecondary),
          ]),
        SizedBox(height: DsSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: DsButton('RECOGER TODO',
              key: const ValueKey('helper-collect'),
              kind: DsButtonKind.primary,
              onPressed:
                  b.chest.isEmpty ? null : () => c.collectChest(b.id)),
        ),
      ],
    );
  }
}
