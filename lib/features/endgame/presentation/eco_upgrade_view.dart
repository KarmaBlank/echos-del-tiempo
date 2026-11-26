import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/rules/progression_rules.dart';
import 'eco_grid.dart';

/// One upgrade operation of the chosen Eco (ecos_atlas.md § 4.1).
class EcoUpgradeOp {
  const EcoUpgradeOp({
    required this.id,
    required this.label,
    required this.effect,
    required this.cost,
    required this.reason,
    required this.onApply,
  });

  /// `reroll`, `addMod`... The button is `ValueKey('eco-craft-<id>')`.
  final String id;
  final String label;
  final String effect;

  /// The material as an item cell with `have/need` (`null` = the
  /// operation is maxed out and costs nothing).
  final DsCostEntry? cost;

  /// Why APLICAR is grey, or `null`.
  final String? reason;
  final VoidCallback onApply;
}

/// Subtab MEJORAR of the Portal's ECOS tab (ecos_atlas.md § 4.1): grid of
/// Ecos (same cells as FUSIONAR) and, on the right, the chosen Eco: where
/// it opens (status + IR AL PORTAL), its info and the upgrades with their
/// materials as item cells. Purely visual: texts, state and callbacks
/// come in as parameters.
class EcoUpgradeView extends StatelessWidget {
  const EcoUpgradeView({
    super.key,
    required this.rules,
    required this.ecos,
    required this.selected,
    required this.onSelect,
    required this.empty,
    required this.info,
    required this.statusText,
    required this.statusReady,
    required this.opensAt,
    required this.goLabel,
    required this.goReason,
    required this.onGo,
    required this.upgradesTitle,
    required this.applyLabel,
    required this.ops,
    this.footer = const [],
  });

  final ProgressionRules rules;
  final List<EcoItem> ecos;

  /// The chosen Eco (`null` only without Ecos).
  final EcoItem? selected;
  final ValueChanged<String> onSelect;

  /// Text without Ecos.
  final String empty;

  /// The Eco's sheet (tier, zone, boss, mods, loot).
  final Widget info;

  /// "Listo para abrir en …" (green) or "Bloqueado: …" (grey).
  final String statusText;
  final bool statusReady;

  /// Reminder: Ecos are opened at the biome portal, not here.
  final String opensAt;
  final String goLabel;

  /// Why IR AL PORTAL is grey, or `null`.
  final String? goReason;
  final VoidCallback onGo;
  final String upgradesTitle;
  final String applyLabel;
  final List<EcoUpgradeOp> ops;

  /// Under the grid (dev shortcuts).
  final List<Widget> footer;

  static const detailWidth = DsSizes.detailPaneWidth;

  Widget _op(EcoUpgradeOp op) => Padding(
        padding: EdgeInsets.only(bottom: DsSpace.sm),
        child: Row(
          key: ValueKey('eco-op-${op.id}'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: DsCostGrid.cell,
              child: op.cost == null
                  ? SizedBox.square(
                      dimension: DsCostGrid.cell,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: DsColors.surfaceSunken,
                              border: Border.all(color: DsColors.border))))
                  : DsCostGrid([op.cost!]),
            ),
            SizedBox(width: DsSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(op.label, style: DsText.body(DsColors.textPrimary)),
                  Text(op.effect, style: DsText.detail()),
                ],
              ),
            ),
            SizedBox(width: DsSpace.sm),
            DsButton(applyLabel,
                key: ValueKey('eco-craft-${op.id}'),
                size: DsButtonSize.compact,
                tooltip: op.reason,
                onPressed: op.reason == null ? op.onApply : null),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final e = selected;
    final detail = DsDetailPane(
      key: const ValueKey('eco-upgrade-detail'),
      body: e == null
          ? Text(opensAt, softWrap: true, style: DsText.detail())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Where it opens: status + travel, always on top.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(statusText,
                          key: const ValueKey('eco-status'),
                          softWrap: true,
                          style: DsText.body(statusReady
                              ? DsColors.success
                              : DsColors.textSecondary)),
                    ),
                    SizedBox(width: DsSpace.sm),
                    DsButton(goLabel,
                        key: const ValueKey('eco-go'),
                        size: DsButtonSize.compact,
                        kind: DsButtonKind.primary,
                        tooltip: goReason,
                        onPressed: goReason == null ? onGo : null),
                  ],
                ),
                SizedBox(height: DsSpace.xs),
                Text(opensAt,
                    key: const ValueKey('eco-opens-at'),
                    softWrap: true,
                    style: DsText.detail()),
                SizedBox(height: DsSpace.sm),
                info,
                SizedBox(height: DsSpace.md),
                Text(upgradesTitle, style: DsText.subtitle(DsColors.textSubtitle)),
                SizedBox(height: DsSpace.xs),
                for (final op in ops) _op(op),
              ],
            ),
    );
    return EcoGridLayout(
      empty: Text(empty,
          key: const ValueKey('eco-upgrade-empty'), style: DsText.detail()),
      footer: footer,
      cells: [
        for (final x in ecos)
          EcoGridCell(
              key: ValueKey('eco-row-${x.uid}'),
              rules: rules,
              eco: x,
              selected: x.uid == e?.uid,
              onTap: () => onSelect(x.uid)),
      ],
      detail: detail,
    );
  }
}
