import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';
import 'life_icon.dart';
import 'life_item_grid.dart';

/// One free house cell (purely visual data).
class HouseCellData {
  const HouseCellData(this.id, this.title, this.line, {this.level = 1});
  final String id;
  final String title;
  final String line;

  /// House level (1–3): picks the `vida_casa_<level>` sprite.
  final int level;
}

/// One resident who can move into a house (purely visual data).
class HouseCandidateData {
  const HouseCandidateData(this.id, this.name, this.line);
  final String id;
  final String name;
  final String line;
}

/// ASIGNAR CASAS (town_editor.md § 1.1): the free houses as a grid and,
/// on the right, who can live in the chosen one plus ASIGNAR. Knows
/// nothing about the session: it calls [onAssign] with (npc, house).
class HouseAssignView extends StatefulWidget {
  const HouseAssignView({
    super.key,
    required this.houses,
    required this.candidates,
    required this.onAssign,
    this.blockedWhy,
  });

  final List<HouseCellData> houses;
  final List<HouseCandidateData> candidates;
  final void Function(String npc, String house) onAssign;

  /// Why ASIGNAR is grey (another player is editing); `null` = enabled.
  final String? blockedWhy;

  @override
  State<HouseAssignView> createState() => _HouseAssignViewState();
}

class _HouseAssignViewState extends State<HouseAssignView> {
  String? _house;
  String? _npc;

  @override
  Widget build(BuildContext context) {
    final houses = widget.houses;
    if (houses.isEmpty || widget.candidates.isEmpty) {
      return Center(
        child: Text(
            houses.isEmpty
                ? context.t('ui.town.houses.no_houses')
                : context.t('ui.town.houses.empty'),
            key: const ValueKey('houses-empty'),
            softWrap: true,
            textAlign: TextAlign.center,
            style: DsText.body(DsColors.textSecondary)),
      );
    }
    final sel = houses.where((h) => h.id == _house).firstOrNull ?? houses.first;
    final who = widget.candidates.where((c) => c.id == _npc).firstOrNull;
    final detail = DsDetailPane(
      key: const ValueKey('houses-detail'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(sel.title, softWrap: true, style: DsText.subtitle()),
          Text(sel.line,
              softWrap: true, style: DsText.detail(DsColors.textSecondary)),
          SizedBox(height: DsSpace.sm),
          Text(context.t('ui.town.houses.who'),
              softWrap: true, style: DsText.detail(DsColors.textSecondary)),
          SizedBox(height: DsSpace.xs),
          for (final c in widget.candidates)
            DsListRow(
              key: ValueKey('houses-npc-${c.id}'),
              title: c.name,
              subtitle: c.line,
              wrap: true,
              selected: c.id == who?.id,
              onTap: () => setState(() => _npc = c.id),
            ),
        ],
      ),
      actions: DsButton(context.t('ui.town.houses.assign'),
          key: const ValueKey('houses-assign'),
          kind: DsButtonKind.primary,
          tooltip: widget.blockedWhy ??
              (who == null ? context.t('ui.town.houses.pick_resident') : null),
          onPressed: who == null || widget.blockedWhy != null
              ? null
              : () {
                  widget.onAssign(who.id, sel.id);
                  setState(() {
                    _npc = null;
                    _house = null;
                  });
                }),
    );
    // INVENTARIO grid (design_system.md § DsGridDetailLayout): house
    // sprites 6 per row top-left, no text in or under the cells (name and
    // level in the tooltip); the detail takes the rest of the width.
    return DsGridDetailLayout(
      keyPrefix: 'houses',
      count: houses.length,
      detail: detail,
      cell: (context, i, size) {
        final h = houses[i];
        return KeyedSubtree(
          key: ValueKey('houses-cell-${h.id}'),
          child: LifeItemCell(
            size: size,
            selected: h.id == sel.id,
            onTap: () => setState(() => _house = h.id),
            data: LifeItemCellData(
              id: 'houses-item-${h.id}',
              icon: LifeIcon('casa_${h.level.clamp(1, 3)}',
                  LifeIconKind.herramienta,
                  size: LifeItemGrid.iconSize * size / LifeItemGrid.cell),
              border: DsColors.border,
              search: h.title,
              detail: LifeItemDetail(
                  name: h.title,
                  nameColor: DsColors.textTitle,
                  lines: [h.line]),
            ),
          ),
        );
      },
    );
  }
}

/// The panel opened from the rune fountain: maps the town to
/// [HouseAssignView] and sends the existing assign op.
class HouseAssignPanel extends StatelessWidget {
  const HouseAssignPanel({super.key, required this.controller});
  final SessionController controller;

  /// Free houses and homeless residents of [town] as view data.
  static (List<HouseCellData>, List<HouseCandidateData>) dataOf(
      BuildContext context, TownState town) {
    final free = ResidentRules.freeHouses(town);
    return (
      [
        for (var i = 0; i < free.length; i++)
          HouseCellData(
              free[i].id,
              context.t('ui.town.houses.cell', {'n': i + 1}),
              context.t('ui.town.houses.level', {'n': free[i].level}),
              level: free[i].level),
      ],
      [
        for (final n in ResidentRules.awaitingHouse(town))
          HouseCandidateData(n.id, n.name,
              ResidentRules.benefitText(n, ResidentRules.tier(town.resident(n.id).copyWith(house: 1)))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final (houses, people) = dataOf(context, c.town);
    return PanelFrame(
      key: const ValueKey('panel-houses'),
      title: context.t('ui.town.houses.title'),
      width: 1000,
      onClose: () => c.openPanel(WorldPanel.fountain),
      actions: [
        PanelButton(context.t('ui.town.fountain.close'),
            key: const ValueKey('houses-close'),
            onPressed: () => c.openPanel(WorldPanel.fountain)),
      ],
      child: SizedBox(
        height: 420,
        child: HouseAssignView(
          houses: houses,
          candidates: people,
          blockedWhy: c.cannotEditTown,
          onAssign: c.assignHouse,
        ),
      ),
    );
  }
}
