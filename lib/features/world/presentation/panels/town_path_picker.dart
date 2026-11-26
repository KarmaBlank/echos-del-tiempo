import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/path_catalog.dart';
import '../../../../game_engine/rules/path_rules.dart';
import '../session_controller.dart';
import '../world_strings.dart';
import 'life_icon.dart';

/// Organism: the CAMINOS tool panel of the town editor (town_editor.md
/// § 1.7, § 4.6). PINTAR / BORRAR sub-mode, the materials as INVENTARIO
/// cells (locked ones grey with the reason in their tooltip) and the
/// detail of the chosen one below.
class TownPathPicker extends StatelessWidget {
  const TownPathPicker({super.key, required this.controller});

  final SessionController controller;

  /// Side of a material cell.
  static const cell = 48.0;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final e = c.townEdit;
    if (e == null) return const SizedBox.shrink();
    final s = worldStrings(context);
    final chosen = townPath(e.pathMat) ?? kTownPaths.first;
    final gap = SizedBox(height: DsSpace.xs);
    return Column(
      key: const ValueKey('town-paths-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsSectionHeader(s.t('ui.town.paths.title')),
        Row(children: [
          Expanded(
            child: DsButton(s.t('ui.town.paths.paint'),
                key: const ValueKey('town-paths-paint'),
                size: DsButtonSize.compact,
                selected: !e.pathErase,
                kind: e.pathErase ? DsButtonKind.secondary : DsButtonKind.primary,
                onPressed: () => c.setPathErase(false)),
          ),
          SizedBox(width: DsSpace.xs),
          Expanded(
            child: DsButton(s.t('ui.town.paths.erase'),
                key: const ValueKey('town-paths-erase'),
                size: DsButtonSize.compact,
                selected: e.pathErase,
                kind: e.pathErase ? DsButtonKind.primary : DsButtonKind.secondary,
                tooltip: s.t('ui.town.paths.erase_tip'),
                onPressed: () => c.setPathErase(true)),
          ),
        ]),
        gap,
        Wrap(
          key: const ValueKey('town-paths-grid'),
          spacing: DsSpace.xs,
          runSpacing: DsSpace.xs,
          children: [
            for (final d in kTownPaths)
              _cell(s, d, c.pathLockText(d),
                  d.id == chosen.id && !e.pathErase),
          ],
        ),
        gap,
        _detail(s, chosen, c.pathLockText(chosen)),
      ],
    );
  }

  String _costText(Strings s, TownPathDef d) {
    final k = PathRules.cost(d);
    return k.ore > 0 && k.item != null
        ? s.t('ui.town.paths.cost_ore', {
            'gold': k.gold,
            'n': k.ore,
            'item': s.t('ui.town.paths.ore.${k.item}'),
          })
        : s.t('ui.town.paths.cost', {'gold': k.gold});
  }

  Widget _detail(Strings s, TownPathDef d, String? why) {
    return Column(
      key: const ValueKey('town-paths-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.t('ui.town.paths.${d.id}.name'),
            style: DsText.title(why == null ? DsColors.reward : null)),
        DsGoldText(_costText(s, d),
            style: DsText.detail(why == null ? null : DsColors.danger)),
        Text(
            s.t('ui.town.paths.level',
                {'n': PathRules.cost(d).level}),
            style: DsText.detail()),
        Text(s.t('ui.town.paths.${d.id}.info'), style: DsText.body()),
        if (why != null)
          Text(why,
              key: const ValueKey('town-paths-why'),
              style: DsText.detail(DsColors.danger)),
      ],
    );
  }

  Widget _cell(Strings s, TownPathDef d, String? why, bool selected) {
    final ok = why == null;
    return DsTooltip(
      card: IgnorePointer(
        child: DsTooltipCard(
            title: s.t('ui.town.paths.${d.id}.name'),
            children: [
              DsGoldText(_costText(s, d),
                  style: DsText.detail(ok ? null : DsColors.danger)),
              Text(s.t('ui.town.paths.level', {'n': PathRules.cost(d).level}),
                  style: DsText.detail()),
              if (why != null)
                Text(why,
                    key: ValueKey('town-paths-lock-${d.id}'),
                    style: DsText.detail(DsColors.danger)),
            ]),
      ),
      child: MouseRegion(
        cursor: ok ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          key: ValueKey('town-paths-mat-${d.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: ok ? () => controller.setPathMaterial(d.id) : null,
          child: DsItemCell(
            dimension: cell,
            icon: Opacity(
              opacity: ok ? 1 : 0.35,
              child: LifeIcon(d.icon, LifeIconKind.herramienta,
                  size: DsSizes.itemIcon * cell / DsSizes.itemCell),
            ),
            border: ok ? DsColors.reward : DsColors.textDisabled,
            selected: selected,
          ),
        ),
      ),
    );
  }
}
