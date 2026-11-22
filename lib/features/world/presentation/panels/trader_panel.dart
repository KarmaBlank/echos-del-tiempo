import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'fishing_panel.dart' show fishRarityColor;

/// Puesto del COMERCIANTE (fishing.md § 5): compra pescado por oro o por
/// materiales (se elige en cada venta), canjea legendarios y vende cañas.
class TraderPanel extends StatefulWidget {
  const TraderPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<TraderPanel> createState() => _TraderPanelState();
}

class _TraderPanelState extends State<TraderPanel> {
  bool _materials = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final p = widget.view.me?.profile;
    final bag = p?.life.bag ?? const <String, int>{};
    final lvl = p == null ? 1 : FishingRules.level(p);
    final t = FishingRules.t;
    final species = [
      for (final f in kFish.values)
        if ((bag[f.id] ?? 0) > 0) f
    ];
    final sellAll = species.any((f) => f.rarity != FishRarity.legendario);
    return PanelFrame(
      key: const ValueKey('panel-trader'),
      title: 'COMERCIANTE',
      width: 720,
      onClose: c.closePanel,
      actions: [
        PanelButton('VENDER TODO',
            key: const ValueKey('trade-sell-all'),
            onPressed: sellAll
                ? () => c.sellFish(materials: _materials)
                : null),
        PanelButton('CERRAR',
            key: const ValueKey('trade-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
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
            const Spacer(),
            Text('Oro ${p?.credits ?? 0}', style: DsText.detail()),
          ]),
          Text(
              _materials
                  ? 'Materiales: Esquirlas del Eco (+${((t.d('matRate') - 1) * 100).round()} % del valor; '
                      '1 cada ${t.i('matValue')} de oro).'
                  : 'Vender todo no incluye los legendarios.',
              style: DsText.detail()),
          SizedBox(height: DsSpace.sm),
          DsSectionHeader('PESCADOS',
              trailing: DsBadge('${p?.life.bagTotal ?? 0}',
                  key: const ValueKey('trade-count'))),
          if (species.isEmpty)
            Text('No tenés pescados. Probá en los muelles del lago.',
                key: const ValueKey('trade-empty'), style: DsText.detail())
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(shrinkWrap: true, children: [
                for (final f in species)
                  DsListRow(
                    key: ValueKey('trade-row-${f.id}'),
                    compact: true,
                    title: '${f.name} ×${bag[f.id]}',
                    titleColor: fishRarityColor(f.rarity),
                    detail: '${f.rarity.label} · ${f.price} de oro c/u',
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (f.rarity == FishRarity.legendario) ...[
                        DsButton('CANJEAR',
                            key: ValueKey('trade-swap-${f.id}'),
                            size: DsButtonSize.compact,
                            tooltip:
                                '${t.i('legendCristales')} Cristales de Era y '
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
                  ),
              ]),
            ),
          SizedBox(height: DsSpace.sm),
          DsSectionHeader('CAÑAS',
              trailing: Text('Pesca nivel $lvl', style: DsText.detail())),
          for (final r in kRods.values)
            DsListRow(
              key: ValueKey('trade-rod-${r.id}'),
              compact: true,
              title: r.name,
              titleColor: fishRarityColor(r.rarity),
              detail: 'Nivel ${r.reqLevel} · rinde '
                  '${(FishingRules.effectiveness(lvl, r.reqLevel) * 100).round()} %'
                  '${r.rareBonus > 0 ? ' · rareza +${(r.rareBonus * 100).round()} %' : ''}',
              trailing: _rodButton(r),
            ),
        ],
      ),
    );
  }

  Widget _rodButton(RodDef r) {
    final c = widget.controller;
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
        onPressed:
            (p?.credits ?? 0) >= r.price ? () => c.buyRod(r.id) : null);
  }
}
