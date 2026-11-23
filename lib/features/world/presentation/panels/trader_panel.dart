import '../../../../core/text/text_detail.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'life_icon.dart';
import 'fishing_widgets.dart' show fishRarityColor;

/// Puesto del COMERCIANTE (fishing.md § 5, v0.23.2): primero COMPRAR o
/// VENDER, después PESCA o CULTIVO. Buscador y filtro por tipo siempre a
/// la vista; "Cobrar en" (oro o materiales) solo al VENDER.
class TraderPanel extends StatefulWidget {
  const TraderPanel(
      {super.key,
      required this.view,
      required this.controller,
      this.tab = 0,
      this.mode = 0});

  final SessionView view;
  final SessionController controller;

  /// Pestaña inicial: 0 PESCA, 1 CULTIVO.
  final int tab;

  /// Modo inicial: 0 COMPRAR, 1 VENDER.
  final int mode;

  @override
  State<TraderPanel> createState() => _TraderPanelState();
}

class _TraderPanelState extends State<TraderPanel> {
  bool _materials = false;
  late int _tab = widget.tab;
  late int _mode = widget.mode;
  String _query = '';
  String? _kind;

  /// Categorías de cada vista, en orden (nunca se mezclan).
  List<String> get _kinds => switch ((_mode, _tab)) {
        (0, 0) => const ['cañas'],
        (0, _) => const ['semillas', 'abonos', 'azadas', 'regaderas'],
        (_, 0) => const ['peces', 'basura', 'legendarios'],
        _ => const ['cultivos', 'legendarios'],
      };

  SessionController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final p = widget.view.me?.profile;
    final fishSellAll = p != null &&
        p.life.bag.keys.any((k) => kFish[k]?.rarity != FishRarity.legendario);
    final cropSellAll = p != null &&
        p.life.farm.crops.keys
            .any((k) => parseCropKey(k)?.$1.rarity != FishRarity.legendario);
    return PanelFrame(
      key: const ValueKey('panel-trader'),
      title: 'COMERCIANTE',
      width: 760,
      onClose: c.closePanel,
      actions: [
        if (_mode == 1)
          PanelButton('VENDER TODO',
              key: const ValueKey('trade-sell-all'),
              onPressed: (_tab == 0 ? fishSellAll : cropSellAll)
                  ? () => _tab == 0
                      ? c.sellFish(materials: _materials)
                      : c.sellCrop(null, materials: _materials)
                  : null),
        if (_tab == 0)
          PanelButton('AUTO-PESCA',
              key: const ValueKey('fish-auto'), onPressed: c.autoFish),
        PanelButton('CERRAR',
            key: const ValueKey('trade-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsTabBar(
            tabs: const [
              DsTab('COMPRAR', key: ValueKey('trade-mode-buy')),
              DsTab('VENDER', key: ValueKey('trade-mode-sell')),
            ],
            index: _mode,
            onChanged: (i) => setState(() {
              _mode = i;
              _kind = null;
            }),
          ),
          SizedBox(height: DsSpace.xs),
          DsTabBar(
            tabs: const [
              DsTab('PESCA', key: ValueKey('trade-tab-pesca')),
              DsTab('CULTIVO', key: ValueKey('trade-tab-cultivo')),
            ],
            index: _tab,
            onChanged: (i) => setState(() {
              _tab = i;
              _kind = null;
            }),
          ),
          SizedBox(height: DsSpace.sm),
          Row(children: [
            DsSearchField(
                key: const ValueKey('trade-search'),
                hint: 'BUSCAR',
                onChanged: (v) => setState(() => _query = v)),
            const Spacer(),
            Text('Oro ${p?.credits ?? 0}',
                key: const ValueKey('trade-gold-have'), style: DsText.detail()),
          ]),
          SizedBox(height: DsSpace.xs),
          // Categorías (filtro): nunca se mezclan en la lista.
          Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
            for (final k in [null, ..._kinds])
              DsButton((k ?? 'todo').toUpperCase(),
                  key: ValueKey('trade-filter-${k ?? 'todo'}'),
                  size: DsButtonSize.compact,
                  selected: _kind == k,
                  onPressed: () => setState(() => _kind = k)),
          ]),
          if (_mode == 1) ...[
            SizedBox(height: DsSpace.xs),
            Row(children: [
              Text('COBRAR EN', style: DsText.subtitle()),
              SizedBox(width: DsSpace.sm),
              DsButton('ORO',
                  key: const ValueKey('trade-gold'),
                  size: DsButtonSize.compact,
                  selected: !_materials,
                  onPressed: () => setState(() => _materials = false)),
              SizedBox(width: DsSpace.xs),
              DsButton('MATERIALES',
                  key: const ValueKey('trade-mats'),
                  size: DsButtonSize.compact,
                  selected: _materials,
                  onPressed: () => setState(() => _materials = true)),
            ]),
            Text(
                _materials
                    ? 'Materiales: Esquirlas del Eco (+${((FishingRules.t.d('matRate') - 1) * 100).round()} % del valor; '
                        '1 cada ${FishingRules.t.i('matValue')} de oro).'
                    : 'Vender todo no incluye los legendarios.',
                style: DsText.detail()),
          ],
          SizedBox(height: DsSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 440),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _visible(_tab == 0 ? _fishing() : _farming()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filas del modo actual que pasan el buscador y el filtro de tipo.
  List<Widget> _visible(List<_Row> rows) {
    final q = _query.toLowerCase();
    final out = <Widget>[];
    for (final k in _kinds) {
      if (_kind != null && _kind != k) continue;
      final group = [
        for (final r in rows)
          if (r.sell == (_mode == 1) &&
              r.kind == k &&
              (q.isEmpty || r.name.toLowerCase().contains(q)))
            r.widget
      ];
      if (group.isEmpty) continue;
      if (out.isNotEmpty) out.add(SizedBox(height: DsSpace.sm));
      out
        ..add(DsSectionHeader(k.toUpperCase(),
            key: ValueKey('trade-group-$k'),
            trailing: DsBadge('${group.length}', neutral: true)))
        ..addAll(group);
    }
    if (out.isEmpty) {
      return [
        Text(
            _query.isNotEmpty || _kind != null
                ? 'Nada coincide con la búsqueda.'
                : _mode == 1
                    ? (_tab == 0
                        ? 'No tenés pescados. Probá en la orilla del lago.'
                        : 'No tenés cosechas. Plantá en la huerta del pueblo.')
                    : 'Nada para comprar.',
            key: ValueKey(_tab == 0 ? 'trade-empty' : 'trade-crop-empty'),
            style: DsText.detail())
      ];
    }
    return out;
  }

  // ---------------- PESCA ----------------

  List<_Row> _fishing() {
    final p = widget.view.me?.profile;
    final bag = p?.life.bag ?? const <String, int>{};
    final lvl = p == null ? 1 : FishingRules.level(p);
    final t = FishingRules.t;
    final species = [
      for (final f in kFish.values)
        if ((bag[f.id] ?? 0) > 0) f
    ];
    return [
      for (final r in kRods.values)
        _Row(
            r.name,
            'cañas',
            DsListRow(
              key: ValueKey('trade-rod-${r.id}'),
              leading: LifeIcon(r.id, LifeIconKind.herramienta),
              compact: true,
              title: r.name,
              titleColor: fishRarityColor(r.rarity),
              detail: 'Caña · nivel ${r.reqLevel} · rinde '
                  '${(FishingRules.effectiveness(lvl, r.reqLevel) * 100).round()} %'
                  '${r.rareBonus > 0 ? ' · rareza +${(r.rareBonus * 100).round()} %' : ''}',
              trailing: _rodButton(r),
            )),
      for (final f in species)
        _Row(
            f.name,
            f.biome == kWaterJunkBiome
                ? 'basura'
                : f.rarity == FishRarity.legendario
                    ? 'legendarios'
                    : 'peces',
            sell: true,
            DsListRow(
              key: ValueKey('trade-row-${f.id}'),
              leading: LifeIcon(
                  f.id,
                  f.biome == kWaterJunkBiome
                      ? LifeIconKind.basura
                      : LifeIconKind.pescado),
              compact: true,
              title: '${f.name} ×${bag[f.id]}',
              titleColor: fishRarityColor(f.rarity),
              detail: '${f.rarity.label} · ${f.price} de oro c/u',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (f.rarity == FishRarity.legendario) ...[
                  DsButton('CANJEAR',
                      key: ValueKey('trade-swap-${f.id}'),
                      size: DsButtonSize.compact,
                      tooltip: '${t.i('legendCristales')} Cristales de Era y '
                          '${t.i('legendPrismas')} Prisma Roto',
                      onPressed: () => c.exchangeFish(f.id)),
                  SizedBox(width: DsSpace.xs),
                ],
                DsButton('VENDER',
                    key: ValueKey('trade-sell-${f.id}'),
                    size: DsButtonSize.compact,
                    onPressed: () =>
                        c.sellFish(species: f.id, materials: _materials)),
              ]),
            )),
    ];
  }

  Widget _rodButton(RodDef r) {
    final p = widget.view.me?.profile;
    final owned = p?.life.rods.contains(r.id) ?? false;
    if (p?.life.rod == r.id) {
      return DsButton('EQUIPADA',
          key: ValueKey('trade-rod-eq-${r.id}'),
          size: DsButtonSize.compact,
          onPressed: null);
    }
    if (owned) {
      return DsButton('EQUIPAR',
          key: ValueKey('trade-rod-eq-${r.id}'),
          size: DsButtonSize.compact,
          onPressed: () => c.equipRod(r.id));
    }
    return DsButton('COMPRAR ${r.price}',
        key: ValueKey('trade-rod-buy-${r.id}'),
        size: DsButtonSize.compact,
        onPressed: (p?.credits ?? 0) >= r.price ? () => c.buyRod(r.id) : null);
  }

  // ---------------- CULTIVO ----------------

  List<_Row> _farming() {
    final p = widget.view.me?.profile;
    final f = p?.life.farm;
    final lvl = p == null ? 1 : FarmingRules.level(p);
    final gold = p?.credits ?? 0;
    final t = FarmingRules.t;
    final seeds = [
      for (final s in kCrops.values)
        if (s.seedPrice > 0) s
    ];
    final crops = [
      for (final e in (f?.crops ?? const <String, int>{}).entries)
        if (parseCropKey(e.key) case final pc?) (e.key, pc.$1, pc.$2, e.value)
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final silo = c.town.silo;
    return [
      for (final s in seeds)
        _Row(
            s.seedName,
            'semillas',
            DsListRow(
              key: ValueKey('trade-seed-${s.id}'),
              leading: LifeIcon('semilla_${s.id}', LifeIconKind.semilla),
              compact: true,
              title: s.seedName,
              titleColor: fishRarityColor(s.rarity),
              detail:
                  '${s.rarity.label} · crece en ${(s.growSec / 60).round()} min '
                  '· tenés ${f?.seedCount(s.id) ?? 0}',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                DsButton('×1 ${s.seedPrice}',
                    key: ValueKey('trade-seed-buy-${s.id}'),
                    size: DsButtonSize.compact,
                    onPressed:
                        gold >= s.seedPrice ? () => c.buySeed(s.id) : null),
                SizedBox(width: DsSpace.xs),
                DsButton('×5 ${s.seedPrice * 5}',
                    key: ValueKey('trade-seed-buy5-${s.id}'),
                    size: DsButtonSize.compact,
                    onPressed: gold >= s.seedPrice * 5
                        ? () => c.buySeed(s.id, 5)
                        : null),
              ]),
            )),
      for (final d in kFertilizers.values)
        _Row(
            d.name,
            'abonos',
            DsListRow(
              key: ValueKey('trade-fert-${d.id}'),
              leading: LifeIcon(d.id, LifeIconKind.semilla),
              compact: true,
              title: d.name,
              titleColor: fishRarityColor(d.rarity),
              detail: 'Mejora las chances: normal / rara / épica / legendaria '
                  '(+${t.d('fert${d.key}Bias')}) · tenés ${f?.fertCount(d.id) ?? 0}',
              tooltip: DsTooltipCard(
                  title: d.name,
                  detail:
                      'Mejora las chances: normal / rara / épica / legendaria. '
                      'Se usa con F sobre un cultivo y lo hace crecer '
                      '× ${t.d('fert${d.key}Speed')}.',
                  children: [
                    Text(
                        TextDetail.isSummary
                            ? 'Mejora la cosecha y la hace crecer más rápido. '
                                'Usalo con F sobre un cultivo.'
                            : 'Mejora las chances: normal / rara / épica / '
                                'legendaria. Se usa con F sobre un cultivo y '
                                'lo hace crecer × ${t.d('fert${d.key}Speed')}.',
                        style: DsText.detail()),
                  ]),
              trailing: DsButton('COMPRAR ${d.price}',
                  key: ValueKey('trade-fert-buy-${d.id}'),
                  size: DsButtonSize.compact,
                  onPressed: gold >= d.price ? () => c.buyFert(d.id) : null),
            )),
      for (final d in kFarmTools.values)
        if (d.price > 0 || _owned(d))
          _Row(
              d.name,
              d.kind == FarmToolKind.azada ? 'azadas' : 'regaderas',
              DsListRow(
                key: ValueKey('trade-tool-${d.id}'),
                leading: LifeIcon(d.id, LifeIconKind.herramienta),
                compact: true,
                title: d.name,
                titleColor: fishRarityColor(d.rarity),
                detail: '${d.kind.label} · nivel ${d.reqLevel} · rinde '
                    '${(FarmingRules.effectiveness(lvl, d.reqLevel) * 100).round()} %'
                    '${d.area > 0 ? ' · área ${d.area == 1 ? 'en cruz' : '3 × 3'}' : ''}',
                trailing: _toolButton(d),
              )),
      if (silo.isNotEmpty)
        _Row(
            'Granero del ayudante',
            'cultivos',
            sell: true,
            DsListRow(
              key: const ValueKey('trade-silo'),
              compact: true,
              title: 'Granero del ayudante',
              detail:
                  '${silo.values.fold(0, (a, b) => a + b)} cosechas para recoger',
              trailing: DsButton('RECOGER',
                  key: const ValueKey('trade-silo-take'),
                  size: DsButtonSize.compact,
                  onPressed: c.collectSilo),
            )),
      for (final (key, crop, quality, n) in crops)
        _Row(
            crop.name,
            crop.rarity == FishRarity.legendario ? 'legendarios' : 'cultivos',
            sell: true,
            DsListRow(
              key: ValueKey('trade-crop-$key'),
              leading: LifeIcon('cosecha_${crop.id}', LifeIconKind.cosecha),
              compact: true,
              title: '${crop.name} ×$n',
              titleColor: fishRarityColor(crop.rarity),
              detail: 'Calidad ${quality.label} · '
                  '${p == null ? crop.price : FarmingRules.unitPrice(p, crop, quality)} de oro c/u',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (crop.rarity == FishRarity.legendario) ...[
                  DsButton('CANJEAR',
                      key: ValueKey('trade-crop-swap-$key'),
                      size: DsButtonSize.compact,
                      tooltip: '${t.i('legendCristales')} Cristales de Era y '
                          '${t.i('legendPrismas')} Prisma Roto',
                      onPressed: () => c.exchangeCrop(key)),
                  SizedBox(width: DsSpace.xs),
                ],
                DsButton('VENDER',
                    key: ValueKey('trade-crop-sell-$key'),
                    size: DsButtonSize.compact,
                    onPressed: () => c.sellCrop(key, materials: _materials)),
              ]),
            )),
    ];
  }

  bool _owned(FarmToolDef d) {
    final f = widget.view.me?.profile.life.farm;
    return (d.kind == FarmToolKind.azada ? f?.hoes : f?.cans)?.contains(d.id) ??
        false;
  }

  Widget _toolButton(FarmToolDef d) {
    final f = widget.view.me?.profile.life.farm;
    final gold = widget.view.me?.profile.credits ?? 0;
    final equipped = d.kind == FarmToolKind.azada ? f?.hoe : f?.can;
    if (equipped == d.id) {
      return DsButton('EQUIPADA',
          key: ValueKey('trade-tool-eq-${d.id}'),
          size: DsButtonSize.compact,
          onPressed: null);
    }
    if (_owned(d)) {
      return DsButton('EQUIPAR',
          key: ValueKey('trade-tool-eq-${d.id}'),
          size: DsButtonSize.compact,
          onPressed: () => c.equipFarmTool(d.id));
    }
    return DsButton('COMPRAR ${d.price}',
        key: ValueKey('trade-tool-buy-${d.id}'),
        size: DsButtonSize.compact,
        onPressed: gold >= d.price ? () => c.buyFarmTool(d.id) : null);
  }
}

/// Una fila del puesto: nombre (buscador), tipo (filtro) y modo.
class _Row {
  const _Row(this.name, this.kind, this.widget, {this.sell = false});
  final String name;
  final String kind;
  final Widget widget;
  final bool sell;
}
