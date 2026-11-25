import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';

/// PIEDRAS DE PASO (docs/specs/biome_regions.md § 4): the waystones of
/// this region as a grid of cards (activated ones lit, the rest grey
/// "not found yet") and the chosen one's detail on the right with IR.
/// Purely visual: the controller validates and sends the travel.
class WaystonePanel extends StatefulWidget {
  const WaystonePanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<WaystonePanel> createState() => _WaystonePanelState();
}

class _WaystonePanelState extends State<WaystonePanel> {
  static const _cellW = 220.0;
  int? _sel;

  String _name(BuildContext context, BiomeLayout lay, int i) {
    final w = lay.waystones[i];
    return switch (w.site) {
      WaystoneSite.entrance => context.t('ui.world.way.site_entrance'),
      WaystoneSite.lake =>
        context.t('ui.world.way.site_lake', {'name': lay.lakes[w.ref].name}),
      WaystoneSite.mine =>
        context.t('ui.world.way.site_mine', {'n': w.ref + 1}),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final lay = biomeLayout(c.place);
    final here = c.nearWaystone;
    final close = PanelButton(context.t('ui.world.way.close'),
        key: const ValueKey('way-close'), onPressed: c.closePanel);
    if (lay == null) {
      return PanelFrame(
          key: const ValueKey('panel-waystone'),
          title: context.t('ui.world.way.title'),
          width: 820,
          onClose: c.closePanel,
          actions: [close],
          child: const SizedBox.shrink());
    }
    final n = lay.waystones.length;
    final sel = (_sel ?? here ?? 0).clamp(0, n - 1);
    final active = [for (var i = 0; i < n; i++) c.waystoneActive(i)];

    // No fixed height and no truncation (ui rule): the cell grows with
    // the name at any text scale.
    Widget cell(int i) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: SizedBox(
          width: _cellW,
          child: DsCard(
            key: ValueKey('way-cell-$i'),
            selected: i == sel,
            onTap: () => setState(() => _sel = i),
            padding: EdgeInsets.all(DsSpace.sm),
            child: Row(children: [
              Container(
                  width: 10,
                  height: 26,
                  color: active[i] ? DsColors.mp : DsColors.textDisabled),
              SizedBox(width: DsSpace.sm),
              Expanded(
                child: Text(
                    active[i]
                        ? _name(context, lay, i)
                        : context.t('ui.world.way.unknown'),
                    softWrap: true,
                    style:
                        DsText.body(active[i] ? null : DsColors.textDisabled)),
              ),
            ]),
          ),
        ));

    final canGo = active[sel] && here != null && here != sel;
    final detail = DsDetailPane(
      key: const ValueKey('way-detail'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              active[sel]
                  ? _name(context, lay, sel)
                  : context.t('ui.world.way.unknown'),
              softWrap: true,
              style: DsText.title()),
          SizedBox(height: DsSpace.sm),
          if (sel == here)
            DsBadge(context.t('ui.world.way.here'),
                key: const ValueKey('way-here')),
          if (!active[sel])
            Text(context.t('ui.world.way.unknown_tip'),
                softWrap: true, style: DsText.detail()),
        ],
      ),
      actions: DsButton(context.t('ui.world.way.go'),
          key: ValueKey('way-go-$sel'),
          kind: DsButtonKind.primary,
          onPressed: canGo ? () => c.travelWaystone(sel) : null),
    );

    return PanelFrame(
      key: const ValueKey('panel-waystone'),
      title: context.t('ui.world.way.title'),
      width: 820,
      onClose: c.closePanel,
      actions: [close],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.t('ui.world.way.help'), style: DsText.detail()),
          SizedBox(height: DsSpace.sm),
          SizedBox(
            height: 300,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 2 * _cellW + DsSpace.sm,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: DsSpace.sm,
                      runSpacing: DsSpace.sm,
                      children: [for (var i = 0; i < n; i++) cell(i)],
                    ),
                  ),
                ),
                SizedBox(width: DsSpace.md),
                Expanded(child: detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
